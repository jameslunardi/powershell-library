<#
.SYNOPSIS
    Uploads files to JFrog Artifactory with comprehensive checksum validation

.DESCRIPTION
    Uploads a specified file to JFrog Artifactory repository with MD5, SHA1, and SHA256 
    checksum headers for integrity verification. Supports both PowerShell 6+ and PowerShell 5.1
    with automatic fallback for older systems like Windows Server 2012 R2.
    
    The script calculates file hashes locally and includes them in the upload headers to ensure
    data integrity during transfer. Progress information is displayed during the upload process.

.PARAMETER SourceFile
    Path to the source file to upload. File must exist and be accessible.

.PARAMETER DestinationUrl
    Complete Artifactory URL for the destination file, including repository path.
    Must be a valid HTTPS URL.

.PARAMETER ApiKey
    JFrog Artifactory API key for authentication. Can be obtained from your Artifactory user profile.

.PARAMETER Force
    Bypasses confirmation prompts for file uploads.

.EXAMPLE
    Upload-ToArtifactory -SourceFile "C:\Files\application.zip" -DestinationUrl "https://artifactory.company.com/artifactory/releases/app/v1.0/application.zip" -ApiKey "your-api-key-here"
    Uploads the specified file to Artifactory with checksum validation

.EXAMPLE
    Upload-ToArtifactory -SourceFile "C:\ISOs\windows.iso" -DestinationUrl "https://artifactory.company.com/artifactory/iso-repo/windows/windows.iso" -ApiKey $env:ARTIFACTORY_API_KEY -Force
    Uploads using environment variable for API key and bypasses confirmation

.NOTES
    Author: James Lunardi
    Version: 1.0
    
    Requirements:
    - PowerShell 5.1+ (PowerShell 6+ recommended)
    - Valid JFrog Artifactory API key
    - Network access to Artifactory instance
    - Read access to source file
    
    For Windows Server 2012 R2 compatibility, the script automatically handles TLS 1.2 configuration.
    
.LINK
    https://github.com/jameslunardi/powershell-library
    https://www.linkedin.com/in/jameslunardi/
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateScript({
        if (-not (Test-Path $_)) {
            throw "Source file does not exist: $_"
        }
        if ((Get-Item $_).PSIsContainer) {
            throw "Source must be a file, not a directory: $_"
        }
        return $true
    })]
    [string]$SourceFile,
    
    [Parameter(Mandatory = $true, Position = 1)]
    [ValidatePattern('^https://.*')]
    [string]$DestinationUrl,
    
    [Parameter(Mandatory = $true, Position = 2)]
    [ValidateNotNullOrEmpty()]
    [string]$ApiKey,
    
    [Parameter(Mandatory = $false)]
    [switch]$Force
)

#region Functions
# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

function Write-ProgressInfo {
    param(
        [string]$Message,
        [string]$Color = "Cyan"
    )
    Write-Host $Message -ForegroundColor $Color
    Write-Verbose $Message
}

function Get-FileSizeString {
    param([long]$SizeBytes)
    
    if ($SizeBytes -gt 1GB) {
        return "{0:N2} GB" -f ($SizeBytes / 1GB)
    }
    elseif ($SizeBytes -gt 1MB) {
        return "{0:N2} MB" -f ($SizeBytes / 1MB)
    }
    elseif ($SizeBytes -gt 1KB) {
        return "{0:N2} KB" -f ($SizeBytes / 1KB)
    }
    else {
        return "$SizeBytes bytes"
    }
}

#endregion Functions

#region Initialization
# =============================================================================
# SCRIPT INITIALIZATION AND VALIDATION
# =============================================================================

Write-ProgressInfo "Artifactory File Upload Utility" "Green"
Write-ProgressInfo "=================================" "Green"

