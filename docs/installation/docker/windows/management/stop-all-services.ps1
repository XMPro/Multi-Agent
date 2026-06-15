# =================================================================
# Stop All Docker Services Script
# Stops Neo4j, Milvus, MQTT, TimescaleDB, Ollama, and OTEL LGTM services
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

# Services to stop: folder name -> display name
$Services = [ordered]@{
    "neo4j"       = "Neo4j"
    "milvus"      = "Milvus"
    "mqtt"        = "MQTT"
    "timescaledb" = "TimescaleDB"
    "ollama"      = "Ollama"
    "otel-lgtm"   = "OTEL LGTM"
}

# Verify expected folders exist
$MissingFolders = @()
foreach ($folder in $Services.Keys) {
    if (-not (Test-Path $folder)) {
        $MissingFolders += $folder
    }
}

if ($MissingFolders.Count -eq $Services.Count) {
    Write-Host "No service folders found in: $InstallPath" -ForegroundColor Red
    Write-Host "Expected folders: $($Services.Keys -join ', ')" -ForegroundColor Yellow
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

foreach ($folder in $Services.Keys) {
    $name = $Services[$folder]

    if (-not (Test-Path $folder)) {
        Write-Host "$name directory not found, skipping" -ForegroundColor Yellow
        continue
    }

    Write-Host ""
    Write-Host "Stopping $name..." -ForegroundColor White
    Set-Location $folder

    # Skip services that were never configured. The service folders are always present
    # (copied from src/), but a service is only "installed" once its install writes a
    # .env. Without it, `docker-compose down` fails interpolating mandatory ${VAR:?...}
    # values (e.g. otel-lgtm's OTEL_INGEST_TOKEN) and reports a false failure.
    if (-not (Test-Path ".env")) {
        Write-Host "$name not configured (no .env), skipping" -ForegroundColor Yellow
        Set-Location ..
        continue
    }

    # Stop the service (use --profile ssl to also stop SSL nginx containers)
    try {
        if ($RemoveVolumes) {
            docker-compose --profile ssl down -v
        } else {
            docker-compose --profile ssl down
        }

        if ($LASTEXITCODE -eq 0) {
            Write-Host "$name stopped successfully" -ForegroundColor Green
            $StoppedServices += $name
        } else {
            Write-Host "Failed to stop $name (exit code: $LASTEXITCODE)" -ForegroundColor Red
            $FailedServices += $name
        }
    } catch {
        Write-Host "Error stopping ${name}: $($_.Exception.Message)" -ForegroundColor Red
        $FailedServices += $name
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
