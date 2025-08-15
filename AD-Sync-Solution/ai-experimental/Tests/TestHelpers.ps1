<#
.SYNOPSIS
    Test helper functions and mock data for AD-Sync-Solution tests

.DESCRIPTION
    Provides common test utilities, mock objects, and helper functions
    used across multiple test files.
#>

#region Mock Data Generators
# =============================================================================
# MOCK DATA GENERATION FUNCTIONS
# =============================================================================

<#
.SYNOPSIS
    Creates mock user objects for testing

.PARAMETER Count
    Number of users to create

.PARAMETER Prefix
    Prefix for usernames (default: "testuser")

.PARAMETER Domain
    Domain for email addresses (default: "test.com")
#>
function New-MockUser {
    [CmdletBinding()]
    param(
        [int]$Count = 1,
        [string]$Prefix = "testuser",
        [string]$Domain = "test.com",
        [switch]$IncludeTargetAttributes
    )
    
    $users = 1..$Count | ForEach-Object {
        $user = @{
            SamAccountName = "$Prefix$_"
            mail = "$Prefix$_@$Domain"
            GivenName = "Test"
            Surname = "User$_"
            EmployeeID = "EMP$($_.ToString('000'))"
            Enabled = $true
            AccountExpirationDate = $null
            Title = "Test Title $_"
            Office = "Test Office $_"
            ObjectGUID = [System.Guid]::NewGuid()
            Department = "IT"
            l = "Test City"
            co = "US"
            DistinguishedName = "CN=$Prefix$_,OU=Users,DC=test,DC=local"
            'msDS-cloudExtensionAttribute1' = "TestValue1_$_"
            'msDS-cloudExtensionAttribute2' = "TestValue2_$_"
            'msDS-cloudExtensionAttribute3' = "TestValue3_$_"
            'msDS-cloudExtensionAttribute6' = "TestValue6_$_"
            'msDS-cloudExtensionAttribute7' = "TestValue7_$_"
            'msDS-cloudExtensionAttribute10' = $null
            'msDS-cloudExtensionAttribute11' = "TestValue11_$_"
        }
        
        if ($IncludeTargetAttributes) {
            $user['Info'] = "Test info for user $_"
        }
        
        return $user
    }
    
    if ($Count -eq 1) {
        return $users[0]
    }
    return $users
}

<#
.SYNOPSIS
    Creates mock update objects for testing

.PARAMETER Users
    Array of users to create updates for

.PARAMETER Attributes
    Array of attributes to update
#>
function New-MockUpdate {
    [CmdletBinding()]
    param(
        [array]$Users,
        [string[]]$Attributes = @("mail", "Title", "Department")
    )
    
    $updates = @()
    
    foreach ($user in $Users) {
        foreach ($attribute in $Attributes) {
            $updates += @{
                DistinguishedName = $user.DistinguishedName
                SamAccountName = $user.SamAccountName
                Attribute = $attribute
                NewValue = "New$attribute"
                OldValue = "Old$attribute"
            }
        }
    }
    
    return $updates
}

<#
.SYNOPSIS
    Creates a mock configuration object for testing
#>
function New-MockConfig {
    [CmdletBinding()]
    param(
        [string]$ScriptRoot = "C:\TestScripts\ADSync",
        [int]$DeletionThreshold = 5,
        [int]$AdditionThreshold = 10,
        [int]$UpdateThreshold = 15
    )
    
    return @{
        General = @{
            ScriptRoot = $ScriptRoot
            LogPath = "$ScriptRoot\Logs"
            CredentialFile = "$ScriptRoot\encrypt.txt"
        }
        SafetyThresholds = @{
            DeletionThreshold = $DeletionThreshold
            AdditionThreshold = $AdditionThreshold
            UpdateThreshold = $UpdateThreshold
        }
        SourceDomain = @{
            DomainName = "test.source.local"
            SearchBase = "OU=TestAccounts,DC=test,DC=source,DC=local"
            ServiceAccount = "test\svc-testsync"
            ExcludedEmployeeIDs = @("TEST001", "TEST002")
        }
        TargetDomain = @{
            DomainName = "test.target.local"
            SearchBase = "DC=test,DC=target,DC=local"
            InactiveOU = "OU=Inactive,OU=Users,OU=Test,DC=test,DC=target,DC=local"
            LeaversOU = "OU=Leavers,OU=Users,OU=Test,DC=test,DC=target,DC=local"
            QuarantineSearchBase = "OU=Users,OU=Test,DC=test,DC=target,DC=local"
            NISObjectDN = "CN=test,CN=ypservers,CN=ypServ30,CN=RpcServices,CN=System,DC=test,DC=target,DC=local"
            ExcludePatterns = @("test_*", "svc_*")
        }
        UnixConfiguration = @{
            DefaultGidNumber = "20001"
            DefaultLoginShell = "/bin/bash"
            NisDomain = "test"
        }
        EmailConfiguration = @{
            From = "testsync@test.com"
            To = "testteam@test.com"
            SMTPServer = "smtp.test.com"
            SMTPPort = 25
        }
        UserAttributes = @{
            StandardAttributes = @(
                "SamAccountName", "mail", "GivenName", "Surname", "EmployeeID",
                "Enabled", "AccountExpirationDate", "Title", "Office", "ObjectGUID",
                "Department", "l", "co", "DistinguishedName"
            )
            CloudExtensionAttributes = @(
                "msDS-cloudExtensionAttribute1", "msDS-cloudExtensionAttribute2",
                "msDS-cloudExtensionAttribute3", "msDS-cloudExtensionAttribute6",
                "msDS-cloudExtensionAttribute7", "msDS-cloudExtensionAttribute10",
                "msDS-cloudExtensionAttribute11"
            )
            TargetOnlyAttributes = @("Info")
        }
    } | ConvertTo-Json -Depth 10 | ConvertFrom-Json
}

