<#
.SYNOPSIS
    Active Directory User Synchronization Script

.DESCRIPTION
    Part of an AD synchronization suite that maintains user accounts between 
    source and target domains. Handles user creation, updates, and removal 
    with safety thresholds and comprehensive logging.
    
    General-Functions.ps1:
    Shared functions for email notifications and user data export.

.AUTHOR
    James Lunardi
    https://www.linkedin.com/in/jameslunardi/

.VERSION
    1.0

.DATE
    June 2019
#>

Function Send-Email {

    [CmdletBinding()]
    Param(

        [Parameter(Mandatory=$True,ValueFromPipeline=$False)]
        [String]$Message,

        [Parameter(Mandatory=$True,ValueFromPipeline=$False)]
        [String]$Subject

    )

    $From = "adsync@company.local"
    $To = "dl-itsecurity@company.local"
    $SMTPServer = "mail-relay01"
    $SMTPPort = 25

    $Message = $Message + "`n`nPlease refer to the troubleshooting section at https://wiki.company.local/ad-sync-troubleshooting for further information on this issue. `n`n`n`nThis report was sent to you by a PowerShell script running on mgmt-server01 (C:\Scripts\ADSync). `n`nWarm regards,`nSecurity Engineering Team"

    Send-MailMessage -From $From -to $To -Subject $Subject -Body $Message -SmtpServer $SMTPServer -port $SMTPPort 

} # End 

Function Export-SourceUsers {

    Try{
        [string]$SourceDomainController = (Get-ADDomainController -DomainName source.company.local -Discover -ErrorAction Stop).hostname
    } Catch {
        Throw "Error connecting to Source Domain Controller to get the users from."
        Break
    }

    $ADProperties = "SamAccountName",
                    "mail",
                    "GivenName",
                    "Surname",
                    "EmployeeID",
                    "Enabled",
                    "AccountExpirationDate",
                    "Title",
                    "Office",
                    "ObjectGUID",
                    "Department",
                    "l",
                    "co",
                    "msDS-cloudExtensionAttribute1",
                    "msDS-cloudExtensionAttribute2",
                    "msDS-cloudExtensionAttribute3",
                    "msDS-cloudExtensionAttribute6",
                    "msDS-cloudExtensionAttribute7",
                    "msDS-cloudExtensionAttribute10",
                    "msDS-cloudExtensionAttribute11",
                    "DistinguishedName"
                        
    $Params =@{ 
        Filter = "((EmployeeID -like '*') -and (EmployeeID -ne '111111')  -and (EmployeeID -ne '111112') -and (EmployeeID -ne '111113') -and (EmployeeID -ne '111114'))";
        SearchBase = "OU=Accounts,DC=source,DC=company,DC=local";
        SearchScope = "Subtree";
        Properties = $ADProperties;
        Server = $SourceDomainController;
        ErrorAction = "Stop"
    } # Params

    $Users = [System.Collections.ArrayList]@()

    $username = "source\svc-adsync"
    $pwdTxt = Get-Content "C:\Scripts\ADSync\encrypt.txt"
    $securePwd = $pwdTxt | ConvertTo-SecureString 
    $creds = New-Object System.Management.Automation.PSCredential -ArgumentList $username, $securePwd

    Try{
        $Users = Get-ADUser @Params -Credential $creds | Select-Object $ADProperties
    } Catch {
        Throw "Error connecting to Source Domain [$SourceDomainController]"
        Break
    } # Try/Catch

    $users = $Users | Sort-Object EmployeeID
    
    Write-Output $Users

} # Function

Function Export-TargetUsers {

    Try{
        [string]$TargetDomainController = (Get-ADDomainController -DomainName target.company.local -Discover -ErrorAction Stop).hostname
    } Catch {
        Throw "Error connecting to Target Domain Controller to get the users from."
        Break
    }

    $ADProperties = "SamAccountName",
                    "mail",
                    "GivenName",
                    "Surname",
                    "EmployeeID",
                    "Enabled",
                    "AccountExpirationDate",
                    "Title",
                    "Office",
                    "ObjectGUID",
                    "Department",
                    "l",
                    "co",
                    "msDS-cloudExtensionAttribute1",
                    "msDS-cloudExtensionAttribute2",
                    "msDS-cloudExtensionAttribute3",
                    "msDS-cloudExtensionAttribute6",
                    "msDS-cloudExtensionAttribute7",
                    "msDS-cloudExtensionAttribute10",
                    "msDS-cloudExtensionAttribute11",
                    "DistinguishedName",
                    "Info"    
    $Params =@{ 
        Filter = "EmployeeID -like '*'";
        SearchBase = "DC=target,DC=company,DC=local";
        Properties = $ADProperties;
        ErrorAction = "Stop"
    } # Params

    $Users = [System.Collections.ArrayList]@()

    Try{
        $Users = Get-ADUser @Params | Where-Object{($_.'msDS-cloudExtensionAttribute10' -ne 'Test Account') -and ($_.'msDS-cloudExtensionAttribute10' -ne 'Third Party') -and ($_.EmployeeID -notlike "tsg_*")} | Select-Object $ADProperties
    } Catch {
        Throw "Error connecting to Target Domain [$TargetDomainController]"
        Break
    } # Try/Catch

    $users = $Users | Sort-Object EmployeeID
    
    Write-Output $Users

} # Function
