<#
.SYNOPSIS
    Generates comprehensive Azure AD license utilization and user activity reports

.DESCRIPTION
    This script provides detailed reporting on Azure AD license consumption and user activity
    patterns to support license optimization and compliance initiatives. It analyzes user
    sign-in activity against configurable thresholds and correlates this data with license
    assignments to identify optimization opportunities.
    
    The script supports multiple output formats including console display, CSV export, and
    JSON for integration with monitoring and reporting systems.

.PARAMETER ClientId
    Azure AD application (client) ID for Microsoft Graph authentication

.PARAMETER TenantId
    Azure AD tenant ID

.PARAMETER CertificateThumbprint
    Certificate thumbprint for certificate-based authentication

.PARAMETER ActivityThresholdDays
    Number of days to consider for recent activity analysis. Default is 60 days.

.PARAMETER OutputPath
    Directory path for exporting detailed reports to CSV and JSON files

.PARAMETER IncludeLicenseDetails
    Include detailed license assignment information in the report

.PARAMETER ExportFormat
    Export format: 'CSV', 'JSON', or 'Both'. Default is 'Both'

.EXAMPLE
    .\Get-AzureADLicenseReport.ps1 -ClientId "12345678-1234-1234-1234-123456789012" -TenantId "87654321-4321-4321-4321-210987654321" -CertificateThumbprint "ABC123..."
    Generates basic license and activity report with 60-day threshold

.EXAMPLE
    .\Get-AzureADLicenseReport.ps1 -ClientId $clientId -TenantId $tenantId -CertificateThumbprint $certThumb -ActivityThresholdDays 90 -OutputPath "C:\Reports" -IncludeLicenseDetails
    Generates comprehensive report with 90-day threshold and detailed license information

.NOTES
    Author: James Lunardi
    Version: 1.0
    
    Prerequisites:
    - Microsoft.Graph PowerShell module
    - Certificate configured for Azure AD app authentication
    - Application permissions: User.Read.All, Organization.Read.All, Directory.Read.All
    
    Business Value:
    - License cost optimization through activity-based analysis
    - Compliance reporting for license usage audits
    - Capacity planning for license procurement
    - User activity insights for security and productivity analysis
    
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
    [ValidateScript({
        if ($_ -and -not (Test-Path $_)) {
            New-Item -Path $_ -ItemType Directory -Force | Out-Null
        }
        return $true
    })]
    [string]$OutputPath,
    
    [Parameter(Mandatory = $false)]
    [switch]$IncludeLicenseDetails,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet('CSV', 'JSON', 'Both')]
    [string]$ExportFormat = 'Both'
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

function Get-UserActivityMetrics {
    param([object]$User, [int]$ThresholdDays)
    
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
    
    $minDaysSinceSignIn = if ($null -eq $daysSinceLastSignIn -and $null -eq $daysSinceLastNonInteractiveSignIn) {
        $null
    } elseif ($null -eq $daysSinceLastSignIn) {
        $daysSinceLastNonInteractiveSignIn
    } elseif ($null -eq $daysSinceLastNonInteractiveSignIn) {
        $daysSinceLastSignIn
    } else {
        [math]::Min($daysSinceLastSignIn, $daysSinceLastNonInteractiveSignIn)
    }
    
    return @{
        LastSignInDateTime = $User.SignInActivity.LastSignInDateTime
        LastNonInteractiveSignInDateTime = $User.SignInActivity.LastNonInteractiveSignInDateTime
        DaysSinceLastSignIn = $daysSinceLastSignIn
        DaysSinceLastNonInteractiveSignIn = $daysSinceLastNonInteractiveSignIn
        MinDaysSinceSignIn = $minDaysSinceSignIn
        IsActiveUser = ($null -ne $minDaysSinceSignIn -and $minDaysSinceSignIn -lt $ThresholdDays)
    }
}

function Export-ReportData {
    param(
        [object]$Data,
        [string]$FileName,
        [string]$OutputPath,
        [string]$Format
    )
    
    if (-not $OutputPath) { return }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
    
    if ($Format -in @('CSV', 'Both')) {
        $csvPath = Join-Path $OutputPath "$FileName-$timestamp.csv"
        $Data | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
        Write-Host "  CSV exported: $csvPath" -ForegroundColor Gray
    }
    
    if ($Format -in @('JSON', 'Both')) {
        $jsonPath = Join-Path $OutputPath "$FileName-$timestamp.json"
        $Data | ConvertTo-Json -Depth 3 | Out-File -FilePath $jsonPath -Encoding UTF8
        Write-Host "  JSON exported: $jsonPath" -ForegroundColor Gray
    }
}

#endregion Functions

#region Initialization
# =============================================================================
# SCRIPT INITIALIZATION
# =============================================================================

