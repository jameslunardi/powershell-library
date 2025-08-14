# Get-UserLogonActivity.ps1

Analyzes Windows Security Event Logs to identify user logon patterns and provide comprehensive activity reporting for security auditing and compliance.

## Disclaimer

**Important:** This script was originally developed for security auditing in enterprise environments and is provided as-is for educational and reference purposes.

- **AI Enhancement:** Script has been sanitised and documented with AI assistance for professional presentation
- **Testing Status:** Enhanced script has NOT been tested post-processing
- **Use at Own Risk:** Test thoroughly in your environment before any production use
- **Impact Warning:** This script accesses Windows Security Event Logs and processes potentially large datasets
- **Prerequisites:** Ensure appropriate administrative permissions and system resources
- **Security:** Be mindful of sensitive information in security logs and data retention policies

The author assumes no responsibility for any performance issues, data concerns, or operational problems resulting from the use of this code. Professional testing and validation are strongly recommended.

## Overview

This PowerShell script provides comprehensive analysis of Windows logon activity by examining Security Event Log entries (Event ID 4624 - successful logons). It's designed for security professionals, system administrators, and compliance teams who need to audit user access patterns, identify inactive accounts, and generate detailed logon activity reports.

The script efficiently processes large volumes of security events and provides actionable insights about user behavior, logon patterns, and potential security concerns.

## Key Features

- **Comprehensive Logon Analysis** - Processes Event ID 4624 (successful logons) with detailed metadata
- **User Activity Tracking** - Identifies unique users with first/last logon times and frequency
- **Flexible Filtering** - Options to include/exclude system accounts and specific logon types
- **Time Range Analysis** - Configurable date ranges for targeted analysis periods
- **Performance Optimization** - Efficient processing of large event logs with progress indication
- **Multiple Output Formats** - Console display and CSV export capabilities
- **Security Insights** - Identifies inactive accounts and unusual logon patterns
- **Remote Computer Support** - Analyze logon activity on remote systems
- **Logon Type Classification** - Categorizes different types of logons (interactive, network, service, etc.)

## Prerequisites

- **PowerShell 5.1+** (PowerShell 7+ recommended for optimal performance)
- **Administrative Privileges** - Required to read Windows Security Event Log
- **Security Auditing Enabled** - Target system must have logon auditing configured
- **Network Permissions** - For remote computer analysis (if applicable)
- **Sufficient Memory** - For processing large event logs (varies by log size)

## Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `ComputerName` | String | No | Local computer | Target computer to analyze |
| `MaxEvents` | Int | No | Unlimited | Maximum number of events to process |
| `StartTime` | DateTime | No | All available | Start time for event analysis |
| `EndTime` | DateTime | No | All available | End time for event analysis |
| `OutputPath` | String | No | Console only | Path for CSV export |
| `IncludeSystemAccounts` | Switch | No | False | Include computer/service accounts |
| `ExcludeInteractiveOnly` | Switch | No | False | Exclude non-interactive logon types |

## Usage Examples

### Basic Analysis
```powershell
.\Get-UserLogonActivity.ps1
```
- Analyzes all available logon events on local computer
- Excludes system accounts
- Displays results in console

### Recent Activity Analysis
```powershell
.\Get-UserLogonActivity.ps1 -StartTime (Get-Date).AddDays(-7) -OutputPath "C:\Reports\WeeklyLogons.csv"
```
- Analyzes logons from past 7 days
- Exports results to CSV file

### Large Dataset Processing
```powershell
.\Get-UserLogonActivity.ps1 -MaxEvents 50000 -ExcludeInteractiveOnly
```
- Processes most recent 50,000 events
- Focuses only on interactive logon types
- Useful for systems with high logon volume

### Remote Server Analysis
```powershell
.\Get-UserLogonActivity.ps1 -ComputerName "SERVER01" -IncludeSystemAccounts -OutputPath "C:\Audit\SERVER01-Activity.csv"
```
- Analyzes remote server logon activity
- Includes system accounts in analysis
- Exports comprehensive results

