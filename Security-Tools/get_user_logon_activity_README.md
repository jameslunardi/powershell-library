# Get-UserLogonActivity.ps1

Windows Security Event Log analysis for user logon activity monitoring and inactive account detection.

## Disclaimer

These scripts were originally developed for specific enterprise environments. They have been updated and documented from their original form by AI. The updated versions have not been tested. Validate and review the scripts before using them. The author assumes no responsibility for any data loss, security issues, or operational problems resulting from the use of this code.

## Overview

Analyses Windows logon activity by examining Security Event Log entries (Event ID 4624 - successful logons) to audit user access patterns, identify inactive accounts, and generate logon activity reports.

## Features

- Processes Event ID 4624 (successful logons) with detailed metadata
- Identifies unique users with first/last logon times and frequency
- Flexible filtering options for system accounts and logon types
- Configurable date ranges for targeted analysis
- Console display and CSV export capabilities
- Remote computer support
- Logon type classification (interactive, network, service, etc.)

## Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `ComputerName` | String | No | Local computer | Target computer to analyse |
| `MaxEvents` | Int | No | Unlimited | Maximum number of events to process |
| `StartTime` | DateTime | No | All available | Start time for event analysis |
| `EndTime` | DateTime | No | All available | End time for event analysis |
| `OutputPath` | String | No | Console only | Path for CSV export |
| `IncludeSystemAccounts` | Switch | No | False | Include computer/service accounts |
| `ExcludeInteractiveOnly` | Switch | No | False | Exclude non-interactive logon types |

## Usage

```powershell
# Basic analysis - all available logon events
.\Get-UserLogonActivity.ps1

# Recent activity with CSV export
.\Get-UserLogonActivity.ps1 -StartTime (Get-Date).AddDays(-7) -OutputPath "C:\Reports\WeeklyLogons.csv"

# Large dataset processing with limits
.\Get-UserLogonActivity.ps1 -MaxEvents 50000 -ExcludeInteractiveOnly

# Remote server analysis
.\Get-UserLogonActivity.ps1 -ComputerName "SERVER01" -IncludeSystemAccounts -OutputPath "C:\Audit\SERVER01-Activity.csv"
```

## Output

### Console Display
- Summary statistics (total events, unique users, time span)
- Most recent activity (top 10 active users)
- Inactive account detection (users not seen in last 30 days)

### CSV Export
Detailed data including account name, latest logon, logon type, first seen, total logons, days since last logon, and activity span.

## Logon Type Classifications

| Type | Description | Common Scenarios |
|------|-------------|------------------|
| Interactive | Direct console logon | Physical computer access |
| RemoteInteractive | RDP/Remote Desktop | Remote administration |
| Network | Network authentication | File share access |
| Service | Service account logon | Scheduled tasks, services |
| Batch | Batch logon | Scheduled jobs |
| CachedInteractive | Cached credential logon | Offline domain logon |

## Requirements

- Administrative privileges to read Windows Security Event Log
- Security auditing enabled on target system
- Network permissions for remote computer analysis (if applicable)

---

**Part of my PowerShell Library:** [Security Tools](README.md) | [Main Repository](../README.md) to explore other solutions and tools.
