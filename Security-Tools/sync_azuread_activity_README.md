# Sync-AzureADActivity.ps1

Synchronises Azure AD user sign-in activity to on-premises Active Directory for hybrid identity governance and licence optimisation.

## Disclaimer

These scripts were originally developed for specific enterprise environments. They have been updated and documented from their original form by AI. The updated versions have not been tested. Validate and review the scripts before using them. The author assumes no responsibility for any data loss, security issues, or operational problems resulting from the use of this code.

## Overview

Addresses the challenge of tracking user activity in hybrid environments where users access only Azure AD-authenticated SaaS services. Synchronises Azure AD sign-in activity to on-premises Active Directory via ExtensionAttribute9 to enable activity-aware account lifecycle management.

## Problem Solved

Users accessing only cloud services (Office 365, Teams, SharePoint Online) don't generate on-premises logon events, leading to:
- Unnecessary account disabling due to perceived inactivity
- Poor visibility into actual user engagement
- Inefficient licence allocation decisions

## Features

- Bridges cloud and on-premises user activity visibility
- Certificate authentication for secure, unattended operation
- Configurable activity thresholds
- Report-only mode for testing
- Performance optimised for large user datasets
- Comprehensive logging and error handling

## Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `ClientId` | String | Yes | N/A | Azure AD application (client) ID |
| `TenantId` | String | Yes | N/A | Azure AD tenant ID |
| `CertificateThumbprint` | String | Yes | N/A | Certificate thumbprint for authentication |
| `ActivityThresholdDays` | Int | No | 60 | Days to consider for recent activity |
| `LogPath` | String | No | Script directory | Path for log file |
| `ReportOnly` | Switch | No | False | Run without making AD changes |
| `TestMode` | Switch | No | False | Process only subset of users |

## Usage

```powershell
# Basic activity sync
.\Sync-AzureADActivity.ps1 -ClientId "12345678-1234-1234-1234-123456789012" -TenantId "87654321-4321-4321-4321-210987654321" -CertificateThumbprint "ABC123DEF456..."

# Custom activity threshold (90 days)
.\Sync-AzureADActivity.ps1 -ClientId $clientId -TenantId $tenantId -CertificateThumbprint $certThumb -ActivityThresholdDays 90

# Test mode without changes
.\Sync-AzureADActivity.ps1 -ClientId $clientId -TenantId $tenantId -CertificateThumbprint $certThumb -ReportOnly
```

## How It Works

1. **Retrieves Azure AD users** with sign-in activity data
2. **Calculates activity status** based on interactive and non-interactive sign-ins
3. **Matches users** by converting UPN to SamAccountName  
4. **Updates ExtensionAttribute9** in on-premises AD:
   - `"True"`: User active within threshold
   - `"False"`: User inactive or never signed in
5. **Logs all actions** for audit and troubleshooting

## Requirements

### Azure AD
- Application registration with certificate authentication
- Required permissions: `User.Read.All`, `AuditLog.Read.All`

### On-Premises
- Active Directory with Azure AD Connect synchronisation
- Service account with write permissions to user accounts
- ExtensionAttribute9 synchronised via Azure AD Connect

---

**Part of my PowerShell Library:** [Security Tools](README.md) | [Main Repository](../README.md) to explore other solutions and tools.