### Security Audit Scenario
```powershell
# Monthly security audit
$startDate = (Get-Date).AddMonths(-1).Date
$endDate = (Get-Date).Date
$outputFile = "C:\SecurityAudits\$(Get-Date -Format 'yyyy-MM')-LogonActivity.csv"

.\Get-UserLogonActivity.ps1 -StartTime $startDate -EndTime $endDate -OutputPath $outputFile -IncludeSystemAccounts
```

### Compliance Reporting
```powershell
# Quarterly access review
$quarterStart = (Get-Date -Month 1 -Day 1).AddMonths(((Get-Date).Month - 1) - ((Get-Date).Month - 1) % 3)
$quarterEnd = $quarterStart.AddMonths(3).AddDays(-1)

.\Get-UserLogonActivity.ps1 -StartTime $quarterStart -EndTime $quarterEnd -OutputPath "C:\Compliance\Q$(Get-Date -Format 'q')-AccessReview.csv"
```

## Output Information

### Console Display

**Summary Statistics:**
- Total events analyzed
- Unique users identified  
- Time span covered
- Logon type breakdown

**Most Recent Activity:**
- Top 10 most recently active users
- Latest logon time and type
- Total logon count per user

**Inactive Account Detection:**
- Users not seen in last 30 days
- Potential stale accounts requiring review

### CSV Export

When using `-OutputPath`, the script exports detailed data including:

| Column | Description |
|--------|-------------|
| `AccountName` | Username or account name |
| `LatestLogon` | Most recent logon timestamp |
| `LatestLogonType` | Type of most recent logon |
| `FirstSeen` | Earliest logon in analyzed period |
| `TotalLogons` | Number of logon events for user |
| `DaysSinceLastLogon` | Days since most recent logon |
| `IsSystemAccount` | Boolean indicating system account |
| `ActivitySpan` | Days between first and last logon |

## Logon Type Classifications

The script categorizes different Windows logon types:

| Type | Description | Common Scenarios |
|------|-------------|------------------|
| Interactive | Direct console logon | Physical computer access |
| RemoteInteractive | RDP/Remote Desktop | Remote administration |
| Network | Network authentication | File share access, mapped drives |
| Service | Service account logon | Scheduled tasks, services |
| Batch | Batch logon | Scheduled jobs |
| CachedInteractive | Cached credential logon | Offline domain logon |
| Unlock | Workstation unlock | Screen unlock |
| NetworkCleartext | Network cleartext | IIS basic authentication |

## Integration Examples

### Daily Security Monitoring
```powershell
# Daily logon activity check
$yesterday = (Get-Date).AddDays(-1).Date
$today = (Get-Date).Date
$reportPath = "C:\DailyReports\Logons-$(Get-Date -Format 'yyyy-MM-dd').csv"

.\Get-UserLogonActivity.ps1 -StartTime $yesterday -EndTime $today -OutputPath $reportPath

# Check for unusual activity
$results = Import-Csv $reportPath
$afterHours = $results | Where-Object { 
    $logonHour = ([datetime]$_.LatestLogon).Hour
    $logonHour -lt 6 -or $logonHour -gt 22 
}

if ($afterHours) {
    Send-MailMessage -To "security@company.com" -Subject "After Hours Logon Activity" -Body "Found $($afterHours.Count) after-hours logons"
}
```

### SIEM Integration
```powershell
# Export for SIEM ingestion
$siemData = .\Get-UserLogonActivity.ps1 -StartTime (Get-Date).AddHours(-1) -OutputPath "C:\SIEM\Logons.csv"

# Convert to JSON for SIEM API
$jsonData = Import-Csv "C:\SIEM\Logons.csv" | ConvertTo-Json
Invoke-RestMethod -Uri "https://siem.company.com/api/events" -Method POST -Body $jsonData -ContentType "application/json"
```

