<#
.SYNOPSIS
    Pester tests for the general_functions.ps1 module

.DESCRIPTION
    Tests email functionality and user export functions for the AD-Sync-Solution.
    Uses mocks to avoid actual Active Directory connections.
#>

BeforeAll {
    # Import the module under test
    $ModulePath = Join-Path $PSScriptRoot "..\general_functions.ps1"
    . $ModulePath
    
    # Load test configuration
    $TestConfigPath = Join-Path $PSScriptRoot "TestConfig.json"
    $TestConfig = Get-ADSyncConfig -ConfigPath $TestConfigPath
    
    # Mock Active Directory commands to avoid actual connections
    Mock Get-ADDomainController { 
        return @{ hostname = "test-dc.test.local" }
    }
    
    Mock Get-ADUser { 
        return @(
            @{
                SamAccountName = "testuser1"
                mail = "testuser1@test.com"
                GivenName = "Test"
                Surname = "User1"
                EmployeeID = "EMP001"
                Enabled = $true
                DistinguishedName = "CN=testuser1,OU=Users,DC=test,DC=local"
            },
            @{
                SamAccountName = "testuser2"
                mail = "testuser2@test.com"
                GivenName = "Test"
                Surname = "User2"
                EmployeeID = "EMP002"
                Enabled = $true
                DistinguishedName = "CN=testuser2,OU=Users,DC=test,DC=local"
            }
        )
    }
    
    Mock Send-MailMessage { }
    Mock Test-Path { return $true }
    Mock Get-Content { return "encryptedpassword" }
    Mock ConvertTo-SecureString { return (ConvertTo-SecureString "password" -AsPlainText -Force) }
    Mock New-Object { 
        param($TypeName, $ArgumentList)
        if ($TypeName -eq "System.Management.Automation.PSCredential") {
            return [PSCredential]::new("testuser", (ConvertTo-SecureString "password" -AsPlainText -Force))
        }
    } -ParameterFilter { $TypeName -eq "System.Management.Automation.PSCredential" }
}

Describe "Send-Email" {
    
    Context "When sending email with valid configuration" {
        
        It "Should send email successfully" {
            Mock Send-MailMessage { } -Verifiable
            
            { Send-Email -Message "Test message" -Subject "Test subject" -Config $TestConfig } | Should -Not -Throw
            
            Should -Invoke Send-MailMessage -Times 1 -ParameterFilter {
                $From -eq $TestConfig.EmailConfiguration.From -and
                $To -eq $TestConfig.EmailConfiguration.To -and
                $Subject -eq "Test subject" -and
                $Body -like "*Test message*" -and
                $SmtpServer -eq $TestConfig.EmailConfiguration.SMTPServer -and
                $Port -eq $TestConfig.EmailConfiguration.SMTPPort
            }
        }
        
        It "Should include additional information in message body" {
            Mock Send-MailMessage { } -Verifiable
            
            Send-Email -Message "Test message" -Subject "Test subject" -Config $TestConfig
            
            Should -Invoke Send-MailMessage -Times 1 -ParameterFilter {
                $Body -like "*troubleshooting documentation*" -and
                $Body -like "*$($env:COMPUTERNAME)*" -and
                $Body -like "*$($TestConfig.General.ScriptRoot)*"
            }
        }
        
        It "Should handle email sending failures gracefully" {
            Mock Send-MailMessage { throw "SMTP server not available" }
            Mock Write-Warning { } -Verifiable
            
            { Send-Email -Message "Test message" -Subject "Test subject" -Config $TestConfig } | Should -Not -Throw
            
            Should -Invoke Write-Warning -Times 1 -ParameterFilter {
                $Message -like "*Failed to send email*"
            }
        }
    }
    
    Context "When email configuration is invalid" {
        
        It "Should use configuration values correctly" {
            $customConfig = $TestConfig.PSObject.Copy()
            $customConfig.EmailConfiguration.From = "custom@test.com"
            $customConfig.EmailConfiguration.To = "customto@test.com"
            $customConfig.EmailConfiguration.SMTPServer = "custom.smtp.com"
            $customConfig.EmailConfiguration.SMTPPort = 587
            
            Mock Send-MailMessage { } -Verifiable
            
            Send-Email -Message "Test" -Subject "Test" -Config $customConfig
            
            Should -Invoke Send-MailMessage -Times 1 -ParameterFilter {
                $From -eq "custom@test.com" -and
                $To -eq "customto@test.com" -and
                $SmtpServer -eq "custom.smtp.com" -and
                $Port -eq 587
            }
        }
    }
}

