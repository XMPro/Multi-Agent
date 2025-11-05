# =================================================================
# Docker Stack One-Click Installer
# Neo4j, Milvus, and MQTT Services
# =================================================================

param(
    [string]$ZipPath = "",
    [string]$InstallPath = "",
    [switch]$SkipChecks = $false,
    [switch]$EnableSSL = $false,
    [string]$Domain = "localhost",
    [string]$Neo4jPassword = "",
    [string]$MilvusPassword = "",
    [string]$MqttPassword = "",
    [switch]$AutoStart = $false,
    [switch]$InstallCertificates = $false
)

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "Docker Stack One-Click Installer" -ForegroundColor Cyan
Write-Host "Neo4j, Milvus, and MQTT Services" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

# Function to check if a command exists
function Test-Command {
    param([string]$Command)
    try {
        Get-Command $Command -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

# Get zip file path if not provided
if (-not $ZipPath) {
    # First, look for ZIP files in the current directory
    $LocalZipFiles = Get-ChildItem -Path "." -Filter "*.zip" | Sort-Object Name
    
    if ($LocalZipFiles.Count -eq 1) {
        # If exactly one ZIP file found, use it automatically
        $ZipPath = $LocalZipFiles[0].FullName
        Write-Host "Found ZIP file: $($LocalZipFiles[0].Name)" -ForegroundColor Green
    } elseif ($LocalZipFiles.Count -gt 1) {
        # If multiple ZIP files found, let user choose
        Write-Host "Multiple ZIP files found:" -ForegroundColor Yellow
        for ($i = 0; $i -lt $LocalZipFiles.Count; $i++) {
            Write-Host "  [$i] $($LocalZipFiles[$i].Name)" -ForegroundColor White
        }
        
        $Selection = Read-Host "Enter number to select ZIP file (or press Enter to browse)"
        if ($Selection -match '^\d+$' -and [int]$Selection -lt $LocalZipFiles.Count) {
            $ZipPath = $LocalZipFiles[[int]$Selection].FullName
            Write-Host "Selected: $($LocalZipFiles[[int]$Selection].Name)" -ForegroundColor Green
        }
    }
    
    # If no ZIP file found or selected, show file browser
    if (-not $ZipPath) {
        Write-Host "No ZIP file found in current directory. Opening file browser..." -ForegroundColor Yellow
        Add-Type -AssemblyName System.Windows.Forms
        $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
        $OpenFileDialog.Filter = "ZIP files (*.zip)|*.zip|All files (*.*)|*.*"
        $OpenFileDialog.Title = "Select Docker Stack ZIP file"
        
        if ($OpenFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $ZipPath = $OpenFileDialog.FileName
        } else {
            Write-Host "No ZIP file selected. Exiting." -ForegroundColor Red
            exit 1
        }
    }
}

# Validate zip file exists
if (-not (Test-Path $ZipPath)) {
    Write-Host "ZIP file not found: $ZipPath" -ForegroundColor Red
    exit 1
}

Write-Host "Selected ZIP file: $ZipPath" -ForegroundColor White

# Set installation path to current directory if not provided
if (-not $InstallPath) {
    $InstallPath = Get-Location
    Write-Host "Installation path: $InstallPath (current directory)" -ForegroundColor White
} else {
    Write-Host "Installation path: $InstallPath" -ForegroundColor White
}

# Prerequisites check
if (-not $SkipChecks) {
    Write-Host ""
    Write-Host "Checking Prerequisites..." -ForegroundColor White
    Write-Host "=========================" -ForegroundColor Gray
    
    # Check Docker Desktop
    if (Test-Command "docker") {
        try {
            docker version | Out-Null
            Write-Host "Docker Desktop is installed and running" -ForegroundColor Green
        } catch {
            Write-Host "Docker Desktop is installed but not running!" -ForegroundColor Red
            Write-Host "Please start Docker Desktop and try again." -ForegroundColor Yellow
            exit 1
        }
    } else {
        Write-Host "Docker Desktop is not installed!" -ForegroundColor Red
        Write-Host "Please install Docker Desktop from: https://www.docker.com/products/docker-desktop" -ForegroundColor Yellow
        exit 1
    }
    
    # Check Docker Compose
    if (Test-Command "docker-compose") {
        Write-Host "Docker Compose is available" -ForegroundColor Green
    } else {
        Write-Host "Docker Compose is not available!" -ForegroundColor Red
        Write-Host "Please ensure Docker Compose is installed with Docker Desktop." -ForegroundColor Yellow
        exit 1
    }
    
    # Check PowerShell version
    $PSVersion = $PSVersionTable.PSVersion
    if ($PSVersion.Major -ge 5) {
        Write-Host "PowerShell $($PSVersion.Major).$($PSVersion.Minor) is supported" -ForegroundColor Green
    } else {
        Write-Host "PowerShell version may be too old. Recommended: 5.0 or higher" -ForegroundColor Yellow
    }
}

# Extract ZIP file
Write-Host ""
Write-Host "Extracting ZIP file..." -ForegroundColor White
Write-Host "=====================" -ForegroundColor Gray

try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    
    # Check if extraction directory has conflicting files
    $ZipArchive = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
    $ConflictingFiles = @()
    
    foreach ($Entry in $ZipArchive.Entries) {
        $TargetPath = Join-Path $InstallPath $Entry.FullName
        if ((Test-Path $TargetPath) -and -not $Entry.FullName.EndsWith("/")) {
            $ConflictingFiles += $Entry.FullName
        }
    }
    $ZipArchive.Dispose()
    
    if ($ConflictingFiles.Count -gt 0) {
        Write-Host "Found $($ConflictingFiles.Count) conflicting file(s):" -ForegroundColor Yellow
        foreach ($File in $ConflictingFiles | Select-Object -First 5) {
            Write-Host "  - $File" -ForegroundColor Gray
        }
        if ($ConflictingFiles.Count -gt 5) {
            Write-Host "  ... and $($ConflictingFiles.Count - 5) more" -ForegroundColor Gray
        }
        
        $OverwriteChoice = Read-Host "Overwrite existing files? (y/n)"
        if ($OverwriteChoice -ne "Y" -and $OverwriteChoice -ne "y") {
            Write-Host "Extraction cancelled by user" -ForegroundColor Yellow
            exit 1
        }
        
        # Extract with overwrite by extracting to temp directory first
        $TempExtractDir = Join-Path $env:TEMP "docker-stack-extract-$(Get-Random)"
        [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $TempExtractDir)
        
        # Copy files with overwrite
        Write-Host "Extracting with overwrite..." -ForegroundColor Yellow
        Copy-Item -Path "$TempExtractDir\*" -Destination $InstallPath -Recurse -Force
        
        # Clean up temp directory
        Remove-Item -Path $TempExtractDir -Recurse -Force
        Write-Host "ZIP file extracted successfully (with overwrite)" -ForegroundColor Green
    } else {
        # No conflicts, extract normally
        [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $InstallPath)
        Write-Host "ZIP file extracted successfully" -ForegroundColor Green
    }
} catch {
    Write-Host "Failed to extract ZIP file: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Change to installation directory
Set-Location $InstallPath

# Move the ZIP file and tar file (if present) to an archive folder
Write-Host ""
Write-Host "Archiving deployment files..." -ForegroundColor White
$ArchiveDir = Join-Path $InstallPath "archive"
if (-not (Test-Path $ArchiveDir)) {
    New-Item -ItemType Directory -Force -Path $ArchiveDir | Out-Null
}

# Move ZIP file
$ZipFileName = Split-Path $ZipPath -Leaf
$ArchiveZipPath = Join-Path $ArchiveDir $ZipFileName

try {
    Move-Item -Path $ZipPath -Destination $ArchiveZipPath -Force
    Write-Host "ZIP file moved to: archive\$ZipFileName" -ForegroundColor Green
} catch {
    Write-Host "Could not move ZIP file to archive: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "ZIP file remains at: $ZipPath" -ForegroundColor Gray
}

# Move tar file if it exists (for offline deployments)
$ZipDir = Split-Path $ZipPath -Parent
$TarFileName = $ZipFileName -replace "\.zip$", "-docker-images.tar"
$TarPath = Join-Path $ZipDir $TarFileName

if (Test-Path $TarPath) {
    $ArchiveTarPath = Join-Path $ArchiveDir $TarFileName
    try {
        Move-Item -Path $TarPath -Destination $ArchiveTarPath -Force
        Write-Host "Docker images tar moved to: archive\$TarFileName" -ForegroundColor Green
    } catch {
        Write-Host "Could not move tar file to archive: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "Tar file remains at: $TarPath" -ForegroundColor Gray
    }
}

# Verify extracted structure
$ExpectedFolders = @("neo4j", "milvus", "mqtt")
$MissingFolders = @()

foreach ($folder in $ExpectedFolders) {
    if (-not (Test-Path $folder)) {
        $MissingFolders += $folder
    }
}

if ($MissingFolders.Count -gt 0) {
    Write-Host "Missing expected folders: $($MissingFolders -join ', ')" -ForegroundColor Red
    Write-Host "Please ensure the ZIP file contains the correct Docker stack structure." -ForegroundColor Yellow
    exit 1
}

Write-Host "All expected service folders found" -ForegroundColor Green

# Configure services
Write-Host ""
Write-Host "Configuring Services..." -ForegroundColor White
Write-Host "======================" -ForegroundColor Gray

# Track which services configured successfully
$ConfiguredServices = @{}

# Configure Neo4j using the install script
Write-Host ""
Write-Host "Neo4j Configuration:" -ForegroundColor Cyan
Write-Host "===================" -ForegroundColor Gray
Write-Host "Running Neo4j installation script..." -ForegroundColor White

# Build parameters for service install scripts
$Neo4jParams = @{
    Force = $true
}
$MilvusParams = @{
    Force = $true
}
$MqttParams = @{
    Force = $true
}

if ($EnableSSL) {
    $Neo4jParams.EnableSSL = $true
    $MilvusParams.EnableSSL = $true
    $MqttParams.EnableSSL = $true
    
    if ($Domain -ne "localhost") {
        $Neo4jParams.Domain = $Domain
        $MilvusParams.Domain = $Domain
    }
}

if ($Neo4jPassword) {
    $Neo4jParams.Password = $Neo4jPassword
}

if ($MilvusPassword) {
    $MilvusParams.Password = $MilvusPassword
}

if ($MqttPassword) {
    $MqttParams.Password = $MqttPassword
}

Set-Location "neo4j"
try {
    if ($Neo4jPassword) {
        Write-Host "Using provided Neo4j password" -ForegroundColor Gray
    }
    if ($EnableSSL) {
        Write-Host "SSL enabled for Neo4j" -ForegroundColor Gray
    }
    
    & ".\management\install.ps1" @Neo4jParams
    Write-Host "Neo4j configured successfully" -ForegroundColor Green
    $ConfiguredServices["neo4j"] = $true
} catch {
    Write-Host "Neo4j installation failed with error:" -ForegroundColor Red
    Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  Line: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Gray
    Write-Host "Neo4j will be skipped during startup..." -ForegroundColor Yellow
    $ConfiguredServices["neo4j"] = $false
}
Set-Location $InstallPath

# Configure Milvus using the install script
Write-Host ""
Write-Host "Milvus Configuration:" -ForegroundColor Cyan
Write-Host "====================" -ForegroundColor Gray
Write-Host "Running Milvus installation script..." -ForegroundColor White

Set-Location "milvus"
try {
    if ($MilvusPassword) {
        Write-Host "Using provided Milvus password" -ForegroundColor Gray
    }
    if ($EnableSSL) {
        Write-Host "SSL enabled for Milvus" -ForegroundColor Gray
    }
    
    & ".\management\install.ps1" @MilvusParams
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Milvus configured successfully" -ForegroundColor Green
        $ConfiguredServices["milvus"] = $true
    } else {
        Write-Host "Milvus installation completed with warnings (exit code: $LASTEXITCODE)" -ForegroundColor Yellow
        $ConfiguredServices["milvus"] = $true  # Still try to start if it completed
    }
} catch {
    Write-Host "Milvus installation failed with error:" -ForegroundColor Red
    Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  Line: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Gray
    Write-Host "Milvus will be skipped during startup..." -ForegroundColor Yellow
    $ConfiguredServices["milvus"] = $false
}
Set-Location $InstallPath

# Configure MQTT using the install script
Write-Host ""
Write-Host "MQTT Configuration:" -ForegroundColor Cyan
Write-Host "==================" -ForegroundColor Gray
Write-Host "Running MQTT installation script..." -ForegroundColor White

Set-Location "mqtt"
try {
    if ($MqttPassword) {
        Write-Host "Using provided MQTT password" -ForegroundColor Gray
    }
    if ($EnableSSL) {
        Write-Host "SSL enabled for MQTT" -ForegroundColor Gray
    }
    
    & ".\management\install.ps1" @MqttParams
    if ($LASTEXITCODE -eq 0) {
        Write-Host "MQTT configured successfully" -ForegroundColor Green
        $ConfiguredServices["mqtt"] = $true
    } else {
        Write-Host "MQTT installation completed with warnings (exit code: $LASTEXITCODE)" -ForegroundColor Yellow
        $ConfiguredServices["mqtt"] = $true  # Still try to start if it completed
    }
} catch {
    Write-Host "MQTT installation failed with error:" -ForegroundColor Red
    Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  Line: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Gray
    Write-Host "MQTT will be skipped during startup..." -ForegroundColor Yellow
    $ConfiguredServices["mqtt"] = $false
}
Set-Location $InstallPath

# Start only successfully configured services
Write-Host ""
Write-Host "Starting Configured Services..." -ForegroundColor White
Write-Host "===============================" -ForegroundColor Gray

$SuccessfullyConfigured = $ConfiguredServices.Keys | Where-Object { $ConfiguredServices[$_] -eq $true }
$FailedConfiguration = $ConfiguredServices.Keys | Where-Object { $ConfiguredServices[$_] -eq $false }

if ($FailedConfiguration.Count -gt 0) {
    Write-Host "Skipping services that failed configuration: $($FailedConfiguration -join ', ')" -ForegroundColor Yellow
}

if ($SuccessfullyConfigured.Count -eq 0) {
    Write-Host "No services configured successfully - skipping startup phase" -ForegroundColor Red
} else {
    Write-Host "Starting services: $($SuccessfullyConfigured -join ', ')" -ForegroundColor Green
}

# Check and start Neo4j if configured successfully
if ($ConfiguredServices["neo4j"]) {
    Write-Host ""
    Write-Host "Starting Neo4j..." -ForegroundColor White
    Write-Host "=================" -ForegroundColor Gray

    Set-Location "neo4j"
    try {
        $Neo4jStatus = docker-compose ps --format json | ConvertFrom-Json
        $Neo4jRunning = $Neo4jStatus | Where-Object { $_.Service -eq "neo4j" -and $_.State -eq "running" }

        if ($Neo4jRunning) {
            Write-Host "Neo4j is already running" -ForegroundColor Green
        } else {
            Write-Host "Starting Neo4j services..." -ForegroundColor Yellow
            docker-compose up -d
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Neo4j started successfully" -ForegroundColor Green
            } else {
                Write-Host "Failed to start Neo4j" -ForegroundColor Red
            }
        }
    } catch {
        Write-Host "Starting Neo4j..." -ForegroundColor Yellow
        docker-compose up -d
    }
    Set-Location ..
} else {
    Write-Host ""
    Write-Host "Skipping Neo4j startup (configuration failed)" -ForegroundColor Yellow
}

