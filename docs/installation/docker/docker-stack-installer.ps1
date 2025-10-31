# =================================================================
# Docker Stack One-Click Installer
# Neo4j, Milvus, and MQTT Services
# =================================================================

param(
    [string]$ZipPath = "",
    [string]$InstallPath = "",
    [switch]$SkipChecks = $false
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

# Function to update .env file
function Update-EnvFile {
    param([string]$FilePath, [hashtable]$Config)
    
    if (Test-Path $FilePath) {
        $Content = Get-Content $FilePath
        $UpdatedContent = @()
        
        foreach ($line in $Content) {
            $updated = $false
            foreach ($key in $Config.Keys) {
                if ($line -match "^$key=") {
                    $UpdatedContent += "$key=$($Config[$key])"
                    $updated = $true
                    break
                }
            }
            if (-not $updated) {
                $UpdatedContent += $line
            }
        }
        
        Set-Content -Path $FilePath -Value $UpdatedContent
        Write-Host "Updated $FilePath" -ForegroundColor Green
    } else {
        Write-Host "File not found: $FilePath" -ForegroundColor Red
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

# Get installation path if not provided
if (-not $InstallPath) {
    Add-Type -AssemblyName System.Windows.Forms
    $FolderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $FolderBrowser.Description = "Select installation directory"
    $FolderBrowser.ShowNewFolderButton = $true
    
    if ($FolderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $InstallPath = $FolderBrowser.SelectedPath
    } else {
        Write-Host "No installation path selected. Exiting." -ForegroundColor Red
        exit 1
    }
}

Write-Host "Installation path: $InstallPath" -ForegroundColor White

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
    [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $InstallPath)
    Write-Host "ZIP file extracted successfully" -ForegroundColor Green
} catch {
    Write-Host "Failed to extract ZIP file: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Change to installation directory
Set-Location $InstallPath

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

# Configure Neo4j
Write-Host ""
Write-Host "Neo4j Configuration:" -ForegroundColor Cyan
Write-Host "===================" -ForegroundColor Gray
$Neo4jPassword = Read-Host "Enter Neo4j password (default: password123)"
if (-not $Neo4jPassword) { $Neo4jPassword = "password123" }

$Neo4jConfig = @{
    "NEO4J_USER" = "neo4j"
    "NEO4J_PASSWORD" = $Neo4jPassword
}
Update-EnvFile -FilePath "neo4j\.env" -Config $Neo4jConfig

# Configure Milvus
Write-Host ""
Write-Host "Milvus Configuration:" -ForegroundColor Cyan
Write-Host "====================" -ForegroundColor Gray
$MilvusRootPassword = Read-Host "Enter Milvus root password (default: YourSecurePassword123!)"
if (-not $MilvusRootPassword) { $MilvusRootPassword = "YourSecurePassword123!" }

$MilvusConfig = @{
    "MILVUS_AUTH_ENABLED" = "true"
    "MILVUS_ROOT_PASSWORD" = $MilvusRootPassword
}
Update-EnvFile -FilePath "milvus\.env" -Config $MilvusConfig

# Configure MQTT using the install script
Write-Host ""
Write-Host "MQTT Configuration:" -ForegroundColor Cyan
Write-Host "==================" -ForegroundColor Gray
Write-Host "Running MQTT installation script..." -ForegroundColor White

Set-Location "mqtt"
try {
    .\management\install.ps1 -Force
    Write-Host "MQTT configured successfully" -ForegroundColor Green
} catch {
    Write-Host "MQTT installation had issues, but continuing..." -ForegroundColor Yellow
}
Set-Location ..

# Check and start Neo4j if not running
Write-Host ""
Write-Host "Checking Neo4j Status..." -ForegroundColor White
Write-Host "========================" -ForegroundColor Gray

Set-Location "neo4j"
try {
    $Neo4jStatus = docker-compose ps --format json | ConvertFrom-Json
    $Neo4jRunning = $Neo4jStatus | Where-Object { $_.Service -eq "neo4j" -and $_.State -eq "running" }

    if ($Neo4jRunning) {
        Write-Host "Neo4j is already running" -ForegroundColor Green
    } else {
        Write-Host "Starting Neo4j..." -ForegroundColor Yellow
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

# Check and start Milvus if not running
Write-Host ""
Write-Host "Checking Milvus Status..." -ForegroundColor White
Write-Host "=========================" -ForegroundColor Gray

Set-Location "milvus"
try {
    $MilvusStatus = docker-compose ps --format json | ConvertFrom-Json
    $MilvusRunning = $MilvusStatus | Where-Object { $_.Service -eq "standalone" -and $_.State -eq "running" }

    if ($MilvusRunning) {
        Write-Host "Milvus is already running" -ForegroundColor Green
    } else {
        Write-Host "Starting Milvus..." -ForegroundColor Yellow
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
    Write-Host "  Username: neo4j" -ForegroundColor White
    Write-Host "  Password: $Neo4jPassword" -ForegroundColor Yellow
}

if ($FinalStatus["milvus"] -eq "running") {
    Write-Host "Milvus API: localhost:19530" -ForegroundColor Green
    Write-Host "Milvus Web UI: http://localhost:9091" -ForegroundColor Green
    Write-Host "Attu UI: http://localhost:8001" -ForegroundColor Green
    Write-Host "  Root Password: $MilvusRootPassword" -ForegroundColor Yellow
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
Write-Host "  - milvus\\management\\backup.ps1" -ForegroundColor Gray
Write-Host "  - mqtt\\management\\backup.ps1" -ForegroundColor Gray
Write-Host "  - mqtt\\management\\manage-users.ps1" -ForegroundColor Gray
Write-Host "  - mqtt\\management\\manage-ssl.ps1" -ForegroundColor Gray

Write-Host ""
Write-Host "Installation completed!" -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Cyan