Describe "Export-SourceUsers" {
    
    Context "When connecting to source domain successfully" {
        
        It "Should retrieve users from source domain" {
            Mock Get-ADDomainController { 
                return @{ hostname = "source-dc.test.local" }
            }
            
            $users = Export-SourceUsers -Config $TestConfig
            
            $users | Should -Not -BeNullOrEmpty
            $users.Count | Should -BeGreaterThan 0
            
            Should -Invoke Get-ADDomainController -Times 1 -ParameterFilter {
                $DomainName -eq $TestConfig.SourceDomain.DomainName
            }
        }
        
        It "Should use correct search parameters" {
            Mock Get-ADUser { return @() } -Verifiable
            
            Export-SourceUsers -Config $TestConfig
            
            Should -Invoke Get-ADUser -Times 1 -ParameterFilter {
                $SearchBase -eq $TestConfig.SourceDomain.SearchBase -and
                $Server -eq "test-dc.test.local"
            }
        }
        
        It "Should exclude specified employee IDs" {
            Mock Get-ADUser { return @() } -Verifiable
            
            Export-SourceUsers -Config $TestConfig
            
            Should -Invoke Get-ADUser -Times 1 -ParameterFilter {
                $Filter -like "*EmployeeID -ne 'TEST001'*" -and
                $Filter -like "*EmployeeID -ne 'TEST002'*"
            }
        }
        
        It "Should sort users by EmployeeID" {
            $mockUsers = @(
                @{ EmployeeID = "EMP002"; SamAccountName = "user2" },
                @{ EmployeeID = "EMP001"; SamAccountName = "user1" },
                @{ EmployeeID = "EMP003"; SamAccountName = "user3" }
            )
            
            Mock Get-ADUser { return $mockUsers }
            
            $users = Export-SourceUsers -Config $TestConfig
            
            $users[0].EmployeeID | Should -Be "EMP001"
            $users[1].EmployeeID | Should -Be "EMP002"
            $users[2].EmployeeID | Should -Be "EMP003"
        }
    }
    
    Context "When domain controller connection fails" {
        
        It "Should throw error when unable to connect to domain controller" {
            Mock Get-ADDomainController { throw "Domain controller not found" }
            
            { Export-SourceUsers -Config $TestConfig } | Should -Throw "*Error connecting to Source Domain Controller*"
        }
    }
    
    Context "When credential file handling" {
        
        It "Should load credentials when file exists" {
            Mock Test-Path { return $true } -ParameterFilter { $Path -eq $TestConfig.General.CredentialFile }
            Mock Get-Content { return "encryptedpassword" }
            Mock ConvertTo-SecureString { return (ConvertTo-SecureString "password" -AsPlainText -Force) }
            
            Export-SourceUsers -Config $TestConfig
            
            Should -Invoke Get-Content -Times 1 -ParameterFilter { $Path -eq $TestConfig.General.CredentialFile }
        }
        
        It "Should handle missing credential file gracefully" {
            Mock Test-Path { return $false } -ParameterFilter { $Path -eq $TestConfig.General.CredentialFile }
            Mock Write-Warning { } -Verifiable
            
            Export-SourceUsers -Config $TestConfig
            
            Should -Invoke Write-Warning -Times 1 -ParameterFilter {
                $Message -like "*Credential file not found*"
            }
        }
        
        It "Should handle credential loading failures" {
            Mock Test-Path { return $true } -ParameterFilter { $Path -eq $TestConfig.General.CredentialFile }
            Mock Get-Content { throw "Access denied" }
            Mock Write-Warning { } -Verifiable
            
            Export-SourceUsers -Config $TestConfig
            
            Should -Invoke Write-Warning -Times 1 -ParameterFilter {
                $Message -like "*Failed to load credentials*"
            }
        }
    }
}

