<#
.SYNOPSIS
    AD Command Wrappers for Test Mode Support

.DESCRIPTION
    This module provides wrapper functions for Active Directory cmdlets that can operate in different modes:
    - Mock mode: Returns predefined mock data for unit testing
    - Integration mode: Uses real AD cmdlets with test domains
    - Production mode: Uses real AD cmdlets (default)

.NOTES
    Set $env:ADSYNC_TEST_MODE to control behavior:
    - "Mock" = Unit tests with mocks
    - "Integration" = Integration tests with live test AD
    - $null or unset = Production mode
#>

# Global mock data storage
$script:MockData = @{
    Users = @{
        'testuser1' = @{
            SamAccountName = 'testuser1'
            mail = 'testuser1@test.com'
            GivenName = 'Test'
            Surname = 'User1'
            EmployeeID = 'EMP001'
            Enabled = $true
            DistinguishedName = 'CN=testuser1,OU=Users,DC=test,DC=target,DC=local'
            ObjectGUID = [guid]::NewGuid()
        }
        'existinguser' = @{
            SamAccountName = 'existinguser'
            mail = 'testuser1@test.com'  # Duplicate email for testing
            EmployeeID = 'EMP999'        # Duplicate employee ID for testing
            Enabled = $true
            DistinguishedName = 'CN=existinguser,OU=Users,DC=test,DC=target,DC=local'
        }
    }
    DomainControllers = @{
        'test.source.local' = @{ hostname = 'test-source-dc.test.local' }
        'test.target.local' = @{ hostname = 'test-target-dc.test.local' }
    }
    NISObject = @{
        msSFU30MaxUidNumber = 50000
    }
    CallHistory = @()
}

function Reset-MockData {
    <#
    .SYNOPSIS
        Resets mock data to initial state for clean test runs
    #>
    $script:MockData.CallHistory = @()
    $script:MockData.NISObject.msSFU30MaxUidNumber = 50000
}

function Get-MockCallHistory {
    <#
    .SYNOPSIS
        Returns history of mocked AD command calls for test verification
    #>
    return $script:MockData.CallHistory
}

function Add-MockCall {
    param($Command, $Parameters)
    $script:MockData.CallHistory += @{
        Command = $Command
        Parameters = $Parameters
        Timestamp = Get-Date
    }
}

#region AD Command Wrappers

function Invoke-GetADUser {
    [CmdletBinding()]
    param(
        [string]$Identity,
        [string[]]$Properties,
        [string]$Server,
        [string]$SearchBase,
        [string]$Filter,
        [string]$SearchScope,
        [PSCredential]$Credential
    )
    
    switch ($env:ADSYNC_TEST_MODE) {
        "Mock" {
            Add-MockCall "Get-ADUser" $PSBoundParameters
            
            if ($Identity) {
                $mockUser = $script:MockData.Users[$Identity]
                if ($mockUser) {
                    return [PSCustomObject]$mockUser
                } else {
                    throw "Cannot find an object with identity: '$Identity'"
                }
            } elseif ($Filter) {
                # Simple mock filter logic for testing
                $results = @()
                
                # Parse common filter patterns used in the tests
                if ($Filter -match "EmailAddress -eq '([^']+)'") {
                    $emailToFind = $Matches[1]
                    foreach ($user in $script:MockData.Users.Values) {
                        if ($user.mail -eq $emailToFind) {
                            $results += [PSCustomObject]$user
                        }
                    }
                }
                elseif ($Filter -match "EmployeeID -eq '([^']+)'") {
                    $empIdToFind = $Matches[1]
                    foreach ($user in $script:MockData.Users.Values) {
                        if ($user.EmployeeID -eq $empIdToFind) {
                            $results += [PSCustomObject]$user
                        }
                    }
                }
                elseif ($Filter -match "SamAccountName -eq '([^']+)'") {
                    $samToFind = $Matches[1]
                    foreach ($user in $script:MockData.Users.Values) {
                        if ($user.SamAccountName -eq $samToFind) {
                            $results += [PSCustomObject]$user
                        }
                    }
                }
                elseif ($Filter -match "\(EmailAddress -eq '([^']+)'\) -or \(EmployeeID -eq '([^']+)'\)") {
                    $emailToFind = $Matches[1]
                    $empIdToFind = $Matches[2]
                    foreach ($user in $script:MockData.Users.Values) {
                        if ($user.mail -eq $emailToFind -or $user.EmployeeID -eq $empIdToFind) {
                            $results += [PSCustomObject]$user
                        }
                    }
                }
                
                return $results
            }
            return $null
        }
        "Integration" {
            # Use real AD cmdlets but log the call
            Add-MockCall "Get-ADUser" $PSBoundParameters
            return Get-ADUser @PSBoundParameters
        }
        default {
            # Production mode - direct call
            return Get-ADUser @PSBoundParameters
        }
    }
}

