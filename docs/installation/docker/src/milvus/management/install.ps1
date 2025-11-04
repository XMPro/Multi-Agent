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
    Set-Location ..
    Write-Host "Changed from management directory to milvus directory" -ForegroundColor Gray
} elseif (Test-Path "management") {
    Write-Host "Already in milvus directory" -ForegroundColor Gray
} else {
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
    $MilvusContainers = $ExistingContainers | Where-Object { $_.Service -match "milvus|etcd|minio|attu" }
    
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
    "tls"
)

foreach ($Dir in $Directories) {
    if (-not (Test-Path $Dir)) {
        New-Item -ItemType Directory -Force -Path $Dir | Out-Null
        Write-Host "Created directory: $Dir" -ForegroundColor Green
    } else {
        Write-Host "Directory exists: $Dir" -ForegroundColor Gray
    }
}

# Ask about GPU support
Write-Host "GPU Configuration:" -ForegroundColor White
$GPUChoice = Read-Host "Enable GPU support for Milvus? (requires NVIDIA GPU and Docker runtime) (y/n)"
$EnableGPU = $false
if ($GPUChoice -eq "Y" -or $GPUChoice -eq "y") {
    $EnableGPU = $true
    Write-Host "GPU support will be enabled" -ForegroundColor Green
    
    Write-Host "GPU Device Selection:" -ForegroundColor White
    Write-Host "Enter GPU device IDs (comma-separated, e.g., '0' or '0,1')" -ForegroundColor Gray
    Write-Host "Leave empty to use GPU 0" -ForegroundColor Gray
    $GPUDevices = Read-Host "GPU device IDs"
    if (-not $GPUDevices) {
        $GPUDevices = "0"
    }
    Write-Host "Will use GPU device(s): $GPUDevices" -ForegroundColor White
} else {
    Write-Host "GPU support will be disabled (CPU only)" -ForegroundColor Yellow
}

# Ask about SSL setup (unless already specified via parameter)
if (-not $PSBoundParameters.ContainsKey('EnableSSL')) {
    Write-Host ""
    Write-Host "SSL Configuration:" -ForegroundColor White
    $SSLChoice = Read-Host "Enable SSL/TLS encryption for Milvus? (y/n)"
    if ($SSLChoice -eq "Y" -or $SSLChoice -eq "y") {
        $EnableSSL = $true
    }
}

