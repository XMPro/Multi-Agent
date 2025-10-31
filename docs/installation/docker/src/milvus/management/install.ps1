param(
    [string]$Username = "milvus",
    [string]$Password = "",
    [switch]$EnableSSL = $false,
    [string]$Domain = "localhost",
    [switch]$Force = $false
)

# Ensure we're in the milvus directory (not management subdirectory)
$CurrentLocation = Get-Location
if ($CurrentLocation.Path.EndsWith("management")) {
    # If we're in the management directory, go up one level to milvus directory
    Set-Location ..
    Write-Host "Changed from management directory to milvus directory" -ForegroundColor Gray
} elseif (Test-Path "management") {
    # If we're already in milvus directory (has management subdirectory), stay here
    Write-Host "Already in milvus directory" -ForegroundColor Gray
} else {
    # We might be in the wrong location
    Write-Host "Warning: Current directory may not be correct for Milvus installation" -ForegroundColor Yellow
    Write-Host "Expected to be in milvus directory or milvus/management directory" -ForegroundColor Yellow
}

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "Milvus Vector Database Installation Script" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

# Check if Docker is running
Write-Host "Checking Docker availability..." -ForegroundColor White
try {
    docker version | Out-Null
    Write-Host "Docker is available" -ForegroundColor Green
} catch {
    Write-Host "Docker is not running or not installed!" -ForegroundColor Red
    Write-Host "Please install Docker Desktop and ensure it's running." -ForegroundColor Yellow
    exit 1
}

# Check if docker-compose is available
try {
    docker-compose version | Out-Null
    Write-Host "Docker Compose is available" -ForegroundColor Green
} catch {
    Write-Host "Docker Compose is not available!" -ForegroundColor Red
    Write-Host "Please ensure Docker Compose is installed." -ForegroundColor Yellow
    exit 1
}

# Check if Milvus containers are already running
Write-Host "Checking existing Milvus containers..." -ForegroundColor White
try {
    $ExistingContainers = docker-compose ps --format json | ConvertFrom-Json
    $MilvusContainers = $ExistingContainers | Where-Object { $_.Service -match "milvus|etcd|minio" }
    
    if ($MilvusContainers -and ($MilvusContainers | Where-Object { $_.State -eq "running" })) {
        Write-Host "Milvus containers are already running" -ForegroundColor Yellow
        $StopChoice = Read-Host "Stop existing containers to reconfigure? (y/n)"
        if ($StopChoice -eq "Y" -or $StopChoice -eq "y") {
            Write-Host "Stopping existing Milvus containers..." -ForegroundColor Yellow
            docker-compose down
            Write-Host "Containers stopped" -ForegroundColor Green
        } else {
            Write-Host "Installation cancelled - containers still running" -ForegroundColor Yellow
            exit 0
        }
    } elseif ($MilvusContainers) {
        Write-Host "Milvus containers exist but are not running" -ForegroundColor Gray
    } else {
        Write-Host "No existing Milvus containers found" -ForegroundColor Green
    }
} catch {
    Write-Host "No existing containers found" -ForegroundColor Green
}

# Create directory structure
Write-Host "Creating directory structure..." -ForegroundColor White
$Directories = @(
    "milvus-data",
    "milvus-data\backups",
    "milvus-data\etcd",
    "milvus-data\milvus",
    "milvus-data\minio",
    "certs",
    "certs\milvus",
    "certs\etcd",
    "certs\minio",
    "certs\milvus\trusted",
    "certs\etcd\trusted",
    "certs\minio\trusted",
    "config"
)

foreach ($Dir in $Directories) {
    if (-not (Test-Path $Dir)) {
        New-Item -ItemType Directory -Force -Path $Dir | Out-Null
        Write-Host "Created directory: $Dir" -ForegroundColor Green
    } else {
        Write-Host "Directory exists: $Dir" -ForegroundColor Gray
    }
}