function Invoke-NewADUser {
    [CmdletBinding()]
    param(
        [string]$SamAccountName,
        [string]$Name,
        [string]$GivenName,
        [string]$Surname,
        [string]$UserPrincipalName,
        [string]$Path,
        [System.Security.SecureString]$AccountPassword,
        [hashtable]$OtherAttributes,
        [string]$Server,
        [bool]$Enabled = $false,
        [PSCredential]$Credential
    )
    
    switch ($env:ADSYNC_TEST_MODE) {
        "Mock" {
            Add-MockCall "New-ADUser" $PSBoundParameters
            # In mock mode, just record the call - don't actually create anything
            Write-Verbose "Mock: Would create user $SamAccountName"
            return $null
        }
        "Integration" {
            Add-MockCall "New-ADUser" $PSBoundParameters
            return New-ADUser @PSBoundParameters
        }
        default {
            return New-ADUser @PSBoundParameters
        }
    }
}

function Invoke-SetADUser {
    [CmdletBinding()]
    param(
        [string]$Identity,
        [hashtable]$Replace,
        [hashtable]$Add,
        [hashtable]$Remove,
        [string[]]$Clear,
        [string]$Server,
        [PSCredential]$Credential
    )
    
    switch ($env:ADSYNC_TEST_MODE) {
        "Mock" {
            Add-MockCall "Set-ADUser" $PSBoundParameters
            Write-Verbose "Mock: Would update user $Identity"
            return $null
        }
        "Integration" {
            Add-MockCall "Set-ADUser" $PSBoundParameters
            return Set-ADUser @PSBoundParameters
        }
        default {
            return Set-ADUser @PSBoundParameters
        }
    }
}

function Invoke-RemoveADUser {
    [CmdletBinding()]
    param(
        [string]$Identity,
        [string]$Server,
        [switch]$Confirm,
        [PSCredential]$Credential
    )
    
    switch ($env:ADSYNC_TEST_MODE) {
        "Mock" {
            Add-MockCall "Remove-ADUser" $PSBoundParameters
            Write-Verbose "Mock: Would remove user $Identity"
            return $null
        }
        "Integration" {
            Add-MockCall "Remove-ADUser" $PSBoundParameters
            return Remove-ADUser @PSBoundParameters
        }
        default {
            return Remove-ADUser @PSBoundParameters
        }
    }
}

function Invoke-MoveADObject {
    [CmdletBinding()]
    param(
        [string]$Identity,
        [string]$TargetPath,
        [string]$Server,
        [PSCredential]$Credential
    )
    
    switch ($env:ADSYNC_TEST_MODE) {
        "Mock" {
            Add-MockCall "Move-ADObject" $PSBoundParameters
            Write-Verbose "Mock: Would move $Identity to $TargetPath"
            return $null
        }
        "Integration" {
            Add-MockCall "Move-ADObject" $PSBoundParameters
            return Move-ADObject @PSBoundParameters
        }
        default {
            return Move-ADObject @PSBoundParameters
        }
    }
}

function Invoke-GetADObject {
    [CmdletBinding()]
    param(
        [string]$Identity,
        [string[]]$Properties,
        [string]$Server,
        [PSCredential]$Credential
    )
    
    switch ($env:ADSYNC_TEST_MODE) {
        "Mock" {
            Add-MockCall "Get-ADObject" $PSBoundParameters
            # Return mock NIS object for Unix UID queries
            if ($Identity -like "*ypservers*" -or $Identity -like "*NIS*") {
                return [PSCustomObject]$script:MockData.NISObject
            }
            return $null
        }
        "Integration" {
            Add-MockCall "Get-ADObject" $PSBoundParameters
            return Get-ADObject @PSBoundParameters
        }
        default {
            return Get-ADObject @PSBoundParameters
        }
    }
}