Describe "Export-ProdUsers" {
    
    Context "When connecting to target domain successfully" {
        
        It "Should retrieve users from target domain" {
            Mock Get-ADDomainController { 
                return @{ hostname = "target-dc.test.local" }
            }
            
            $users = Export-ProdUsers -Config $TestConfig
            
            $users | Should -Not -BeNullOrEmpty
            
            Should -Invoke Get-ADDomainController -Times 1 -ParameterFilter {
                $DomainName -eq $TestConfig.TargetDomain.DomainName
            }
        }
        
        It "Should use correct search parameters" {
            Mock Get-ADUser { return @() } -Verifiable
            
            Export-ProdUsers -Config $TestConfig
            
            Should -Invoke Get-ADUser -Times 1 -ParameterFilter {
                $Filter -eq "EmployeeID -like '*'" -and
                $SearchBase -eq $TestConfig.TargetDomain.SearchBase
            }
        }
        
        It "Should include target-only attributes" {
            $attributes = Get-ADUserAttributes -Config $TestConfig -IncludeTargetOnly
            
            Mock Get-ADUser { 
                param($Filter, $SearchBase, $Properties)
                $Properties | Should -Contain "Info"
                return @()
            } -Verifiable
            
            Export-ProdUsers -Config $TestConfig
            
            Should -Invoke Get-ADUser -Times 1
        }
        
        It "Should filter out test and service accounts" {
            $mockUsers = @(
                @{ 
                    SamAccountName = "regularuser"
                    EmployeeID = "EMP001"
                    'msDS-cloudExtensionAttribute10' = $null
                },
                @{ 
                    SamAccountName = "testuser"
                    EmployeeID = "EMP002"
                    'msDS-cloudExtensionAttribute10' = "Test Account"
                },
                @{ 
                    SamAccountName = "thirdpartyuser"
                    EmployeeID = "EMP003"
                    'msDS-cloudExtensionAttribute10' = "Third Party"
                }
            )
            
            Mock Get-ADUser { return $mockUsers }
            
            $users = Export-ProdUsers -Config $TestConfig
            
            $users.Count | Should -Be 1
            $users[0].SamAccountName | Should -Be "regularuser"
        }
        
        It "Should sort users by EmployeeID" {
            $mockUsers = @(
                @{ 
                    EmployeeID = "EMP002"
                    SamAccountName = "user2"
                    'msDS-cloudExtensionAttribute10' = $null
                },
                @{ 
                    EmployeeID = "EMP001"
                    SamAccountName = "user1"
                    'msDS-cloudExtensionAttribute10' = $null
                }
            )
            
            Mock Get-ADUser { return $mockUsers }
            
            $users = Export-ProdUsers -Config $TestConfig
            
            $users[0].EmployeeID | Should -Be "EMP001"
            $users[1].EmployeeID | Should -Be "EMP002"
        }
    }
    
    Context "When domain controller connection fails" {
        
        It "Should throw error when unable to connect to domain controller" {
            Mock Get-ADDomainController { throw "Domain controller not found" }
            
            { Export-ProdUsers -Config $TestConfig } | Should -Throw "*Error connecting to Target Domain Controller*"
        }
    }
    
    Context "When user retrieval fails" {
        
        It "Should throw error when Get-ADUser fails" {
            Mock Get-ADUser { throw "Access denied" }
            
            { Export-ProdUsers -Config $TestConfig } | Should -Throw "*Error connecting to Target Domain*"
        }
    }
}

Describe "Configuration Integration" {
    
    Context "When using configuration parameters" {
        
        It "Should use domain names from configuration" {
            Export-SourceUsers -Config $TestConfig
            
            Should -Invoke Get-ADDomainController -Times 1 -ParameterFilter {
                $DomainName -eq "test.source.local"
            }
        }
        
        It "Should use search bases from configuration" {
            Export-SourceUsers -Config $TestConfig
            
            Should -Invoke Get-ADUser -Times 1 -ParameterFilter {
                $SearchBase -eq "OU=TestAccounts,DC=test,DC=source,DC=local"
            }
        }
        
        It "Should use service account from configuration" {
            Export-SourceUsers -Config $TestConfig
            
            # Verify the service account is used in credential creation
            Should -Invoke New-Object -ParameterFilter { 
                $TypeName -eq "System.Management.Automation.PSCredential" -and
                $ArgumentList[0] -eq "test\svc-testsync"
            }
        }
    }
}