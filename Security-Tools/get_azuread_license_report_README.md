# Get-AzureADLicenseReport.ps1

Azure AD licence utilisation and user activity reporting for cost optimisation and compliance.

## Disclaimer

These scripts were originally developed for specific enterprise environments. They have been updated and documented from their original form by AI. The updated versions have not been tested. Validate and review the scripts before using them. The author assumes no responsibility for any data loss, security issues, or operational problems resulting from the use of this code.

## Overview

Analyses Azure AD licence consumption and user activity patterns to identify optimisation opportunities, inactive licensed users, and unlicensed active users.

## Features

- Licence utilisation analysis by SKU
- Activity-based insights correlating user activity with licence assignments
- Cost optimisation recommendations
- Multiple export formats (CSV and JSON)
- Certificate authentication for unattended operation
- Scalable processing for large user populations

## Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `ClientId` | String | Yes | N/A | Azure AD application (client) ID |
| `TenantId` | String | Yes | N/A | Azure AD tenant ID |
| `CertificateThumbprint` | String | Yes | N/A | Certificate thumbprint for authentication |
| `ActivityThresholdDays` | Int | No | 60 | Days to consider for recent activity analysis |
| `OutputPath` | String | No | N/A | Directory for exporting detailed reports |
| `IncludeLicenseDetails` | Switch | No | False | Include detailed licence assignment information |
| `ExportFormat` | String | No | 'Both' | Export format: 'CSV', 'JSON', or 'Both' |

## Usage

```powershell
# Basic console report
.\Get-AzureADLicenseReport.ps1 -ClientId "12345678-1234-1234-1234-123456789012" -TenantId "87654321-4321-4321-4321-210987654321" -CertificateThumbprint "ABC123DEF456..."

# Detailed report with export
.\Get-AzureADLicenseReport.ps1 -ClientId $clientId -TenantId $tenantId -CertificateThumbprint $certThumb -OutputPath "C:\Reports" -IncludeLicenseDetails -ActivityThresholdDays 90
```

## Report Outputs

### Console Display
- User activity summary (total, enabled, active vs inactive users)
- Licence summary (total, consumed, available by SKU)
- Optimisation insights (licensed active/inactive users, potential savings)

### CSV Exports (when OutputPath specified)
- **UserActivityReport.csv**: User activity and licence assignment details
- **LicenseUtilizationReport.csv**: Licence utilisation by SKU
- **SummaryReport.csv**: Key metrics for executive reporting

## Authentication Setup

Requires Azure AD app registration with certificate authentication and these permissions:
- `User.Read.All`
- `Organization.Read.All` 
- `Directory.Read.All`

---

**Part of my PowerShell Library:** [Security Tools](README.md) | [Main Repository](../README.md) to explore other solutions and tools.
