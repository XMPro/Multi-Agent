# =================================================================
# TimescaleDB Restore Script (PowerShell)
# Production-Grade Database Restore
# =================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$BackupFile,
    [switch]$Force = $false,
    [switch]$DropDatabase = $false
)

$ErrorActionPreference = "Stop"

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "TimescaleDB Restore Script" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

# Validate backup file exists
if (-not (Test-Path $BackupFile)) {
    Write-Host "Error: Backup file not found: $BackupFile" -ForegroundColor Red
    exit 1
}

Write-Host "Backup file: $BackupFile" -ForegroundColor White

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

$DbName = $env:POSTGRES_DB
$DbUser = $env:POSTGRES_USER
$DbPassword = $env:POSTGRES_PASSWORD

if (-not $Force) {
    Write-Host ""
    Write-Host "WARNING: This will restore the database from backup!" -ForegroundColor Yellow
    Write-Host "  Database: $DbName" -ForegroundColor Gray
    Write-Host "  User: $DbUser" -ForegroundColor Gray
    Write-Host "  All current data will be replaced!" -ForegroundColor Red
    Write-Host ""
    $Confirm = Read-Host "Continue with restore? (yes/no)"
    if ($Confirm -ne "yes") {
        Write-Host "Restore cancelled" -ForegroundColor Yellow
        exit 0
    }
}

# Check if file is compressed
$isCompressed = $BackupFile -match '\.gz$'
$tempFile = $null

if ($isCompressed) {
    Write-Host ""
    Write-Host "Decompressing backup..." -ForegroundColor White
    $tempFile = [System.IO.Path]::GetTempFileName()
    
    $gzipStream = New-Object System.IO.Compression.GzipStream([System.IO.File]::OpenRead($BackupFile), [System.IO.Compression.CompressionMode]::Decompress)
    $outputStream = [System.IO.File]::Create($tempFile)
    $gzipStream.CopyTo($outputStream)
    $outputStream.Close()
    $gzipStream.Close()
    
    Write-Host "Decompressed successfully" -ForegroundColor Green
    $RestoreFile = $tempFile
} else {
    $RestoreFile = $BackupFile
}

Write-Host ""
Write-Host "Restoring database..." -ForegroundColor White

try {
    # Stop any active connections
    docker exec -e PGPASSWORD=$DbPassword timescaledb psql -U $DbUser -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$DbName' AND pid <> pg_backend_pid();" 2>$null
    
    if ($DropDatabase) {
        Write-Host "Dropping existing database..." -ForegroundColor Yellow
        docker exec -e PGPASSWORD=$DbPassword timescaledb psql -U $DbUser -d postgres -c "DROP DATABASE IF EXISTS $DbName;" 2>&1 | Out-Null
        docker exec -e PGPASSWORD=$DbPassword timescaledb psql -U $DbUser -d postgres -c "CREATE DATABASE $DbName;" 2>&1 | Out-Null
    }
    
    # Restore database
    Get-Content $RestoreFile | docker exec -i -e PGPASSWORD=$DbPassword timescaledb psql -U $DbUser -d $DbName 2>&1 | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Database restored successfully" -ForegroundColor Green
    } else {
        Write-Host "Error during restore" -ForegroundColor Red
        exit 1
    }
} finally {
    if ($tempFile -and (Test-Path $tempFile)) {
        Remove-Item $tempFile -Force
    }
}

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "Restore completed successfully!" -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Cyan

exit 0
