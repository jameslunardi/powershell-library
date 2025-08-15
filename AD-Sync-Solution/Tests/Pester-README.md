# Pester Testing Guide for Windows Environments

This guide provides comprehensive instructions for running the AD-Sync-Solution Pester tests on Windows systems with the ActiveDirectory PowerShell module.

## 📋 Prerequisites

### Required Components
- **Windows Server 2012 R2** or later / **Windows 10** or later
- **PowerShell 5.1** or later (PowerShell 7+ recommended)
- **ActiveDirectory PowerShell module** (RSAT-AD-PowerShell feature)
- **Pester 5.0** or later

### Installation

#### 1. Install ActiveDirectory Module
```powershell
# On Windows Server
Install-WindowsFeature -Name RSAT-AD-PowerShell

# On Windows 10/11 (as Administrator)
Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0

# Verify installation
Import-Module ActiveDirectory
Get-Command -Module ActiveDirectory | Select-Object -First 5
```

#### 2. Install Pester
```powershell
# Install latest Pester (recommended)
Install-Module -Name Pester -Force -SkipPublisherCheck

# Verify installation
Get-Module Pester -ListAvailable
```

#### 3. Configure PowerShell Execution Policy
```powershell
# Check current policy
Get-ExecutionPolicy

# Set execution policy (if needed)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## 🚀 Quick Start

### Basic Test Execution
```powershell
# Navigate to AD-Sync-Solution directory
cd "C:\Scripts\ADSync"

# Run all tests
.\Tests\Invoke-AllTests.ps1

# Run with detailed output
.\Tests\Invoke-AllTests.ps1 -OutputFormat Detailed

# Run with code coverage analysis
.\Tests\Invoke-AllTests.ps1 -CodeCoverage -ExportResults
```

### Test Categories
```powershell
# Configuration management tests only
.\Tests\Invoke-AllTests.ps1 -TestType ConfigHelper

# All unit tests (recommended first run)
.\Tests\Invoke-AllTests.ps1 -TestType Unit

# User management functions only
.\Tests\Invoke-AllTests.ps1 -TestType UserManagement

# Integration tests (requires all modules)
.\Tests\Invoke-AllTests.ps1 -TestType Integration

# All tests including integration
.\Tests\Invoke-AllTests.ps1 -TestType All
```

## 📊 Test Coverage Overview

### Test Files and Coverage

| Test File | Coverage | Tests | Description |
|-----------|----------|-------|-------------|
| **ConfigHelper.Tests.ps1** | 95%+ | 20 | Configuration management and validation |
| **GeneralFunctions.Tests.ps1** | 90%+ | 22 | Email functions and user export |
| **AddProdUser.Tests.ps1** | 90%+ | 20 | User creation functionality |
| **RemoveProdUser.Tests.ps1** | 85%+ | 16 | User removal and quarantine |
| **UpdateProdUser.Tests.ps1** | 90%+ | 18 | User attribute updates |
| **StartADSync.Integration.Tests.ps1** | 80%+ | 10 | End-to-end workflow |

### Total Test Metrics
- **106 Total Tests**
- **~85% Average Code Coverage**
- **All Critical Paths Tested**
- **Error Scenarios Validated**

## 🧪 Detailed Test Scenarios

### Configuration Management Tests
```powershell
# Test configuration loading and validation
Invoke-Pester -Path ".\Tests\ConfigHelper.Tests.ps1" -Output Detailed

# What's tested:
# ✅ JSON configuration loading
# ✅ Environment variable expansion
# ✅ Required section validation
# ✅ Directory creation and permissions
# ✅ Error handling for invalid configs
```

### User Export Function Tests
```powershell
# Test domain connectivity and user retrieval
Invoke-Pester -Path ".\Tests\GeneralFunctions.Tests.ps1" -Output Detailed

# What's tested:
# ✅ Domain controller discovery
# ✅ Credential handling (encrypted passwords)
# ✅ User filtering and exclusions
# ✅ Email notification functionality
# ✅ LDAP query construction
# ✅ Error handling for connection failures
```

### User Management Tests
```powershell
# Test all user operations
Invoke-Pester -Path ".\Tests\AddProdUser.Tests.ps1" -Output Detailed
Invoke-Pester -Path ".\Tests\UpdateProdUser.Tests.ps1" -Output Detailed  
Invoke-Pester -Path ".\Tests\RemoveProdUser.Tests.ps1" -Output Detailed

