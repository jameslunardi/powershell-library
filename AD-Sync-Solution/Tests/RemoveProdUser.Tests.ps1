<#
.SYNOPSIS
    Pester tests for the Remove-ProdUser function

.DESCRIPTION
    Tests user removal functionality including safety thresholds,
    two-stage removal process, and group membership cleanup.
#>

BeforeAll {
    # Import the function under test
    $ModulePath = Join-Path $PSScriptRoot "..\remove_produser.ps1"
    . $ModulePath
    
    # Load test configuration
    $TestConfigPath = Join-Path $PSScriptRoot "TestConfig.json"
    $TestConfig = Get-Content $TestConfigPath | ConvertFrom-Json
    
    # Mock Active Directory commands
    Mock Set-ADUser { }
    Mock Remove-ADUser { }
    Mock Get-ADUser { 
        return @{
            memberof = @("CN=TestGroup1,DC=test,DC=local", "CN=TestGroup2,DC=test,DC=local")
        }
    }
    Mock Remove-ADGroupMember { }
    Mock Move-ADObject { }
    Mock Start-Sleep { }
    
    # Create test user data for removal
    $script:TestUsersToRemove = @(
        @{
            SamAccountName = "usertoremove1"
            EmployeeID = "EMP001"
            DistinguishedName = "CN=usertoremove1,OU=Users,DC=test,DC=local"
            Info = "Existing info"
        },
        @{
            SamAccountName = "usertoremove2"
            EmployeeID = "EMP002"
            DistinguishedName = "CN=usertoremove2,OU=Leavers,OU=Users,OU=Test,DC=test,DC=target,DC=local"
            Info = "User in leavers OU"
        },
        @{
            SamAccountName = "usertoremove3"
            EmployeeID = "EMP003"
            DistinguishedName = "CN=usertoremove3,OU=Active,DC=test,DC=local"
            Info = "Active user"
        }
    )
}

