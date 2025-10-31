# =================================================================
# Milvus SSL Certificate Management Script
# =================================================================

param(
    [ValidateSet("generate", "enable", "disable", "status", "renew", "install-ca")]
    [string]$Action = "",
    
    [string]$Domain = "localhost",
    [int]$ValidDays = 365,
    [string]$CACertPath = "",
    [string]$CAKeyPath = "",
    [string]$ServerCertPath = "",
    [string]$ServerKeyPath = "",
    [switch]$Force = $false
)

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "Milvus SSL Certificate Management Script" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

# Show help if no action provided
if (-not $Action) {
    Write-Host "Usage: .\manage-ssl.ps1 <action> [options]" -ForegroundColor White
    Write-Host ""
    Write-Host "Actions:" -ForegroundColor Cyan
    Write-Host "  generate      Generate new self-signed SSL certificates" -ForegroundColor White
    Write-Host "  install-ca    Install CA-provided SSL certificates" -ForegroundColor White
    Write-Host "  enable        Enable SSL in Milvus" -ForegroundColor White
    Write-Host "  disable       Disable SSL in Milvus" -ForegroundColor White
    Write-Host "  status        Show SSL certificate status" -ForegroundColor White
    Write-Host "  renew         Renew existing SSL certificates" -ForegroundColor White
    Write-Host ""
    Write-Host "Parameters:" -ForegroundColor Cyan
    Write-Host "  -Domain         Certificate domain name (default: localhost)" -ForegroundColor White
    Write-Host "  -ValidDays      Certificate validity in days (default: 365)" -ForegroundColor White
    Write-Host "  -CACertPath     Path to CA certificate file (for install-ca)" -ForegroundColor White
    Write-Host "  -CAKeyPath      Path to CA private key file (for install-ca)" -ForegroundColor White
    Write-Host "  -ServerCertPath Path to server certificate file (for install-ca)" -ForegroundColor White
    Write-Host "  -ServerKeyPath  Path to server private key file (for install-ca)" -ForegroundColor White
    Write-Host "  -Force          Overwrite existing certificates without prompting" -ForegroundColor White
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Cyan
    Write-Host "  # Generate self-signed certificates" -ForegroundColor Gray
    Write-Host "  .\manage-ssl.ps1 generate" -ForegroundColor Gray
    Write-Host "  .\manage-ssl.ps1 generate -Domain 'milvus.company.com' -ValidDays 730" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  # Install CA-provided certificates" -ForegroundColor Gray
    Write-Host "  .\manage-ssl.ps1 install-ca -ServerCertPath 'C:\certs\server.crt' -ServerKeyPath 'C:\certs\server.key'" -ForegroundColor Gray
    Write-Host "  .\manage-ssl.ps1 install-ca -CACertPath 'C:\certs\ca.crt' -ServerCertPath 'C:\certs\server.crt' -ServerKeyPath 'C:\certs\server.key'" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  # Management commands" -ForegroundColor Gray
    Write-Host "  .\manage-ssl.ps1 enable" -ForegroundColor Gray
    Write-Host "  .\manage-ssl.ps1 status" -ForegroundColor Gray
    Write-Host "  .\manage-ssl.ps1 renew -Force" -ForegroundColor Gray
    Write-Host ""
    Write-Host "==================================================================" -ForegroundColor Cyan
    exit 0
}

# Change to parent directory (milvus folder)
Set-Location ..

# Check if Docker is available
function Test-Docker {
    try {
        docker version | Out-Null
        return $true
    } catch {
        Write-Host "Docker is not available!" -ForegroundColor Red
        Write-Host "Please ensure Docker Desktop is running." -ForegroundColor Yellow
        return $false
    }
}

# Function to restart Milvus services to apply SSL changes
function Restart-Milvus {
    Write-Host "Restarting Milvus services to apply SSL changes..." -ForegroundColor Yellow
    docker-compose restart
    Start-Sleep -Seconds 15
    Write-Host "Milvus services restarted" -ForegroundColor Green
}

