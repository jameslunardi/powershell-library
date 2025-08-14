<#
.SYNOPSIS
    Analyzes Windows Security logs to identify unique user logons and their latest activity

.DESCRIPTION
    This script examines Windows Security Event Log (Event ID 4624 - successful logons) to create 
    a comprehensive report of user logon activity. It identifies unique usernames and tracks their 
    most recent logon times, providing valuable information for security auditing, compliance 
    reporting, and user activity monitoring.
    
    The script processes large volumes of security events efficiently and provides detailed 
    statistics about the analyzed timeframe and user activity patterns.

.PARAMETER ComputerName
    Target computer name to analyze. Default is local computer.

.PARAMETER MaxEvents
    Maximum number of events to process. Default is unlimited (all available events).

.PARAMETER StartTime
    Start time for event analysis. Only events after this time will be processed.

.PARAMETER EndTime
    End time for event analysis. Only events before this time will be processed.

.PARAMETER OutputPath
    Path to export results to CSV file. If not specified, results are displayed on console only.

.PARAMETER IncludeSystemAccounts
    Include system accounts (computer accounts, service accounts) in the analysis.

.PARAMETER ExcludeInteractiveOnly
    Exclude non-interactive logon types (service logons, network logons, etc.).

.EXAMPLE
    .\Get-UserLogonActivity.ps1
    Analyzes all available logon events on the local computer

.EXAMPLE
    .\Get-UserLogonActivity.ps1 -MaxEvents 10000 -OutputPath "C:\Reports\LogonActivity.csv"
    Analyzes the most recent 10,000 logon events and exports to CSV

.EXAMPLE
    .\Get-UserLogonActivity.ps1 -StartTime (Get-Date).AddDays(-7) -ExcludeInteractiveOnly
    Analyzes only interactive logons from the past 7 days

.EXAMPLE
    .\Get-UserLogonActivity.ps1 -ComputerName "SERVER01" -IncludeSystemAccounts -OutputPath "C:\Audit\SERVER01-Logons.csv"
    Analyzes logons on remote server including system accounts and exports results

.NOTES
    Author: James Lunardi
    Version: 1.0
    
    Prerequisites:
    - Administrative privileges to read Security event log
    - Security auditing enabled on target system
    - Appropriate network permissions for remote computer analysis
    
    Event ID 4624 Details:
    - Represents successful logon events
    - Property[5] contains the account name
    - Various logon types indicate different authentication scenarios
    
.LINK
    https://github.com/jameslunardi/powershell-library
    https://www.linkedin.com/in/jameslunardi/
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ComputerName = $env:COMPUTERNAME,
    
    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 1000000)]
    [int]$MaxEvents,
    
    [Parameter(Mandatory = $false)]
    [datetime]$StartTime,
    
    [Parameter(Mandatory = $false)]
    [datetime]$EndTime,
    
    [Parameter(Mandatory = $false)]
    [ValidateScript({
        $directory = Split-Path $_
        if ($directory -and -not (Test-Path $directory)) {
            New-Item -Path $directory -ItemType Directory -Force | Out-Null
        }
        return $true
    })]
    [string]$OutputPath,
    
    [Parameter(Mandatory = $false)]
    [switch]$IncludeSystemAccounts,
    
    [Parameter(Mandatory = $false)]
    [switch]$ExcludeInteractiveOnly
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

function Test-EventLogAccess {
    param([string]$ComputerName)
    
    try {
        Write-Verbose "Testing Security event log access on $ComputerName..."
        $testEvent = Get-WinEvent -ComputerName $ComputerName -LogName Security -MaxEvents 1 -ErrorAction Stop
        Write-Verbose "Successfully accessed Security event log"
        return $true
    }
    catch [System.UnauthorizedAccessException] {
        Write-Error "Access denied to Security event log on $ComputerName. Administrator privileges required."
        return $false
    }
    catch [System.Exception] {
        Write-Error "Failed to access Security event log on $ComputerName`: $($_.Exception.Message)"
        return $false
    }
}

function Get-LogonTypeDescription {
    param([int]$LogonType)
    
    switch ($LogonType) {
        2 { return "Interactive" }
        3 { return "Network" }
        4 { return "Batch" }
        5 { return "Service" }
        7 { return "Unlock" }
        8 { return "NetworkCleartext" }
        9 { return "NewCredentials" }
        10 { return "RemoteInteractive" }
        11 { return "CachedInteractive" }
        default { return "Unknown($LogonType)" }
    }
}

