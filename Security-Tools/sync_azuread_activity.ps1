<#
.SYNOPSIS
    Synchronizes Azure AD user activity data to on-premises Active Directory for license optimization

.DESCRIPTION
    This script addresses the challenge of tracking user activity across hybrid environments where users
    may only access cloud-based SaaS applications without logging into on-premises systems. It retrieves
    Azure AD sign-in activity data and updates ExtensionAttribute9 in on-premises AD to indicate recent
    activity, enabling intelligent license management and automated account lifecycle processes.
    
    The script supports certificate-based authentication for secure, unattended operation and provides
    comprehensive logging for audit and troubleshooting purposes.

.PARAMETER ClientId
    Azure AD application (client) ID for Microsoft Graph authentication

.PARAMETER TenantId
    Azure AD tenant ID

.PARAMETER CertificateThumbprint
    Certificate thumbprint for certificate-based authentication

.PARAMETER ActivityThresholdDays
    Number of days to consider for recent activity. Default is 60 days.

.PARAMETER LogPath
    Path for log file. Default is script directory with timestamp.

.PARAMETER ReportOnly
    When specified, runs in report-only mode without making changes to AD

.PARAMETER TestMode
    Processes only a subset of users for testing purposes

.EXAMPLE
    .\Sync-AzureADActivity.ps1 -ClientId "12345678-1234-1234-1234-123456789012" -TenantId "87654321-4321-4321-4321-210987654321" -CertificateThumbprint "ABC123..."
    Runs the sync with certificate authentication using default 60-day threshold

.EXAMPLE
    .\Sync-AzureADActivity.ps1 -ClientId $clientId -TenantId $tenantId -CertificateThumbprint $certThumb -ActivityThresholdDays 90 -ReportOnly
    Runs in report-only mode with 90-day activity threshold

.NOTES
    Author: James Lunardi
    Version: 1.0
    
    Prerequisites:
    - Microsoft.Graph PowerShell module
    - ActiveDirectory PowerShell module
    - Certificate configured for Azure AD app authentication
    - Application permissions: User.Read.All, AuditLog.Read.All
    - On-premises AD write permissions for target users
    
    Business Context:
    - Enables license optimization through activity-based assignment
    - Supports hybrid identity lifecycle management
    - Prevents unnecessary account disabling for cloud-only users
    
.LINK
    https://github.com/jameslunardi/powershell-library
    https://www.linkedin.com/in/jameslunardi/
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$ClientId,
    
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$TenantId,
    
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-fA-F]{40}$')]
    [string]$CertificateThumbprint,
    
    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 365)]
    [int]$ActivityThresholdDays = 60,
    
    [Parameter(Mandatory = $false)]
    [string]$LogPath,
    
    [Parameter(Mandatory = $false)]
    [switch]$ReportOnly,
    
    [Parameter(Mandatory = $false)]
    [switch]$TestMode
)

#region Functions
# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

function Write-ProgressInfo {
    param(
        [string]$Message,
        [string]$Color = "Cyan"
    )
    Write-Host $Message -ForegroundColor $Color
    Write-Verbose $Message
}

function Write-LogEntry {
    param(
        [string]$Message,
        [string]$LogPath,
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp [$Level] - $Message"
    
    try {
        Add-Content -Path $LogPath -Value $logEntry -ErrorAction Stop
    }
    catch {
        Write-Warning "Failed to write to log file: $($_.Exception.Message)"
    }
}

function Test-Prerequisites {
    Write-Verbose "Checking prerequisites..."
    
    # Check Microsoft Graph module
    if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Users)) {
        throw "Microsoft.Graph.Users module is required. Install with: Install-Module Microsoft.Graph"
    }
    
    # Check Active Directory module
    if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
        throw "ActiveDirectory module is required."
    }
    
    # Check certificate availability
    $cert = Get-ChildItem -Path "Cert:\CurrentUser\My\$CertificateThumbprint" -ErrorAction SilentlyContinue
    if (-not $cert) {
        $cert = Get-ChildItem -Path "Cert:\LocalMachine\My\$CertificateThumbprint" -ErrorAction SilentlyContinue
        if (-not $cert) {
            throw "Certificate with thumbprint $CertificateThumbprint not found in certificate store."
        }
    }
    
    Write-Verbose "Prerequisites check completed successfully"
}

