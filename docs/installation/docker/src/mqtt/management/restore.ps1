# =================================================================
# MQTT Mosquitto Restore Script
# =================================================================

# Change to parent directory (mqtt folder)
Set-Location ..

# List available backups
Write-Host "`nAvailable backups:" -ForegroundColor Cyan
$backups = Get-ChildItem -Path "data\backups" -Directory | Sort-Object Name -Descending

if ($backups.Count -eq 0) {
    Write-Host "No backups found!" -ForegroundColor Red
    exit
}

for ($i = 0; $i -lt $backups.Count; $i++) {
    Write-Host "[$i] $($backups[$i].Name)" -ForegroundColor Yellow
}

# Get user selection
Write-Host "`nEnter the number of the backup to restore (or 'q' to quit): " -NoNewline -ForegroundColor Green
$selection = Read-Host

if ($selection -eq 'q') {
    Write-Host "Restore cancelled." -ForegroundColor Yellow
    exit
}

if ($selection -notmatch '^\d+$' -or [int]$selection -ge $backups.Count) {
    Write-Host "Invalid selection!" -ForegroundColor Red
    exit
}

$selectedBackup = $backups[[int]$selection]
$BACKUP_PATH = $selectedBackup.FullName

# Show backup information if available
$BackupInfoPath = Join-Path $BACKUP_PATH "backup_info.json"
if (Test-Path $BackupInfoPath) {
    $BackupInfo = Get-Content $BackupInfoPath | ConvertFrom-Json
    Write-Host "`nBackup Information:" -ForegroundColor Cyan
    Write-Host "  Timestamp: $($BackupInfo.timestamp)" -ForegroundColor White
    Write-Host "  Type: $($BackupInfo.backup_type)" -ForegroundColor White
    Write-Host "  MQTT Version: $($BackupInfo.mqtt_version)" -ForegroundColor White
}

# Show confirmation
Write-Host "`n============================================" -ForegroundColor Red
Write-Host "WARNING: This will OVERWRITE current data!" -ForegroundColor Red
Write-Host "============================================" -ForegroundColor Red
Write-Host "Restoring from: $($selectedBackup.Name)" -ForegroundColor Yellow
Write-Host "`nType 'yes' (full word) to continue: " -NoNewline -ForegroundColor Green
$confirmation = Read-Host

if ($confirmation -ne 'yes') {
    Write-Host "Restore cancelled. (You must type 'yes' exactly)" -ForegroundColor Yellow
    exit
}

# Stop services
Write-Host "`nStopping services..." -ForegroundColor Cyan
docker-compose down

# Create rollback backup BEFORE restoring (unless already restoring from a rollback)
if ($selectedBackup.Name -notlike "*_ROLLBACK") {
    $ROLLBACK_TIMESTAMP = Get-Date -Format "yyyyMMdd_HHmmss"
    $ROLLBACK_DIR = "data\backups\${ROLLBACK_TIMESTAMP}_ROLLBACK"

    Write-Host "Creating rollback backup..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Force -Path $ROLLBACK_DIR | Out-Null

    # Backup current data (excluding backups folder)
    if (Test-Path "data") {
        New-Item -ItemType Directory -Force -Path "$ROLLBACK_DIR\data" | Out-Null
        Get-ChildItem -Path "data" | Where-Object { $_.Name -ne "backups" } | ForEach-Object {
            Copy-Item -Path $_.FullName -Destination "$ROLLBACK_DIR\data" -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    Copy-Item -Path "config" -Destination "$ROLLBACK_DIR\config" -Recurse -Force -ErrorAction SilentlyContinue
    Copy-Item -Path "logs" -Destination "$ROLLBACK_DIR\logs" -Recurse -Force -ErrorAction SilentlyContinue
    Copy-Item -Path "certs" -Destination "$ROLLBACK_DIR\certs" -Recurse -Force -ErrorAction SilentlyContinue
    Copy-Item -Path "docker-compose.yml" -Destination "$ROLLBACK_DIR\" -Force -ErrorAction SilentlyContinue
    Copy-Item -Path ".env" -Destination "$ROLLBACK_DIR\" -Force -ErrorAction SilentlyContinue

    Write-Host "Rollback backup saved to: $ROLLBACK_DIR" -ForegroundColor Magenta
} else {
    Write-Host "Restoring from a rollback - skipping rollback creation." -ForegroundColor Yellow
}

# Remove current data (but preserve backups folder)
Write-Host "Removing current data..." -ForegroundColor Cyan
Get-ChildItem -Path "data" | Where-Object { $_.Name -ne "backups" } | ForEach-Object {
    Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
}
Remove-Item -Path "config" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "logs" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "certs" -Recurse -Force -ErrorAction SilentlyContinue

# Restore from backup
Write-Host "Restoring data..." -ForegroundColor Cyan
if (Test-Path "$BACKUP_PATH\data") {
    Copy-Item -Path "$BACKUP_PATH\data\*" -Destination "data" -Recurse -Force
}
if (Test-Path "$BACKUP_PATH\config") {
    Copy-Item -Path "$BACKUP_PATH\config" -Destination "config" -Recurse -Force
}
if (Test-Path "$BACKUP_PATH\logs") {
    Copy-Item -Path "$BACKUP_PATH\logs" -Destination "logs" -Recurse -Force
}
if (Test-Path "$BACKUP_PATH\certs") {
    Copy-Item -Path "$BACKUP_PATH\certs" -Destination "certs" -Recurse -Force
}

# Optionally restore configuration files
if (Test-Path "$BACKUP_PATH\docker-compose.yml") {
    Write-Host "Restore docker-compose.yml? (y/n): " -NoNewline -ForegroundColor Yellow
    $restoreConfig = Read-Host
    if ($restoreConfig -eq 'y') {
        Copy-Item -Path "$BACKUP_PATH\docker-compose.yml" -Destination "docker-compose.yml" -Force
        Write-Host "Configuration restored." -ForegroundColor Green
    }
}

if (Test-Path "$BACKUP_PATH\.env") {
    Write-Host "Restore .env file? (y/n): " -NoNewline -ForegroundColor Yellow
    $restoreEnv = Read-Host
    if ($restoreEnv -eq 'y') {
        Copy-Item -Path "$BACKUP_PATH\.env" -Destination ".env" -Force
        Write-Host "Environment file restored." -ForegroundColor Green
    }
}

# Restart services
Write-Host "`nStarting services..." -ForegroundColor Cyan
docker-compose up -d

Write-Host "`n============================================" -ForegroundColor Green
Write-Host "Restore completed successfully!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host "Restored from: $($selectedBackup.Name)" -ForegroundColor Green

if ($selectedBackup.Name -notlike "*_ROLLBACK") {
    Write-Host "Rollback saved to: $ROLLBACK_DIR" -ForegroundColor Magenta
    Write-Host "`nIf you need to undo this restore, use the rollback backup." -ForegroundColor Yellow
}

Write-Host "`nWaiting for MQTT broker to start..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

Write-Host "`nRestore Summary:" -ForegroundColor Cyan
Write-Host "- MQTT persistence data restored" -ForegroundColor White
Write-Host "- Configuration files restored" -ForegroundColor White
Write-Host "- Log files restored" -ForegroundColor White
Write-Host "- SSL certificates restored (if present)" -ForegroundColor White
Write-Host "`nCheck MQTT broker status: docker-compose logs mosquitto" -ForegroundColor White

# Return to management directory
Set-Location management
