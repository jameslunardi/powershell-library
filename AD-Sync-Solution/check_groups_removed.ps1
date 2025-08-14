<#
.SYNOPSIS
    Checks and cleans up group memberships for quarantined users

.DESCRIPTION
    This maintenance script checks all users in the quarantine OU for remaining group memberships
    and optionally removes them. This is useful for ensuring that quarantined users don't retain
    access through group memberships that weren't properly cleaned up during the quarantine process.

.PARAMETER RemoveGroups
    When $true, actually removes the group memberships. When $false (default), only reports on them.

.PARAMETER SearchBase
    The OU to search for quarantined users. Default is the standard quarantine OU.

.EXAMPLE
    .\Check-GroupsRemoved.ps1
    Reports on all quarantined users with remaining group memberships

.EXAMPLE
    .\Check-GroupsRemoved.ps1 -RemoveGroups $true
    Actually removes group memberships from quarantined users

.NOTES
    Author: James Lunardi
    Version: 1.0
    
    This script should be run periodically to ensure quarantined users
    don't retain access through overlooked group memberships.
    
.LINK
    https://github.com/jameslunardi/powershell-library
    https://www.linkedin.com/in/jameslunardi/
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [bool]$RemoveGroups = $false,
    
    [Parameter(Mandatory = $false)]
    [string]$SearchBase = "OU=Users,OU=Quarantine,OU=TARGET,DC=prod,DC=local"
)

#region Configuration
# =============================================================================
# CONFIGURATION SECTION
# =============================================================================

Write-Host "===============================================" -ForegroundColor Green
Write-Host "Group Membership Cleanup for Quarantined Users" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green

Write-Host "`nConfiguration:" -ForegroundColor Cyan
Write-Host "Search Base: $SearchBase" -ForegroundColor White
Write-Host "Remove Groups: $RemoveGroups" -ForegroundColor White
Write-Host ""

#endregion Configuration

#region Get Quarantined Users
# =============================================================================
# RETRIEVE ALL USERS IN QUARANTINE OU
# =============================================================================

Write-Host "Retrieving users from quarantine OU..." -ForegroundColor Yellow

try {
    # Get all users in the quarantine OU with their group memberships
    $Users = Get-ADUser -Filter * -SearchBase $SearchBase -Properties memberof, SamAccountName, DistinguishedName, Name
    
    Write-Host "Found $($Users.Count) users in quarantine OU" -ForegroundColor Green
}
catch {
    Write-Error "Failed to retrieve users from quarantine OU: $($_.Exception.Message)"
    exit 1
}

#endregion Get Quarantined Users

#region Initialize Collections
# =============================================================================
# INITIALIZE TRACKING COLLECTIONS
# =============================================================================

$UsersWithGroups = [System.Collections.ArrayList]@()
$TotalGroupMemberships = 0
$ProcessedUsers = 0

#endregion Initialize Collections

#region Process Users
# =============================================================================
# PROCESS EACH USER FOR GROUP MEMBERSHIPS
# =============================================================================

Write-Host "`nChecking users for group memberships..." -ForegroundColor Yellow

foreach ($User in $Users) {
    $ProcessedUsers++
    Write-Progress -Activity "Checking Group Memberships" -Status "Processing $($User.SamAccountName)" -PercentComplete (($ProcessedUsers / $Users.Count) * 100)
    
    # Count group memberships (excluding Domain Users)
    $GroupCount = 0
    if ($User.memberof) {
        $GroupCount = ($User.memberof).Count
    }
    
    if ($GroupCount -gt 0) {
        Write-Host "$($User.Name) // $($User.DistinguishedName) - $GroupCount group(s)" -ForegroundColor Red
        
        # Get detailed group information (excluding Domain Users)
        try {
            $ADGroups = Get-ADPrincipalGroupMembership -Identity $User.SamAccountName | Where-Object { $_.Name -ne "Domain Users" }
            
            if ($ADGroups) {
                $UsersWithGroups += [PSCustomObject]@{
                    SamAccountName    = $User.SamAccountName
                    Name              = $User.Name
                    DistinguishedName = $User.DistinguishedName
                    GroupCount        = $ADGroups.Count
                    Groups            = $ADGroups
                }
                
                $TotalGroupMemberships += $ADGroups.Count
                
                # Display group details
                Write-Host "  Groups:" -ForegroundColor Gray
                foreach ($Group in $ADGroups) {
                    Write-Host "    - $($Group.Name)" -ForegroundColor Gray
                }
                
                #region Remove Groups
                # =================================================================
                # REMOVE GROUP MEMBERSHIPS IF REQUESTED
                # =================================================================
                
                if ($RemoveGroups) {
                    Write-Host "  Removing group memberships..." -ForegroundColor Yellow
                    
                    try {
                        Remove-ADPrincipalGroupMembership -Identity $User.SamAccountName -MemberOf $ADGroups -Confirm:$false
                        Write-Host "  Successfully removed $($ADGroups.Count) group memberships" -ForegroundColor Green
                    }
                    catch {
                        Write-Warning "  Failed to remove group memberships for $($User.SamAccountName): $($_.Exception.Message)"
                    }
                }
                
                #endregion Remove Groups
            }
        }
        catch {
            Write-Warning "Failed to get group memberships for $($User.SamAccountName): $($_.Exception.Message)"
        }
        
        Write-Host ""
    }
}

Write-Progress -Activity "Checking Group Memberships" -Completed

#endregion Process Users

#region Summary Report
# =============================================================================
# DISPLAY SUMMARY REPORT
# =============================================================================

Write-Host "`n===============================================" -ForegroundColor Green
Write-Host "Summary Report" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green

Write-Host "`nUsers Processed: $($Users.Count)" -ForegroundColor White
Write-Host "Users with Group Memberships: $($UsersWithGroups.Count)" -ForegroundColor White
Write-Host "Total Group Memberships Found: $TotalGroupMemberships" -ForegroundColor White

if ($UsersWithGroups.Count -gt 0) {
    Write-Host "`nUsers requiring attention:" -ForegroundColor Yellow
    
    foreach ($User in $UsersWithGroups) {
        Write-Host "  $($User.SamAccountName) - $($User.GroupCount) groups" -ForegroundColor Red
    }
    
    if (-not $RemoveGroups) {
        Write-Host "`nTo remove these group memberships, run:" -ForegroundColor Cyan
        Write-Host "  .\Check-GroupsRemoved.ps1 -RemoveGroups `$true" -ForegroundColor White
    }
}
else {
    Write-Host "`nNo users found with group memberships - all clean!" -ForegroundColor Green
}

#endregion Summary Report

#region Export Results
# =============================================================================
# EXPORT RESULTS TO CSV (OPTIONAL)
# =============================================================================

if ($UsersWithGroups.Count -gt 0) {
    $ExportPath = "C:\Scripts\ADSync\Logs\QuarantineGroupCheck-$(Get-Date -Format 'yyyy-MM-dd-HHmm').csv"
    
    try {
        $ExportData = $UsersWithGroups | Select-Object SamAccountName, Name, DistinguishedName, GroupCount, 
            @{Name="GroupNames"; Expression={($_.Groups | ForEach-Object {$_.Name}) -join "; "}}
        
        $ExportData | Export-Csv -Path $ExportPath -NoTypeInformation
        Write-Host "`nResults exported to: $ExportPath" -ForegroundColor Cyan
    }
    catch {
        Write-Warning "Failed to export results: $($_.Exception.Message)"
    }
}

#endregion Export Results

Write-Host "`nGroup membership check completed." -ForegroundColor Green