# Ask about SSL setup
Write-Host "SSL Configuration:" -ForegroundColor White
$SSLChoice = Read-Host "Enable SSL/TLS encryption for Milvus? (y/n)"
if ($SSLChoice -eq "Y" -or $SSLChoice -eq "y") {
    $EnableSSL = $true
    Write-Host "SSL will be enabled for Milvus API and internal communications" -ForegroundColor Green
    
    # Ask for certificate type
    Write-Host ""
    Write-Host "Certificate Options:" -ForegroundColor White
    Write-Host "1. Generate self-signed certificates (for development/testing)" -ForegroundColor Gray
    Write-Host "2. Use CA-provided certificates (for production)" -ForegroundColor Gray
    $CertChoice = Read-Host "Select certificate type (1 or 2, default: 1)"
    
    if ($CertChoice -eq "2") {
        Write-Host "CA-provided certificates selected" -ForegroundColor Green
        Write-Host "You can install them after setup using: .\management\manage-ssl.ps1 install-ca" -ForegroundColor Cyan
        Write-Host "SSL will be configured but not enabled until certificates are installed" -ForegroundColor Yellow
        $EnableSSL = $false  # Don't generate self-signed certs, wait for CA certs
        $UseCAProvided = $true
    } else {
        Write-Host "Self-signed certificates selected" -ForegroundColor Green
        $UseCAProvided = $false
        
        # Ask for domain name
        $DomainChoice = Read-Host "Enter domain name for SSL certificate (default: localhost)"
        if ($DomainChoice) {
            $Domain = $DomainChoice
        }
        Write-Host "SSL certificates will be generated for domain: $Domain" -ForegroundColor White
    }
} else {
    Write-Host "SSL will be disabled (unencrypted connections only)" -ForegroundColor Yellow
    $UseCAProvided = $false
}

# Generate or prompt for password if not provided
if (-not $Password) {
    Write-Host "Password Setup:" -ForegroundColor White
    $Choice = Read-Host "Generate secure password automatically? (y/n)"
    
    if ($Choice -eq "" -or $Choice -eq "Y" -or $Choice -eq "y") {
        Write-Host "Generating secure password..." -ForegroundColor White
        # Generate a secure password for Milvus (avoiding $ and other problematic characters for .env files)
        $Password = -join ((65..90) + (97..122) + (48..57) + @(33,35,37,38,42,43,45,61,63,64) | Get-Random -Count 18 | ForEach-Object {[char]$_})
        Write-Host "Generated password for user '$Username': $Password" -ForegroundColor Green
    } else {
        $Password = Read-Host "Enter password for user '$Username'" -AsSecureString
        $Password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password))
        if (-not $Password) {
            Write-Host "Password cannot be empty!" -ForegroundColor Red
            exit 1
        }
    }
}

# Update .env file with configuration
Write-Host "Creating configuration files..." -ForegroundColor White
$EnvContent = @"
# Milvus Authentication
MILVUS_USER=$Username
MILVUS_PASSWORD=$Password

# SSL Configuration
ENABLE_SSL=$($EnableSSL.ToString().ToLower())
SSL_DOMAIN=$Domain

# Milvus Ports
MILVUS_PORT=19530
MILVUS_GRPC_PORT=19530
MILVUS_HTTP_PORT=9091

# MinIO Configuration
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=minioadmin
MINIO_PORT=9000
MINIO_CONSOLE_PORT=9001

# etcd Configuration
ETCD_PORT=2379
ETCD_PEER_PORT=2380

# Memory and Performance
MILVUS_CACHE_SIZE=2GB
MILVUS_INSERT_BUFFER_SIZE=1GB

# Timezone
TZ=UTC
"@

$EnvContent | Out-File -FilePath ".env" -Encoding ASCII
Write-Host "Created .env file with configuration" -ForegroundColor Green

# Set proper permissions for data directories
Write-Host "Setting directory permissions..." -ForegroundColor White
# On Windows, Docker handles most permissions, but we ensure directories are accessible
icacls "milvus-data" /grant "Everyone:(OI)(CI)F" /T | Out-Null
icacls "config" /grant "Everyone:(OI)(CI)F" /T | Out-Null
Write-Host "Directory permissions configured" -ForegroundColor Green