function Test-SystemAccount {
    param([string]$AccountName)
    
    # Common patterns for system accounts
    $systemPatterns = @(
        '^SYSTEM$',
        '^ANONYMOUS LOGON$',
        '^LOCAL SERVICE$',
        '^NETWORK SERVICE$',
        '^\w+\$$',  # Computer accounts end with $
        '^DWM-\d+$', # Desktop Window Manager
        '^UMFD-\d+$' # User Mode Font Driver
    )
    
    foreach ($pattern in $systemPatterns) {
        if ($AccountName -match $pattern) {
            return $true
        }
    }
    
    return $false
}

#endregion Functions

#region Initialization
# =============================================================================
# SCRIPT INITIALIZATION AND VALIDATION
# =============================================================================

Write-ProgressInfo "User Logon Activity Analysis" "Green"
Write-ProgressInfo "=============================" "Green"

# Configuration display
Write-ProgressInfo "`nConfiguration:"
Write-Host "  Target Computer: $ComputerName" -ForegroundColor White
Write-Host "  Max Events: $(if ($MaxEvents) { $MaxEvents } else { 'Unlimited' })" -ForegroundColor White
Write-Host "  Include System Accounts: $IncludeSystemAccounts" -ForegroundColor White
Write-Host "  Interactive Only: $(-not $ExcludeInteractiveOnly)" -ForegroundColor White

if ($StartTime) {
    Write-Host "  Start Time: $StartTime" -ForegroundColor White
}
if ($EndTime) {
    Write-Host "  End Time: $EndTime" -ForegroundColor White
}
if ($OutputPath) {
    Write-Host "  Output File: $OutputPath" -ForegroundColor White
}

# Validate time range
if ($StartTime -and $EndTime -and $StartTime -gt $EndTime) {
    Write-Error "Start time cannot be later than end time"
    exit 1
}

# Test event log access
if (-not (Test-EventLogAccess -ComputerName $ComputerName)) {
    exit 1
}

#endregion Initialization

#region Event Retrieval
# =============================================================================
# RETRIEVE SECURITY EVENTS
# =============================================================================

Write-ProgressInfo "`nRetrieving Security events (Event ID 4624)..."

# Build filter hashtable
$filterHashtable = @{
    LogName = 'Security'
    Id = 4624
}

if ($StartTime) {
    $filterHashtable['StartTime'] = $StartTime
}
if ($EndTime) {
    $filterHashtable['EndTime'] = $EndTime
}

# Build Get-WinEvent parameters
$eventParams = @{
    FilterHashtable = $filterHashtable
    ErrorAction = 'SilentlyContinue'
}

if ($ComputerName -ne $env:COMPUTERNAME) {
    $eventParams['ComputerName'] = $ComputerName
}

if ($MaxEvents) {
    $eventParams['MaxEvents'] = $MaxEvents
}

try {
    Write-Verbose "Executing Get-WinEvent with parameters: $($eventParams | ConvertTo-Json -Compress)"
    $events = Get-WinEvent @eventParams
    
    if (-not $events) {
        Write-Warning "No logon events (4624) found matching the specified criteria"
        exit 0
    }
    
    Write-ProgressInfo "Retrieved $($events.Count) logon events for analysis" "Green"
}
catch {
    Write-Error "Failed to retrieve events: $($_.Exception.Message)"
    exit 1
}

#endregion Event Retrieval

#region Event Processing
# =============================================================================
# PROCESS EVENTS AND EXTRACT USER ACTIVITY
# =============================================================================

Write-ProgressInfo "`nProcessing logon events..."

# Initialize tracking variables
$userActivity = @{}
$logonTypeStats = @{}
$oldestEventDate = [datetime]::MaxValue
$newestEventDate = [datetime]::MinValue
$processedEvents = 0
$filteredEvents = 0

