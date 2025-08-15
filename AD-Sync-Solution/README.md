# AD-Sync-Solution

PowerShell solution for synchronizing user accounts between two Active Directory domains with centralized configuration management.

## ⚠️ Disclaimer

These scripts were originally developed for a specific enterprise environment and have since been updated with improved configuration management and comprehensive testing using Pester and Claude Code. Always validate and test scripts thoroughly in your own environment before taking them into production use. The author assumes no responsibility for any data loss, security issues, or operational problems resulting from the use of this code.

## 🚀 What It Does

Synchronizes user accounts between source and target domains:
- ✅ Creates new users from source domain
- ✅ Updates existing user attributes  
- ✅ Removes users no longer in source (with quarantine)
- ✅ Includes safety thresholds and comprehensive logging
- ✅ Centralized JSON configuration management
- ✅ Environment variable support
- ✅ Comprehensive Pester test suite

## 📂 Components

### Core Scripts
- **`start_adsync.ps1`** - Main orchestrator script
- **`add_produser.ps1`** - Creates new users
- **`update_produser.ps1`** - Updates user attributes  
- **`remove_produser.ps1`** - Quarantines and removes users
- **`general_functions.ps1`** - Utility functions (email, user export)
- **`check_groups_removed.ps1`** - Group cleanup maintenance

### Configuration Management
- **`config.json`** - Centralized configuration file
- **`config_helper.ps1`** - Configuration management functions
- **`test_config.ps1`** - Configuration validation script

### Testing Infrastructure  
- **`Tests/`** - Complete Pester test suite
- **`Tests/Invoke-AllTests.ps1`** - Master test runner
- **`Tests/README.md`** - Detailed testing documentation

## 🔧 Configuration

### Quick Start
1. **Update config.json** with your environment values:
```json
{
  "General": {
    "ScriptRoot": "C:\\Scripts\\ADSync",
    "LogPath": "C:\\Scripts\\ADSync\\Logs",
    "CredentialFile": "C:\\Scripts\\ADSync\\encrypt.txt"
  },
  "SourceDomain": {
    "DomainName": "source.enterprise.local",
    "SearchBase": "OU=Accounts,DC=source,DC=enterprise,DC=local",
    "ServiceAccount": "source\\svc-adsync"
  },
  "TargetDomain": {
    "DomainName": "prod.local",
    "SearchBase": "DC=prod,DC=local"
  },
  "EmailConfiguration": {
    "From": "adsync@company.com",
    "To": "it-team@company.com", 
    "SMTPServer": "smtp.company.com"
  }
}
```

2. **Test configuration**:
```powershell
.\test_config.ps1
```

3. **Create encrypted credential file**:
```powershell
$credential = Get-Credential "source\svc-adsync"
$credential.Password | ConvertFrom-SecureString | Out-File "C:\Scripts\ADSync\encrypt.txt"
```

### Environment Variables
Override configuration file location:
```powershell
$env:ADSYNC_CONFIG = "C:\Custom\my-config.json"
```

Configuration supports environment variable expansion:
```json
{
  "General": {
    "ScriptRoot": "%ADSYNC_ROOT%\\Scripts"
  }
}
```

## 🎯 Usage

### Testing Mode (Recommended First)
```powershell
# Validate configuration
.\test_config.ps1

# Run sync in report-only mode
.\start_adsync.ps1 -ReportOnly $true
```

### Production Mode
```powershell
# Run actual synchronization
.\start_adsync.ps1 -ReportOnly $false
```

### Group Cleanup Maintenance
```powershell
# Check for quarantined users with remaining group memberships
.\check_groups_removed.ps1

# Remove group memberships from quarantined users
.\check_groups_removed.ps1 -RemoveGroups $true
```

## 🛡️ Safety Features

### Configurable Thresholds
- **Deletion Threshold**: Maximum user removals per run (default: 45)
- **Addition Threshold**: Maximum new users per run (default: 300)  
- **Update Threshold**: Maximum attribute changes per run (default: 300)

