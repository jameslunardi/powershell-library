<#
.SYNOPSIS
    Updates user account attributes in the Target domain

.DESCRIPTION
    This function updates user account attributes in the Target domain based on changes detected
    in the Source domain. It handles various attribute types including standard AD attributes,
    cloud extension attributes, and special cases like account expiration and user moves.
    
    Special handling includes:
    - Account expiration dates (set/clear)
    - User disabling and moves to Leavers OU
    - Office attribute mapping to physicalDeliveryOfficeName
    - Cloud extension attributes

.PARAMETER Data
    Array of update objects. Each object must contain:
    - DistinguishedName
    - SamAccountName
    - Attribute (name of attribute to update)
    - NewValue (new value for the attribute)
    - OldValue (current value for reference)

.PARAMETER ReportOnly
    When $true, runs in report-only mode without making actual changes.
    Default: $true

.EXAMPLE
    Update-ProdUser -Data $attributeUpdates -ReportOnly $true -Verbose
    Runs in report-only mode with verbose output

.EXAMPLE
    Update-ProdUser -Data $attributeUpdates -ReportOnly $false
    Executes actual attribute updates

.NOTES
    Author: James Lunardi
    Version: 1.0
    
    Safety Features:
    - Maximum update threshold: 300 changes per execution
    - Comprehensive error handling for each attribute type
    - Audit trail updates in user info field
    - Special handling for complex attributes
    
.LINK
    https://github.com/jameslunardi/powershell-library
    https://www.linkedin.com/in/jameslunardi/
#>

# Import AD Command Wrappers for test mode support
if (Test-Path (Join-Path $PSScriptRoot "Tests\ADCommandWrappers.ps1")) {
    . (Join-Path $PSScriptRoot "Tests\ADCommandWrappers.ps1")
}

