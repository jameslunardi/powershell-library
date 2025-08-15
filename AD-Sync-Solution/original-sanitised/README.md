# Active Directory User Synchronization Suite

## Overview

This PowerShell-based solution synchronises user accounts between an Enterprise Domain (used for end-user computing services) and a Production domain (used for securing access to production services with stricter security, audit, and compliance requirements).

Originally designed as a temporary solution in 2019 while an IAM service was being implemented, this system successfully operated for 5 years, scaling from around 1,500 to over 3,000 synchronised accounts. The solution ran hourly via scheduled task with minimal issues normally associated with source domain data consistency.

**Note**: While I created the framework and majority of the code, colleagues contributed small fixes and improvements over the years. The code has been sanitised for public sharing, but the core functionality remains unchanged.

## Architecture

The solution consists of five PowerShell modules:

- **Start-ADSync.ps1** - Main orchestration script that coordinates the synchronisation process
- **Add-TargetUser.ps1** - Creates new user accounts in the target domain with Unix/Linux attributes
- **Remove-TargetUser.ps1** - Handles user account removal and quarantine processes
- **Update-TargetUser.ps1** - Updates existing user attributes to maintain synchronisation
- **General-Functions.ps1** - Shared functions for email notifications and user data export

### Key Technical Components

- **PowerShell Modules**: ActiveDirectory, built-in cmdlets for user management and domain operations
- **Authentication**: Cross-domain service account with encrypted password storage
- **Safety Mechanisms**: Configurable thresholds prevent bulk operations (300 adds/updates, 45 deletions)
- **Unix Integration**: Automatic UID/GID assignment for Linux/Unix system compatibility
- **Logging**: Comprehensive transcript logging and CSV-based audit trails
- **Error Handling**: Email notifications for failures with detailed error reporting

## Synchronisation Process
1. **Export users** from both domains using EmployeeID as the primary key
2. **Compare accounts** to identify additions, updates, and removals
3. **Process updates** for attribute changes between matched accounts
4. **Add new accounts** to target domain (disabled, in quarantine OU)
5. **Remove/quarantine** accounts no longer in source domain
6. **Handle conflicts** through duplicate detection and automatic SamAccountName numbering

### Account Lifecycle
- **New accounts**: Created disabled in quarantine OU until manually activated
- **Updates**: Automatic attribute synchronisation based on source changes
- **Leavers**: Moved to leavers OU, group memberships removed, accounts disabled
- **Deletion**: Only after accounts have been in leavers OU (two-stage process)

## Prerequisites

- PowerShell 5.0+ with ActiveDirectory module
- Service account with appropriate permissions on both domains
- Domain controllers accessible from execution environment
- SMTP server for error notifications

## Configuration

1. **Update domain references** in all scripts:
   - Replace `source.company.local` with your source domain
   - Replace `target.company.local` with your target domain

2. **Configure service account**:
   - Create encrypted password file: `"password" | ConvertTo-SecureString | ConvertFrom-SecureString | Out-File encrypt.txt`
   - Update username in `Export-SourceUsers` function

3. **Adjust thresholds** in each script:
   - Add threshold: 300 (line varies by script)
   - Delete threshold: 45 (Remove-TargetUser.ps1)
   - Update threshold: 300 (Update-TargetUser.ps1)

4. **Configure email notifications**:
   - Update SMTP server and email addresses in `Send-Email` function
   - Modify recipients and sender addresses

5. **Update file paths**:
   - Change `C:\Scripts\ADSync\` to your preferred location
   - Ensure log directory exists

## Usage

### Execution
```powershell
# Always test in report-only mode first, check that $ReportOnly = $True in Start-ADSync.ps1 before running.
.\Start-ADSync.ps1

# Review the output and logs, before moving to running in production.

# Set $ReportOnly = $False in Start-ADSync.ps1 and then run 
.\Start-ADSync.ps1
```

### Scheduled Task
Configure Windows Scheduled Task to run hourly:
```
Program: PowerShell.exe
Arguments: -ExecutionPolicy Bypass -File "C:\Scripts\ADSync\Start-ADSync.ps1"
```

---
**Part of my PowerShell Library:** Visit the [main repository](../README.md) to explore other solutions and tools.

## Disclaimer
Always validate and test scripts thoroughly in your own environment before taking them into production use. The author assumes no responsibility for any data loss, security issues, or operational problems resulting from the use of this code.
