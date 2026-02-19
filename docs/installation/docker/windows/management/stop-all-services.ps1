# =================================================================
# Stop All Docker Services Script
# Stops Neo4j, Milvus, MQTT, TimescaleDB, and Ollama services
# =================================================================

param(
    [string]$InstallPath = "",
    [switch]$RemoveVolumes = $false
)

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "Stop All Docker Services" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

# Get installation path if not provided
if (-not $InstallPath) {
    # Check if we're in the management subfolder
    $CurrentLocation = Get-Location
    if ($CurrentLocation.Path.EndsWith("management")) {
        # Go up one level to the installation root
        $InstallPath = Split-Path $CurrentLocation -Parent
        Write-Host "Detected management subfolder, using parent directory: $InstallPath" -ForegroundColor White
    } else {
        $InstallPath = $CurrentLocation
        Write-Host "Using current directory: $InstallPath" -ForegroundColor White
    }
}

# Verify installation path
if (-not (Test-Path $InstallPath)) {
    Write-Host "Installation path not found: $InstallPath" -ForegroundColor Red
    exit 1
}

Set-Location $InstallPath

# Verify expected folders exist
$ExpectedFolders = @("neo4j", "milvus", "mqtt", "timescaledb", "ollama")
$MissingFolders = @()

foreach ($folder in $ExpectedFolders) {
    if (-not (Test-Path $folder)) {
        $MissingFolders += $folder
    }
}

if ($MissingFolders.Count -eq 5) {
    Write-Host "No service folders found in: $InstallPath" -ForegroundColor Red
    Write-Host "Expected folders: neo4j, milvus, mqtt, timescaledb, ollama" -ForegroundColor Yellow
    exit 1
}

if ($MissingFolders.Count -gt 0) {
    Write-Host "Warning: Missing service folders: $($MissingFolders -join ', ')" -ForegroundColor Yellow
}

# Confirm action
Write-Host ""
if ($RemoveVolumes) {
    Write-Host "WARNING: This will stop all services AND remove their data volumes!" -ForegroundColor Red
    Write-Host "All data will be permanently deleted." -ForegroundColor Red
} else {
    Write-Host "This will stop all running services (data will be preserved)." -ForegroundColor White
}

Write-Host ""
$Confirm = Read-Host "Continue? (y/n)"
if ($Confirm -ne "Y" -and $Confirm -ne "y") {
    Write-Host "Operation cancelled" -ForegroundColor Yellow
    exit 0
}

# Stop services
Write-Host ""
Write-Host "Stopping Services..." -ForegroundColor White
Write-Host "====================" -ForegroundColor Gray

$StoppedServices = @()
$FailedServices = @()

# Stop Neo4j
if (Test-Path "neo4j") {
    Write-Host ""
    Write-Host "Stopping Neo4j..." -ForegroundColor White
    Set-Location "neo4j"
    try {
        if ($RemoveVolumes) {
            docker-compose down -v
        } else {
            docker-compose down
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Neo4j stopped successfully" -ForegroundColor Green
            $StoppedServices += "Neo4j"
        } else {
            Write-Host "Failed to stop Neo4j (exit code: $LASTEXITCODE)" -ForegroundColor Red
            $FailedServices += "Neo4j"
        }
    } catch {
        Write-Host "Error stopping Neo4j: $($_.Exception.Message)" -ForegroundColor Red
        $FailedServices += "Neo4j"
    }
    Set-Location ..
}

# Stop Milvus
if (Test-Path "milvus") {
    Write-Host ""
    Write-Host "Stopping Milvus..." -ForegroundColor White
    Set-Location "milvus"
    try {
        if ($RemoveVolumes) {
            docker-compose down -v
        } else {
            docker-compose down
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Milvus stopped successfully" -ForegroundColor Green
            $StoppedServices += "Milvus"
        } else {
            Write-Host "Failed to stop Milvus (exit code: $LASTEXITCODE)" -ForegroundColor Red
            $FailedServices += "Milvus"
        }
    } catch {
        Write-Host "Error stopping Milvus: $($_.Exception.Message)" -ForegroundColor Red
        $FailedServices += "Milvus"
    }
    Set-Location ..
}

# Stop MQTT
if (Test-Path "mqtt") {
    Write-Host ""
    Write-Host "Stopping MQTT..." -ForegroundColor White
    Set-Location "mqtt"
    try {
        if ($RemoveVolumes) {
            docker-compose down -v
        } else {
            docker-compose down
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "MQTT stopped successfully" -ForegroundColor Green
            $StoppedServices += "MQTT"
        } else {
            Write-Host "Failed to stop MQTT (exit code: $LASTEXITCODE)" -ForegroundColor Red
            $FailedServices += "MQTT"
        }
    } catch {
        Write-Host "Error stopping MQTT: $($_.Exception.Message)" -ForegroundColor Red
        $FailedServices += "MQTT"
    }
    Set-Location ..
}

# Stop TimescaleDB
if (Test-Path "timescaledb") {
    Write-Host ""
    Write-Host "Stopping TimescaleDB..." -ForegroundColor White
    Set-Location "timescaledb"
    try {
        if ($RemoveVolumes) {
            docker-compose down -v
        } else {
            docker-compose down
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "TimescaleDB stopped successfully" -ForegroundColor Green
            $StoppedServices += "TimescaleDB"
        } else {
            Write-Host "Failed to stop TimescaleDB (exit code: $LASTEXITCODE)" -ForegroundColor Red
            $FailedServices += "TimescaleDB"
        }
    } catch {
        Write-Host "Error stopping TimescaleDB: $($_.Exception.Message)" -ForegroundColor Red
        $FailedServices += "TimescaleDB"
    }
    Set-Location ..
}

# Stop Ollama
if (Test-Path "ollama") {
    Write-Host ""
    Write-Host "Stopping Ollama..." -ForegroundColor White
    Set-Location "ollama"
    try {
        if ($RemoveVolumes) {
            docker-compose down -v
        } else {
            docker-compose down
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Ollama stopped successfully" -ForegroundColor Green
            $StoppedServices += "Ollama"
        } else {
            Write-Host "Failed to stop Ollama (exit code: $LASTEXITCODE)" -ForegroundColor Red
            $FailedServices += "Ollama"
        }
    } catch {
        Write-Host "Error stopping Ollama: $($_.Exception.Message)" -ForegroundColor Red
        $FailedServices += "Ollama"
    }
    Set-Location ..
}

# Summary
Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

if ($StoppedServices.Count -gt 0) {
    Write-Host "Successfully stopped: $($StoppedServices -join ', ')" -ForegroundColor Green
}

if ($FailedServices.Count -gt 0) {
    Write-Host "Failed to stop: $($FailedServices -join ', ')" -ForegroundColor Red
}

if ($RemoveVolumes) {
    Write-Host ""
    Write-Host "Data volumes have been removed" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "All operations completed" -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Cyan