function Update-ProdUser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $false)]
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
    $UpdateThreshold = $Config.SafetyThresholds.UpdateThreshold
    
    # Target domain configuration
    $LeaversOU = $Config.TargetDomain.LeaversOU
    
    #endregion Configuration

    #region Initialization
    # =============================================================================
    # INITIALIZATION
    # =============================================================================
    
    $Results = [System.Collections.ArrayList]@()
    $DisableUsers = [System.Collections.ArrayList]@()
    $UpdateCount = $Data.Count
    
    Write-Verbose "Update-ProdUser function started"
    Write-Verbose "Updates to process: $UpdateCount"
    Write-Verbose "Update threshold: $UpdateThreshold"
    Write-Verbose "Report Only mode: $ReportOnly"
    
    #endregion Initialization

    #region Safety Check
    # =============================================================================
    # SAFETY THRESHOLD CHECK
    # =============================================================================
    
    if ($UpdateCount -ge $UpdateThreshold) {
        $ErrorMessage = "Too many updates are required: [$UpdateCount]. Update threshold is $UpdateThreshold"
        Write-Verbose $ErrorMessage
        Write-Error $ErrorMessage -ErrorAction Stop
    }
    
    #endregion Safety Check

    #region Main Processing
    # =============================================================================
    # MAIN PROCESSING LOOP
    # =============================================================================
    
    if ($ReportOnly) {
        Write-Verbose "Report Only Mode - Target Sync Script - Updating Users - Processing $UpdateCount changes to user objects"
    }
    else {
        Write-Verbose "Target Sync Script - Updating Users - Processing $UpdateCount changes to user objects"
    }
    
    foreach ($Update in $Data) {
        $ErrorMessage = $null
        $DetailedErrorMessage = $null
        
        Write-Verbose "Processing update: $($Update.SamAccountName) - $($Update.Attribute) - $($Update.NewValue)"
        
        #region Special Attribute Handling
        # =========================================================================
        # HANDLE SPECIAL ATTRIBUTES (ENABLED AND DISTINGUISHED NAME)
        # =========================================================================
        
        if (($Update.Attribute -eq "Enabled") -or ($Update.Attribute -eq "DistinguishedName")) {
            # These require special processing - add to disable users collection
            $DisableUsers += $Update
            continue
        }
        
        #endregion Special Attribute Handling

        #region Account Expiration Handling
        # =========================================================================
        # HANDLE ACCOUNT EXPIRATION DATE
        # =========================================================================
        
        if ($Update.Attribute -eq "AccountExpirationDate") {
            try {
                if ($Update.NewValue) {
                    Write-Verbose "Setting AD Account Expiration on $($Update.SamAccountName) to $($Update.NewValue)"
                    
                    if ($ReportOnly) {
                        Write-Verbose "Would set account expiration to $($Update.NewValue)"
                    }
                    else {
                        Invoke-SetADAccountExpiration -Identity $Update.SamAccountName -DateTime $Update.NewValue
                    }
                }
                else {
                    Write-Verbose "Clearing AD Account Expiration on $($Update.SamAccountName)"
                    
                    if ($ReportOnly) {
                        Write-Verbose "Would clear account expiration"
                    }
                    else {
                        Invoke-ClearADAccountExpiration -Identity $Update.SamAccountName
                    }
                }
            }
            catch {
                $ErrorMessage = $_.Exception.Message
                $DetailedErrorMessage = "When attempting to update the $($Update.Attribute) attribute, got error: $($_.Exception.InnerException.Message)"
                
                Write-Warning $ErrorMessage
                Write-Warning $DetailedErrorMessage
            }
        }
        
        #endregion Account Expiration Handling

        #region Standard Attribute Handling
        # =========================================================================
        # HANDLE STANDARD ATTRIBUTES
        # =========================================================================
        
        else {
            try {
                if ($Update.NewValue) {
                    Write-Verbose "Setting attribute $($Update.Attribute) for $($Update.SamAccountName)"
                    
                    # Get the user object with all properties
                    $User = Invoke-GetADUser -Identity $Update.SamAccountName -Properties *
                    
                    # Update the appropriate attribute based on type
                    switch ($Update.Attribute) {
                        "mail" { $User.mail = $Update.NewValue }
                        "GivenName" { $User.GivenName = $Update.NewValue }
                        "Surname" { $User.Surname = $Update.NewValue }
                        "EmployeeID" { $User.EmployeeID = $Update.NewValue }
                        "Title" { $User.Title = $Update.NewValue }
                        "Office" { $User.physicalDeliveryOfficeName = $Update.NewValue }
                        "Department" { $User.Department = $Update.NewValue }
                        "l" { $User.l = $Update.NewValue }
                        "co" { $User.co = $Update.NewValue }
                        "msDS-cloudExtensionAttribute1" { $User.'msDS-cloudExtensionAttribute1' = $Update.NewValue }
                        "msDS-cloudExtensionAttribute2" { $User.'msDS-cloudExtensionAttribute2' = $Update.NewValue }
                        "msDS-cloudExtensionAttribute3" { $User.'msDS-cloudExtensionAttribute3' = $Update.NewValue }
                        "msDS-cloudExtensionAttribute6" { $User.'msDS-cloudExtensionAttribute6' = $Update.NewValue }
                        "msDS-cloudExtensionAttribute7" { $User.'msDS-cloudExtensionAttribute7' = $Update.NewValue }
                        "msDS-cloudExtensionAttribute10" { $User.'msDS-cloudExtensionAttribute10' = $Update.NewValue }
                        "msDS-cloudExtensionAttribute11" { $User.'msDS-cloudExtensionAttribute11' = $Update.NewValue }
                    }
                    
                    # Apply the update
                    if ($ReportOnly) {
                        Write-Verbose "Would update $($Update.Attribute) for $($Update.SamAccountName) to $($Update.NewValue)"
                    }
                    else {
                        Write-Verbose "Updating $($Update.Attribute) for $($Update.SamAccountName)"
                        Invoke-SetADUser -Identity $Update.SamAccountName -Replace @{$Update.Attribute = $Update.NewValue}
                    }
                }
                else {
                    # Clear the attribute if NewValue is empty
                    Write-Verbose "Clearing $($Update.Attribute) for $($Update.SamAccountName)"
                    
                    if ($Update.Attribute -eq "Office") {
                        # Special handling for Office attribute
                        if ($ReportOnly) {
                            Write-Verbose "Would clear physicalDeliveryOfficeName for $($Update.SamAccountName)"
                        }
                        else {
                            Invoke-SetADUser -Identity $Update.SamAccountName -Clear 'physicalDeliveryOfficeName'
                        }
                    }
                    elseif ($Update.Attribute -eq "l") {
                        # Special handling for location attribute
                        if ($ReportOnly) {
                            Write-Verbose "Would clear $($Update.Attribute) for $($Update.SamAccountName)"
                        }
                        else {
                            Invoke-SetADUser -Identity $Update.SamAccountName -Clear $Update.Attribute
                        }
                    }
                }
            }
            catch {
                $ErrorMessage = $_.Exception.Message
                $DetailedErrorMessage = "When attempting to set the $($Update.Attribute) attribute, got error: $($_.Exception.InnerException.Message)"
                
                Write-Warning $ErrorMessage
                Write-Warning $DetailedErrorMessage
            }
            finally {
                if ($ErrorMessage) {
                    $Results += [PSCustomObject]@{
                        DistinguishedName = $Update.DistinguishedName
                        Success           = $false
                        Attribute         = "$($Update.Attribute)"
                        Result            = $DetailedErrorMessage
                    }
                }
                else {
                    # Update the info field with audit trail
                    $DateTime = Get-Date
                    
                    if ($ReportOnly) {
                        $Info = "$DateTime - ADSync`r`nAttributes Updated Based on Source User Account`r`n"
                        Set-ADUser -Identity $Update.SamAccountName -Replace @{Info = $Info } -ErrorAction SilentlyContinue -WhatIf
                    }
                    else {
                        $Info = "$DateTime - ADSync`r`nAttributes Updated Based on Source User Account`r`n"
                        Set-ADUser -Identity $Update.SamAccountName -Replace @{Info = $Info } -ErrorAction SilentlyContinue
                    }
                    
                    # Format old value for display
                    if ($Update.OldValue) { 
                        $OldValueDisplay = $Update.OldValue 
                    }
                    else { 
                        $OldValueDisplay = "'Blank'" 
                    }
                    
                    Write-Verbose "Updated $($Update.SamAccountName) - changed $($Update.Attribute) from $OldValueDisplay to '$($Update.NewValue)'"
                    
                    $Results += [PSCustomObject]@{
                        DistinguishedName = $Update.DistinguishedName
                        Success           = $true
                        Attribute         = "$($Update.Attribute)"
                        Result            = "Updated"
                    }
                }
            }
        }
        
        #endregion Standard Attribute Handling
    }
    
    #endregion Main Processing

    #region Disable Users Processing
    # =============================================================================
    # PROCESS USERS REQUIRING DISABLE/MOVE TO LEAVERS
    # =============================================================================
    
    foreach ($User in $DisableUsers) {
        $ErrorMessage = $null
        $DetailedErrorMessage = $null
        
        Write-Verbose "Processing user disable/move: $($User.SamAccountName)"
        
        # Prepare audit information
        $DateTime = Get-Date
        $Info = "$DateTime - ADSync`r`nAccount in Source has moved to leavers. Disabled account, removed groups, and moved to Leavers OU.`r`n"
        
        # Get current user object
        $UserObject = Get-ADUser $User.SamAccountName -Properties Enabled, Info
        $UserObject.Info = $UserObject.Info + $Info
        
        try {
            if ($ReportOnly) {
                Write-Verbose "Would disable and move user: $($User.SamAccountName) (Report Only mode)"
                
                # Disable account
                Disable-ADAccount $User.SamAccountName -WhatIf
                
                # Get and remove group memberships
                $Groups = Get-ADUser -Identity $User.SamAccountName -Properties memberof -ErrorAction SilentlyContinue | 
                    Select-Object -ExpandProperty memberof -ErrorAction SilentlyContinue
                $Groups | Remove-ADGroupMember -Members $User.SamAccountName -ErrorAction SilentlyContinue -WhatIf
                
                Start-Sleep -Seconds 1.5
                
                # Move to Leavers OU
                Get-ADUser $User.SamAccountName | Move-ADObject -TargetPath $LeaversOU -ErrorAction SilentlyContinue -WhatIf
            }
            else {
                Write-Verbose "Disabling and moving user: $($User.SamAccountName)"
                
                # Update info field
                Set-ADUser -Instance $UserObject -ErrorAction SilentlyContinue
                
                # Disable account
                Disable-ADAccount $User.SamAccountName
                
                # Get and remove group memberships
                $Groups = Get-ADUser -Identity $User.SamAccountName -Properties memberof -ErrorAction SilentlyContinue | 
                    Select-Object -ExpandProperty memberof -ErrorAction SilentlyContinue
                $Groups | Remove-ADGroupMember -Members $User.SamAccountName -Confirm:$false -ErrorAction SilentlyContinue
                
                Start-Sleep -Seconds 1.5
                
                # Move to Leavers OU
                Get-ADUser $User.SamAccountName | Move-ADObject -TargetPath $LeaversOU -ErrorAction SilentlyContinue
            }
        }
        catch {
            $ErrorMessage = $_.Exception.Message
            $DetailedErrorMessage = "When attempting to disable and move user $($User.SamAccountName), got error: $($_.Exception.InnerException.Message)"
            
            Write-Warning $ErrorMessage
            Write-Warning $DetailedErrorMessage
        }
        finally {
            if ($ErrorMessage) {
                $Results += [PSCustomObject]@{
                    DistinguishedName = $User.DistinguishedName
                    Success           = $false
                    Attribute         = "$($User.Attribute)"
                    Result            = $DetailedErrorMessage
                }
            }
            else {
                Write-Verbose "Disabled $($User.SamAccountName) and moved to Leavers OU"
                
                if ($Groups) {
                    Write-Verbose "Removed from the following groups:"
                    foreach ($Group in $Groups) {
                        Write-Verbose " - $Group"
                    }
                }
                
                $Results += [PSCustomObject]@{
                    DistinguishedName = $User.DistinguishedName
                    Success           = $true
                    Attribute         = "$($User.Attribute)"
                    Result            = "Updated"
                }
            }
        }
    }
    
    #endregion Disable Users Processing

    #region Completion
    # =============================================================================
    # COMPLETION
    # =============================================================================
    
    if ($ReportOnly) {
        Write-Verbose "ADSync Update Users Complete (Report Only)"
    }
    else {
        Write-Verbose "ADSync Update Users Complete"
    }
    
    Write-Output $Results
    
    #endregion Completion
}