function Get-UserActivityStatus {
    param(
        [object]$User,
        [int]$ThresholdDays
    )
    
    # Calculate days since last sign-in (interactive or non-interactive)
    $daysSinceLastSignIn = if ($User.SignInActivity.LastSignInDateTime) { 
        (New-TimeSpan -Start $User.SignInActivity.LastSignInDateTime -End (Get-Date)).Days 
    } else { 
        $null 
    }
    
    $daysSinceLastNonInteractiveSignIn = if ($User.SignInActivity.LastNonInteractiveSignInDateTime) { 
        (New-TimeSpan -Start $User.SignInActivity.LastNonInteractiveSignInDateTime -End (Get-Date)).Days 
    } else { 
        $null 
    }
    
    # Determine minimum days since any sign-in
    $minDaysSinceSignIn = if ($null -eq $daysSinceLastSignIn -and $null -eq $daysSinceLastNonInteractiveSignIn) {
        $null
    } elseif ($null -eq $daysSinceLastSignIn) {
        $daysSinceLastNonInteractiveSignIn
    } elseif ($null -eq $daysSinceLastNonInteractiveSignIn) {
        $daysSinceLastSignIn
    } else {
        [math]::Min($daysSinceLastSignIn, $daysSinceLastNonInteractiveSignIn)
    }
    
    # Determine activity status
    $isActive = if ($null -eq $minDaysSinceSignIn -or $minDaysSinceSignIn -ge $ThresholdDays) {
        "False"
    } else {
        "True"
    }
    
    return @{
        IsActive = $isActive
        MinDaysSinceSignIn = $minDaysSinceSignIn
        LastSignInDateTime = $User.SignInActivity.LastSignInDateTime
        LastNonInteractiveSignInDateTime = $User.SignInActivity.LastNonInteractiveSignInDateTime
    }
}

#endregion Functions

#region Initialization
# =============================================================================
# SCRIPT INITIALIZATION
# =============================================================================

Write-ProgressInfo "Azure AD Activity Sync Utility" "Green"
Write-ProgressInfo "===============================" "Green"

# Set up logging
if (-not $LogPath) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
    $LogPath = Join-Path $scriptDir "AzureADActivitySync_$timestamp.log"
}

# Ensure log directory exists
$logDir = Split-Path -Parent $LogPath
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

# Initialize log file
if (-not (Test-Path $LogPath)) {
    New-Item -Path $LogPath -ItemType File -Force | Out-Null
}

Write-LogEntry -Message "Script started" -LogPath $LogPath
Write-LogEntry -Message "Parameters: ClientId=$ClientId, TenantId=$TenantId, ActivityThresholdDays=$ActivityThresholdDays, ReportOnly=$ReportOnly" -LogPath $LogPath

Write-ProgressInfo "`nConfiguration:"
Write-Host "  Activity Threshold: $ActivityThresholdDays days" -ForegroundColor White
Write-Host "  Report Only Mode: $ReportOnly" -ForegroundColor White
Write-Host "  Test Mode: $TestMode" -ForegroundColor White
Write-Host "  Log Path: $LogPath" -ForegroundColor White

# Check prerequisites
try {
    Test-Prerequisites
}
catch {
    Write-Error $_.Exception.Message
    Write-LogEntry -Message "Prerequisites check failed: $($_.Exception.Message)" -LogPath $LogPath -Level "ERROR"
    exit 1
}

#endregion Initialization

#region Azure AD Connection
# =============================================================================
# CONNECT TO MICROSOFT GRAPH
# =============================================================================

Write-ProgressInfo "`nConnecting to Microsoft Graph..."
Write-LogEntry -Message "Attempting to connect to Microsoft Graph" -LogPath $LogPath

