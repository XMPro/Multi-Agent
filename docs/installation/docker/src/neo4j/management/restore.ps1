# Change to parent directory (neo4j folder)
Set-Location ..

# List available backups
Write-Host "`nAvailable backups:" -ForegroundColor Cyan
$backups = Get-ChildItem -Path "neo4j-data\backups" -Directory | Sort-Object Name -Descending

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
    $ROLLBACK_DIR = "neo4j-data\backups\${ROLLBACK_TIMESTAMP}_ROLLBACK"

    Write-Host "Creating rollback backup..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Force -Path $ROLLBACK_DIR | Out-Null

    Copy-Item -Path "neo4j-data\data" -Destination "$ROLLBACK_DIR\data" -Recurse -Force -ErrorAction SilentlyContinue
    Copy-Item -Path "neo4j-data\plugins" -Destination "$ROLLBACK_DIR\plugins" -Recurse -Force -ErrorAction SilentlyContinue
    Copy-Item -Path "docker-compose.yml" -Destination "$ROLLBACK_DIR\" -Force -ErrorAction SilentlyContinue

    Write-Host "Rollback backup saved to: $ROLLBACK_DIR" -ForegroundColor Magenta
} else {
    Write-Host "Restoring from a rollback - skipping rollback creation." -ForegroundColor Yellow
}

# Remove current data
Write-Host "Removing current data..." -ForegroundColor Cyan
Remove-Item -Path "neo4j-data\data" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "neo4j-data\plugins" -Recurse -Force -ErrorAction SilentlyContinue

# Restore from backup
Write-Host "Restoring data..." -ForegroundColor Cyan
Copy-Item -Path "$BACKUP_PATH\data" -Destination "neo4j-data\data" -Recurse -Force
Copy-Item -Path "$BACKUP_PATH\plugins" -Destination "neo4j-data\plugins" -Recurse -Force

# Optionally restore configuration files
if (Test-Path "$BACKUP_PATH\docker-compose.yml") {
    Write-Host "Restore docker-compose.yml? (y/n): " -NoNewline -ForegroundColor Yellow
    $restoreConfig = Read-Host
    if ($restoreConfig -eq 'y') {
        Copy-Item -Path "$BACKUP_PATH\docker-compose.yml" -Destination "docker-compose.yml" -Force
        Write-Host "Configuration restored." -ForegroundColor Green
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

Write-Host "`nWaiting for Neo4j to start..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

Write-Host "`nRestore Summary:" -ForegroundColor Cyan
Write-Host "- Database data restored" -ForegroundColor White
Write-Host "- Plugins restored" -ForegroundColor White
Write-Host "`nCheck Neo4j Browser at http://localhost:7474 to verify." -ForegroundColor White
