<#
.SYNOPSIS
    Active Directory User Synchronization Script

.DESCRIPTION
    Part of an AD synchronization suite that maintains user accounts between 
    source and target domains. Handles user creation, updates, and removal 
    with safety thresholds and comprehensive logging.
    
    Update-TargetUser.ps1:
    Updates existing user attributes to maintain synchronization.

.AUTHOR
    James Lunardi
    https://www.linkedin.com/in/jameslunardi/

.VERSION
    1.0

.DATE
    June 2019
#>

Function Update-TargetUser {

    [CmdletBinding()]
    Param(

        [Parameter(Mandatory=$False,ValueFromPipeline=$False)]
        [Array[]]$Data,

        [Parameter(Mandatory=$False)]
        $ReportOnly = $True

    )

    $results = [System.Collections.ArrayList]@()
    $disableuser = [System.Collections.ArrayList]@()
    $updatecount = $Data.Count
    $updatethreshold = 300

    
    If($updatecount -ge $updatethreshold){

        Write-Verbose "Too many updates are required, stopping process"
        throw "Too many updates are required: [$updatecount]. Update Threshold is $updatethreshold"
        break

    } Else {
        
        If ($ReportOnly) {

            Write-Verbose "Report Only Mode - Target Sync Script - Updating Users - Processing $updatecount changes to user objects"
            Write-Debug -Message "Debug1"

        } Else {

            Write-Verbose "Target Sync Script - Updating Users - Processing $updatecount changes user objects"
            Write-Debug -Message "Debug2"

        } # End If

        ForEach($Update in $Data){

            $ErrorMessage = $null
            $DetailedErrorMessage = $null

            Write-Debug -Message "Debug1"
            Write-Debug -Message "$($update.SamAccountName) - $($update.Attribute) - $($update.newvalue)"

            If(($update.Attribute -eq "Enabled") -or ($update.Attribute -eq "DistinguishedName")){

                $disableuser += $update

            } elseIf($update.Attribute -eq "AccountExpirationDate") {

                If($Update.NewValue){

                    Write-Verbose "Setting AD Account Expiration on $($Update.SamAccountName)"
                    If ($ReportOnly) {
                        Set-ADAccountExpiration -Identity $Update.SamAccountName -DateTime $Update.NewValue -WhatIf
                    } else {
                        Set-ADAccountExpiration -Identity $Update.SamAccountName -DateTime $Update.NewValue
                    }

                } else {

                    Write-Verbose "Clearing AD Account Expiration on $($Update.SamAccountName)"
                    If ($ReportOnly) {
                        Clear-ADAccountExpiration -Identity $update.SamAccountName -WhatIf
                    } else {
                        Clear-ADAccountExpiration -Identity $update.SamAccountName
                    }
                }

            } else {

                Try {

                    If($Update.NewValue){

                        Write-Verbose "Setting Attribute"

                        $user = Get-ADUser -Identity $update.SamAccountName -Properties *

                        switch($update.Attribute){
                            mail {
                                $user.mail = $update.newvalue
                            }
                            GivenName {
                                $user.GivenName = $update.newvalue
                            }
                            Surname {
                                $user.Surname = $update.newvalue
                            }
                            EmployeeID {
                                $user.EmployeeID = $update.newvalue
                            }
                            Title {
                                $user.Title = $update.newvalue
                            }
                            Office {
                                $user.physicalDeliveryOfficeName = $update.newvalue
                            }
                            Department {
                                $user.Department = $update.newvalue
                            }
                            l {
                                $user.l = $update.newvalue
                            }
                            Co {
                                $user.Co = $update.newvalue
                            }
                            msDS-cloudExtensionAttribute1 {
                                $user.'msDS-cloudExtensionAttribute1' = $update.newvalue
                            }
                            msDS-cloudExtensionAttribute2 {
                                $user.'msDS-cloudExtensionAttribute2' = $update.newvalue
                            }
                            msDS-cloudExtensionAttribute3 {
                                $user.'msDS-cloudExtensionAttribute3' = $update.newvalue
                            }
                            msDS-cloudExtensionAttribute6 {
                                $user.'msDS-cloudExtensionAttribute6' = $update.newvalue
                            }
                            msDS-cloudExtensionAttribute7 {
                                $user.'msDS-cloudExtensionAttribute7' = $update.newvalue
                            }
                            msDS-cloudExtensionAttribute10 {
                                $user.'msDS-cloudExtensionAttribute10' = $update.newvalue
                            }
                            msDS-cloudExtensionAttribute11 {
                                $user.'msDS-cloudExtensionAttribute11' = $update.newvalue
                            }
                        }

                        If ($ReportOnly) {

                            Write-Verbose "Updating $($update.Attribute) for $($update.SamAccountName)"
                            Set-ADUser -Instance $user -ErrorAction SilentlyContinue -WhatIf
                            
                        } else {

                            Write-Verbose "Updating $($update.Attribute) for $($update.SamAccountName)"
                            Set-ADUser -Instance $user -ErrorAction SilentlyContinue
                         
                        }

                    } else {

                        Write-Verbose "Clearing $($update.Attribute) for $($update.SamAccountName)"

                        If($Update.Attribute -eq "Office"){
                       
                            If ($ReportOnly) {
                                
                                Set-ADUser $update.SamAccountName -clear physicalDeliveryOfficeName -WhatIf
                            } else {
 
                                Set-ADUser $update.SamAccountName -clear physicalDeliveryOfficeName
                            }

                        } else {

                            If($Update.Attribute -eq "l"){

                                If ($ReportOnly) {

                                    Set-ADUser $update.SamAccountName -clear $update.Attribute -WhatIf
                                } else {

                                    Set-ADUser $update.SamAccountName -clear $update.Attribute
                                }
                            
                            }

                        }



                    }



                } Catch {

                    $ErrorMessage = $_.Exception.Message
                    $DetailedErrorMessage = "When attempting to set the $($update.Attribute) attribute got error: $($_.Exception.InnerException.Message)"
                
                    Write-Warning $ErrorMessage
                    Write-Warning $DetailedErrorMessage                 

                } Finally {

                    If($ErrorMessage){

                        $Results += [PSCustomObject]@{
                            DistinguishedName = $Update.DistinguishedName
                            Success = $false
                            Attribute = "$($update.Attribute)" 
                            Result = $DetailedErrorMessage
                        }

                    } else {

                        $datetime = Get-Date
                        
                        If ($ReportOnly) {
                            $info = "$datetime - ADSync`r`nAttributes Updated Based on Source User Account`r`n"
                            Set-ADUser -Identity $update.SamAccountName -Replace @{Info=$info} -ErrorAction SilentlyContinue -WhatIf
                        } else {
                            $info = "$datetime - ADSync`r`nAttributes Updated Based on Source User Account`r`n"
                            Set-ADUser -Identity $update.SamAccountName -Replace @{Info=$info} -ErrorAction SilentlyContinue                        
                        }

                        If($update.oldvalue){$old = $update.oldvalue} else {$old = "'Blank'"}
                        
                        Write-Verbose "Updating $($update.SamAccountName) changing $($update.Attribute) from $old to '$($update.newvalue)'"

                        $Results += [PSCustomObject]@{
                            DistinguishedName = $Update.DistinguishedName
                            Success = $true
                            Attribute = "$($update.Attribute)" 
                            Result = "Updated"
                        }

                    } 

                }
                
                
           
            }

        } # End ForEach

        ForEach($user in $disableuser){

            $ErrorMessage = $null
            $DetailedErrorMessage = $null
            $datetime = Get-Date
            $info = "$datetime - ADSync`r`nAccount in Source has moved to leavers. Disabled account, removed groups, and moved to Leavers OU. `r`n"
            $user = Get-ADUser $user.SamAccountName -Properties Enabled,info
            $user.info = $user.info + $info

            Try{

                If ($ReportOnly) {

                    Disable-ADAccount $user.SamAccountName -WhatIf
                    
                    $groups = Get-ADUser -Identity $user.SamAccountName -Properties memberof -ErrorAction SilentlyContinue | select -expand memberof -ErrorAction SilentlyContinue
                    $groups | Remove-ADGroupMember -Members $user.SamAccountName -ErrorAction SilentlyContinue -WhatIf
                    
                    Start-Sleep -Seconds 1.5
                    
                    Get-aduser $user.SamAccountName | Move-ADObject -TargetPath "OU=Leavers,OU=Users,OU=Quarantine,OU=Sync,DC=target,DC=company,DC=local" -ErrorAction SilentlyContinue -WhatIf
                    

                } else {

                    Set-ADUser -instance $user -ErrorAction SilentlyContinue

                    Disable-ADAccount $user.SamAccountName

                    $groups = Get-ADUser -Identity $user.SamAccountName -Properties memberof -ErrorAction SilentlyContinue | select -expand memberof -ErrorAction SilentlyContinue
                    $groups | Remove-ADGroupMember -Members $user.SamAccountName -Confirm:$false -ErrorAction SilentlyContinue

                    Start-Sleep -Seconds 1.5

                    Get-aduser $user.SamAccountName | Move-ADObject -TargetPath "OU=Leavers,OU=Users,OU=Quarantine,OU=Sync,DC=target,DC=company,DC=local" -ErrorAction SilentlyContinue     

                }


            } Catch {

                $ErrorMessage = $_.Exception.Message
                $DetailedErrorMessage = "When attempting to set the $($user.Attribute) attribute got error: $($_.Exception.InnerException.Message)"
                
                Write-Warning $ErrorMessage
                Write-Warning $DetailedErrorMessage

            } Finally {

                If($ErrorMessage){

                    $Results += [PSCustomObject]@{
                        DistinguishedName = $user.DistinguishedName
                        Success = $false
                        Attribute = "$($user.Attribute)" 
                        Result = $DetailedErrorMessage
                    }

                } else {

                    Write-Verbose "Disabling $($user.SamAccountName) and moving to Leavers OU"

                    $Results += [PSCustomObject]@{
                        DistinguishedName = $user.DistinguishedName
                        Success = $true
                        Attribute = "$($user.Attribute)" 
                        Result = "Updated"
                    }

                } 

            }



        }

    } # End IF

    Write-Output $results

} # End of Function
