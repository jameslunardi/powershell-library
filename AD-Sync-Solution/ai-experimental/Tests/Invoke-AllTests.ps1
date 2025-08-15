<#
.SYNOPSIS
    Master test runner for AD-Sync-Solution Pester tests

.DESCRIPTION
    Runs all Pester tests for the AD-Sync-Solution with proper setup,
    reporting, and cleanup. Supports different test configurations and
    output formats.

.PARAMETER TestType
    Type of tests to run: All, Unit, Integration, or specific module

.PARAMETER OutputFormat
    Pester output format: Normal, Detailed, or Minimal

.PARAMETER CodeCoverage
    Enable code coverage analysis

.PARAMETER ExportResults
    Export test results to files

.EXAMPLE
    .\Invoke-AllTests.ps1
    Runs all tests with default settings

.EXAMPLE
    .\Invoke-AllTests.ps1 -TestType Unit -OutputFormat Detailed
    Runs only unit tests with detailed output

.EXAMPLE
    .\Invoke-AllTests.ps1 -CodeCoverage -ExportResults
    Runs all tests with code coverage and exports results
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("All", "Unit", "Integration", "ConfigHelper", "GeneralFunctions", "UserManagement")]
    [string]$TestType = "All",
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("Normal", "Detailed", "Minimal")]
    [string]$OutputFormat = "Normal",
    
    [Parameter(Mandatory = $false)]
    [switch]$CodeCoverage,
    
    [Parameter(Mandatory = $false)]
    [switch]$ExportResults,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "TestResults"
)

#region Setup
# =============================================================================
# TEST ENVIRONMENT SETUP
# =============================================================================

# Get script directory
$TestsPath = $PSScriptRoot
$SolutionPath = Split-Path $TestsPath -Parent

Write-Host "==============================================================" -ForegroundColor Green
Write-Host "AD-Sync-Solution Pester Test Runner" -ForegroundColor Green
Write-Host "==============================================================" -ForegroundColor Green
Write-Host ""

Write-Host "Configuration:" -ForegroundColor Cyan
Write-Host "  Test Type: $TestType" -ForegroundColor White
Write-Host "  Output Format: $OutputFormat" -ForegroundColor White
Write-Host "  Code Coverage: $CodeCoverage" -ForegroundColor White
Write-Host "  Export Results: $ExportResults" -ForegroundColor White
Write-Host "  Tests Path: $TestsPath" -ForegroundColor White
Write-Host "  Solution Path: $SolutionPath" -ForegroundColor White
Write-Host ""

# Check if Pester is available
try {
    $pesterVersion = Get-Module Pester -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
    if (-not $pesterVersion) {
        throw "Pester module not found"
    }
    
    Write-Host "Pester Version: $($pesterVersion.Version)" -ForegroundColor Green
    
    # Import Pester
    Import-Module Pester -Force
}
catch {
    Write-Error "Failed to load Pester module: $($_.Exception.Message)"
    Write-Host "Please install Pester with: Install-Module -Name Pester -Force" -ForegroundColor Yellow
    exit 1
}

# Create output directory if needed
if ($ExportResults) {
    $OutputPath = Join-Path $TestsPath $OutputPath
    if (-not (Test-Path $OutputPath)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
        Write-Host "Created output directory: $OutputPath" -ForegroundColor Green
    }
}

#endregion Setup

#region Test Selection
# =============================================================================
# DETERMINE WHICH TESTS TO RUN
# =============================================================================

$testFiles = @()

switch ($TestType) {
    "All" {
        $testFiles = Get-ChildItem -Path $TestsPath -Filter "*.Tests.ps1" | ForEach-Object { $_.FullName }
    }
    "Unit" {
        $testFiles = @(
            (Join-Path $TestsPath "ConfigHelper.Tests.ps1"),
            (Join-Path $TestsPath "GeneralFunctions.Tests.ps1"),
            (Join-Path $TestsPath "AddProdUser.Tests.ps1"),
            (Join-Path $TestsPath "RemoveProdUser.Tests.ps1"),
            (Join-Path $TestsPath "UpdateProdUser.Tests.ps1")
        )
    }
    "Integration" {
        $testFiles = @(
            (Join-Path $TestsPath "StartADSync.Integration.Tests.ps1")
        )
    }
    "ConfigHelper" {
        $testFiles = @((Join-Path $TestsPath "ConfigHelper.Tests.ps1"))
    }
    "GeneralFunctions" {
        $testFiles = @((Join-Path $TestsPath "GeneralFunctions.Tests.ps1"))
    }
    "UserManagement" {
        $testFiles = @(
            (Join-Path $TestsPath "AddProdUser.Tests.ps1"),
            (Join-Path $TestsPath "RemoveProdUser.Tests.ps1"),
            (Join-Path $TestsPath "UpdateProdUser.Tests.ps1")
        )
    }
}

