<#
.SYNOPSIS
    Active Directory User Synchronization Script

.DESCRIPTION
    Part of an AD synchronization suite that maintains user accounts between 
    source and target domains. Handles user creation, updates, and removal 
    with safety thresholds and comprehensive logging.
    
    Add-TargetUser.ps1: 
    Creates new user accounts in the target domain with Unix attributes.

.AUTHOR
    James Lunardi
    https://www.linkedin.com/in/jameslunardi/

.VERSION
    1.0

.DATE
    June 2019
#>

Function Add-TargetUser {

    [CmdletBinding(SupportsShouldProcess=$False,ConfirmImpact='High')]
    Param(

        [Parameter(Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({$_.EmployeeID -and $_.SamAccountName})]
        [Array[]]$Data,
        [Parameter(Mandatory=$False)]
        $ReportOnly = $True

    )

    $results = [System.Collections.ArrayList]@()
    $addcount = $data.Count
    $addthreshold = 300

    function Get-RandomCharacters($length, $characters) {
    $random = 1..$length | ForEach-Object { Get-Random -Maximum $characters.length }
    $private:ofs=""
    return [String]$characters[$random]#
    }
        
    function Get-RandomString([string]$inputString){     
        $characterArray = $inputString.ToCharArray()   
        $scrambledStringArray = $characterArray | Get-Random -Count $characterArray.Length     
        $outputString = -join $scrambledStringArray
        return $outputString 
    }
        
    $password = Get-RandomCharacters -length 8 -characters 'abcdefghiklmnoprstuvwxyz'
    $password += Get-RandomCharacters -length 4 -characters 'ABCDEFGHKLMNOPRSTUVWXYZ'
    $password += Get-RandomCharacters -length 4 -characters '1234567890'
    $password += Get-RandomCharacters -length 2 -characters '!"§$%&/()=?}][{@#*+'
        
    $password = Get-RandomString $password
        
    $newpass = ConvertTo-SecureString -String $password -AsPlainText –Force

    # End Password Creation section

    If($addcount -ge $addthreshold){

        Write-Verbose "Too many users are going to be added, stopping process"

        ForEach($user in $data){

            Write-Verbose " - $($user.SamAccountName)"

        } # End ForEach

        Write-Verbose "Too many users are going to be created, stopping process"
        throw "Too many users are marked for creation [$addcount]. Add Threshold is $addthreshold"
        break

    } Else {

        If ($reportonly) {

            Write-Verbose "Report Only Mode - Target Sync Script - Adding Users - Processing $addcount User(s)"
            Write-Debug "Report Only Mode - Target Sync Script - Adding Users - Processing $addcount User(s)"

        } Else {

            Write-Verbose "Target Sync Script - Adding Users - Processing $addcount User(s)"
            Write-Debug "Target Sync Script - Adding Users - Processing $addcount User(s)"

        } # End If

        ForEach($user in $data){

            Try{

                [string]$TargetDomainController = (Get-ADDomainController -DomainName target.company.local -Discover -ErrorAction Stop).hostname

            } Catch {

                Write-Verbose "Cannot get Target Domain Controller"
                throw "Cannot get Target Domain Controller"
                break

            }

            $NIS = Get-ADObject "CN=target,CN=ypservers,CN=ypServ30,CN=RpcServices,CN=System,DC=target,DC=company,DC=local" -Properties:* -Server $TargetDomainController
            $maxUid = $NIS.msSFU30MaxUidNumber 
            $updatemaxuid = $maxUid +1
            $SamAccountName = ($user.SamAccountName).ToLower()
            $UserPrincipalName = $SamAccountName + "@target.company.local"
            $mail = ($user.mail).ToLower()
            $GivenName = $user.GivenName
            $Surname = $user.Surname
            $EmployeeID = $user.EmployeeID
            $AccountExpirationDate = $user.AccountExpirationDate
            $Title = $user.Title
            $Office = $user.Office
            $Department = $user.Department
            $Country = $user.co
            $DN = "OU=Inactive,OU=Users,OU=Quarantine,OU=Sync,DC=target,DC=company,DC=local"
            $datetime = Get-Date
            $info= "$datetime - ADSync`r`nAccount created based on Source account. Account is disabled and in the Inactive OU until required.`r`n"
            $number = ([regex]::Matches($mail, '\d')).value
            $fullName = $GivenName + " " + $Surname
            
            If($number){

                $name = $fullName + " " + $number

            } else {

                $name = $fullName

            }
            
            $Description = $fullname
            $DisplayName = $fullname
            
            $OtherAttributes = @{}
            If($user.co){$OtherAttributes["co"] = $user.co}
            If($info){$OtherAttributes["info"] = $info}
            If($user.'msDS-cloudExtensionAttribute1'){$OtherAttributes["msDS-cloudExtensionAttribute1"] = $user.'msDS-cloudExtensionAttribute1'}
            If($user.'msDS-cloudExtensionAttribute2'){$OtherAttributes["msDS-cloudExtensionAttribute2"] = $user.'msDS-cloudExtensionAttribute2'}
            If($user.'msDS-cloudExtensionAttribute3'){$OtherAttributes["msDS-cloudExtensionAttribute3"] = $user.'msDS-cloudExtensionAttribute3'}
            If($user.'msDS-cloudExtensionAttribute6'){$OtherAttributes["msDS-cloudExtensionAttribute6"] = $user.'msDS-cloudExtensionAttribute6'}
            If($user.'msDS-cloudExtensionAttribute7'){$OtherAttributes["msDS-cloudExtensionAttribute7"] = $user.'msDS-cloudExtensionAttribute7'}
            If($user.'msDS-cloudExtensionAttribute10'){$OtherAttributes["msDS-cloudExtensionAttribute10"] = $user.'msDS-cloudExtensionAttribute10'}
            If($user.'msDS-cloudExtensionAttribute11'){$OtherAttributes["msDS-cloudExtensionAttribute11"] = $user.'msDS-cloudExtensionAttribute11'}
            $OtherAttributes["msSFU30Name"] = $SamAccountName
            $OtherAttributes["msSFU30NisDomain"] = "target"
            $OtherAttributes["uidNumber"] = $maxUid
            $OtherAttributes["uid"] = $SamAccountName
            $OtherAttributes["unixHomeDirectory"] = "/home/" + $SamAccountName
            $OtherAttributes["loginShell"] = "/bin/bash"
            $OtherAttributes["gidNumber"] = "11337"

            $Params =@{ 
                SamAccountName = $SamAccountName;
                UserPrincipalName = $UserPrincipalName;
                EmailAddress = $mail;
                Accountpassword = $newpass;
                GivenName = $GivenName;
                Surname = $Surname;
                EmployeeID = $EmployeeID;
                AccountExpirationDate = $AccountExpirationDate;
                Title = $Title;
                Office = $Office;
                Department = $Department;
                Description = $fullName;
                DisplayName = $DisplayName;
                name = $name;
                ChangePasswordAtLogon = $False;
                path = $dn;
                Enabled = $False;
                PasswordNeverExpires = $False;
                Server = $TargetDomainController;
                ErrorAction = "Stop";
                OtherAttributes = $OtherAttributes;
            } # Params               

            ForEach ($item in $Params.GetEnumerator()) {
                
                If($item.Name -eq "OtherAttributes"){

                     ForEach ($attribute in $OtherAttributes.GetEnumerator()) {

                        Write-Verbose "$($attribute.Name): $($attribute.Value)"

                    }

                } Else {
                
                    Write-Verbose "$($item.Name): $($item.Value)"

                }
            
            }                  

            $MailEmployeeIDCheck = Get-ADUser -Filter{(EmailAddress -eq $mail) -or (EmployeeID -eq $EmployeeID)} -Properties SamAccountName,EmailAddress,EmployeeID
            $SamAccountNameCheck = Get-ADUser -Filter{SamAccountName -eq $SamAccountName} -Properties SamAccountName,EmailAddress,EmployeeID
            

            If($MailEmployeeIDCheck){
                  
                Write-Warning -Message "Trying to create $SamAccountName, a user already exists with the same Mail or EmployeeID:"
                Write-Warning -Message $MailEmployeeIDCheck.SamAccountName
                Write-Warning -Message $MailEmployeeIDCheck.EmailAddress
                Write-Warning -Message $MailEmployeeIDCheck.EmployeeID

                $Results += [PSCustomObject]@{
                    SamAccountName = $SamAccountName
                    Success = $false
                    Result = "Duplicate"
                }

            } else {

                if($SamAccountNameCheck) {

                    Do {

                        $count = 1
                        $newSamAccountName = $SamAccountName + $count.ToString("D2")

                        $SamAccountNameLoopCheck = Get-ADUser -Filter{SamAccountName -eq $newSamAccountName} -Properties SamAccountName,EmailAddress,EmployeeID
                    
                        Write-Warning -Message "A user exists with SamAccountName: $SamAccountName"
                        Write-Warning -Message "Trying: $newSamAccountName"

                    } Until(!$SamAccountNameLoopCheck)

                    $Params.SamAccountName = $newSamAccountName
                    $Params.UserPrincipalName = $newSamAccountName+ "@target.company.local"
                    $OtherAttributes["msSFU30Name"] = $newSamAccountName
                    $OtherAttributes["msSFU30NisDomain"] = "target"
                    $OtherAttributes["uidNumber"] = $maxUid
                    $OtherAttributes["unixHomeDirectory"] = "/home/" + $newSamAccountName
                    $OtherAttributes["loginShell"] = "/bin/bash"
                    $OtherAttributes["gidNumber"] = "1005546505"
                    $Params.OtherAttributes = $OtherAttributes

                }

                Try {
                
                    If ($reportonly) {

                        Write-Verbose "Creating user in ReadOnly Mode"
                        Write-Debug "Creating user in ReadOnly Mode"
                        New-ADUser @Params -WhatIf

                    } else {

                        Write-Verbose "Creating user"
                        Write-Debug "Creating user"
                        New-ADUser @Params

                    }

                } Catch {

                    $ErrorMessage = $_.Exception.Message
                    $DetailedErrorMessage = "When attempting to create the Target account $SamAccountName got error: $($_.Exception.InnerException.Message)"
            
                    Write-Verbose $ErrorMessage
                    Write-Verbose $DetailedErrorMessage

                    Break
                
                } Finally {

                    If($ErrorMessage){  

                        $Results += [PSCustomObject]@{
                            SamAccountName = $SamAccountName
                            Success = $false
                            Result = $DetailedErrorMessage
                        }

                    } else {

                        Write-Verbose "$SamAccountName - Has been created in Target"

                        If($SamAccountNameCheck){

                            $Results += [PSCustomObject]@{
                                SamAccountName = $SamAccountName
                                Success = $true
                                Result = "Created-NewSamAccountName"
                            }

                        } else {

                            $Results += [PSCustomObject]@{
                                SamAccountName = $SamAccountName
                                Success = $true
                                Result = "Created"
                            }

                        }


                    } # End If    

                } # End TryCatchFinally

                Try {

                    If ($reportonly) {

                        Set-ADObject $nis -Replace @{msSFU30MaxUidNumber=$updatemaxuid} -WhatIf

                    } else {

                        Set-ADObject $nis -Replace @{msSFU30MaxUidNumber=$updatemaxuid}

                    }
            
                } Catch {

                    Write-Verbose "Unable to update the AD msSFU30MaxGidNumber attribute."
                    throw "Unable to update the AD msSFU30MaxGidNumber attribute."
                    break

                }

            } # End IF

        } # End ForEach

    } # End If

    Write-Output $results

} # End Function