try {
    Import-Module Microsoft.Graph.Users -Force
    Import-Module ActiveDirectory -Force
    
    Connect-MgGraph -ClientId $ClientId -TenantId $TenantId -CertificateThumbprint $CertificateThumbprint -NoWelcome
    
    # Verify connection
    $context = Get-MgContext
    Write-ProgressInfo "Successfully connected to Microsoft Graph" "Green"
    Write-Host "  Tenant: $($context.TenantId)" -ForegroundColor White
    Write-Host "  App: $($context.AppName)" -ForegroundColor White
    Write-Host "  Scopes: $($context.Scopes -join ', ')" -ForegroundColor White
    
    Write-LogEntry -Message "Successfully connected to Microsoft Graph" -LogPath $LogPath
}
catch {
    Write-Error "Failed to connect to Microsoft Graph: $($_.Exception.Message)"
    Write-LogEntry -Message "Failed to connect to Microsoft Graph: $($_.Exception.Message)" -LogPath $LogPath -Level "ERROR"
    exit 1
}

#endregion Azure AD Connection

#region User Data Retrieval
# =============================================================================
# RETRIEVE AZURE AD USER DATA
# =============================================================================

Write-ProgressInfo "`nRetrieving Azure AD user data..."
Write-LogEntry -Message "Starting user data retrieval from Azure AD" -LogPath $LogPath

try {
    $users = Get-MgUser -All -Property DisplayName, UserPrincipalName, AccountEnabled, SignInActivity | 
        Where-Object { $_.AccountEnabled -eq $true }
    
    if ($TestMode) {
        $users = $users | Select-Object -First 10
        Write-ProgressInfo "Test mode: Processing only $($users.Count) users" "Yellow"
    }
    
    Write-ProgressInfo "Retrieved $($users.Count) enabled users from Azure AD" "Green"
    Write-LogEntry -Message "Retrieved $($users.Count) enabled users from Azure AD" -LogPath $LogPath
}
catch {
    Write-Error "Failed to retrieve user data: $($_.Exception.Message)"
    Write-LogEntry -Message "Failed to retrieve user data: $($_.Exception.Message)" -LogPath $LogPath -Level "ERROR"
    exit 1
}

#endregion User Data Retrieval

#region User Processing
# =============================================================================
# PROCESS USERS AND UPDATE ACTIVE DIRECTORY
# =============================================================================

Write-ProgressInfo "`nProcessing users and updating Active Directory..."
Write-LogEntry -Message "Starting user processing and AD updates" -LogPath $LogPath

$stats = @{
    Processed = 0
    Updated = 0
    NoChangeNeeded = 0
    Errors = 0
    NotFoundInAD = 0
}

foreach ($user in $users) {
    $stats.Processed++
    
    # Show progress for large datasets
    if ($stats.Processed % 100 -eq 0) {
        Write-Progress -Activity "Processing Users" -Status "Processed $($stats.Processed) of $($users.Count)" -PercentComplete (($stats.Processed / $users.Count) * 100)
    }
    
    # Extract SamAccountName from UPN
    $samAccountName = $user.UserPrincipalName -replace "@.*$"
    
    # Get activity status
    $activityStatus = Get-UserActivityStatus -User $user -ThresholdDays $ActivityThresholdDays
    
    try {
        # Check if user exists in on-premises AD
        $adUser = Get-ADUser -Filter "SamAccountName -eq '$samAccountName'" -Properties ExtensionAttribute9 -ErrorAction Stop
        
        if ($adUser) {
            # Determine if update is needed
            if ($adUser.ExtensionAttribute9 -ne $activityStatus.IsActive) {
                if (-not $ReportOnly) {
                    Set-ADUser -Identity $samAccountName -Replace @{ExtensionAttribute9 = $activityStatus.IsActive} -ErrorAction Stop
                    $stats.Updated++
                    
                    Write-Host "Updated $samAccountName -> ExtensionAttribute9 = $($activityStatus.IsActive)" -ForegroundColor Green
                    Write-LogEntry -Message "Updated $samAccountName to $($activityStatus.IsActive) (Days since sign-in: $($activityStatus.MinDaysSinceSignIn))" -LogPath $LogPath
                }
                else {
                    $stats.Updated++
                    Write-Host "Would update $samAccountName -> ExtensionAttribute9 = $($activityStatus.IsActive) (Report Only)" -ForegroundColor Yellow
                    Write-LogEntry -Message "Would update $samAccountName to $($activityStatus.IsActive) (Report Only)" -LogPath $LogPath
                }
            }
            else {
                $stats.NoChangeNeeded++
                Write-Verbose "No update needed for $samAccountName (already $($activityStatus.IsActive))"
            }
        }
        else {
            $stats.NotFoundInAD++
            Write-Verbose "User not found in AD: $samAccountName"
            Write-LogEntry -Message "User not found in AD: $samAccountName" -LogPath $LogPath -Level "WARN"
        }
    }
    catch {
        $stats.Errors++
        Write-Warning "Error processing $samAccountName`: $($_.Exception.Message)"
        Write-LogEntry -Message "Error processing $samAccountName`: $($_.Exception.Message)" -LogPath $LogPath -Level "ERROR"
    }
}