# Function to generate SSL certificates using Docker OpenSSL
function Generate-SSLCertificates {
    param([string]$Domain, [int]$ValidDays)
    
    Write-Host "Generating SSL certificates for domain: $Domain" -ForegroundColor White
    Write-Host "Certificate validity: $ValidDays days" -ForegroundColor Gray
    
    # Create certs directories if they don't exist
    $CertDirs = @(
        "certs", 
        "certs\milvus", "certs\etcd", "certs\minio",
        "certs\milvus\trusted", "certs\etcd\trusted", "certs\minio\trusted"
    )
    foreach ($Dir in $CertDirs) {
        if (-not (Test-Path $Dir)) {
            New-Item -ItemType Directory -Force -Path $Dir | Out-Null
            Write-Host "Created directory: $Dir" -ForegroundColor Green
        }
    }
    
    try {
        # Generate CA private key
        Write-Host "Generating CA private key..." -ForegroundColor Gray
        docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl genrsa -out ca.key 4096
        
        # Generate CA certificate
        Write-Host "Generating CA certificate..." -ForegroundColor Gray
        docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl req -new -x509 -days $ValidDays -key ca.key -out ca.crt -subj "/C=US/ST=State/L=City/O=Milvus-VectorDB/CN=Milvus-CA"
        
        # Generate Milvus server certificates
        Write-Host "Generating Milvus server certificates..." -ForegroundColor Gray
        docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl genrsa -out milvus_server.key 4096
        docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl req -new -key milvus_server.key -out milvus_server.csr -subj "/C=US/ST=State/L=City/O=Milvus-VectorDB/CN=$Domain"
        docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl x509 -req -in milvus_server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out milvus_server.crt -days $ValidDays
        
        # Generate etcd certificates
        Write-Host "Generating etcd certificates..." -ForegroundColor Gray
        docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl genrsa -out etcd_server.key 4096
        docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl req -new -key etcd_server.key -out etcd_server.csr -subj "/C=US/ST=State/L=City/O=Milvus-VectorDB/CN=etcd-$Domain"
        docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl x509 -req -in etcd_server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out etcd_server.crt -days $ValidDays
        
        # Generate MinIO certificates
        Write-Host "Generating MinIO certificates..." -ForegroundColor Gray
        docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl genrsa -out minio_server.key 4096
        docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl req -new -key minio_server.key -out minio_server.csr -subj "/C=US/ST=State/L=City/O=Milvus-VectorDB/CN=minio-$Domain"
        docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl x509 -req -in minio_server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out minio_server.crt -days $ValidDays
        
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
            Write-Host "SSL certificates generated successfully using Docker OpenSSL" -ForegroundColor Green
            
            # Clean up the alpine/openssl image
            Write-Host "Cleaning up temporary Docker image..." -ForegroundColor Gray
            docker rmi alpine/openssl -f 2>$null | Out-Null
            docker rmi alpine -f 2>$null | Out-Null
            Write-Host "Temporary Docker images removed" -ForegroundColor Green
            
            return $true
        } else {
            Write-Host "Certificate files not created properly" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "SSL certificate generation failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to install CA-provided certificates
function Install-CACertificates {
    param(
        [string]$CACertPath,
        [string]$CAKeyPath,
        [string]$ServerCertPath,
        [string]$ServerKeyPath
    )
    
    Write-Host "Installing CA-provided SSL certificates..." -ForegroundColor White
    
    # Create certs directories if they don't exist
    $CertDirs = @(
        "certs", 
        "certs\milvus", "certs\etcd", "certs\minio",
        "certs\milvus\trusted", "certs\etcd\trusted", "certs\minio\trusted"
    )
    foreach ($Dir in $CertDirs) {
        if (-not (Test-Path $Dir)) {
            New-Item -ItemType Directory -Force -Path $Dir | Out-Null
            Write-Host "Created directory: $Dir" -ForegroundColor Green
        }
    }
    
    try {
        # Validate certificate files exist
        if ($ServerCertPath -and -not (Test-Path $ServerCertPath)) {
            throw "Server certificate file not found: $ServerCertPath"
        }
        if ($ServerKeyPath -and -not (Test-Path $ServerKeyPath)) {
            throw "Server private key file not found: $ServerKeyPath"
        }
        if ($CACertPath -and -not (Test-Path $CACertPath)) {
            throw "CA certificate file not found: $CACertPath"
        }
        if ($CAKeyPath -and -not (Test-Path $CAKeyPath)) {
            throw "CA private key file not found: $CAKeyPath"
        }
        
        # Copy server certificates to all service directories
        if ($ServerCertPath -and $ServerKeyPath) {
            Copy-Item -Path $ServerCertPath -Destination "certs\milvus\server.crt" -Force
            Copy-Item -Path $ServerKeyPath -Destination "certs\milvus\server.key" -Force
            Copy-Item -Path $ServerCertPath -Destination "certs\etcd\server.crt" -Force
            Copy-Item -Path $ServerKeyPath -Destination "certs\etcd\server.key" -Force
            Copy-Item -Path $ServerCertPath -Destination "certs\minio\server.crt" -Force
            Copy-Item -Path $ServerKeyPath -Destination "certs\minio\server.key" -Force
            Write-Host "Server certificates installed for all services" -ForegroundColor Green
        }
        
        # Copy CA certificate to trusted directories
        if ($CACertPath) {
            Copy-Item -Path $CACertPath -Destination "certs\milvus\trusted\ca.crt" -Force
            Copy-Item -Path $CACertPath -Destination "certs\etcd\trusted\ca.crt" -Force
            Copy-Item -Path $CACertPath -Destination "certs\minio\trusted\ca.crt" -Force
            Write-Host "CA certificate installed to all trusted directories" -ForegroundColor Green
        }
        
        # Copy CA private key if provided (for certificate management)
        if ($CAKeyPath) {
            Copy-Item -Path $CAKeyPath -Destination "certs\ca.key" -Force
            Write-Host "CA private key installed for certificate management" -ForegroundColor Green
        }
        
        # Verify installation
        $RequiredFiles = @(
            "certs\milvus\server.key", "certs\milvus\server.crt",
            "certs\etcd\server.key", "certs\etcd\server.crt",
            "certs\minio\server.key", "certs\minio\server.crt"
        )
        $AllFilesExist = $true
        foreach ($File in $RequiredFiles) {
            if (-not (Test-Path $File)) {
                Write-Host "Missing required file: $File" -ForegroundColor Red
                $AllFilesExist = $false
            }
        }
        
        if ($AllFilesExist) {
            Write-Host "CA-provided certificates installed successfully" -ForegroundColor Green
            return $true
        } else {
            throw "Not all required certificate files were installed"
        }
    } catch {
        Write-Host "CA certificate installation failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to enable SSL in configuration
function Enable-SSL {
    Write-Host "Enabling SSL in Milvus configuration..." -ForegroundColor White
    
    # Update .env file
    if (Test-Path ".env") {
        $EnvContent = Get-Content ".env" -Raw
        $EnvContent = $EnvContent -replace "ENABLE_SSL=false", "ENABLE_SSL=true"
        Set-Content -Path ".env" -Value $EnvContent
        Write-Host "SSL enabled in .env file" -ForegroundColor Green
    }
    
    # Update milvus.yaml configuration
    if (Test-Path "config\milvus.yaml") {
        $ConfigContent = Get-Content "config\milvus.yaml" -Raw
        
        # Update MinIO SSL setting
        $ConfigContent = $ConfigContent -replace "useSSL: false", "useSSL: true"
        
        # Add TLS configuration if not present
        if ($ConfigContent -notmatch "tls:") {
            $TLSConfig = @"

# SSL Configuration
tls:
  serverPemPath: /milvus/certs/server.crt
  serverKeyPath: /milvus/certs/server.key
  caPemPath: /milvus/certs/trusted/ca.crt
"@
            $ConfigContent += $TLSConfig
        }
        
        Set-Content -Path "config\milvus.yaml" -Value $ConfigContent
        Write-Host "SSL enabled in milvus.yaml" -ForegroundColor Green
    }
    
    # Update docker-compose.yml
    if (Test-Path "docker-compose.yml") {
        $ComposeContent = Get-Content "docker-compose.yml" -Raw
        
        # Add SSL certificate volumes for etcd
        if ($ComposeContent -notmatch "certs/etcd") {
            $ComposeContent = $ComposeContent -replace '(\s+- \.\/milvus-data\/etcd:\/etcd)', "`$1`n      - ./certs/etcd:/etcd/certs"
        }
        
        # Add SSL certificate volumes for MinIO
        if ($ComposeContent -notmatch "certs/minio") {
            $ComposeContent = $ComposeContent -replace '(\s+- \.\/milvus-data\/minio:\/minio_data)', "`$1`n      - ./certs/minio:/minio/certs"
        }
        
        # Add SSL certificate volumes for Milvus standalone
        if ($ComposeContent -notmatch "certs/milvus") {
            $ComposeContent = $ComposeContent -replace '(\s+- \.\/milvus-data\/milvus:\/var\/lib\/milvus)', "`$1`n      - ./certs/milvus:/milvus/certs"
        }
        
        # Add SSL environment variables for Milvus standalone
        $SSLEnvVars = @"
      # SSL Configuration
      - MILVUS_TLS_MODE=2
      - MILVUS_TLS_CERT_PATH=/milvus/certs/server.crt
      - MILVUS_TLS_KEY_PATH=/milvus/certs/server.key
      - MILVUS_TLS_CA_PATH=/milvus/certs/trusted/ca.crt"@
        
        if ($ComposeContent -notmatch "MILVUS_TLS_MODE") {
            $ComposeContent = $ComposeContent -replace '(\s+COMMON_SECURITY_DEFAULTROOTPASSWORD: \$\{MILVUS_ROOT_PASSWORD:-Milvus\})', "`$1`n$SSLEnvVars"
        }
        
        # Update MinIO to use HTTPS
        if ($ComposeContent -match "minio:") {
            $ComposeContent = $ComposeContent -replace '(MINIO_ROOT_PASSWORD: \$\{MINIO_ROOT_PASSWORD:-minioadmin\})', "`$1`n      MINIO_SERVER_URL: https://minio:9000"
        }
        
        Set-Content -Path "docker-compose.yml" -Value $ComposeContent
        Write-Host "SSL enabled in docker-compose.yml" -ForegroundColor Green
    }
}

# Function to disable SSL in configuration
function Disable-SSL {
    Write-Host "Disabling SSL in Milvus configuration..." -ForegroundColor White
    
    # Update .env file
    if (Test-Path ".env") {
        $EnvContent = Get-Content ".env" -Raw
        $EnvContent = $EnvContent -replace "ENABLE_SSL=true", "ENABLE_SSL=false"
        Set-Content -Path ".env" -Value $EnvContent
        Write-Host "SSL disabled in .env file" -ForegroundColor Green
    }
    
    # Update milvus.yaml configuration
    if (Test-Path "config\milvus.yaml") {
        $ConfigContent = Get-Content "config\milvus.yaml" -Raw
        
        # Update MinIO SSL setting
        $ConfigContent = $ConfigContent -replace "useSSL: true", "useSSL: false"
        
        # Remove TLS configuration
        $ConfigContent = $ConfigContent -replace '(?s)\n# SSL Configuration.*?caPemPath: \/milvus\/certs\/trusted\/ca\.crt', ""
        
        Set-Content -Path "config\milvus.yaml" -Value $ConfigContent
        Write-Host "SSL disabled in milvus.yaml" -ForegroundColor Green
    }
    
    # Update docker-compose.yml
    if (Test-Path "docker-compose.yml") {
        $ComposeContent = Get-Content "docker-compose.yml" -Raw
        
        # Remove SSL certificate volumes
        $ComposeContent = $ComposeContent -replace '\s+- \.\/certs\/milvus:\/milvus\/certs\n', ""
        $ComposeContent = $ComposeContent -replace '\s+- \.\/certs\/etcd:\/etcd\/certs\n', ""
        $ComposeContent = $ComposeContent -replace '\s+- \.\/certs\/minio:\/minio\/certs\n', ""
        
        # Remove SSL environment variables
        $ComposeContent = $ComposeContent -replace '(?s)\s+# SSL Configuration.*?- MILVUS_TLS_CA_PATH=\/milvus\/certs\/trusted\/ca\.crt', ""
        
        Set-Content -Path "docker-compose.yml" -Value $ComposeContent
        Write-Host "SSL disabled in docker-compose.yml" -ForegroundColor Green
    }
}

# Function to show SSL status
function Show-SSLStatus {
    Write-Host "SSL Certificate Status:" -ForegroundColor White
    Write-Host "======================" -ForegroundColor Gray
    
    # Check if certificates exist
    $CertFiles = @(
        @{Path="certs\milvus\server.key"; Name="Milvus Private Key"},
        @{Path="certs\milvus\server.crt"; Name="Milvus Certificate"},
        @{Path="certs\etcd\server.key"; Name="etcd Private Key"},
        @{Path="certs\etcd\server.crt"; Name="etcd Certificate"},
        @{Path="certs\minio\server.key"; Name="MinIO Private Key"},
        @{Path="certs\minio\server.crt"; Name="MinIO Certificate"},
        @{Path="certs\milvus\trusted\ca.crt"; Name="Milvus CA Certificate"},
        @{Path="certs\etcd\trusted\ca.crt"; Name="etcd CA Certificate"},
        @{Path="certs\minio\trusted\ca.crt"; Name="MinIO CA Certificate"}
    )
    
    $AllCertsExist = $true
    
    foreach ($CertFile in $CertFiles) {
        if (Test-Path $CertFile.Path) {
            $FileInfo = Get-Item $CertFile.Path
            Write-Host "$($CertFile.Name) - $($FileInfo.Length) bytes - Created: $($FileInfo.LastWriteTime)" -ForegroundColor Green
        } else {
            Write-Host "$($CertFile.Name) - Missing" -ForegroundColor Red
            $AllCertsExist = $false
        }
    }
    
    # Show certificate expiry information
    if ($AllCertsExist) {
        Write-Host ""
        Write-Host "Certificate Expiry:" -ForegroundColor White
        Write-Host "==================" -ForegroundColor Gray
        
        try {
            # Check Milvus certificate expiry
            $MilvusExpiryInfo = docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl x509 -in milvus/server.crt -noout -dates
            if ($MilvusExpiryInfo) {
                $NotAfterLine = $MilvusExpiryInfo | Where-Object { $_ -match "notAfter=" }
                if ($NotAfterLine) {
                    $ExpiryDateStr = ($NotAfterLine -split "notAfter=")[1]
                    Write-Host "Milvus Certificate Expires: $ExpiryDateStr" -ForegroundColor White
                }
            }
            
            # Check etcd certificate expiry
            $EtcdExpiryInfo = docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl x509 -in etcd/server.crt -noout -dates
            if ($EtcdExpiryInfo) {
                $NotAfterLine = $EtcdExpiryInfo | Where-Object { $_ -match "notAfter=" }
                if ($NotAfterLine) {
                    $ExpiryDateStr = ($NotAfterLine -split "notAfter=")[1]
                    Write-Host "etcd Certificate Expires: $ExpiryDateStr" -ForegroundColor White
                }
            }
            
            # Check MinIO certificate expiry
            $MinioExpiryInfo = docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl x509 -in minio/server.crt -noout -dates
            if ($MinioExpiryInfo) {
                $NotAfterLine = $MinioExpiryInfo | Where-Object { $_ -match "notAfter=" }
                if ($NotAfterLine) {
                    $ExpiryDateStr = ($NotAfterLine -split "notAfter=")[1]
                    Write-Host "MinIO Certificate Expires: $ExpiryDateStr" -ForegroundColor White
                }
            }
            
            # Clean up the alpine/openssl image
            docker rmi alpine/openssl -f 2>$null | Out-Null
        } catch {
            Write-Host "Could not check certificate expiry" -ForegroundColor Yellow
        }
    }
    
    # Check configuration status
    Write-Host ""
    Write-Host "Configuration Status:" -ForegroundColor White
    Write-Host "====================" -ForegroundColor Gray
    
    if (Test-Path ".env") {
        $EnvContent = Get-Content ".env" -Raw
        if ($EnvContent -match "ENABLE_SSL=true") {
            Write-Host "SSL enabled in environment" -ForegroundColor Green
        } else {
            Write-Host "SSL disabled in environment" -ForegroundColor Red
        }
    }
    
    if (Test-Path "config\milvus.yaml") {
        $ConfigContent = Get-Content "config\milvus.yaml" -Raw
        if ($ConfigContent -match "useSSL: true") {
            Write-Host "MinIO SSL enabled" -ForegroundColor Green
        } else {
            Write-Host "MinIO SSL disabled" -ForegroundColor Red
        }
        
        if ($ConfigContent -match "tls:") {
            Write-Host "Milvus TLS configuration present" -ForegroundColor Green
        } else {
            Write-Host "Milvus TLS configuration missing" -ForegroundColor Red
        }
    }
    
    if (Test-Path "docker-compose.yml") {
        $ComposeContent = Get-Content "docker-compose.yml" -Raw
        if ($ComposeContent -match "MILVUS_TLS_MODE=2") {
            Write-Host "Milvus TLS mode enabled" -ForegroundColor Green
        } else {
            Write-Host "Milvus TLS mode disabled" -ForegroundColor Red
        }
    }
}

# Main script logic
switch ($Action) {
    "generate" {
        if (-not (Test-Docker)) { exit 1 }
        
        if ((Test-Path "certs\milvus\server.crt") -and -not $Force) {
            Write-Host "SSL certificates already exist!" -ForegroundColor Red
            Write-Host "Use -Force to overwrite existing certificates." -ForegroundColor Yellow
            exit 1
        }
        
        if (Generate-SSLCertificates -Domain $Domain -ValidDays $ValidDays) {
            Write-Host ""
            Write-Host "SSL certificates generated successfully!" -ForegroundColor Green
            Write-Host "Domain: $Domain" -ForegroundColor White
            Write-Host "Valid for: $ValidDays days" -ForegroundColor White
            Write-Host ""
            Write-Host "Use 'manage-ssl.ps1 enable' to activate SSL in Milvus." -ForegroundColor Cyan
        }
    }
    
    "install-ca" {
        if (-not $ServerCertPath -or -not $ServerKeyPath) {
            Write-Host "Server certificate and private key paths are required!" -ForegroundColor Red
            Write-Host "Use -ServerCertPath and -ServerKeyPath parameters." -ForegroundColor Yellow
            exit 1
        }
        
        if (Install-CACertificates -CACertPath $CACertPath -CAKeyPath $CAKeyPath -ServerCertPath $ServerCertPath -ServerKeyPath $ServerKeyPath) {
            Write-Host ""
            Write-Host "CA-provided certificates installed successfully!" -ForegroundColor Green
            Write-Host ""
            Write-Host "Use 'manage-ssl.ps1 enable' to activate SSL in Milvus." -ForegroundColor Cyan
        }
    }
    
    "enable" {
        if (-not (Test-Path "certs\milvus\server.crt") -or -not (Test-Path "certs\etcd\server.crt") -or -not (Test-Path "certs\minio\server.crt")) {
            Write-Host "SSL certificates not found!" -ForegroundColor Red
            Write-Host "Run 'manage-ssl.ps1 generate' or 'manage-ssl.ps1 install-ca' first." -ForegroundColor Yellow
            exit 1
        }
        
        Enable-SSL
        Restart-Milvus
        
        Write-Host ""
        Write-Host "SSL enabled successfully!" -ForegroundColor Green
        Write-Host "Milvus gRPC API: localhost:19530 (TLS encrypted)" -ForegroundColor White
        Write-Host "Milvus HTTP API: localhost:9091 (HTTPS)" -ForegroundColor White
        Write-Host "MinIO Console: https://localhost:9001 (HTTPS)" -ForegroundColor White
        Write-Host "Connect using SSL/TLS with your Milvus client." -ForegroundColor Cyan
    }
    
    "disable" {
        Disable-SSL
        Restart-Milvus
        
        Write-Host ""
        Write-Host "SSL disabled successfully!" -ForegroundColor Green
        Write-Host "Milvus will only accept unencrypted connections." -ForegroundColor Yellow
        Write-Host "gRPC API: localhost:19530" -ForegroundColor White
        Write-Host "HTTP API: localhost:9091" -ForegroundColor White
        Write-Host "MinIO Console: http://localhost:9001" -ForegroundColor White
    }
    
    "status" {
        Show-SSLStatus
    }
    
    "renew" {
        if (-not (Test-Docker)) { exit 1 }
        
        if (-not (Test-Path "certs\milvus\server.crt")) {
            Write-Host "No existing certificates to renew!" -ForegroundColor Red
            Write-Host "Run 'manage-ssl.ps1 generate' to create new certificates." -ForegroundColor Yellow
            exit 1
        }
        
        Write-Host "Renewing SSL certificates..." -ForegroundColor White
        
        # Backup existing certificates
        $BackupDir = "certs\backup-$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
        Copy-Item -Path "certs\milvus\*" -Destination "$BackupDir\milvus\" -Recurse -Force -ErrorAction SilentlyContinue
        Copy-Item -Path "certs\etcd\*" -Destination "$BackupDir\etcd\" -Recurse -Force -ErrorAction SilentlyContinue
        Copy-Item -Path "certs\minio\*" -Destination "$BackupDir\minio\" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Existing certificates backed up to: $BackupDir" -ForegroundColor Green
        
        if (Generate-SSLCertificates -Domain $Domain -ValidDays $ValidDays) {
            Restart-Milvus
            Write-Host ""
            Write-Host "SSL certificates renewed successfully!" -ForegroundColor Green
            Write-Host "Domain: $Domain" -ForegroundColor White
            Write-Host "Valid for: $ValidDays days" -ForegroundColor White
        }
    }
}

Write-Host ""
Write-Host "SSL management completed!" -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Cyan

# Return to management directory
Set-Location management
