<#
.SYNOPSIS
    General utility functions for Active Directory synchronisation

.DESCRIPTION
    This module contains utility functions used by the AD sync solution:
    - Send-Email: Email notification function for alerts and errors
    - Export-SourceUsers: Exports users from the Source (Enterprise) domain
    - Export-ProdUsers: Exports users from the Target (Production) domain
    
    These functions handle domain controller discovery, credential management,
    and user filtering for the synchronisation process.

.NOTES
    Author: Security Engineering Team
    Version: 1.0
    
    Prerequisites:
    - ActiveDirectory PowerShell module
    - SMTP relay configuration
    - Service account credentials
    - Network connectivity to both domains
    
.LINK
    https://github.com/yourusername/powershell-library
#>

#region Email Functions
# =============================================================================
# EMAIL NOTIFICATION FUNCTIONS
# =============================================================================

<#
.SYNOPSIS
    Sends email notifications for sync events and errors

.DESCRIPTION
    Sends email notifications using SMTP relay. Used for alerting on sync errors,
    threshold violations, and other important events.

.PARAMETER Message
    The message body to send

.PARAMETER Subject
    The email subject line

.EXAMPLE
    Send-Email -Message "Sync completed successfully" -Subject "ADSync - Success"
#>
function Send-Email {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $false)]
        [String]$Message,
        
        [Parameter(Mandatory = $true, ValueFromPipeline = $false)]
        [String]$Subject
    )

    #region Configuration
    # =============================================================================
    # EMAIL CONFIGURATION - Update for your environment
    # =============================================================================
    
    $From = "adsync@company.com"
    $To = "it-team@company.com"
    $SMTPServer = "smtp.company.com"
    $SMTPPort = 25
    
    #endregion Configuration

    #region Message Formatting
    # =============================================================================
    # FORMAT MESSAGE WITH ADDITIONAL INFORMATION
    # =============================================================================
    
    $AdditionalInfo = @"

Please refer to the troubleshooting documentation for further information on this issue.

This report was sent by a PowerShell script running on $($env:COMPUTERNAME) (C:\Scripts\ADSync).

Regards,
IT Operations Team
"@

    $FullMessage = $Message + $AdditionalInfo
    
    #endregion Message Formatting

    #region Send Email
    # =============================================================================
    # SEND THE EMAIL
    # =============================================================================
    
    try {
        Send-MailMessage -From $From -To $To -Subject $Subject -Body $FullMessage -SmtpServer $SMTPServer -Port $SMTPPort
        Write-Verbose "Email sent successfully to $To"
    }
    catch {
        Write-Warning "Failed to send email: $($_.Exception.Message)"
    }
    
    #endregion Send Email
}

#endregion Email Functions

#region Source Domain Functions
# =============================================================================
# SOURCE DOMAIN USER EXPORT FUNCTIONS
# =============================================================================

<#
.SYNOPSIS
    Exports user accounts from the Source (Enterprise) domain

.DESCRIPTION
    Connects to the Source domain and exports user accounts that should be
    synchronized to the Target domain. Includes filtering to exclude test
    accounts and service accounts.

.EXAMPLE
    $sourceUsers = Export-SourceUsers
    Gets all synchronizable users from the Source domain
