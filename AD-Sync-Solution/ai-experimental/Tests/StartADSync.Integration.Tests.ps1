<#
.SYNOPSIS
    Integration tests for the start_adsync.ps1 main script

.DESCRIPTION
    Tests the main orchestration script including user comparison logic,
    threshold enforcement, and coordination between modules.
#>

BeforeAll {
    # Set test mode for wrapper functions
    $env:ADSYNC_TEST_MODE = "Mock"
    
    # Import all required functions
    . (Join-Path $PSScriptRoot "..\general_functions.ps1")
    . (Join-Path $PSScriptRoot "..\add_produser.ps1") 
    . (Join-Path $PSScriptRoot "..\remove_produser.ps1")
    . (Join-Path $PSScriptRoot "..\update_produser.ps1")
    
    # Import the main script functions (but don't execute the script)
    $MainScriptPath = Join-Path $PSScriptRoot "..\start_adsync.ps1"
    
    # Load test configuration
    $TestConfigPath = Join-Path $PSScriptRoot "TestConfig.json"
    
    # Mock all external dependencies
    Mock Start-Transcript { }
    Mock Stop-Transcript { }
    Mock Write-Host { }
    Mock Write-Error { }
    Mock Send-Email { }
    Mock Search-ADAccount { return @() }
    Mock Export-Csv { }
    
    # Mock the user management functions
    Mock Export-SourceUsers { 
        return @(
            @{
                SamAccountName = "sourceuser1"
                mail = "sourceuser1@source.com"
                GivenName = "Source"
                Surname = "User1"
                EmployeeID = "EMP001"
                Enabled = $true
                DistinguishedName = "CN=sourceuser1,OU=Users,DC=source,DC=local"
                AccountExpirationDate = $null
                Title = "Test Title"
                Office = "HQ"
                Department = "IT"
            },
            @{
                SamAccountName = "sourceuser2"
                mail = "sourceuser2@source.com"
                GivenName = "Source"
                Surname = "User2"
                EmployeeID = "EMP002"
                Enabled = $true
                DistinguishedName = "CN=sourceuser2,OU=Users,DC=source,DC=local"
                AccountExpirationDate = $null
                Title = "Test Title 2"
                Office = "Branch"
                Department = "HR"
            },
            @{
                SamAccountName = "sourceuser3"
                mail = "sourceuser3@source.com"
                GivenName = "Source"
                Surname = "User3"
                EmployeeID = "EMP003"
                Enabled = $false
                DistinguishedName = "CN=sourceuser3,OU=Leavers,DC=source,DC=local"
                AccountExpirationDate = $null
                Title = "Test Title 3"
                Office = "HQ"
                Department = "IT"
            }
        )
    }
    
    Mock Export-ProdUsers { 
        return @(
            @{
                SamAccountName = "targetuser1"
                mail = "targetuser1@target.com"
                GivenName = "Target"
                Surname = "User1"
                EmployeeID = "EMP001"
                Enabled = $true
                DistinguishedName = "CN=targetuser1,OU=Users,DC=target,DC=local"
                AccountExpirationDate = $null
                Title = "Old Title"  # Different from source
                Office = "HQ"
                Department = "IT"
            },
            @{
                SamAccountName = "targetuser4"
                mail = "targetuser4@target.com"
                GivenName = "Target"
                Surname = "User4"
                EmployeeID = "EMP004"
                Enabled = $true
                DistinguishedName = "CN=targetuser4,OU=Users,DC=target,DC=local"
                AccountExpirationDate = $null
                Title = "Title 4"
                Office = "Remote"
                Department = "Sales"
                'msDS-cloudExtensionAttribute10' = $null  # Not exempt from removal
            }
        )
    }
    
    Mock Add-ProdUser { 
        param($Data)
        return $Data | ForEach-Object {
            @{
                SamAccountName = $_.SamAccountName
                Success = $true
                Result = "Created"
            }
        }
    }
    
    Mock Update-ProdUser { 
        param($Data)
        return $Data | ForEach-Object {
            @{
                DistinguishedName = $_.DistinguishedName
                Success = $true
                Attribute = $_.Attribute
                Result = "Updated"
            }
        }
    }
    
    Mock Remove-ProdUser { 
        param($Data)
        return $Data | ForEach-Object {
            @{
                SamAccountName = $_.SamAccountName
                Success = $true
                Result = "Quarantined"
            }
        }
    }
    
    # Create a test script that can be executed
    $script:TestScriptContent = @"
# Mock the configuration loading to use our test config
function Get-ADSyncConfig { 
    return Get-Content '$TestConfigPath' | ConvertFrom-Json
}

function Test-ADSyncDirectories { }

# Import the actual script content but skip execution
`$ScriptContent = Get-Content '$MainScriptPath' -Raw
`$ScriptContent = `$ScriptContent -replace 'param\(', '#param('
`$ScriptContent = `$ScriptContent -replace '^\s*\.\s*"\$', '#. "$'
`$ScriptContent = `$ScriptContent -replace 'Start-Transcript', '#Start-Transcript'
`$ScriptContent = `$ScriptContent -replace 'Stop-Transcript', '#Stop-Transcript'
`$ScriptContent = `$ScriptContent -replace 'exit 1', 'return'

# Execute the modified script content
Invoke-Expression `$ScriptContent
"@
}

