<#
.SYNOPSIS
    Removes or quarantines user accounts in the Target domain

.DESCRIPTION
    This function handles the removal process for users who no longer exist in the Source domain.
    It implements a two-stage process:
    1. First run: Disable account, remove group memberships, move to Leavers OU
    2. Second run: If already in Leavers OU, completely delete the account
    
    Includes safety threshold to prevent mass deletions.

.PARAMETER Data
    Array of user objects to be removed. Each object must contain:
    - EmployeeID
    - SamAccountName  
    - DistinguishedName

.PARAMETER ReportOnly
    When $true, runs in report-only mode without making actual changes.
    Default: $true

.EXAMPLE
    Remove-ProdUser -Data $usersToRemove -ReportOnly $true -Verbose
    Runs in report-only mode with verbose output

.EXAMPLE
    Remove-ProdUser -Data $usersToRemove -ReportOnly $false
    Executes actual user removal operations

.NOTES
    Author: James Lunardi
    Version: 1.0
    
    Safety Features:
    - Maximum deletion threshold: 45 users per execution
    - Two-stage removal process (quarantine then delete)
    - Comprehensive logging and error handling
    - Group membership cleanup
    
.LINK
    https://github.com/jameslunardi/powershell-library
    https://www.linkedin.com/in/jameslunardi/
#>

