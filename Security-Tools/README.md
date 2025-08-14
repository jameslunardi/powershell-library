# Security Tools

A collection of PowerShell scripts and utilities for security monitoring, auditing, and compliance operations in enterprise environments.

## Disclaimer

**Important:** These tools were originally developed for specific enterprise security environments and are provided as-is for educational and reference purposes.

- **AI Enhancement:** Scripts have been sanitised and documented with AI assistance for professional presentation
- **Testing Status:** Enhanced scripts have NOT been tested post-processing
- **Use at Own Risk:** Test thoroughly in your environment before any production use
- **Impact Warning:** These tools access sensitive security logs and system information
- **Prerequisites:** Ensure appropriate administrative permissions and security clearances
- **Compliance:** Validate tools meet your organization's security and audit requirements

The author assumes no responsibility for any data loss, security issues, or operational problems resulting from the use of this code. Professional testing and validation are strongly recommended.

## Scripts

### Get-UserLogonActivity.ps1
Comprehensive Windows Security Event Log analysis for user logon activity monitoring. Processes Event ID 4624 (successful logons) to identify user access patterns, inactive accounts, and security anomalies.

**[📖 Full Documentation](Get-UserLogonActivity-README.md)**

```powershell
# Example usage
.\Get-UserLogonActivity.ps1 -StartTime (Get-Date).AddDays(-7) -OutputPath "C:\Reports\LogonActivity.csv"
```

### Sync-AzureADActivity.ps1
Synchronizes Azure AD user sign-in activity to on-premises Active Directory for hybrid identity governance and license optimization. Enables activity-aware account lifecycle management in hybrid environments.

**[📖 Full Documentation](Sync-AzureADActivity-README.md)**

```powershell
# Example usage
.\Sync-AzureADActivity.ps1 -ClientId $clientId -TenantId $tenantId -CertificateThumbprint $certThumb -ActivityThresholdDays 60
```

### Get-AzureADLicenseReport.ps1
Comprehensive Azure AD license utilization and user activity reporting for cost optimization and compliance. Provides detailed insights into license consumption patterns and inactive user identification.

**[📖 Full Documentation](Get-AzureADLicenseReport-README.md)**

```powershell
# Example usage
.\Get-AzureADLicenseReport.ps1 -ClientId $clientId -TenantId $tenantId -CertificateThumbprint $certThumb -OutputPath "C:\Reports"
```

---

## General Requirements

- **PowerShell 5.1+** (PowerShell 7+ recommended)
- **Administrative privileges** for security log access
- **Appropriate security clearances** and permissions
- **Secure storage** for exported data and reports

## Security Considerations

- **Sensitive Data Handling** - Security logs contain PII and access patterns
- **Access Control** - Restrict tool usage to authorized security personnel
- **Data Retention** - Implement appropriate retention policies for security data
- **Audit Trails** - Maintain logs of security tool usage and data access
- **Compliance** - Ensure tools meet regulatory and organizational requirements

## Use Cases

### Security Monitoring
- Daily user activity analysis
- Anomaly detection and alerting
- Insider threat monitoring
- Access pattern analysis

### Compliance Auditing
- User access reviews
- Privileged account monitoring
- Regulatory compliance reporting
- Audit trail generation

### Incident Response
- Forensic analysis support
- Timeline reconstruction
- User activity correlation
- Evidence collection

---

**Part of the PowerShell Library:** Visit the [main repository](../README.md) to explore other automation solutions.