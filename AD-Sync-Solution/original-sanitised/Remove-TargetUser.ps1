<#
.SYNOPSIS
    Active Directory User Synchronization Script

.DESCRIPTION
    Part of an AD synchronization suite that maintains user accounts between 
    source and target domains. Handles user creation, updates, and removal 
    with safety thresholds and comprehensive logging.
    
    Remove-TargetUser.ps1: 
    Handles user account removal and quarantine processes.

.AUTHOR
    James Lunardi
    https://www.linkedin.com/in/jameslunardi/

.VERSION
    1.0

.DATE
    June 2019
#>

Function Remove-TargetUser {

    [CmdletBinding(SupportsShouldProcess=$False,ConfirmImpact='High')]
    Param(

        [Parameter(Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({$_.EmployeeID -and $_.SamAccountName -and $_.DistinguishedName})]
        [Array[]]$Data,
        [Parameter(Mandatory=$False)]
        $ReportOnly = $True

    )

    $results = [System.Collections.ArrayList]@()
    $deletecount = $data.Count
    $deletethreshold = 45
    
    If($deletecount -ge $deletethreshold){

        Write-Verbose "Too many users are going to be deleted, stopping process"

        ForEach($user in $data){

            Write-Verbose " - $($user.SamAccountName)"

        } # End ForEach

        Write-Verbose "Too many users are going to be deleted, stopping process"
        throw "Too many users are marked for deletion [$deletecount]. Delete Threshold is $deletethreshold"
        break

    } Else {
        
        If ($ReportOnly) {

            Write-Verbose "Report Only Mode - Target Sync Script - Deleting Users - Processing $deletecount User(s)"

        } Else {

            Write-Verbose "Target Sync Script - Deleting Users - Processing $deletecount User(s)"

        } # End If

        ForEach($user in $data){

            If($user.DistinguishedName -like "*OU=Leavers,OU=Users,OU=Quarantine,OU=Sync,DC=target,DC=company,DC=local"){
            
                $datetime = Get-Date
                $newinfo = "$datetime - ADSync`r`nNo Account found in Source with EID:$($user.EmployeeID), account is disabled and in Quarantine. Deleting Account.`r`n"
                $info = $user.info + $newinfo

                Write-Verbose "No Account found in Source with EID:$($user.EmployeeID), account is disabled and in Quarantine. Deleting Account."
            
                Try{

                    If ($ReportOnly) {

                        Write-Verbose "Running in Report Only Mode"
                        Set-ADUser $user.DistinguishedName –Replace @{info="$info"} -ErrorAction SilentlyContinue -WhatIf
                        Start-Sleep -Seconds 2
                        Remove-ADUser $user.DistinguishedName -ErrorAction SilentlyContinue -WhatIf

                    } Else {

                        Set-ADUser $user.DistinguishedName –Replace @{info="$info"} -ErrorAction SilentlyContinue
                        Start-Sleep -Seconds 2
                        Remove-ADUser $user.DistinguishedName -ErrorAction SilentlyContinue -Confirm:$false

                    }

                } Catch {

                    $ErrorMessage = $_.Exception.Message
                    $DetailedErrorMessage = "When attempting to set the info attribute and then remove the Target account $($user.SamAccountName) got error: $($_.Exception.InnerException.Message)"

                    Break

                } Finally {
                
                    If($ErrorMessage){
   
                        Write-Verbose $ErrorMessage
                        Write-Verbose $DetailedErrorMessage

                        $Results += [PSCustomObject]@{
                            SamAccountName = $user.SamAccountName
                            Success = $false
                            Result = $DetailedErrorMessage
                        }

                    } Else {

                        Write-Verbose "Deleting user $($user.SamAccountName)"

                        $Results += [PSCustomObject]@{
                            SamAccountName = $user.SamAccountName
                            Success = $true
                            Result = "Deleted"
                        }

                    } # End If

                } # End TryCatchFinally

            } Else {

                $datetime = Get-Date
                $newinfo = "$datetime - ADSync`r`nNo Account found in Source with EID:$($user.EmployeeID), account disabled and moved to Quarantine. `r`n"
                $info = $user.info + $newinfo

                Write-Verbose "No Account found in Source with EID:$($user.EmployeeID), account disabled and moved to Quarantine."
            
                Try {

                    if ($ReportOnly) {

                        Write-Verbose "Running in Report Only Mode"
                        
                        Set-ADUser $user.DistinguishedName -Enabled $false –Replace @{info="$info"} -ErrorAction SilentlyContinue -WhatIf
                        
                        $groups = Get-ADUser -Identity $user.DistinguishedName -Properties memberof -ErrorAction SilentlyContinue | select -expand memberof -ErrorAction SilentlyContinue
                        $groups | Remove-ADGroupMember -Members $user.DistinguishedName -Confirm:$false -WhatIf
                        
                        Start-Sleep -Seconds 1.5

                        Move-ADObject $user.DistinguishedName -TargetPath "OU=Leavers,OU=Users,OU=Quarantine,OU=Sync,DC=target,DC=company,DC=local" -ErrorAction SilentlyContinue -WhatIf

                    } else {

                        Set-ADUser $user.DistinguishedName -Enabled $false –Replace @{info="$info"} -ErrorAction SilentlyContinue

                        $groups = Get-ADUser -Identity $user.DistinguishedName -Properties memberof -ErrorAction SilentlyContinue | select -expand memberof -ErrorAction SilentlyContinue
                        $groups | Remove-ADGroupMember -Members $user.DistinguishedName -Confirm:$false
                        
                        Start-Sleep -Seconds 1.5

                        Move-ADObject $user.DistinguishedName -TargetPath "OU=Leavers,OU=Users,OU=Quarantine,OU=Sync,DC=target,DC=company,DC=local" -ErrorAction SilentlyContinue

                    }

                } Catch {

                    $ErrorMessage = $_.Exception.Message
                    $DetailedErrorMessage = "When attempting to set the info attribute and then move the Target account $($user.SamAccountName) to Quarantine got error: $($_.Exception.InnerException.Message)"
                
                    Write-Verbose $ErrorMessage
                    Write-Verbose $DetailedErrorMessage

                    Break

                } Finally {

                    If($ErrorMessage){

                        $Results += [PSCustomObject]@{
                            SamAccountName = $user.SamAccountName
                            Success = $false
                            Result = $DetailedErrorMessage
                        }

                    } else {

                        Write-Verbose "$($user.SamAccountName) - Is to be deleted but is not yet Quarantined, removed group memberships and Quarantined the user"
                        Write-Verbose "Removed from the following groups:"
                        
                        ForEach($group in $groups){
                            
                            Write-Verbose $group
                        
                        }

                        $Results += [PSCustomObject]@{
                            SamAccountName = $user.SamAccountName
                            Success = $true
                            Result = "Quarantined"
                        }

                    } # End If                

                } # End TryCatchFinally
            
            } # End If

        } # End ForEach

        If(!$ErrorMessage){

            If ($ReportOnly) {

                Write-Verbose "ADSync Deleted Users Complete (Report Only)"

            } Else {

                Write-Verbose "ADSync Deleted Users Complete"

            } # End If

        } # End If

    } # End If

    Write-Output $results

} # End of Function

