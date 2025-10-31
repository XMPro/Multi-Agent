# Change to parent directory (neo4j folder)
Set-Location ..

# Stop services
docker-compose down

# Create backup directory with timestamp
$TIMESTAMP = Get-Date -Format "yyyyMMdd_HHmmss"
$BACKUP_DIR = "neo4j-data\backups\$TIMESTAMP"

# Create backup directory if it doesn't exist
New-Item -ItemType Directory -Force -Path $BACKUP_DIR | Out-Null

Write-Host "Creating backup..." -ForegroundColor Cyan

# Copy data folders
Copy-Item -Path "neo4j-data\data" -Destination "$BACKUP_DIR\data" -Recurse -Force
Copy-Item -Path "neo4j-data\plugins" -Destination "$BACKUP_DIR\plugins" -Recurse -Force

# Copy configuration files
Copy-Item -Path "docker-compose.yml" -Destination "$BACKUP_DIR\" -Force

# Restart
docker-compose up -d

# Return to management directory
Set-Location management

Write-Host "Backup completed to $BACKUP_DIR" -ForegroundColor Green
Write-Host "Waiting for Neo4j to start..." -ForegroundColor Yellow

# Wait a moment for services to start
Start-Sleep -Seconds 5

Write-Host "`nBackup Summary:" -ForegroundColor Cyan
Write-Host "- Database data backed up" -ForegroundColor White
Write-Host "- Plugins backed up" -ForegroundColor White
Write-Host "- Configuration files backed up" -ForegroundColor White
