# =================================================================
# Docker Stack Prepare Script
# Creates deployment ZIP with Cypher scripts
# =================================================================

param(
    [string]$OutputPath = "",
    [string]$ZipName = "",
    [switch]$Force = $false,
    [switch]$Offline = $false
)

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "Docker Stack Prepare Script" -ForegroundColor Cyan
Write-Host "Creates deployment ZIP with Cypher scripts" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

# Get current directory (should be docs/installation/docker)
$CurrentDir = Get-Location
Write-Host "Current directory: $CurrentDir" -ForegroundColor White

# Validate we're in the correct directory
if (-not (Test-Path "src") -or -not (Test-Path "management")) {
    Write-Host "Error: This script must be run from the docs/installation/docker directory!" -ForegroundColor Red
    Write-Host "Expected to find 'src' folder and 'management' folder." -ForegroundColor Yellow
    exit 1
}

# Set default output path if not provided
if (-not $OutputPath) {
    $OutputPath = Join-Path $CurrentDir "dist"
}

# Create output directory if it doesn't exist
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Force -Path $OutputPath | Out-Null
    Write-Host "Created output directory: $OutputPath" -ForegroundColor Green
}

# Set default zip name if not provided
if (-not $ZipName) {
    $Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $ZipName = "docker-stack-$Timestamp.zip"
}

# Ensure .zip extension
if (-not $ZipName.EndsWith(".zip")) {
    $ZipName += ".zip"
}

$ZipPath = Join-Path $OutputPath $ZipName

# Check if zip already exists
if ((Test-Path $ZipPath) -and -not $Force) {
    Write-Host "ZIP file already exists: $ZipPath" -ForegroundColor Red
    Write-Host "Use -Force to overwrite existing file." -ForegroundColor Yellow
    exit 1
}

Write-Host "Preparing Docker stack deployment..." -ForegroundColor White
Write-Host "Output ZIP: $ZipPath" -ForegroundColor White

# Create temporary working directory
$TempDir = Join-Path $env:TEMP "docker-stack-prep-$(Get-Random)"
New-Item -ItemType Directory -Force -Path $TempDir | Out-Null
Write-Host "Working directory: $TempDir" -ForegroundColor Gray

