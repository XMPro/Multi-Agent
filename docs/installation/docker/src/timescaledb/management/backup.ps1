# =================================================================
# TimescaleDB Backup Script (PowerShell)
# Production-Grade Database Backup
# =================================================================

param(
    [string]$BackupName = "",
    [string]$BackupDir = "..\backups",
    [switch]$Compress = $true,
    [switch]$IncludeSchema = $true,
    [switch]$Verbose = $false
)

$ErrorActionPreference = "Stop"

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "TimescaleDB Backup Script" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

# Load environment variables
if (Test-Path ".env") {
    Get-Content ".env" | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            [Environment]::SetEnvironmentVariable($key, $value, "Process")
        }
    }
    Write-Host "Loaded configuration from .env" -ForegroundColor Green
} else {
    Write-Host "Warning: .env file not found" -ForegroundColor Yellow
    exit 1
}

# Get database configuration
$DbName = $env:POSTGRES_DB
$DbUser = $env:POSTGRES_USER
$DbPassword = $env:POSTGRES_PASSWORD

if (-not $DbName -or -not $DbUser -or -not $DbPassword) {
    Write-Host "Error: Database configuration not found in .env file" -ForegroundColor Red
    exit 1
}

# Generate backup name if not provided
if (-not $BackupName) {
    $BackupName = "timescaledb_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
}

# Ensure backup directory exists
if (-not (Test-Path $BackupDir)) {
    New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
    Write-Host "Created backup directory: $BackupDir" -ForegroundColor Green
}

# Create WAL backup directory
$WalBackupDir = Join-Path $BackupDir "wal"
if (-not (Test-Path $WalBackupDir)) {
    New-Item -ItemType Directory -Force -Path $WalBackupDir | Out-Null
}

Write-Host ""
Write-Host "Backup Configuration:" -ForegroundColor White
Write-Host "  Database: $DbName" -ForegroundColor Gray
Write-Host "  User: $DbUser" -ForegroundColor Gray
Write-Host "  Backup Name: $BackupName" -ForegroundColor Gray
Write-Host "  Compression: $Compress" -ForegroundColor Gray
Write-Host "  Include Schema: $IncludeSchema" -ForegroundColor Gray

# Check if container is running
Write-Host ""
Write-Host "Checking database status..." -ForegroundColor White

$containerStatus = docker ps --filter "name=timescaledb" --format "{{.Status}}"
if (-not $containerStatus) {
    Write-Host "Error: TimescaleDB container is not running" -ForegroundColor Red
    Write-Host "Start the container with: docker-compose up -d" -ForegroundColor Yellow
    exit 1
}

Write-Host "Container is running" -ForegroundColor Green

# Perform backup
Write-Host ""
Write-Host "Creating backup..." -ForegroundColor White
Write-Host "==================" -ForegroundColor Gray

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Write-Host "Backup started at: $timestamp" -ForegroundColor Gray

$backupFile = Join-Path $BackupDir "$BackupName.sql"

# Build pg_dump command
$pgDumpArgs = @(
    "exec", "-e", "PGPASSWORD=$DbPassword",
    "timescaledb",
    "pg_dump",
    "-U", $DbUser,
    "-d", $DbName,
    "--format=plain",
    "--no-owner",
    "--no-acl"
)

if ($IncludeSchema) {
    $pgDumpArgs += "--create"
}

if ($Verbose) {
    $pgDumpArgs += "--verbose"
}

