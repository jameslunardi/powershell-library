<#
.SYNOPSIS
    Integration tests for Add-ProdUser function using live AD

.DESCRIPTION  
    These tests run against real Active Directory environments and are designed to test
    the Add-ProdUser function with actual AD cmdlets rather than mocks.
    
    Requirements:
    - Access to test AD domains specified in IntegrationTestConfig.json
    - AD PowerShell module
    - Appropriate permissions for user creation
    
.NOTES
    These tests should be run in a test environment only, never production!
#>

BeforeAll {
    # Set integration test mode
    $env:ADSYNC_TEST_MODE = "Integration"
    
    # Import the function under test
    $ModulePath = Join-Path $PSScriptRoot "..\add_produser.ps1"
    . $ModulePath
    
    # Load integration test configuration (separate from unit test config)
    $IntegrationConfigPath = Join-Path $PSScriptRoot "IntegrationTestConfig.json"
    if (Test-Path $IntegrationConfigPath) {
        $IntegrationConfig = Get-Content $IntegrationConfigPath | ConvertFrom-Json
    } else {
        Write-Warning "Integration test config not found. Skipping integration tests."
        return
    }
    
    # Reset mock data and verify we can connect to test domains
    Reset-MockData
    
    # Test connectivity to domains before running tests
    try {
        $SourceDC = Get-ADDomainController -DomainName $IntegrationConfig.SourceDomain.DomainName -Discover
        $TargetDC = Get-ADDomainController -DomainName $IntegrationConfig.TargetDomain.DomainName -Discover
        Write-Host "Successfully connected to test domains: $($SourceDC.hostname), $($TargetDC.hostname)"
    }
    catch {
        Write-Warning "Cannot connect to test domains. Skipping integration tests: $($_.Exception.Message)"
        return
    }
    
    # Create test user data for integration tests
    $script:IntegrationTestUsers = @(
        @{
            SamAccountName = "integtest001"
            mail = "integtest001@integration.test"
            GivenName = "Integration"
            Surname = "Test001" 
            EmployeeID = "INT001"
            Enabled = $false  # Always create as disabled in test
            AccountExpirationDate = $null
            Title = "Integration Test User"
            Office = "Test Lab"
            Department = "QA"
            co = "US"
        }
    )
}

AfterAll {
    # Clean up integration test mode
    $env:ADSYNC_TEST_MODE = $null
    
    # Cleanup: Remove any test users created during integration tests
    if ($script:IntegrationTestUsers -and $IntegrationConfig) {
        foreach ($testUser in $script:IntegrationTestUsers) {
            try {
                $existingUser = Get-ADUser -Identity $testUser.SamAccountName -ErrorAction SilentlyContinue
                if ($existingUser) {
                    Remove-ADUser -Identity $testUser.SamAccountName -Confirm:$false
                    Write-Verbose "Cleaned up test user: $($testUser.SamAccountName)"
                }
            }
            catch {
                Write-Warning "Failed to cleanup test user $($testUser.SamAccountName): $($_.Exception.Message)"
            }
        }
    }
}

Describe "Add-ProdUser Integration Tests" -Tag "Integration" {
    
    BeforeEach {
        # Skip if integration config is not available
        if (-not $IntegrationConfig) {
            Set-ItResult -Skipped -Because "Integration test configuration not available"
        }
        
        # Clean up any existing test users before each test
        foreach ($testUser in $script:IntegrationTestUsers) {
            try {
                $existingUser = Get-ADUser -Identity $testUser.SamAccountName -ErrorAction SilentlyContinue
                if ($existingUser) {
                    Remove-ADUser -Identity $testUser.SamAccountName -Confirm:$false
                }
            }
            catch {
                # User doesn't exist, which is fine
            }
        }
    }
    
    Context "When creating users in live AD environment" {
        
        It "Should create test user successfully in live AD" {
            # Run the actual function against live AD
            $result = Add-ProdUser -Data $IntegrationTestUsers -ReportOnly $false -Config $IntegrationConfig
            
            # Verify the result
            $result | Should -Not -BeNullOrEmpty
            $result[0].Success | Should -Be $true
            $result[0].Result | Should -Match "Created"
            
            # Verify the user actually exists in AD
            $createdUser = Get-ADUser -Identity $IntegrationTestUsers[0].SamAccountName
            $createdUser | Should -Not -BeNullOrEmpty
            $createdUser.GivenName | Should -Be $IntegrationTestUsers[0].GivenName
            $createdUser.Surname | Should -Be $IntegrationTestUsers[0].Surname
            $createdUser.Enabled | Should -Be $false  # Should be disabled by default
        }
        
        It "Should respect ReportOnly mode in live environment" {
            # Run in report-only mode
            $result = Add-ProdUser -Data $IntegrationTestUsers -ReportOnly $true -Config $IntegrationConfig
            
            # Should return results but not create actual users
            $result | Should -Not -BeNullOrEmpty
            $result[0].Result | Should -Match "Report Only"
            
            # Verify no user was actually created
            { Get-ADUser -Identity $IntegrationTestUsers[0].SamAccountName } | Should -Throw
        }
        
        It "Should handle duplicate user scenarios in live AD" {
            # First, create a user
            $firstResult = Add-ProdUser -Data $IntegrationTestUsers -ReportOnly $false -Config $IntegrationConfig
            $firstResult[0].Success | Should -Be $true
            
            # Try to create the same user again - should detect duplicate
            $duplicateResult = Add-ProdUser -Data $IntegrationTestUsers -ReportOnly $false -Config $IntegrationConfig
            $duplicateResult[0].Success | Should -Be $false
            $duplicateResult[0].Result | Should -Match "duplicate|already exists"
        }
    }
    
    Context "When testing Unix attributes in live AD" {
        
        It "Should set Unix attributes correctly in live AD" {
            $result = Add-ProdUser -Data $IntegrationTestUsers -ReportOnly $false -Config $IntegrationConfig
            $result[0].Success | Should -Be $true
            
            # Verify Unix attributes were set (if supported by the test AD)
            $createdUser = Get-ADUser -Identity $IntegrationTestUsers[0].SamAccountName -Properties *
            if ($createdUser.msSFU30UidNumber) {
                $createdUser.msSFU30UidNumber | Should -BeGreaterThan 0
                $createdUser.msSFU30GidNumber | Should -Be $IntegrationConfig.UnixConfiguration.DefaultGidNumber
                $createdUser.msSFU30LoginShell | Should -Be $IntegrationConfig.UnixConfiguration.DefaultLoginShell
            }
        }
    }
}