# Process each event
foreach ($event in $events) {
    $processedEvents++
    
    # Show progress for large datasets
    if ($processedEvents % 1000 -eq 0) {
        Write-Progress -Activity "Processing Events" -Status "Processed $processedEvents of $($events.Count)" -PercentComplete (($processedEvents / $events.Count) * 100)
    }
    
    try {
        # Extract event properties
        $accountName = $event.Properties[5].Value
        $logonType = $event.Properties[8].Value
        $eventDate = $event.TimeCreated
        
        # Track date range
        if ($eventDate -lt $oldestEventDate) {
            $oldestEventDate = $eventDate
        }
        if ($eventDate -gt $newestEventDate) {
            $newestEventDate = $eventDate
        }
        
        # Filter system accounts if requested
        if (-not $IncludeSystemAccounts -and (Test-SystemAccount -AccountName $accountName)) {
            continue
        }
        
        # Filter non-interactive logons if requested
        if ($ExcludeInteractiveOnly -and $logonType -notin @(2, 10, 11)) { # Interactive, RemoteInteractive, CachedInteractive
            continue
        }
        
        $filteredEvents++
        
        # Track logon type statistics
        $logonTypeDesc = Get-LogonTypeDescription -LogonType $logonType
        if ($logonTypeStats.ContainsKey($logonTypeDesc)) {
            $logonTypeStats[$logonTypeDesc]++
        }
        else {
            $logonTypeStats[$logonTypeDesc] = 1
        }
        
        # Update user activity tracking
        if ($userActivity.ContainsKey($accountName)) {
            # Update if this is a more recent logon
            if ($eventDate -gt $userActivity[$accountName].LatestLogon) {
                $userActivity[$accountName].LatestLogon = $eventDate
                $userActivity[$accountName].LatestLogonType = $logonTypeDesc
            }
            
            # Update first seen if this is older
            if ($eventDate -lt $userActivity[$accountName].FirstSeen) {
                $userActivity[$accountName].FirstSeen = $eventDate
            }
            
            $userActivity[$accountName].TotalLogons++
        }
        else {
            # First time seeing this user
            $userActivity[$accountName] = [PSCustomObject]@{
                AccountName = $accountName
                FirstSeen = $eventDate
                LatestLogon = $eventDate
                LatestLogonType = $logonTypeDesc
                TotalLogons = 1
            }
        }
    }
    catch {
        Write-Warning "Error processing event at index $processedEvents`: $($_.Exception.Message)"
        continue
    }
}

Write-Progress -Activity "Processing Events" -Completed

Write-ProgressInfo "Event processing completed:" "Green"
Write-Host "  Total Events Retrieved: $($events.Count)" -ForegroundColor White
Write-Host "  Events After Filtering: $filteredEvents" -ForegroundColor White
Write-Host "  Unique Users Found: $($userActivity.Count)" -ForegroundColor White

#endregion Event Processing

#region Results Analysis
# =============================================================================
# ANALYZE AND DISPLAY RESULTS
# =============================================================================

Write-ProgressInfo "`nAnalysis Results:" "Green"
Write-ProgressInfo "=================" "Green"

# Display time range analysis
if ($oldestEventDate -ne [datetime]::MaxValue) {
    Write-Host "`nTime Range Analysis:" -ForegroundColor Cyan
    Write-Host "  Oldest Event: $oldestEventDate" -ForegroundColor White
    Write-Host "  Newest Event: $newestEventDate" -ForegroundColor White
    Write-Host "  Analysis Span: $([math]::Round(($newestEventDate - $oldestEventDate).TotalDays, 1)) days" -ForegroundColor White
}

# Display logon type statistics
if ($logonTypeStats.Count -gt 0) {
    Write-Host "`nLogon Type Statistics:" -ForegroundColor Cyan
    foreach ($logonType in ($logonTypeStats.GetEnumerator() | Sort-Object Value -Descending)) {
        Write-Host "  $($logonType.Key): $($logonType.Value)" -ForegroundColor White
    }
}

# Prepare results for display and export
$results = $userActivity.Values | Sort-Object LatestLogon -Descending

# Display top recent logons
Write-Host "`nMost Recent User Logons:" -ForegroundColor Cyan
$topResults = $results | Select-Object -First 10
foreach ($user in $topResults) {
    Write-Host "  $($user.AccountName) - Latest: $($user.LatestLogon) ($($user.LatestLogonType)) - Total: $($user.TotalLogons)" -ForegroundColor White
}

