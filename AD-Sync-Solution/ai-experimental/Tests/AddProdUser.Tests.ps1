<#
.SYNOPSIS
    Pester tests for the Add-ProdUser function

.DESCRIPTION
    Tests user creation functionality including safety thresholds,
    duplicate detection, and Unix attribute management.
#>

BeforeAll {
    # Set test mode for wrapper functions
    $env:ADSYNC_TEST_MODE = "Mock"
    
    # Import the function under test
    $ModulePath = Join-Path $PSScriptRoot "..\add_produser.ps1"
    . $ModulePath
    
    # Load test configuration
    $TestConfigPath = Join-Path $PSScriptRoot "TestConfig.json"
    $TestConfig = Get-Content $TestConfigPath | ConvertFrom-Json
    
    # Reset mock data for clean test runs
    Reset-MockData
    
    # Create test user data
    $script:TestUsers = @(
        @{
            SamAccountName = "testuser1"
            mail = "testuser1@test.com"
            GivenName = "Test"
            Surname = "User1"
            EmployeeID = "EMP001"
            Enabled = $true
            AccountExpirationDate = $null
            Title = "Test Title"
            Office = "Test Office"
            Department = "IT"
            co = "US"
            'msDS-cloudExtensionAttribute1' = "TestValue1"
        },
        @{
            SamAccountName = "testuser2"
            mail = "testuser2@test.com"
            GivenName = "Test"
            Surname = "User2"
            EmployeeID = "EMP002"
            Enabled = $true
            AccountExpirationDate = (Get-Date).AddDays(30)
            Title = "Test Title 2"
            Office = "Test Office 2"
            Department = "HR"
            co = "CA"
            'msDS-cloudExtensionAttribute2' = "TestValue2"
        }
    )
}

AfterAll {
    # Clean up test mode
    $env:ADSYNC_TEST_MODE = $null
}