### User Access Review Automation
```powershell
# Generate user access review data
$reviewPeriod = 90 # days
$reviewStart = (Get-Date).AddDays(-$reviewPeriod)
$outputPath = "C:\AccessReviews\$(Get-Date -Format 'yyyy-MM-dd')-UserAccess.csv"

.\Get-UserLogonActivity.ps1 -StartTime $reviewStart -OutputPath $outputPath

# Identify accounts for review
$accessData = Import-Csv $outputPath
$inactiveAccounts = $accessData | Where-Object { [int]$_.DaysSinceLastLogon -gt 30 }
$highActivityAccounts = $accessData | Where-Object { [int]$_.TotalLogons -gt 1000 }

# Generate summary report
$summary = @{
    "Review Period" = "$reviewPeriod days"
    "Total Accounts" = $accessData.Count
    "Inactive Accounts (30+ days)" = $inactiveAccounts.Count
    "High Activity Accounts (1000+ logons)" = $highActivityAccounts.Count
}

$summary | ConvertTo-Json | Out-File "C:\AccessReviews\$(Get-Date -Format 'yyyy-MM-dd')-Summary.json"
```

### PowerBI Dashboard Data
```powershell
# Prepare data for PowerBI dashboard
$dashboardData = .\Get-UserLogonActivity.ps1 -StartTime (Get-Date).AddDays(-30) -OutputPath "C:\PowerBI\LogonActivity.csv"

# Create trend analysis
$dailyStats = Import-Csv "C:\PowerBI\LogonActivity.csv" | 
    Group-Object {([datetime]$_.LatestLogon).Date} |
    Select-Object @{N='Date';E={$_.Name}}, @{N='UniqueUsers';E={$_.Count}}, @{N='TotalLogons';E={($_.Group | Measure-Object TotalLogons -Sum).Sum}}

$dailyStats | Export-Csv "C:\PowerBI\DailyLogonTrends.csv" -NoTypeInformation
```

## Performance Considerations

### Optimization Strategies

1. **Use Time Filters** - Limit analysis to specific periods to reduce processing time
2. **Set MaxEvents** - Cap event processing for initial analysis or regular monitoring
3. **Filter Logon Types** - Use `-ExcludeInteractiveOnly` to focus on relevant logon types
4. **Remote Analysis** - Consider network bandwidth when analyzing remote computers

### Expected Performance

| Event Count | Processing Time | Memory Usage | Recommendations |
|-------------|----------------|--------------|-----------------|
| < 10,000    | 30-60 seconds  | < 100 MB     | No optimization needed |
| 10K-50K     | 2-5 minutes    | 100-300 MB   | Consider time filtering |
| 50K-100K    | 5-15 minutes   | 300-500 MB   | Use MaxEvents parameter |
| 100K+       | 15+ minutes    | 500+ MB      | Batch processing recommended |

### Large Dataset Handling
```powershell
# Process large datasets in batches
$batchSize = 25000
$totalProcessed = 0
$allResults = @()

do {
    $batch = .\Get-UserLogonActivity.ps1 -MaxEvents $batchSize -StartTime $startTime -EndTime $endTime
    $allResults += $batch
    $totalProcessed += $batchSize
    
    Write-Host "Processed $totalProcessed events..."
    Start-Sleep -Seconds 5  # Brief pause to prevent resource exhaustion
    
} while ($batch.Count -eq $batchSize)
```

## Troubleshooting

### Common Issues

**Access Denied Errors**
```powershell
# Verify current user has appropriate permissions
whoami /priv | findstr "SeSecurityPrivilege"

# Check if running as administrator
([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

# Test basic event log access
Get-WinEvent -LogName Security -MaxEvents 1
```

**No Events Found**
```powershell
# Check if Security auditing is enabled
auditpol /get /category:"Logon/Logoff"

# Verify Event ID 4624 is being logged
Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4624} -MaxEvents 1

# Check Security log size and retention
Get-WinEvent -ListLog Security | Select-Object LogName, RecordCount, MaximumSizeInBytes
```

