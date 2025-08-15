<#
.SYNOPSIS
    Active Directory User Synchronisation - Main Orchestrator Script

.DESCRIPTION
    This script synchronises user accounts between two Active Directory domains (Source and Target).
    It compares users from both domains and performs add, update, and remove operations as needed.
    
    The script includes safety thresholds to prevent mass deletions and provides comprehensive
    logging and email alerting capabilities.

.PARAMETER ReportOnly
    When set to $true, runs in report-only mode without making actual changes.
    Default: $true (safety first)

.EXAMPLE
    .\Start-ADSync.ps1
    Runs the sync in report-only mode (default)

.EXAMPLE  
    .\Start-ADSync.ps1 -ReportOnly $false
    Runs the sync with actual changes (after editing the functions to set ReportOnly = $false)

.NOTES
    Author: James Lunardi
    Version: 1.3
    
    Prerequisites:
    - ActiveDirectory PowerShell module
    - Appropriate permissions on both domains
    - Service account credentials configured
    - SMTP relay for email notifications
    
    Safety Features:
    - Deletion threshold: Maximum 45 users
    - Addition threshold: Maximum 300 users  
    - Update threshold: Maximum 300 changes
    - Email alerts on errors
    - Comprehensive logging

.LINK
    https://github.com/jameslunardi/powershell-library
    https://www.linkedin.com/in/jameslunardi/
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [bool]$ReportOnly = $true
)

#region Configuration
# =============================================================================
# CONFIGURATION SECTION - Loaded from config.json
# =============================================================================

# Load configuration helper and get configuration
. "$PSScriptRoot\config_helper.ps1"
$Config = Get-ADSyncConfig

# Validate and create directories
Test-ADSyncDirectories -Config $Config

# Import Required Functions
. "$($Config.General.ScriptRoot)\Remove-ProdUser.ps1"
. "$($Config.General.ScriptRoot)\Add-ProdUser.ps1"
. "$($Config.General.ScriptRoot)\Update-ProdUser.ps1"
. "$($Config.General.ScriptRoot)\General-Functions.ps1"

# Safety Thresholds from configuration
$DeletionThreshold = $Config.SafetyThresholds.DeletionThreshold
$AdditionThreshold = $Config.SafetyThresholds.AdditionThreshold
$UpdateThreshold = $Config.SafetyThresholds.UpdateThreshold

#endregion Configuration

#region Initialisation
# =============================================================================
# SCRIPT INITIALISATION
# =============================================================================

# Setup logging
$LogTime = Get-Date -Format "MM-dd-yyyy_HH"
$LogName = "ADSync-$LogTime-log.txt"
$TranscriptPath = "$($Config.General.LogPath)\transcript-$LogTime.log"

# Start transcript logging
Start-Transcript -Path $TranscriptPath -Append

Write-Host "===============================================" -ForegroundColor Green
Write-Host "Active Directory Sync Started: $(Get-Date)" -ForegroundColor Green
Write-Host "Report Only Mode: $ReportOnly" -ForegroundColor Green  
Write-Host "===============================================" -ForegroundColor Green

#endregion Initialisation

#region Data Collection
# =============================================================================
# DATA COLLECTION AND COMPARISON
# =============================================================================

Write-Host "`nCollecting user data from both domains..." -ForegroundColor Cyan

try {
    $SourceUsers = Export-SourceUsers -Config $Config
    $TargetUsers = Export-ProdUsers -Config $Config
    
    Write-Host "Number of users found in Source Domain: $($SourceUsers.count)" -ForegroundColor Yellow
    Write-Host "Number of users found in Target Domain: $($TargetUsers.count)" -ForegroundColor Yellow
}
catch {
    $ErrorMessage = "Failed to collect user data: $($_.Exception.Message)"
    Write-Error $ErrorMessage
    Send-Email -Message $ErrorMessage -Subject "ADSync - Data Collection Error" -Config $Config
    Stop-Transcript
    exit 1
}

# Initialize collections for processing
$SourceMatchedUsers = [System.Collections.ArrayList]@()
$TargetMatchedUsers = [System.Collections.ArrayList]@()
$UsersToAdd = [System.Collections.ArrayList]@()
$UsersToRemove = [System.Collections.ArrayList]@()
$UsersToUpdate = [System.Collections.ArrayList]@()
$ExpiredUsers = [System.Collections.ArrayList]@()
$InactiveUsers = [System.Collections.ArrayList]@()