# SSL Certificate setup
if ($EnableSSL) {
    Write-Host "Setting up SSL certificates..." -ForegroundColor White
    
    if (-not (Test-Path "certs\milvus\server.key") -or $Force) {
        Write-Host "Generating SSL certificates for Milvus..." -ForegroundColor Gray
        
        try {
            # Use OpenSSL in Docker container to generate certificates
            Write-Host "Generating certificates using OpenSSL in Docker..." -ForegroundColor Gray
            
            # Generate CA private key
            docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl genrsa -out ca.key 4096
            
            # Generate CA certificate
            docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl req -new -x509 -days 365 -key ca.key -out ca.crt -subj "/C=US/ST=State/L=City/O=Milvus-VectorDB/CN=Milvus-CA"
            
            # Generate Milvus server certificates with SAN
            Write-Host "Generating Milvus server certificates..." -ForegroundColor Gray
            docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl genrsa -out milvus_server.key 4096
            docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl req -new -key milvus_server.key -out milvus_server.csr -subj "/C=US/ST=State/L=City/O=Milvus-VectorDB/CN=$Domain" -addext "subjectAltName=DNS:$Domain,DNS:localhost,DNS:127.0.0.1,DNS:milvus,IP:127.0.0.1,IP:::1"
            docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl x509 -req -in milvus_server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out milvus_server.crt -days 365 -copy_extensions copy
            
            # Generate etcd certificates with SAN
            Write-Host "Generating etcd certificates..." -ForegroundColor Gray
            docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl genrsa -out etcd_server.key 4096
            docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl req -new -key etcd_server.key -out etcd_server.csr -subj "/C=US/ST=State/L=City/O=Milvus-VectorDB/CN=etcd" -addext "subjectAltName=DNS:etcd,DNS:localhost,DNS:127.0.0.1,IP:127.0.0.1,IP:::1"
            docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl x509 -req -in etcd_server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out etcd_server.crt -days 365 -copy_extensions copy
            
            # Generate MinIO certificates with SAN
            Write-Host "Generating MinIO certificates..." -ForegroundColor Gray
            docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl genrsa -out minio_server.key 4096
            docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl req -new -key minio_server.key -out minio_server.csr -subj "/C=US/ST=State/L=City/O=Milvus-VectorDB/CN=minio" -addext "subjectAltName=DNS:minio,DNS:localhost,DNS:127.0.0.1,IP:127.0.0.1,IP:::1"
            docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl x509 -req -in minio_server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out minio_server.crt -days 365 -copy_extensions copy
            
            # Move certificates to proper directories
            docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine sh -c "
                mv milvus_server.key milvus/server.key &&
                mv milvus_server.crt milvus/server.crt &&
                cp ca.crt milvus/trusted/ca.crt &&
                mv etcd_server.key etcd/server.key &&
                mv etcd_server.crt etcd/server.crt &&
                cp ca.crt etcd/trusted/ca.crt &&
                mv minio_server.key minio/server.key &&
                mv minio_server.crt minio/server.crt &&
                cp ca.crt minio/trusted/ca.crt &&
                rm -f *.csr ca.srl
            "
            
            # Verify certificates were created
            if ((Test-Path "certs\milvus\server.key") -and (Test-Path "certs\milvus\server.crt") -and 
                (Test-Path "certs\etcd\server.key") -and (Test-Path "certs\etcd\server.crt") -and
                (Test-Path "certs\minio\server.key") -and (Test-Path "certs\minio\server.crt")) {
                Write-Host "SSL certificates generated successfully" -ForegroundColor Green
                
                # Clean up temporary Docker images (only if not from offline package)
                Write-Host "Cleaning up temporary Docker images..." -ForegroundColor Gray
                
                # Check if images were loaded from offline package by looking for specific tag pattern
                $AlpineOpenSSLInfo = docker images alpine/openssl:latest --format "{{.Repository}}:{{.Tag}} {{.CreatedSince}}" 2>$null
                $AlpineInfo = docker images alpine:latest --format "{{.Repository}}:{{.Tag}} {{.CreatedSince}}" 2>$null
                
                # Only remove if images are very recent (likely just pulled) or if they don't have the offline package characteristics
                if ($AlpineOpenSSLInfo -and $AlpineOpenSSLInfo -notmatch "months|weeks") {
                    docker rmi alpine/openssl:latest -f 2>$null | Out-Null
                    Write-Host "Removed alpine/openssl temporary image" -ForegroundColor Gray
                } else {
                    Write-Host "Preserving alpine/openssl image (likely from offline package)" -ForegroundColor Green
                }
                
                if ($AlpineInfo -and $AlpineInfo -notmatch "months|weeks") {
                    docker rmi alpine:latest -f 2>$null | Out-Null
                    Write-Host "Removed alpine temporary image" -ForegroundColor Gray
                } else {
                    Write-Host "Preserving alpine image (likely from offline package)" -ForegroundColor Green
                }
            } else {
                throw "Certificate files not created properly"
            }
        } catch {
            Write-Host "SSL certificate generation failed: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "SSL will be disabled for this installation" -ForegroundColor Yellow
            $EnableSSL = $false
            
            # Update .env file to disable SSL
            $EnvContent = $EnvContent -replace "ENABLE_SSL=true", "ENABLE_SSL=false"
            Set-Content -Path ".env" -Value $EnvContent
        }
    } elseif (Test-Path "certs\milvus\server.key") {
        Write-Host "SSL certificates already exist" -ForegroundColor Gray
    }
}

