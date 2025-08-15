<#
.SYNOPSIS
    Pester tests for the Update-ProdUser function

.DESCRIPTION
    Tests user update functionality including attribute updates,
    account expiration handling, and user disabling/moving.
#>

BeforeAll {
    # Import the function under test
    $ModulePath = Join-Path $PSScriptRoot "..\update_produser.ps1"
    . $ModulePath
    
    # Load test configuration
    $TestConfigPath = Join-Path $PSScriptRoot "TestConfig.json"
    $TestConfig = Get-Content $TestConfigPath | ConvertFrom-Json
    
    # Mock Active Directory commands
    Mock Set-ADUser { }
    Mock Set-ADAccountExpiration { }
    Mock Clear-ADAccountExpiration { }
    Mock Disable-ADAccount { }
    Mock Get-ADUser { 
        return @{
            SamAccountName = "testuser"
            Enabled = $true
            Info = "Existing info"
            memberof = @("CN=TestGroup1,DC=test,DC=local")
        }
    }
    Mock Remove-ADGroupMember { }
    Mock Move-ADObject { }
    Mock Start-Sleep { }
    
    # Create test update data
    $script:TestUpdates = @(
        @{
            DistinguishedName = "CN=testuser1,OU=Users,DC=test,DC=local"
            SamAccountName = "testuser1"
            Attribute = "mail"
            NewValue = "newemail@test.com"
            OldValue = "oldemail@test.com"
        },
        @{
            DistinguishedName = "CN=testuser2,OU=Users,DC=test,DC=local"
            SamAccountName = "testuser2"
            Attribute = "GivenName"
            NewValue = "NewFirstName"
            OldValue = "OldFirstName"
        },
        @{
            DistinguishedName = "CN=testuser3,OU=Users,DC=test,DC=local"
            SamAccountName = "testuser3"
            Attribute = "AccountExpirationDate"
            NewValue = (Get-Date).AddDays(30)
            OldValue = $null
        },
        @{
            DistinguishedName = "CN=testuser4,OU=Users,DC=test,DC=local"
            SamAccountName = "testuser4"
            Attribute = "AccountExpirationDate"
            NewValue = $null
            OldValue = (Get-Date).AddDays(30)
        },
        @{
            DistinguishedName = "CN=testuser5,OU=Users,DC=test,DC=local"
            SamAccountName = "testuser5"
            Attribute = "Enabled"
            NewValue = $false
            OldValue = $true
        },
        @{
            DistinguishedName = "CN=testuser6,OU=Users,DC=test,DC=local"
            SamAccountName = "testuser6"
            Attribute = "DistinguishedName"
            NewValue = "OU=Leavers,OU=Users,OU=Test,DC=test,DC=target,DC=local"
            OldValue = "CN=testuser6,OU=Users,DC=test,DC=local"
        }
    )
}