Write-ProgressInfo "Azure AD License & Activity Report" "Green"
Write-ProgressInfo "==================================" "Green"

Write-ProgressInfo "`nConfiguration:"
Write-Host "  Activity Threshold: $ActivityThresholdDays days" -ForegroundColor White
Write-Host "  Include License Details: $IncludeLicenseDetails" -ForegroundColor White
Write-Host "  Export Format: $ExportFormat" -ForegroundColor White
if ($OutputPath) {
    Write-Host "  Output Directory: $OutputPath" -ForegroundColor White
}

# Check prerequisites
try {
    if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Users)) {
        throw "Microsoft.Graph.Users module is required. Install with: Install-Module Microsoft.Graph"
    }
    Write-Verbose "Prerequisites validated successfully"
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}

#endregion Initialization

#region Azure AD Connection
# =============================================================================
# CONNECT TO MICROSOFT GRAPH
# =============================================================================

Write-ProgressInfo "`nConnecting to Microsoft Graph..."

try {
    Import-Module Microsoft.Graph.Users -Force
    Import-Module Microsoft.Graph.Identity.DirectoryManagement -Force
    
    Connect-MgGraph -ClientId $ClientId -TenantId $TenantId -CertificateThumbprint $CertificateThumbprint -NoWelcome
    
    # Verify connection and get organization info
    $context = Get-MgContext
    $organization = Get-MgOrganization | Select-Object -First 1
    
    Write-ProgressInfo "Successfully connected to Microsoft Graph" "Green"
    Write-Host "  Organization: $($organization.DisplayName)" -ForegroundColor White
    Write-Host "  Tenant ID: $($context.TenantId)" -ForegroundColor White
}
catch {
    Write-Error "Failed to connect to Microsoft Graph: $($_.Exception.Message)"
    exit 1
}

#endregion Azure AD Connection

#region Data Collection
# =============================================================================
# COLLECT USER AND LICENSE DATA
# =============================================================================

Write-ProgressInfo "`nCollecting user and license data..."

try {
    # Retrieve user data with sign-in activity
    Write-Host "  Retrieving user data..." -ForegroundColor Gray
    $users = Get-MgUser -All -Property DisplayName, UserPrincipalName, AccountEnabled, SignInActivity, AssignedLicenses
    
    # Retrieve license information
    Write-Host "  Retrieving license data..." -ForegroundColor Gray
    $subscribedSkus = Get-MgSubscribedSku
    
    Write-ProgressInfo "Data collection completed:" "Green"
    Write-Host "  Total Users: $($users.Count)" -ForegroundColor White
    Write-Host "  License SKUs: $($subscribedSkus.Count)" -ForegroundColor White
}
catch {
    Write-Error "Failed to collect data: $($_.Exception.Message)"
    exit 1
}

#endregion Data Collection

#region Data Analysis
# =============================================================================
# ANALYZE USER ACTIVITY AND LICENSE DATA
# =============================================================================

Write-ProgressInfo "`nAnalyzing user activity and license utilization..."

# Process user activity data
$userActivityData = @()
$activityStats = @{
    TotalUsers = $users.Count
    EnabledUsers = 0
    UsersWithSignInData = 0
    ActiveUsers = 0
    InactiveUsers = 0
    NeverSignedIn = 0
}

foreach ($user in $users) {
    if ($user.AccountEnabled) {
        $activityStats.EnabledUsers++
    }
    
    $activityMetrics = Get-UserActivityMetrics -User $user -ThresholdDays $ActivityThresholdDays
    
    if ($null -ne $activityMetrics.MinDaysSinceSignIn) {
        $activityStats.UsersWithSignInData++
        
        if ($activityMetrics.IsActiveUser) {
            $activityStats.ActiveUsers++
        } else {
            $activityStats.InactiveUsers++
        }
    } else {
        $activityStats.NeverSignedIn++
    }
    
    # Create user activity record
    $userRecord = [PSCustomObject]@{
        DisplayName = $user.DisplayName
        UserPrincipalName = $user.UserPrincipalName
        AccountEnabled = $user.AccountEnabled
        LastSignInDateTime = $activityMetrics.LastSignInDateTime
        LastNonInteractiveSignInDateTime = $activityMetrics.LastNonInteractiveSignInDateTime
        DaysSinceLastSignIn = $activityMetrics.DaysSinceLastSignIn
        DaysSinceLastNonInteractiveSignIn = $activityMetrics.DaysSinceLastNonInteractiveSignIn
        MinDaysSinceSignIn = $activityMetrics.MinDaysSinceSignIn
        IsActiveUser = $activityMetrics.IsActiveUser
        LicenseCount = $user.AssignedLicenses.Count
        AssignedLicenses = ($user.AssignedLicenses.SkuId -join ';')
    }
    
    $userActivityData += $userRecord
}