#endregion Data Collection

#region User Comparison and Matching
# =============================================================================
# COMPARE USERS AND IDENTIFY REQUIRED ACTIONS
# =============================================================================

Write-Host "`nComparing Source users with Target users..." -ForegroundColor Cyan
Write-Host "Creating lists of matched users and missing users..." -ForegroundColor Gray

# Compare Source users with Target users to find matches and additions needed
foreach ($SourceUser in $SourceUsers) {
    # Check if Source user exists in Target domain
    $MatchIndex = [array]::IndexOf($TargetUsers.EmployeeID, $SourceUser.EmployeeID)
    
    if ($MatchIndex -ne -1) {
        # User exists in both domains - add to matched collections
        $TargetMatchedUsers += $TargetUsers[$MatchIndex]
        $MatchCount = $TargetMatchedUsers.count - 1
        $SourceUser | Add-Member -NotePropertyName Match -NotePropertyValue $MatchCount
        $SourceMatchedUsers += $SourceUser
    }
    else {
        # User exists in Source but not Target - needs to be added
        $UsersToAdd += $SourceUser
    }
}

Write-Host "Matched users found: $($SourceMatchedUsers.count)" -ForegroundColor Green
Write-Host "Users to add: $($UsersToAdd.count)" -ForegroundColor Yellow

#endregion User Comparison and Matching

#region Attribute Comparison
# =============================================================================
# CHECK MATCHED USERS FOR ATTRIBUTE UPDATES
# =============================================================================

Write-Host "`nChecking matched users for required attribute updates..." -ForegroundColor Cyan

foreach ($User in $SourceMatchedUsers) {
    $MatchedTargetUser = $TargetMatchedUsers[$User.Match]
    
    # Define attributes to check and compare
    $AttributesToCheck = @(
        @{Name = "mail"; SourceValue = $User.mail; TargetValue = $MatchedTargetUser.mail},
        @{Name = "GivenName"; SourceValue = $User.GivenName; TargetValue = $MatchedTargetUser.GivenName},
        @{Name = "Surname"; SourceValue = $User.Surname; TargetValue = $MatchedTargetUser.Surname},
        @{Name = "Title"; SourceValue = $User.Title; TargetValue = $MatchedTargetUser.Title},
        @{Name = "Office"; SourceValue = $User.Office; TargetValue = $MatchedTargetUser.Office},
        @{Name = "Department"; SourceValue = $User.Department; TargetValue = $MatchedTargetUser.Department},
        @{Name = "l"; SourceValue = $User.l; TargetValue = $MatchedTargetUser.l},
        @{Name = "AccountExpirationDate"; SourceValue = $User.AccountExpirationDate; TargetValue = $MatchedTargetUser.AccountExpirationDate},
        @{Name = "msDS-cloudExtensionAttribute1"; SourceValue = $User.'msDS-cloudExtensionAttribute1'; TargetValue = $MatchedTargetUser.'msDS-cloudExtensionAttribute1'},
        @{Name = "msDS-cloudExtensionAttribute2"; SourceValue = $User.'msDS-cloudExtensionAttribute2'; TargetValue = $MatchedTargetUser.'msDS-cloudExtensionAttribute2'},
        @{Name = "msDS-cloudExtensionAttribute3"; SourceValue = $User.'msDS-cloudExtensionAttribute3'; TargetValue = $MatchedTargetUser.'msDS-cloudExtensionAttribute3'},
        @{Name = "msDS-cloudExtensionAttribute6"; SourceValue = $User.'msDS-cloudExtensionAttribute6'; TargetValue = $MatchedTargetUser.'msDS-cloudExtensionAttribute6'},
        @{Name = "msDS-cloudExtensionAttribute7"; SourceValue = $User.'msDS-cloudExtensionAttribute7'; TargetValue = $MatchedTargetUser.'msDS-cloudExtensionAttribute7'},
        @{Name = "msDS-cloudExtensionAttribute10"; SourceValue = $User.'msDS-cloudExtensionAttribute10'; TargetValue = $MatchedTargetUser.'msDS-cloudExtensionAttribute10'},
        @{Name = "msDS-cloudExtensionAttribute11"; SourceValue = $User.'msDS-cloudExtensionAttribute11'; TargetValue = $MatchedTargetUser.'msDS-cloudExtensionAttribute11'}
    )
    
    # Check each attribute for differences
    foreach ($Attribute in $AttributesToCheck) {
        if ($Attribute.SourceValue -ne $Attribute.TargetValue) {
            $UsersToUpdate += [PSCustomObject]@{
                DistinguishedName = $MatchedTargetUser.DistinguishedName
                SamAccountName = $MatchedTargetUser.SamAccountName
                Attribute = $Attribute.Name
                NewValue = $Attribute.SourceValue
                OldValue = $Attribute.TargetValue
            }
        }
    }
    
    # Special check for Enabled status (only disable, not enable)
    if (($User.Enabled -ne $MatchedTargetUser.Enabled) -and ($User.Enabled -eq $false)) {
        $UsersToUpdate += [PSCustomObject]@{
            DistinguishedName = $MatchedTargetUser.DistinguishedName
            SamAccountName = $MatchedTargetUser.SamAccountName
            Attribute = "Enabled"
            NewValue = $User.Enabled
            OldValue = $MatchedTargetUser.Enabled
        }
    }
    
    # Check if user has moved to Leavers OU in Source
    if (($User.DistinguishedName -like "*Leavers*") -and ($MatchedTargetUser.DistinguishedName -notlike "*Leavers*")) {
        $UsersToUpdate += [PSCustomObject]@{
            DistinguishedName = $MatchedTargetUser.DistinguishedName
            SamAccountName = $MatchedTargetUser.SamAccountName
            Attribute = "DistinguishedName"
            NewValue = $Config.TargetDomain.LeaversOU
            OldValue = $MatchedTargetUser.DistinguishedName
        }
    }
}

