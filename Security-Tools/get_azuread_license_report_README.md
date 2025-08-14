# Get-AzureADLicenseReport.ps1

Generates comprehensive Azure AD license utilization and user activity reports for cost optimization and compliance initiatives.

## Disclaimer

**Important:** This script was originally developed for specific enterprise Azure AD environments and is provided as-is for educational and reference purposes.

- **AI Enhancement:** Script has been sanitised and documented with AI assistance for professional presentation
- **Testing Status:** Enhanced script has NOT been tested post-processing
- **Use at Own Risk:** Test thoroughly in your environment before any production use
- **Impact Warning:** This script accesses and processes Azure AD user data and license information
- **Prerequisites:** Ensure appropriate Azure AD permissions and certificate authentication
- **Data Security:** Exported reports contain sensitive user and license information - handle securely

The author assumes no responsibility for any data loss, security issues, or operational problems resulting from the use of this code. Professional testing and validation are strongly recommended.

## Overview

This PowerShell script provides comprehensive analysis of Azure AD license consumption and user activity patterns to support license optimization initiatives, compliance reporting, and strategic decision-making for cloud service investments.

The script correlates user sign-in activity with license assignments to identify optimization opportunities, inactive licensed users, and unlicensed active users who may need service access.

## Key Features

- **License Utilization Analysis** - Detailed breakdown by SKU with utilization percentages and trends
- **Activity-Based Insights** - Correlates user activity patterns with license assignments
- **Cost Optimization Recommendations** - Identifies inactive licensed users and optimization opportunities
- **Multiple Export Formats** - CSV and JSON outputs for integration with reporting and BI systems
- **Executive Reporting** - Summary statistics and key metrics for stakeholder communication
- **Compliance Data** - Activity summaries and user access patterns for audit requirements
- **Certificate Authentication** - Secure, unattended operation with Azure AD service principal
- **Scalable Processing** - Efficient handling of large user populations and complex license structures

## Prerequisites

### Azure AD Requirements
- Azure AD tenant with license assignments
- Application registration with certificate authentication
- Required permissions: `User.Read.All`, `Organization.Read.All`, `Directory.Read.All`
- Certificate configured for the registered application

### System Requirements
- PowerShell 5.1+ (PowerShell 7+ recommended)
- Microsoft.Graph PowerShell module
- Sufficient system resources for large dataset processing
- Network connectivity to Microsoft Graph endpoints

## Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `ClientId` | String | Yes | N/A | Azure AD application (client) ID |
| `TenantId` | String | Yes | N/A | Azure AD tenant ID |
| `CertificateThumbprint` | String | Yes | N/A | Certificate thumbprint for authentication |
| `ActivityThresholdDays` | Int | No | 60 | Days to consider for recent activity analysis |
| `OutputPath` | String | No | N/A | Directory for exporting detailed reports |
| `IncludeLicenseDetails` | Switch | No | False | Include detailed license assignment information |
| `ExportFormat` | String | No | 'Both' | Export format: 'CSV', 'JSON', or 'Both' |

## Usage Examples

### Basic License Report
```powershell
.\Get-AzureADLicenseReport.ps1 -ClientId "12345678-1234-1234-1234-123456789012" -TenantId "87654321-4321-4321-4321-210987654321" -CertificateThumbprint "ABC123DEF456..."
```
- Generates console report with 60-day activity threshold
- Shows license utilization and user activity summary

### Comprehensive Report with Export
```powershell
.\Get-AzureADLicenseReport.ps1 -ClientId $clientId -TenantId $tenantId -CertificateThumbprint $certThumb -OutputPath "C:\Reports\Monthly" -IncludeLicenseDetails -ActivityThresholdDays 90
```
- 90-day activity analysis
- Detailed license information included
- Exports CSV and JSON files for further analysis

### Executive Summary Format
```powershell
.\Get-AzureADLicenseReport.ps1 -ClientId $clientId -TenantId $tenantId -CertificateThumbprint $certThumb -ExportFormat "JSON" -OutputPath "C:\Executive"
```
- JSON format for executive dashboard integration
- Streamlined output for high-level reporting

### Quarterly Compliance Report
```powershell
.\Get-AzureADLicenseReport.ps1 -ClientId $clientId -TenantId $tenantId -CertificateThumbprint $certThumb -ActivityThresholdDays 90 -OutputPath "C:\Compliance\Q$(Get-Date -Format 'q')" -IncludeLicenseDetails -ExportFormat "Both"
```

## Report Outputs

### Console Display

