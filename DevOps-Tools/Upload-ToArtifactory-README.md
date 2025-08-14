# Upload-ToArtifactory.ps1

Uploads files to JFrog Artifactory with comprehensive integrity verification and enterprise-grade error handling.

## Overview

This script provides a robust solution for uploading files to JFrog Artifactory repositories with built-in data integrity verification using multiple hash algorithms. Originally developed to support automated deployment pipelines and artifact management workflows in enterprise environments.

## Key Features

- **Multi-hash validation** (MD5, SHA1, SHA256) for data integrity
- **Cross-platform compatibility** (PowerShell 5.1+ and 6+)
- **Progress tracking** with upload speed calculation
- **Automatic TLS configuration** for older systems
- **Comprehensive error handling** with troubleshooting guidance
- **Background job processing** for efficient hash calculation
- **Confirmation prompts** with force override option
- **WhatIf support** for testing

## Prerequisites

- **PowerShell 5.1+** (PowerShell 7+ recommended for best performance)
- **JFrog Artifactory instance** with API access
- **Valid API key** with upload permissions to target repositories
- **Network connectivity** to Artifactory server
- **File access permissions** for source files

## Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `SourceFile` | String | Yes | Path to the file to upload. Must exist and be accessible. |
| `DestinationUrl` | String | Yes | Complete Artifactory URL including repository path. Must be HTTPS. |
| `ApiKey` | String | Yes | JFrog Artifactory API key for authentication. |
| `Force` | Switch | No | Bypasses confirmation prompts for automated scenarios. |

## Usage Examples

### Basic Interactive Upload
```powershell
.\Upload-ToArtifactory.ps1 -SourceFile "C:\Builds\application-v1.0.zip" -DestinationUrl "https://artifactory.company.com/artifactory/releases/application-v1.0.zip" -ApiKey "your-api-key-here"
```

### Automated Upload (No Prompts)
```powershell
.\Upload-ToArtifactory.ps1 -SourceFile "C:\ISOs\windows-server.iso" -DestinationUrl "https://artifactory.company.com/artifactory/iso-repo/windows-server.iso" -ApiKey $env:ARTIFACTORY_API_KEY -Force
```

### Test Mode (WhatIf)
```powershell
.\Upload-ToArtifactory.ps1 -SourceFile "test-file.txt" -DestinationUrl "https://artifactory.company.com/test/test-file.txt" -ApiKey "test-key" -WhatIf
```

### Using Environment Variables
```powershell
# Set API key as environment variable
$env:ARTIFACTORY_API_KEY = "your-api-key-here"

# Use in script
.\Upload-ToArtifactory.ps1 -SourceFile "artifact.zip" -DestinationUrl "https://artifactory.company.com/repo/artifact.zip" -ApiKey $env:ARTIFACTORY_API_KEY -Force
```

## Configuration

### API Key Management
For security, avoid hardcoding API keys. Use one of these approaches:

```powershell
# Environment variable (recommended)
$env:ARTIFACTORY_API_KEY = "your-api-key"

# Azure Key Vault (enterprise)
$ApiKey = Get-AzKeyVaultSecret -VaultName "KeyVault" -Name "ArtifactoryKey" -AsPlainText

# Secure string file
$SecureKey = Get-Content "api-key.txt" | ConvertTo-SecureString
$ApiKey = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureKey))
```

### TLS Configuration
The script automatically handles TLS 1.2 configuration for older PowerShell versions (Windows Server 2012 R2 compatibility).

## Integration Examples

### CI/CD Pipeline Integration

**Jenkins Pipeline:**
```groovy
stage('Upload Artifacts') {
    steps {
        powershell '''
            $result = .\Upload-ToArtifactory.ps1 -SourceFile "$env:BUILD_ARTIFACT" -DestinationUrl "$env:ARTIFACTORY_URL" -ApiKey "$env:ARTIFACTORY_KEY" -Force
            if ($LASTEXITCODE -ne 0) { exit 1 }
        '''
    }
}
```

**Azure DevOps YAML:**
```yaml
- task: PowerShell@2
  displayName: 'Upload to Artifactory'
  inputs:
    targetType: 'inline'
    script: |
      .\Upload-ToArtifactory.ps1 -SourceFile "$(Build.ArtifactStagingDirectory)\app.zip" -DestinationUrl "$(ArtifactoryUrl)" -ApiKey "$(ArtifactoryApiKey)" -Force
```

### Batch Upload Script
```powershell
# Upload multiple files
$sourceFiles = Get-ChildItem "C:\Artifacts\*.zip"
$baseUrl = "https://artifactory.company.com/artifactory/releases"

foreach ($file in $sourceFiles) {
    $destinationUrl = "$baseUrl/$($file.Name)"
    
    Write-Host "Uploading $($file.Name)..."
    .\Upload-ToArtifactory.ps1 -SourceFile $file.FullName -DestinationUrl $destinationUrl -ApiKey $env:ARTIFACTORY_KEY -Force
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to upload $($file.Name)"
        break
    }
}
```

