<#
.SYNOPSIS
    Pester tests for the config_helper.ps1 module

.DESCRIPTION
    Tests configuration loading, validation, and helper functions
    for the AD-Sync-Solution configuration management.
#>

BeforeAll {
    # Import the module under test
    $ModulePath = Join-Path $PSScriptRoot "..\config_helper.ps1"
    . $ModulePath
    
    # Set up test paths
    $TestConfigPath = Join-Path $PSScriptRoot "TestConfig.json"
    $InvalidConfigPath = Join-Path $PSScriptRoot "InvalidTestConfig.json"
    $NonExistentConfigPath = Join-Path $PSScriptRoot "NonExistent.json"
    
    # Create a temporary directory for testing directory creation  
    $TempDir = if ($IsLinux -or $IsMacOS) { "/tmp" } else { $env:TEMP }
    $TempTestRoot = Join-Path $TempDir "ADSyncTest_$(Get-Random)"
}

AfterAll {
    # Clean up temporary test directory
    if (Test-Path $TempTestRoot) {
        Remove-Item $TempTestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe "Get-ADSyncConfig" {
    
    Context "When loading a valid configuration file" {
        
        It "Should load configuration successfully" {
            $config = Get-ADSyncConfig -ConfigPath $TestConfigPath
            $config | Should -Not -BeNullOrEmpty
        }
        
        It "Should contain all required sections" {
            $config = Get-ADSyncConfig -ConfigPath $TestConfigPath
            
            $config.General | Should -Not -BeNullOrEmpty
            $config.SafetyThresholds | Should -Not -BeNullOrEmpty
            $config.SourceDomain | Should -Not -BeNullOrEmpty
            $config.TargetDomain | Should -Not -BeNullOrEmpty
            $config.UnixConfiguration | Should -Not -BeNullOrEmpty
            $config.EmailConfiguration | Should -Not -BeNullOrEmpty
            $config.UserAttributes | Should -Not -BeNullOrEmpty
        }
        
        It "Should have correct values from test config" {
            $config = Get-ADSyncConfig -ConfigPath $TestConfigPath
            
            $config.General.ScriptRoot | Should -Be "C:\TestScripts\ADSync"
            $config.SafetyThresholds.DeletionThreshold | Should -Be 5
            $config.SourceDomain.DomainName | Should -Be "test.source.local"
            $config.TargetDomain.DomainName | Should -Be "test.target.local"
            $config.EmailConfiguration.From | Should -Be "testsync@test.com"
        }
        
        It "Should validate required properties exist" {
            { Get-ADSyncConfig -ConfigPath $TestConfigPath } | Should -Not -Throw
        }
    }
    
    Context "When loading an invalid configuration file" {
        
        It "Should throw error for missing required sections" {
            { Get-ADSyncConfig -ConfigPath $InvalidConfigPath } | Should -Throw
        }
        
        It "Should throw error for non-existent file" {
            { Get-ADSyncConfig -ConfigPath $NonExistentConfigPath } | Should -Throw "*not found*"
        }
        
        It "Should throw error for invalid JSON" {
            $InvalidJsonPath = Join-Path $PSScriptRoot "InvalidJson.json"
            "{ invalid json" | Out-File $InvalidJsonPath -Encoding UTF8
            
            try {
                { Get-ADSyncConfig -ConfigPath $InvalidJsonPath } | Should -Throw
            }
            finally {
                Remove-Item $InvalidJsonPath -ErrorAction SilentlyContinue
            }
        }
    }
    
    Context "When using environment variables" {
        
        BeforeEach {
            # Clear any existing environment variable
            $env:ADSYNC_CONFIG = $null
        }
        
        AfterEach {
            # Clean up environment variable
            $env:ADSYNC_CONFIG = $null
        }
        
        It "Should use ADSYNC_CONFIG environment variable when set" {
            $env:ADSYNC_CONFIG = $TestConfigPath
            
            Mock Write-Verbose { } -Verifiable
            
            $config = Get-ADSyncConfig
            $config.General.ScriptRoot | Should -Be "C:\TestScripts\ADSync"
            
            Should -Invoke Write-Verbose -ParameterFilter { 
                $Message -like "*environment variable*" 
            }
        }
        
        It "Should use default location when no environment variable" {
            $env:ADSYNC_CONFIG = $null
            
            Mock Write-Verbose { } -Verifiable
            
            # This will fail because there's no default config.json, but we can test the path logic
            { Get-ADSyncConfig } | Should -Throw "*not found*"
            
            Should -Invoke Write-Verbose -ParameterFilter { 
                $Message -like "*default config path*" 
            }
        }
    }
}

Describe "Get-ADUserAttributes" {
    
    BeforeAll {
        $config = Get-ADSyncConfig -ConfigPath $TestConfigPath
    }
    
    Context "When getting standard attributes" {
        
        It "Should return standard and cloud extension attributes" {
            $attributes = Get-ADUserAttributes -Config $config
            
            $attributes | Should -Contain "SamAccountName"
            $attributes | Should -Contain "mail" 
            $attributes | Should -Contain "GivenName"
            $attributes | Should -Contain "msDS-cloudExtensionAttribute1"
            $attributes | Should -Not -Contain "Info"
        }
        
        It "Should return correct number of attributes" {
            $attributes = Get-ADUserAttributes -Config $config
            $expectedCount = $config.UserAttributes.StandardAttributes.Count + 
                           $config.UserAttributes.CloudExtensionAttributes.Count
            
            $attributes.Count | Should -Be $expectedCount
        }
    }
    
    Context "When including target-only attributes" {
        
        It "Should include target-only attributes when requested" {
            $attributes = Get-ADUserAttributes -Config $config -IncludeTargetOnly
            
            $attributes | Should -Contain "Info"
            $attributes | Should -Contain "SamAccountName"
            $attributes | Should -Contain "msDS-cloudExtensionAttribute1"
        }
        
        It "Should return more attributes when including target-only" {
            $standardAttributes = Get-ADUserAttributes -Config $config
            $allAttributes = Get-ADUserAttributes -Config $config -IncludeTargetOnly
            
            $allAttributes.Count | Should -BeGreaterThan $standardAttributes.Count
        }
    }
    
    Context "When config parameter is missing" {
        
        It "Should throw error when config is null" {
            { Get-ADUserAttributes -Config $null } | Should -Throw
        }
    }
}

Describe "Test-ADSyncDirectories" {
    
    BeforeAll {
        # Create a test config with temp directories
        $testConfig = @{
            General = @{
                ScriptRoot = Join-Path $TempTestRoot "Scripts"
                LogPath = Join-Path $TempTestRoot "Logs"
            }
        } | ConvertTo-Json | ConvertFrom-Json
    }
    
    Context "When directories don't exist" {
        
        It "Should create missing directories" {
            # Ensure directories don't exist
            if (Test-Path $testConfig.General.ScriptRoot) {
                Remove-Item $testConfig.General.ScriptRoot -Recurse -Force
            }
            if (Test-Path $testConfig.General.LogPath) {
                Remove-Item $testConfig.General.LogPath -Recurse -Force
            }
            
            Test-ADSyncDirectories -Config $testConfig
            
            Test-Path $testConfig.General.ScriptRoot | Should -Be $true
            Test-Path $testConfig.General.LogPath | Should -Be $true
        }
        
        It "Should not throw when directories already exist" {
            # Directories should exist from previous test
            { Test-ADSyncDirectories -Config $testConfig } | Should -Not -Throw
        }
    }
    
    Context "When directory creation fails" {
        
        It "Should throw error when unable to create directory" {
            # Use a path that requires permissions or is invalid
            $invalidPath = if ($IsLinux -or $IsMacOS) { "/root/restricteddir" } else { "Z:\NonExistentDrive\Scripts" }
            $invalidConfig = @{
                General = @{
                    ScriptRoot = $invalidPath
                    LogPath = "$invalidPath\Logs"
                }
            } | ConvertTo-Json | ConvertFrom-Json
            
            { Test-ADSyncDirectories -Config $invalidConfig } | Should -Throw
        }
    }
}

Describe "Configuration Validation" {
    
    Context "When required sections are missing" {
        
        It "Should throw for missing General section" {
            $incompleteConfig = @{
                SafetyThresholds = @{ DeletionThreshold = 5 }
            } | ConvertTo-Json
            
            $configPath = Join-Path $PSScriptRoot "TempIncomplete.json"
            $incompleteConfig | Out-File $configPath -Encoding UTF8
            
            try {
                { Get-ADSyncConfig -ConfigPath $configPath } | Should -Throw "*Missing required configuration section: General*"
            }
            finally {
                Remove-Item $configPath -ErrorAction SilentlyContinue
            }
        }
        
        It "Should throw for missing required properties" {
            $incompleteConfig = @{
                General = @{ ScriptRoot = "C:\Test" }
                SafetyThresholds = @{ DeletionThreshold = 5 }
                SourceDomain = @{ DomainName = "test.local" }
                TargetDomain = @{ DomainName = "test.local" }
                UnixConfiguration = @{ DefaultGidNumber = "1000" }
                EmailConfiguration = @{ From = "test@test.com" }
                UserAttributes = @{ StandardAttributes = @() }
            } | ConvertTo-Json
            
            $configPath = Join-Path $PSScriptRoot "TempIncomplete2.json"
            $incompleteConfig | Out-File $configPath -Encoding UTF8
            
            try {
                { Get-ADSyncConfig -ConfigPath $configPath } | Should -Throw "*Missing required property*"
            }
            finally {
                Remove-Item $configPath -ErrorAction SilentlyContinue
            }
        }
    }
}

Describe "Environment Variable Expansion" {
    
    BeforeAll {
        # Set a test environment variable
        $env:TEST_ADSYNC_ROOT = "C:\TestExpansion"
    }
    
    AfterAll {
        # Clean up test environment variable
        Remove-Item env:TEST_ADSYNC_ROOT -ErrorAction SilentlyContinue
    }
    
    Context "When configuration contains environment variables" {
        
        It "Should expand environment variables in paths" {
            $configWithEnvVars = @{
                General = @{
                    ScriptRoot = "%TEST_ADSYNC_ROOT%\Scripts"
                    LogPath = "%TEST_ADSYNC_ROOT%\Logs"
                    CredentialFile = "%TEST_ADSYNC_ROOT%\creds.txt"
                }
                SafetyThresholds = @{
                    DeletionThreshold = 5
                    AdditionThreshold = 10
                    UpdateThreshold = 15
                }
                SourceDomain = @{
                    DomainName = "test.local"
                    SearchBase = "DC=test,DC=local"
                    ServiceAccount = "test\svc"
                    ExcludedEmployeeIDs = @()
                }
                TargetDomain = @{
                    DomainName = "test.local"
                    SearchBase = "DC=test,DC=local"
                    InactiveOU = "OU=Inactive,DC=test,DC=local"
                    LeaversOU = "OU=Leavers,DC=test,DC=local"
                    NISObjectDN = "CN=test,DC=test,DC=local"
                    ExcludePatterns = @()
                }
                UnixConfiguration = @{
                    DefaultGidNumber = "1000"
                    DefaultLoginShell = "/bin/bash"
                    NisDomain = "test"
                }
                EmailConfiguration = @{
                    From = "test@test.com"
                    To = "test@test.com"
                    SMTPServer = "smtp.test.com"
                    SMTPPort = 25
                }
                UserAttributes = @{
                    StandardAttributes = @("SamAccountName")
                    CloudExtensionAttributes = @("msDS-cloudExtensionAttribute1")
                    TargetOnlyAttributes = @("Info")
                }
            } | ConvertTo-Json -Depth 10
            
            $configPath = Join-Path $PSScriptRoot "TempEnvVar.json"
            $configWithEnvVars | Out-File $configPath -Encoding UTF8
            
            try {
                $config = Get-ADSyncConfig -ConfigPath $configPath
                
                $config.General.ScriptRoot | Should -Be "C:\TestExpansion\Scripts"
                $config.General.LogPath | Should -Be "C:\TestExpansion\Logs"
                $config.General.CredentialFile | Should -Be "C:\TestExpansion\creds.txt"
            }
            finally {
                Remove-Item $configPath -ErrorAction SilentlyContinue
            }
        }
    }
}