Write-Host "Attribute updates required: $($UsersToUpdate.count)" -ForegroundColor Yellow

#endregion Attribute Comparison

#region Removal Identification
# =============================================================================
# IDENTIFY USERS FOR REMOVAL
# =============================================================================

Write-Host "`nIdentifying Target users that no longer exist in Source..." -ForegroundColor Cyan

# Compare Target users with Source users to find removals needed
foreach ($TargetUser in $TargetUsers) {
    # Check if Target user exists in Source domain
    $MatchIndex = [array]::IndexOf($SourceUsers.EmployeeID, $TargetUser.EmployeeID)
    
    if ($MatchIndex -eq -1) {
        # User exists in Target but not Source - check if it should be removed
        if ($TargetUser.'msDS-cloudExtensionAttribute10' -ne "1") {
            # Not marked as exempt from removal
            $UsersToRemove += $TargetUser
        }
        else {
            Write-Host "User $($TargetUser.SamAccountName) marked as exempt from removal (CloudExtension10 = 1)" -ForegroundColor Gray
        }
    }
}

Write-Host "Users to remove: $($UsersToRemove.count)" -ForegroundColor Yellow

#endregion Removal Identification

#region Expired Account Check
# =============================================================================
# FIND EXPIRED ACCOUNTS
# =============================================================================

Write-Host "`nChecking for expired Target accounts outside Leavers OU..." -ForegroundColor Cyan

try {
    $ExpiredTargetUsers = Search-ADAccount -AccountExpired | 
        Where-Object { $_.DistinguishedName -notlike "*$($Config.TargetDomain.LeaversOU)" }
    
    foreach ($ExpiredAccount in $ExpiredTargetUsers) {
        $ExpiredUsers += [PSCustomObject]@{
            DistinguishedName = $ExpiredAccount.DistinguishedName
            SamAccountName = $ExpiredAccount.SamAccountName
            Attribute = "Enabled"
            NewValue = $false
            OldValue = $true
        }
    }
    
    Write-Host "Expired accounts found: $($ExpiredUsers.count)" -ForegroundColor Yellow
}
catch {
    Write-Warning "Failed to check for expired accounts: $($_.Exception.Message)"
}

#endregion Expired Account Check

#region Processing Updates
# =============================================================================
# PROCESS USER UPDATES
# =============================================================================

