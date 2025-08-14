# AD Sync Solution

PowerShell solution for synchronising user accounts between two Active Directory domains.

## Disclaimer

These scripts were originally developed for specific enterprise environments. They have been updated and documented from their original form by AI. The updated versions have not been tested. Validate and review the scripts before using them. The author assumes no responsibility for any data loss, security issues, or operational problems resulting from the use of this code.

## What It Does

Synchronises user accounts between source and target domains:
- Creates new users from source domain
- Updates existing user attributes
- Removes users no longer in source (with quarantine)
- Includes safety thresholds and comprehensive logging

## Components

### Core Scripts
- **Start-ADSync.ps1** - Main orchestrator
- **Add-ProdUser.ps1** - Creates new users
- **Update-ProdUser.ps1** - Updates user attributes
- **Remove-ProdUser.ps1** - Quarantines and removes users
- **General-Functions.ps1** - Utility functions
- **Check-GroupsRemoved.ps1** - Group cleanup maintenance

### Safety Features
- Maximum 45 user removals per run (configurable)
- Maximum 300 additions/updates per run (configurable)
- Report-only mode for testing
- Email alerts on errors
- Comprehensive logging

## Configuration

Update these settings in each script:

```powershell
# Domains
$SourceDomain = "source.enterprise.local"
$TargetDomain = "prod.local"

# Paths
$ScriptRoot = "C:\Scripts\ADSync"
$LogPath = "C:\Scripts\ADSync\Logs"

# Email
$EmailFrom = "adsync@company.com"
$EmailTo = "it-team@company.com"
$SMTPServer = "smtp.company.com"
```

Create encrypted credential file:
```powershell
$credential = Get-Credential "source\svc-adsync"
$credential.Password | ConvertFrom-SecureString | Out-File "C:\Scripts\ADSync\encrypt.txt"
```

## Usage

```powershell
# Test mode - no changes made
.\Start-ADSync.ps1 -ReportOnly $true

# Production mode - edit scripts to set $ReportOnly = $false
.\Start-ADSync.ps1
```

## Monitoring

### Log Files
- Transcript logs: `transcript-MM-dd-yyyy_HH.log`
- Data logs: `Add-Data-*.csv`, `Update-Data-*.csv`, `Remove-Data-*.csv`
- Results logs: `Add-Results-*.csv`, `Update-Results-*.csv`, `Remove-Results-*.csv`

### Email Alerts
Sent automatically on errors, failures, or threshold violations.

## Customisation

### Attributes
Modify the attribute list in `General-Functions.ps1`:
```powershell
$ADProperties = "SamAccountName", "mail", "GivenName", "Surname", "EmployeeID"
```

### Filtering
Update user filters in export functions to exclude test accounts or specific OUs.

### Thresholds
Adjust safety thresholds in the main scripts based on your environment size.

---

**Part of my PowerShell Library:** Visit the [main repository](../README.md) to explore other solutions and tools.