function Invoke-SetADObject {
    [CmdletBinding()]
    param(
        [string]$Identity,
        [hashtable]$Replace,
        [hashtable]$Add,
        [string]$Server,
        [PSCredential]$Credential
    )
    
    switch ($env:ADSYNC_TEST_MODE) {
        "Mock" {
            Add-MockCall "Set-ADObject" $PSBoundParameters
            # Update mock NIS object if this is a UID counter update
            if ($Identity -like "*ypservers*" -and $Replace -and $Replace.ContainsKey('msSFU30MaxUidNumber')) {
                $script:MockData.NISObject.msSFU30MaxUidNumber = $Replace['msSFU30MaxUidNumber']
                Write-Verbose "Mock: Updated UID counter to $($Replace['msSFU30MaxUidNumber'])"
            }
            return $null
        }
        "Integration" {
            Add-MockCall "Set-ADObject" $PSBoundParameters
            return Set-ADObject @PSBoundParameters
        }
        default {
            return Set-ADObject @PSBoundParameters
        }
    }
}

function Invoke-GetADDomainController {
    [CmdletBinding()]
    param(
        [string]$DomainName,
        [string]$Server,
        [switch]$Discover,
        [PSCredential]$Credential
    )
    
    switch ($env:ADSYNC_TEST_MODE) {
        "Mock" {
            Add-MockCall "Get-ADDomainController" $PSBoundParameters
            $mockDC = $script:MockData.DomainControllers[$DomainName]
            if ($mockDC) {
                return [PSCustomObject]$mockDC
            } else {
                throw "Cannot contact domain controller for domain '$DomainName'"
            }
        }
        "Integration" {
            Add-MockCall "Get-ADDomainController" $PSBoundParameters
            return Get-ADDomainController @PSBoundParameters
        }
        default {
            return Get-ADDomainController @PSBoundParameters
        }
    }
}

function Invoke-DisableADAccount {
    [CmdletBinding()]
    param(
        [string]$Identity,
        [string]$Server,
        [PSCredential]$Credential
    )
    
    switch ($env:ADSYNC_TEST_MODE) {
        "Mock" {
            Add-MockCall "Disable-ADAccount" $PSBoundParameters
            Write-Verbose "Mock: Would disable account $Identity"
            return $null
        }
        "Integration" {
            Add-MockCall "Disable-ADAccount" $PSBoundParameters
            return Disable-ADAccount @PSBoundParameters
        }
        default {
            return Disable-ADAccount @PSBoundParameters
        }
    }
}

function Invoke-SetADAccountExpiration {
    [CmdletBinding()]
    param(
        [string]$Identity,
        [DateTime]$DateTime,
        [string]$Server,
        [PSCredential]$Credential
    )
    
    switch ($env:ADSYNC_TEST_MODE) {
        "Mock" {
            Add-MockCall "Set-ADAccountExpiration" $PSBoundParameters
            Write-Verbose "Mock: Would set account expiration for $Identity to $DateTime"
            return $null
        }
        "Integration" {
            Add-MockCall "Set-ADAccountExpiration" $PSBoundParameters
            return Set-ADAccountExpiration @PSBoundParameters
        }
        default {
            return Set-ADAccountExpiration @PSBoundParameters
        }
    }
}

function Invoke-ClearADAccountExpiration {
    [CmdletBinding()]
    param(
        [string]$Identity,
        [string]$Server,
        [PSCredential]$Credential
    )
    
    switch ($env:ADSYNC_TEST_MODE) {
        "Mock" {
            Add-MockCall "Clear-ADAccountExpiration" $PSBoundParameters
            Write-Verbose "Mock: Would clear account expiration for $Identity"
            return $null
        }
        "Integration" {
            Add-MockCall "Clear-ADAccountExpiration" $PSBoundParameters
            return Clear-ADAccountExpiration @PSBoundParameters
        }
        default {
            return Clear-ADAccountExpiration @PSBoundParameters
        }
    }
}

function Invoke-RemoveADGroupMember {
    [CmdletBinding()]
    param(
        [string]$Identity,
        [string[]]$Members,
        [string]$Server,
        [switch]$Confirm,
        [PSCredential]$Credential
    )
    
    switch ($env:ADSYNC_TEST_MODE) {
        "Mock" {
            Add-MockCall "Remove-ADGroupMember" $PSBoundParameters
            Write-Verbose "Mock: Would remove $($Members -join ',') from group $Identity"
            return $null
        }
        "Integration" {
            Add-MockCall "Remove-ADGroupMember" $PSBoundParameters
            return Remove-ADGroupMember @PSBoundParameters
        }
        default {
            return Remove-ADGroupMember @PSBoundParameters
        }
    }
}

#endregion AD Command Wrappers

# Note: Export-ModuleMember not needed when dot-sourcing
# Functions are available in the global scope when dot-sourced