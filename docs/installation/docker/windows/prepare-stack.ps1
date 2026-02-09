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

Write-Host "Docker Stack Prepare Script" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

# Get current directory (should be docs/installation/docker/windows)
$CurrentDir = Get-Location
$ParentDir = Split-Path $CurrentDir -Parent

# Validate we're in the correct directory
if (-not (Test-Path "$ParentDir\src")) {
    Write-Host "Error: This script must be run from the docs/installation/docker/windows directory!" -ForegroundColor Red
    exit 1
}

# Set default output path if not provided
if (-not $OutputPath) {
    $OutputPath = Join-Path $CurrentDir "dist"
}

# Create output directory if it doesn't exist
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Force -Path $OutputPath | Out-Null
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

Write-Host "Output: $ZipPath" -ForegroundColor White

# Create temporary working directory
$TempDir = Join-Path $env:TEMP "docker-stack-prep-$(Get-Random)"
New-Item -ItemType Directory -Force -Path $TempDir | Out-Null

try {
    # Copy source directories
    Write-Host "Copying services..." -ForegroundColor White
    
    $Services = @("neo4j", "milvus", "mqtt", "timescaledb")
    foreach ($Service in $Services) {
        $SourcePath = Join-Path "$ParentDir\src" $Service
        $DestPath = Join-Path $TempDir $Service
        
        if (Test-Path $SourcePath) {
            Copy-Item -Path $SourcePath -Destination $DestPath -Recurse -Force
        } else {
            Write-Host "Warning: $Service not found" -ForegroundColor Yellow
        }
    }
    
    # Copy Cypher scripts to Neo4j updates folder
    Write-Host "Processing Cypher scripts..." -ForegroundColor White
    
    $CypherSourceDir = Join-Path $ParentDir ".."
    $Neo4jUpdatesDir = Join-Path $TempDir "neo4j\updates"
    
    # Create the updates directory if it doesn't exist
    if (-not (Test-Path $Neo4jUpdatesDir)) {
        New-Item -ItemType Directory -Force -Path $Neo4jUpdatesDir | Out-Null
    }
    
    # Find all .cypher files in the installation directory
    $CypherFiles = Get-ChildItem -Path $CypherSourceDir -Filter "*.cypher" -File
    
    if ($CypherFiles.Count -gt 0) {
        foreach ($CypherFile in $CypherFiles) {
            $DestFile = Join-Path $Neo4jUpdatesDir $CypherFile.Name
            Copy-Item -Path $CypherFile.FullName -Destination $DestFile -Force
        }
        Write-Host "  Added $($CypherFiles.Count) Cypher script(s)" -ForegroundColor Green
    } else {
        Write-Host "  No Cypher scripts found" -ForegroundColor Yellow
    }
    
    # Download Python packages for Neo4j watcher (for airgapped installations)
    Write-Host "Downloading Python packages for Neo4j watcher..." -ForegroundColor White
    $Neo4jPackagesDir = Join-Path $TempDir "neo4j\neo4j-packages"
    New-Item -ItemType Directory -Force -Path $Neo4jPackagesDir | Out-Null
    
    try {
        # Check if pip is available
        $PipAvailable = $false
        try {
            pip --version | Out-Null
            $PipAvailable = $true
        } catch {
            Write-Host "  pip not found, skipping Python package download" -ForegroundColor Yellow
        }
        
        if ($PipAvailable) {
            # Download neo4j Python driver and its dependencies
            pip download neo4j -d $Neo4jPackagesDir 2>&1 | Out-Null
            
            if ($LASTEXITCODE -eq 0) {
                $PackageCount = (Get-ChildItem -Path $Neo4jPackagesDir -Filter "*.whl").Count
                Write-Host "  Downloaded $PackageCount Python package(s) for offline installation" -ForegroundColor Green
                
                # Create README for the packages
                $PackagesReadme = @"
# Neo4j Python Packages

This directory contains Python packages required for the Neo4j watcher service.
These packages enable the watcher to work in airgapped/offline environments.

## Contents
- neo4j Python driver
- All dependencies required by the neo4j driver

## Usage
These packages are automatically used by the watcher when it starts.
The watcher will install from these local packages instead of downloading from PyPI.

## Updating Packages
To update the packages, run on a machine with internet access:
``````powershell
pip download neo4j -d neo4j-packages --upgrade
``````

Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
"@
                $PackagesReadme | Out-File -FilePath (Join-Path $Neo4jPackagesDir "README.md") -Encoding UTF8
            } else {
                Write-Host "  Failed to download Python packages" -ForegroundColor Yellow
                Write-Host "  Watcher will attempt online installation if deployed with internet access" -ForegroundColor Gray
            }
        }
    } catch {
        Write-Host "  Error downloading Python packages: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "  Watcher will attempt online installation if deployed with internet access" -ForegroundColor Gray
    }
    
    # Copy management scripts
    Write-Host "Copying management scripts..." -ForegroundColor White
    
    # Create management folder for supporting scripts
    $ManagementDir = Join-Path $TempDir "management"
    New-Item -ItemType Directory -Force -Path $ManagementDir | Out-Null
    
    # Copy supporting management scripts to management folder
    $ManagementScripts = @(
        "install-ca-certificates.ps1",
        "stop-all-services.ps1"
    )
    
    foreach ($Script in $ManagementScripts) {
        $ScriptSource = Join-Path $CurrentDir "management\$Script"
        $ScriptDest = Join-Path $ManagementDir $Script
        
        if (Test-Path $ScriptSource) {
            Copy-Item -Path $ScriptSource -Destination $ScriptDest -Force
            Write-Host "  Added $Script to management/" -ForegroundColor Green
        } else {
            Write-Host "  Warning: $Script not found at $ScriptSource" -ForegroundColor Yellow
        }
    }
    
    # Note: docker-stack-installer.ps1 is NOT included in ZIP - it should be copied separately
    Write-Host "  Note: docker-stack-installer.ps1 not included in ZIP (copy separately)" -ForegroundColor Gray
    
    # Create README file for the deployment
    $ReadmeContent = @"
# Docker Stack Deployment

This package contains a complete Docker stack deployment for:
- **Neo4j** - Graph database
- **Milvus** - Vector database  
- **MQTT** - Message broker

## Directory Structure

``````
.
├── README.md                          # This file
├── docker-stack-installer.ps1         # Main installer (run this)
├── management/                        # Supporting management scripts
│   ├── install-ca-certificates.ps1   # CA certificate installer
│   └── stop-all-services.ps1         # Stop all services
├── neo4j/                            # Neo4j service
│   ├── docker-compose.yml
│   ├── watcher.py
│   ├── neo4j-packages/               # Python packages for offline
│   └── management/                   # Neo4j management scripts
├── milvus/                           # Milvus service
│   ├── docker-compose.yml
│   └── management/                   # Milvus management scripts
└── mqtt/                             # MQTT service
    ├── docker-compose.yml
    └── management/                   # MQTT management scripts
``````

## Quick Start

1. **Place files** in your desired installation directory:
   - Copy ``docker-stack-installer.ps1`` to the directory
   - Copy the ZIP file to the same directory

2. **Run the installer** (extracts to current directory):
   ``````powershell
   .\docker-stack-installer.ps1
   ``````

3. **Follow** the interactive prompts to configure each service

4. **Access** your services using the credentials provided during installation

**Note:** The installer extracts the ZIP to the current directory and moves the ZIP to an ``archive/`` folder.

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

## Management Scripts

### Stack-Level Management
- **docker-stack-installer.ps1** (root) - Install and configure all services
- **management/install-ca-certificates.ps1** - Install SSL CA certificates to Windows
- **management/stop-all-services.ps1** - Stop all services at once

### Service-Level Management (in each service's management/ folder)
- **install.ps1** - Service installation and configuration
- **backup.ps1** - Create service backups
- **restore.ps1** - Restore from backups
- **manage-ssl.ps1** - SSL certificate management
- **manage-users.ps1** - User management (MQTT only)

## Features

- Interactive configuration for all services
- SSL/TLS support for secure connections
- Automatic password generation
- Comprehensive management scripts
- Backup and restore capabilities
- Airgapped/offline installation support

## Support

For issues or questions, refer to the documentation in each service directory.

---
Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
"@
    
    $ReadmePath = Join-Path $TempDir "README.md"
    $ReadmeContent | Out-File -FilePath $ReadmePath -Encoding UTF8
    
    # Create the ZIP file
    Write-Host "Creating ZIP..." -ForegroundColor White
    
    # Remove existing zip if Force is specified
    if ((Test-Path $ZipPath) -and $Force) {
        Remove-Item -Path $ZipPath -Force
    }
    
    # Create ZIP using .NET compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory($TempDir, $ZipPath)
    
    # Get ZIP file size
    $ZipInfo = Get-Item $ZipPath
    $ZipSizeMB = [math]::Round($ZipInfo.Length / 1MB, 2)
    Write-Host "  Created: $ZipSizeMB MB" -ForegroundColor Green
    
    # Copy docker-stack-installer.ps1 to dist folder
    Write-Host "Copying installer to dist folder..." -ForegroundColor White
    $InstallerSource = Join-Path $CurrentDir "management\docker-stack-installer.ps1"
    $InstallerDest = Join-Path $OutputPath "docker-stack-installer.ps1"
    
    if (Test-Path $InstallerSource) {
        Copy-Item -Path $InstallerSource -Destination $InstallerDest -Force
        Write-Host "  Copied docker-stack-installer.ps1 to dist/" -ForegroundColor Green
    } else {
        Write-Host "  Warning: docker-stack-installer.ps1 not found at $InstallerSource" -ForegroundColor Yellow
    }
    
    # Handle offline deployment if requested
    if ($Offline) {
        Write-Host ""
        Write-Host "Offline Deployment Preparation" -ForegroundColor Cyan
        Write-Host "==================================================================" -ForegroundColor Cyan
        
        # Check for Docker
        Write-Host "Checking Docker..." -ForegroundColor White
        $DockerAvailable = $false
        try {
            docker version 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                $DockerAvailable = $true
                Write-Host "  Docker available" -ForegroundColor Green
            }
        } catch {
            Write-Host "  Docker not available" -ForegroundColor Red
        }
        
        if (-not $DockerAvailable) {
            Write-Host ""
            Write-Host "ERROR: Docker required for offline package creation" -ForegroundColor Red
            Write-Host "Install from: https://www.docker.com/products/docker-desktop" -ForegroundColor Yellow
            exit 1
        }
        
        # Define required Docker images with exact versions from docker-compose files
        # NOTE: alpine/openssl IS included for offline/airgapped installations even though
        # it's only used temporarily for SSL cert generation - without it, SSL setup would
        # require internet access to pull the image
        $DockerImages = @(
            @{
                Primary = "neo4j:2025.08-community"
                Fallbacks = @("neo4j:5.25-community", "neo4j:5.24-community")
                Description = "Neo4j"
            },
            @{
                Primary = "python:3.11-slim"
                Fallbacks = @("python:3.11", "python:3.10-slim")
                Description = "Python"
            },
            @{
                Primary = "alpine/openssl:latest"
                Fallbacks = @()
                Description = "OpenSSL (for SSL cert generation)"
            },
            @{
                Primary = "alpine:latest"
                Fallbacks = @()
                Description = "Alpine (for file operations)"
            },
            @{
                Primary = "eclipse-mosquitto:2.0.22"
                Fallbacks = @("eclipse-mosquitto:2.0.21", "eclipse-mosquitto:2.0")
                Description = "MQTT"
            },
            @{
                Primary = "milvusdb/milvus:v2.6.3"
                Fallbacks = @("milvusdb/milvus:v2.6.2", "milvusdb/milvus:v2.6.1")
                Description = "Milvus"
            },
            @{
                Primary = "minio/minio:latest"
                Fallbacks = @("minio/minio:RELEASE.2024-10-13T13-34-11Z")
                Description = "MinIO"
            },
            @{
                Primary = "quay.io/coreos/etcd:v3.6.5"
                Fallbacks = @("quay.io/coreos/etcd:v3.6.4", "quay.io/coreos/etcd:v3.6.3")
                Description = "etcd"
            },
            @{
                Primary = "zilliz/attu:v2.6"
                Fallbacks = @("zilliz/attu:v2.5")
                Description = "Attu"
            },
            @{
                Primary = "nginx:alpine"
                Fallbacks = @("nginx:stable-alpine")
                Description = "Nginx"
            },
            @{
                Primary = "timescale/timescaledb:latest-pg16"
                Fallbacks = @("timescale/timescaledb:2.18.0-pg16", "timescale/timescaledb:2.17.2-pg16")
                Description = "TimescaleDB"
            },
            @{
                Primary = "dpage/pgadmin4:latest"
                Fallbacks = @("dpage/pgadmin4:8.15", "dpage/pgadmin4:8.14")
                Description = "pgAdmin"
            },
            @{
                Primary = "postgres:16-alpine"
                Fallbacks = @("postgres:16.7-alpine", "postgres:16.6-alpine")
                Description = "PostgreSQL (for backups)"
            }
        )
        
        Write-Host "Downloading Docker images..." -ForegroundColor White
        
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
                
                Write-Host "  $($ImageConfig.Description): $($ImageConfig.Primary)" -ForegroundColor White
                
                foreach ($ImageVersion in $AllImageVersions) {
                    if ($Success) { break }
                    
                    $MaxRetries = 2  # Reduced retries per version since we have fallbacks
                    $RetryCount = 0
                    
                    while ($RetryCount -lt $MaxRetries -and -not $Success) {
                        try {
                            if ($RetryCount -gt 0 -or $ImageVersion -ne $ImageConfig.Primary) {
                                Write-Host "    Retry: $ImageVersion" -ForegroundColor Yellow
                            }
                            
                            # Clear any previous error state
                            $global:LASTEXITCODE = 0
                            
                            # Use Start-Process for better control over output and exit codes
                            $PullProcess = Start-Process -FilePath "docker" `
                                -ArgumentList @("pull", $ImageVersion) `
                                -Wait -PassThru -NoNewWindow -RedirectStandardError $env:TEMP\docker-error.txt
                            
                            if ($PullProcess.ExitCode -eq 0) {
                                $SuccessfulDownloads += $ImageVersion
                                $Success = $true
                                if ($ImageVersion -ne $ImageConfig.Primary) {
                                    Write-Host "    Using fallback: $ImageVersion" -ForegroundColor Cyan
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
                                Start-Sleep -Seconds 3
                            }
                        }
                    }
                }
                
                # If no version worked, add the primary image to failed list
                if (-not $Success) {
                    Write-Host "    FAILED" -ForegroundColor Red
                    $FailedDownloads += $ImageConfig.Primary
                }
            }
            
            # Save images to tar archive using Docker
            if ($SuccessfulDownloads.Count -gt 0) {
                Write-Host "Saving to tar archive..." -ForegroundColor White
                
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
                    Write-Host "  Created: $ArchiveSizeGB GB" -ForegroundColor Green
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
            Write-Host "WARNING: $($FailedDownloads.Count) image(s) failed - will download during install" -ForegroundColor Yellow
        }
        
        # Download Docker Desktop installer
        Write-Host "Downloading Docker Desktop..." -ForegroundColor White
        
        $DockerDesktopUrl = "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe"
        $DockerInstallerPath = Join-Path $OutputPath "Docker-Desktop-Installer.exe"
        
        if (Test-Path $DockerInstallerPath) {
            $InstallerInfo = Get-Item $DockerInstallerPath
            $InstallerSizeMB = [math]::Round($InstallerInfo.Length / 1MB, 2)
            Write-Host "  Already exists: $InstallerSizeMB MB" -ForegroundColor Green
        } else {
            try {
                $ProgressPreference = 'SilentlyContinue'
                Invoke-WebRequest -Uri $DockerDesktopUrl -OutFile $DockerInstallerPath -UseBasicParsing
                $ProgressPreference = 'Continue'
                
                $InstallerInfo = Get-Item $DockerInstallerPath
                $InstallerSizeMB = [math]::Round($InstallerInfo.Length / 1MB, 2)
                Write-Host "  Downloaded: $InstallerSizeMB MB" -ForegroundColor Green
            } catch {
                Write-Host "  Failed - download manually from docker.com" -ForegroundColor Yellow
            }
        }
        
        # Create offline installation instructions
        Write-Host "Creating offline instructions..." -ForegroundColor White
        
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
3. Run the installer (extracts to current directory):

``````powershell
.\docker-stack-installer.ps1
``````

4. The installer will:
   - Extract ``$ZipName`` to the current directory
   - Move the ZIP file to an ``archive/`` folder
   - Configure all services
5. Follow the interactive prompts to configure each service

---
Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Package Type: Offline Deployment
Images Included: $($SuccessfulDownloads.Count)
Missing Images: $($FailedDownloads.Count)
"@
        
        $OfflineInstructionsPath = Join-Path $OutputPath "OFFLINE-INSTALLATION-INSTRUCTIONS.md"
        $OfflineInstructions | Out-File -FilePath $OfflineInstructionsPath -Encoding UTF8
    }
    
} finally {
    # Clean up temporary directory
    if (Test-Path $TempDir) {
        Remove-Item -Path $TempDir -Recurse -Force
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
