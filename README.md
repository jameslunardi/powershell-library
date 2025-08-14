# PowerShell Library

A collection of PowerShell scripts and automation solutions developed to solve real-world problems in a production environment. Built from a Security Engineering perspective to assist with AD Management, Azure Administration, and Security Operations.

## Disclaimer

These scripts were originally developed for specific enterprise environments. They have been updated and documented from their original form by AI. The updated versions have not been tested. Validate and review the scripts before using them. The author assumes no responsibility for any data loss, security issues, or operational problems resulting from the use of this code.

## Solutions

### 🔄 [AD-Sync-Solution](AD-Sync-Solution/)
**Enterprise Active Directory User Synchronisation System**

Synchronises user accounts between two AD domains. Originally built as an interim solution in 2019, it ran in production for 5 years until replaced by enterprise IAM.
Features cross-domain sync with safety thresholds, quarantine process, Unix attributes support, and comprehensive logging.

### 🛠️ [DevOps-Tools](DevOps-Tools/)
**DevOps Automation and Infrastructure Utilities**

Collection of DevOps automation tools for artifact management and Azure administration.

#### Upload-ToArtifactory.ps1
Enterprise file upload utility for JFrog Artifactory with integrity verification and progress tracking.

#### Export-AzureADApplications.ps1
Azure AD application inventory and audit tool for compliance reporting and security audits.

### 🔐 [Security-Tools](Security-Tools/)
**Security Monitoring and Audit Utilities**
Security tools for monitoring, auditing, and compliance in enterprise environments.

#### Get-UserLogonActivity.ps1
Windows Security Event Log analysis for user logon activity monitoring and inactive account detection.

## Contact
If you want to contact me:
- **LinkedIn:** [jameslunardi](https://www.linkedin.com/in/jameslunardi/)

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