**Performance Issues**
```powershell
# Check available system resources
Get-Counter "\Memory\Available MBytes"
Get-Counter "\Processor(_Total)\% Processor Time"

# Monitor PowerShell process during execution
Get-Process PowerShell* | Select-Object Name, CPU, WorkingSet

# Use time-based filtering to reduce dataset
$recentOnly = (Get-Date).AddDays(-7)
.\Get-UserLogonActivity.ps1 -StartTime $recentOnly -MaxEvents 10000
```

**Remote Computer Issues**
```powershell
# Test remote connectivity
Test-NetConnection -ComputerName "RemoteServer" -Port 5985  # WinRM HTTP
Test-NetConnection -ComputerName "RemoteServer" -Port 5986  # WinRM HTTPS

# Verify remote event log access
Get-WinEvent -ComputerName "RemoteServer" -LogName Security -MaxEvents 1

# Check firewall rules for Windows Remote Management
Get-NetFirewallRule -DisplayName "*Remote Event Log Management*"
```

**Memory Exhaustion**
```powershell
# Process events in smaller batches
.\Get-UserLogonActivity.ps1 -MaxEvents 5000 -StartTime (Get-Date).AddDays(-1)

# Clear variables between runs
Remove-Variable events, userActivity -ErrorAction SilentlyContinue
[System.GC]::Collect()
```

### Event Log Configuration Issues

**Enable Security Auditing (if missing events):**
```cmd
# Enable logon auditing via Group Policy or local policy
auditpol /set /subcategory:"Logon" /success:enable

# Check current audit policy
auditpol /get /subcategory:"Logon"
```

**Increase Security Log Size:**
```powershell
# Check current log configuration
Get-WinEvent -ListLog Security | Format-List

# Increase log size (requires administrative privileges)
wevtutil sl Security /ms:1073741824  # Set to 1GB
```

## Security Considerations

### Data Sensitivity
- **Event logs contain sensitive information** including usernames, IP addresses, and access patterns
- **Exported CSV files** should be stored securely and access-controlled
- **Consider data retention policies** for exported reports
- **Implement proper disposal** of exported data when no longer needed

### Monitoring and Alerting
- **Regular execution** helps establish baseline activity patterns
- **Automated alerting** for unusual logon patterns or volumes
- **Integration with SIEM** systems for comprehensive security monitoring
- **Correlation with other security events** for enhanced threat detection

### Compliance Applications
- **User access reviews** for SOX, HIPAA, PCI-DSS compliance
- **Privileged access monitoring** for administrative accounts
- **Insider threat detection** through activity pattern analysis
- **Audit trail maintenance** for forensic investigations

## Development Notes

**Original Purpose:** Developed for enterprise security auditing to identify user access patterns, inactive accounts, and potential security concerns in Windows domain environments.

**Enhancement History:**
- **Initial Version:** Basic logon event enumeration for manual security reviews
- **v1.0 Enhancement:** Added comprehensive filtering, performance optimization, and automated reporting capabilities
- **Documentation Update:** August 2025 - Professional presentation for portfolio

**Production Context:** Used in enterprise environments for:
- Daily security monitoring and alerting
- Monthly user access reviews
- Quarterly compliance reporting
- Incident response and forensic analysis
- Insider threat detection programs

## Related Tools and Integration

### Microsoft Security Tools
- **Microsoft Sentinel** - SIEM integration for advanced analytics
- **Microsoft Defender for Identity** - Identity threat detection
- **Advanced Audit Policy Configuration** - Enhanced logging configuration

### Third-Party SIEM Integration
- **Splunk** - Custom data inputs and dashboards
- **QRadar** - Event correlation and threat detection
- **ArcSight** - Security event management

### PowerShell Security Modules
- **PowerShell Protect** - Additional security analysis capabilities
- **PSEventViewer** - Enhanced event log processing
- **SecurityFever** - Security-focused PowerShell functions

---

**Part of Security-Tools Collection:** [Back to Security Tools](README.md) | [Main Repository](../README.md)