if ($results.Count -gt 10) {
    Write-Host "  ... and $($results.Count - 10) more users" -ForegroundColor Gray
}

# Display users not seen recently (potential inactive accounts)
$recentThreshold = (Get-Date).AddDays(-30)
$staleUsers = $results | Where-Object { $_.LatestLogon -lt $recentThreshold }

if ($staleUsers) {
    Write-Host "`nUsers Not Seen in Last 30 Days: $($staleUsers.Count)" -ForegroundColor Yellow
    $oldestStale = $staleUsers | Select-Object -First 5
    foreach ($user in $oldestStale) {
        Write-Host "  $($user.AccountName) - Last Seen: $($user.LatestLogon)" -ForegroundColor Yellow
    }
    
    if ($staleUsers.Count -gt 5) {
        Write-Host "  ... and $($staleUsers.Count - 5) more stale accounts" -ForegroundColor Gray
    }
}

#endregion Results Analysis

#region Export Results
# =============================================================================
# EXPORT RESULTS TO CSV IF REQUESTED
# =============================================================================

if ($OutputPath) {
    Write-ProgressInfo "`nExporting results to CSV..."
    
    try {
        # Prepare export data with additional computed properties
        $exportData = $results | Select-Object @(
            @{Name = "AccountName"; Expression = { $_.AccountName }},
            @{Name = "LatestLogon"; Expression = { $_.LatestLogon }},
            @{Name = "LatestLogonType"; Expression = { $_.LatestLogonType }},
            @{Name = "FirstSeen"; Expression = { $_.FirstSeen }},
            @{Name = "TotalLogons"; Expression = { $_.TotalLogons }},
            @{Name = "DaysSinceLastLogon"; Expression = { [math]::Round(((Get-Date) - $_.LatestLogon).TotalDays, 1) }},
            @{Name = "IsSystemAccount"; Expression = { Test-SystemAccount -AccountName $_.AccountName }},
            @{Name = "ActivitySpan"; Expression = { [math]::Round(($_.LatestLogon - $_.FirstSeen).TotalDays, 1) }}
        )
        
        $exportData | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
        
        $fileSize = (Get-Item $OutputPath).Length / 1KB
        Write-ProgressInfo "Results exported successfully:" "Green"
        Write-Host "  File: $OutputPath" -ForegroundColor White
        Write-Host "  Records: $($exportData.Count)" -ForegroundColor White
        Write-Host "  File Size: $($fileSize.ToString('F2')) KB" -ForegroundColor White
    }
    catch {
        Write-Error "Failed to export results: $($_.Exception.Message)"
    }
}

#endregion Export Results

#region Summary
# =============================================================================
# FINAL SUMMARY AND RECOMMENDATIONS
# =============================================================================

Write-ProgressInfo "`n=============================" "Green"
Write-ProgressInfo "Analysis Summary" "Green"
Write-ProgressInfo "=============================" "Green"

Write-Host "`nKey Findings:" -ForegroundColor Cyan
Write-Host "  • Analyzed $($events.Count) logon events" -ForegroundColor White
Write-Host "  • Identified $($userActivity.Count) unique user accounts" -ForegroundColor White
Write-Host "  • Time span: $(if ($oldestEventDate -ne [datetime]::MaxValue) { [math]::Round(($newestEventDate - $oldestEventDate).TotalDays, 1) } else { 'N/A' }) days" -ForegroundColor White

if ($staleUsers) {
    Write-Host "  • Found $($staleUsers.Count) accounts inactive for 30+ days" -ForegroundColor Yellow
}

$recentUsers = $results | Where-Object { $_.LatestLogon -gt (Get-Date).AddDays(-7) }
Write-Host "  • $($recentUsers.Count) accounts active in last 7 days" -ForegroundColor White

# Security recommendations
Write-Host "`nSecurity Recommendations:" -ForegroundColor Cyan
if ($staleUsers.Count -gt 0) {
    Write-Host "  • Review inactive accounts for potential disabling" -ForegroundColor Yellow
}
Write-Host "  • Monitor accounts with unusual logon patterns" -ForegroundColor White
Write-Host "  • Regular auditing of logon activity recommended" -ForegroundColor White

Write-ProgressInfo "`nLogon activity analysis completed successfully!" "Green"

#endregion Summary