#>
function Export-SourceUsers {
    [CmdletBinding()]
    param()

    #region Configuration
    # =============================================================================
    # SOURCE DOMAIN CONFIGURATION - Update for your environment
    # =============================================================================
    
    $SourceDomain = "source.enterprise.local"
    $SourceSearchBase = "OU=Accounts,DC=source,DC=enterprise,DC=local"
    $ServiceAccount = "source\svc-adsync"
    $CredentialFile = "C:\Scripts\ADSync\encrypt.txt"
    
    # Excluded Employee IDs (test/service accounts)
    $ExcludedEmployeeIDs = @('TEST001', 'TEST002', 'SVC001', 'SVC002')
    
    #endregion Configuration

    #region Domain Controller Discovery
    # =============================================================================
    # GET SOURCE DOMAIN CONTROLLER
    # =============================================================================
    
    try {
        [string]$SourceDomainController = (Get-ADDomainController -DomainName $SourceDomain -Discover -ErrorAction Stop).hostname
        Write-Verbose "Connected to Source domain controller: $SourceDomainController"
    }
    catch {
        $ErrorMessage = "Error connecting to Source Domain Controller"
        Write-Error $ErrorMessage
        throw $ErrorMessage
    }
    
    #endregion Domain Controller Discovery

    #region Attribute Definition
    # =============================================================================
    # DEFINE ATTRIBUTES TO RETRIEVE
    # =============================================================================
    
    $ADProperties = @(
        "SamAccountName",
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
        "l",                                      # City
        "co",                                     # Country
        "msDS-cloudExtensionAttribute1",
        "msDS-cloudExtensionAttribute2",
        "msDS-cloudExtensionAttribute3",
        "msDS-cloudExtensionAttribute6",
        "msDS-cloudExtensionAttribute7",
        "msDS-cloudExtensionAttribute10",
        "msDS-cloudExtensionAttribute11",
        "DistinguishedName"
    )
    
    #endregion Attribute Definition

    #region Filter Definition
    # =============================================================================
    # BUILD FILTER TO EXCLUDE UNWANTED ACCOUNTS
    # =============================================================================
    
    # Build filter to exclude specific Employee IDs
    $ExcludeFilter = ""
    foreach ($ExcludedID in $ExcludedEmployeeIDs) {
        if ($ExcludeFilter) {
            $ExcludeFilter += " -and "
        }
        $ExcludeFilter += "(EmployeeID -ne '$ExcludedID')"
    }
    
    $Filter = "((EmployeeID -like '*') -and $ExcludeFilter)"
    
    Write-Verbose "Using filter: $Filter"
    
    #endregion Filter Definition

    #region Query Parameters
    # =============================================================================
    # SETUP GET-ADUSER PARAMETERS
    # =============================================================================
    
    $Params = @{
        Filter      = $Filter
        SearchBase  = $SourceSearchBase
        SearchScope = "Subtree"
        Properties  = $ADProperties
        Server      = $SourceDomainController
        ErrorAction = "Stop"
    }
    
    #endregion Query Parameters

    #region Credential Management
    # =============================================================================
    # SETUP CREDENTIALS FOR SOURCE DOMAIN
    # =============================================================================
    
    try {
        if (Test-Path $CredentialFile) {
            $PwdTxt = Get-Content $CredentialFile
            $SecurePwd = $PwdTxt | ConvertTo-SecureString
            $Creds = New-Object System.Management.Automation.PSCredential -ArgumentList $ServiceAccount, $SecurePwd
            Write-Verbose "Loaded credentials for Source domain access"
        }
        else {
            Write-Warning "Credential file not found: $CredentialFile"
            Write-Warning "Attempting to use current user credentials"
            $Creds = $null
        }
    }
    catch {
        Write-Warning "Failed to load credentials: $($_.Exception.Message)"
        $Creds = $null
    }
    
    #endregion Credential Management

    #region User Retrieval
    # =============================================================================
    # RETRIEVE USERS FROM SOURCE DOMAIN
    # =============================================================================
    
    $Users = [System.Collections.ArrayList]@()
    
    try {
        Write-Verbose "Retrieving users from Source domain..."
        
        if ($Creds) {
            $Users = Get-ADUser @Params -Credential $Creds | Select-Object $ADProperties
        }
        else {
            $Users = Get-ADUser @Params | Select-Object $ADProperties
        }
        
        Write-Verbose "Retrieved $($Users.Count) users from Source domain"
    }
    catch {
        $ErrorMessage = "Error connecting to Source Domain [$SourceDomainController]: $($_.Exception.Message)"
        Write-Error $ErrorMessage
        throw $ErrorMessage
    }
    
    #endregion User Retrieval

    #region Result Processing
    # =============================================================================
    # PROCESS AND RETURN RESULTS
    # =============================================================================
    
    # Sort users by Employee ID for consistent processing
    $Users = $Users | Sort-Object EmployeeID
    
    Write-Verbose "Export-SourceUsers completed successfully"
    Write-Output $Users
    
    #endregion Result Processing
}

#endregion Source Domain Functions

#region Target Domain Functions
# =============================================================================
# TARGET DOMAIN USER EXPORT FUNCTIONS
# =============================================================================

<#
.SYNOPSIS
    Exports user accounts from the Target (Production) domain