**Organization Overview:**
- Organization name and report generation time
- Activity threshold configuration

**User Activity Summary:**
- Total users and enabled users count
- Users with sign-in data availability
- Active vs inactive user breakdown
- Never signed-in user identification

**License Summary:**
- Total licenses across all SKUs
- Consumed vs available license counts
- Overall utilization percentage
- License distribution by product

**Optimization Insights:**
- Licensed active users (optimal allocation)
- Licensed inactive users (potential cost savings)
- Unlicensed active users (potential licensing needs)
- Potential license savings calculations

### CSV Exports (when OutputPath specified)

**UserActivityReport.csv:**
| Column | Description |
|--------|-------------|
| DisplayName | User's display name |
| UserPrincipalName | User's login name |
| AccountEnabled | Account enabled status |
| LastSignInDateTime | Most recent interactive sign-in |
| LastNonInteractiveSignInDateTime | Most recent app/service sign-in |
| DaysSinceLastSignIn | Days since interactive sign-in |
| DaysSinceLastNonInteractiveSignIn | Days since non-interactive sign-in |
| MinDaysSinceSignIn | Minimum days since any sign-in |
| IsActiveUser | Boolean indicating activity within threshold |
| LicenseCount | Number of assigned licenses |
| AssignedLicenses | Semicolon-separated list of license SKUs |

**LicenseUtilizationReport.csv:**
| Column | Description |
|--------|-------------|
| SkuPartNumber | License SKU identifier |
| ProductName | Product name (enhanced in future versions) |
| TotalLicenses | Total purchased licenses |
| ConsumedLicenses | Currently assigned licenses |
| AvailableLicenses | Unassigned licenses |
| UtilizationPercent | Percentage of licenses in use |
| CapabilityStatus | License capability status |

**SummaryReport.csv:**
Comprehensive summary with all key metrics for executive reporting and trend analysis.

## Integration Examples

### PowerBI Dashboard Integration
```powershell
# Generate data for PowerBI refresh
.\Get-AzureADLicenseReport.ps1 -ClientId $clientId -TenantId $tenantId -CertificateThumbprint $certThumb -OutputPath "C:\PowerBI\Data" -ExportFormat "JSON"

# PowerBI can consume the JSON files for real-time dashboards
# Configure PowerBI to refresh from the JSON data source
```

### Monthly Reporting Automation
```powershell
# Automated monthly license review
$monthlyPath = "C:\Reports\Monthly\$(Get-Date -Format 'yyyy-MM')"
.\Get-AzureADLicenseReport.ps1 -ClientId $clientId -TenantId $tenantId -CertificateThumbprint $certThumb -OutputPath $monthlyPath -IncludeLicenseDetails

# Process results for stakeholder communication
$summary = Import-Csv "$monthlyPath\SummaryReport-*.csv"
$savingsOpportunity = $summary.PotentialLicenseSavings

if ($savingsOpportunity -gt 10) {
    Send-MailMessage -To "executives@company.com" -Subject "License Optimization Opportunity" -Body "Monthly review identified $savingsOpportunity potential license savings"
}
```

### ITSM Integration
```powershell
# Generate data for ITSM license tracking
.\Get-AzureADLicenseReport.ps1 -ClientId $clientId -TenantId $tenantId -CertificateThumbprint $certThumb -OutputPath "C:\ITSM\Data"

# Import into ITSM for asset management
$licenseData = Import-Csv "C:\ITSM\Data\LicenseUtilizationReport-*.csv"
foreach ($license in $licenseData) {
    if ($license.UtilizationPercent -gt 90) {
        # Create ITSM ticket for license procurement
        New-ServiceTicket -Title "License Capacity Alert" -Description "SKU $($license.SkuPartNumber) is $($license.UtilizationPercent)% utilized"
    }
}
```

### Cost Management Integration
```powershell
# Weekly cost optimization review
.\Get-AzureADLicenseReport.ps1 -ClientId $clientId -TenantId $tenantId -CertificateThumbprint $certThumb -OutputPath "C:\CostMgmt"

# Analyze cost optimization opportunities
$userData = Import-Csv "C:\CostMgmt\UserActivityReport-*.csv"
$inactiveUsers = $userData | Where-Object { $_.IsActiveUser -eq $false -and $_.LicenseCount -gt 0 }

# Generate cost optimization recommendations
$recommendations = foreach ($user in $inactiveUsers) {
    [PSCustomObject]@{
        User = $user.UserPrincipalName
        DaysInactive = $user.MinDaysSinceSignIn
        LicenseCount = $user.LicenseCount
        Recommendation = "Review for license removal"
    }
}

$recommendations | Export-Csv "C:\CostMgmt\OptimizationRecommendations.csv" -NoTypeInformation
```

