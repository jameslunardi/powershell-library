<#
.SYNOPSIS
    Configuration management helper for AD-Sync-Solution

.DESCRIPTION
    This module provides functions to load and validate configuration from JSON files.
    It supports environment-specific configurations and parameter validation.

.NOTES
    Author: James Lunardi
    Version: 1.0
    
    The configuration file should be named config.json by default, but can be 
    overridden by setting the ADSYNC_CONFIG environment variable.

.LINK
    https://github.com/jameslunardi/powershell-library
    https://www.linkedin.com/in/jameslunardi/
#>

#region Configuration Loading Functions
# =============================================================================
# CONFIGURATION LOADING AND VALIDATION FUNCTIONS
# =============================================================================

<#
.SYNOPSIS
    Loads configuration from JSON file

.DESCRIPTION
    Loads the AD-Sync configuration from a JSON file. Supports environment-specific
    configurations and validates required parameters.

.PARAMETER ConfigPath
    Path to the configuration file. If not specified, looks for config.json in the
    same directory as this script, or uses the ADSYNC_CONFIG environment variable.

.EXAMPLE
    $config = Get-ADSyncConfig
    Loads configuration from default location

.EXAMPLE
    $config = Get-ADSyncConfig -ConfigPath "C:\Scripts\ADSync\prod-config.json"
    Loads configuration from specific file
#>
function Get-ADSyncConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ConfigPath
    )

    #region Determine Config Path
    # =============================================================================
    # DETERMINE CONFIGURATION FILE PATH
    # =============================================================================
    
    if (-not $ConfigPath) {
        # Check for environment variable first
        if ($env:ADSYNC_CONFIG) {
            $ConfigPath = $env:ADSYNC_CONFIG
            Write-Verbose "Using config path from environment variable: $ConfigPath"
        }
        else {
            # Default to config.json in script directory
            $ScriptDirectory = Split-Path -Parent $MyInvocation.PSCommandPath
            if (-not $ScriptDirectory) {
                $ScriptDirectory = Split-Path -Parent $PSCommandPath
            }
            if (-not $ScriptDirectory) {
                $ScriptDirectory = $PSScriptRoot
            }
            $ConfigPath = Join-Path $ScriptDirectory "config.json"
            Write-Verbose "Using default config path: $ConfigPath"
        }
    }
    
    #endregion Determine Config Path

    #region Load Configuration
    # =============================================================================
    # LOAD AND PARSE CONFIGURATION FILE
    # =============================================================================
    
    try {
        if (-not (Test-Path $ConfigPath)) {
            throw "Configuration file not found: $ConfigPath"
        }

        Write-Verbose "Loading configuration from: $ConfigPath"
        $ConfigContent = Get-Content -Path $ConfigPath -Raw -ErrorAction Stop
        $Config = $ConfigContent | ConvertFrom-Json -ErrorAction Stop
        
        Write-Verbose "Configuration loaded successfully"
    }
    catch {
        Write-Error "Failed to load configuration from $ConfigPath`: $($_.Exception.Message)" -ErrorAction Stop
    }
    
    #endregion Load Configuration

    #region Validate Configuration
    # =============================================================================
    # VALIDATE REQUIRED CONFIGURATION SECTIONS
    # =============================================================================
    
    $RequiredSections = @(
        'General',
        'SafetyThresholds', 
        'SourceDomain',
        'TargetDomain',
        'UnixConfiguration',
        'EmailConfiguration',
        'UserAttributes'
    )
    
    foreach ($Section in $RequiredSections) {
        if (-not $Config.$Section) {
            throw "Missing required configuration section: $Section"
        }
    }
    
    # Validate specific required properties
    $RequiredProperties = @{
        'General' = @('ScriptRoot', 'LogPath', 'CredentialFile')
        'SafetyThresholds' = @('DeletionThreshold', 'AdditionThreshold', 'UpdateThreshold')
        'SourceDomain' = @('DomainName', 'SearchBase', 'ServiceAccount')
        'TargetDomain' = @('DomainName', 'SearchBase', 'InactiveOU', 'LeaversOU', 'NISObjectDN')
        'UnixConfiguration' = @('DefaultGidNumber', 'DefaultLoginShell', 'NisDomain')
        'EmailConfiguration' = @('From', 'To', 'SMTPServer', 'SMTPPort')
        'UserAttributes' = @('StandardAttributes', 'CloudExtensionAttributes')
    }
    
    foreach ($Section in $RequiredProperties.Keys) {
        foreach ($Property in $RequiredProperties[$Section]) {
            if ($null -eq $Config.$Section.$Property) {
                throw "Missing required property '$Property' in section '$Section'"
            }
        }
    }
    
    # Validate SafetyThresholds are positive integers
    $ThresholdProperties = @('DeletionThreshold', 'AdditionThreshold', 'UpdateThreshold')
    foreach ($Property in $ThresholdProperties) {
        $Value = $Config.SafetyThresholds.$Property
        
        # Convert to integer (handles both string and numeric JSON values)
        try {
            $IntValue = [int]$Value
        }
        catch {
            throw "SafetyThresholds.$Property must be a valid integer. Current value: '$Value'"
        }
        
        # Check if it's positive
        if ($IntValue -le 0) {
            throw "SafetyThresholds.$Property must be a positive number greater than 0. Current value: $IntValue"
        }
        
        Write-Verbose "SafetyThresholds.$Property validation passed: $IntValue"
    }
    
    Write-Verbose "Configuration validation completed successfully"
    
    #endregion Validate Configuration

    #region Expand Paths
    # =============================================================================
    # EXPAND ENVIRONMENT VARIABLES IN PATHS
    # =============================================================================
    
    # Expand environment variables in path properties
    $Config.General.ScriptRoot = [Environment]::ExpandEnvironmentVariables($Config.General.ScriptRoot)
    $Config.General.LogPath = [Environment]::ExpandEnvironmentVariables($Config.General.LogPath)
    $Config.General.CredentialFile = [Environment]::ExpandEnvironmentVariables($Config.General.CredentialFile)
    
    #endregion Expand Paths

    return $Config
}