# Filter out non-existent files
$testFiles = $testFiles | Where-Object { Test-Path $_ }

if ($testFiles.Count -eq 0) {
    Write-Warning "No test files found for test type: $TestType"
    exit 1
}

Write-Host "Test Files to Execute:" -ForegroundColor Cyan
$testFiles | ForEach-Object { 
    Write-Host "  - $(Split-Path $_ -Leaf)" -ForegroundColor White 
}
Write-Host ""

#endregion Test Selection

#region Test Configuration
# =============================================================================
# CONFIGURE PESTER SETTINGS
# =============================================================================

$pesterConfig = @{
    Run = @{
        Path = $testFiles
        PassThru = $true
    }
    Should = @{
        ErrorAction = 'Stop'
    }
    Output = @{
        Verbosity = switch ($OutputFormat) {
            "Minimal" { "Minimal" }
            "Detailed" { "Detailed" }
            default { "Normal" }
        }
    }
}

# Add code coverage if requested
if ($CodeCoverage) {
    $sourceFiles = @(
        Join-Path $SolutionPath "config_helper.ps1",
        Join-Path $SolutionPath "general_functions.ps1",
        Join-Path $SolutionPath "add_produser.ps1",
        Join-Path $SolutionPath "remove_produser.ps1",
        Join-Path $SolutionPath "update_produser.ps1"
    ) | Where-Object { Test-Path $_ }
    
    $pesterConfig.CodeCoverage = @{
        Enabled = $true
        Path = $sourceFiles
        OutputFormat = "JaCoCo"
    }
    
    if ($ExportResults) {
        $pesterConfig.CodeCoverage.OutputPath = Join-Path $OutputPath "CodeCoverage.xml"
    }
    
    Write-Host "Code Coverage Enabled for:" -ForegroundColor Cyan
    $sourceFiles | ForEach-Object { 
        Write-Host "  - $(Split-Path $_ -Leaf)" -ForegroundColor White 
    }
    Write-Host ""
}

# Add test results export if requested
if ($ExportResults) {
    $pesterConfig.TestResult = @{
        Enabled = $true
        OutputFormat = "NUnitXml"
        OutputPath = Join-Path $OutputPath "TestResults.xml"
    }
    
    Write-Host "Test results will be exported to: $(Join-Path $OutputPath "TestResults.xml")" -ForegroundColor Green
    Write-Host ""
}

#endregion Test Configuration

#region Test Execution
# =============================================================================
# EXECUTE TESTS
# =============================================================================

Write-Host "Starting test execution..." -ForegroundColor Yellow
Write-Host ""

$startTime = Get-Date