if ($EnableSSL) {
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
        $EnableSSL = $false
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
        # Use safe charset for .env compatibility
        $SafeChars = (65..90) + (97..122) + (48..57) + @(95, 45)  # A-Z, a-z, 0-9, _, -
        $Password = -join ($SafeChars | Get-Random -Count 18 | ForEach-Object {[char]$_})
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

# Generate MinIO credentials
Write-Host "Generating MinIO credentials..." -ForegroundColor White
$SafeChars = (65..90) + (97..122) + (48..57) + @(95, 45)
$MinIOAccessKey = -join ($SafeChars | Get-Random -Count 16 | ForEach-Object {[char]$_})
$MinIOSecretKey = -join ($SafeChars | Get-Random -Count 32 | ForEach-Object {[char]$_})
Write-Host "Generated MinIO Access Key: $MinIOAccessKey" -ForegroundColor Green
Write-Host "Generated MinIO Secret Key: $MinIOSecretKey" -ForegroundColor Green

# Update .env file with configuration
Write-Host "Creating configuration files..." -ForegroundColor White
$EnvContent = @"
# Milvus Authentication
MILVUS_AUTH_ENABLED=true
MILVUS_ROOT_PASSWORD=$Password

# SSL Configuration
ENABLE_SSL=$($EnableSSL.ToString().ToLower())
SSL_DOMAIN=$Domain

# Milvus Ports
MILVUS_PORT=19530
MILVUS_HTTP_PORT=8080

# MinIO Configuration (Randomly Generated)
MINIO_ROOT_USER=$MinIOAccessKey
MINIO_ROOT_PASSWORD=$MinIOSecretKey

# Timezone
TZ=UTC
"@

$EnvContent | Out-File -FilePath ".env" -Encoding ASCII
Write-Host "Created .env file with configuration" -ForegroundColor Green

# Set proper permissions for data directories
Write-Host "Setting directory permissions..." -ForegroundColor White
icacls "milvus-data" /grant "Everyone:(OI)(CI)F" /T | Out-Null
Write-Host "Directory permissions configured" -ForegroundColor Green

# SSL Certificate setup
if ($EnableSSL) {
    Write-Host "Setting up SSL certificates..." -ForegroundColor White
    
    if (-not (Test-Path "tls\server.key") -or $Force) {
        Write-Host "Generating SSL certificates for Milvus..." -ForegroundColor Gray
        
        try {
            Write-Host "Generating certificates using OpenSSL in Docker..." -ForegroundColor Gray
            
            # Create server extension
            @"
[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
[alt_names]
DNS.1 = $Domain
DNS.2 = localhost
IP.1  = 127.0.0.1
"@ | Out-File -FilePath "tls\server-ext.cnf" -Encoding ASCII
            
            # Create client extension
            @"
[v3_req_client]
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth
"@ | Out-File -FilePath "tls\client-ext.cnf" -Encoding ASCII
            
            # Generate CA
            docker run --rm -v "${PWD}\tls:/tls" -w /tls alpine/openssl genrsa -out ca.key 2048
            docker run --rm -v "${PWD}\tls:/tls" -w /tls alpine/openssl req -x509 -new -key ca.key -sha256 -days 3650 -out ca.pem -subj "/C=US/ST=State/L=City/O=Milvus/CN=$Domain" -addext "basicConstraints=critical,CA:TRUE" -addext "keyUsage=keyCertSign,cRLSign"
            
            # Generate server cert
            Write-Host "Generating server certificates..." -ForegroundColor Gray
            docker run --rm -v "${PWD}\tls:/tls" -w /tls alpine/openssl genrsa -out server.key 2048
            docker run --rm -v "${PWD}\tls:/tls" -w /tls alpine/openssl req -new -key server.key -subj "/C=US/ST=State/L=City/O=Milvus/CN=$Domain" -out server.csr
            docker run --rm -v "${PWD}\tls:/tls" -w /tls alpine/openssl x509 -req -days 3650 -in server.csr -CA ca.pem -CAkey ca.key -CAcreateserial -out server.pem -extfile server-ext.cnf -extensions v3_req
            
            # Generate client cert
            Write-Host "Generating client certificates..." -ForegroundColor Gray
            docker run --rm -v "${PWD}\tls:/tls" -w /tls alpine/openssl genrsa -out client.key 2048
            docker run --rm -v "${PWD}\tls:/tls" -w /tls alpine/openssl req -new -key client.key -subj "/C=US/ST=State/L=City/O=Milvus/CN=$Domain" -out client.csr
            docker run --rm -v "${PWD}\tls:/tls" -w /tls alpine/openssl x509 -req -days 3650 -in client.csr -CA ca.pem -CAkey ca.key -CAcreateserial -out client.pem -extfile client-ext.cnf -extensions v3_req_client
            
            # Cleanup
            Remove-Item "tls\*.csr" -ErrorAction SilentlyContinue
            Remove-Item "tls\*.srl" -ErrorAction SilentlyContinue
            Remove-Item "tls\*.cnf" -ErrorAction SilentlyContinue
            
            if ((Test-Path "tls\server.key") -and (Test-Path "tls\server.pem") -and (Test-Path "tls\ca.pem")) {
                Write-Host "SSL certificates generated successfully" -ForegroundColor Green
                Write-Host "SSL certificate generation complete" -ForegroundColor Green
                Write-Host "Note: alpine/openssl image preserved for future SSL operations" -ForegroundColor Gray
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
    } elseif (Test-Path "tls\server.key") {
        Write-Host "SSL certificates already exist" -ForegroundColor Gray
    }
}

# Create Milvus configuration file
Write-Host "Creating Milvus configuration..." -ForegroundColor White

if ($EnableSSL) {
    $MilvusConfig = @"
# Milvus Configuration File
etcd:
  endpoints: [etcd:2379]
minio:
  address: minio
  port: 9000
  accessKeyID: $MinIOAccessKey
  secretAccessKey: $MinIOSecretKey
  useSSL: false
common:
  security:
    tlsMode: 1
  defaultPartitionName: _default
proxy:
  grpc:
    serverAddress: 0.0.0.0
  port: 19530
  http:
    enabled: true
    port: 8080
log:
  level: info
grpc:
  serverMaxRecvSize: 268435456
tls:
  serverPemPath: /milvus/tls/server.pem
  serverKeyPath: /milvus/tls/server.key
  caPemPath: /milvus/tls/ca.pem
"@
} else {
    $MilvusConfig = @"
# Milvus Configuration File
etcd:
  endpoints: [etcd:2379]
minio:
  address: minio
  port: 9000
  accessKeyID: $MinIOAccessKey
  secretAccessKey: $MinIOSecretKey
  useSSL: false
common:
  defaultPartitionName: _default
proxy:
  grpc:
    serverAddress: 0.0.0.0
  port: 19530
  http:
    enabled: true
    port: 8080
log:
  level: info
grpc:
  serverMaxRecvSize: 268435456
"@
}

if ($EnableGPU) {
    $MilvusConfig += @"

gpu:
  initMemSize: 1024
  maxMemSize: 2048
"@
}

$MilvusConfig | Out-File -FilePath "user.yaml" -Encoding UTF8
Write-Host "Created user.yaml configuration file" -ForegroundColor Green

# Create nginx configuration for Attu SSL
if ($EnableSSL) {
    Write-Host "Creating nginx configuration for Attu HTTPS..." -ForegroundColor White
    $NginxConfig = @"
events {
    worker_connections 1024;
}

http {
    upstream attu {
        server attu:3000;
    }

    # Redirect HTTP to HTTPS
    server {
        listen 80;
        server_name $Domain;
        return 301 https://`$host`$request_uri;
    }

    # HTTPS server
    server {
        listen 443 ssl;
        server_name $Domain;

        ssl_certificate /etc/nginx/ssl/server.pem;
        ssl_certificate_key /etc/nginx/ssl/server.key;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers HIGH:!aNULL:!MD5;
        ssl_prefer_server_ciphers on;

        location / {
            proxy_pass http://attu;
            proxy_set_header Host `$host;
            proxy_set_header X-Real-IP `$remote_addr;
            proxy_set_header X-Forwarded-For `$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto `$scheme;
            proxy_http_version 1.1;
            proxy_set_header Upgrade `$http_upgrade;
            proxy_set_header Connection "upgrade";
        }
    }
}
"@
    $NginxConfig | Out-File -FilePath "nginx.conf" -Encoding ASCII
    Write-Host "Created nginx.conf for Attu HTTPS" -ForegroundColor Green
} else {
    # Create simple nginx config without SSL
    Write-Host "Creating nginx configuration for Attu HTTP..." -ForegroundColor White
    $NginxConfig = @"
events {
    worker_connections 1024;
}

http {
    upstream attu {
        server attu:3000;
    }

    server {
        listen 80;
        server_name $Domain;

        location / {
            proxy_pass http://attu;
            proxy_set_header Host `$host;
            proxy_set_header X-Real-IP `$remote_addr;
            proxy_set_header X-Forwarded-For `$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto `$scheme;
            proxy_http_version 1.1;
            proxy_set_header Upgrade `$http_upgrade;
            proxy_set_header Connection "upgrade";
        }
    }
}
"@
    $NginxConfig | Out-File -FilePath "nginx.conf" -Encoding ASCII
    Write-Host "Created nginx.conf for Attu HTTP" -ForegroundColor Green
}

# Configure GPU in docker-compose.yml if enabled
if ($EnableGPU) {
    Write-Host "Configuring GPU support in docker-compose.yml..." -ForegroundColor White
    
    $ComposeContent = Get-Content "docker-compose.yml" -Raw
    $ComposeContent = $ComposeContent -replace 'image:\s*milvusdb/milvus:([^\s]+)', 'image: milvusdb/milvus:v2.6.3-gpu'
    
    $DeviceList = ($GPUDevices -split ',' | ForEach-Object { "`"$($_.Trim())`"" }) -join ', '
    $GPUConfig = "`n          devices:`n            - driver: nvidia`n              capabilities: [`"gpu`"]`n              device_ids: [$DeviceList]"
    $ComposeContent = $ComposeContent -replace '(standalone:[\s\S]*?memory: 4G)', "`$1$GPUConfig"
    
    Set-Content -Path "docker-compose.yml" -Value $ComposeContent
    Write-Host "GPU configuration added to docker-compose.yml" -ForegroundColor Green
    Write-Host "Using GPU device(s): $GPUDevices" -ForegroundColor Green
}

# Initialize backup system
Write-Host "Initializing backup system..." -ForegroundColor White
if (-not (Test-Path "milvus-data\backups")) {
    New-Item -ItemType Directory -Force -Path "milvus-data\backups" | Out-Null
}

$BackupInfo = @"
# Milvus Backup Information
This directory contains backups of Milvus vector database.
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
    Write-Host "  HTTP API: localhost:8080 (HTTPS)" -ForegroundColor White
    Write-Host "  Attu Web UI: https://localhost:8001 (HTTPS)" -ForegroundColor White
    Write-Host "  Attu HTTP Redirect: http://localhost:8002 -> https://localhost:8001" -ForegroundColor Gray
    Write-Host "  Domain: $Domain" -ForegroundColor White
} else {
    Write-Host "  gRPC API: localhost:19530 (unencrypted)" -ForegroundColor White
    Write-Host "  HTTP API: localhost:8080 (HTTP)" -ForegroundColor White
    Write-Host "  Attu Web UI: http://localhost:8002" -ForegroundColor White
}
Write-Host "  MinIO Console: http://localhost:9001" -ForegroundColor White
Write-Host ""
Write-Host "MinIO Credentials:" -ForegroundColor Cyan
Write-Host "  Access Key: $MinIOAccessKey" -ForegroundColor Yellow
Write-Host "  Secret Key: $MinIOSecretKey" -ForegroundColor Yellow
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
        
        Write-Host "Waiting for services to initialize (this may take 60-90 seconds)..." -ForegroundColor Yellow
        Start-Sleep -Seconds 30
        
        Write-Host "Checking services status..." -ForegroundColor White
        $Status = docker-compose ps --format json | ConvertFrom-Json
        $MilvusStatus = $Status | Where-Object { $_.Service -match "standalone|attu" }
        
        if ($MilvusStatus -and ($MilvusStatus | Where-Object { $_.State -eq "running" })) {
            Write-Host "[OK] Milvus services are running successfully!" -ForegroundColor Green
            
            Start-Sleep -Seconds 30
            
            if ($EnableSSL) {
                Write-Host "[OK] Access Milvus at: https://localhost:19530 (with SSL)" -ForegroundColor Green
                Write-Host "[OK] Access Attu at: https://localhost:8001 (with SSL)" -ForegroundColor Green
                Write-Host "[INFO] Attu connects to Milvus using SSL internally" -ForegroundColor Cyan
                Write-Host "[INFO] Your external clients should use SSL to connect to Milvus" -ForegroundColor Cyan
            } else {
                Write-Host "[OK] Access Milvus at: localhost:19530" -ForegroundColor Green
                Write-Host "[OK] Access Attu at: http://localhost:8002" -ForegroundColor Green
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
    Write-Host "- Install CA certificates: .\management\manage-ssl.ps1 install-ca" -ForegroundColor Cyan
    Write-Host "- Enable SSL after installing: .\management\manage-ssl.ps1 enable" -ForegroundColor Cyan
}
Write-Host "- Create backup: .\management\backup.ps1" -ForegroundColor White
Write-Host "- Restore backup: .\management\restore.ps1" -ForegroundColor White
Write-Host ""
Write-Host "Configuration files:" -ForegroundColor Cyan
Write-Host "  - docker-compose.yml (main configuration)" -ForegroundColor White
Write-Host "  - .env (environment variables)" -ForegroundColor White
Write-Host "  - user.yaml (Milvus settings)" -ForegroundColor White
if ($EnableSSL) {
    Write-Host "  - tls/ (SSL certificates)" -ForegroundColor White
}

# Return to appropriate directory based on how script was called
if ($Force) {
    Write-Host "Staying in milvus directory for stack installer" -ForegroundColor Gray
} else {
    Set-Location management
}
