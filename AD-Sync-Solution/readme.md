# AD Sync Solution

A comprehensive PowerShell-based enterprise solution for synchronising user accounts between two Active Directory domains - typically from an Enterprise/Source domain to a Production/Target domain.

> **Note:** This is a complete enterprise-grade system that was used in production to manage user synchronisation across domains. It demonstrates advanced PowerShell development, enterprise security practices, and production operational procedures.

## Overview

This solution provides automated synchronisation of user accounts between domains, including:
- **User Creation**: Adding new users from source to target domain
- **User Updates**: Synchronising attribute changes 
- **User Removal**: Quarantining and removing users no longer in source
- **Safety Controls**: Thresholds to prevent mass deletions/changes
- **Logging**: Comprehensive logging and email alerting
- **Unix Integration**: Support for Unix/Linux attributes (SFU)

## Architecture

```
Source Domain (Enterprise)  →  Target Domain (Production)
     ↓                              ↓
Export-SourceUsers           Export-ProdUsers
     ↓                              ↓
     └──────── Compare Users ───────┘
               ↓
     ┌─────────┼─────────┐
     ↓         ↓         ↓
  Add-Users Update-Users Remove-Users
```

## Components

### Core Scripts
- **Start-ADSync.ps1** - Main orchestrator script
- **Add-ProdUser.ps1** - Creates new user accounts
- **Update-ProdUser.ps1** - Updates existing user attributes
- **Remove-ProdUser.ps1** - Quarantines and removes users
- **General-Functions.ps1** - Utility functions (export, email)
- **Check-GroupsRemoved.ps1** - Maintenance script for group cleanup

### Safety Features
- **Deletion Threshold**: Maximum 45 users can be removed per run
- **Addition Threshold**: Maximum 300 users can be added per run  
- **Update Threshold**: Maximum 300 updates per run
- **ReportOnly Mode**: Test mode for validation before execution
- **Email Alerts**: Automatic notifications on errors
- **Comprehensive Logging**: Detailed transcript and CSV logs

## Prerequisites

### PowerShell Modules
```powershell
# Required modules
Import-Module ActiveDirectory
```

### Permissions Required
- **Source Domain**: Read access to user accounts and attributes
- **Target Domain**: Full user management permissions (create, modify, delete, move)
- **Service Account**: Dedicated account with appropriate permissions

### Infrastructure
- Network connectivity between domains
- SMTP relay for email notifications
- Secure credential storage

## Configuration

### 1. Update Domain Settings
Edit the configuration section in each script:

```powershell
# Domain Configuration
$SourceDomain = "source.enterprise.local"
$TargetDomain = "prod.local" 
$SourceSearchBase = "OU=Accounts,DC=source,DC=enterprise,DC=local"
$TargetSearchBase = "DC=prod,DC=local"
```

### 2. Update File Paths
```powershell
# Script Paths
$ScriptRoot = "C:\Scripts\ADSync"
$LogPath = "C:\Scripts\ADSync\Logs"
```

### 3. Configure Email Settings
```powershell
# Email Configuration  
$EmailFrom = "adsync@company.com"
$EmailTo = "it-team@company.com"
$SMTPServer = "smtp.company.com"
$SMTPPort = 25
```

### 4. Service Account Setup
Create encrypted credential file:
```powershell
# Create encrypted password file
$credential = Get-Credential "source\svc-adsync"
$credential.Password | ConvertFrom-SecureString | Out-File "C:\Scripts\ADSync\encrypt.txt"
```

## Installation

### 1. Create Directory Structure
```powershell
New-Item -Path "C:\Scripts\ADSync" -ItemType Directory
New-Item -Path "C:\Scripts\ADSync\Logs" -ItemType Directory
```

### 2. Copy Scripts
Place all .ps1 files in `C:\Scripts\ADSync\`

### 3. Update Configurations
Edit configuration sections in each script file

### 4. Test Setup
```powershell
# Test in report-only mode first
.\Start-ADSync.ps1 -ReportOnly $true
```

## Usage

### Manual Execution
```powershell
# Run in report-only mode (safe testing)
.\Start-ADSync.ps1

# Run with actual changes
# Edit $ReportOnly = $false in the functions before running
```

### Scheduled Execution
Recommended: Run via Windows Task Scheduler
- **Frequency**: Daily during off-hours
- **Account**: Service account with required permissions
- **Working Directory**: Script location

### Individual Functions
```powershell
# Test individual components
. .\General-Functions.ps1
$sourceUsers = Export-SourceUsers
$targetUsers = Export-ProdUsers

# Test specific operations
. .\Add-ProdUser.ps1
Add-ProdUser -Data $newUsers -ReportOnly $true -Verbose
```

## Monitoring

### Log Files
- **Transcript Logs**: `transcript-MM-dd-yyyy_HH.log`
- **Data Logs**: `Add-Data-*.csv`, `Update-Data-*.csv`, `Remove-Data-*.csv`  
- **Result Logs**: `Add-Results-*.csv`, `Update-Results-*.csv`, `Remove-Results-*.csv`

### Email Alerts
Automatic emails sent on:
- Script execution errors
- Failed user operations
- Threshold violations

### Key Metrics to Monitor
- Number of users processed in each category
- Success/failure rates
- Threshold approaching warnings
- Execution time trends

## Customisation

### Attribute Synchronisation
Modify the attribute list in `General-Functions.ps1`:
```powershell
$ADProperties = "SamAccountName",
                "mail", 
                "GivenName",
                "Surname",
                "EmployeeID"
                # Add or remove attributes as needed
```

### User Filtering
Update filters in `Export-SourceUsers` and `Export-ProdUsers`:
```powershell
# Example: Exclude test accounts
$Filter = "((EmployeeID -like '*') -and (EmployeeID -ne 'TEST001'))"
```

### Organisational Units
Update OU paths for different environments:
- Quarantine OU for disabled users
- Leavers OU for terminated users  
- Inactive OU for new accounts

## Troubleshooting

### Common Issues

**Permission Errors**
- Verify service account permissions
- Check cross-domain trust relationships
- Validate LDAP connectivity

**Threshold Violations**
- Review user data for unexpected changes
- Adjust thresholds if legitimate
- Check source system for issues

**Credential Issues**
- Recreate encrypted password file
- Verify service account status
- Test manual authentication

### Debug Mode
Enable detailed logging:
```powershell
# Add to scripts for enhanced debugging
$VerbosePreference = "Continue"
$DebugPreference = "Continue"
```

## Security Considerations

- **Credential Storage**: Use encrypted password files, not plaintext
- **Service Accounts**: Dedicated accounts with minimal required permissions
- **Network Security**: Secure communication between domains
- **Audit Logging**: Retain logs for compliance requirements
- **Access Control**: Restrict script access to authorised personnel

## Version History

- **v1.0**: Initial implementation with core sync functionality
- **v1.1**: Added safety thresholds and improved error handling
- **v1.2**: Enhanced logging and email notifications
- **v1.3**: Added Unix/Linux attribute support

## Support

For issues or questions:
1. Check log files for detailed error information
2. Review this documentation for configuration guidance
3. Test in ReportOnly mode before making changes
4. Contact your IT team for domain-specific issues

---

**Part of the PowerShell Library:** This AD Sync Solution is part of a larger collection of PowerShell scripts and tools. Visit the [main repository](../README.md) to explore other automation solutions including Azure management, security tools, and general utilities.

**Enterprise Implementation:** This solution was designed and implemented for production use in a complex enterprise environment, handling the synchronisation of hundreds of user accounts across security domains with zero-downtime requirements.