if ($UsersToUpdate) {
    Write-Host "`nProcessing required user updates..." -ForegroundColor Cyan
    
    # Export update data for logging
    $UpdateDataLogName = "Update-Data-$LogName"
    $UpdateDataPath = "$($Config.General.LogPath)\$UpdateDataLogName"
    $UsersToUpdate | Export-Csv -Path $UpdateDataPath -Append -NoClobber -NoTypeInformation -Encoding UTF8 -Delimiter ";" -Force
    
    # Process updates
    $UpdateLogName = "Update-Results-$LogName"
    $UpdateLogPath = "$($Config.General.LogPath)\$UpdateLogName"
    $UpdateFailure = $false
    
    try {
        $UpdateResults = Update-ProdUser -Data $UsersToUpdate -ReportOnly $ReportOnly -Config $Config -Verbose
        $UpdateResults | Export-Csv -Path $UpdateLogPath -Append -NoClobber -NoTypeInformation -Encoding UTF8 -Delimiter ";" -Force
    }
    catch {
        $UpdateFailure = $true
        Write-Warning "Update process failed: $($Error[0].FullyQualifiedErrorId)"
    }
    finally {
        if ($UpdateFailure) {
            $Message = "Update process failed: $($Error[0].FullyQualifiedErrorId)"
            $Subject = "ADSync - Error in Update Users Module"
            Send-Email -Message $Message -Subject $Subject -Config $Config
        }
    }
    
    # Check for individual update failures
    $UpdateErrors = $UpdateResults | Where-Object { $_.Success -eq $false }
    if ($UpdateErrors) {
        $Subject = "ADSync - Error in Update Users Module"
        $Message = "There were errors processing the following updates:`r`n"
        
        foreach ($Result in $UpdateErrors) {
            $Message += "$($Result.DistinguishedName) - $($Result.Success) - $($Result.Result)`r`n"
        }
        
        Send-Email -Message $Message -Subject $Subject
    }
    
    $SuccessfulUpdates = ($UpdateResults | Where-Object { $_.Success -eq $true }).Count
    Write-Host "Updates completed successfully: $SuccessfulUpdates" -ForegroundColor Green
    Write-Host "Updates failed: $($UpdateErrors.Count)" -ForegroundColor Red
}
else {
    Write-Host "`nNo user updates required." -ForegroundColor Green
}

#endregion Processing Updates

#region Processing Additions
# =============================================================================
# PROCESS USER ADDITIONS
# =============================================================================

if ($UsersToAdd) {
    Write-Host "`nProcessing new user additions..." -ForegroundColor Cyan
    
    # Export addition data for logging
    $AddDataLogName = "Add-Data-$LogName"
    $AddDataPath = "$($Config.General.LogPath)\$AddDataLogName"
    $UsersToAdd | Export-Csv -Path $AddDataPath -Append -NoClobber -NoTypeInformation -Encoding UTF8 -Delimiter ";" -Force
    
    # Process additions
    $AddLogName = "Add-Results-$LogName"
    $AddLogPath = "$($Config.General.LogPath)\$AddLogName"
    $AddFailure = $false
    
    try {
        $AddResults = Add-ProdUser -Data $UsersToAdd -ReportOnly $ReportOnly -Config $Config -Verbose
        $AddResults | Export-Csv -Path $AddLogPath -Append -NoClobber -NoTypeInformation -Encoding UTF8 -Delimiter ";" -Force
    }
    catch {
        $AddFailure = $true
        Write-Warning "Add process failed: $($Error[0].FullyQualifiedErrorId)"
    }
    finally {
        if ($AddFailure) {
            $Message = "Add process failed: $($Error[0].FullyQualifiedErrorId)"
            $Subject = "ADSync - Error in Add Users Module"
            Send-Email -Message $Message -Subject $Subject -Config $Config
        }
    }
    
    # Check for individual addition failures
    $AddErrors = $AddResults | Where-Object { $_.Success -eq $false }
    if ($AddErrors) {
        $Subject = "ADSync - Error in Add Users Module"
        $Message = "There were errors processing the following new accounts:`r`n"
        
        foreach ($Result in $AddErrors) {
            $Message += "$($Result.SamAccountName) - $($Result.Success) - $($Result.Result)`r`n"
        }
        
        Send-Email -Message $Message -Subject $Subject
    }
    
    $SuccessfulAdds = ($AddResults | Where-Object { $_.Success -eq $true }).Count
    Write-Host "Users added successfully: $SuccessfulAdds" -ForegroundColor Green
    Write-Host "User additions failed: $($AddErrors.Count)" -ForegroundColor Red
}
else {
    Write-Host "`nNo new users to create." -ForegroundColor Green
}

