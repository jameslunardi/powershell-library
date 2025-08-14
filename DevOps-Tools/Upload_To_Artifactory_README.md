# Upload-ToArtifactory.ps1

Uploads files to JFrog Artifactory with integrity verification and progress tracking.

## Overview

Script for uploading files to JFrog Artifactory repositories with built-in data integrity verification using multiple hash algorithms.

## Features

- Multi-hash validation (MD5, SHA1, SHA256)
- Cross-platform compatibility (PowerShell 5.1+)
- Progress tracking with upload speed
- Automatic TLS configuration
- Background job processing for hash calculation
- Confirmation prompts with force override
- WhatIf support for testing

## Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `SourceFile` | String | Yes | Path to the file to upload |
| `DestinationUrl` | String | Yes | Complete Artifactory URL including repository path |
| `ApiKey` | String | Yes | JFrog Artifactory API key |
| `Force` | Switch | No | Bypasses confirmation prompts |

## Usage

```powershell
# Interactive mode (prompts for confirmation)
.\Upload-ToArtifactory.ps1 -SourceFile "C:\Builds\app.zip" -DestinationUrl "https://artifactory.company.com/repo/app.zip" -ApiKey "your-api-key"

# Automated mode (no prompts)
.\Upload-ToArtifactory.ps1 -SourceFile "C:\Builds\app.zip" -DestinationUrl "https://artifactory.company.com/repo/app.zip" -ApiKey $env:ARTIFACTORY_API_KEY -Force
```

## Configuration

Use environment variables for API keys:
```powershell
$env:ARTIFACTORY_API_KEY = "your-api-key"
```

---

**Part of my PowerShell Library:** [DevOps Tools](README.md) | [Main Repository](../README.md) to explore other solutions and tools.