### Automated Deployment with Validation
```powershell
# Deploy and validate upload
$uploadResult = .\Upload-ToArtifactory.ps1 -SourceFile "release.zip" -DestinationUrl "https://artifactory.company.com/repo/release.zip" -ApiKey $apiKey -Force

if ($LASTEXITCODE -eq 0) {
    Write-Host "Upload successful - triggering deployment pipeline"
    # Trigger next step in deployment
} else {
    Write-Error "Upload failed - stopping deployment"
    exit 1
}
```

## Performance Features

### Parallel Hash Calculation
The script uses PowerShell background jobs to calculate MD5, SHA1, and SHA256 hashes simultaneously, reducing overall processing time for large files.

### Progress Tracking
Real-time feedback includes:
- File size and upload progress
- Hash calculation status
- Upload speed and duration
- Success/failure status with detailed metrics

### Memory Efficiency
Uses `Invoke-WebRequest` with `-InFile` parameter for efficient streaming of large files without loading entire file into memory.

## Error Handling

### Comprehensive Validation
- **File existence** and accessibility checks
- **URL format** validation (HTTPS required)
- **API key** presence validation
- **Network connectivity** testing

### Detailed Error Messages
When failures occur, the script provides:
- **Specific error details** with root cause analysis
- **Troubleshooting guidance** for common issues
- **Context information** (file size, duration, etc.)
- **Suggested remediation** steps

### Common Error Scenarios

**Authentication Failures:**
```
Upload failed: 401 Unauthorized
Troubleshooting:
- Verify API key is valid and not expired
- Check permissions on target repository
- Ensure API key has appropriate scope
```

**Network Issues:**
```
Upload failed: Unable to connect to remote server
Troubleshooting:
- Test basic connectivity to Artifactory server
- Verify firewall rules allow HTTPS traffic
- Check proxy settings if applicable
```

## Troubleshooting

### Authentication Issues
1. **Verify API key validity:**
   ```powershell
   # Test API key with simple REST call
   $headers = @{"X-JFrog-Art-Api" = "your-api-key"}
   Invoke-RestMethod -Uri "https://artifactory.company.com/artifactory/api/system/ping" -Headers $headers
   ```

2. **Check repository permissions:**
   - Ensure API key has `Deploy/Cache` permissions
   - Verify target repository exists and is accessible
   - Check if repository requires additional authentication

### Network Connectivity
1. **Test basic connectivity:**
   ```powershell
   Test-NetConnection -ComputerName "artifactory.company.com" -Port 443
   ```

2. **Verify TLS/SSL configuration:**
   ```powershell
   [Net.ServicePointManager]::SecurityProtocol
   # Should include Tls12
   ```

### File Access Issues
1. **Check file permissions:**
   ```powershell
   Get-Acl "C:\path\to\file.zip" | Format-List
   ```

2. **Verify file is not locked:**
   ```powershell
   # Check if file is in use
   try { [IO.File]::OpenWrite("C:\path\to\file.zip").Close() }
   catch { Write-Host "File is locked" }
   ```

## Development Notes

**Original Context:** Developed to support enterprise deployment pipelines where reliable artifact uploads with integrity verification were critical for production deployments.

**Enhancement History:** 
- **Initial Version:** Basic upload functionality for CI/CD integration
- **v1.0 Enhancement:** Added comprehensive error handling, progress tracking, and cross-platform compatibility
- **Documentation Update:** December 2024 - Professional presentation for portfolio

**Production Usage:** Used in enterprise environments for:
- Application deployment artifacts
- ISO image distribution
- Release package management
- Automated backup uploads

## Security Considerations

- **API Key Storage:** Never hardcode API keys in scripts
- **Network Security:** Always use HTTPS for uploads
- **File Integrity:** Multiple hash verification ensures data corruption detection
- **Audit Trails:** Comprehensive logging for security compliance
- **Access Control:** Validate upload permissions before execution

## Performance Benchmarks

Typical performance on enterprise networks:

| File Size | Hash Calculation | Upload Time (100Mbps) | Total Time |
|-----------|------------------|----------------------|------------|
| 10 MB     | ~2 seconds       | ~1 second            | ~3 seconds |
| 100 MB    | ~8 seconds       | ~8 seconds           | ~16 seconds |
| 1 GB      | ~45 seconds      | ~80 seconds          | ~125 seconds |
| 5 GB      | ~180 seconds     | ~400 seconds         | ~580 seconds |

*Note: Times vary based on hardware, network conditions, and file types.*

---

**Part of DevOps-Tools Collection:** [Back to DevOps Tools](README.md) | [Main Repository](../README.md)