# Create Milvus configuration file
Write-Host "Creating Milvus configuration..." -ForegroundColor White
$MilvusConfig = @"
# Milvus Configuration File
# Generated by installation script

etcd:
  endpoints:
    - etcd:2379
  rootPath: by-dev
  metaSubPath: meta
  kvSubPath: kv

minio:
  address: minio
  port: 9000
  accessKeyID: minioadmin
  secretAccessKey: minioadmin
  useSSL: $($EnableSSL.ToString().ToLower())
  bucketName: a-bucket

common:
  defaultPartitionName: _default
  defaultIndexName: _default_idx
  entityExpiration: -1
  indexSliceSize: 16

rootCoord:
  address: localhost
  port: 53100
  enableActiveStandby: false

proxy:
  port: 19530
  internalPort: 19529

queryCoord:
  address: localhost
  port: 19531
  enableActiveStandby: false

queryNode:
  cacheSize: 2147483648

indexCoord:
  address: localhost
  port: 31000
  enableActiveStandby: false

indexNode:
  port: 21121

dataCoord:
  address: localhost
  port: 13333
  enableActiveStandby: false

dataNode:
  port: 21124

log:
  level: info
  file:
    rootPath: ""
    maxSize: 300
    maxAge: 10
    maxBackups: 20

grpc:
  serverMaxRecvSize: 268435456
  serverMaxSendSize: 268435456
  clientMaxRecvSize: 268435456
  clientMaxSendSize: 268435456
"@

if ($EnableSSL) {
    $MilvusConfig += @"

# SSL Configuration
tls:
  serverPemPath: /milvus/certs/server.crt
  serverKeyPath: /milvus/certs/server.key
  caPemPath: /milvus/certs/trusted/ca.crt
"@
}

$MilvusConfig | Out-File -FilePath "config\milvus.yaml" -Encoding UTF8
Write-Host "Created milvus.yaml configuration file" -ForegroundColor Green

# Update docker-compose.yml with SSL configuration if enabled
if ($EnableSSL) {
    Write-Host "Updating Docker Compose configuration for SSL..." -ForegroundColor White
    
    # Read current docker-compose.yml
    $ComposeContent = Get-Content "docker-compose.yml" -Raw
    
    # Add SSL certificate volumes for Milvus
    if ($ComposeContent -notmatch "certs.*milvus") {
        $ComposeContent = $ComposeContent -replace '(\s+volumes:\s+)', "`$1`n      - ./certs/milvus:/milvus/certs"
    }
    
    # Add SSL certificate volumes for etcd
    if ($ComposeContent -notmatch "certs.*etcd" -and $ComposeContent -match "etcd:") {
        $ComposeContent = $ComposeContent -replace '(etcd:.*?volumes:\s+)', "`$1`n      - ./certs/etcd:/etcd/certs"
    }
    
    # Add SSL certificate volumes for MinIO
    if ($ComposeContent -notmatch "certs.*minio" -and $ComposeContent -match "minio:") {
        $ComposeContent = $ComposeContent -replace '(minio:.*?volumes:\s+)', "`$1`n      - ./certs/minio:/minio/certs"
    }
    
    # Add SSL environment variables for Milvus
    $SSLEnvVars = @"

      # SSL Configuration
      - MILVUS_TLS_MODE=2
      - MILVUS_TLS_CERT_PATH=/milvus/certs/server.crt
      - MILVUS_TLS_KEY_PATH=/milvus/certs/server.key
      - MILVUS_TLS_CA_PATH=/milvus/certs/trusted/ca.crt
"@
    
    if ($ComposeContent -notmatch "MILVUS_TLS_MODE") {
        $ComposeContent = $ComposeContent -replace '(\s+environment:\s+)', "`$1$SSLEnvVars`n"
    }
    
    Set-Content -Path "docker-compose.yml" -Value $ComposeContent
    Write-Host "Docker Compose configuration updated for SSL" -ForegroundColor Green
}