#endregion Mock Data Generators

#region Test Utilities
# =============================================================================
# TEST UTILITY FUNCTIONS
# =============================================================================

<#
.SYNOPSIS
    Sets up common mocks for Active Directory cmdlets
#>
function Set-ADMocks {
    [CmdletBinding()]
    param()
    
    Mock Get-ADDomainController { 
        return @{ hostname = "test-dc.test.local" }
    } -ModuleName * -Scope Global
    
    Mock Get-ADUser { 
        return @()
    } -ModuleName * -Scope Global
    
    Mock New-ADUser { } -ModuleName * -Scope Global
    Mock Set-ADUser { } -ModuleName * -Scope Global
    Mock Remove-ADUser { } -ModuleName * -Scope Global
    Mock Move-ADObject { } -ModuleName * -Scope Global
    Mock Disable-ADAccount { } -ModuleName * -Scope Global
    Mock Set-ADAccountExpiration { } -ModuleName * -Scope Global
    Mock Clear-ADAccountExpiration { } -ModuleName * -Scope Global
    Mock Remove-ADGroupMember { } -ModuleName * -Scope Global
    Mock Get-ADObject { 
        return @{ msSFU30MaxUidNumber = 50000 }
    } -ModuleName * -Scope Global
    Mock Set-ADObject { } -ModuleName * -Scope Global
    Mock Search-ADAccount { return @() } -ModuleName * -Scope Global
}

<#
.SYNOPSIS
    Sets up common mocks for email and logging functions
#>
function Set-CommonMocks {
    [CmdletBinding()]
    param()
    
    Mock Send-MailMessage { } -ModuleName * -Scope Global
    Mock Write-Host { } -ModuleName * -Scope Global
    Mock Write-Verbose { } -ModuleName * -Scope Global
    Mock Write-Warning { } -ModuleName * -Scope Global
    Mock Write-Error { } -ModuleName * -Scope Global
    Mock Start-Transcript { } -ModuleName * -Scope Global
    Mock Stop-Transcript { } -ModuleName * -Scope Global
    Mock Export-Csv { } -ModuleName * -Scope Global
    Mock Start-Sleep { } -ModuleName * -Scope Global
    Mock Test-Path { return $true } -ModuleName * -Scope Global
    Mock Get-Content { return "encryptedpassword" } -ModuleName * -Scope Global
    Mock ConvertTo-SecureString { 
        return (ConvertTo-SecureString "password" -AsPlainText -Force) 
    } -ModuleName * -Scope Global
    Mock New-Object { 
        param($TypeName, $ArgumentList)
        if ($TypeName -eq "System.Management.Automation.PSCredential") {
            return [PSCredential]::new("testuser", (ConvertTo-SecureString "password" -AsPlainText -Force))
        }
    } -ParameterFilter { $TypeName -eq "System.Management.Automation.PSCredential" } -ModuleName * -Scope Global
}

<#
.SYNOPSIS
    Validates that a mock was called with expected parameters
#>
function Assert-MockCalled {
    [CmdletBinding()]
    param(
        [string]$CommandName,
        [scriptblock]$ParameterFilter,
        [int]$Times = 1,
        [string]$Because = "Expected mock to be called"
    )
    
    try {
        Should -Invoke $CommandName -Times $Times -ParameterFilter $ParameterFilter -Because $Because
    }
    catch {
        Write-Host "Mock assertion failed for $CommandName" -ForegroundColor Red
        Write-Host "Expected: $Times calls" -ForegroundColor Red
        Write-Host "Filter: $($ParameterFilter.ToString())" -ForegroundColor Red
        throw
    }
}

