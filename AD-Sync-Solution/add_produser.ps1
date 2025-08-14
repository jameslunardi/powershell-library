<#
.SYNOPSIS
    Creates new user accounts in the Target domain

.DESCRIPTION
    This function creates new user accounts in the Target domain based on users found in the Source domain.
    New accounts are created in a disabled state in the Inactive OU until manually activated.
    
    Features include:
    - Automatic password generation with complexity requirements
    - Unix/Linux attribute support (SFU)
    - Duplicate detection and automatic SamAccountName generation
    - Safety threshold to prevent mass account creation

.PARAMETER Data
    Array of user objects to be created. Each object must contain:
    - EmployeeID
    - SamAccountName
    - Additional user attributes (mail, GivenName, Surname, etc.)

.PARAMETER ReportOnly
    When $true, runs in report-only mode without making actual changes.
    Default: $true

.EXAMPLE
    Add-ProdUser -Data $usersToAdd -ReportOnly $true -Verbose
    Runs in report-only mode with verbose output

.EXAMPLE
    Add-ProdUser -Data $usersToAdd -ReportOnly $false
    Creates actual user accounts

.NOTES
    Author: Security Engineering Team
    Version: 1.0
    
    Safety Features:
    - Maximum addition threshold: 300 users per execution
    - Automatic duplicate detection
    - Complex password generation
    - Unix attribute management
    - Comprehensive error handling
    
.LINK
    https://github.com/yourusername/powershell-library
#>

