# AD-Sync-Solution Test Suite

This directory contains comprehensive Pester tests for the AD-Sync-Solution PowerShell scripts.

## Test Structure

### Test Files

- **ConfigHelper.Tests.ps1** - Tests for configuration management (`config_helper.ps1`)
- **GeneralFunctions.Tests.ps1** - Tests for email and user export functions (`general_functions.ps1`)
- **AddProdUser.Tests.ps1** - Tests for user creation functionality (`add_produser.ps1`)
- **RemoveProdUser.Tests.ps1** - Tests for user removal functionality (`remove_produser.ps1`)
- **UpdateProdUser.Tests.ps1** - Tests for user update functionality (`update_produser.ps1`)
- **StartADSync.Integration.Tests.ps1** - Integration tests for the main orchestration script

### Support Files

- **TestConfig.json** - Test configuration with safe test values
- **InvalidTestConfig.json** - Invalid configuration for negative testing
- **TestHelpers.ps1** - Common test utilities and mock data generators
- **Invoke-AllTests.ps1** - Master test runner script

## Running Tests

### Quick Start

```powershell
# Run all tests
.\Tests\Invoke-AllTests.ps1

# Run only unit tests
.\Tests\Invoke-AllTests.ps1 -TestType Unit

# Run with code coverage
.\Tests\Invoke-AllTests.ps1 -CodeCoverage -ExportResults
```

### Test Types

- **All** - Runs all tests (default)
- **Unit** - Runs all unit tests
- **Integration** - Runs integration tests only
- **ConfigHelper** - Tests configuration management only
- **GeneralFunctions** - Tests email and export functions only
- **UserManagement** - Tests user add/update/remove functions only

### Output Formats

- **Normal** - Standard Pester output (default)
- **Detailed** - Verbose test output with details
- **Minimal** - Minimal output for CI/CD scenarios

### Advanced Options

```powershell
# Run with detailed output and export results
.\Tests\Invoke-AllTests.ps1 -OutputFormat Detailed -ExportResults

# Run specific test type with code coverage
.\Tests\Invoke-AllTests.ps1 -TestType UserManagement -CodeCoverage

# Export results to custom location
.\Tests\Invoke-AllTests.ps1 -ExportResults -OutputPath "C:\TestResults"
```

## Test Coverage

The test suite covers:

### Configuration Management
- ✅ Configuration file loading and validation
- ✅ Environment variable expansion
- ✅ Required section and property validation
- ✅ Safety threshold validation (positive integers)
- ✅ Directory creation and validation
- ✅ Attribute management functions

### User Export Functions
- ✅ Source domain user retrieval
- ✅ Target domain user retrieval
- ✅ Domain controller discovery
- ✅ Credential handling
- ✅ User filtering and sorting
- ✅ Error handling

### User Management Functions
- ✅ User creation with all attributes
- ✅ Safety threshold enforcement
- ✅ Duplicate detection and handling
- ✅ Unix/Linux attribute management
- ✅ Two-stage user removal process
- ✅ Attribute updates and comparisons
- ✅ Account expiration handling
- ✅ User disabling and quarantine

### Email Functionality
- ✅ Email sending with configuration
- ✅ Error handling and reporting
- ✅ Message formatting

### Integration Testing
- ✅ User comparison logic
- ✅ Workflow coordination
- ✅ Consistent error handling patterns
- ✅ Logging and reporting
- ✅ Configuration integration

## Test Data

Tests use mock objects and data to avoid requiring actual Active Directory infrastructure:

- Mock AD cmdlets prevent actual directory operations
- Test configuration uses safe, non-production values
- Mock user data covers various scenarios
- Mock functions simulate different error conditions

## Prerequisites

- **PowerShell 5.1** or later
- **Pester 5.0** or later
- **ActiveDirectory** module (for cmdlet mocking)

Install Pester if not available:
```powershell
Install-Module -Name Pester -Force -SkipPublisherCheck
```

## CI/CD Integration

The test suite is designed for CI/CD integration:

### Exit Codes
- **0** - All tests passed
- **1** - Test failures or execution errors

### Output Files
When using `-ExportResults`:
- **TestResults.xml** - NUnit format test results
- **CodeCoverage.xml** - JaCoCo format coverage report
- **TestSummary.json** - Summary statistics

### Example CI/CD Usage

```powershell
# Azure DevOps / GitHub Actions
.\Tests\Invoke-AllTests.ps1 -TestType All -CodeCoverage -ExportResults -OutputFormat Minimal

# Check exit code
if ($LASTEXITCODE -ne 0) {
    Write-Error "Tests failed"
    exit $LASTEXITCODE
}
```

## Troubleshooting

### Common Issues

**"Pester module not found"**
- Install Pester: `Install-Module -Name Pester -Force`

**"Test files not found"**
- Ensure you're running from the correct directory
- Check that test files exist in the Tests directory

**"Mock not working"**
- Verify PowerShell execution policy allows script execution
- Check that all required modules are available

### Debug Mode

For detailed debugging:
```powershell
# Run with verbose output
.\Tests\Invoke-AllTests.ps1 -OutputFormat Detailed -Verbose

# Run specific test file directly
Invoke-Pester -Path .\Tests\ConfigHelper.Tests.ps1 -Output Detailed
```

## Contributing

When adding new functionality:

1. Add corresponding test coverage
2. Use the TestHelpers.ps1 utilities
3. Follow existing test patterns
4. Ensure all tests pass before submitting
5. Update this README if adding new test categories

### Test Naming Convention

- **Describe** blocks: Feature or function name
- **Context** blocks: Specific scenario or condition
- **It** blocks: Expected behavior statement

Example:
```powershell
Describe "Add-ProdUser" {
    Context "When processing valid user data" {
        It "Should create users successfully" {
            # Test implementation
        }
    }
}
```