.DESCRIPTION
    Connects to the Target domain and exports existing user accounts for comparison
    with Source domain users. Includes filtering to exclude test accounts and
    third-party accounts that should not be managed by the sync process.

.EXAMPLE
    $targetUsers = Export-ProdUsers
    Gets all managed users from the Target domain
#>
function Export-ProdUsers {
    [CmdletBinding()]
    param()

    #region Configuration
    # =============================================================================
    # TARGET DOMAIN CONFIGURATION - Update for your environment
    # =============================================================================
    
    $TargetDomain = "prod.local"
    $TargetSearchBase = "DC=prod,DC=local"
    
    # Account patterns to exclude from sync management
    $ExcludePatterns = @("test_*", "svc_*", "admin_*")
    
    #endregion Configuration

    #region Domain Controller Discovery
    # =============================================================================
    # GET TARGET DOMAIN CONTROLLER
    # =============================================================================
    
    try {
        [string]$TargetDomainController = (Get-ADDomainController -DomainName $TargetDomain -Discover -ErrorAction Stop).hostname
        Write-Verbose "Connected to Target domain controller: $TargetDomainController"
    }
    catch {
        $ErrorMessage = "Error connecting to Target Domain Controller"
        Write-Error $ErrorMessage
        throw $ErrorMessage
    }
    
    #endregion Domain Controller Discovery

    #region Attribute Definition
    # =============================================================================
    # DEFINE ATTRIBUTES TO RETRIEVE
    # =============================================================================
    
    $ADProperties = @(
        "SamAccountName",
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
        "l",                                      # City
        "co",                                     # Country
        "msDS-cloudExtensionAttribute1",
        "msDS-cloudExtensionAttribute2",
        "msDS-cloudExtensionAttribute3",
        "msDS-cloudExtensionAttribute6",
        "msDS-cloudExtensionAttribute7",
        "msDS-cloudExtensionAttribute10",
        "msDS-cloudExtensionAttribute11",
        "DistinguishedName",
        "Info"                                    # Include info field for Target domain
    )
    
    #endregion Attribute Definition

    #region Query Parameters
    # =============================================================================
    # SETUP GET-ADUSER PARAMETERS
    # =============================================================================
    
    $Params = @{
        Filter      = "EmployeeID -like '*'"
        SearchBase  = $TargetSearchBase
        Properties  = $ADProperties
        ErrorAction = "Stop"
    }
    
    #endregion Query Parameters

    #region User Retrieval
    # =============================================================================
    # RETRIEVE USERS FROM TARGET DOMAIN
    # =============================================================================
    
    $Users = [System.Collections.ArrayList]@()
    
    try {
        Write-Verbose "Retrieving users from Target domain..."
        
        $AllUsers = Get-ADUser @Params | Select-Object $ADProperties
        
        # Filter out test accounts, third-party accounts, and service accounts
        $FilteredUsers = $AllUsers | Where-Object {
            # Exclude accounts marked as test or third-party
            ($_.'msDS-cloudExtensionAttribute10' -ne 'Test Account') -and
            ($_.'msDS-cloudExtensionAttribute10' -ne 'Third Party') -and
            
            # Exclude accounts matching exclusion patterns
            (-not ($ExcludePatterns | Where-Object { $_.SamAccountName -like $_ }))
        }
        
        $Users = $FilteredUsers
        
        Write-Verbose "Retrieved $($Users.Count) managed users from Target domain (filtered from $($AllUsers.Count) total users)"
    }
    catch {
        $ErrorMessage = "Error connecting to Target Domain [$TargetDomainController]: $($_.Exception.Message)"
        Write-Error $ErrorMessage
        throw $ErrorMessage
    }
    
    #endregion User Retrieval

    #region Result Processing
    # =============================================================================
    # PROCESS AND RETURN RESULTS
    # =============================================================================
    
    # Sort users by Employee ID for consistent processing
    $Users = $Users | Sort-Object EmployeeID
    
    Write-Verbose "Export-ProdUsers completed successfully"
    Write-Output $Users
    
    #endregion Result Processing
}

#endregion Target Domain Functions

#region Module Exports
# =============================================================================
# EXPORT FUNCTIONS FOR MODULE USE
# =============================================================================

# Export functions for use by other scripts
Export-ModuleMember -Function Send-Email, Export-SourceUsers, Export-ProdUsers

#endregion Module Exports