# Check and start Milvus if configured successfully
if ($ConfiguredServices["milvus"]) {
    Write-Host ""
    Write-Host "Starting Milvus..." -ForegroundColor White
    Write-Host "=================" -ForegroundColor Gray

    Set-Location "milvus"
    try {
        $MilvusStatus = docker-compose ps --format json | ConvertFrom-Json
        $MilvusRunning = $MilvusStatus | Where-Object { $_.Service -eq "standalone" -and $_.State -eq "running" }

        if ($MilvusRunning) {
            Write-Host "Milvus is already running" -ForegroundColor Green
        } else {
            Write-Host "Starting Milvus services..." -ForegroundColor Yellow
            docker-compose up -d
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Milvus started successfully" -ForegroundColor Green
            } else {
                Write-Host "Failed to start Milvus" -ForegroundColor Red
            }
        }
    } catch {
        Write-Host "Starting Milvus..." -ForegroundColor Yellow
        docker-compose up -d
    }
    Set-Location ..
} else {
    Write-Host ""
    Write-Host "Skipping Milvus startup (configuration failed)" -ForegroundColor Yellow
}

# Check and start MQTT if configured successfully
if ($ConfiguredServices["mqtt"]) {
    Write-Host ""
    Write-Host "Starting MQTT..." -ForegroundColor White
    Write-Host "===============" -ForegroundColor Gray

    Set-Location "mqtt"
    try {
        $MqttStatus = docker-compose ps --format json | ConvertFrom-Json
        $MqttRunning = $MqttStatus | Where-Object { $_.Service -eq "mosquitto" -and $_.State -eq "running" }

        if ($MqttRunning) {
            Write-Host "MQTT is already running" -ForegroundColor Green
        } else {
            Write-Host "Starting MQTT services..." -ForegroundColor Yellow
            docker-compose up -d
            if ($LASTEXITCODE -eq 0) {
                Write-Host "MQTT started successfully" -ForegroundColor Green
            } else {
                Write-Host "Failed to start MQTT" -ForegroundColor Red
            }
        }
    } catch {
        Write-Host "Starting MQTT..." -ForegroundColor Yellow
        docker-compose up -d
    }
    Set-Location ..
} else {
    Write-Host ""
    Write-Host "Skipping MQTT startup (configuration failed)" -ForegroundColor Yellow
}