# Get file information
try {
    $FileInfo = Get-Item $SourceFile -ErrorAction Stop
    $FileName = $FileInfo.Name
    $FileSize = $FileInfo.Length
    $FileSizeFormatted = Get-FileSizeString $FileSize
    
    Write-ProgressInfo "`nFile Information:"
    Write-Host "  Source: $SourceFile" -ForegroundColor White
    Write-Host "  Name: $FileName" -ForegroundColor White
    Write-Host "  Size: $FileSizeFormatted" -ForegroundColor White
    Write-Host "  Destination: $DestinationUrl" -ForegroundColor White
}
catch {
    Write-Error "Failed to access source file: $($_.Exception.Message)"
    exit 1
}

# Confirmation prompt (unless -Force is used)
if (-not $Force) {
    Write-Host "`nProceed with upload? [Y/N]: " -ForegroundColor Yellow -NoNewline
    $confirmation = Read-Host
    if ($confirmation -notin @('Y', 'y', 'Yes', 'yes')) {
        Write-Host "Upload cancelled by user." -ForegroundColor Yellow
        exit 0
    }
}

#endregion Initialization

#region Hash Calculation
# =============================================================================
# CALCULATE FILE HASHES FOR INTEGRITY VERIFICATION
# =============================================================================

Write-ProgressInfo "`nCalculating file hashes for integrity verification..."

try {
    # Calculate all three hash types in parallel using background jobs for better performance
    Write-Verbose "Starting hash calculations..."
    
    $HashJobs = @{
        MD5    = Start-Job -ScriptBlock { param($Path) (Get-FileHash -Path $Path -Algorithm MD5).Hash.ToLower() } -ArgumentList $SourceFile
        SHA1   = Start-Job -ScriptBlock { param($Path) (Get-FileHash -Path $Path -Algorithm SHA1).Hash.ToLower() } -ArgumentList $SourceFile
        SHA256 = Start-Job -ScriptBlock { param($Path) (Get-FileHash -Path $Path -Algorithm SHA256).Hash.ToLower() } -ArgumentList $SourceFile
    }
    
    # Wait for all jobs to complete and collect results
    $Hashes = @{}
    foreach ($Algorithm in $HashJobs.Keys) {
        Write-Host "  Calculating $Algorithm hash..." -ForegroundColor Gray
        $Hashes[$Algorithm] = Receive-Job -Job $HashJobs[$Algorithm] -Wait
        Remove-Job -Job $HashJobs[$Algorithm]
    }
    
    Write-ProgressInfo "Hash calculation completed successfully:" "Green"
    Write-Host "  MD5:    $($Hashes.MD5)" -ForegroundColor Gray
    Write-Host "  SHA1:   $($Hashes.SHA1)" -ForegroundColor Gray
    Write-Host "  SHA256: $($Hashes.SHA256)" -ForegroundColor Gray
}
catch {
    Write-Error "Failed to calculate file hashes: $($_.Exception.Message)"
    exit 1
}

#endregion Hash Calculation

#region TLS Configuration
# =============================================================================
# CONFIGURE TLS FOR OLDER POWERSHELL VERSIONS
# =============================================================================

# Handle TLS 1.2 for older PowerShell versions (Windows Server 2012 R2 compatibility)
if ($PSVersionTable.PSVersion.Major -lt 6) {
    Write-Verbose "PowerShell version $($PSVersionTable.PSVersion) detected - configuring TLS 1.2"
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Write-Verbose "TLS 1.2 configured successfully"
    }
    catch {
        Write-Warning "Failed to configure TLS 1.2: $($_.Exception.Message)"
    }
}

#endregion TLS Configuration

#region Upload Preparation
# =============================================================================
# PREPARE UPLOAD HEADERS AND PARAMETERS
# =============================================================================

Write-ProgressInfo "`nPreparing upload to Artifactory..."

# Prepare headers with checksums and authentication
$Headers = @{
    "X-Checksum-Md5"    = $Hashes.MD5
    "X-Checksum-Sha1"   = $Hashes.SHA1
    "X-Checksum-Sha256" = $Hashes.SHA256
    "X-JFrog-Art-Api"   = $ApiKey
    "SendChunked"       = $true
}