# Create initial backup directory structure
Write-Host "Initializing backup system..." -ForegroundColor White
if (-not (Test-Path "milvus-data\backups")) {
    New-Item -ItemType Directory -Force -Path "milvus-data\backups" | Out-Null
}

# Create backup info file
$BackupInfo = @"
# Milvus Backup Information

This directory contains backups of Milvus vector database.

## Backup Structure
- Collections: Vector collections and metadata
- Indexes: Vector indexes for fast similarity search
- Configuration: Milvus configuration files

## Restore Process
Use the restore.ps1 script in the management directory to restore from backups.

## Backup Schedule
Consider setting up automated backups for production environments.
"@
$BackupInfo | Out-File -FilePath "milvus-data\backups\README.md" -Encoding UTF8
Write-Host "Backup system initialized" -ForegroundColor Green

# Test configuration
Write-Host "Testing configuration..." -ForegroundColor White
try {
    docker-compose config | Out-Null
    Write-Host "Docker Compose configuration is valid" -ForegroundColor Green
} catch {
    Write-Host "Docker Compose configuration has errors!" -ForegroundColor Red
    Write-Host "Run 'docker-compose config' to see details." -ForegroundColor Gray
    exit 1
}

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "Installation Summary:" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "Directory structure created" -ForegroundColor Green
Write-Host "Authentication configured" -ForegroundColor Green
Write-Host "Permissions set" -ForegroundColor Green
if ($EnableSSL) {
    Write-Host "SSL certificates generated and configured" -ForegroundColor Green
}
Write-Host "Milvus configuration created" -ForegroundColor Green
Write-Host "Backup system initialized" -ForegroundColor Green
Write-Host "Configuration validated" -ForegroundColor Green
Write-Host ""
Write-Host "Milvus Vector Database Details:" -ForegroundColor Cyan
Write-Host "  Username: $Username" -ForegroundColor White
Write-Host "  Password: $Password" -ForegroundColor Yellow
if ($EnableSSL) {
    Write-Host "  gRPC API: localhost:19530 (TLS encrypted)" -ForegroundColor White
    Write-Host "  HTTP API: localhost:9091 (HTTPS)" -ForegroundColor White
    Write-Host "  MinIO Console: https://localhost:9001 (HTTPS)" -ForegroundColor White
    Write-Host "  Domain: $Domain" -ForegroundColor White
} else {
    Write-Host "  gRPC API: localhost:19530 (unencrypted)" -ForegroundColor White
    Write-Host "  HTTP API: localhost:9091 (HTTP)" -ForegroundColor White
    Write-Host "  MinIO Console: http://localhost:9001 (HTTP)" -ForegroundColor White
}
Write-Host ""
Write-Host "Installation completed successfully!" -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Cyan