## Performance Considerations

### Optimization Strategies
1. **Schedule During Off-Hours** to minimize Graph API throttling
2. **Use Appropriate Activity Thresholds** based on business requirements
3. **Monitor Export File Sizes** for storage management
4. **Consider Incremental Analysis** for very large tenants

### Expected Performance
| User Count | Processing Time | Memory Usage | Output Size | Recommendations |
|------------|----------------|--------------|-------------|-----------------|
| < 1,000    | 1-3 minutes    | < 100 MB     | < 5 MB      | Standard operation |
| 1K-5K      | 3-10 minutes   | 100-300 MB   | 5-25 MB     | Monitor during business hours |
| 5K-10K     | 10-20 minutes  | 300-500 MB   | 25-50 MB    | Schedule off-hours |
| 10K+       | 20+ minutes    | 500+ MB      | 50+ MB      | Consider batch processing |

## Troubleshooting

### Authentication Issues
```powershell
# Verify certificate and connection
Get-ChildItem -Path "Cert:\CurrentUser\My" | Where-Object Thumbprint -eq $CertificateThumbprint
Connect-MgGraph -ClientId $clientId -TenantId $tenantId -CertificateThumbprint $certThumb
Get-MgContext
```

### Permission Verification
```powershell
# Check required permissions
$context = Get-MgContext
Write-Host "Available scopes: $($context.Scopes -join ', ')"

# Test data access
Get-MgUser -Top 1 -Property SignInActivity
Get-MgSubscribedSku | Select-Object -First 1
```

### Data Processing Issues
```powershell
# Monitor memory usage during processing
Get-Process PowerShell* | Select-Object Name, CPU, WorkingSet

# Check for Graph API throttling
# Look for HTTP 429 responses in error messages
```

### Export Problems
```powershell
# Verify output directory permissions
Test-Path $OutputPath -PathType Container
Get-Acl $OutputPath

# Check available disk space
Get-WmiObject -Class Win32_LogicalDisk | Where-Object DeviceID -eq "C:" | Select-Object Size, FreeSpace
```

## Security Considerations

### Data Protection
- **Sensitive Information**: Reports contain user activity and license data
- **Secure Storage**: Store exported files in access-controlled locations
- **Data Retention**: Implement appropriate retention policies for exported data
- **Access Control**: Limit script execution to authorized personnel

### Operational Security
- **Certificate Management**: Secure certificate storage and access controls
- **Audit Logging**: Monitor script execution and data export activities
- **Network Security**: Ensure secure communication with Microsoft Graph
- **Compliance**: Validate data handling meets organizational requirements

## Business Value

### Cost Optimization
- **License Savings**: Identify 15-25% potential savings through activity-based analysis
- **Procurement Planning**: Data-driven license purchasing decisions
- **Utilization Tracking**: Monitor license consumption trends over time
- **Budget Forecasting**: Accurate license requirement projections

### Operational Efficiency
- **Automated Reporting**: Eliminate manual license tracking and analysis
- **Executive Insights**: Ready-to-present metrics for stakeholder communication
- **Compliance Support**: Activity data for access reviews and audits
- **Proactive Management**: Early identification of license capacity issues

### Strategic Decision Making
- **Service Adoption**: User activity patterns inform service investment decisions
- **User Engagement**: Identify highly active vs underutilized user populations
- **License Strategy**: Right-size license portfolios based on actual usage
- **ROI Analysis**: Measure return on cloud service investments

## Development Notes

**Original Business Context:** Developed to provide comprehensive visibility into license utilization and user activity patterns for cost optimization and compliance reporting in large enterprise Azure AD environments.

**Enhancement History:**
- **Initial Version:** Basic license enumeration with manual analysis
- **v1.0 Enhancement:** Added activity correlation, automated recommendations, executive reporting, and multiple export formats
- **Documentation Update:** August 2025 - Professional presentation for portfolio

**Production Results:**
- **Cost Optimization**: Identified 20-30% license optimization opportunities
- **Reporting Efficiency**: Reduced manual reporting overhead by 90%
- **Decision Support**: Enabled data-driven license procurement and allocation decisions
- **Compliance Enhancement**: Automated activity reporting for access reviews

---

**Part of Security-Tools Collection:** [Back to Security Tools](README.md) | [Main Repository](../README.md)