# Prepare parameters for Invoke-WebRequest
$UploadParams = @{
    Uri     = $DestinationUrl
    Method  = 'PUT'
    Headers = $Headers
    InFile  = $SourceFile
    Verbose = $VerbosePreference -eq 'Continue'
}

# Add SSL protocol parameter for PowerShell 6+
if ($PSVersionTable.PSVersion.Major -ge 6) {
    $UploadParams['SslProtocol'] = 'Tls12'
}

Write-Verbose "Upload parameters configured:"
Write-Verbose "  URI: $DestinationUrl"
Write-Verbose "  Method: PUT"
Write-Verbose "  InFile: $SourceFile"
Write-Verbose "  Headers configured with checksums and API key"

#endregion Upload Preparation

#region File Upload
# =============================================================================
# EXECUTE FILE UPLOAD TO ARTIFACTORY
# =============================================================================

Write-ProgressInfo "`nUploading file to Artifactory..."
Write-Host "  This may take some time for large files..." -ForegroundColor Gray

try {
    $UploadStartTime = Get-Date
    
    if ($PSCmdlet.ShouldProcess($DestinationUrl, "Upload file $FileName")) {
        $Response = Invoke-WebRequest @UploadParams
        $UploadEndTime = Get-Date
        $UploadDuration = $UploadEndTime - $UploadStartTime
        
        # Check response status
        if ($Response.StatusCode -eq 201) {
            Write-ProgressInfo "`nUpload completed successfully!" "Green"
            Write-Host "  Status: $($Response.StatusCode) - Created" -ForegroundColor Green
            Write-Host "  Duration: $($UploadDuration.TotalSeconds.ToString('F2')) seconds" -ForegroundColor White
            Write-Host "  Average Speed: $(Get-FileSizeString ($FileSize / $UploadDuration.TotalSeconds))/sec" -ForegroundColor White
            
            # Display any response headers of interest
            if ($Response.Headers.ContainsKey('X-Checksum-Sha256')) {
                Write-Host "  Server SHA256: $($Response.Headers['X-Checksum-Sha256'])" -ForegroundColor Gray
                Write-Verbose "Server checksum verification available"
            }
        }
        else {
            Write-Warning "Upload completed with unexpected status code: $($Response.StatusCode)"
            Write-Host "Response: $($Response.Content)" -ForegroundColor Yellow
        }
    }
}
catch {
    $UploadEndTime = Get-Date
    $UploadDuration = $UploadEndTime - $UploadStartTime
    
    Write-Error "Upload failed after $($UploadDuration.TotalSeconds.ToString('F2')) seconds"
    Write-Error "Error details: $($_.Exception.Message)"
    
    # Provide troubleshooting information
    Write-Host "`nTroubleshooting Information:" -ForegroundColor Yellow
    Write-Host "  - Verify API key is valid and has upload permissions" -ForegroundColor Gray
    Write-Host "  - Check network connectivity to Artifactory server" -ForegroundColor Gray
    Write-Host "  - Ensure destination repository exists and is accessible" -ForegroundColor Gray
    Write-Host "  - Verify file is not locked or in use by another process" -ForegroundColor Gray
    
    exit 1
}

#endregion File Upload

#region Completion
# =============================================================================
# SCRIPT COMPLETION AND SUMMARY
# =============================================================================

Write-ProgressInfo "`n=================================" "Green"
Write-ProgressInfo "Upload Summary:" "Green"
Write-Host "  File: $FileName" -ForegroundColor White
Write-Host "  Size: $FileSizeFormatted" -ForegroundColor White
Write-Host "  Destination: $DestinationUrl" -ForegroundColor White
Write-Host "  Status: Successfully uploaded" -ForegroundColor Green
Write-ProgressInfo "=================================" "Green"

Write-Verbose "Script execution completed successfully"

#endregion Completion