# Wait for services to initialize
Write-Host ""
Write-Host "Waiting for services to initialize..." -ForegroundColor White
Write-Host "=====================================" -ForegroundColor Gray
Start-Sleep -Seconds 15

# Final status check
Write-Host ""
Write-Host "Final Service Status:" -ForegroundColor White
Write-Host "====================" -ForegroundColor Gray

$FinalStatus = @{}
foreach ($service in @("neo4j", "milvus", "mqtt")) {
    Set-Location $service
    try {
        $Status = docker-compose ps --format json | ConvertFrom-Json
        if ($Status) {
            foreach ($container in $Status) {
                $statusColor = switch ($container.State) {
                    "running" { "Green" }
                    "exited" { "Red" }
                    default { "Yellow" }
                }
                Write-Host "  $service/$($container.Service): $($container.State)" -ForegroundColor $statusColor
                $FinalStatus["$service"] = $container.State
            }
        }
    } catch {
        Write-Host "  ${service}: Not available" -ForegroundColor Gray
    }
    Set-Location ..
}

# Installation summary
Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "Installation Summary" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

Write-Host "Service Access Information:" -ForegroundColor Cyan
Write-Host "===========================" -ForegroundColor Gray

if ($FinalStatus["neo4j"] -eq "running") {
    Write-Host "Neo4j Browser: http://localhost:7474" -ForegroundColor Green
    Write-Host "Neo4j Bolt: bolt://localhost:7687" -ForegroundColor Green
    Write-Host "  (Check Neo4j install output above for username/password)" -ForegroundColor Gray
}