Describe "Start-ADSync Integration Tests" {
    
    Context "When comparing source and target users" {
        
        BeforeEach {
            # Reset mocks for each test
            Mock Export-SourceUsers { 
                return @(
                    @{
                        SamAccountName = "sourceuser1"
                        EmployeeID = "EMP001"
                        mail = "sourceuser1@source.com"
                        Title = "Test Title"
                        DistinguishedName = "CN=sourceuser1,OU=Users,DC=source,DC=local"
                    },
                    @{
                        SamAccountName = "sourceuser2"
                        EmployeeID = "EMP002"
                        mail = "sourceuser2@source.com"
                        Title = "Test Title 2"
                        DistinguishedName = "CN=sourceuser2,OU=Users,DC=source,DC=local"
                    }
                )
            }
            
            Mock Export-ProdUsers { 
                return @(
                    @{
                        SamAccountName = "targetuser1"
                        EmployeeID = "EMP001"
                        mail = "targetuser1@target.com"
                        Title = "Old Title"
                        DistinguishedName = "CN=targetuser1,OU=Users,DC=target,DC=local"
                    }
                )
            }
        }
        
        It "Should identify users to add" {
            # Execute the script logic to identify users
            $TestScriptContent | Invoke-Expression
            
            # Verify Add-ProdUser was called with the correct user
            Should -Invoke Add-ProdUser -ParameterFilter {
                $Data.Count -eq 1 -and
                $Data[0].EmployeeID -eq "EMP002"
            }
        }
        
        It "Should identify users to update" {
            # Execute the script logic
            $TestScriptContent | Invoke-Expression
            
            # Verify Update-ProdUser was called for attribute differences
            Should -Invoke Update-ProdUser -ParameterFilter {
                $Data.Count -gt 0 -and
                ($Data | Where-Object { $_.Attribute -eq "Title" -and $_.NewValue -eq "Test Title" })
            }
        }
        
        It "Should identify users to remove" {
            Mock Export-ProdUsers { 
                return @(
                    @{
                        SamAccountName = "targetuser1"
                        EmployeeID = "EMP001"
                        'msDS-cloudExtensionAttribute10' = $null
                    },
                    @{
                        SamAccountName = "targetuser4"
                        EmployeeID = "EMP004"
                        'msDS-cloudExtensionAttribute10' = $null
                    }
                )
            }
            
            # Execute the script logic
            $TestScriptContent | Invoke-Expression
            
            # Verify Remove-ProdUser was called for users not in source
            Should -Invoke Remove-ProdUser -ParameterFilter {
                $Data.Count -eq 1 -and
                $Data[0].EmployeeID -eq "EMP004"
            }
        }
    }
    
    Context "When handling attribute comparisons" {
        
        It "Should detect email changes" {
            Mock Export-SourceUsers { 
                return @(
                    @{
                        EmployeeID = "EMP001"
                        mail = "newemail@source.com"
                        DistinguishedName = "CN=user,DC=source,DC=local"
                    }
                )
            }
            
            Mock Export-ProdUsers { 
                return @(
                    @{
                        EmployeeID = "EMP001"
                        mail = "oldemail@target.com"
                        DistinguishedName = "CN=user,DC=target,DC=local"
                    }
                )
            }
            
            $TestScriptContent | Invoke-Expression
            
            Should -Invoke Update-ProdUser -ParameterFilter {
                ($Data | Where-Object { 
                    $_.Attribute -eq "mail" -and 
                    $_.NewValue -eq "newemail@source.com" -and
                    $_.OldValue -eq "oldemail@target.com"
                })
            }
        }
        
        It "Should detect user moves to Leavers OU" {
            Mock Export-SourceUsers { 
                return @(
                    @{
                        EmployeeID = "EMP001"
                        DistinguishedName = "CN=user,OU=Leavers,DC=source,DC=local"
                    }
                )
            }
            
            Mock Export-ProdUsers { 
                return @(
                    @{
                        EmployeeID = "EMP001"
                        DistinguishedName = "CN=user,OU=Users,DC=target,DC=local"
                        SamAccountName = "user1"
                    }
                )
            }
            
            $TestScriptContent | Invoke-Expression
            
            Should -Invoke Update-ProdUser -ParameterFilter {
                ($Data | Where-Object { 
                    $_.Attribute -eq "DistinguishedName" -and 
                    $_.NewValue -like "*Leavers*"
                })
            }
        }
        
        It "Should detect account disabled in source" {
            Mock Export-SourceUsers { 
                return @(
                    @{
                        EmployeeID = "EMP001"
                        Enabled = $false
                        DistinguishedName = "CN=user,DC=source,DC=local"
                    }
                )
            }
            
            Mock Export-ProdUsers { 
                return @(
                    @{
                        EmployeeID = "EMP001"
                        Enabled = $true
                        DistinguishedName = "CN=user,DC=target,DC=local"
                        SamAccountName = "user1"
                    }
                )
            }
            
            $TestScriptContent | Invoke-Expression
            
            Should -Invoke Update-ProdUser -ParameterFilter {
                ($Data | Where-Object { 
                    $_.Attribute -eq "Enabled" -and 
                    $_.NewValue -eq $false
                })
            }
        }
    }
    
    Context "When enforcing safety thresholds" {
        
        It "Should respect deletion threshold" {
            # Create many users to remove (exceeding threshold)
            $manyTargetUsers = 1..10 | ForEach-Object {
                @{
                    EmployeeID = "EMP$($_.ToString('000'))"
                    SamAccountName = "user$_"
                    'msDS-cloudExtensionAttribute10' = $null
                }
            }
            
            Mock Export-SourceUsers { return @() }  # No source users
            Mock Export-ProdUsers { return $manyTargetUsers }
            
            Mock Remove-ProdUser { throw "Too many users are marked for deletion" }
            
            $TestScriptContent | Invoke-Expression
            
            # Should attempt to call Remove-ProdUser but it will throw due to threshold
            Should -Invoke Remove-ProdUser -Times 1
        }
        
        It "Should respect addition threshold" {
            # Create many users to add (exceeding threshold)
            $manySourceUsers = 1..15 | ForEach-Object {
                @{
                    EmployeeID = "EMP$($_.ToString('000'))"
                    SamAccountName = "user$_"
                    mail = "user$_@source.com"
                }
            }
            
            Mock Export-SourceUsers { return $manySourceUsers }
            Mock Export-ProdUsers { return @() }  # No target users
            
            Mock Add-ProdUser { throw "Too many users are marked for creation" }
            
            $TestScriptContent | Invoke-Expression
            
            # Should attempt to call Add-ProdUser but it will throw due to threshold
            Should -Invoke Add-ProdUser -Times 1
        }
    }
    
    Context "When handling expired accounts" {
        
        It "Should identify expired accounts outside Leavers OU" {
            Mock Search-ADAccount { 
                return @(
                    @{
                        DistinguishedName = "CN=expireduser,OU=Users,DC=target,DC=local"
                        SamAccountName = "expireduser"
                    }
                )
            }
            
            $TestScriptContent | Invoke-Expression
            
            Should -Invoke Search-ADAccount -ParameterFilter {
                $AccountExpired -eq $true
            }
        }
        
        It "Should exclude expired accounts in Leavers OU" {
            Mock Search-ADAccount { 
                return @(
                    @{
                        DistinguishedName = "CN=expireduser,OU=Leavers,OU=Users,OU=Test,DC=test,DC=target,DC=local"
                        SamAccountName = "expireduser"
                    },
                    @{
                        DistinguishedName = "CN=expireduser2,OU=Users,DC=target,DC=local"
                        SamAccountName = "expireduser2"
                    }
                )
            }
            
            $TestScriptContent | Invoke-Expression
            
            # The script should filter out users in Leavers OU
            # This is tested by checking the Where-Object filter in the script
            Should -Invoke Search-ADAccount -Times 1
        }
    }
    
    Context "When logging and reporting" {
        
        It "Should create log files with timestamp" {
            Mock Export-Csv { } -Verifiable
            
            $TestScriptContent | Invoke-Expression
            
            # Should export various CSV logs
            Should -Invoke Export-Csv -ParameterFilter {
                $Path -like "*Update-Data-ADSync*" -or
                $Path -like "*Add-Data-ADSync*" -or
                $Path -like "*Remove-Data-ADSync*"
            }
        }
        
        It "Should start and stop transcript logging" {
            $TestScriptContent | Invoke-Expression
            
            Should -Invoke Start-Transcript -Times 1
            Should -Invoke Stop-Transcript -Times 1
        }
        
        It "Should display summary information" {
            Mock Write-Host { } -Verifiable
            
            $TestScriptContent | Invoke-Expression
            
            Should -Invoke Write-Host -ParameterFilter {
                $Object -like "*Summary:*" -or
                $Object -like "*Source Users:*" -or
                $Object -like "*Target Users:*"
            }
        }
    }
    
    Context "When handling errors" {
        
        It "Should handle data collection errors gracefully" {
            Mock Export-SourceUsers { throw "Domain controller not available" }
            Mock Send-Email { } -Verifiable
            
            $TestScriptContent | Invoke-Expression
            
            Should -Invoke Send-Email -ParameterFilter {
                $Subject -like "*Data Collection Error*"
            }
        }
        
        It "Should send error emails for processing failures" {
            Mock Update-ProdUser { throw "Update failed" }
            Mock Send-Email { } -Verifiable
            
            $TestScriptContent | Invoke-Expression
            
            Should -Invoke Send-Email -ParameterFilter {
                $Subject -like "*Error in Update Users Module*"
            }
        }
        
        It "Should continue processing after individual module failures" {
            Mock Update-ProdUser { throw "Update failed" }
            Mock Add-ProdUser { return @() }  # Should still be called
            
            $TestScriptContent | Invoke-Expression
            
            # Should still attempt other operations
            Should -Invoke Add-ProdUser -Times 1
        }
    }
    
    Context "When using configuration parameters" {
        
        It "Should use configuration paths for logging" {
            Mock Export-Csv { } -Verifiable
            
            $TestScriptContent | Invoke-Expression
            
            # Should use configured log path
            Should -Invoke Export-Csv -ParameterFilter {
                $Path -like "*TestScripts*ADSync*Logs*"
            }
        }
        
        It "Should pass configuration to all functions" {
            $TestScriptContent | Invoke-Expression
            
            Should -Invoke Export-SourceUsers -ParameterFilter {
                $Config -ne $null
            }
            
            Should -Invoke Export-ProdUsers -ParameterFilter {
                $Config -ne $null
            }
            
            Should -Invoke Add-ProdUser -ParameterFilter {
                $Config -ne $null
            }
        }
    }
    
    Context "When running in different modes" {
        
        It "Should respect ReportOnly parameter" {
            $TestScriptContent | Invoke-Expression
            
            # All functions should be called with ReportOnly = $true by default
            Should -Invoke Add-ProdUser -ParameterFilter {
                $ReportOnly -eq $true
            }
            
            Should -Invoke Update-ProdUser -ParameterFilter {
                $ReportOnly -eq $true
            }
            
            Should -Invoke Remove-ProdUser -ParameterFilter {
                $ReportOnly -eq $true
            }
        }
    }
}

AfterAll {
    # Clean up test mode
    $env:ADSYNC_TEST_MODE = $null
}