#endregion Processing Additions

#region Processing Removals
# =============================================================================
# PROCESS USER REMOVALS
# =============================================================================

if ($UsersToRemove) {
    Write-Host "`nProcessing user removals..." -ForegroundColor Cyan
    
    # Export removal data for logging
    $RemoveDataLogName = "Remove-Data-$LogName"
    $RemoveDataPath = "$($Config.General.LogPath)\$RemoveDataLogName"
    $UsersToRemove | Export-Csv -Path $RemoveDataPath -Append -NoClobber -NoTypeInformation -Encoding UTF8 -Delimiter ";" -Force
    
    # Process removals
    $RemoveLogName = "Remove-Results-$LogName"
    $RemoveLogPath = "$($Config.General.LogPath)\$RemoveLogName"
    $RemoveFailure = $false
    
    try {
        $RemoveResults = Remove-ProdUser -Data $UsersToRemove -ReportOnly $ReportOnly -Config $Config -Verbose
        $RemoveResults | Export-Csv -Path $RemoveLogPath -Append -NoClobber -NoTypeInformation -Encoding UTF8 -Delimiter ";" -Force
    }
    catch {
        $RemoveFailure = $true
        Write-Warning "Remove process failed: $($Error[0].FullyQualifiedErrorId)"
    }
    finally {
        if ($RemoveFailure) {
            $Message = "Remove process failed: $($Error[0].FullyQualifiedErrorId)"
            $Subject = "ADSync - Error in Remove Users Module"
            Send-Email -Message $Message -Subject $Subject -Config $Config
        }
    }
    
    # Check for individual removal failures
    $RemoveErrors = $RemoveResults | Where-Object { $_.Success -eq $false }
    if ($RemoveErrors) {
        $Subject = "ADSync - Error in Remove Users Module"
        $Message = "There were errors processing the following removals:`r`n"
        
        foreach ($Result in $RemoveErrors) {
            $Message += "$($Result.SamAccountName) - $($Result.Success) - $($Result.Result)`r`n"
        }
        
        Send-Email -Message $Message -Subject $Subject
    }
    
    $SuccessfulRemovals = ($RemoveResults | Where-Object { $_.Success -eq $true }).Count
    Write-Host "Users removed successfully: $SuccessfulRemovals" -ForegroundColor Green
    Write-Host "User removals failed: $($RemoveErrors.Count)" -ForegroundColor Red
}
else {
    Write-Host "`nNo users to remove." -ForegroundColor Green
}

#endregion Processing Removals

#region Processing Expired Users
# =============================================================================
# PROCESS EXPIRED USERS (Future Enhancement)
# =============================================================================

if ($ExpiredUsers) {
    Write-Host "`nExpired users identified but processing not yet implemented." -ForegroundColor Yellow
    Write-Host "Count: $($ExpiredUsers.Count)" -ForegroundColor Yellow
}
else {
    Write-Host "`nNo expired users to process." -ForegroundColor Green
}

#endregion Processing Expired Users

#region Summary and Cleanup
# =============================================================================
# SUMMARY AND CLEANUP
# =============================================================================

Write-Host "`n===============================================" -ForegroundColor Green
Write-Host "Active Directory Sync Completed: $(Get-Date)" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green

Write-Host "`nSummary:" -ForegroundColor Cyan
Write-Host "- Source Users: $($SourceUsers.Count)" -ForegroundColor White
Write-Host "- Target Users: $($TargetUsers.Count)" -ForegroundColor White
Write-Host "- Users Added: $($UsersToAdd.Count)" -ForegroundColor White
Write-Host "- Users Updated: $($UsersToUpdate.Count)" -ForegroundColor White
Write-Host "- Users Removed: $($UsersToRemove.Count)" -ForegroundColor White
Write-Host "- Report Only Mode: $ReportOnly" -ForegroundColor White

Stop-Transcript

#endregion Summary and Cleanup