try {
    # Create Pester configuration object
    $config = New-PesterConfiguration -Hashtable $pesterConfig
    
    # Run tests
    $testResults = Invoke-Pester -Configuration $config
    
    $endTime = Get-Date
    $duration = $endTime - $startTime
    
    Write-Host ""
    Write-Host "==============================================================" -ForegroundColor Green
    Write-Host "Test Execution Complete" -ForegroundColor Green
    Write-Host "==============================================================" -ForegroundColor Green
    
    # Display summary
    Write-Host ""
    Write-Host "Summary:" -ForegroundColor Cyan
    Write-Host "  Total Tests: $($testResults.TotalCount)" -ForegroundColor White
    Write-Host "  Passed: $($testResults.PassedCount)" -ForegroundColor Green
    Write-Host "  Failed: $($testResults.FailedCount)" -ForegroundColor Red
    Write-Host "  Skipped: $($testResults.SkippedCount)" -ForegroundColor Yellow
    Write-Host "  Duration: $($duration.ToString('mm\:ss\.fff'))" -ForegroundColor White
    
    # Display failed tests if any
    if ($testResults.FailedCount -gt 0) {
        Write-Host ""
        Write-Host "Failed Tests:" -ForegroundColor Red
        $testResults.Tests | Where-Object { $_.Result -eq "Failed" } | ForEach-Object {
            Write-Host "  - $($_.ExpandedName)" -ForegroundColor Red
            if ($_.ErrorRecord) {
                Write-Host "    Error: $($_.ErrorRecord.Exception.Message)" -ForegroundColor DarkRed
            }
        }
    }
    
    # Display code coverage if enabled
    if ($CodeCoverage -and $testResults.CodeCoverage) {
        Write-Host ""
        Write-Host "Code Coverage:" -ForegroundColor Cyan
        
        $coverage = $testResults.CodeCoverage
        $totalLines = $coverage.NumberOfCommandsAnalyzed
        $coveredLines = $coverage.NumberOfCommandsExecuted
        $coveragePercent = if ($totalLines -gt 0) { [math]::Round(($coveredLines / $totalLines) * 100, 2) } else { 0 }
        
        Write-Host "  Total Lines: $totalLines" -ForegroundColor White
        Write-Host "  Covered Lines: $coveredLines" -ForegroundColor White
        Write-Host "  Coverage: $coveragePercent%" -ForegroundColor $(if ($coveragePercent -ge 80) { "Green" } elseif ($coveragePercent -ge 60) { "Yellow" } else { "Red" })
        
        # Show files with low coverage
        $coverage.AnalyzedFiles | ForEach-Object {
            $file = $_
            $fileLines = ($coverage.HitCommands | Where-Object { $_.File -eq $file }).Count
            $fileTotalLines = ($coverage.AnalyzedCommands | Where-Object { $_.File -eq $file }).Count
            $fileCoverage = if ($fileTotalLines -gt 0) { [math]::Round(($fileLines / $fileTotalLines) * 100, 2) } else { 0 }
            
            $fileName = Split-Path $file -Leaf
            $color = if ($fileCoverage -ge 80) { "Green" } elseif ($fileCoverage -ge 60) { "Yellow" } else { "Red" }
            Write-Host "    $fileName`: $fileCoverage%" -ForegroundColor $color
        }
    }
    
    # Export additional reports if requested
    if ($ExportResults) {
        Write-Host ""
        Write-Host "Exported Files:" -ForegroundColor Cyan
        
        # Create a summary report
        $summaryReport = @{
            TestRun = @{
                Timestamp = $startTime
                Duration = $duration.ToString()
                TestType = $TestType
                OutputFormat = $OutputFormat
                CodeCoverageEnabled = $CodeCoverage
            }
            Results = @{
                TotalTests = $testResults.TotalCount
                PassedTests = $testResults.PassedCount
                FailedTests = $testResults.FailedCount
                SkippedTests = $testResults.SkippedCount
                SuccessRate = if ($testResults.TotalCount -gt 0) { [math]::Round(($testResults.PassedCount / $testResults.TotalCount) * 100, 2) } else { 0 }
            }
        }
        
        if ($CodeCoverage -and $testResults.CodeCoverage) {
            $coverage = $testResults.CodeCoverage
            $summaryReport.CodeCoverage = @{
                TotalLines = $coverage.NumberOfCommandsAnalyzed
                CoveredLines = $coverage.NumberOfCommandsExecuted
                CoveragePercent = if ($coverage.NumberOfCommandsAnalyzed -gt 0) { [math]::Round(($coverage.NumberOfCommandsExecuted / $coverage.NumberOfCommandsAnalyzed) * 100, 2) } else { 0 }
            }
        }
        
        $summaryPath = Join-Path $OutputPath "TestSummary.json"
        $summaryReport | ConvertTo-Json -Depth 10 | Out-File $summaryPath -Encoding UTF8
        
        Write-Host "  - TestSummary.json" -ForegroundColor White
        Write-Host "  - TestResults.xml" -ForegroundColor White
        
        if ($CodeCoverage) {
            Write-Host "  - CodeCoverage.xml" -ForegroundColor White
        }
        
        Write-Host ""
        Write-Host "Results exported to: $OutputPath" -ForegroundColor Green
    }
    
    # Exit with appropriate code
    if ($testResults.FailedCount -gt 0) {
        Write-Host ""
        Write-Host "Some tests failed. Please review the results above." -ForegroundColor Red
        exit 1
    } else {
        Write-Host ""
        Write-Host "All tests passed successfully!" -ForegroundColor Green
        exit 0
    }
}
catch {
    Write-Error "Test execution failed: $($_.Exception.Message)"
    Write-Host "Stack Trace:" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
    exit 1
}

#endregion Test Execution