if ($FinalStatus["milvus"] -eq "running") {
    Write-Host "Milvus API: localhost:19530" -ForegroundColor Green
    Write-Host "Milvus HTTP API: localhost:9091" -ForegroundColor Green
    Write-Host "MinIO Console: http://localhost:9001" -ForegroundColor Green
    Write-Host "  (Check Milvus install output above for username/password)" -ForegroundColor Gray
}

if ($FinalStatus["mqtt"] -eq "running") {
    Write-Host "MQTT Broker: localhost:1883" -ForegroundColor Green
    Write-Host "MQTT WebSocket: ws://localhost:9002" -ForegroundColor Green
    Write-Host "  (Check MQTT install output above for username/password)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Management Scripts:" -ForegroundColor Cyan
Write-Host "==================" -ForegroundColor Gray
Write-Host "Backup and management scripts are located in each service's 'management' folder:" -ForegroundColor White
Write-Host "  - neo4j\\management\\backup.ps1" -ForegroundColor Gray
Write-Host "  - neo4j\\management\\restore.ps1" -ForegroundColor Gray
Write-Host "  - neo4j\\management\\manage-ssl.ps1" -ForegroundColor Gray
Write-Host "  - milvus\\management\\backup.ps1" -ForegroundColor Gray
Write-Host "  - milvus\\management\\restore.ps1" -ForegroundColor Gray
Write-Host "  - milvus\\management\\manage-ssl.ps1" -ForegroundColor Gray
Write-Host "  - mqtt\\management\\backup.ps1" -ForegroundColor Gray
Write-Host "  - mqtt\\management\\restore.ps1" -ForegroundColor Gray
Write-Host "  - mqtt\\management\\manage-users.ps1" -ForegroundColor Gray
Write-Host "  - mqtt\\management\\manage-ssl.ps1" -ForegroundColor Gray

Write-Host ""
Write-Host "SSL Certificate Distribution:" -ForegroundColor Cyan
Write-Host "============================" -ForegroundColor Gray
Write-Host "If you enabled SSL with self-signed certificates, client machines need CA certificates:" -ForegroundColor White
Write-Host ""
Write-Host "CA Certificate Locations:" -ForegroundColor White
Write-Host "  - Neo4j: neo4j\\certs\\bolt\\trusted\\ca.crt" -ForegroundColor Gray
Write-Host "  - Milvus: milvus\\certs\\milvus\\trusted\\ca.crt" -ForegroundColor Gray
Write-Host "  - MQTT: mqtt\\certs\\ca.crt" -ForegroundColor Gray
Write-Host ""
Write-Host "Install on client machines:" -ForegroundColor White
Write-Host "  Import-Certificate -FilePath 'ca.crt' -CertStoreLocation Cert:\\LocalMachine\\Root" -ForegroundColor Gray
Write-Host ""
Write-Host "For CA-provided certificates, no client distribution is needed." -ForegroundColor Green

# Check if any services have self-signed SSL certificates and offer to install them
Write-Host ""
Write-Host "Self-Signed Certificate Auto-Installation:" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Gray

$HasSelfSignedCerts = $false
$SelfSignedServices = @()

# Check for self-signed certificates
$CertPaths = @(
    @{Service="Neo4j"; Path="neo4j\certs\bolt\trusted\ca.crt"},
    @{Service="Milvus"; Path="milvus\certs\milvus\trusted\ca.crt"},
    @{Service="MQTT"; Path="mqtt\certs\ca.crt"}
)

foreach ($CertPath in $CertPaths) {
    if (Test-Path $CertPath.Path) {
        $HasSelfSignedCerts = $true
        $SelfSignedServices += $CertPath.Service
    }
}

if ($HasSelfSignedCerts) {
    Write-Host "Found self-signed CA certificates for: $($SelfSignedServices -join ', ')" -ForegroundColor White
    
    if ($InstallCertificates) {
        Write-Host "Auto-installing CA certificates (InstallCertificates parameter specified)..." -ForegroundColor Green
        try {
            & ".\management\install-ca-certificates.ps1" -InstallPath $InstallPath
            Write-Host ""
            Write-Host "CA certificates installed successfully!" -ForegroundColor Green
        } catch {
            Write-Host "Failed to install CA certificates: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "You can install them manually later using: .\management\install-ca-certificates.ps1" -ForegroundColor Yellow
        }
    } else {
        Write-Host ""
        Write-Host "Would you like to automatically install these CA certificates to your" -ForegroundColor White
        Write-Host "Windows certificate store? This will eliminate SSL warnings in browsers" -ForegroundColor White
        Write-Host "and allow applications to connect without certificate validation errors." -ForegroundColor White
        Write-Host ""
        
        $InstallCertsChoice = Read-Host "Install CA certificates to Windows certificate store? (y/n)"
        if ($InstallCertsChoice -eq "Y" -or $InstallCertsChoice -eq "y") {
            Write-Host ""
            Write-Host "Installing CA certificates..." -ForegroundColor Green
            try {
                & ".\management\install-ca-certificates.ps1" -InstallPath $InstallPath
                Write-Host ""
                Write-Host "CA certificates installed successfully!" -ForegroundColor Green
            } catch {
                Write-Host "Failed to install CA certificates: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host "You can install them manually later using: .\management\install-ca-certificates.ps1" -ForegroundColor Yellow
            }
        } else {
            Write-Host ""
            Write-Host "CA certificates not installed." -ForegroundColor Yellow
            Write-Host "To install them later, run: .\management\install-ca-certificates.ps1" -ForegroundColor Gray
        }
    }
} else {
    Write-Host "No self-signed certificates found - CA installation not needed." -ForegroundColor Gray
}

# Generate credentials file
Write-Host ""
Write-Host "Generating Credentials File..." -ForegroundColor White
Write-Host "==============================" -ForegroundColor Gray

$CredentialsContent = @"
# =================================================================
# Docker Stack Credentials and Access Information
# Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
# =================================================================

IMPORTANT: Keep this file secure and do not commit to version control!

"@

# Collect Neo4j credentials
if ($ConfiguredServices["neo4j"]) {
    $CredentialsContent += @"

# =================================================================
# Neo4j Graph Database
# =================================================================

"@
    
    if (Test-Path "neo4j\.env") {
        $Neo4jEnv = Get-Content "neo4j\.env" -Raw
        
        # Extract username
        if ($Neo4jEnv -match 'NEO4J_USER=(.+)') {
            $Neo4jUser = $Matches[1].Trim()
        } elseif ($Neo4jEnv -match 'NEO4J_AUTH=([^/]+)/') {
            $Neo4jUser = $Matches[1].Trim()
        } else {
            $Neo4jUser = "neo4j"
        }
        
        # Extract password
        if ($Neo4jEnv -match 'NEO4J_PASSWORD=(.+)') {
            $Neo4jPass = $Matches[1].Trim()
        } elseif ($Neo4jEnv -match 'NEO4J_AUTH=[^/]+/(.+)') {
            $Neo4jPass = $Matches[1].Trim()
        } else {
            $Neo4jPass = "(check Neo4j .env file)"
        }
        
        $CredentialsContent += @"
Username: $Neo4jUser
Password: $Neo4jPass

"@
    }
    
    $CredentialsContent += @"
Access URLs:
  - Browser UI: http://localhost:7474
  - Bolt Protocol: bolt://localhost:7687
"@
    
    # Check if SSL is actually enabled in Neo4j
    $Neo4jSSLEnabled = $false
    if (Test-Path "neo4j\.env") {
        $Neo4jEnvContent = Get-Content "neo4j\.env" -Raw
        if ($Neo4jEnvContent -match 'ENABLE_SSL=true') {
            $Neo4jSSLEnabled = $true
        }
    }
    
    if ($Neo4jSSLEnabled -and (Test-Path "neo4j\certs\bolt\trusted\ca.crt")) {
        $CredentialsContent += @"

  - HTTPS Browser: https://localhost:7473
  - Bolt+S Protocol: bolt+s://localhost:7687

SSL Certificate:
  - CA Certificate: neo4j\certs\bolt\trusted\ca.crt
"@
    }
}

# Collect Milvus credentials
if ($ConfiguredServices["milvus"]) {
    $CredentialsContent += @"


# =================================================================
# Milvus Vector Database
# =================================================================

"@
    
    if (Test-Path "milvus\.env") {
        $MilvusEnv = Get-Content "milvus\.env" -Raw
        if ($MilvusEnv -match 'MILVUS_USERNAME=(.+)') {
            $MilvusUser = $Matches[1].Trim()
            $CredentialsContent += "Username: $MilvusUser`n"
        }
        if ($MilvusEnv -match 'MILVUS_ROOT_PASSWORD=(.+)') {
            $MilvusPass = $Matches[1].Trim()
            $CredentialsContent += "Password: $MilvusPass`n"
        }
        
        $CredentialsContent += "`n"
        
        # Get MinIO credentials
        if ($MilvusEnv -match 'MINIO_ROOT_USER=(.+)') {
            $MinIOUser = $Matches[1].Trim()
        }
        if ($MilvusEnv -match 'MINIO_ROOT_PASSWORD=(.+)') {
            $MinIOPass = $Matches[1].Trim()
        }
    }
    
    $CredentialsContent += @"
Access URLs:
  - gRPC API: localhost:19530
  - HTTP API: localhost:9091
"@
    
    # Check if SSL is actually enabled in Milvus
    $MilvusSSLEnabled = $false
    if (Test-Path "milvus\.env") {
        $MilvusEnvContent = Get-Content "milvus\.env" -Raw
        if ($MilvusEnvContent -match 'ENABLE_SSL=true') {
            $MilvusSSLEnabled = $true
        }
    }
    
    if ($MilvusSSLEnabled) {
        $CredentialsContent += @"

  - Attu Web UI (HTTPS): https://localhost:8001
  - Attu Web UI (HTTP redirect): http://localhost:8002

SSL Certificate:
  - CA Certificate: milvus\tls\ca.pem
  - Client Certificate: milvus\tls\client.pem
  - Client Key: milvus\tls\client.key
"@
    } else {
        $CredentialsContent += @"

  - Attu Web UI: http://localhost:8002
"@
    }
    
    if ($MinIOUser -and $MinIOPass) {
        $CredentialsContent += @"


MinIO Object Storage:
  - Console: http://localhost:9001
  - API: http://localhost:9000
  - Access Key: $MinIOUser
  - Secret Key: $MinIOPass
"@
    }
}

# Collect MQTT credentials
if ($ConfiguredServices["mqtt"]) {
    $CredentialsContent += @"


# =================================================================
# MQTT Message Broker
# =================================================================

"@
    
    $MqttUser = "xmpro"
    $MqttPass = "(check MQTT install output above)"
    
    # Try to get username from password file
    if (Test-Path "mqtt\config\passwords.txt") {
        $MqttCreds = Get-Content "mqtt\config\passwords.txt" -First 1
        if ($MqttCreds -match '^([^:]+):') {
            $MqttUser = $Matches[1]
        }
    }
    
    # Try to get password from .env if it exists
    if (Test-Path "mqtt\.env") {
        $MqttEnv = Get-Content "mqtt\.env" -Raw
        if ($MqttEnv -match 'MQTT_PASSWORD=(.+)') {
            $MqttPass = $Matches[1].Trim()
        }
    }
    
    $CredentialsContent += "Username: $MqttUser`n"
    $CredentialsContent += "Password: $MqttPass`n`n"
    
    $CredentialsContent += @"
Access URLs:
  - MQTT Broker: localhost:1883
  - WebSocket: ws://localhost:9002
"@
    
    # Check if SSL is actually enabled in MQTT
    $MqttSSLEnabled = $false
    if (Test-Path "mqtt\.env") {
        $MqttEnvContent = Get-Content "mqtt\.env" -Raw
        if ($MqttEnvContent -match 'ENABLE_SSL=true') {
            $MqttSSLEnabled = $true
        }
    }
    
    if ($MqttSSLEnabled) {
        $CredentialsContent += @"

  - MQTT Broker (SSL): localhost:8883
  - WebSocket (SSL): wss://localhost:9003

SSL Certificate:
  - CA Certificate: mqtt\certs\ca.crt
  - Client Certificate: mqtt\certs\client.crt
  - Client Key: mqtt\certs\client.key
"@
    }
}

# Add management information
$CredentialsContent += @"


# =================================================================
# Management Commands
# =================================================================

Stop All Services:
  .\stop-all-services.ps1

Stop All Services and Remove Data:
  .\stop-all-services.ps1 -RemoveVolumes

Service-Specific Management:
  - Neo4j Backup: .\neo4j\management\backup.ps1
  - Neo4j Restore: .\neo4j\management\restore.ps1
  - Neo4j SSL: .\neo4j\management\manage-ssl.ps1
  
  - Milvus Backup: .\milvus\management\backup.ps1
  - Milvus Restore: .\milvus\management\restore.ps1
  - Milvus SSL: .\milvus\management\manage-ssl.ps1
  
  - MQTT Backup: .\mqtt\management\backup.ps1
  - MQTT Restore: .\mqtt\management\restore.ps1
  - MQTT Users: .\mqtt\management\manage-users.ps1
  - MQTT SSL: .\mqtt\management\manage-ssl.ps1

# =================================================================
# Security Notes
# =================================================================

1. Keep this file secure - it contains sensitive credentials
2. Do not commit this file to version control
3. Change default passwords in production environments
4. For SSL/TLS connections, distribute CA certificates to client machines
5. Regularly backup your data using the provided backup scripts

# =================================================================
# Support
# =================================================================

For issues or questions:
- Check service logs: docker-compose logs -f (in service directory)
- Review service README files in each service directory
- Verify Docker Desktop is running and healthy

"@

# Save credentials file
$CredentialsFilePath = Join-Path $InstallPath "CREDENTIALS.txt"
$CredentialsContent | Out-File -FilePath $CredentialsFilePath -Encoding UTF8
Write-Host "Credentials file created: CREDENTIALS.txt" -ForegroundColor Green
Write-Host "Location: $CredentialsFilePath" -ForegroundColor White

Write-Host ""
Write-Host "Installation completed!" -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "IMPORTANT: All credentials and access URLs have been saved to:" -ForegroundColor Yellow
Write-Host "  $CredentialsFilePath" -ForegroundColor Cyan
Write-Host ""
Write-Host "Keep this file secure and do not commit it to version control!" -ForegroundColor Yellow
Write-Host "==================================================================" -ForegroundColor Cyan