# Process license data
$licenseData = @()
$totalLicenses = 0
$totalConsumed = 0
$totalAvailable = 0

foreach ($sku in $subscribedSkus) {
    $available = $sku.PrepaidUnits.Enabled - $sku.ConsumedUnits
    $utilizationPercent = if ($sku.PrepaidUnits.Enabled -gt 0) {
        [math]::Round(($sku.ConsumedUnits / $sku.PrepaidUnits.Enabled) * 100, 2)
    } else { 0 }
    
    $licenseRecord = [PSCustomObject]@{
        SkuPartNumber = $sku.SkuPartNumber
        ProductName = $sku.SkuPartNumber  # Could be enhanced with friendly names
        TotalLicenses = $sku.PrepaidUnits.Enabled
        ConsumedLicenses = $sku.ConsumedUnits
        AvailableLicenses = $available
        UtilizationPercent = $utilizationPercent
        CapabilityStatus = $sku.CapabilityStatus
    }
    
    $licenseData += $licenseRecord
    $totalLicenses += $sku.PrepaidUnits.Enabled
    $totalConsumed += $sku.ConsumedUnits
    $totalAvailable += $available
}

#endregion Data Analysis

#region Report Generation
# =============================================================================
# GENERATE AND DISPLAY REPORTS
# =============================================================================

Write-ProgressInfo "`n==================================" "Green"
Write-ProgressInfo "License & Activity Report" "Green"
Write-ProgressInfo "==================================" "Green"

# Organization Overview
Write-Host "`nOrganization: $($organization.DisplayName)" -ForegroundColor Cyan
Write-Host "Report Generated: $(Get-Date)" -ForegroundColor Gray
Write-Host "Activity Threshold: $ActivityThresholdDays days" -ForegroundColor Gray

# User Activity Summary
Write-Host "`nUser Activity Summary:" -ForegroundColor Cyan
Write-Host "  Total Users: $($activityStats.TotalUsers)" -ForegroundColor White
Write-Host "  Enabled Users: $($activityStats.EnabledUsers)" -ForegroundColor White
Write-Host "  Users with Sign-in Data: $($activityStats.UsersWithSignInData)" -ForegroundColor White
Write-Host "  Active Users (< $ActivityThresholdDays days): $($activityStats.ActiveUsers)" -ForegroundColor Green
Write-Host "  Inactive Users (≥ $ActivityThresholdDays days): $($activityStats.InactiveUsers)" -ForegroundColor Yellow
Write-Host "  Never Signed In: $($activityStats.NeverSignedIn)" -ForegroundColor Red

# License Summary
Write-Host "`nLicense Summary:" -ForegroundColor Cyan
Write-Host "  Total Licenses: $totalLicenses" -ForegroundColor White
Write-Host "  Consumed Licenses: $totalConsumed" -ForegroundColor White
Write-Host "  Available Licenses: $totalAvailable" -ForegroundColor White

$overallUtilization = if ($totalLicenses -gt 0) {
    [math]::Round(($totalConsumed / $totalLicenses) * 100, 2)
} else { 0 }
Write-Host "  Overall Utilization: $overallUtilization%" -ForegroundColor White

# License Details by SKU
if ($IncludeLicenseDetails -or $licenseData.Count -le 10) {
    Write-Host "`nLicense Details by SKU:" -ForegroundColor Cyan
    foreach ($license in ($licenseData | Sort-Object ConsumedLicenses -Descending)) {
        $statusColor = if ($license.UtilizationPercent -gt 90) { "Red" } 
                      elseif ($license.UtilizationPercent -gt 75) { "Yellow" } 
                      else { "Green" }
        
        Write-Host "  $($license.SkuPartNumber):" -ForegroundColor White
        Write-Host "    Total: $($license.TotalLicenses) | Consumed: $($license.ConsumedLicenses) | Available: $($license.AvailableLicenses) | Utilization: $($license.UtilizationPercent)%" -ForegroundColor $statusColor
    }
}

# Activity-Based License Insights
$licensedActiveUsers = $userActivityData | Where-Object { $_.LicenseCount -gt 0 -and $_.IsActiveUser }
$licensedInactiveUsers = $userActivityData | Where-Object { $_.LicenseCount -gt 0 -and -not $_.IsActiveUser }
$unlicensedActiveUsers = $userActivityData | Where-Object { $_.LicenseCount -eq 0 -and $_.IsActiveUser }

Write-Host "`nLicense Optimization Insights:" -ForegroundColor Cyan
Write-Host "  Licensed Active Users: $($licensedActiveUsers.Count)" -ForegroundColor Green
Write-Host "  Licensed Inactive Users: $($licensedInactiveUsers.Count)" -ForegroundColor Yellow
Write-Host "  Unlicensed Active Users: $($unlicensedActiveUsers.Count)" -ForegroundColor Red

