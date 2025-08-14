# PowerShell Library

A comprehensive collection of enterprise-grade PowerShell scripts and automation solutions developed for real-world production environments. This repository showcases practical automation tools across Active Directory management, DevOps operations, Azure administration, and security tooling.

## Disclaimer

**Important:** These solutions were originally developed for specific enterprise environments and are provided as-is for educational and reference purposes.

- **Original Development:** Created without AI assistance for production use in enterprise environments
- **AI Enhancement:** Scripts have been sanitised and documented with AI assistance for professional presentation (August 2025)
- **Testing Status:** Enhanced scripts have NOT been tested post-processing
- **Use at Own Risk:** Test thoroughly in your environment before any production use
- **Impact Warning:** These tools interact with production systems, modify configurations, and handle sensitive data
- **Prerequisites:** Ensure appropriate permissions, backups, security measures, and compliance procedures
- **Professional Validation:** Strongly recommended before any production implementation

The author assumes no responsibility for any data loss, security issues, or operational problems resulting from the use of this code. Professional testing and validation are essential.

## Repository Overview

This library demonstrates enterprise PowerShell development skills across multiple domains:

- **Complex system integration** and cross-domain automation
- **Production-grade error handling** and safety mechanisms
- **Enterprise security practices** and compliance considerations
- **Scalable automation solutions** with comprehensive logging
- **Professional documentation** and operational procedures

## Solutions

### 🔄 [AD-Sync-Solution](AD-Sync-Solution/)
**Enterprise Active Directory User Synchronisation System**

A comprehensive solution for synchronising user accounts between two Active Directory domains. Originally developed as an "interim solution" in June 2019, it proved so robust that it remained the primary production system for 5 years until replaced by a dedicated enterprise IAM platform in June 2024.

**Key Features:**
- Cross-domain user synchronisation with safety thresholds
- Two-stage removal process (quarantine → delete)
- Unix/Linux attribute support (SFU)
- Comprehensive logging and email alerting
- Production-tested reliability over 5 years

**Technologies:** PowerShell, Active Directory, Cross-domain authentication, Email automation

```powershell
# Example: Run sync in report-only mode
.\Start-ADSync.ps1 -ReportOnly $true
```

### 🛠️ [DevOps-Tools](DevOps-Tools/)
**DevOps Automation and Infrastructure Utilities**

A collection of professional DevOps automation tools for artifact management, Azure administration, and deployment operations.

#### Upload-ToArtifactory.ps1
Enterprise-grade file upload utility for JFrog Artifactory with comprehensive integrity verification.

**Features:** Multi-hash validation (MD5/SHA1/SHA256), cross-platform compatibility, progress tracking, automated TLS configuration

#### Export-AzureADApplications.ps1
Comprehensive Azure AD application inventory and audit tool for compliance reporting.

**Features:** Complete application metadata export, security audit capabilities, compliance reporting, multi-tenant support

**Technologies:** PowerShell, JFrog Artifactory APIs, Azure Active Directory, REST APIs, Compliance automation

```powershell
# Example: Upload with integrity verification
.\Upload-ToArtifactory.ps1 -SourceFile "app.zip" -DestinationUrl "https://artifactory.company.com/repo/app.zip" -ApiKey $apiKey

# Example: Export Azure AD apps for audit
.\Export-AzureADApplications.ps1 -OutputPath "C:\Reports" -IncludeDisabled
```

### 🔐 [Security-Tools](Security-Tools/)
**Security Monitoring and Audit Utilities**

Professional security tools for monitoring, auditing, and compliance operations in enterprise environments.

#### Get-UserLogonActivity.ps1
Comprehensive Windows Security Event Log analysis for user logon activity monitoring and security auditing.

**Features:** Event ID 4624 analysis, user activity tracking, inactive account detection, compliance reporting, performance optimization

**Technologies:** PowerShell, Windows Event Logs, Security Auditing, Compliance Automation

```powershell
# Example: Weekly security audit
.\Get-UserLogonActivity.ps1 -StartTime (Get-Date).AddDays(-7) -OutputPath "C:\SecurityReports\WeeklyLogons.csv"
```

## Technical Highlights

### Enterprise-Grade Features
- **Safety Mechanisms:** Deletion thresholds, confirmation prompts, report-only modes
- **Error Handling:** Comprehensive try-catch blocks with detailed error reporting
- **Logging:** Transaction logs, CSV exports, email alerting, audit trails
- **Security:** Encrypted credential storage, secure API authentication, permission validation
- **Performance:** Background job processing, parallel operations, memory-efficient streaming

