# =================================================================
# Docker Stack Prepare Script
# Creates deployment ZIP with Cypher scripts
# =================================================================

param(
    [string]$OutputPath = "",
    [string]$ZipName = "",
    [switch]$Force = $false
)

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "Docker Stack Prepare Script" -ForegroundColor Cyan
Write-Host "Creates deployment ZIP with Cypher scripts" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

# Get current directory (should be docs/installation/docker)
$CurrentDir = Get-Location
Write-Host "Current directory: $CurrentDir" -ForegroundColor White

# Validate we're in the correct directory
if (-not (Test-Path "src") -or -not (Test-Path "docker-stack-installer.ps1")) {
    Write-Host "Error: This script must be run from the docs/installation/docker directory!" -ForegroundColor Red
    Write-Host "Expected to find 'src' folder and 'docker-stack-installer.ps1' file." -ForegroundColor Yellow
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
    
    # Skip copying the installer script (excluded from ZIP)
    Write-Host ""
    Write-Host "Skipping installer script..." -ForegroundColor White
    Write-Host "============================" -ForegroundColor Gray
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

Each service includes management scripts in their respective `management/` folders:
- `install.ps1` - Service installation and configuration
- `backup.ps1` - Create service backups
- `restore.ps1` - Restore from backups
- `manage-ssl.ps1` - SSL certificate management (Neo4j/Milvus/MQTT)
- `manage-users.ps1` - User management (MQTT)

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
Write-Host "Deployment Package Ready!" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "ZIP File: $ZipPath" -ForegroundColor Green
Write-Host "Size: $ZipSizeMB MB" -ForegroundColor White
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "1. Copy the ZIP file to your target machine" -ForegroundColor White
Write-Host "2. Copy docker-stack-installer.ps1 to your target machine" -ForegroundColor White
Write-Host "3. Extract the ZIP file to your desired location" -ForegroundColor White
Write-Host "4. Run: .\docker-stack-installer.ps1" -ForegroundColor White
Write-Host "5. Follow the interactive installation prompts" -ForegroundColor White
Write-Host ""
Write-Host "The installer will configure all services with the included Cypher scripts!" -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Cyan