<#
.SYNOPSIS
    Creates a temporary test directory
#>
function New-TestDirectory {
    [CmdletBinding()]
    param(
        [string]$BasePath = $(if ($IsLinux -or $IsMacOS) { "/tmp" } else { $env:TEMP }),
        [string]$Prefix = "ADSyncTest"
    )
    
    $testDir = Join-Path $BasePath "$Prefix`_$(Get-Random)"
    New-Item -Path $testDir -ItemType Directory -Force | Out-Null
    return $testDir
}

<#
.SYNOPSIS
    Removes a test directory and all contents
#>
function Remove-TestDirectory {
    [CmdletBinding()]
    param(
        [string]$Path
    )
    
    if (Test-Path $Path) {
        Remove-Item $Path -Recurse -Force -ErrorAction SilentlyContinue
    }
}

<#
.SYNOPSIS
    Validates user comparison logic results
#>
function Test-UserComparison {
    [CmdletBinding()]
    param(
        [array]$SourceUsers,
        [array]$TargetUsers,
        [array]$ExpectedAdds,
        [array]$ExpectedUpdates,
        [array]$ExpectedRemoves
    )
    
    # This would contain the actual comparison logic
    # For now, it's a placeholder that could be used to test
    # the user matching and comparison algorithms
    
    $results = @{
        ToAdd = @()
        ToUpdate = @()
        ToRemove = @()
    }
    
    # Find users to add (in source but not in target)
    foreach ($sourceUser in $SourceUsers) {
        $match = $TargetUsers | Where-Object { $_.EmployeeID -eq $sourceUser.EmployeeID }
        if (-not $match) {
            $results.ToAdd += $sourceUser
        }
    }
    
    # Find users to remove (in target but not in source)
    foreach ($targetUser in $TargetUsers) {
        $match = $SourceUsers | Where-Object { $_.EmployeeID -eq $targetUser.EmployeeID }
        if (-not $match) {
            $results.ToRemove += $targetUser
        }
    }
    
    return $results
}

#endregion Test Utilities

#region Assertion Helpers
# =============================================================================
# CUSTOM ASSERTION HELPERS
# =============================================================================

<#
.SYNOPSIS
    Asserts that a collection has the expected count
#>
function Assert-CollectionCount {
    [CmdletBinding()]
    param(
        [array]$Collection,
        [int]$ExpectedCount,
        [string]$Because = "Collection should have expected count"
    )
    
    if ($null -eq $Collection) {
        $actualCount = 0
    } else {
        $actualCount = $Collection.Count
    }
    
    $actualCount | Should -Be $ExpectedCount -Because $Because
}

<#
.SYNOPSIS
    Asserts that a user object has expected properties
#>
function Assert-UserObject {
    [CmdletBinding()]
    param(
        [object]$User,
        [hashtable]$ExpectedProperties
    )
    
    $User | Should -Not -BeNullOrEmpty -Because "User object should not be null"
    
    foreach ($property in $ExpectedProperties.Keys) {
        $User.$property | Should -Be $ExpectedProperties[$property] -Because "Property $property should match expected value"
    }
}

<#
.SYNOPSIS
    Asserts that a result object indicates success
#>
function Assert-OperationSuccess {
    [CmdletBinding()]
    param(
        [object]$Result,
        [string]$ExpectedResult = $null
    )
    
    $Result | Should -Not -BeNullOrEmpty -Because "Result should not be null"
    $Result.Success | Should -Be $true -Because "Operation should succeed"
    
    if ($ExpectedResult) {
        $Result.Result | Should -Be $ExpectedResult -Because "Result message should match expected"
    }
}

<#
.SYNOPSIS
    Asserts that a result object indicates failure
#>
function Assert-OperationFailure {
    [CmdletBinding()]
    param(
        [object]$Result,
        [string]$ExpectedErrorPattern = $null
    )
    
    $Result | Should -Not -BeNullOrEmpty -Because "Result should not be null"
    $Result.Success | Should -Be $false -Because "Operation should fail"
    
    if ($ExpectedErrorPattern) {
        $Result.Result | Should -Match $ExpectedErrorPattern -Because "Error message should match expected pattern"
    }
}

#endregion Assertion Helpers

# Export functions for use in tests (only when loaded as module)
if ($MyInvocation.MyCommand.CommandType -eq 'ExternalScript') {
    # When dot-sourced, functions are automatically available
} else {
    Export-ModuleMember -Function New-MockUser, New-MockUpdate, New-MockConfig, Set-ADMocks, Set-CommonMocks, 
                                  Assert-MockCalled, New-TestDirectory, Remove-TestDirectory, Test-UserComparison,
                                  Assert-CollectionCount, Assert-UserObject, Assert-OperationSuccess, Assert-OperationFailure
}