try {
    # Copy source directories
    Write-Host ""
    Write-Host "Copying service directories..." -ForegroundColor White
    Write-Host "==============================" -ForegroundColor Gray
    
    $Services = @("neo4j", "milvus", "mqtt")
    foreach ($Service in $Services) {
        $SourcePath = Join-Path "src" $Service
        $DestPath = Join-Path $TempDir $Service
        
        if (Test-Path $SourcePath) {
            Copy-Item -Path $SourcePath -Destination $DestPath -Recurse -Force
            Write-Host "Copied $Service service files" -ForegroundColor Green
        } else {
            Write-Host "Warning: $Service source directory not found: $SourcePath" -ForegroundColor Yellow
        }
    }
    
    # Copy Cypher scripts to Neo4j updates folder
    Write-Host ""
    Write-Host "Processing Cypher scripts..." -ForegroundColor White
    Write-Host "============================" -ForegroundColor Gray
    
    $CypherSourceDir = Join-Path $CurrentDir ".."
    $Neo4jUpdatesDir = Join-Path $TempDir "neo4j\updates"
    
    # Find all .cypher files in the installation directory
    $CypherFiles = Get-ChildItem -Path $CypherSourceDir -Filter "*.cypher" -File
    
    if ($CypherFiles.Count -gt 0) {
        Write-Host "Found $($CypherFiles.Count) Cypher script(s):" -ForegroundColor White
        
        foreach ($CypherFile in $CypherFiles) {
            $DestFile = Join-Path $Neo4jUpdatesDir $CypherFile.Name
            Copy-Item -Path $CypherFile.FullName -Destination $DestFile -Force
            Write-Host "  - $($CypherFile.Name)" -ForegroundColor Green
        }
        
        Write-Host "Cypher scripts copied to neo4j/updates/ directory" -ForegroundColor Green
    } else {
        Write-Host "No Cypher scripts found in: $CypherSourceDir" -ForegroundColor Yellow
        Write-Host "Neo4j will start without additional scripts" -ForegroundColor Gray
    }
    
    # Copy the CA certificate installation script
    Write-Host ""
    Write-Host "Adding CA certificate installer..." -ForegroundColor White
    Write-Host "==================================" -ForegroundColor Gray
    
    $CACertInstallerSource = Join-Path $CurrentDir "management\install-ca-certificates.ps1"
    $CACertInstallerDest = Join-Path $TempDir "install-ca-certificates.ps1"
    
    if (Test-Path $CACertInstallerSource) {
        Copy-Item -Path $CACertInstallerSource -Destination $CACertInstallerDest -Force
        Write-Host "Added install-ca-certificates.ps1" -ForegroundColor Green
    } else {
        Write-Host "Warning: CA certificate installer not found: $CACertInstallerSource" -ForegroundColor Yellow
    }
    
    # Skip copying the main installer script (excluded from ZIP)
    Write-Host ""
    Write-Host "Skipping main installer script..." -ForegroundColor White
    Write-Host "=================================" -ForegroundColor Gray
    Write-Host "docker-stack-installer.ps1 excluded from ZIP package" -ForegroundColor Gray
    
    # Create README file for the deployment
    Write-Host ""
    Write-Host "Creating deployment README..." -ForegroundColor White
    Write-Host "============================" -ForegroundColor Gray
    
    $ReadmeContent = @"
# Docker Stack Deployment

This ZIP file contains a complete Docker stack deployment for:
- **Neo4j** - Graph database
- **Milvus** - Vector database  
- **MQTT** - Message broker

## Quick Start

1. **Extract** this ZIP file to your desired installation directory
2. **Copy** the ``docker-stack-installer.ps1`` script to the same directory
3. **Run** the installer: ``.\docker-stack-installer.ps1``
4. **Follow** the interactive prompts to configure each service

## What's Included

### Services
- **neo4j/** - Neo4j graph database with Cypher scripts
- **milvus/** - Milvus vector database with configuration
- **mqtt/** - MQTT message broker with SSL support

### Installation
- **Installer script not included** - Copy ``docker-stack-installer.ps1`` separately

### Features
- Interactive configuration for all services
- SSL/TLS support for secure connections
- Automatic password generation
- Comprehensive management scripts
- Backup and restore capabilities

## Requirements

- **Docker Desktop** - Must be installed and running
- **PowerShell 5.0+** - For running installation scripts
- **Windows 10/11** - Tested on Windows environments

## Service Access (after installation)

### Neo4j
- Browser UI: http://localhost:7474
- Bolt Protocol: bolt://localhost:7687
- HTTPS (if SSL enabled): https://localhost:7473

### Milvus  
- gRPC API: localhost:19530
- HTTP API: localhost:9091
- MinIO Console: http://localhost:9001

### MQTT
- Broker: localhost:1883
- WebSocket: ws://localhost:9002
- SSL (if enabled): localhost:8883

## Management

Each service includes management scripts in their respective ``management/`` folders:
- ``install.ps1`` - Service installation and configuration
- ``backup.ps1`` - Create service backups
- ``restore.ps1`` - Restore from backups
- ``manage-ssl.ps1`` - SSL certificate management (Neo4j/Milvus/MQTT)
- ``manage-users.ps1`` - User management (MQTT)

## Support

For issues or questions, refer to the documentation in each service directory.

---
Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
"@
    
    $ReadmePath = Join-Path $TempDir "README.md"
    $ReadmeContent | Out-File -FilePath $ReadmePath -Encoding UTF8
    Write-Host "Created README.md with deployment instructions" -ForegroundColor Green
    
    # Create the ZIP file
    Write-Host ""
    Write-Host "Creating ZIP file..." -ForegroundColor White
    Write-Host "===================" -ForegroundColor Gray
    
    # Remove existing zip if Force is specified
    if ((Test-Path $ZipPath) -and $Force) {
        Remove-Item -Path $ZipPath -Force
        Write-Host "Removed existing ZIP file" -ForegroundColor Yellow
    }
    
    # Create ZIP using .NET compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory($TempDir, $ZipPath)
    
    Write-Host "ZIP file created successfully!" -ForegroundColor Green
    Write-Host "Location: $ZipPath" -ForegroundColor White
    
    # Get ZIP file size
    $ZipInfo = Get-Item $ZipPath
    $ZipSizeMB = [math]::Round($ZipInfo.Length / 1MB, 2)
    Write-Host "Size: $ZipSizeMB MB" -ForegroundColor Gray
    
    # Show contents summary
    Write-Host ""
    Write-Host "ZIP Contents Summary:" -ForegroundColor White
    Write-Host "====================" -ForegroundColor Gray
    
    $ZipContents = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
    $ServiceCounts = @{}
    $TotalFiles = 0
    
    foreach ($Entry in $ZipContents.Entries) {
        $TotalFiles++
        $PathParts = $Entry.FullName -split '/'
        if ($PathParts.Length -gt 0) {
            $ServiceName = $PathParts[0]
            if ($ServiceCounts.ContainsKey($ServiceName)) {
                $ServiceCounts[$ServiceName]++
            } else {
                $ServiceCounts[$ServiceName] = 1
            }
        }
    }
    $ZipContents.Dispose()
    
    Write-Host "Total files: $TotalFiles" -ForegroundColor White
    foreach ($Service in $ServiceCounts.Keys | Sort-Object) {
        Write-Host "  $Service/: $($ServiceCounts[$Service]) files" -ForegroundColor Gray
    }
    
    # Handle offline deployment if requested
    if ($Offline) {
        Write-Host ""
        Write-Host "==================================================================" -ForegroundColor Cyan
        Write-Host "Offline Deployment Preparation" -ForegroundColor Cyan
        Write-Host "==================================================================" -ForegroundColor Cyan
        
        # Check for Docker
        Write-Host ""
        Write-Host "Checking for Docker..." -ForegroundColor White
        $DockerAvailable = $false
        try {
            $dockerVersion = docker version 2>&1
            if ($LASTEXITCODE -eq 0) {
                $DockerAvailable = $true
                Write-Host "  Docker is available and running" -ForegroundColor Green
            }
        } catch {
            Write-Host "  Docker is not available" -ForegroundColor Red
        }
        
        if (-not $DockerAvailable) {
            Write-Host ""
            Write-Host "==================================================================" -ForegroundColor Red
            Write-Host "ERROR: Docker is required for offline package creation!" -ForegroundColor Red
            Write-Host "==================================================================" -ForegroundColor Red
            Write-Host ""
            Write-Host "To create an offline package with Docker images, you need:" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Docker Desktop or Docker CLI" -ForegroundColor White
            Write-Host "  Install from: https://www.docker.com/products/docker-desktop" -ForegroundColor Gray
            Write-Host ""
            Write-Host "After installing Docker:" -ForegroundColor Yellow
            Write-Host "  1. Start Docker and wait for it to be ready" -ForegroundColor White
            Write-Host "  2. Run this script again with -Offline flag" -ForegroundColor White
            Write-Host ""
            Write-Host "Alternative: Create the offline package on a different machine" -ForegroundColor Gray
            Write-Host "that has Docker installed, then transfer the files." -ForegroundColor Gray
            Write-Host ""
            exit 1
        }
        
        # Define required Docker images with fallback versions
        $DockerImages = @(
            @{
                Primary = "neo4j:2025.08-community"
                Fallbacks = @("neo4j:5.25-community", "neo4j:5.24-community", "neo4j:latest")
                Description = "Neo4j Graph Database"
            },
            @{
                Primary = "python:3.11-slim"
                Fallbacks = @("python:3.11", "python:3.10-slim", "python:3.10")
                Description = "Python Runtime"
            },
            @{
                Primary = "alpine/openssl:latest"
                Fallbacks = @("alpine:latest")
                Description = "OpenSSL Tools"
            },
            @{
                Primary = "alpine:latest"
                Fallbacks = @("alpine:3.19", "alpine:3.18")
                Description = "Alpine Linux Base"
            },
            @{
                Primary = "eclipse-mosquitto:2.0.22"
                Fallbacks = @("eclipse-mosquitto:2.0", "eclipse-mosquitto:latest")
                Description = "MQTT Broker"
            },
            @{
                Primary = "milvusdb/milvus:v2.6.3"
                Fallbacks = @("milvusdb/milvus:v2.6.2", "milvusdb/milvus:v2.6.1", "milvusdb/milvus:v2.6.0", "milvusdb/milvus:latest")
                Description = "Milvus Vector Database"
            },
            @{
                Primary = "minio/minio:latest"
                Fallbacks = @("minio/minio:RELEASE.2024-10-29T09-49-05Z", "minio/minio:RELEASE.2024-10-13T13-34-11Z")
                Description = "MinIO Object Storage"
            },
            @{
                Primary = "quay.io/coreos/etcd:v3.6.5"
                Fallbacks = @("quay.io/coreos/etcd:v3.6.4", "quay.io/coreos/etcd:v3.6.3", "quay.io/coreos/etcd:latest")
                Description = "etcd Key-Value Store"
            },
            @{
                Primary = "zilliz/attu:v2.6"
                Fallbacks = @("zilliz/attu:v2.5", "zilliz/attu:latest")
                Description = "Attu Milvus Management UI"
            }
        )
        
        Write-Host ""
        Write-Host "Downloading Docker images..." -ForegroundColor White
        Write-Host "============================" -ForegroundColor Gray
        Write-Host "This may take several minutes depending on your internet connection" -ForegroundColor Gray
        Write-Host ""
        
        $SuccessfulDownloads = @()
        $FailedDownloads = @()
        
        # Create temp directory for image downloads
        $ImagesDir = Join-Path $env:TEMP "docker-images-$(Get-Random)"
        New-Item -ItemType Directory -Force -Path $ImagesDir | Out-Null
        
        try {
            # Download using Docker with retry logic and fallback versions
            foreach ($ImageConfig in $DockerImages) {
                $AllImageVersions = @($ImageConfig.Primary) + $ImageConfig.Fallbacks
                $Success = $false
                $SuccessfulImage = $null
                
                Write-Host "Pulling: $($ImageConfig.Description)" -ForegroundColor White
                Write-Host "  Primary: $($ImageConfig.Primary)" -ForegroundColor Gray
                
                foreach ($ImageVersion in $AllImageVersions) {
                    if ($Success) { break }
                    
                    $MaxRetries = 2  # Reduced retries per version since we have fallbacks
                    $RetryCount = 0
                    
                    while ($RetryCount -lt $MaxRetries -and -not $Success) {
                        try {
                            if ($ImageVersion -eq $ImageConfig.Primary) {
                                if ($RetryCount -eq 0) {
                                    Write-Host "  Trying: $ImageVersion" -ForegroundColor White
                                } else {
                                    Write-Host "  Retry $RetryCount/$($MaxRetries-1): $ImageVersion" -ForegroundColor Yellow
                                }
                            } else {
                                if ($RetryCount -eq 0) {
                                    Write-Host "  Fallback: $ImageVersion" -ForegroundColor Cyan
                                } else {
                                    Write-Host "  Retry $RetryCount/$($MaxRetries-1): $ImageVersion" -ForegroundColor Yellow
                                }
                            }
                            
                            # Clear any previous error state
                            $global:LASTEXITCODE = 0
                            
                            # Use Start-Process for better control over output and exit codes
                            $PullProcess = Start-Process -FilePath "docker" `
                                -ArgumentList @("pull", $ImageVersion) `
                                -Wait -PassThru -NoNewWindow -RedirectStandardError $env:TEMP\docker-error.txt
                            
                            if ($PullProcess.ExitCode -eq 0) {
                                Write-Host "  SUCCESS" -ForegroundColor Green
                                $SuccessfulDownloads += $ImageVersion
                                $SuccessfulImage = $ImageVersion
                                $Success = $true
                                
                                # If we used a fallback, note it
                                if ($ImageVersion -ne $ImageConfig.Primary) {
                                    Write-Host "  NOTE: Using fallback version instead of $($ImageConfig.Primary)" -ForegroundColor Yellow
                                }
                            } else {
                                $ErrorOutput = ""
                                if (Test-Path "$env:TEMP\docker-error.txt") {
                                    $ErrorOutput = Get-Content "$env:TEMP\docker-error.txt" -Raw
                                    Remove-Item "$env:TEMP\docker-error.txt" -Force -ErrorAction SilentlyContinue
                                }
                                throw "Docker pull failed with exit code $($PullProcess.ExitCode). Error: $ErrorOutput"
                            }
                        } catch {
                            $RetryCount++
                            if ($RetryCount -lt $MaxRetries) {
                                Write-Host "  FAILED: $($_.Exception.Message -split "`n" | Select-Object -First 1)" -ForegroundColor Red
                                Write-Host "  Waiting 3 seconds before retry..." -ForegroundColor Gray
                                Start-Sleep -Seconds 3
                            } else {
                                Write-Host "  FAILED: $($_.Exception.Message -split "`n" | Select-Object -First 1)" -ForegroundColor Red
                                # Don't add to failed list yet - we might have more fallbacks
                            }
                        }
                    }
                }
                
                # If no version worked, add the primary image to failed list
                if (-not $Success) {
                    Write-Host "  ALL VERSIONS FAILED for $($ImageConfig.Description)" -ForegroundColor Red
                    $FailedDownloads += $ImageConfig.Primary
                }
                
                Write-Host "" # Empty line for readability
            }
            
            # Save images to tar files using Docker
            if ($SuccessfulDownloads.Count -gt 0) {
                Write-Host ""
                Write-Host "Saving images to tar archive..." -ForegroundColor White
                
                $ImagesArchiveName = $ZipName -replace "\.zip$", "-docker-images.tar"
                $ImagesArchivePath = Join-Path $OutputPath $ImagesArchiveName
                
                if ((Test-Path $ImagesArchivePath) -and $Force) {
                    Remove-Item -Path $ImagesArchivePath -Force
                }
                
                # Build argument list properly - combine all into single array
                $SaveArgs = @("save", "-o", $ImagesArchivePath) + $SuccessfulDownloads
                
                $SaveProcess = Start-Process -FilePath "docker" `
                    -ArgumentList $SaveArgs `
                    -Wait -PassThru -NoNewWindow
                
                if ($SaveProcess.ExitCode -eq 0 -and (Test-Path $ImagesArchivePath)) {
                    $ArchiveInfo = Get-Item $ImagesArchivePath
                    $ArchiveSizeGB = [math]::Round($ArchiveInfo.Length / 1GB, 2)
                    Write-Host "  Archive created: $ImagesArchivePath" -ForegroundColor Green
                    Write-Host "  Size: $ArchiveSizeGB GB" -ForegroundColor White
                } else {
                    throw "Docker save failed"
                }
            }
            
        } finally {
            # Clean up temp images directory
            if (Test-Path $ImagesDir) {
                Remove-Item $ImagesDir -Recurse -Force
            }
        }
        
        # Handle failures
        if ($FailedDownloads.Count -gt 0) {
            Write-Host ""
            Write-Host "==================================================================" -ForegroundColor Yellow
            Write-Host "WARNING: Some images failed to download" -ForegroundColor Yellow
            Write-Host "==================================================================" -ForegroundColor Yellow
            Write-Host "Failed images:" -ForegroundColor Red
            foreach ($FailedImage in $FailedDownloads) {
                Write-Host "  - $FailedImage" -ForegroundColor Red
            }
            Write-Host ""
            Write-Host "These images will need to be downloaded during installation." -ForegroundColor Yellow
        }
        
        # Download Docker Desktop installer
        Write-Host ""
        Write-Host "Downloading Docker Desktop installer..." -ForegroundColor White
        Write-Host "=======================================" -ForegroundColor Gray
        
        $DockerDesktopUrl = "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe"
        $DockerInstallerPath = Join-Path $OutputPath "Docker-Desktop-Installer.exe"
        
        if (Test-Path $DockerInstallerPath) {
            $InstallerInfo = Get-Item $DockerInstallerPath
            $InstallerSizeMB = [math]::Round($InstallerInfo.Length / 1MB, 2)
            Write-Host "Docker Desktop installer already exists ($InstallerSizeMB MB)" -ForegroundColor Green
            Write-Host "Skipping download" -ForegroundColor Gray
        } else {
            try {
                Write-Host "Downloading from: $DockerDesktopUrl" -ForegroundColor Gray
                Write-Host "This may take several minutes (500+ MB)..." -ForegroundColor Gray
                
                $ProgressPreference = 'SilentlyContinue'
                Invoke-WebRequest -Uri $DockerDesktopUrl -OutFile $DockerInstallerPath -UseBasicParsing
                $ProgressPreference = 'Continue'
                
                $InstallerInfo = Get-Item $DockerInstallerPath
                $InstallerSizeMB = [math]::Round($InstallerInfo.Length / 1MB, 2)
                Write-Host ""
                Write-Host "Docker Desktop installer downloaded successfully!" -ForegroundColor Green
                Write-Host "  Location: $DockerInstallerPath" -ForegroundColor White
                Write-Host "  Size: $InstallerSizeMB MB" -ForegroundColor White
            } catch {
                Write-Host ""
                Write-Host "WARNING: Failed to download Docker Desktop installer" -ForegroundColor Yellow
                Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host ""
                Write-Host "You can download it manually from:" -ForegroundColor Yellow
                Write-Host "  https://www.docker.com/products/docker-desktop" -ForegroundColor White
            }
        }
        
        # Create offline installation instructions
        Write-Host ""
        Write-Host "Creating offline installation instructions..." -ForegroundColor White
        Write-Host "===========================================" -ForegroundColor Gray
        
        $ImagesArchivePath = Join-Path $OutputPath ($ZipName -replace "\.zip$", "-docker-images.tar")
        $HasImagesArchive = Test-Path $ImagesArchivePath
        $HasDockerInstaller = Test-Path $DockerInstallerPath
        
        $OfflineInstructions = @"
# Offline Docker Stack Deployment

This package was created using **Docker** and contains everything needed for offline deployment.

## Package Contents

1. **$ZipName** - Service configuration files and scripts
"@

        if ($HasImagesArchive) {
            $ArchiveInfo = Get-Item $ImagesArchivePath
            $ArchiveSizeGB = [math]::Round($ArchiveInfo.Length / 1GB, 2)
            $OfflineInstructions += @"

2. **$($ArchiveInfo.Name)** - Pre-downloaded Docker images ($ArchiveSizeGB GB)
   - Contains $($SuccessfulDownloads.Count) Docker images
"@
            if ($FailedDownloads.Count -gt 0) {
                $OfflineInstructions += @"

   - **WARNING**: Missing $($FailedDownloads.Count) images (will download during install):
"@
                foreach ($Failed in $FailedDownloads) {
                    $OfflineInstructions += "`n     - $Failed"
                }
            }
        }

        if ($HasDockerInstaller) {
            $InstallerInfo = Get-Item $DockerInstallerPath
            $InstallerSizeMB = [math]::Round($InstallerInfo.Length / 1MB, 2)
            $OfflineInstructions += @"

3. **Docker-Desktop-Installer.exe** - Docker Desktop installer ($InstallerSizeMB MB)
"@
        }

        $OfflineInstructions += @"

4. **docker-stack-installer.ps1** - Main installation script (copy separately)

## Offline Installation Steps

### Step 1: Install Docker Desktop (if not already installed)

1. Run ``Docker-Desktop-Installer.exe``
2. Follow the installation wizard
3. **Restart your computer** when prompted
4. Start Docker Desktop
5. Wait for Docker to be fully ready (whale icon in system tray should be steady)

### Step 2: Load Docker Images (CRITICAL - DO NOT SKIP)

Before running the installer, load the pre-downloaded images:

``````powershell
# Open PowerShell in the directory containing the .tar file
docker load -i $($ImagesArchivePath | Split-Path -Leaf)
``````

This will load all $($SuccessfulDownloads.Count) Docker images into your local Docker environment.

**Verify images are loaded:**
``````powershell
docker images
``````

You should see all the required images listed.

### Step 3: Run the Installer

1. Copy ``docker-stack-installer.ps1`` to the same directory as the ZIP file
2. Open PowerShell in that directory
3. Run the installer:

``````powershell
.\docker-stack-installer.ps1
``````

4. The installer will automatically extract ``$ZipName`` and configure all services
5. Follow the interactive prompts to configure each service

---
Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Package Type: Offline Deployment
Images Included: $($SuccessfulDownloads.Count)
Missing Images: $($FailedDownloads.Count)
"@
        
        $OfflineInstructionsPath = Join-Path $OutputPath "OFFLINE-INSTALLATION-INSTRUCTIONS.md"
        $OfflineInstructions | Out-File -FilePath $OfflineInstructionsPath -Encoding UTF8
        Write-Host "Created offline installation instructions" -ForegroundColor Green
        Write-Host "Location: $OfflineInstructionsPath" -ForegroundColor White
    }
    
} finally {
    # Clean up temporary directory
    if (Test-Path $TempDir) {
        Remove-Item -Path $TempDir -Recurse -Force
        Write-Host ""
        Write-Host "Cleaned up temporary files" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
if ($Offline) {
    Write-Host "Offline Deployment Package Ready!" -ForegroundColor Cyan
} else {
    Write-Host "Deployment Package Ready!" -ForegroundColor Cyan
}
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "ZIP File: $ZipPath" -ForegroundColor Green
Write-Host "Size: $ZipSizeMB MB" -ForegroundColor White

if ($Offline) {
    Write-Host ""
    Write-Host "Offline Package Contents:" -ForegroundColor Cyan
    Write-Host "========================" -ForegroundColor Gray
    Write-Host "1. Service configuration ZIP: $ZipName" -ForegroundColor White
    
    $ImagesArchivePath = Join-Path $OutputPath ($ZipName -replace "\.zip$", "-docker-images.tar")
    if (Test-Path $ImagesArchivePath) {
        $ImagesArchiveInfo = Get-Item $ImagesArchivePath
        $ImagesArchiveSizeGB = [math]::Round($ImagesArchiveInfo.Length / 1GB, 2)
        Write-Host "2. Docker images archive: $($ImagesArchiveInfo.Name) ($ImagesArchiveSizeGB GB)" -ForegroundColor White
    }
    
    $DockerInstallerPath = Join-Path $OutputPath "Docker-Desktop-Installer.exe"
    if (Test-Path $DockerInstallerPath) {
        $DockerInstallerInfo = Get-Item $DockerInstallerPath
        $DockerInstallerSizeMB = [math]::Round($DockerInstallerInfo.Length / 1MB, 2)
        Write-Host "3. Docker Desktop installer: Docker-Desktop-Installer.exe ($DockerInstallerSizeMB MB)" -ForegroundColor White
    }
    
    Write-Host "4. Installation script: docker-stack-installer.ps1 (copy separately)" -ForegroundColor White
    Write-Host "5. Offline instructions: OFFLINE-INSTALLATION-INSTRUCTIONS.md" -ForegroundColor White
    
    Write-Host ""
    Write-Host "CRITICAL: Offline Installation Steps:" -ForegroundColor Cyan
    Write-Host "1. Copy ALL files to target machine" -ForegroundColor White
    Write-Host "2. Install Docker Desktop if needed" -ForegroundColor White
    Write-Host "3. LOAD images FIRST: docker load -i [images-archive].tar" -ForegroundColor Yellow
    Write-Host "4. Extract services ZIP" -ForegroundColor White
    Write-Host "5. Run installer: .\docker-stack-installer.ps1" -ForegroundColor White
    Write-Host ""
    Write-Host "Read OFFLINE-INSTALLATION-INSTRUCTIONS.md for detailed steps!" -ForegroundColor Yellow
} else {
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Cyan
    Write-Host "1. Copy the ZIP file to your target machine" -ForegroundColor White
    Write-Host "2. Copy management\docker-stack-installer.ps1 to your target machine" -ForegroundColor White
    Write-Host "3. Extract the ZIP file to your desired location" -ForegroundColor White
    Write-Host "4. Run: .\docker-stack-installer.ps1" -ForegroundColor White
    Write-Host "5. Follow the interactive installation prompts" -ForegroundColor White
}

Write-Host ""
Write-Host "The installer will configure all services with the included Cypher scripts!" -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Cyan