function Add-ProdUser {
    [CmdletBinding(SupportsShouldProcess = $false, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ $_.EmployeeID -and $_.SamAccountName })]
        [Array[]]$Data,
        
        [Parameter(Mandatory = $false)]
        [bool]$ReportOnly = $true
    )

    #region Configuration
    # =============================================================================
    # CONFIGURATION SECTION
    # =============================================================================
    
    # Safety thresholds
    $AdditionThreshold = 300
    
    # Target domain configuration
    $TargetDomain = "prod.local"
    $InactiveOU = "OU=Inactive,OU=Users,OU=Quarantine,OU=TARGET,DC=prod,DC=local"
    $NISObjectDN = "CN=prod,CN=ypservers,CN=ypServ30,CN=RpcServices,CN=System,DC=prod,DC=local"
    
    # Unix/Linux configuration
    $DefaultGidNumber = "10001"
    $DefaultLoginShell = "/bin/bash"
    
    #endregion Configuration

    #region Initialization
    # =============================================================================
    # INITIALIZATION
    # =============================================================================
    
    $Results = [System.Collections.ArrayList]@()
    $AddCount = $Data.Count
    
    Write-Verbose "Add-ProdUser function started"
    Write-Verbose "Users to process: $AddCount"
    Write-Verbose "Addition threshold: $AdditionThreshold"
    Write-Verbose "Report Only mode: $ReportOnly"
    
    #endregion Initialization

    #region Password Generation
    # =============================================================================
    # SECURE PASSWORD GENERATION
    # =============================================================================
    
    function Get-RandomCharacters {
        param(
            [int]$Length,
            [string]$Characters
        )
        
        $Random = 1..$Length | ForEach-Object { Get-Random -Maximum $Characters.length }
        $private:ofs = ""
        return [String]$Characters[$Random]
    }
    
    function Get-RandomString {
        param([string]$InputString)
        
        $CharacterArray = $InputString.ToCharArray()
        $ScrambledStringArray = $CharacterArray | Get-Random -Count $CharacterArray.Length
        $OutputString = -join $ScrambledStringArray
        return $OutputString
    }
    
    # Generate complex password
    $Password = Get-RandomCharacters -Length 8 -Characters 'abcdefghiklmnoprstuvwxyz'
    $Password += Get-RandomCharacters -Length 4 -Characters 'ABCDEFGHKLMNOPRSTUVWXYZ'
    $Password += Get-RandomCharacters -Length 4 -Characters '1234567890'
    $Password += Get-RandomCharacters -Length 2 -Characters '!"§$%&/()=?}][{@#*+'
    
    $Password = Get-RandomString $Password
    $SecurePassword = ConvertTo-SecureString -String $Password -AsPlainText -Force
    
    Write-Verbose "Generated secure password for new accounts"
    
    #endregion Password Generation

    #region Safety Check
    # =============================================================================
    # SAFETY THRESHOLD CHECK
    # =============================================================================
    
    if ($AddCount -ge $AdditionThreshold) {
        Write-Verbose "Too many users are scheduled for addition - stopping process"
        Write-Verbose "Users that would be added:"
        
        foreach ($User in $Data) {
            Write-Verbose " - $($User.SamAccountName)"
        }
        
        $ErrorMessage = "Too many users are marked for creation [$AddCount]. Addition threshold is $AdditionThreshold"
        Write-Error $ErrorMessage
        throw $ErrorMessage
    }
    
    #endregion Safety Check

    #region Main Processing
    # =============================================================================
    # MAIN PROCESSING LOOP
    # =============================================================================
    
    if ($ReportOnly) {
        Write-Verbose "Report Only Mode - Target Sync Script - Adding Users - Processing $AddCount User(s)"
    }
    else {
        Write-Verbose "Target Sync Script - Adding Users - Processing $AddCount User(s)"
    }
    
    foreach ($User in $Data) {
        $ErrorMessage = $null
        $DetailedErrorMessage = $null
        
        Write-Verbose "Processing user: $($User.SamAccountName) (EmployeeID: $($User.EmployeeID))"
        
        #region Domain Controller Discovery
        # =========================================================================
        # GET TARGET DOMAIN CONTROLLER
        # =========================================================================
        
        try {
            [string]$TargetDomainController = (Get-ADDomainController -DomainName $TargetDomain -Discover -ErrorAction Stop).hostname
            Write-Verbose "Using domain controller: $TargetDomainController"
        }
        catch {
            Write-Verbose "Cannot get Target Domain Controller"
            throw "Cannot get Target Domain Controller"
        }
        
        #endregion Domain Controller Discovery

        #region Unix Attributes
        # =========================================================================
        # MANAGE UNIX/LINUX ATTRIBUTES
        # =========================================================================
        
        try {
            $NISObject = Get-ADObject $NISObjectDN -Properties * -Server $TargetDomainController
            $MaxUid = $NISObject.msSFU30MaxUidNumber
            $UpdateMaxUid = $MaxUid + 1
            Write-Verbose "Current max UID: $MaxUid, Next UID: $UpdateMaxUid"
        }
        catch {
            Write-Warning "Unable to retrieve Unix UID information"
            $MaxUid = 10000
            $UpdateMaxUid = $MaxUid + 1
        }
        
        #endregion Unix Attributes

        #region User Attribute Preparation
        # =========================================================================
        # PREPARE USER ATTRIBUTES
        # =========================================================================
        
        $SamAccountName = ($User.SamAccountName).ToLower()
        $UserPrincipalName = $SamAccountName + "@$TargetDomain"
        $Mail = ($User.mail).ToLower()
        $GivenName = $User.GivenName
        $Surname = $User.Surname
        $EmployeeID = $User.EmployeeID
        $AccountExpirationDate = $User.AccountExpirationDate
        $Title = $User.Title
        $Office = $User.Office
        $Department = $User.Department
        $Country = $User.co
        
        # Generate display name with number suffix if needed
        $Number = ([regex]::Matches($Mail, '\d')).value
        $FullName = $GivenName + " " + $Surname
        
        if ($Number) {
            $Name = $FullName + " " + $Number
        }
        else {
            $Name = $FullName
        }
        
        $Description = $FullName
        $DisplayName = $FullName
        
        # Create info field
        $DateTime = Get-Date
        $Info = "$DateTime - ADSync`r`nAccount created based on Source account. Account is disabled and in the Inactive OU until required.`r`n"
        
        #endregion User Attribute Preparation

        #region Other Attributes
        # =========================================================================
        # PREPARE OTHER ATTRIBUTES AND UNIX SETTINGS
        # =========================================================================
        
        $OtherAttributes = @{}
        
        # Standard attributes
        if ($User.co) { $OtherAttributes["co"] = $User.co }
        if ($Info) { $OtherAttributes["info"] = $Info }
        
        # Cloud extension attributes
        if ($User.'msDS-cloudExtensionAttribute1') { $OtherAttributes["msDS-cloudExtensionAttribute1"] = $User.'msDS-cloudExtensionAttribute1' }
        if ($User.'msDS-cloudExtensionAttribute2') { $OtherAttributes["msDS-cloudExtensionAttribute2"] = $User.'msDS-cloudExtensionAttribute2' }
        if ($User.'msDS-cloudExtensionAttribute3') { $OtherAttributes["msDS-cloudExtensionAttribute3"] = $User.'msDS-cloudExtensionAttribute3' }
        if ($User.'msDS-cloudExtensionAttribute6') { $OtherAttributes["msDS-cloudExtensionAttribute6"] = $User.'msDS-cloudExtensionAttribute6' }
        if ($User.'msDS-cloudExtensionAttribute7') { $OtherAttributes["msDS-cloudExtensionAttribute7"] = $User.'msDS-cloudExtensionAttribute7' }
        if ($User.'msDS-cloudExtensionAttribute10') { $OtherAttributes["msDS-cloudExtensionAttribute10"] = $User.'msDS-cloudExtensionAttribute10' }
        if ($User.'msDS-cloudExtensionAttribute11') { $OtherAttributes["msDS-cloudExtensionAttribute11"] = $User.'msDS-cloudExtensionAttribute11' }
        
        # Unix/Linux attributes (SFU)
        $OtherAttributes["msSFU30Name"] = $SamAccountName
        $OtherAttributes["msSFU30NisDomain"] = "prod"
        $OtherAttributes["uidNumber"] = $MaxUid
        $OtherAttributes["uid"] = $SamAccountName
        $OtherAttributes["unixHomeDirectory"] = "/home/" + $SamAccountName
        $OtherAttributes["loginShell"] = $DefaultLoginShell
        $OtherAttributes["gidNumber"] = $DefaultGidNumber
        
        #endregion Other Attributes

        #region New-ADUser Parameters
        # =========================================================================
        # PREPARE NEW-ADUSER PARAMETERS
        # =========================================================================
        
        $Params = @{
            SamAccountName           = $SamAccountName
            UserPrincipalName        = $UserPrincipalName
            EmailAddress             = $Mail
            AccountPassword          = $SecurePassword
            GivenName                = $GivenName
            Surname                  = $Surname
            EmployeeID               = $EmployeeID
            AccountExpirationDate    = $AccountExpirationDate
            Title                    = $Title
            Office                   = $Office
            Department               = $Department
            Description              = $FullName
            DisplayName              = $DisplayName
            Name                     = $Name
            ChangePasswordAtLogon    = $false
            Path                     = $InactiveOU
            Enabled                  = $false
            PasswordNeverExpires     = $false
            Server                   = $TargetDomainController
            ErrorAction              = "Stop"
            OtherAttributes          = $OtherAttributes
        }
        
        # Log parameters for debugging
        Write-Verbose "User creation parameters:"
        foreach ($Item in $Params.GetEnumerator()) {
            if ($Item.Name -eq "OtherAttributes") {
                foreach ($Attribute in $OtherAttributes.GetEnumerator()) {
                    Write-Verbose "  $($Attribute.Name): $($Attribute.Value)"
                }
            }
            elseif ($Item.Name -ne "AccountPassword") {
                Write-Verbose "  $($Item.Name): $($Item.Value)"
            }
        }
        
        #endregion New-ADUser Parameters

        #region Duplicate Checking
        # =========================================================================
        # CHECK FOR DUPLICATE ACCOUNTS
        # =========================================================================
        
        # Check for existing accounts with same mail or employee ID
        $MailEmployeeIDCheck = Get-ADUser -Filter { (EmailAddress -eq $Mail) -or (EmployeeID -eq $EmployeeID) } -Properties SamAccountName, EmailAddress, EmployeeID
        $SamAccountNameCheck = Get-ADUser -Filter { SamAccountName -eq $SamAccountName } -Properties SamAccountName, EmailAddress, EmployeeID
        
        if ($MailEmployeeIDCheck) {
            Write-Warning "Trying to create $SamAccountName, but a user already exists with the same Mail or EmployeeID:"
            Write-Warning "  SamAccountName: $($MailEmployeeIDCheck.SamAccountName)"
            Write-Warning "  EmailAddress: $($MailEmployeeIDCheck.EmailAddress)"
            Write-Warning "  EmployeeID: $($MailEmployeeIDCheck.EmployeeID)"
            
            $Results += [PSCustomObject]@{
                SamAccountName = $SamAccountName
                Success        = $false
                Result         = "Duplicate"
            }
            
            continue
        }
        
        # Handle SamAccountName conflicts
        if ($SamAccountNameCheck) {
            $Count = 1
            do {
                $NewSamAccountName = $SamAccountName + $Count.ToString("D2")
                $SamAccountNameLoopCheck = Get-ADUser -Filter { SamAccountName -eq $NewSamAccountName } -Properties SamAccountName, EmailAddress, EmployeeID
                
                Write-Warning "A user exists with SamAccountName: $SamAccountName"
                Write-Warning "Trying: $NewSamAccountName"
                
                $Count++
            } until (-not $SamAccountNameLoopCheck)
            
            # Update parameters with new SamAccountName
            $Params.SamAccountName = $NewSamAccountName
            $Params.UserPrincipalName = $NewSamAccountName + "@$TargetDomain"
            $OtherAttributes["msSFU30Name"] = $NewSamAccountName
            $OtherAttributes["uid"] = $NewSamAccountName
            $OtherAttributes["unixHomeDirectory"] = "/home/" + $NewSamAccountName
            $Params.OtherAttributes = $OtherAttributes
            
            Write-Verbose "Updated SamAccountName to: $NewSamAccountName"
        }
        
        #endregion Duplicate Checking

        #region User Creation
        # =========================================================================
        # CREATE THE USER ACCOUNT
        # =========================================================================
        
        try {
            if ($ReportOnly) {
                Write-Verbose "Creating user in Report Only Mode: $($Params.SamAccountName)"
                # In report-only mode, we don't actually create the user
                # New-ADUser @Params -WhatIf
            }
            else {
                Write-Verbose "Creating user: $($Params.SamAccountName)"
                New-ADUser @Params
            }
        }
        catch {
            $ErrorMessage = $_.Exception.Message
            $DetailedErrorMessage = "When attempting to create the Target account $($Params.SamAccountName), got error: $($_.Exception.InnerException.Message)"
            
            Write-Verbose $ErrorMessage
            Write-Verbose $DetailedErrorMessage
        }
        finally {
            if ($ErrorMessage) {
                $Results += [PSCustomObject]@{
                    SamAccountName = $Params.SamAccountName
                    Success        = $false
                    Result         = $DetailedErrorMessage
                }
            }
            else {
                Write-Verbose "$($Params.SamAccountName) - Has been created in Target domain"
                
                if ($SamAccountNameCheck) {
                    $Results += [PSCustomObject]@{
                        SamAccountName = $Params.SamAccountName
                        Success        = $true
                        Result         = "Created-NewSamAccountName"
                    }
                }
                else {
                    $Results += [PSCustomObject]@{
                        SamAccountName = $Params.SamAccountName
                        Success        = $true
                        Result         = "Created"
                    }
                }
            }
        }
        
        #endregion User Creation

        #region Update Unix UID Counter
        # =========================================================================
        # UPDATE UNIX UID COUNTER
        # =========================================================================
        
        if (-not $ErrorMessage) {
            try {
                if ($ReportOnly) {
                    Write-Verbose "Would update Unix UID counter to: $UpdateMaxUid"
                    Set-ADObject $NISObject -Replace @{msSFU30MaxUidNumber = $UpdateMaxUid } -WhatIf
                }
                else {
                    Write-Verbose "Updating Unix UID counter to: $UpdateMaxUid"
                    Set-ADObject $NISObject -Replace @{msSFU30MaxUidNumber = $UpdateMaxUid }
                }
            }
            catch {
                Write-Warning "Unable to update the AD msSFU30MaxUidNumber attribute: $($_.Exception.Message)"
            }
        }
        
        #endregion Update Unix UID Counter
    }
    
    #endregion Main Processing

    #region Completion
    # =============================================================================
    # COMPLETION
    # =============================================================================
    
    if ($ReportOnly) {
        Write-Verbose "ADSync Add Users Complete (Report Only)"
    }
    else {
        Write-Verbose "ADSync Add Users Complete"
    }
    
    Write-Output $Results
    
    #endregion Completion
}