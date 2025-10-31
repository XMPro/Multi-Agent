# Change to parent directory (milvus folder)
Set-Location ..

# Stop services
docker-compose down

# Create backup directory with timestamp
$TIMESTAMP = Get-Date -Format "yyyyMMdd_HHmmss"
$BACKUP_DIR = "milvus-data\backups\$TIMESTAMP"

# Create backup directory if it doesn't exist
New-Item -ItemType Directory -Force -Path $BACKUP_DIR | Out-Null

Write-Host "Creating backup..." -ForegroundColor Cyan

# Copy all data folders
Copy-Item -Path "milvus-data\etcd" -Destination "$BACKUP_DIR\etcd" -Recurse -Force
Copy-Item -Path "milvus-data\minio" -Destination "$BACKUP_DIR\minio" -Recurse -Force
Copy-Item -Path "milvus-data\milvus" -Destination "$BACKUP_DIR\milvus" -Recurse -Force

# Copy configuration files
Copy-Item -Path "docker-compose.yml" -Destination "$BACKUP_DIR\" -Force

# Restart
docker-compose up -d

# Return to management directory
Set-Location management

Write-Host "Backup completed to $BACKUP_DIR" -ForegroundColor Green
Write-Host "Waiting for services to be healthy..." -ForegroundColor Yellow

# Wait a moment for services to start
Start-Sleep -Seconds 5

Write-Host "`nBackup Summary:" -ForegroundColor Cyan
Write-Host "- etcd metadata backed up" -ForegroundColor White
Write-Host "- MinIO vector data backed up" -ForegroundColor White
Write-Host "- Milvus state backed up" -ForegroundColor White
Write-Host "- Configuration files backed up" -ForegroundColor White
