<#
.SYNOPSIS
    Test script to validate AD-Sync configuration

.DESCRIPTION
    This script tests the configuration loading and validation functionality
    without connecting to Active Directory domains.

.EXAMPLE
    .\test_config.ps1
    Tests the default configuration

.EXAMPLE
    .\test_config.ps1 -ConfigPath "C:\Custom\config.json"
    Tests a specific configuration file
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath
)

try {
    Write-Host "Testing AD-Sync Configuration..." -ForegroundColor Green
    Write-Host "=================================" -ForegroundColor Green
    
    # Load configuration helper
    Write-Host "`n1. Loading configuration helper..." -ForegroundColor Cyan
    . "$PSScriptRoot\config_helper.ps1"
    Write-Host "   ✓ Configuration helper loaded successfully" -ForegroundColor Green
    
    # Load configuration
    Write-Host "`n2. Loading configuration..." -ForegroundColor Cyan
    if ($ConfigPath) {
        $Config = Get-ADSyncConfig -ConfigPath $ConfigPath
        Write-Host "   ✓ Configuration loaded from: $ConfigPath" -ForegroundColor Green
    }
    else {
        $Config = Get-ADSyncConfig
        Write-Host "   ✓ Configuration loaded from default location" -ForegroundColor Green
    }
    
    # Test directory validation
    Write-Host "`n3. Testing directory validation..." -ForegroundColor Cyan
    Test-ADSyncDirectories -Config $Config
    Write-Host "   ✓ Directory validation completed" -ForegroundColor Green
    
    # Test attribute retrieval
    Write-Host "`n4. Testing attribute configuration..." -ForegroundColor Cyan
    $StandardAttributes = Get-ADUserAttributes -Config $Config
    $AllAttributes = Get-ADUserAttributes -Config $Config -IncludeTargetOnly
    
    Write-Host "   ✓ Standard attributes: $($StandardAttributes.Count)" -ForegroundColor Green
    Write-Host "   ✓ All attributes (with target-only): $($AllAttributes.Count)" -ForegroundColor Green
    
    # Display configuration summary
    Write-Host "`n5. Configuration Summary:" -ForegroundColor Cyan
    Write-Host "   Script Root: $($Config.General.ScriptRoot)" -ForegroundColor White
    Write-Host "   Log Path: $($Config.General.LogPath)" -ForegroundColor White
    Write-Host "   Source Domain: $($Config.SourceDomain.DomainName)" -ForegroundColor White
    Write-Host "   Target Domain: $($Config.TargetDomain.DomainName)" -ForegroundColor White
    Write-Host "   Email From: $($Config.EmailConfiguration.From)" -ForegroundColor White
    Write-Host "   Email To: $($Config.EmailConfiguration.To)" -ForegroundColor White
    Write-Host "   SMTP Server: $($Config.EmailConfiguration.SMTPServer)" -ForegroundColor White
    
    # Test safety thresholds
    Write-Host "`n6. Safety Thresholds:" -ForegroundColor Cyan
    Write-Host "   Deletion Threshold: $($Config.SafetyThresholds.DeletionThreshold)" -ForegroundColor White
    Write-Host "   Addition Threshold: $($Config.SafetyThresholds.AdditionThreshold)" -ForegroundColor White
    Write-Host "   Update Threshold: $($Config.SafetyThresholds.UpdateThreshold)" -ForegroundColor White
    
    Write-Host "`n✓ Configuration test completed successfully!" -ForegroundColor Green
    Write-Host "✓ All components are properly configured and ready for use." -ForegroundColor Green
}
catch {
    Write-Host "`n✗ Configuration test failed!" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "`nNext Steps:" -ForegroundColor Yellow
Write-Host "1. Review the configuration values above" -ForegroundColor White
Write-Host "2. Update config.json with your environment-specific values" -ForegroundColor White
Write-Host "3. Test with: .\start_adsync.ps1 -ReportOnly `$true" -ForegroundColor White