### Two-Stage Removal Process
1. **First Run**: Disable account, remove groups, move to Leavers OU
2. **Second Run**: Delete account completely

### Built-in Protections
- ✅ Report-only mode for testing
- ✅ Email alerts on errors and threshold violations
- ✅ Comprehensive audit logging
- ✅ Exemption support for special accounts
- ✅ Duplicate detection and handling

## 📊 Monitoring & Logging

### Log Files (Timestamped)
- **Transcript logs**: `transcript-MM-dd-yyyy_HH.log`
- **Data exports**: `Add-Data-*.csv`, `Update-Data-*.csv`, `Remove-Data-*.csv`
- **Operation results**: `Add-Results-*.csv`, `Update-Results-*.csv`, `Remove-Results-*.csv`

### Email Notifications
Automatic alerts for:
- Configuration or connection errors
- Safety threshold violations
- Individual operation failures
- Processing completion summaries

## 🧪 Testing

### Run Tests
```powershell
# Run all tests
.\Tests\Invoke-AllTests.ps1

# Run specific test categories  
.\Tests\Invoke-AllTests.ps1 -TestType Unit
.\Tests\Invoke-AllTests.ps1 -TestType Integration

# Run with code coverage
.\Tests\Invoke-AllTests.ps1 -CodeCoverage -ExportResults
```

### Test Categories
- **Configuration Management** (20 tests)
- **User Export Functions** (22 tests)
- **User Management Operations** (60+ tests)
- **Integration Workflows** (Multiple scenarios)

See [Tests/README.md](Tests/README.md) for detailed testing documentation.

## ⚙️ Customization

### User Attributes
Attributes are centrally managed in `config.json`:
```json
{
  "UserAttributes": {
    "StandardAttributes": [
      "SamAccountName", "mail", "GivenName", "Surname", "EmployeeID"
    ],
    "CloudExtensionAttributes": [
      "msDS-cloudExtensionAttribute1", "msDS-cloudExtensionAttribute2"
    ]
  }
}
```

### Account Filtering
Configure in `config.json`:
```json
{
  "SourceDomain": {
    "ExcludedEmployeeIDs": ["TEST001", "SVC001"]
  },
  "TargetDomain": {
    "ExcludePatterns": ["test_*", "svc_*", "admin_*"]
  }
}
```

### Unix/Linux Integration
Configure SFU attributes:
```json
{
  "UnixConfiguration": {
    "DefaultGidNumber": "10001",
    "DefaultLoginShell": "/bin/bash",
    "NisDomain": "prod"
  }
}
```

## 🚀 Deployment

### Prerequisites
- **PowerShell 5.1** or later
- **ActiveDirectory** PowerShell module
- **Appropriate AD permissions** on both domains
- **SMTP relay** for notifications
- **Service account** with sync permissions

### Installation Steps
1. Copy scripts to target directory
2. Update `config.json` with environment values
3. Test configuration: `.\test_config.ps1`
4. Run tests: `.\Tests\Invoke-AllTests.ps1`
5. Test in report mode: `.\start_adsync.ps1 -ReportOnly $true`
6. Schedule for production

### Scheduled Task Example
```powershell
# Create scheduled task for daily sync
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-File C:\Scripts\ADSync\start_adsync.ps1 -ReportOnly `$false"
$trigger = New-ScheduledTaskTrigger -Daily -At "02:00AM"
Register-ScheduledTask -TaskName "AD-Sync-Daily" -Action $action -Trigger $trigger
```


## 📚 Additional Documentation

- **[Tests/README.md](Tests/README.md)** - Comprehensive testing guide
- **[Tests/Pester-README.md](Tests/Pester-README.md)** - Windows Pester testing guide

## 🤝 Contributing

When contributing improvements:
1. Update relevant tests
2. Ensure all tests pass
3. Follow existing code patterns
4. Update documentation
5. Test in both report and live modes

---

**Part of my PowerShell Library:** Visit the [main repository](../README.md) to explore other solutions and tools.