Describe "Update-ProdUser" {
    
    Context "When processing valid update data" {
        
        It "Should process updates successfully in report mode" {
            Mock Set-ADUser { }
            
            $standardUpdates = $TestUpdates | Where-Object { $_.Attribute -notin @("Enabled", "DistinguishedName", "AccountExpirationDate") }
            $result = Update-ProdUser -Data $standardUpdates -ReportOnly $true -Config $TestConfig
            
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 2
            $result[0].Success | Should -Be $true
            $result[0].Result | Should -Be "Updated"
        }
        
        It "Should process updates successfully in live mode" {
            $standardUpdates = $TestUpdates | Where-Object { $_.Attribute -notin @("Enabled", "DistinguishedName", "AccountExpirationDate") }
            $result = Update-ProdUser -Data $standardUpdates -ReportOnly $false -Config $TestConfig
            
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 2
        }
    }
    
    Context "When safety thresholds are exceeded" {
        
        It "Should throw error when update threshold is exceeded" {
            # Create more updates than the threshold (15 in test config)
            $tooManyUpdates = 1..20 | ForEach-Object {
                @{
                    DistinguishedName = "CN=user$_,OU=Users,DC=test,DC=local"
                    SamAccountName = "user$_"
                    Attribute = "mail"
                    NewValue = "user$_@test.com"
                    OldValue = "olduser$_@test.com"
                }
            }
            
            { Update-ProdUser -Data $tooManyUpdates -Config $TestConfig } | Should -Throw "*Too many updates are required*"
        }
    }
    
    Context "When handling standard attribute updates" {
        
        It "Should update mail attribute correctly" {
            $mailUpdate = $TestUpdates | Where-Object { $_.Attribute -eq "mail" }
            
            Mock Get-ADUser { 
                return @{
                    SamAccountName = "testuser1"
                    mail = "oldemail@test.com"
                }
            } -ParameterFilter { $Identity -eq "testuser1" }
            
            Mock Set-ADUser { } -Verifiable
            
            Update-ProdUser -Data $mailUpdate -ReportOnly $false -Config $TestConfig
            
            Should -Invoke Set-ADUser -ParameterFilter {
                $Instance.mail -eq "newemail@test.com"
            }
        }
        
        It "Should update GivenName attribute correctly" {
            $nameUpdate = $TestUpdates | Where-Object { $_.Attribute -eq "GivenName" }
            
            Mock Get-ADUser { 
                return @{
                    SamAccountName = "testuser2"
                    GivenName = "OldFirstName"
                }
            } -ParameterFilter { $Identity -eq "testuser2" }
            
            Mock Set-ADUser { } -Verifiable
            
            Update-ProdUser -Data $nameUpdate -ReportOnly $false -Config $TestConfig
            
            Should -Invoke Set-ADUser -ParameterFilter {
                $Instance.GivenName -eq "NewFirstName"
            }
        }
        
        It "Should handle Office attribute mapping to physicalDeliveryOfficeName" {
            $officeUpdate = @{
                DistinguishedName = "CN=testuser,OU=Users,DC=test,DC=local"
                SamAccountName = "testuser"
                Attribute = "Office"
                NewValue = "New Office"
                OldValue = "Old Office"
            }
            
            Mock Get-ADUser { 
                return @{
                    SamAccountName = "testuser"
                    physicalDeliveryOfficeName = "Old Office"
                }
            }
            
            Mock Set-ADUser { } -Verifiable
            
            Update-ProdUser -Data $officeUpdate -ReportOnly $false -Config $TestConfig
            
            Should -Invoke Set-ADUser -ParameterFilter {
                $Instance.physicalDeliveryOfficeName -eq "New Office"
            }
        }
        
        It "Should clear attributes when NewValue is empty" {
            $clearUpdate = @{
                DistinguishedName = "CN=testuser,OU=Users,DC=test,DC=local"
                SamAccountName = "testuser"
                Attribute = "Office"
                NewValue = $null
                OldValue = "Old Office"
            }
            
            Mock Set-ADUser { } -Verifiable
            
            Update-ProdUser -Data $clearUpdate -ReportOnly $false -Config $TestConfig
            
            Should -Invoke Set-ADUser -ParameterFilter {
                $Clear -contains "physicalDeliveryOfficeName"
            }
        }
        
        It "Should update info field with audit trail" {
            $standardUpdate = $TestUpdates | Where-Object { $_.Attribute -eq "mail" }
            
            Mock Set-ADUser { } -Verifiable
            
            Update-ProdUser -Data $standardUpdate -ReportOnly $false -Config $TestConfig
            
            Should -Invoke Set-ADUser -ParameterFilter {
                $Replace["Info"] -like "*ADSync*" -and
                $Replace["Info"] -like "*Attributes Updated Based on Source User Account*"
            }
        }
    }
    
    Context "When handling account expiration updates" {
        
        It "Should set account expiration date when NewValue is provided" {
            $expirationUpdate = $TestUpdates | Where-Object { $_.Attribute -eq "AccountExpirationDate" -and $_.NewValue -ne $null }
            
            Mock Set-ADAccountExpiration { } -Verifiable
            
            Update-ProdUser -Data $expirationUpdate -ReportOnly $false -Config $TestConfig
            
            Should -Invoke Set-ADAccountExpiration -ParameterFilter {
                $Identity -eq "testuser3" -and
                $DateTime -ne $null
            }
        }
        
        It "Should clear account expiration date when NewValue is null" {
            $clearExpirationUpdate = $TestUpdates | Where-Object { $_.Attribute -eq "AccountExpirationDate" -and $_.NewValue -eq $null }
            
            Mock Clear-ADAccountExpiration { } -Verifiable
            
            Update-ProdUser -Data $clearExpirationUpdate -ReportOnly $false -Config $TestConfig
            
            Should -Invoke Clear-ADAccountExpiration -ParameterFilter {
                $Identity -eq "testuser4"
            }
        }
        
        It "Should handle account expiration errors gracefully" {
            $expirationUpdate = $TestUpdates | Where-Object { $_.Attribute -eq "AccountExpirationDate" -and $_.NewValue -ne $null }
            
            Mock Set-ADAccountExpiration { throw "Access denied" }
            Mock Write-Warning { } -Verifiable
            
            $result = Update-ProdUser -Data $expirationUpdate -ReportOnly $false -Config $TestConfig
            
            $result.Success | Should -Be $false
            $result.Result | Should -Like "*Access denied*"
            
            Should -Invoke Write-Warning -Times 2  # One for exception message, one for detailed message
        }
    }
    
    Context "When handling special attributes (Enabled and DistinguishedName)" {
        
        It "Should defer Enabled and DistinguishedName updates to disable processing" {
            $specialUpdates = $TestUpdates | Where-Object { $_.Attribute -in @("Enabled", "DistinguishedName") }
            
            Mock Disable-ADAccount { } -Verifiable
            Mock Move-ADObject { } -Verifiable
            
            $result = Update-ProdUser -Data $specialUpdates -ReportOnly $false -Config $TestConfig
            
            # Should have 2 results for the 2 special updates
            $result.Count | Should -Be 2
            
            Should -Invoke Disable-ADAccount -Times 2
            Should -Invoke Move-ADObject -Times 2
        }
        
        It "Should disable accounts and move to Leavers OU" {
            $enabledUpdate = $TestUpdates | Where-Object { $_.Attribute -eq "Enabled" }
            
            Mock Disable-ADAccount { } -Verifiable
            Mock Move-ADObject { } -Verifiable
            Mock Remove-ADGroupMember { } -Verifiable
            
            Update-ProdUser -Data $enabledUpdate -ReportOnly $false -Config $TestConfig
            
            Should -Invoke Disable-ADAccount -ParameterFilter {
                $Identity -eq "testuser5"
            }
            
            Should -Invoke Move-ADObject -ParameterFilter {
                $TargetPath -eq $TestConfig.TargetDomain.LeaversOU
            }
            
            Should -Invoke Remove-ADGroupMember
        }
        
        It "Should remove group memberships during disable process" {
            $enabledUpdate = $TestUpdates | Where-Object { $_.Attribute -eq "Enabled" }
            
            Mock Get-ADUser { 
                return @{
                    SamAccountName = "testuser5"
                    memberof = @("CN=Group1,DC=test,DC=local", "CN=Group2,DC=test,DC=local")
                }
            } -ParameterFilter { $Identity -eq "testuser5" }
            
            Mock Remove-ADGroupMember { } -Verifiable
            
            Update-ProdUser -Data $enabledUpdate -ReportOnly $false -Config $TestConfig
            
            Should -Invoke Remove-ADGroupMember -ParameterFilter {
                $Members -eq "testuser5"
            }
        }
        
        It "Should update info field for disabled users" {
            $enabledUpdate = $TestUpdates | Where-Object { $_.Attribute -eq "Enabled" }
            
            Mock Set-ADUser { } -Verifiable
            
            Update-ProdUser -Data $enabledUpdate -ReportOnly $false -Config $TestConfig
            
            Should -Invoke Set-ADUser -ParameterFilter {
                $Instance.Info -like "*Account in Source has moved to leavers*"
            }
        }
    }
    
    Context "When errors occur during updates" {
        
        It "Should handle Get-ADUser failures gracefully" {
            $standardUpdate = $TestUpdates | Where-Object { $_.Attribute -eq "mail" }
            
            Mock Get-ADUser { throw "User not found" }
            
            $result = Update-ProdUser -Data $standardUpdate -ReportOnly $false -Config $TestConfig
            
            $result.Success | Should -Be $false
            $result.Result | Should -Like "*User not found*"
        }
        
        It "Should handle Set-ADUser failures gracefully" {
            $standardUpdate = $TestUpdates | Where-Object { $_.Attribute -eq "mail" }
            
            Mock Set-ADUser { throw "Access denied" }
            
            $result = Update-ProdUser -Data $standardUpdate -ReportOnly $false -Config $TestConfig
            
            $result.Success | Should -Be $false
            $result.Result | Should -Like "*Access denied*"
        }
        
        It "Should handle disable operation failures gracefully" {
            $enabledUpdate = $TestUpdates | Where-Object { $_.Attribute -eq "Enabled" }
            
            Mock Disable-ADAccount { throw "Cannot disable user" }
            Mock Write-Warning { } -Verifiable
            
            $result = Update-ProdUser -Data $enabledUpdate -ReportOnly $false -Config $TestConfig
            
            $result.Success | Should -Be $false
            $result.Result | Should -Like "*Cannot disable user*"
        }
        
        It "Should continue processing other updates after a failure" {
            $multipleUpdates = $TestUpdates | Where-Object { $_.Attribute -in @("mail", "GivenName") }
            
            Mock Get-ADUser { 
                if ($Identity -eq "testuser1") {
                    throw "Access denied"
                }
                return @{ SamAccountName = $Identity }
            }
            
            $result = Update-ProdUser -Data $multipleUpdates -ReportOnly $false -Config $TestConfig
            
            $result.Count | Should -Be 2
            $result[0].Success | Should -Be $false
            $result[1].Success | Should -Be $true
        }
    }
    
    Context "When using configuration values" {
        
        It "Should use update threshold from configuration" {
            $TestConfig.SafetyThresholds.UpdateThreshold | Should -Be 15
            
            # Create exactly threshold + 1 updates
            $tooManyUpdates = 1..16 | ForEach-Object {
                @{
                    DistinguishedName = "CN=user$_,OU=Users,DC=test,DC=local"
                    SamAccountName = "user$_"
                    Attribute = "mail"
                    NewValue = "user$_@test.com"
                    OldValue = "olduser$_@test.com"
                }
            }
            
            { Update-ProdUser -Data $tooManyUpdates -Config $TestConfig } | Should -Throw
        }
        
        It "Should use LeaversOU from configuration for moves" {
            $enabledUpdate = $TestUpdates | Where-Object { $_.Attribute -eq "Enabled" }
            
            Mock Move-ADObject { } -Verifiable
            
            Update-ProdUser -Data $enabledUpdate -ReportOnly $false -Config $TestConfig
            
            Should -Invoke Move-ADObject -ParameterFilter {
                $TargetPath -eq $TestConfig.TargetDomain.LeaversOU
            }
        }
    }
    
    Context "When in report-only mode" {
        
        It "Should not perform actual updates" {
            Mock Set-ADUser { } -Verifiable
            Mock Set-ADAccountExpiration { } -Verifiable
            Mock Disable-ADAccount { } -Verifiable
            
            Update-ProdUser -Data $TestUpdates -ReportOnly $true -Config $TestConfig
            
            # Should call mocks with -WhatIf but verify no actual changes
            Should -Invoke Set-ADAccountExpiration -Times 0
            Should -Invoke Disable-ADAccount -Times 0
        }
        
        It "Should still return results indicating what would be done" {
            $standardUpdates = $TestUpdates | Where-Object { $_.Attribute -notin @("Enabled", "DistinguishedName") }
            
            $result = Update-ProdUser -Data $standardUpdates -ReportOnly $true -Config $TestConfig
            
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -BeGreaterThan 0
            
            $result | ForEach-Object {
                $_.Success | Should -Be $true
                $_.Result | Should -Be "Updated"
            }
        }
    }
}