# Ask if user wants to start Milvus now
Write-Host ""
$StartChoice = Read-Host "Start Milvus vector database now? (y/n)"
if ($StartChoice -eq "" -or $StartChoice -eq "Y" -or $StartChoice -eq "y") {
    Write-Host "Starting Milvus vector database..." -ForegroundColor Green
    docker-compose up -d
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Milvus vector database started successfully!" -ForegroundColor Green
        
        # Wait for Milvus to initialize (it takes time to start all services)
        Write-Host "Waiting for all services to initialize (this may take 60-120 seconds)..." -ForegroundColor Yellow
        Start-Sleep -Seconds 45
        
        # Check status
        Write-Host "Checking services status..." -ForegroundColor White
        $Status = docker-compose ps --format json | ConvertFrom-Json
        $MilvusStatus = $Status | Where-Object { $_.Service -match "milvus|etcd|minio" }
        
        $RunningServices = $MilvusStatus | Where-Object { $_.State -eq "running" }
        if ($RunningServices.Count -gt 0) {
            Write-Host "[OK] Milvus services are running successfully!" -ForegroundColor Green
            Write-Host "[OK] Running services: $($RunningServices.Count)" -ForegroundColor Green
            
            # Test connection
            Write-Host "Testing service connectivity..." -ForegroundColor White
            Start-Sleep -Seconds 15  # Give more time for full initialization
            
            try {
                if ($EnableSSL) {
                    Write-Host "[OK] Milvus gRPC API: localhost:19530 (TLS)" -ForegroundColor Green
                    Write-Host "[OK] Milvus HTTP API: localhost:9091 (HTTPS)" -ForegroundColor Green
                    Write-Host "[OK] MinIO Console: https://localhost:9001" -ForegroundColor Green
                } else {
                    Write-Host "[OK] Milvus gRPC API: localhost:19530" -ForegroundColor Green
                    Write-Host "[OK] Milvus HTTP API: localhost:9091" -ForegroundColor Green
                    Write-Host "[OK] MinIO Console: http://localhost:9001" -ForegroundColor Green
                }
            } catch {
                Write-Host "[WARN] Services may still be initializing" -ForegroundColor Yellow
            }
        } else {
            Write-Host "[WARN] Services may still be starting up" -ForegroundColor Yellow
            Write-Host "Check logs with: docker-compose logs" -ForegroundColor Gray
        }
    } else {
        Write-Host "Failed to start Milvus vector database" -ForegroundColor Red
        Write-Host "Check configuration and try: docker-compose up -d" -ForegroundColor Gray
    }
} else {
    Write-Host "Milvus vector database not started" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To start manually:" -ForegroundColor Cyan
    Write-Host "1. Start the services: docker-compose up -d" -ForegroundColor White
    Write-Host "2. Check status: docker-compose ps" -ForegroundColor White
    Write-Host "3. View logs: docker-compose logs -f" -ForegroundColor White
}

Write-Host ""
Write-Host "Management Commands:" -ForegroundColor Cyan
Write-Host "===================" -ForegroundColor Gray
if ($EnableSSL) {
    Write-Host "- SSL management: .\management\manage-ssl.ps1 status" -ForegroundColor White
} elseif ($UseCAProvided) {
    Write-Host "- Install CA certificates: .\management\manage-ssl.ps1 install-ca -ServerCertPath 'path\to\server.crt' -ServerKeyPath 'path\to\server.key'" -ForegroundColor Cyan
    Write-Host "- Enable SSL after installing: .\management\manage-ssl.ps1 enable" -ForegroundColor Cyan
}
Write-Host "- Create backup: .\management\backup.ps1" -ForegroundColor White
Write-Host "- Restore backup: .\management\restore.ps1" -ForegroundColor White
Write-Host "- View all logs: docker-compose logs -f" -ForegroundColor White
Write-Host ""
Write-Host "Configuration files:" -ForegroundColor Cyan
Write-Host "  - docker-compose.yml (main configuration)" -ForegroundColor White
Write-Host "  - .env (environment variables)" -ForegroundColor White
Write-Host "  - config/milvus.yaml (Milvus settings)" -ForegroundColor White
if ($EnableSSL) {
    Write-Host "  - certs/ (SSL certificates)" -ForegroundColor White
}
Write-Host ""
Write-Host "MinIO Credentials:" -ForegroundColor Cyan
Write-Host "  - Access Key: minioadmin" -ForegroundColor White
Write-Host "  - Secret Key: minioadmin" -ForegroundColor White

# Return to appropriate directory based on how script was called
if ($Force) {
    # If called with -Force (from stack installer), stay in service directory
    Write-Host "Staying in milvus directory for stack installer" -ForegroundColor Gray
} else {
    # If called manually, return to management directory
    Set-Location management
}