### Professional Development Practices
- **Comment-Based Help:** Complete PowerShell help documentation for all functions
- **Parameter Validation:** Input validation with meaningful error messages
- **Modular Design:** Reusable functions and clean separation of concerns
- **Cross-Platform:** Compatible with PowerShell 5.1+ and PowerShell 7+
- **Production Testing:** Solutions proven in enterprise environments over multiple years

### Integration Capabilities
- **CI/CD Pipelines:** Jenkins, Azure DevOps integration examples
- **Automation Frameworks:** Scheduled task integration, batch processing
- **Monitoring Systems:** SIEM integration, alerting mechanisms
- **Compliance Tools:** Audit reporting, data export capabilities

## Prerequisites

### General Requirements
- **PowerShell 5.1+** (PowerShell 7+ recommended for optimal performance)
- **Appropriate permissions** for target systems and services
- **Network connectivity** to required services and domains
- **Valid credentials** and authentication mechanisms

### Module Dependencies
Different solutions require specific PowerShell modules:
- **ActiveDirectory** - For AD-Sync-Solution
- **AzureAD** - For Azure-related tools
- **Various API clients** - Depending on target services

### Security Considerations
- **Service Accounts:** Dedicated accounts with minimal required permissions
- **Credential Management:** Encrypted password files, environment variables, or key vaults
- **Network Security:** Secure communication channels and appropriate firewall rules
- **Audit Requirements:** Logging and monitoring for compliance purposes

## Getting Started

### 1. Clone the Repository
```bash
git clone https://github.com/jameslunardi/powershell-library.git
cd powershell-library
```

### 2. Review Documentation
Each solution includes comprehensive documentation:
- **README.md** - Overview and quick start
- **Detailed READMEs** - Complete implementation guides
- **Comment-based help** - PowerShell Get-Help compatible documentation

### 3. Test in Non-Production
Always test scripts in a safe environment first:
```powershell
# Use report-only modes where available
.\Start-ADSync.ps1 -ReportOnly $true

# Use WhatIf parameters for testing
.\Export-AzureADApplications.ps1 -WhatIf
```

### 4. Configure for Your Environment
- Update configuration sections in each script
- Set up appropriate credentials and permissions
- Modify paths, domains, and service endpoints
- Configure logging and alerting mechanisms

## Use Cases

### Identity and Access Management
- **User lifecycle automation** across domains
- **Application inventory** and compliance auditing
- **Permission analysis** and governance reporting
- **Identity synchronisation** and data consistency

### DevOps and Operations
- **Artifact management** and deployment automation
- **Infrastructure auditing** and documentation
- **Compliance reporting** and security assessments
- **Operational tooling** and process automation

### Security and Compliance
- **Access reviews** and application audits
- **Configuration management** and drift detection
- **Audit trail generation** and compliance reporting
- **Security monitoring** and alerting integration

## Professional Context

These solutions represent real-world enterprise automation challenges and demonstrate:

### Problem-Solving Ability
- **Complex integration** requirements solved with elegant solutions
- **Production constraints** addressed with appropriate safety mechanisms
- **Long-term maintainability** proven through years of operational use
- **Scalability considerations** built into design and architecture

### Technical Expertise
- **Advanced PowerShell** development and best practices
- **Enterprise system integration** across multiple platforms
- **Security-conscious development** with appropriate safeguards
- **Professional documentation** and operational procedures

### Business Value
- **Operational efficiency** through automation of manual processes
- **Risk reduction** via standardised and tested procedures
- **Compliance support** through comprehensive audit trails
- **Cost savings** by extending existing infrastructure capabilities

## Development Timeline

### AD-Sync-Solution
- **June 2019:** Initial development as "interim" solution
- **2019-2024:** Continuous production operation and refinement
- **June 2024:** Replaced by dedicated enterprise IAM platform
- **August 2025:** Sanitised and documented for portfolio presentation

### DevOps-Tools
- **2019-2024:** Various development periods based on operational requirements
- **August 2025:** Enhanced documentation and professional presentation

## Contributing

While this is a personal portfolio repository, the code demonstrates patterns and practices that can be adapted for various enterprise environments. Each solution includes comprehensive documentation to facilitate understanding and adaptation.

## Support and Contact

For questions about implementation approaches or technical discussions:

- **GitHub:** [jameslunardi](https://github.com/jameslunardi)
- **LinkedIn:** [jameslunardi](https://www.linkedin.com/in/jameslunardi/)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**Repository Purpose:** This collection serves as a demonstration of enterprise PowerShell development capabilities, showcasing real-world automation solutions developed for production environments. The code represents practical experience in enterprise system integration, security automation, and operational tooling.