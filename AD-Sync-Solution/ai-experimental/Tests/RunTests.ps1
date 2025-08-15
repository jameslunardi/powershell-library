<#
.SYNOPSIS
    Test runner script for AD-Sync-Solution

.DESCRIPTION
    This script demonstrates how to run both unit tests (with mocks) and integration tests 
    (with live AD) using the new wrapper system.

.PARAMETER TestType
    Specify which type of tests to run: Unit, Integration, or All

.EXAMPLE
    .\RunTests.ps1 -TestType Unit
    Run only unit tests with mocks

.EXAMPLE  
    .\RunTests.ps1 -TestType Integration
    Run only integration tests against live AD

.EXAMPLE
    .\RunTests.ps1 -TestType All
    Run both unit and integration tests
#>

param(
    [ValidateSet("Unit", "Integration", "All")]
    [string]$TestType = "Unit"
)

Write-Host "AD-Sync-Solution Test Runner" -ForegroundColor Green
Write-Host "=============================" -ForegroundColor Green

switch ($TestType) {
    "Unit" {
        Write-Host "Running Unit Tests (with mocks)..." -ForegroundColor Yellow
        $env:ADSYNC_TEST_MODE = "Mock"
        
        # Run unit tests
        $unitResults = Invoke-Pester -Path @(
            "AddProdUser.Tests.ps1",
            "RemoveProdUser.Tests.ps1", 
            "UpdateProdUser.Tests.ps1",
            "GeneralFunctions.Tests.ps1",
            "ConfigHelper.Tests.ps1"
        ) -Output Detailed
        
        Write-Host "Unit Test Results:" -ForegroundColor Cyan
        Write-Host "  Passed: $($unitResults.PassedCount)" -ForegroundColor Green
        Write-Host "  Failed: $($unitResults.FailedCount)" -ForegroundColor Red
        Write-Host "  Skipped: $($unitResults.SkippedCount)" -ForegroundColor Yellow
    }
    
    "Integration" {
        Write-Host "Running Integration Tests (with live AD)..." -ForegroundColor Yellow
        
        # Check for integration test config
        if (-not (Test-Path "IntegrationTestConfig.json")) {
            Write-Warning "IntegrationTestConfig.json not found. Please configure integration test domains first."
            Write-Host "See IntegrationTestConfig.json template for required configuration." -ForegroundColor Yellow
            exit 1
        }
        
        $env:ADSYNC_TEST_MODE = "Integration"
        
        # Run integration tests
        $integrationResults = Invoke-Pester -Path @(
            "AddProdUser.Integration.Tests.ps1"
        ) -Tag "Integration" -Output Detailed
        
        Write-Host "Integration Test Results:" -ForegroundColor Cyan  
        Write-Host "  Passed: $($integrationResults.PassedCount)" -ForegroundColor Green
        Write-Host "  Failed: $($integrationResults.FailedCount)" -ForegroundColor Red
        Write-Host "  Skipped: $($integrationResults.SkippedCount)" -ForegroundColor Yellow
    }
    
    "All" {
        Write-Host "Running All Tests..." -ForegroundColor Yellow
        
        # Run unit tests first
        Write-Host "`nPhase 1: Unit Tests" -ForegroundColor Cyan
        $env:ADSYNC_TEST_MODE = "Mock"
        $unitResults = Invoke-Pester -Path @(
            "AddProdUser.Tests.ps1",
            "RemoveProdUser.Tests.ps1",
            "UpdateProdUser.Tests.ps1", 
            "GeneralFunctions.Tests.ps1",
            "ConfigHelper.Tests.ps1"
        ) -Output Normal
        
        # Run integration tests if config exists
        Write-Host "`nPhase 2: Integration Tests" -ForegroundColor Cyan
        if (Test-Path "IntegrationTestConfig.json") {
            $env:ADSYNC_TEST_MODE = "Integration"
            $integrationResults = Invoke-Pester -Path @(
                "AddProdUser.Integration.Tests.ps1"
            ) -Tag "Integration" -Output Normal
        } else {
            Write-Warning "Integration tests skipped - no IntegrationTestConfig.json found"
            $integrationResults = @{ PassedCount = 0; FailedCount = 0; SkippedCount = 0 }
        }
        
        # Summary
        Write-Host "`nTest Summary:" -ForegroundColor Green
        Write-Host "=============" -ForegroundColor Green
        Write-Host "Unit Tests:        $($unitResults.PassedCount) passed, $($unitResults.FailedCount) failed" -ForegroundColor White
        Write-Host "Integration Tests: $($integrationResults.PassedCount) passed, $($integrationResults.FailedCount) failed" -ForegroundColor White
        Write-Host "Total:             $(($unitResults.PassedCount + $integrationResults.PassedCount)) passed, $(($unitResults.FailedCount + $integrationResults.FailedCount)) failed" -ForegroundColor $(if (($unitResults.FailedCount + $integrationResults.FailedCount) -eq 0) { "Green" } else { "Red" })
    }
}

# Clean up environment
$env:ADSYNC_TEST_MODE = $null

Write-Host "`nTesting complete!" -ForegroundColor Green