<#
.SYNOPSIS
    Gets the combined list of user attributes to retrieve

.DESCRIPTION
    Combines standard and cloud extension attributes into a single array
    for use with Get-ADUser queries.

.PARAMETER Config
    The configuration object from Get-ADSyncConfig

.PARAMETER IncludeTargetOnly
    Include target-only attributes like Info (default: $false)

.EXAMPLE
    $attributes = Get-ADUserAttributes -Config $config
    Gets all user attributes for source domain queries

.EXAMPLE
    $attributes = Get-ADUserAttributes -Config $config -IncludeTargetOnly
    Gets all user attributes including target-only attributes
#>
function Get-ADUserAttributes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Config,
        
        [Parameter(Mandatory = $false)]
        [switch]$IncludeTargetOnly
    )

    $Attributes = [System.Collections.ArrayList]@()
    
    # Add standard attributes
    $Attributes.AddRange($Config.UserAttributes.StandardAttributes)
    
    # Add cloud extension attributes
    $Attributes.AddRange($Config.UserAttributes.CloudExtensionAttributes)
    
    # Add target-only attributes if requested
    if ($IncludeTargetOnly -and $Config.UserAttributes.TargetOnlyAttributes) {
        $Attributes.AddRange($Config.UserAttributes.TargetOnlyAttributes)
    }
    
    return $Attributes.ToArray()
}

<#
.SYNOPSIS
    Validates that required directories exist

.DESCRIPTION
    Checks that all configured directories exist and creates them if they don't.
    This is particularly important for log directories.

.PARAMETER Config
    The configuration object from Get-ADSyncConfig

.EXAMPLE
    Test-ADSyncDirectories -Config $config
    Validates and creates directories as needed
#>
function Test-ADSyncDirectories {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Config
    )

    $DirectoriesToCheck = @(
        $Config.General.ScriptRoot,
        $Config.General.LogPath
    )

    foreach ($Directory in $DirectoriesToCheck) {
        if (-not (Test-Path $Directory)) {
            try {
                Write-Verbose "Creating directory: $Directory"
                New-Item -Path $Directory -ItemType Directory -Force -ErrorAction Stop | Out-Null
            }
            catch {
                $errorMsg = "Failed to create directory $Directory`: $($_.Exception.Message)"
                Write-Error $errorMsg -ErrorAction Stop
            }
        }
        else {
            Write-Verbose "Directory exists: $Directory"
        }
    }
}

#endregion Configuration Loading Functions

#region Module Exports
# =============================================================================
# EXPORT FUNCTIONS FOR MODULE USE
# =============================================================================

# Export functions for use by other scripts (only when loaded as module)
if ($MyInvocation.MyCommand.CommandType -eq 'ExternalScript') {
    # When dot-sourced, functions are automatically available
} else {
    Export-ModuleMember -Function Get-ADSyncConfig, Get-ADUserAttributes, Test-ADSyncDirectories
}

#endregion Module Exports