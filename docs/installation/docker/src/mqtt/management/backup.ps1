# =================================================================
# MQTT Mosquitto Backup Script
# =================================================================

param(
    [string]$BackupName = "",
    [switch]$SkipRestart = $false
)

# Change to parent directory (mqtt folder)
Set-Location ..

# Load environment variables
if (Test-Path ".env") {
    Get-Content ".env" | ForEach-Object {
        if ($_ -match "^([^#][^=]+)=(.*)$") {
            [Environment]::SetEnvironmentVariable($matches[1], $matches[2])
        }
    }
}

# Configuration
$BACKUP_RETENTION_DAYS = if ([Environment]::GetEnvironmentVariable("BACKUP_RETENTION_DAYS")) { [Environment]::GetEnvironmentVariable("BACKUP_RETENTION_DAYS") } else { "30" }
$TIMESTAMP = Get-Date -Format "yyyyMMdd_HHmmss"
$BACKUP_DIR = if ($BackupName) { "data\backups\$BackupName" } else { "data\backups\$TIMESTAMP" }

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "MQTT Mosquitto Backup Script" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

# Stop services if not skipping restart
if (-not $SkipRestart) {
    Write-Host "Stopping MQTT services..." -ForegroundColor Yellow
    docker-compose down
    Start-Sleep -Seconds 3
}

# Create backup directory if it doesn't exist
New-Item -ItemType Directory -Force -Path $BACKUP_DIR | Out-Null

Write-Host "Creating backup in: $BACKUP_DIR" -ForegroundColor Cyan

# Backup data files (excluding backups folder to prevent recursion)
Write-Host "Backing up MQTT data..." -ForegroundColor White
if (Test-Path "data") {
    # Create data directory in backup
    New-Item -ItemType Directory -Force -Path "$BACKUP_DIR\data" | Out-Null
    
    # Copy all files and folders in data except backups folder
    Get-ChildItem -Path "data" | Where-Object { $_.Name -ne "backups" } | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination "$BACKUP_DIR\data" -Recurse -Force
    }
    Write-Host "MQTT persistence data backed up (excluding backups folder)" -ForegroundColor Green
} else {
    Write-Host "No data directory found" -ForegroundColor Yellow
}

# Backup configuration files
Write-Host "Backing up configuration files..." -ForegroundColor White
if (Test-Path "config") {
    Copy-Item -Path "config" -Destination "$BACKUP_DIR\config" -Recurse -Force
    Write-Host "Configuration files backed up" -ForegroundColor Green
}

# Backup logs
Write-Host "Backing up log files..." -ForegroundColor White
if (Test-Path "logs") {
    Copy-Item -Path "logs" -Destination "$BACKUP_DIR\logs" -Recurse -Force
    Write-Host "Log files backed up" -ForegroundColor Green
} else {
    Write-Host "No logs directory found" -ForegroundColor Yellow
}

# Backup SSL certificates if they exist
Write-Host "Backing up SSL certificates..." -ForegroundColor White
if (Test-Path "certs") {
    Copy-Item -Path "certs" -Destination "$BACKUP_DIR\certs" -Recurse -Force
    Write-Host "SSL certificates backed up" -ForegroundColor Green
} else {
    Write-Host "No SSL certificates found" -ForegroundColor Yellow
}

# Backup Docker Compose and environment files
Write-Host "Backing up Docker configuration..." -ForegroundColor White
Copy-Item -Path "docker-compose.yml" -Destination "$BACKUP_DIR\" -Force
Copy-Item -Path ".env" -Destination "$BACKUP_DIR\" -Force
Write-Host "Docker configuration backed up" -ForegroundColor Green

# Create backup metadata
$BackupInfo = @{
    timestamp = $TIMESTAMP
    backup_type = "full"
    mqtt_version = "eclipse-mosquitto:2.0.22"
    retention_days = $BACKUP_RETENTION_DAYS
    files_backed_up = @(
        "data/mosquitto.db",
        "config/mosquitto.conf",
        "config/passwords.txt",
        "config/acl.txt",
        "logs/",
        "docker-compose.yml",
        ".env"
    )
}

$BackupInfo | ConvertTo-Json -Depth 3 | Out-File -FilePath "$BACKUP_DIR\backup_info.json" -Encoding UTF8
Write-Host "Backup metadata created" -ForegroundColor Green

# Restart services if not skipping restart
if (-not $SkipRestart) {
    Write-Host "Restarting MQTT services..." -ForegroundColor Yellow
    docker-compose up -d
    Write-Host "Waiting for MQTT broker to start..." -ForegroundColor Yellow
    Start-Sleep -Seconds 10
}

# Clean up old backups
Write-Host "Cleaning up old backups (older than $BACKUP_RETENTION_DAYS days)..." -ForegroundColor White
$CutoffDate = (Get-Date).AddDays(-[int]$BACKUP_RETENTION_DAYS)
Get-ChildItem -Path "data\backups" -Directory | Where-Object { 
    $_.CreationTime -lt $CutoffDate -and $_.Name -match "^\d{8}_\d{6}$" 
} | ForEach-Object {
    Write-Host "Removing old backup: $($_.Name)" -ForegroundColor Gray
    Remove-Item -Path $_.FullName -Recurse -Force
}

# Calculate backup size
$BackupSize = (Get-ChildItem -Path $BACKUP_DIR -Recurse | Measure-Object -Property Length -Sum).Sum
$BackupSizeMB = [math]::Round($BackupSize / 1MB, 2)

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "Backup Summary:" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "MQTT persistence data backed up" -ForegroundColor Green
Write-Host "Configuration files backed up" -ForegroundColor Green
Write-Host "Log files backed up" -ForegroundColor Green
Write-Host "SSL certificates backed up (if present)" -ForegroundColor Green
Write-Host "Docker configuration backed up" -ForegroundColor Green
Write-Host ""
Write-Host "Backup Location: $BACKUP_DIR" -ForegroundColor White
Write-Host "Backup Size: $BackupSizeMB MB" -ForegroundColor White
Write-Host "Retention: $BACKUP_RETENTION_DAYS days" -ForegroundColor White
Write-Host ""
Write-Host "Backup completed successfully!" -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Cyan

# Return to management directory
Set-Location management