Describe "Add-ProdUser" {
    
    Context "When processing valid user data" {
        
        It "Should create users successfully in report mode" {
            Mock New-ADUser { } -Verifiable
            
            $result = Add-ProdUser -Data $TestUsers -ReportOnly $true -Config $TestConfig
            
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 2
            $result[0].Success | Should -Be $true
            $result[0].Result | Should -Be "Created"
            
            # Should not actually call New-ADUser in report mode
            Should -Invoke New-ADUser -Times 0
        }
        
        It "Should create users successfully in live mode" {
            Mock New-ADUser { } -Verifiable
            
            $result = Add-ProdUser -Data $TestUsers -ReportOnly $false -Config $TestConfig
            
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 2
            
            Should -Invoke New-ADUser -Times 2
        }
        
        It "Should use correct OU for new users" {
            Mock New-ADUser { } -Verifiable
            
            Add-ProdUser -Data $TestUsers -ReportOnly $false -Config $TestConfig
            
            Should -Invoke New-ADUser -ParameterFilter {
                $Path -eq $TestConfig.TargetDomain.InactiveOU
            }
        }
        
        It "Should set users as disabled by default" {
            Mock New-ADUser { } -Verifiable
            
            Add-ProdUser -Data $TestUsers -ReportOnly $false -Config $TestConfig
            
            Should -Invoke New-ADUser -ParameterFilter {
                $Enabled -eq $false
            }
        }
        
        It "Should generate complex passwords" {
            Mock New-ADUser { 
                param($AccountPassword)
                $AccountPassword | Should -Not -BeNullOrEmpty
                $AccountPassword.GetType().Name | Should -Be "SecureString"
            } -Verifiable
            
            Add-ProdUser -Data $TestUsers -ReportOnly $false -Config $TestConfig
            
            Should -Invoke New-ADUser -Times 2
        }
    }
    
    Context "When safety thresholds are exceeded" {
        
        It "Should throw error when addition threshold is exceeded" {
            # Create more users than the threshold (10 in test config)
            $tooManyUsers = 1..15 | ForEach-Object {
                @{
                    SamAccountName = "user$_"
                    mail = "user$_@test.com"
                    GivenName = "User"
                    Surname = "$_"
                    EmployeeID = "EMP$($_.ToString('000'))"
                }
            }
            
            { Add-ProdUser -Data $tooManyUsers -Config $TestConfig } | Should -Throw "*Too many users are marked for creation*"
        }
        
        It "Should list users that would be added when threshold exceeded" {
            $tooManyUsers = 1..15 | ForEach-Object {
                @{
                    SamAccountName = "user$_"
                    mail = "user$_@test.com"
                    GivenName = "User"
                    Surname = "$_"
                    EmployeeID = "EMP$($_.ToString('000'))"
                }
            }
            
            Mock Write-Verbose { } -Verifiable
            
            { Add-ProdUser -Data $tooManyUsers -Config $TestConfig } | Should -Throw
            
            Should -Invoke Write-Verbose -ParameterFilter {
                $Message -like "*Users that would be added:*"
            }
        }
    }
    
    Context "When handling duplicate users" {
        
        It "Should detect duplicate email addresses" {
            Mock Get-ADUser { 
                return @{
                    SamAccountName = "existinguser"
                    EmailAddress = "testuser1@test.com"
                    EmployeeID = "EMP999"
                }
            } -ParameterFilter { $Filter -like "*EmailAddress -eq*" }
            
            $result = Add-ProdUser -Data $TestUsers[0] -ReportOnly $false -Config $TestConfig
            
            $result.Success | Should -Be $false
            $result.Result | Should -Be "Duplicate"
        }
        
        It "Should detect duplicate employee IDs" {
            Mock Get-ADUser { 
                return @{
                    SamAccountName = "existinguser"
                    EmailAddress = "different@test.com"
                    EmployeeID = "EMP001"
                }
            } -ParameterFilter { $Filter -like "*EmployeeID -eq*" }
            
            $result = Add-ProdUser -Data $TestUsers[0] -ReportOnly $false -Config $TestConfig
            
            $result.Success | Should -Be $false
            $result.Result | Should -Be "Duplicate"
        }
        
        It "Should handle SamAccountName conflicts by adding suffix" {
            Mock Get-ADUser { 
                return @{ SamAccountName = "testuser1" }
            } -ParameterFilter { $Filter -like "*SamAccountName -eq 'testuser1'*" }
            
            Mock Get-ADUser { 
                return $null
            } -ParameterFilter { $Filter -like "*SamAccountName -eq 'testuser101'*" }
            
            Mock New-ADUser { } -Verifiable
            
            $result = Add-ProdUser -Data $TestUsers[0] -ReportOnly $false -Config $TestConfig
            
            $result.Success | Should -Be $true
            $result.Result | Should -Be "Created-NewSamAccountName"
            
            Should -Invoke New-ADUser -ParameterFilter {
                $SamAccountName -eq "testuser101"
            }
        }
    }
    
    Context "When managing Unix attributes" {
        
        It "Should retrieve and increment UID number" {
            Mock Get-ADObject { 
                return @{ msSFU30MaxUidNumber = 50000 }
            } -Verifiable
            
            Mock Set-ADObject { } -Verifiable
            Mock New-ADUser { } -Verifiable
            
            Add-ProdUser -Data $TestUsers[0] -ReportOnly $false -Config $TestConfig
            
            Should -Invoke Get-ADObject -ParameterFilter {
                $Identity -eq $TestConfig.TargetDomain.NISObjectDN
            }
            
            Should -Invoke New-ADUser -ParameterFilter {
                $OtherAttributes["uidNumber"] -eq 50000 -and
                $OtherAttributes["gidNumber"] -eq $TestConfig.UnixConfiguration.DefaultGidNumber -and
                $OtherAttributes["loginShell"] -eq $TestConfig.UnixConfiguration.DefaultLoginShell
            }
            
            Should -Invoke Set-ADObject -ParameterFilter {
                $Replace["msSFU30MaxUidNumber"] -eq 50001
            }
        }
        
        It "Should handle Unix UID retrieval failures gracefully" {
            Mock Get-ADObject { throw "Access denied" }
            Mock Write-Warning { } -Verifiable
            Mock New-ADUser { } -Verifiable
            
            Add-ProdUser -Data $TestUsers[0] -ReportOnly $false -Config $TestConfig
            
            Should -Invoke Write-Warning -ParameterFilter {
                $Message -like "*Unable to retrieve Unix UID information*"
            }
            
            # Should still create user with default UID
            Should -Invoke New-ADUser -ParameterFilter {
                $OtherAttributes["uidNumber"] -eq 10000
            }
        }
    }
    
    Context "When setting user attributes" {
        
        It "Should set all standard attributes correctly" {
            Mock New-ADUser { } -Verifiable
            
            Add-ProdUser -Data $TestUsers[0] -ReportOnly $false -Config $TestConfig
            
            Should -Invoke New-ADUser -ParameterFilter {
                $SamAccountName -eq "testuser1" -and
                $EmailAddress -eq "testuser1@test.com" -and
                $GivenName -eq "Test" -and
                $Surname -eq "User1" -and
                $EmployeeID -eq "EMP001" -and
                $Title -eq "Test Title" -and
                $Office -eq "Test Office" -and
                $Department -eq "IT"
            }
        }
        
        It "Should set cloud extension attributes" {
            Mock New-ADUser { } -Verifiable
            
            Add-ProdUser -Data $TestUsers[0] -ReportOnly $false -Config $TestConfig
            
            Should -Invoke New-ADUser -ParameterFilter {
                $OtherAttributes["msDS-cloudExtensionAttribute1"] -eq "TestValue1"
            }
        }
        
        It "Should set Unix home directory correctly" {
            Mock New-ADUser { } -Verifiable
            
            Add-ProdUser -Data $TestUsers[0] -ReportOnly $false -Config $TestConfig
            
            Should -Invoke New-ADUser -ParameterFilter {
                $OtherAttributes["unixHomeDirectory"] -eq "/home/testuser1" -and
                $OtherAttributes["msSFU30Name"] -eq "testuser1" -and
                $OtherAttributes["uid"] -eq "testuser1"
            }
        }
        
        It "Should handle account expiration dates" {
            Mock New-ADUser { } -Verifiable
            
            Add-ProdUser -Data $TestUsers[1] -ReportOnly $false -Config $TestConfig
            
            Should -Invoke New-ADUser -ParameterFilter {
                $AccountExpirationDate -ne $null
            }
        }
    }
    
    Context "When errors occur during user creation" {
        
        It "Should handle New-ADUser failures gracefully" {
            Mock New-ADUser { throw "Access denied" }
            
            $result = Add-ProdUser -Data $TestUsers[0] -ReportOnly $false -Config $TestConfig
            
            $result.Success | Should -Be $false
            $result.Result | Should -Like "*Access denied*"
        }
        
        It "Should continue processing other users after a failure" {
            Mock New-ADUser { 
                if ($SamAccountName -eq "testuser1") {
                    throw "Access denied"
                }
            }
            
            $result = Add-ProdUser -Data $TestUsers -ReportOnly $false -Config $TestConfig
            
            $result.Count | Should -Be 2
            $result[0].Success | Should -Be $false
            $result[1].Success | Should -Be $true
        }
    }
    
    Context "When in report-only mode" {
        
        It "Should not create actual users" {
            Mock New-ADUser { } -Verifiable
            
            Add-ProdUser -Data $TestUsers -ReportOnly $true -Config $TestConfig
            
            Should -Invoke New-ADUser -Times 0
        }
        
        It "Should not update Unix UID counter" {
            Mock Set-ADObject { } -Verifiable
            
            Add-ProdUser -Data $TestUsers -ReportOnly $true -Config $TestConfig
            
            Should -Invoke Set-ADObject -Times 0
        }
        
        It "Should still return success results" {
            $result = Add-ProdUser -Data $TestUsers -ReportOnly $true -Config $TestConfig
            
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 2
            $result[0].Success | Should -Be $true
            $result[1].Success | Should -Be $true
        }
    }
}