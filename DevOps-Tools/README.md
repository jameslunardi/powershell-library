# DevOps Tools

A collection of PowerShell scripts and utilities for DevOps operations, including artifact management, deployment automation, and infrastructure tooling.

## Scripts

### Upload-ToArtifactory.ps1
Uploads files to JFrog Artifactory with comprehensive integrity verification (MD5, SHA1, SHA256). Features cross-platform compatibility, progress tracking, and enterprise-grade error handling.

**[📖 Full Documentation](Upload-ToArtifactory-README.md)**

```powershell
# Example usage
.\Upload-ToArtifactory.ps1 -SourceFile "app.zip" -DestinationUrl "https://artifactory.company.com/repo/app.zip" -ApiKey "your-key"
```

---

## General Requirements

- PowerShell 5.1+ (PowerShell 7+ recommended)
- Network connectivity to target systems  
- Appropriate authentication credentials

## Security Notes

- Store API keys securely (environment variables, key vaults)
- Scripts include comprehensive error handling and validation
- All tools designed for enterprise production environments

---

**Part of the PowerShell Library:** Visit the [main repository](../README.md) to explore other automation solutions.