# =================================================================
# TimescaleDB SSL Certificate Management Script
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
Write-Host "TimescaleDB SSL Certificate Management Script" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

# Show help if no action provided
if (-not $Action) {
    Write-Host "Usage: .\manage-ssl.ps1 <action> [options]" -ForegroundColor White
    Write-Host ""
    Write-Host "Actions:" -ForegroundColor Cyan
    Write-Host "  generate      Generate new self-signed SSL certificates" -ForegroundColor White
    Write-Host "  install-ca    Install CA-provided SSL certificates" -ForegroundColor White
    Write-Host "  enable        Enable SSL in TimescaleDB" -ForegroundColor White
    Write-Host "  disable       Disable SSL in TimescaleDB" -ForegroundColor White
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
    Write-Host "  .\manage-ssl.ps1 generate -Domain 'timescaledb.company.com' -ValidDays 730" -ForegroundColor Gray
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

# Change to parent directory (timescaledb folder)
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

# Function to restart TimescaleDB to apply SSL changes
function Restart-TimescaleDB {
    Write-Host "Restarting TimescaleDB to apply SSL changes..." -ForegroundColor Yellow
    docker-compose restart timescaledb pgadmin-nginx
    Start-Sleep -Seconds 10
    Write-Host "TimescaleDB restarted" -ForegroundColor Green
}

# Function to generate SSL certificates using Docker OpenSSL
function Generate-SSLCertificates {
    param([string]$Domain, [int]$ValidDays)
    
    Write-Host "Generating SSL certificates for domain: $Domain" -ForegroundColor White
    Write-Host "Certificate validity: $ValidDays days" -ForegroundColor Gray
    
    # Create certs directory if it doesn't exist
    if (-not (Test-Path "certs")) {
        New-Item -ItemType Directory -Force -Path "certs" | Out-Null
        Write-Host "Created directory: certs" -ForegroundColor Green
    }
    
    try {
        # Generate CA private key
        Write-Host "Generating CA private key..." -ForegroundColor Gray
        docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl genrsa -out ca.key 4096 2>$null
        
        # Generate CA certificate
        Write-Host "Generating CA certificate..." -ForegroundColor Gray
        docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl req -new -x509 -days $ValidDays -key ca.key -out ca.crt -subj "/C=US/ST=State/L=City/O=TimescaleDB/CN=TimescaleDB-CA" 2>$null
        
        # Generate server private key
        Write-Host "Generating server private key..." -ForegroundColor Gray
        docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl genrsa -out temp_server.key 4096 2>$null
        
        # Build SAN list
        $SANList = "DNS:$Domain,DNS:localhost,DNS:127.0.0.1,DNS:timescaledb,IP:127.0.0.1,IP:::1"
        
        # Generate server CSR with SAN
        Write-Host "Generating server CSR..." -ForegroundColor Gray
        docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl req -new -key temp_server.key -out temp_server.csr -subj "/C=US/ST=State/L=City/O=TimescaleDB/CN=$Domain" -addext "subjectAltName=$SANList" 2>$null
        
        # Sign server certificate
        Write-Host "Signing server certificate..." -ForegroundColor Gray
        docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl x509 -req -in temp_server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out temp_server.crt -days $ValidDays -copy_extensions copy 2>$null
        
        # Move temp files to final names and set permissions
        docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine sh -c "mv temp_server.key server.key && mv temp_server.crt server.crt && chmod 600 server.key && chmod 644 server.crt ca.crt && rm -f temp_server.csr ca.srl ca.key" 2>$null
        
        # Verify certificates were created
        if ((Test-Path "certs\ca.crt") -and (Test-Path "certs\server.crt") -and (Test-Path "certs\server.key")) {
            Write-Host "SSL certificates generated successfully using Docker OpenSSL" -ForegroundColor Green
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
    
    # Create certs directory if it doesn't exist
    if (-not (Test-Path "certs")) {
        New-Item -ItemType Directory -Force -Path "certs" | Out-Null
        Write-Host "Created directory: certs" -ForegroundColor Green
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
        
        # Copy server certificates
        if ($ServerCertPath -and $ServerKeyPath) {
            Copy-Item -Path $ServerCertPath -Destination "certs\server.crt" -Force
            Copy-Item -Path $ServerKeyPath -Destination "certs\server.key" -Force
            Write-Host "Server certificates installed" -ForegroundColor Green
        }
        
        # Copy CA certificate
        if ($CACertPath) {
            Copy-Item -Path $CACertPath -Destination "certs\ca.crt" -Force
            Write-Host "CA certificate installed" -ForegroundColor Green
        }
        
        # Copy CA private key if provided
        if ($CAKeyPath) {
            Copy-Item -Path $CAKeyPath -Destination "certs\ca.key" -Force
            Write-Host "CA private key installed" -ForegroundColor Green
        }
        
        # Verify installation
        $RequiredFiles = @("certs\server.key", "certs\server.crt")
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
    Write-Host "Enabling SSL in TimescaleDB configuration..." -ForegroundColor White
    
    # Update .env file
    if (Test-Path ".env") {
        $EnvContent = Get-Content ".env" -Raw
        $EnvContent = $EnvContent -replace "ENABLE_SSL=false", "ENABLE_SSL=true"
        Set-Content -Path ".env" -Value $EnvContent -NoNewline
        Write-Host "SSL enabled in .env file" -ForegroundColor Green
    }
    
    # Update postgresql.conf
    if (Test-Path "config\postgresql.conf") {
        $ConfContent = Get-Content "config\postgresql.conf" -Raw
        $ConfContent = $ConfContent -replace 'ssl = off', 'ssl = on'
        $ConfContent = $ConfContent -replace '# ssl_cert_file not configured \(SSL disabled\)', "ssl_cert_file = '/var/lib/postgresql/certs/server.crt'"
        $ConfContent = $ConfContent -replace '# ssl_key_file not configured \(SSL disabled\)', "ssl_key_file = '/var/lib/postgresql/certs/server.key'"
        $ConfContent = $ConfContent -replace '# ssl_ca_file not configured \(SSL disabled\)', "ssl_ca_file = '/var/lib/postgresql/certs/ca.crt'"
        $ConfContent = $ConfContent -replace '# ssl_min_protocol_version not configured \(SSL disabled\)', "ssl_min_protocol_version = 'TLSv1.2'"
        Set-Content -Path "config\postgresql.conf" -Value $ConfContent -NoNewline
        Write-Host "SSL enabled in postgresql.conf" -ForegroundColor Green
    }
    
    # Update nginx.conf for HTTPS
    if (Test-Path "pgadmin\nginx.conf") {
        $NginxContent = @"
events {
    worker_connections 1024;
}

http {
    upstream pgadmin {
        server pgadmin:80;
    }

    # Redirect HTTP to HTTPS
    server {
        listen 80;
        server_name $Domain;
        return 301 https://`$host:5051`$request_uri;
    }

    # HTTPS server
    server {
        listen 443 ssl;
        server_name $Domain;

        ssl_certificate /etc/nginx/ssl/server.crt;
        ssl_certificate_key /etc/nginx/ssl/server.key;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers HIGH:!aNULL:!MD5;
        ssl_prefer_server_ciphers on;

        location / {
            proxy_pass http://pgadmin;
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
        Set-Content -Path "pgadmin\nginx.conf" -Value $NginxContent -NoNewline
        Write-Host "SSL enabled in nginx.conf" -ForegroundColor Green
    }
    
    Write-Host "SSL configuration updated successfully" -ForegroundColor Green
}

# Function to disable SSL in configuration
function Disable-SSL {
    Write-Host "Disabling SSL in TimescaleDB configuration..." -ForegroundColor White
    
    # Update .env file
    if (Test-Path ".env") {
        $EnvContent = Get-Content ".env" -Raw
        $EnvContent = $EnvContent -replace "ENABLE_SSL=true", "ENABLE_SSL=false"
        Set-Content -Path ".env" -Value $EnvContent -NoNewline
        Write-Host "SSL disabled in .env file" -ForegroundColor Green
    }
    
    # Update postgresql.conf
    if (Test-Path "config\postgresql.conf") {
        $ConfContent = Get-Content "config\postgresql.conf" -Raw
        $ConfContent = $ConfContent -replace 'ssl = on', 'ssl = off'
        $ConfContent = $ConfContent -replace "ssl_cert_file = '/var/lib/postgresql/certs/server.crt'", '# ssl_cert_file not configured (SSL disabled)'
        $ConfContent = $ConfContent -replace "ssl_key_file = '/var/lib/postgresql/certs/server.key'", '# ssl_key_file not configured (SSL disabled)'
        $ConfContent = $ConfContent -replace "ssl_ca_file = '/var/lib/postgresql/certs/ca.crt'", '# ssl_ca_file not configured (SSL disabled)'
        $ConfContent = $ConfContent -replace "ssl_min_protocol_version = 'TLSv1.2'", '# ssl_min_protocol_version not configured (SSL disabled)'
        Set-Content -Path "config\postgresql.conf" -Value $ConfContent -NoNewline
        Write-Host "SSL disabled in postgresql.conf" -ForegroundColor Green
    }
    
    # Update nginx.conf for HTTP only
    if (Test-Path "pgadmin\nginx.conf") {
        $NginxContent = @"
events {
    worker_connections 1024;
}

http {
    upstream pgadmin {
        server pgadmin:80;
    }

    server {
        listen 80;
        server_name $Domain;

        location / {
            proxy_pass http://pgadmin;
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
        Set-Content -Path "pgadmin\nginx.conf" -Value $NginxContent -NoNewline
        Write-Host "SSL disabled in nginx.conf" -ForegroundColor Green
    }
    
    Write-Host "SSL configuration disabled successfully" -ForegroundColor Green
}

# Function to show SSL status
function Show-SSLStatus {
    Write-Host "SSL Certificate Status:" -ForegroundColor White
    Write-Host ""
    
    # Check if certificates exist
    if (Test-Path "certs\server.crt") {
        Write-Host "Certificates:" -ForegroundColor Cyan
        Write-Host "  CA Certificate: $(if (Test-Path 'certs\ca.crt') { 'Present' } else { 'Missing' })" -ForegroundColor $(if (Test-Path 'certs\ca.crt') { 'Green' } else { 'Red' })
        Write-Host "  Server Certificate: Present" -ForegroundColor Green
        Write-Host "  Server Key: $(if (Test-Path 'certs\server.key') { 'Present' } else { 'Missing' })" -ForegroundColor $(if (Test-Path 'certs\server.key') { 'Green' } else { 'Red' })
        
        # Show certificate details
        Write-Host ""
        Write-Host "Certificate Details:" -ForegroundColor Cyan
        $CertInfo = docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl x509 -in server.crt -noout -subject -dates 2>$null
        Write-Host $CertInfo -ForegroundColor Gray
    } else {
        Write-Host "No SSL certificates found" -ForegroundColor Yellow
    }
    
    # Check configuration
    Write-Host ""
    Write-Host "Configuration:" -ForegroundColor Cyan
    if (Test-Path ".env") {
        $EnvSSL = Select-String -Path ".env" -Pattern "ENABLE_SSL=(true|false)" | ForEach-Object { $_.Matches.Groups[1].Value }
        Write-Host "  .env ENABLE_SSL: $EnvSSL" -ForegroundColor $(if ($EnvSSL -eq 'true') { 'Green' } else { 'Yellow' })
    }
    
    if (Test-Path "config\postgresql.conf") {
        $ConfSSL = Select-String -Path "config\postgresql.conf" -Pattern "ssl = (on|off)" | ForEach-Object { $_.Matches.Groups[1].Value }
        Write-Host "  postgresql.conf ssl: $ConfSSL" -ForegroundColor $(if ($ConfSSL -eq 'on') { 'Green' } else { 'Yellow' })
    }
}

# Main action handling
switch ($Action) {
    "generate" {
        if (-not (Test-Docker)) { exit 1 }
        
        Write-Host ""
        if (Generate-SSLCertificates -Domain $Domain -ValidDays $ValidDays) {
            Write-Host ""
            Write-Host "Certificates generated successfully!" -ForegroundColor Green
            Write-Host "Run '.\manage-ssl.ps1 enable' to enable SSL in TimescaleDB" -ForegroundColor Cyan
        } else {
            Write-Host "Certificate generation failed" -ForegroundColor Red
            exit 1
        }
    }
    
    "install-ca" {
        if (-not $ServerCertPath -or -not $ServerKeyPath) {
            Write-Host "Error: Server certificate and key paths are required" -ForegroundColor Red
            Write-Host "Usage: .\manage-ssl.ps1 install-ca -ServerCertPath <path> -ServerKeyPath <path> [-CACertPath <path>]" -ForegroundColor Gray
            exit 1
        }
        
        Write-Host ""
        if (Install-CACertificates -CACertPath $CACertPath -CAKeyPath $CAKeyPath -ServerCertPath $ServerCertPath -ServerKeyPath $ServerKeyPath) {
            Write-Host ""
            Write-Host "CA certificates installed successfully!" -ForegroundColor Green
            Write-Host "Run '.\manage-ssl.ps1 enable' to enable SSL in TimescaleDB" -ForegroundColor Cyan
        } else {
            Write-Host "CA certificate installation failed" -ForegroundColor Red
            exit 1
        }
    }
    
    "enable" {
        # Check if certificates exist
        if (-not (Test-Path "certs\server.crt") -or -not (Test-Path "certs\server.key")) {
            Write-Host "Error: SSL certificates not found!" -ForegroundColor Red
            Write-Host "Generate certificates first: .\manage-ssl.ps1 generate" -ForegroundColor Yellow
            exit 1
        }
        
        Write-Host ""
        Enable-SSL
        Write-Host ""
        Restart-TimescaleDB
        Write-Host ""
        Write-Host "SSL enabled successfully!" -ForegroundColor Green
        Write-Host "Access pgAdmin: https://localhost:5051" -ForegroundColor Cyan
        Write-Host "Connect to database: postgresql://user:pass@localhost:5432/db?sslmode=require" -ForegroundColor Cyan
    }
    
    "disable" {
        Write-Host ""
        Disable-SSL
        Write-Host ""
        Restart-TimescaleDB
        Write-Host ""
        Write-Host "SSL disabled successfully!" -ForegroundColor Green
        Write-Host "Access pgAdmin: http://localhost:5050" -ForegroundColor Cyan
        Write-Host "Connect to database: psql -h localhost -U postgres -d timescaledb" -ForegroundColor Cyan
    }
    
    "status" {
        Write-Host ""
        Show-SSLStatus
    }
    
    "renew" {
        if (-not (Test-Docker)) { exit 1 }
        
        Write-Host ""
        Write-Host "Renewing SSL certificates..." -ForegroundColor White
        
        if (Generate-SSLCertificates -Domain $Domain -ValidDays $ValidDays) {
            Write-Host ""
            Write-Host "Certificates renewed successfully!" -ForegroundColor Green
            Restart-TimescaleDB
            Write-Host ""
            Write-Host "SSL certificates renewed and TimescaleDB restarted" -ForegroundColor Green
        } else {
            Write-Host "Certificate renewal failed" -ForegroundColor Red
            exit 1
        }
    }
}

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan

# Return to management directory
Set-Location management

exit 0