Describe "Remove-ProdUser" {
    
    Context "When processing valid user data" {
        
        It "Should process users successfully in report mode" {
            Mock Remove-ADUser { }
            Mock Move-ADObject { }
            
            $result = Remove-ProdUser -Data $TestUsersToRemove -ReportOnly $true -Config $TestConfig
            
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 3
            
            # Should not actually remove or move users in report mode
            Should -Invoke Remove-ADUser -Times 0
            Should -Invoke Move-ADObject -Times 0
        }
        
        It "Should process users successfully in live mode" {
            $result = Remove-ProdUser -Data $TestUsersToRemove -ReportOnly $false -Config $TestConfig
            
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 3
        }
    }
    
    Context "When safety thresholds are exceeded" {
        
        It "Should throw error when deletion threshold is exceeded" {
            # Create more users than the threshold (5 in test config)
            $tooManyUsers = 1..10 | ForEach-Object {
                @{
                    SamAccountName = "user$_"
                    EmployeeID = "EMP$($_.ToString('000'))"
                    DistinguishedName = "CN=user$_,OU=Users,DC=test,DC=local"
                }
            }
            
            { Remove-ProdUser -Data $tooManyUsers -Config $TestConfig } | Should -Throw "*Too many users are marked for deletion*"
        }
        
        It "Should list users that would be deleted when threshold exceeded" {
            $tooManyUsers = 1..10 | ForEach-Object {
                @{
                    SamAccountName = "user$_"
                    EmployeeID = "EMP$($_.ToString('000'))"
                    DistinguishedName = "CN=user$_,OU=Users,DC=test,DC=local"
                }
            }
            
            Mock Write-Verbose { } -Verifiable
            
            { Remove-ProdUser -Data $tooManyUsers -Config $TestConfig } | Should -Throw
            
            Should -Invoke Write-Verbose -ParameterFilter {
                $Message -like "*Users that would be deleted:*"
            }
        }
    }
    
    Context "When handling users in Leavers OU (second stage removal)" {
        
        It "Should delete users already in Leavers OU" {
            $leaverUser = $TestUsersToRemove | Where-Object { $_.DistinguishedName -like "*Leavers*" }
            
            Mock Remove-ADUser { } -Verifiable
            Mock Set-ADUser { } -Verifiable
            
            $result = Remove-ProdUser -Data $leaverUser -ReportOnly $false -Config $TestConfig
            
            $result.Success | Should -Be $true
            $result.Result | Should -Be "Deleted"
            
            Should -Invoke Set-ADUser -ParameterFilter {
                $Replace["info"] -like "*Deleting account*"
            }
            
            Should -Invoke Remove-ADUser -ParameterFilter {
                $Identity -eq $leaverUser.DistinguishedName
            }
        }
        
        It "Should update info field before deletion" {
            $leaverUser = $TestUsersToRemove | Where-Object { $_.DistinguishedName -like "*Leavers*" }
            
            Mock Set-ADUser { } -Verifiable
            
            Remove-ProdUser -Data $leaverUser -ReportOnly $false -Config $TestConfig
            
            Should -Invoke Set-ADUser -ParameterFilter {
                $Replace["info"] -like "*ADSync*" -and
                $Replace["info"] -like "*No account found in Source with EmployeeID: $($leaverUser.EmployeeID)*"
            }
        }
        
        It "Should not delete users in report-only mode" {
            $leaverUser = $TestUsersToRemove | Where-Object { $_.DistinguishedName -like "*Leavers*" }
            
            Mock Remove-ADUser { } -Verifiable
            
            Remove-ProdUser -Data $leaverUser -ReportOnly $true -Config $TestConfig
            
            Should -Invoke Remove-ADUser -Times 0
        }
    }
    
    Context "When handling users not in Leavers OU (first stage quarantine)" {
        
        It "Should quarantine users not in Leavers OU" {
            $activeUsers = $TestUsersToRemove | Where-Object { $_.DistinguishedName -notlike "*Leavers*" }
            
            Mock Set-ADUser { } -Verifiable
            Mock Move-ADObject { } -Verifiable
            Mock Remove-ADGroupMember { } -Verifiable
            
            $result = Remove-ProdUser -Data $activeUsers -ReportOnly $false -Config $TestConfig
            
            $result | Where-Object { $_.Result -eq "Quarantined" } | Should -HaveCount 2
            
            Should -Invoke Set-ADUser -ParameterFilter {
                $Enabled -eq $false
            }
            
            Should -Invoke Move-ADObject -ParameterFilter {
                $TargetPath -eq $TestConfig.TargetDomain.LeaversOU
            }
        }
        
        It "Should remove group memberships during quarantine" {
            $activeUser = $TestUsersToRemove | Where-Object { $_.DistinguishedName -notlike "*Leavers*" } | Select-Object -First 1
            
            Mock Get-ADUser { 
                return @{
                    memberof = @("CN=TestGroup1,DC=test,DC=local", "CN=TestGroup2,DC=test,DC=local")
                }
            }
            Mock Remove-ADGroupMember { } -Verifiable
            
            Remove-ProdUser -Data $activeUser -ReportOnly $false -Config $TestConfig
            
            Should -Invoke Remove-ADGroupMember -Times 1 -ParameterFilter {
                $Members -eq $activeUser.DistinguishedName
            }
        }
        
        It "Should update info field during quarantine" {
            $activeUser = $TestUsersToRemove | Where-Object { $_.DistinguishedName -notlike "*Leavers*" } | Select-Object -First 1
            
            Mock Set-ADUser { } -Verifiable
            
            Remove-ProdUser -Data $activeUser -ReportOnly $false -Config $TestConfig
            
            Should -Invoke Set-ADUser -ParameterFilter {
                $Replace["info"] -like "*ADSync*" -and
                $Replace["info"] -like "*Account disabled and moved to Quarantine*"
            }
        }
        
        It "Should add sleep delay between operations" {
            $activeUser = $TestUsersToRemove | Where-Object { $_.DistinguishedName -notlike "*Leavers*" } | Select-Object -First 1
            
            Mock Start-Sleep { } -Verifiable
            
            Remove-ProdUser -Data $activeUser -ReportOnly $false -Config $TestConfig
            
            Should -Invoke Start-Sleep -ParameterFilter {
                $Seconds -eq 1.5
            }
        }
    }
    
    Context "When errors occur during removal" {
        
        It "Should handle Set-ADUser failures gracefully for deletion" {
            $leaverUser = $TestUsersToRemove | Where-Object { $_.DistinguishedName -like "*Leavers*" }
            
            Mock Set-ADUser { throw "Access denied" }
            
            $result = Remove-ProdUser -Data $leaverUser -ReportOnly $false -Config $TestConfig
            
            $result.Success | Should -Be $false
            $result.Result | Should -Like "*Access denied*"
        }
        
        It "Should handle Remove-ADUser failures gracefully" {
            $leaverUser = $TestUsersToRemove | Where-Object { $_.DistinguishedName -like "*Leavers*" }
            
            Mock Remove-ADUser { throw "User not found" }
            
            $result = Remove-ProdUser -Data $leaverUser -ReportOnly $false -Config $TestConfig
            
            $result.Success | Should -Be $false
            $result.Result | Should -Like "*User not found*"
        }
        
        It "Should handle quarantine operation failures gracefully" {
            $activeUser = $TestUsersToRemove | Where-Object { $_.DistinguishedName -notlike "*Leavers*" } | Select-Object -First 1
            
            Mock Move-ADObject { throw "OU not found" }
            
            $result = Remove-ProdUser -Data $activeUser -ReportOnly $false -Config $TestConfig
            
            $result.Success | Should -Be $false
            $result.Result | Should -Like "*OU not found*"
        }
        
        It "Should continue processing other users after a failure" {
            $activeUsers = $TestUsersToRemove | Where-Object { $_.DistinguishedName -notlike "*Leavers*" }
            
            Mock Set-ADUser { 
                if ($Identity -like "*usertoremove1*") {
                    throw "Access denied"
                }
            }
            
            $result = Remove-ProdUser -Data $activeUsers -ReportOnly $false -Config $TestConfig
            
            $result.Count | Should -Be 2
            $result[0].Success | Should -Be $false
            $result[1].Success | Should -Be $true
        }
    }
    
    Context "When using configuration values" {
        
        It "Should use deletion threshold from configuration" {
            $TestConfig.SafetyThresholds.DeletionThreshold | Should -Be 5
            
            # Create exactly threshold + 1 users
            $tooManyUsers = 1..6 | ForEach-Object {
                @{
                    SamAccountName = "user$_"
                    EmployeeID = "EMP$($_.ToString('000'))"
                    DistinguishedName = "CN=user$_,OU=Users,DC=test,DC=local"
                }
            }
            
            { Remove-ProdUser -Data $tooManyUsers -Config $TestConfig } | Should -Throw
        }
        
        It "Should use LeaversOU from configuration" {
            $activeUser = $TestUsersToRemove | Where-Object { $_.DistinguishedName -notlike "*Leavers*" } | Select-Object -First 1
            
            Mock Move-ADObject { } -Verifiable
            
            Remove-ProdUser -Data $activeUser -ReportOnly $false -Config $TestConfig
            
            Should -Invoke Move-ADObject -ParameterFilter {
                $TargetPath -eq $TestConfig.TargetDomain.LeaversOU
            }
        }
    }
    
    Context "When in report-only mode" {
        
        It "Should not perform actual deletions" {
            Mock Remove-ADUser { } -Verifiable
            Mock Set-ADUser { } -Verifiable
            
            Remove-ProdUser -Data $TestUsersToRemove -ReportOnly $true -Config $TestConfig
            
            # Set-ADUser might be called with -WhatIf, but Remove-ADUser should not be called
            Should -Invoke Remove-ADUser -Times 0
        }
        
        It "Should not perform actual moves" {
            Mock Move-ADObject { } -Verifiable
            
            Remove-ProdUser -Data $TestUsersToRemove -ReportOnly $true -Config $TestConfig
            
            Should -Invoke Move-ADObject -Times 0
        }
        
        It "Should still return results indicating what would be done" {
            $result = Remove-ProdUser -Data $TestUsersToRemove -ReportOnly $true -Config $TestConfig
            
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 3
            
            # Should have one deletion and two quarantines
            $result | Where-Object { $_.Result -eq "Deleted" } | Should -HaveCount 1
            $result | Where-Object { $_.Result -eq "Quarantined" } | Should -HaveCount 2
        }
    }
}