Write-Progress -Activity "Processing Users" -Completed

#endregion User Processing

#region Summary and Cleanup
# =============================================================================
# DISPLAY SUMMARY AND CLEANUP
# =============================================================================

Write-ProgressInfo "`n===============================" "Green"
Write-ProgressInfo "Processing Summary" "Green"
Write-ProgressInfo "===============================" "Green"

Write-Host "`nProcessing Statistics:" -ForegroundColor Cyan
Write-Host "  Total Users Processed: $($stats.Processed)" -ForegroundColor White
Write-Host "  Users Updated: $($stats.Updated)" -ForegroundColor White
Write-Host "  No Change Needed: $($stats.NoChangeNeeded)" -ForegroundColor White
Write-Host "  Users Not Found in AD: $($stats.NotFoundInAD)" -ForegroundColor White
Write-Host "  Errors Encountered: $($stats.Errors)" -ForegroundColor White

# Calculate activity statistics
$activeUsers = $users | Where-Object { 
    $activity = Get-UserActivityStatus -User $_ -ThresholdDays $ActivityThresholdDays
    $activity.IsActive -eq "True"
}

$inactiveUsers = $users | Where-Object { 
    $activity = Get-UserActivityStatus -User $_ -ThresholdDays $ActivityThresholdDays
    $activity.IsActive -eq "False"
}

Write-Host "`nActivity Analysis:" -ForegroundColor Cyan
Write-Host "  Active Users (< $ActivityThresholdDays days): $($activeUsers.Count)" -ForegroundColor Green
Write-Host "  Inactive Users (≥ $ActivityThresholdDays days): $($inactiveUsers.Count)" -ForegroundColor Yellow
Write-Host "  Activity Threshold: $ActivityThresholdDays days" -ForegroundColor White

# Log final statistics
Write-LogEntry -Message "Processing completed: $($stats.Processed) processed, $($stats.Updated) updated, $($stats.Errors) errors" -LogPath $LogPath
Write-LogEntry -Message "Activity analysis: $($activeUsers.Count) active, $($inactiveUsers.Count) inactive (threshold: $ActivityThresholdDays days)" -LogPath $LogPath

# Cleanup
try {
    Disconnect-MgGraph -ErrorAction SilentlyContinue
    Write-LogEntry -Message "Disconnected from Microsoft Graph" -LogPath $LogPath
}
catch {
    Write-Warning "Error disconnecting from Graph: $($_.Exception.Message)"
}

Write-LogEntry -Message "Script completed successfully" -LogPath $LogPath
Write-LogEntry -Message "============================================================" -LogPath $LogPath

if ($ReportOnly) {
    Write-ProgressInfo "`nScript completed in Report Only mode - no changes were made." "Yellow"
}
else {
    Write-ProgressInfo "`nScript completed successfully!" "Green"
}

Write-Host "`nLog file: $LogPath" -ForegroundColor Gray

#endregion Summary and Cleanup