function Remove-ProdUser {
    [CmdletBinding(SupportsShouldProcess = $false, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ $_.EmployeeID -and $_.SamAccountName -and $_.DistinguishedName })]
        [Array[]]$Data,
        
        [Parameter(Mandatory = $false)]
        [bool]$ReportOnly = $true,
        
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Config
    )

    #region Configuration
    # =============================================================================
    # CONFIGURATION SECTION - Loaded from config
    # =============================================================================
    
    # Safety thresholds
    $DeletionThreshold = $Config.SafetyThresholds.DeletionThreshold
    
    # Target domain configuration
    $LeaversOU = $Config.TargetDomain.LeaversOU
    
    #endregion Configuration

    #region Initialization
    # =============================================================================
    # INITIALIZATION
    # =============================================================================
    
    $Results = [System.Collections.ArrayList]@()
    $DeleteCount = $Data.Count
    
    Write-Verbose "Remove-ProdUser function started"
    Write-Verbose "Users to process: $DeleteCount"
    Write-Verbose "Deletion threshold: $DeletionThreshold"
    Write-Verbose "Report Only mode: $ReportOnly"
    
    #endregion Initialization

    #region Safety Check
    # =============================================================================
    # SAFETY THRESHOLD CHECK
    # =============================================================================
    
    if ($DeleteCount -ge $DeletionThreshold) {
        Write-Verbose "Too many users are scheduled for deletion - stopping process"
        Write-Verbose "Users that would be deleted:"
        
        foreach ($User in $Data) {
            Write-Verbose " - $($User.SamAccountName)"
        }
        
        $ErrorMessage = "Too many users are marked for deletion [$DeleteCount]. Deletion threshold is $DeletionThreshold"
        Write-Error $ErrorMessage
        throw $ErrorMessage
    }
    
    #endregion Safety Check

    #region Main Processing
    # =============================================================================
    # MAIN PROCESSING LOOP
    # =============================================================================
    
    if ($ReportOnly) {
        Write-Verbose "Report Only Mode - Target Sync Script - Removing Users - Processing $DeleteCount User(s)"
    }
    else {
        Write-Verbose "Target Sync Script - Removing Users - Processing $DeleteCount User(s)"
    }
    
    foreach ($User in $Data) {
        $ErrorMessage = $null
        $DetailedErrorMessage = $null
        
        Write-Verbose "Processing user: $($User.SamAccountName) (EmployeeID: $($User.EmployeeID))"
        
        #region Check Current Location
        # =========================================================================
        # CHECK IF USER IS ALREADY IN LEAVERS OU
        # =========================================================================
        
        if ($User.DistinguishedName -like "*$($Config.TargetDomain.LeaversOU)") {
            #region Delete User
            # =====================================================================
            # USER IS IN LEAVERS OU - PROCEED WITH DELETION
            # =====================================================================
            
            $DateTime = Get-Date
            $NewInfo = "$DateTime - ADSync`r`nNo account found in Source with EmployeeID: $($User.EmployeeID). Account is disabled and in Quarantine. Deleting account.`r`n"
            $Info = $User.Info + $NewInfo
            
            Write-Verbose "No account found in Source with EmployeeID: $($User.EmployeeID). Account is disabled and in Quarantine. Deleting account."
            
            try {
                if ($ReportOnly) {
                    Write-Verbose "Running in Report Only Mode - Would delete user: $($User.SamAccountName)"
                    Set-ADUser $User.DistinguishedName -Replace @{info = "$Info" } -ErrorAction SilentlyContinue -WhatIf
                    Start-Sleep -Seconds 2
                    Remove-ADUser $User.DistinguishedName -ErrorAction SilentlyContinue -WhatIf
                }
                else {
                    Write-Verbose "Updating info attribute and deleting user: $($User.SamAccountName)"
                    Set-ADUser $User.DistinguishedName -Replace @{info = "$Info" } -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 2
                    Remove-ADUser $User.DistinguishedName -ErrorAction SilentlyContinue -Confirm:$false
                }
            }
            catch {
                $ErrorMessage = $_.Exception.Message
                $DetailedErrorMessage = "When attempting to set the info attribute and remove the Target account $($User.SamAccountName), got error: $($_.Exception.InnerException.Message)"
            }
            finally {
                if ($ErrorMessage) {
                    Write-Verbose $ErrorMessage
                    Write-Verbose $DetailedErrorMessage
                    
                    $Results += [PSCustomObject]@{
                        SamAccountName = $User.SamAccountName
                        Success        = $false
                        Result         = $DetailedErrorMessage
                    }
                }
                else {
                    Write-Verbose "Successfully deleted user: $($User.SamAccountName)"
                    
                    $Results += [PSCustomObject]@{
                        SamAccountName = $User.SamAccountName
                        Success        = $true
                        Result         = "Deleted"
                    }
                }
            }
            
            #endregion Delete User
        }
        else {
            #region Quarantine User
            # =====================================================================
            # USER NOT IN LEAVERS OU - QUARANTINE FIRST
            # =====================================================================
            
            $DateTime = Get-Date
            $NewInfo = "$DateTime - ADSync`r`nNo account found in Source with EmployeeID: $($User.EmployeeID). Account disabled and moved to Quarantine.`r`n"
            $Info = $User.Info + $NewInfo
            
            Write-Verbose "No account found in Source with EmployeeID: $($User.EmployeeID). Account disabled and moved to Quarantine."
            
            try {
                if ($ReportOnly) {
                    Write-Verbose "Running in Report Only Mode - Would quarantine user: $($User.SamAccountName)"
                    
                    # Disable account and update info
                    Set-ADUser $User.DistinguishedName -Enabled $false -Replace @{info = "$Info" } -ErrorAction SilentlyContinue -WhatIf
                    
                    # Get and remove group memberships
                    $Groups = Get-ADUser -Identity $User.DistinguishedName -Properties memberof -ErrorAction SilentlyContinue | 
                        Select-Object -ExpandProperty memberof -ErrorAction SilentlyContinue
                    $Groups | Remove-ADGroupMember -Members $User.DistinguishedName -Confirm:$false -WhatIf
                    
                    Start-Sleep -Seconds 1.5
                    
                    # Move to Leavers OU
                    Move-ADObject $User.DistinguishedName -TargetPath $LeaversOU -ErrorAction SilentlyContinue -WhatIf
                }
                else {
                    Write-Verbose "Quarantining user: $($User.SamAccountName)"
                    
                    # Disable account and update info
                    Set-ADUser $User.DistinguishedName -Enabled $false -Replace @{info = "$Info" } -ErrorAction SilentlyContinue
                    
                    # Get and remove group memberships
                    $Groups = Get-ADUser -Identity $User.DistinguishedName -Properties memberof -ErrorAction SilentlyContinue | 
                        Select-Object -ExpandProperty memberof -ErrorAction SilentlyContinue
                    $Groups | Remove-ADGroupMember -Members $User.DistinguishedName -Confirm:$false
                    
                    Start-Sleep -Seconds 1.5
                    
                    # Move to Leavers OU
                    Move-ADObject $User.DistinguishedName -TargetPath $LeaversOU -ErrorAction SilentlyContinue
                }
            }
            catch {
                $ErrorMessage = $_.Exception.Message
                $DetailedErrorMessage = "When attempting to set the info attribute and move the Target account $($User.SamAccountName) to Quarantine, got error: $($_.Exception.InnerException.Message)"
                
                Write-Verbose $ErrorMessage
                Write-Verbose $DetailedErrorMessage
            }
            finally {
                if ($ErrorMessage) {
                    $Results += [PSCustomObject]@{
                        SamAccountName = $User.SamAccountName
                        Success        = $false
                        Result         = $DetailedErrorMessage
                    }
                }
                else {
                    Write-Verbose "$($User.SamAccountName) - Scheduled for deletion but not yet quarantined. Removed group memberships and quarantined the user."
                    
                    if ($Groups) {
                        Write-Verbose "Removed from the following groups:"
                        foreach ($Group in $Groups) {
                            Write-Verbose " - $Group"
                        }
                    }
                    
                    $Results += [PSCustomObject]@{
                        SamAccountName = $User.SamAccountName
                        Success        = $true
                        Result         = "Quarantined"
                    }
                }
            }
            
            #endregion Quarantine User
        }
        
        #endregion Check Current Location
    }
    
    #endregion Main Processing

    #region Completion
    # =============================================================================
    # COMPLETION
    # =============================================================================
    
    if (-not $ErrorMessage) {
        if ($ReportOnly) {
            Write-Verbose "ADSync Remove Users Complete (Report Only)"
        }
        else {
            Write-Verbose "ADSync Remove Users Complete"
        }
    }
    
    Write-Output $Results
    
    #endregion Completion
}