# What's tested:
# ✅ User creation with all attributes
# ✅ Safety threshold enforcement
# ✅ Duplicate detection and handling
# ✅ Unix/Linux SFU attribute management
# ✅ Two-stage removal process
# ✅ Attribute updates and comparisons
# ✅ Account expiration handling
# ✅ Group membership cleanup
```

### Integration Tests
```powershell
# Test complete workflow coordination
Invoke-Pester -Path ".\Tests\StartADSync.Integration.Tests.ps1" -Output Detailed

# What's tested:
# ✅ User comparison logic
# ✅ Workflow orchestration
# ✅ Safety threshold coordination
# ✅ Error recovery and rollback
# ✅ Logging and audit trails
# ✅ Configuration integration
```

## 📈 Advanced Testing Options

### Code Coverage Analysis
```powershell
# Generate comprehensive code coverage report
.\Tests\Invoke-AllTests.ps1 -CodeCoverage -ExportResults -OutputPath "C:\TestReports"

# Output files:
# - TestResults.xml (NUnit format)
# - CodeCoverage.xml (JaCoCo format) 
# - TestSummary.json (Custom summary)
```

### Performance Testing
```powershell
# Test with performance metrics
Measure-Command { .\Tests\Invoke-AllTests.ps1 -TestType Unit }

# Optimize for CI/CD environments
.\Tests\Invoke-AllTests.ps1 -OutputFormat Minimal -TestType Unit
```

### Parallel Test Execution
```powershell
# Run test categories in parallel (PowerShell 7+)
$jobs = @(
    Start-Job { Invoke-Pester -Path ".\Tests\ConfigHelper.Tests.ps1" }
    Start-Job { Invoke-Pester -Path ".\Tests\GeneralFunctions.Tests.ps1" }
    Start-Job { Invoke-Pester -Path ".\Tests\AddProdUser.Tests.ps1" }
)

$jobs | Receive-Job -Wait
```

## 🛠️ Troubleshooting

### Common Issues and Solutions

#### ActiveDirectory Module Not Found
```powershell
# Check if module is available
Get-Module -ListAvailable ActiveDirectory

# Install RSAT tools
# Windows Server:
Install-WindowsFeature -Name RSAT-AD-PowerShell

# Windows 10/11:
Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0
```

#### Pester Version Conflicts
```powershell
# Remove old Pester versions
Get-Module Pester -ListAvailable | Uninstall-Module -Force

# Install latest version
Install-Module -Name Pester -Force -SkipPublisherCheck

# Import specific version
Import-Module Pester -RequiredVersion 5.7.1
```

#### Permission Issues
```powershell
# Run as Administrator for system-level tests
Start-Process PowerShell -Verb RunAs

# Set execution policy
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Check current user permissions
whoami /groups
```

#### Configuration File Issues
```powershell
# Validate configuration syntax
Test-Json -Path ".\config.json"

# Test with sample configuration
.\test_config.ps1 -ConfigPath ".\Tests\TestConfig.json"

# Check environment variables
Get-ChildItem Env: | Where-Object Name -like "*ADSYNC*"
```

### Debug Mode Testing
```powershell
# Enable verbose output for debugging
$VerbosePreference = "Continue"
.\Tests\Invoke-AllTests.ps1 -TestType ConfigHelper -OutputFormat Detailed

# Run individual test with debugging
Invoke-Pester -Path ".\Tests\ConfigHelper.Tests.ps1" -Output Diagnostic

# Reset verbose preference
$VerbosePreference = "SilentlyContinue"
```

## 🔧 Customizing Tests

### Adding Custom Test Cases
```powershell
# Example: Add custom configuration test
Describe "Custom Environment Tests" {
    Context "When testing production configuration" {
        It "Should validate production domains are reachable" {
            # Your custom test logic here
            $result = Test-Connection "prod.domain.com" -Count 1 -Quiet
            $result | Should -Be $true
        }
    }
}
```

### Environment-Specific Testing
```powershell
# Create environment-specific test configuration
Copy-Item ".\Tests\TestConfig.json" ".\Tests\ProdTestConfig.json"