if ($licensedInactiveUsers.Count -gt 0) {
    $potentialSavings = $licensedInactiveUsers.Count
    Write-Host "  Potential License Savings: $potentialSavings licenses" -ForegroundColor Yellow
}

# Top Inactive Licensed Users
if ($licensedInactiveUsers.Count -gt 0) {
    Write-Host "`nTop Inactive Licensed Users:" -ForegroundColor Yellow
    $topInactive = $licensedInactiveUsers | Sort-Object MinDaysSinceSignIn -Descending | Select-Object -First 10
    foreach ($user in $topInactive) {
        $daysSince = if ($null -ne $user.MinDaysSinceSignIn) { "$($user.MinDaysSinceSignIn) days" } else { "Never" }
        Write-Host "  $($user.UserPrincipalName) - Last activity: $daysSince ago" -ForegroundColor Gray
    }
}

#endregion Report Generation

#region Data Export
# =============================================================================
# EXPORT DETAILED DATA
# =============================================================================

if ($OutputPath) {
    Write-ProgressInfo "`nExporting detailed reports..."
    
    # Export user activity data
    Export-ReportData -Data $userActivityData -FileName "UserActivityReport" -OutputPath $OutputPath -Format $ExportFormat
    
    # Export license data
    Export-ReportData -Data $licenseData -FileName "LicenseUtilizationReport" -OutputPath $OutputPath -Format $ExportFormat
    
    # Export summary statistics
    $summaryReport = [PSCustomObject]@{
        OrganizationName = $organization.DisplayName
        ReportDate = Get-Date
        ActivityThresholdDays = $ActivityThresholdDays
        TotalUsers = $activityStats.TotalUsers
        EnabledUsers = $activityStats.EnabledUsers
        ActiveUsers = $activityStats.ActiveUsers
        InactiveUsers = $activityStats.InactiveUsers
        NeverSignedInUsers = $activityStats.NeverSignedIn
        TotalLicenses = $totalLicenses
        ConsumedLicenses = $totalConsumed
        AvailableLicenses = $totalAvailable
        OverallUtilizationPercent = $overallUtilization
        LicensedActiveUsers = $licensedActiveUsers.Count
        LicensedInactiveUsers = $licensedInactiveUsers.Count
        UnlicensedActiveUsers = $unlicensedActiveUsers.Count
        PotentialLicenseSavings = $licensedInactiveUsers.Count
    }
    
    Export-ReportData -Data $summaryReport -FileName "SummaryReport" -OutputPath $OutputPath -Format $ExportFormat
    
    Write-ProgressInfo "Reports exported successfully to: $OutputPath" "Green"
}

#endregion Data Export

#region Recommendations
# =============================================================================
# GENERATE RECOMMENDATIONS
# =============================================================================

Write-Host "`nRecommendations:" -ForegroundColor Cyan

if ($licensedInactiveUsers.Count -gt 0) {
    Write-Host "  • Review $($licensedInactiveUsers.Count) licensed but inactive users for potential license reclamation" -ForegroundColor Yellow
}

if ($unlicensedActiveUsers.Count -gt 0) {
    Write-Host "  • Consider licensing $($unlicensedActiveUsers.Count) active users who may need access to licensed services" -ForegroundColor Yellow
}

if ($overallUtilization -gt 90) {
    Write-Host "  • License utilization is high ($overallUtilization%) - consider procuring additional licenses" -ForegroundColor Red
}
elseif ($overallUtilization -lt 70) {
    Write-Host "  • License utilization is low ($overallUtilization%) - review license requirements" -ForegroundColor Green
}

$highUtilizationSkus = $licenseData | Where-Object { $_.UtilizationPercent -gt 90 }
if ($highUtilizationSkus) {
    Write-Host "  • High utilization SKUs requiring attention:" -ForegroundColor Red
    foreach ($sku in $highUtilizationSkus) {
        Write-Host "    - $($sku.SkuPartNumber): $($sku.UtilizationPercent)%" -ForegroundColor Red
    }
}

Write-Host "  • Regular monitoring recommended to optimize license costs and compliance" -ForegroundColor Green

#endregion Recommendations

#region Cleanup
# =============================================================================
# CLEANUP AND COMPLETION
# =============================================================================

try {
    Disconnect-MgGraph -ErrorAction SilentlyContinue
    Write-Verbose "Disconnected from Microsoft Graph"
}
catch {
    Write-Warning "Error disconnecting from Graph: $($_.Exception.Message)"
}

Write-ProgressInfo "`n==================================" "Green"
Write-ProgressInfo "Report generation completed successfully!" "Green"
Write-ProgressInfo "==================================" "Green"

#endregion Cleanup