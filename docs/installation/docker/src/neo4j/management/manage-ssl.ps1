# =================================================================
# Neo4j SSL Certificate Management Script
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
Write-Host "Neo4j SSL Certificate Management Script" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

# Show help if no action provided
if (-not $Action) {
    Write-Host "Usage: .\manage-ssl.ps1 <action> [options]" -ForegroundColor White
    Write-Host ""
    Write-Host "Actions:" -ForegroundColor Cyan
    Write-Host "  generate      Generate new self-signed SSL certificates" -ForegroundColor White
    Write-Host "  install-ca    Install CA-provided SSL certificates" -ForegroundColor White
    Write-Host "  enable        Enable SSL in Neo4j" -ForegroundColor White
    Write-Host "  disable       Disable SSL in Neo4j" -ForegroundColor White
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
    Write-Host "  .\manage-ssl.ps1 generate -Domain 'neo4j.company.com' -ValidDays 730" -ForegroundColor Gray
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

# Change to parent directory (neo4j folder)
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

# Function to restart Neo4j to apply SSL changes
function Restart-Neo4j {
    Write-Host "Restarting Neo4j to apply SSL changes..." -ForegroundColor Yellow
    docker-compose restart neo4j
    Start-Sleep -Seconds 10
    Write-Host "Neo4j restarted" -ForegroundColor Green
}

# Function to generate SSL certificates using Docker OpenSSL
function Generate-SSLCertificates {
    param([string]$Domain, [int]$ValidDays)
    
    Write-Host "Generating SSL certificates for domain: $Domain" -ForegroundColor White
    Write-Host "Certificate validity: $ValidDays days" -ForegroundColor Gray
    
    # Create certs directories if they don't exist
    $CertDirs = @("certs", "certs\bolt", "certs\https", "certs\bolt\trusted", "certs\https\trusted")
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
        docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl req -new -x509 -days $ValidDays -key ca.key -out ca.crt -subj "/C=US/ST=State/L=City/O=Neo4j-Database/CN=Neo4j-CA"
        
        # Generate Bolt protocol certificates
        Write-Host "Generating Bolt protocol certificates..." -ForegroundColor Gray
        docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl genrsa -out bolt_private.key 4096
        docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl req -new -key bolt_private.key -out bolt.csr -subj "/C=US/ST=State/L=City/O=Neo4j-Database/CN=$Domain"
        docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl x509 -req -in bolt.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out bolt_public.crt -days $ValidDays
        
        # Generate HTTPS certificates
        Write-Host "Generating HTTPS certificates..." -ForegroundColor Gray
        docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl genrsa -out https_private.key 4096
        docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl req -new -key https_private.key -out https.csr -subj "/C=US/ST=State/L=City/O=Neo4j-Database/CN=$Domain"
        docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl x509 -req -in https.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out https_public.crt -days $ValidDays
        
        # Move certificates to proper directories
        docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine sh -c "
            mv bolt_private.key bolt/private.key &&
            mv bolt_public.crt bolt/public.crt &&
            cp ca.crt bolt/trusted/ca.crt &&
            mv https_private.key https/private.key &&
            mv https_public.crt https/public.crt &&
            cp ca.crt https/trusted/ca.crt &&
            rm -f *.csr ca.srl
        "
        
        # Verify certificates were created
        if ((Test-Path "certs\bolt\private.key") -and (Test-Path "certs\bolt\public.crt") -and 
            (Test-Path "certs\https\private.key") -and (Test-Path "certs\https\public.crt")) {
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
    $CertDirs = @("certs", "certs\bolt", "certs\https", "certs\bolt\trusted", "certs\https\trusted")
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
        
        # Copy server certificates to both Bolt and HTTPS directories
        if ($ServerCertPath -and $ServerKeyPath) {
            Copy-Item -Path $ServerCertPath -Destination "certs\bolt\public.crt" -Force
            Copy-Item -Path $ServerKeyPath -Destination "certs\bolt\private.key" -Force
            Copy-Item -Path $ServerCertPath -Destination "certs\https\public.crt" -Force
            Copy-Item -Path $ServerKeyPath -Destination "certs\https\private.key" -Force
            Write-Host "Server certificates installed for both Bolt and HTTPS" -ForegroundColor Green
        }
        
        # Copy CA certificate to trusted directories
        if ($CACertPath) {
            Copy-Item -Path $CACertPath -Destination "certs\bolt\trusted\ca.crt" -Force
            Copy-Item -Path $CACertPath -Destination "certs\https\trusted\ca.crt" -Force
            Write-Host "CA certificate installed to trusted directories" -ForegroundColor Green
        }
        
        # Copy CA private key if provided (for certificate management)
        if ($CAKeyPath) {
            Copy-Item -Path $CAKeyPath -Destination "certs\ca.key" -Force
            Write-Host "CA private key installed for certificate management" -ForegroundColor Green
        }
        
        # Verify installation
        $RequiredFiles = @("certs\bolt\private.key", "certs\bolt\public.crt", "certs\https\private.key", "certs\https\public.crt")
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
    Write-Host "Enabling SSL in Neo4j configuration..." -ForegroundColor White
    
    # Update .env file
    if (Test-Path ".env") {
        $EnvContent = Get-Content ".env" -Raw
        $EnvContent = $EnvContent -replace "ENABLE_SSL=false", "ENABLE_SSL=true"
        $EnvContent = $EnvContent -replace "NEO4J_URI=bolt://neo4j:7687", "NEO4J_URI=bolt+s://neo4j:7687"
        Set-Content -Path ".env" -Value $EnvContent
        Write-Host "SSL enabled in .env file" -ForegroundColor Green
    }
    
    # Update docker-compose.yml
    if (Test-Path "docker-compose.yml") {
        $ComposeContent = Get-Content "docker-compose.yml" -Raw
        
        # Add HTTPS port if not present
        if ($ComposeContent -notmatch "7473:7473") {
            $ComposeContent = $ComposeContent -replace '(\s+- "7474:7474")', "`$1`n      - `"7473:7473`"   # HTTPS Browser UI"
        }
        
        # Add SSL certificate volumes if not present
        if ($ComposeContent -notmatch "certificates") {
            $ComposeContent = $ComposeContent -replace '(\s+- \.\/neo4j-data\/import:\/var\/lib\/neo4j\/import)', "`$1`n      - ./certs:/var/lib/neo4j/certificates"
        }
        
        # Add SSL environment variables
        $SSLEnvVars = @"

      # SSL Configuration
      - NEO4J_server_https_enabled=true
      - NEO4J_server_http_enabled=false
      
      # Bolt TLS Configuration
      - NEO4J_server_bolt_tls__level=REQUIRED
      
      # SSL Policies
      - NEO4J_dbms_ssl_policy_bolt_enabled=true
      - NEO4J_dbms_ssl_policy_bolt_base__directory=certificates/bolt
      - NEO4J_dbms_ssl_policy_bolt_private__key=private.key
      - NEO4J_dbms_ssl_policy_bolt_public__certificate=public.crt
      - NEO4J_dbms_ssl_policy_bolt_client__auth=NONE
      
      - NEO4J_dbms_ssl_policy_https_enabled=true
      - NEO4J_dbms_ssl_policy_https_base__directory=certificates/https
      - NEO4J_dbms_ssl_policy_https_private__key=private.key
      - NEO4J_dbms_ssl_policy_https_public__certificate=public.crt
      - NEO4J_dbms_ssl_policy_https_client__auth=NONE
"@
        
        if ($ComposeContent -notmatch "NEO4J_server_https_enabled") {
            $ComposeContent = $ComposeContent -replace '(\s+# Disable telemetry\s+- NEO4J_dbms_usage__report_enabled=false)', "`$1$SSLEnvVars"
        }
        
        # Update watcher to use SSL Bolt connection
        $ComposeContent = $ComposeContent -replace 'NEO4J_URI=bolt://neo4j:7687', 'NEO4J_URI=bolt+s://neo4j:7687'
        
        Set-Content -Path "docker-compose.yml" -Value $ComposeContent
        Write-Host "SSL enabled in docker-compose.yml" -ForegroundColor Green
        Write-Host "Neo4j watcher updated to use SSL Bolt connection" -ForegroundColor Green
    }
}

# Function to disable SSL in configuration
function Disable-SSL {
    Write-Host "Disabling SSL in Neo4j configuration..." -ForegroundColor White
    
    # Update .env file
    if (Test-Path ".env") {
        $EnvContent = Get-Content ".env" -Raw
        $EnvContent = $EnvContent -replace "ENABLE_SSL=true", "ENABLE_SSL=false"
        $EnvContent = $EnvContent -replace "NEO4J_URI=bolt\+s://neo4j:7687", "NEO4J_URI=bolt://neo4j:7687"
        Set-Content -Path ".env" -Value $EnvContent
        Write-Host "SSL disabled in .env file" -ForegroundColor Green
    }
    
    # Update docker-compose.yml
    if (Test-Path "docker-compose.yml") {
        $ComposeContent = Get-Content "docker-compose.yml" -Raw
        
        # Remove HTTPS port
        $ComposeContent = $ComposeContent -replace '\s+- "7473:7473".*?\n', ""
        
        # Remove SSL certificate volumes
        $ComposeContent = $ComposeContent -replace '\s+- \.\/certs:\/var\/lib\/neo4j\/certificates\n', ""
        
        # Remove SSL environment variables
        $ComposeContent = $ComposeContent -replace '(?s)\s+# SSL Configuration.*?- NEO4J_dbms_ssl_policy_https_client__auth=NONE', ""
        
        # Revert watcher to use non-SSL Bolt connection
        $ComposeContent = $ComposeContent -replace 'NEO4J_URI=bolt\+s://neo4j:7687', 'NEO4J_URI=bolt://neo4j:7687'
        
        Set-Content -Path "docker-compose.yml" -Value $ComposeContent
        Write-Host "SSL disabled in docker-compose.yml" -ForegroundColor Green
        Write-Host "Neo4j watcher reverted to non-SSL Bolt connection" -ForegroundColor Green
    }
}

# Function to show SSL status
function Show-SSLStatus {
    Write-Host "SSL Certificate Status:" -ForegroundColor White
    Write-Host "======================" -ForegroundColor Gray
    
    # Check if certificates exist
    $CertFiles = @(
        @{Path="certs\bolt\private.key"; Name="Bolt Private Key"},
        @{Path="certs\bolt\public.crt"; Name="Bolt Certificate"},
        @{Path="certs\https\private.key"; Name="HTTPS Private Key"},
        @{Path="certs\https\public.crt"; Name="HTTPS Certificate"},
        @{Path="certs\bolt\trusted\ca.crt"; Name="Bolt CA Certificate"},
        @{Path="certs\https\trusted\ca.crt"; Name="HTTPS CA Certificate"}
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
            # Check Bolt certificate expiry
            $BoltExpiryInfo = docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl x509 -in bolt/public.crt -noout -dates
            if ($BoltExpiryInfo) {
                $NotAfterLine = $BoltExpiryInfo | Where-Object { $_ -match "notAfter=" }
                if ($NotAfterLine) {
                    $ExpiryDateStr = ($NotAfterLine -split "notAfter=")[1]
                    Write-Host "Bolt Certificate Expires: $ExpiryDateStr" -ForegroundColor White
                }
            }
            
            # Check HTTPS certificate expiry
            $HttpsExpiryInfo = docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl x509 -in https/public.crt -noout -dates
            if ($HttpsExpiryInfo) {
                $NotAfterLine = $HttpsExpiryInfo | Where-Object { $_ -match "notAfter=" }
                if ($NotAfterLine) {
                    $ExpiryDateStr = ($NotAfterLine -split "notAfter=")[1]
                    Write-Host "HTTPS Certificate Expires: $ExpiryDateStr" -ForegroundColor White
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
    
    if (Test-Path "docker-compose.yml") {
        $ComposeContent = Get-Content "docker-compose.yml" -Raw
        if ($ComposeContent -match "NEO4J_server_https_enabled=true") {
            Write-Host "HTTPS enabled (port 7473)" -ForegroundColor Green
        } else {
            Write-Host "HTTPS disabled" -ForegroundColor Red
        }
        
        if ($ComposeContent -match "NEO4J_server_bolt_tls__level=REQUIRED") {
            Write-Host "Bolt TLS enabled (port 7687)" -ForegroundColor Green
        } else {
            Write-Host "Bolt TLS disabled" -ForegroundColor Red
        }
    }
}

# Main script logic
switch ($Action) {
    "generate" {
        if (-not (Test-Docker)) { exit 1 }
        
        if ((Test-Path "certs\bolt\public.crt") -and -not $Force) {
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
            Write-Host "Use 'manage-ssl.ps1 enable' to activate SSL in Neo4j." -ForegroundColor Cyan
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
            Write-Host "Use 'manage-ssl.ps1 enable' to activate SSL in Neo4j." -ForegroundColor Cyan
        }
    }
    
    "enable" {
        if (-not (Test-Path "certs\bolt\public.crt") -or -not (Test-Path "certs\https\public.crt")) {
            Write-Host "SSL certificates not found!" -ForegroundColor Red
            Write-Host "Run 'manage-ssl.ps1 generate' or 'manage-ssl.ps1 install-ca' first." -ForegroundColor Yellow
            exit 1
        }
        
        Enable-SSL
        Restart-Neo4j
        
        Write-Host ""
        Write-Host "SSL enabled successfully!" -ForegroundColor Green
        Write-Host "Neo4j Browser UI: https://localhost:7473" -ForegroundColor White
        Write-Host "Bolt+TLS URI: bolt+s://localhost:7687" -ForegroundColor White
        Write-Host "Connect using SSL/TLS with your Neo4j client." -ForegroundColor Cyan
    }
    
    "disable" {
        Disable-SSL
        Restart-Neo4j
        
        Write-Host ""
        Write-Host "SSL disabled successfully!" -ForegroundColor Green
        Write-Host "Neo4j will only accept unencrypted connections." -ForegroundColor Yellow
        Write-Host "Browser UI: http://localhost:7474" -ForegroundColor White
        Write-Host "Bolt URI: bolt://localhost:7687" -ForegroundColor White
    }
    
    "status" {
        Show-SSLStatus
    }
    
    "renew" {
        if (-not (Test-Docker)) { exit 1 }
        
        if (-not (Test-Path "certs\bolt\public.crt")) {
            Write-Host "No existing certificates to renew!" -ForegroundColor Red
            Write-Host "Run 'manage-ssl.ps1 generate' to create new certificates." -ForegroundColor Yellow
            exit 1
        }
        
        Write-Host "Renewing SSL certificates..." -ForegroundColor White
        
        # Backup existing certificates
        $BackupDir = "certs\backup-$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
        Copy-Item -Path "certs\bolt\*" -Destination "$BackupDir\bolt\" -Recurse -Force -ErrorAction SilentlyContinue
        Copy-Item -Path "certs\https\*" -Destination "$BackupDir\https\" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Existing certificates backed up to: $BackupDir" -ForegroundColor Green
        
        if (Generate-SSLCertificates -Domain $Domain -ValidDays $ValidDays) {
            Restart-Neo4j
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