# Edit ProdTestConfig.json with production-like values
# Run tests with custom config
$env:ADSYNC_CONFIG = ".\Tests\ProdTestConfig.json"
.\Tests\Invoke-AllTests.ps1 -TestType ConfigHelper
```

## 📋 CI/CD Integration

### Azure DevOps Pipeline
```yaml
# azure-pipelines.yml
steps:
- task: PowerShell@2
  displayName: 'Run Pester Tests'
  inputs:
    targetType: 'inline'
    script: |
      .\Tests\Invoke-AllTests.ps1 -TestType Unit -ExportResults -OutputFormat Minimal
    workingDirectory: '$(Build.SourcesDirectory)\AD-Sync-Solution'

- task: PublishTestResults@2
  inputs:
    testResultsFormat: 'NUnit'
    testResultsFiles: '**/TestResults.xml'
    testRunTitle: 'AD-Sync Pester Tests'
```

### GitHub Actions
```yaml
# .github/workflows/test.yml
- name: Run Pester Tests
  shell: pwsh
  run: |
    .\Tests\Invoke-AllTests.ps1 -TestType Unit -ExportResults -OutputFormat Minimal
  working-directory: ./AD-Sync-Solution

- name: Upload Test Results
  uses: actions/upload-artifact@v3
  with:
    name: test-results
    path: AD-Sync-Solution/Tests/TestResults/
```

### Jenkins Pipeline
```groovy
// Jenkinsfile
stage('Test') {
    steps {
        powershell '''
            cd AD-Sync-Solution
            .\\Tests\\Invoke-AllTests.ps1 -TestType Unit -ExportResults -OutputFormat Minimal
        '''
    }
    post {
        always {
            nunit testResultsPattern: 'AD-Sync-Solution/Tests/TestResults/TestResults.xml'
        }
    }
}
```

## 📊 Expected Test Results

### Successful Test Run Output
```
==============================================================
AD-Sync-Solution Pester Test Runner
==============================================================

Configuration:
  Test Type: Unit
  Output Format: Normal
  Code Coverage: True
  Export Results: True

Test Files to Execute:
  - ConfigHelper.Tests.ps1
  - GeneralFunctions.Tests.ps1
  - AddProdUser.Tests.ps1
  - RemoveProdUser.Tests.ps1
  - UpdateProdUser.Tests.ps1

Starting test execution...

Tests completed in 45.2s
Tests Passed: 96, Failed: 0, Skipped: 0

Code Coverage:
  Total Lines: 2,847
  Covered Lines: 2,456
  Coverage: 86.3%

All tests passed successfully!
```

### Test Failure Investigation
```powershell
# When tests fail, investigate with:

# 1. Run specific failing test with detailed output
Invoke-Pester -Path ".\Tests\FailingTest.Tests.ps1" -Output Detailed

# 2. Check configuration
.\test_config.ps1

# 3. Verify ActiveDirectory module
Get-Command -Module ActiveDirectory | Select-Object -First 5

# 4. Check permissions
Test-Path "C:\Scripts\ADSync" -PathType Container
```

## 🎯 Best Practices

### Before Running Tests
1. **Backup configuration** - Save current config before testing
2. **Validate prerequisites** - Ensure all modules are installed  
3. **Check permissions** - Run with appropriate privileges
4. **Review test environment** - Use test configurations, not production

### During Testing
1. **Start with unit tests** - Validate individual components first
2. **Monitor resource usage** - Tests create temporary files and connections
3. **Review test output** - Check for warnings and deprecation notices
4. **Validate test data** - Ensure mock data represents realistic scenarios

### After Testing
1. **Review coverage reports** - Identify untested code paths
2. **Clean up artifacts** - Remove temporary test files and directories
3. **Document failures** - Record any environmental issues encountered
4. **Update tests** - Improve test coverage based on findings

## 📞 Support and Resources

### Getting Help
- **Test Issues**: Review individual test files for specific error patterns
- **Configuration Problems**: Use `.\test_config.ps1` for validation
- **Performance Issues**: Run tests individually to isolate problems
- **Coverage Analysis**: Use exported reports for detailed analysis

### Additional Resources
- **[Main README](../README.md)** - Complete AD-Sync-Solution documentation
- **[Tests README](README.md)** - General testing guide (all platforms)

### Test Maintenance
- **Regular Updates**: Keep tests updated with code changes
- **Performance Monitoring**: Track test execution times
- **Coverage Goals**: Maintain >85% code coverage
- **Environment Testing**: Validate in staging before production

---

**Windows-Specific Pester Testing Guide** - Part of the comprehensive AD-Sync-Solution test suite.