try {
    # Execute pg_dump and save to file
    $output = docker $pgDumpArgs 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        $output | Out-File -FilePath $backupFile -Encoding UTF8
        Write-Host "Database dump created successfully" -ForegroundColor Green
        
        # Get file size
        $fileSize = (Get-Item $backupFile).Length
        $fileSizeMB = [math]::Round($fileSize / 1MB, 2)
        Write-Host "Backup size: $fileSizeMB MB" -ForegroundColor Gray
        
        # Compress if requested
        if ($Compress) {
            Write-Host ""
            Write-Host "Compressing backup..." -ForegroundColor White
            
            $compressedFile = "$backupFile.gz"
            
            # Use 7-Zip if available, otherwise use PowerShell compression
            if (Get-Command "7z" -ErrorAction SilentlyContinue) {
                & 7z a -tgzip "$compressedFile" "$backupFile" -mx9 | Out-Null
            } else {
                # PowerShell native compression
                $bytes = [System.IO.File]::ReadAllBytes($backupFile)
                $output = [System.IO.File]::Create($compressedFile)
                $gzipStream = New-Object System.IO.Compression.GzipStream($output, [System.IO.Compression.CompressionMode]::Compress)
                $gzipStream.Write($bytes, 0, $bytes.Length)
                $gzipStream.Close()
                $output.Close()
            }
            
            # Remove uncompressed file
            Remove-Item $backupFile
            
            $compressedSize = (Get-Item $compressedFile).Length
            $compressedSizeMB = [math]::Round($compressedSize / 1MB, 2)
            $compressionRatio = [math]::Round(($fileSize - $compressedSize) / $fileSize * 100, 1)
            
            Write-Host "Compressed successfully" -ForegroundColor Green
            Write-Host "  Compressed size: $compressedSizeMB MB" -ForegroundColor Gray
            Write-Host "  Compression ratio: $compressionRatio%" -ForegroundColor Gray
            
            $finalBackupFile = $compressedFile
        } else {
            $finalBackupFile = $backupFile
        }
        
        # Create backup metadata
        $metadataFile = "$finalBackupFile.meta"
        $metadata = @"
Backup Metadata
===============
Database: $DbName
User: $DbUser
Backup Time: $timestamp
Backup File: $(Split-Path $finalBackupFile -Leaf)
Original Size: $fileSizeMB MB
Compressed: $Compress
PostgreSQL Version: $(docker exec timescaledb psql -U $DbUser -d $DbName -t -c 'SELECT version();' 2>$null)
TimescaleDB Version: $(docker exec timescaledb psql -U $DbUser -d $DbName -t -c "SELECT extversion FROM pg_extension WHERE extname = 'timescaledb';" 2>$null)
"@
        $metadata | Out-File -FilePath $metadataFile -Encoding UTF8
        
    } else {
        Write-Host "Error during backup:" -ForegroundColor Red
        Write-Host $output -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Backup retention cleanup
Write-Host ""
Write-Host "Checking backup retention..." -ForegroundColor White

$retentionDays = [int]$env:BACKUP_RETENTION_DAYS
if (-not $retentionDays -or $retentionDays -le 0) {
    $retentionDays = 30
}

$cutoffDate = (Get-Date).AddDays(-$retentionDays)
$oldBackups = Get-ChildItem -Path $BackupDir -Filter "*.sql*" | Where-Object {
    $_.LastWriteTime -lt $cutoffDate
}

if ($oldBackups.Count -gt 0) {
    Write-Host "Found $($oldBackups.Count) backup(s) older than $retentionDays days" -ForegroundColor Yellow
    foreach ($oldBackup in $oldBackups) {
        Write-Host "  Removing: $($oldBackup.Name)" -ForegroundColor Gray
        Remove-Item $oldBackup.FullName -Force
        
        # Remove metadata file if exists
        $metaFile = "$($oldBackup.FullName).meta"
        if (Test-Path $metaFile) {
            Remove-Item $metaFile -Force
        }
    }
    Write-Host "Old backups removed" -ForegroundColor Green
} else {
    Write-Host "No old backups to remove (retention: $retentionDays days)" -ForegroundColor Gray
}

# Display summary
Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "Backup Summary" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "Backup completed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Backup Details:" -ForegroundColor White
Write-Host "  Location: $finalBackupFile" -ForegroundColor Gray
Write-Host "  Metadata: $metadataFile" -ForegroundColor Gray
Write-Host "  Retention: $retentionDays days" -ForegroundColor Gray

Write-Host ""
Write-Host "To restore this backup:" -ForegroundColor White
Write-Host "  .\restore.ps1 -BackupFile `"$finalBackupFile`"" -ForegroundColor Gray

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan

exit 0
