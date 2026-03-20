param(
    [string]$Username = "postgres",
    [string]$Password = "",
    [string]$DatabaseName = "timescaledb",
    [switch]$EnableSSL = $false,
    [string]$Domain = "localhost",
    [ValidateSet("self-signed", "ca-provided", "")]
    [string]$CertType = "",
    [string]$MachineIPs = "",
    [switch]$Force = $false
)

# Ensure we're in the timescaledb directory (not management subdirectory)
$CurrentLocation = Get-Location
if ($CurrentLocation.Path.EndsWith("management")) {
    Set-Location ..
}

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "TimescaleDB Time-Series Database Installation Script" -ForegroundColor Cyan
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

# Check if TimescaleDB container is already running (only if .env exists)
if (Test-Path ".env") {
    Write-Host "Checking existing TimescaleDB containers..." -ForegroundColor White
    try {
        $ExistingContainers = docker-compose ps --format json 2>$null | ConvertFrom-Json
        $TimescaleDBContainer = $ExistingContainers | Where-Object { $_.Service -eq "timescaledb" }
        
        if ($TimescaleDBContainer -and $TimescaleDBContainer.State -eq "running") {
            Write-Host "TimescaleDB container is already running" -ForegroundColor Yellow
            $StopChoice = Read-Host "Stop existing container to reconfigure? (y/n)"
            if ($StopChoice -eq "Y" -or $StopChoice -eq "y") {
                Write-Host "Stopping existing TimescaleDB container..." -ForegroundColor Yellow
                docker-compose down
                Write-Host "Container stopped" -ForegroundColor Green
            } else {
                Write-Host "Installation cancelled - container still running" -ForegroundColor Yellow
                exit 0
            }
        }
    } catch {
        # Ignore errors if container doesn't exist yet
    }
}

# Create directory structure
Write-Host "Creating directory structure..." -ForegroundColor White
$Directories = @(
    "init",
    "backups",
    "certs",
    "config",
    "pgadmin",
    "postgrest",
    "timescaledb-data",
    "timescaledb-data\data",
    "timescaledb-data\pgadmin"
)
foreach ($Dir in $Directories) {
    if (-not (Test-Path $Dir)) {
        New-Item -ItemType Directory -Force -Path $Dir | Out-Null
        Write-Host "Created directory: $Dir" -ForegroundColor Green
    } else {
        Write-Host "Directory exists: $Dir" -ForegroundColor Gray
    }
}

# Ask about backup retention
Write-Host ""
Write-Host "Backup Retention Configuration:" -ForegroundColor White
Write-Host "How many days should automated backups be retained?" -ForegroundColor White
Write-Host "  7 days   - Minimal retention (development/testing)" -ForegroundColor Gray
Write-Host "  30 days  - Standard production (recommended)" -ForegroundColor Gray
Write-Host "  90 days  - Extended retention (compliance)" -ForegroundColor Gray
Write-Host "  365 days - Long-term retention (regulatory)" -ForegroundColor Gray
$RetentionChoice = Read-Host "Enter retention days (default: 30)"
if ($RetentionChoice -match '^\d+$') {
    $BackupRetentionDays = [int]$RetentionChoice
} else {
    $BackupRetentionDays = 30
}
Write-Host "Backup retention set to: $BackupRetentionDays days" -ForegroundColor Green

# Ask about SSL setup (unless already specified via parameter)
if (-not $PSBoundParameters.ContainsKey('EnableSSL')) {
    Write-Host "SSL Configuration:" -ForegroundColor White
    $SSLChoice = Read-Host "Enable SSL/TLS encryption for TimescaleDB? (y/n)"
    if ($SSLChoice -eq "Y" -or $SSLChoice -eq "y") {
        $EnableSSL = $true
    }
}

$UseCAProvided = $false
$MachineIP = ""

if ($EnableSSL) {
    Write-Host "SSL will be enabled for PostgreSQL connections" -ForegroundColor Green

    if ($CertType) {
        if ($CertType -eq "ca-provided") {
            Write-Host "CA-provided certificates selected (from stack installer)" -ForegroundColor Green
            $EnableSSL = $false
            $UseCAProvided = $true
        } else {
            Write-Host "Self-signed certificates selected (from stack installer)" -ForegroundColor Green
        }
        $MachineIP = $MachineIPs
    } else {
        Write-Host ""
        Write-Host "Certificate Options:" -ForegroundColor White
        Write-Host "1. Generate self-signed certificates (for development/testing)" -ForegroundColor Gray
        Write-Host "2. Use CA-provided certificates (for production)" -ForegroundColor Gray
        $CertChoice = Read-Host "Select certificate type (1 or 2, default: 1)"

        if ($CertChoice -eq "2") {
            Write-Host "CA-provided certificates selected" -ForegroundColor Green
            Write-Host "You can install them after setup using: .\management\manage-ssl.ps1 -Enable" -ForegroundColor Cyan
            Write-Host "SSL will be configured but not enabled until certificates are installed" -ForegroundColor Yellow
            $EnableSSL = $false
            $UseCAProvided = $true
        } else {
            Write-Host "Self-signed certificates selected" -ForegroundColor Green

            $DomainChoice = Read-Host "Enter domain name for SSL certificate (default: localhost)"
            if ($DomainChoice) {
                $Domain = $DomainChoice
            }
            Write-Host "SSL certificates will be generated for domain: $Domain" -ForegroundColor White

            Write-Host ""
            Write-Host "Detecting machine IP addresses..." -ForegroundColor White
            try {
                $AllIPs = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notmatch '^127\.' -and ($_.PrefixOrigin -eq 'Dhcp' -or $_.PrefixOrigin -eq 'Manual') }

                if ($AllIPs.Count -gt 0) {
                    Write-Host "Detected IP addresses:" -ForegroundColor Green
                    for ($i = 0; $i -lt $AllIPs.Count; $i++) {
                        $adapter = Get-NetAdapter -InterfaceIndex $AllIPs[$i].InterfaceIndex
                        Write-Host "  [$i] $($AllIPs[$i].IPAddress) - $($adapter.InterfaceDescription)" -ForegroundColor White
                    }

                    Write-Host ""
                    $IPChoice = Read-Host "Enter IP numbers to include (comma-separated, e.g., '0,1') or press Enter to skip"

                    if ($IPChoice) {
                        $SelectedIndices = $IPChoice -split ',' | ForEach-Object { $_.Trim() }
                        $SelectedIPs = @()
                        foreach ($index in $SelectedIndices) {
                            if ($index -match '^\d+$' -and [int]$index -lt $AllIPs.Count) {
                                $SelectedIPs += $AllIPs[[int]$index].IPAddress
                            }
                        }

                        if ($SelectedIPs.Count -gt 0) {
                            Write-Host "Selected IPs: $($SelectedIPs -join ', ')" -ForegroundColor Cyan
                            $MachineIP = $SelectedIPs -join ','
                        } else {
                            Write-Host "No valid IPs selected" -ForegroundColor Gray
                        }
                    } else {
                        Write-Host "IP addresses not included (localhost/domain only)" -ForegroundColor Gray
                    }
                } else {
                    Write-Host "Could not detect IP addresses, skipping" -ForegroundColor Gray
                }
            } catch {
                Write-Host "Could not detect IP addresses: $($_.Exception.Message)" -ForegroundColor Gray
            }
        }
    }
} else {
    Write-Host "SSL will be disabled (unencrypted connections only)" -ForegroundColor Yellow
}

# Generate or prompt for password if not provided
if (-not $Password) {
    Write-Host "Password Setup:" -ForegroundColor White
    $Choice = Read-Host "Generate secure password automatically? (y/n)"
    
    if ($Choice -eq "" -or $Choice -eq "Y" -or $Choice -eq "y") {
        Write-Host "Generating secure password..." -ForegroundColor White
        $Password = -join ((65..90) + (97..122) + (48..57) + @(33,35,37,38,42,43,45,61,63,64) | Get-Random -Count 32 | ForEach-Object {[char]$_})
        Write-Host "Generated password for user '$Username': $Password" -ForegroundColor Green
    } else {
        $Password = Read-Host "Enter password for user '$Username'" -AsSecureString
        $Password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password))
        if (-not $Password) {
            Write-Host "Password cannot be empty!" -ForegroundColor Red
            exit 1
        }
    }
} else {
    Write-Host "Using provided password for user '$Username'" -ForegroundColor Gray
}

# Create .env file
Write-Host "Creating configuration files..." -ForegroundColor White
$EnvContent = @"
# =================================================================
# TimescaleDB Environment Configuration
# =================================================================

# Database Configuration
POSTGRES_DB=$DatabaseName
POSTGRES_USER=$Username
POSTGRES_PASSWORD=$Password
POSTGRES_PORT=5432

# TimescaleDB Settings
TIMESCALEDB_TELEMETRY=off

# SSL Configuration
ENABLE_SSL=$($EnableSSL.ToString().ToLower())
SSL_DOMAIN=$Domain

# Backup Configuration
BACKUP_RETENTION_DAYS=$BackupRetentionDays

# Generated on: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
"@

# Generate pgAdmin password and email
Write-Host ""
Write-Host "pgAdmin Configuration:" -ForegroundColor White
$PgAdminEmailChoice = Read-Host "Enter email for pgAdmin login (default: admin@example.com)"
if ($PgAdminEmailChoice -and $PgAdminEmailChoice -match '^[^@]+@[^@]+\.[^@]+$') {
    $PgAdminEmail = $PgAdminEmailChoice
} else {
    $PgAdminEmail = "admin@example.com"
}
Write-Host "pgAdmin email set to: $PgAdminEmail" -ForegroundColor Green

Write-Host "Generating pgAdmin password..." -ForegroundColor White
# Use safe charset for .env compatibility (no special shell characters)
$SafeChars = (65..90) + (97..122) + (48..57) + @(95, 45)  # A-Z, a-z, 0-9, _, -
$PgAdminPassword = -join ($SafeChars | Get-Random -Count 24 | ForEach-Object {[char]$_})
Write-Host "Generated pgAdmin password: $PgAdminPassword" -ForegroundColor Green

# Add pgAdmin configuration to .env
$EnvContent += @"

# pgAdmin Configuration
PGADMIN_EMAIL=$PgAdminEmail
PGADMIN_PASSWORD=$PgAdminPassword
PGADMIN_PORT=5050
PGADMIN_HTTPS_PORT=5051
"@

# PostgREST Configuration
Write-Host ""
Write-Host "PostgREST Configuration:" -ForegroundColor Cyan
Write-Host "PostgREST exposes the 'api' schema as a REST API on port 3000." -ForegroundColor Gray

$PostgrestPortChoice = Read-Host "Enter PostgREST HTTP port (default: 3000)"
if ($PostgrestPortChoice -match '^\d+$') {
    $PostgrestPort = [int]$PostgrestPortChoice
} else {
    $PostgrestPort = 3000
}

$PostgrestHttpsPortChoice = Read-Host "Enter PostgREST HTTPS port (default: 3443)"
if ($PostgrestHttpsPortChoice -match '^\d+$') {
    $PostgrestHttpsPort = [int]$PostgrestHttpsPortChoice
} else {
    $PostgrestHttpsPort = 3443
}

Write-Host ""
Write-Host "CORS Configuration:" -ForegroundColor Cyan
Write-Host "  Enter the origin(s) allowed to call PostgREST from the browser." -ForegroundColor Gray
Write-Host "  Examples: https://app.example.com  or  *  (allow all, dev only)" -ForegroundColor Gray
$CorsChoice = Read-Host "Allowed CORS origins (default: *)"
if ($CorsChoice) {
    $PostgrestCorsOrigins = $CorsChoice
} else {
    $PostgrestCorsOrigins = "*"
}

Write-Host "Generating PostgREST secrets..." -ForegroundColor White
$SafeChars = (65..90) + (97..122) + (48..57)  # A-Z, a-z, 0-9
$PostgrestAuthenticatorPassword = -join ($SafeChars | Get-Random -Count 32 | ForEach-Object {[char]$_})
$PgrstJwtSecret = -join ($SafeChars | Get-Random -Count 48 | ForEach-Object {[char]$_})
Write-Host "Generated authenticator password and JWT secret" -ForegroundColor Green

$EnvContent += @"

# PostgREST Configuration
POSTGREST_PORT=$PostgrestPort
POSTGREST_HTTPS_PORT=$PostgrestHttpsPort
POSTGREST_AUTHENTICATOR_PASSWORD=$PostgrestAuthenticatorPassword
# On-premise URI (authenticator connects to the local TimescaleDB container)
# For Tiger Cloud, replace with: postgres://tsdbadmin:<password>@<host>.tsdb.cloud.timescale.com:<port>/tsdb?sslmode=require
PGRST_DB_URI=postgres://authenticator:${PostgrestAuthenticatorPassword}@timescaledb:5432/$DatabaseName
PGRST_DB_SCHEMAS=api
PGRST_DB_ANON_ROLE=anon
PGRST_JWT_SECRET=$PgrstJwtSecret
PGRST_DB_MAX_ROWS=1000
PGRST_SERVER_CORS_ALLOWED_ORIGINS=$PostgrestCorsOrigins
PGRST_DB_POOL=10
PGRST_DB_PREPARED_STATEMENTS=true
"@
Write-Host "PostgREST configuration written to .env" -ForegroundColor Green

# Activate ssl profile for nginx reverse proxy when SSL is enabled
if ($EnableSSL) {
    $EnvContent += "`nCOMPOSE_PROFILES=ssl"
}

$EnvContent | Out-File -FilePath ".env" -Encoding ASCII
Write-Host "Created .env file with configuration" -ForegroundColor Green

# Create pgAdmin servers.json configuration
Write-Host "Creating pgAdmin configuration..." -ForegroundColor White
$ServersJson = @"
{
  "Servers": {
    "1": {
      "Name": "TimescaleDB",
      "Group": "Servers",
      "Host": "timescaledb",
      "Port": 5432,
      "MaintenanceDB": "$DatabaseName",
      "Username": "$Username",
      "SSLMode": "$( if ($EnableSSL) { 'require' } else { 'prefer' })",
      "PassFile": "/tmp/pgpassfile"
    }
  }
}
"@

# Write without BOM to avoid JSON parsing issues
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText("$PWD\pgadmin\servers.json", $ServersJson, $utf8NoBom)
Write-Host "Created pgAdmin configuration" -ForegroundColor Green

# Substitute authenticator password into PostgREST init SQL
Write-Host "Configuring PostgREST initialization script..." -ForegroundColor White
$PostgrestSqlPath = "init\02-init-postgrest.sql"
if (Test-Path $PostgrestSqlPath) {
    $postgrestSqlContent = Get-Content $PostgrestSqlPath -Raw
    $postgrestSqlContent = $postgrestSqlContent -replace '\{\{AUTHENTICATOR_PASSWORD\}\}', $PostgrestAuthenticatorPassword
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText("$PWD\$PostgrestSqlPath", $postgrestSqlContent, $utf8NoBom)
    Write-Host "PostgREST initialization script configured" -ForegroundColor Green
} else {
    Write-Host "Warning: $PostgrestSqlPath not found - creating it" -ForegroundColor Yellow
    $postgrestSqlContent = @"
-- PostgREST Database Setup (generated by install.ps1)
CREATE SCHEMA IF NOT EXISTS api;
DO `$`$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'anon') THEN
        CREATE ROLE anon NOLOGIN NOINHERIT;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'webuser') THEN
        CREATE ROLE webuser NOLOGIN NOINHERIT;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'authenticator') THEN
        CREATE ROLE authenticator NOINHERIT LOGIN PASSWORD '$PostgrestAuthenticatorPassword';
    ELSE
        ALTER ROLE authenticator PASSWORD '$PostgrestAuthenticatorPassword';
    END IF;
END
`$`$;
GRANT anon TO authenticator;
GRANT webuser TO authenticator;
GRANT USAGE ON SCHEMA api TO anon;
GRANT USAGE ON SCHEMA api TO webuser;
"@
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText("$PWD\$PostgrestSqlPath", $postgrestSqlContent, $utf8NoBom)
    Write-Host "Created PostgREST initialization script" -ForegroundColor Green
}

# Create nginx configuration for pgAdmin (only used when ssl profile is active)
if ($EnableSSL) {
    Write-Host "Creating nginx configuration for pgAdmin HTTPS..." -ForegroundColor White
    $NginxConfig = @"
events {
    worker_connections 1024;
}

http {
    upstream pgadmin {
        server pgadmin:80;
    }

    # HTTPS server - nginx handles SSL termination, proxies to pgAdmin HTTP
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
            proxy_set_header Host `$http_host;
            proxy_set_header X-Real-IP `$remote_addr;
            proxy_set_header X-Forwarded-For `$proxy_add_x_forwarded_for;
            # Tell pgAdmin it's being accessed via HTTPS
            proxy_set_header X-Forwarded-Proto https;
            proxy_set_header X-Script-Name /;
            proxy_redirect off;
            proxy_http_version 1.1;
            proxy_set_header Upgrade `$http_upgrade;
            proxy_set_header Connection "upgrade";

            # Increase timeouts for long-running queries
            proxy_connect_timeout 600;
            proxy_send_timeout 600;
            proxy_read_timeout 600;
            send_timeout 600;
        }
    }
}
"@
    $NginxConfig | Out-File -FilePath "pgadmin\nginx.conf" -Encoding ASCII
    Write-Host "Created nginx.conf for pgAdmin HTTPS (port 5051)" -ForegroundColor Green

    # Create nginx configuration for PostgREST HTTPS
    Write-Host "Creating nginx configuration for PostgREST HTTPS..." -ForegroundColor White
    $PostgrestNginxConfig = @"
events {
    worker_connections 1024;
}

http {
    upstream postgrest {
        server postgrest:3000;
    }

    # HTTPS server - nginx handles SSL termination, proxies to PostgREST HTTP
    server {
        listen 443 ssl;
        server_name $Domain;

        ssl_certificate /etc/nginx/ssl/server.crt;
        ssl_certificate_key /etc/nginx/ssl/server.key;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers HIGH:!aNULL:!MD5;
        ssl_prefer_server_ciphers on;

        location / {
            proxy_pass http://postgrest;
            proxy_set_header Host `$http_host;
            proxy_set_header X-Real-IP `$remote_addr;
            proxy_set_header X-Forwarded-For `$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto https;
            proxy_redirect off;
            proxy_http_version 1.1;

            # Security headers
            add_header X-Content-Type-Options nosniff;
            add_header X-Frame-Options DENY;
        }
    }
}
"@
    $PostgrestNginxConfig | Out-File -FilePath "postgrest\nginx.conf" -Encoding ASCII
    Write-Host "Created nginx.conf for PostgREST HTTPS (port $PostgrestHttpsPort)" -ForegroundColor Green
}

# Create backup script
Write-Host "Creating automated backup script..." -ForegroundColor White
$BackupScript = @"
#!/bin/sh
set -e

TIMESTAMP=`$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/backups"
RETENTION_DAYS=`${BACKUP_RETENTION_DAYS:-30}

# Create backup directory if it doesn't exist
mkdir -p "`$BACKUP_DIR"

# Backup filename
BACKUP_FILE="`$BACKUP_DIR/timescaledb_`${TIMESTAMP}.sql.gz"

echo "`$(date): Starting backup to `$BACKUP_FILE"

# Perform backup using pg_dump
pg_dump -Fc "`$PGDATABASE" | gzip > "`$BACKUP_FILE"

if [ `$? -eq 0 ]; then
    echo "`$(date): Backup completed successfully: `$BACKUP_FILE"
    
    # Clean up old backups
    echo "`$(date): Cleaning up backups older than `$RETENTION_DAYS days"
    find "`$BACKUP_DIR" -name "*.sql.gz" -type f -mtime +`$RETENTION_DAYS -delete
    
    # List current backups
    BACKUP_COUNT=`$(ls -1 "`$BACKUP_DIR"/*.sql.gz 2>/dev/null | wc -l)
    BACKUP_SIZE=`$(du -sh "`$BACKUP_DIR" 2>/dev/null | cut -f1)
    echo "`$(date): Current backups: `$BACKUP_COUNT files, Total size: `$BACKUP_SIZE"
else
    echo "`$(date): Backup failed!"
    exit 1
fi
"@

$BackupScript | Out-File -FilePath "management\backup.sh" -Encoding ASCII
Write-Host "Created automated backup script (retention: $BackupRetentionDays days)" -ForegroundColor Green

# Create docker-entrypoint.sh with Unix line endings
Write-Host "Creating docker-entrypoint.sh..." -ForegroundColor White
$dockerEntrypoint = @"
#!/bin/bash
set -e

# Fix SSL certificate permissions if they exist
if [ -d "/var/lib/postgresql/certs" ] && [ -f "/var/lib/postgresql/certs/server.key" ]; then
    echo "Fixing SSL certificate permissions..."
    chown postgres:postgres /var/lib/postgresql/certs/server.key /var/lib/postgresql/certs/server.crt /var/lib/postgresql/certs/ca.crt 2>/dev/null || true
    chmod 600 /var/lib/postgresql/certs/server.key 2>/dev/null || true
    chmod 644 /var/lib/postgresql/certs/server.crt /var/lib/postgresql/certs/ca.crt 2>/dev/null || true
    echo "SSL certificate permissions fixed"
fi

# Execute the original docker entrypoint with all arguments
exec docker-entrypoint.sh "`$@"
"@

# Convert to Unix line endings and write without BOM
$unixContent = $dockerEntrypoint -replace "`r`n", "`n"
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText("$PWD\docker-entrypoint.sh", $unixContent, $utf8NoBom)
Write-Host "Created docker-entrypoint.sh with Unix line endings" -ForegroundColor Green

# Create initialization SQL script
Write-Host "Creating initialization script..." -ForegroundColor White
$initSQL = @"
-- =================================================================
-- TimescaleDB Initialization Script
-- =================================================================

-- Create TimescaleDB extension
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- Enable additional useful extensions
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Create a sample schema for time-series data
CREATE SCHEMA IF NOT EXISTS timeseries;

-- Set default privileges
GRANT USAGE ON SCHEMA timeseries TO PUBLIC;
GRANT CREATE ON SCHEMA timeseries TO $Username;

-- Log successful initialization
DO `$`$
BEGIN
    RAISE NOTICE 'TimescaleDB initialized successfully';
    RAISE NOTICE 'Version: %', (SELECT extversion FROM pg_extension WHERE extname = 'timescaledb');
END
`$`$;
"@

$initSQL | Out-File -FilePath "init\01-init-timescaledb.sql" -Encoding UTF8
Write-Host "Created initialization script" -ForegroundColor Green

# Generate PostgreSQL configuration file from template
Write-Host "Generating PostgreSQL configuration..." -ForegroundColor White
$templatePath = "config\postgresql.conf.template"
$configPath = "config\postgresql.conf"

if (Test-Path $templatePath) {
    $configContent = Get-Content $templatePath -Raw
    
    if ($EnableSSL) {
        $configContent = $configContent -replace '{{SSL_STATUS}}', 'enabled'
        $configContent = $configContent -replace '{{SSL_ENABLED}}', 'on'
        $configContent = $configContent -replace '{{SSL_CERT_LINE}}', 'ssl_cert_file = ''/var/lib/postgresql/certs/server.crt'''
        $configContent = $configContent -replace '{{SSL_KEY_LINE}}', 'ssl_key_file = ''/var/lib/postgresql/certs/server.key'''
        $configContent = $configContent -replace '{{SSL_CA_LINE}}', 'ssl_ca_file = ''/var/lib/postgresql/certs/ca.crt'''
        $configContent = $configContent -replace '{{SSL_MIN_PROTOCOL_LINE}}', 'ssl_min_protocol_version = ''TLSv1.2'''
    } else {
        $configContent = $configContent -replace '{{SSL_STATUS}}', 'disabled'
        $configContent = $configContent -replace '{{SSL_ENABLED}}', 'off'
        $configContent = $configContent -replace '{{SSL_CERT_LINE}}', '# ssl_cert_file not configured (SSL disabled)'
        $configContent = $configContent -replace '{{SSL_KEY_LINE}}', '# ssl_key_file not configured (SSL disabled)'
        $configContent = $configContent -replace '{{SSL_CA_LINE}}', '# ssl_ca_file not configured (SSL disabled)'
        $configContent = $configContent -replace '{{SSL_MIN_PROTOCOL_LINE}}', '# ssl_min_protocol_version not configured (SSL disabled)'
    }
    
    # Use ASCII encoding to avoid UTF-8 BOM issues with PostgreSQL
    $configContent | Out-File -FilePath $configPath -Encoding ASCII -NoNewline
    Write-Host "Created PostgreSQL configuration file" -ForegroundColor Green
} else {
    Write-Host "Warning: Template file not found at $templatePath" -ForegroundColor Yellow
    Write-Host "Creating basic configuration file..." -ForegroundColor Yellow
    
    # Create a basic config if template is missing
    $basicConfig = @"
# Basic PostgreSQL Configuration
listen_addresses = '*'
port = 5432
max_connections = 100
shared_preload_libraries = 'timescaledb'
timescaledb.telemetry_level = off
ssl = off
"@
    # Use ASCII encoding to avoid UTF-8 BOM issues with PostgreSQL
    $basicConfig | Out-File -FilePath $configPath -Encoding ASCII -NoNewline
    Write-Host "Created basic configuration file" -ForegroundColor Green
}

# Set proper permissions for data directories
Write-Host "Setting directory permissions..." -ForegroundColor White
icacls "backups" /grant "Everyone:(OI)(CI)F" /T | Out-Null
Write-Host "Directory permissions configured" -ForegroundColor Green

# SSL Certificate setup
if ($EnableSSL) {
    Write-Host "Setting up SSL certificates..." -ForegroundColor White
    
    if (-not (Test-Path "certs\server.crt") -or $Force) {
        Write-Host "Generating SSL certificates for TimescaleDB..." -ForegroundColor Gray
        
        try {
            Write-Host "Generating certificates using OpenSSL in Docker..." -ForegroundColor Gray
            
            # Generate CA private key
            docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl genrsa -out ca.key 4096
            
            # Generate CA certificate
            docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl req -new -x509 -days 365 -key ca.key -out ca.crt -subj "/C=US/ST=State/L=City/O=TimescaleDB/CN=TimescaleDB-CA"
            
            # Generate server private key with temp name
            docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl genrsa -out temp_server.key 4096
            
            # Build SAN list
            $SANList = "DNS:$Domain,DNS:localhost,DNS:127.0.0.1,DNS:timescaledb,IP:127.0.0.1,IP:::1"
            if ($MachineIP) {
                $IPArray = $MachineIP -split ','
                foreach ($IP in $IPArray) {
                    $SANList += ",IP:$($IP.Trim())"
                }
            }
            
            # Generate server CSR with SAN
            docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl req -new -key temp_server.key -out temp_server.csr -subj "/C=US/ST=State/L=City/O=TimescaleDB/CN=$Domain" -addext "subjectAltName=$SANList"
            
            # Sign server certificate with temp name
            docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl x509 -req -in temp_server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out temp_server.crt -days 365 -copy_extensions copy
            
            # Move temp files to final names and set permissions
            docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine sh -c "mv temp_server.key server.key && mv temp_server.crt server.crt && chmod 600 server.key && chmod 644 server.crt ca.crt && rm -f temp_server.csr ca.srl ca.key"
            
            if ((Test-Path "certs\ca.crt") -and (Test-Path "certs\server.crt") -and (Test-Path "certs\server.key")) {
                Write-Host "SSL certificates generated successfully" -ForegroundColor Green
                Write-Host "Note: alpine/openssl image preserved for future SSL operations" -ForegroundColor Gray
            } else {
                throw "Certificate files not created properly"
            }
        } catch {
            Write-Host "SSL certificate generation failed: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "SSL will be disabled for this installation" -ForegroundColor Yellow
            $EnableSSL = $false
            
            # Update .env to disable SSL
            $EnvContent = $EnvContent -replace "ENABLE_SSL=true", "ENABLE_SSL=false"
            Set-Content -Path ".env" -Value $EnvContent
        }
    } elseif (Test-Path "certs\server.crt") {
        Write-Host "SSL certificates already exist" -ForegroundColor Gray
    }
}

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
Write-Host "Initialization script created" -ForegroundColor Green
Write-Host "Configuration validated" -ForegroundColor Green
Write-Host ""
Write-Host "TimescaleDB Database Details:" -ForegroundColor Cyan
Write-Host "  Database: $DatabaseName" -ForegroundColor White
Write-Host "  Username: $Username" -ForegroundColor White
Write-Host "  Password: $Password" -ForegroundColor Yellow
Write-Host "  Port: 5432" -ForegroundColor White
if ($EnableSSL) {
    Write-Host "  SSL: Enabled (TLSv1.2+)" -ForegroundColor Green
    Write-Host "  Domain: $Domain" -ForegroundColor White
    $connStr = "postgresql://$Username" + ":<password>@localhost:5432/$DatabaseName?sslmode=require"
    Write-Host "  Connection: $connStr" -ForegroundColor White
} else {
    Write-Host "  SSL: Disabled" -ForegroundColor Yellow
    $connStr = "postgresql://$Username" + ":<password>@localhost:5432/$DatabaseName"
    Write-Host "  Connection: $connStr" -ForegroundColor White
}
Write-Host ""
Write-Host "pgAdmin Web UI Details:" -ForegroundColor Cyan
if ($EnableSSL) {
    Write-Host "  URL: https://localhost:5051 (HTTPS)" -ForegroundColor White
    Write-Host "  HTTP Redirect: http://localhost:5050 -> https://localhost:5051" -ForegroundColor Gray
} else {
    Write-Host "  URL: http://localhost:5050" -ForegroundColor White
}
Write-Host "  Email: $PgAdminEmail" -ForegroundColor White
Write-Host "  Password: $PgAdminPassword" -ForegroundColor Yellow
Write-Host "  Note: TimescaleDB server is pre-configured in pgAdmin" -ForegroundColor Gray
Write-Host ""
Write-Host "PostgREST REST API Details:" -ForegroundColor Cyan
Write-Host "  URL (HTTP):  http://localhost:$PostgrestPort" -ForegroundColor White
if ($EnableSSL) {
    Write-Host "  URL (HTTPS): https://localhost:$PostgrestHttpsPort" -ForegroundColor White
}
Write-Host "  Exposes: api schema as REST endpoints" -ForegroundColor Gray
Write-Host "  JWT Secret:              $PgrstJwtSecret" -ForegroundColor Yellow
Write-Host "  Authenticator password:  $PostgrestAuthenticatorPassword" -ForegroundColor Yellow
Write-Host "  CORS origins: $PostgrestCorsOrigins" -ForegroundColor Gray
Write-Host "  OpenAPI schema: GET http://localhost:$PostgrestPort/" -ForegroundColor Gray
Write-Host "  Tiger Cloud: set PGRST_DB_URI in .env to your Timescale Cloud connection string" -ForegroundColor Cyan
Write-Host ""
Write-Host "Installation completed successfully!" -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Cyan

# When called from stack installer (-Force), only configure - don't start services
if ($Force) {
    Write-Host ""
    Write-Host "[OK] TimescaleDB configuration complete (services will be started by stack installer)" -ForegroundColor Green
    exit 0
}

# Ask if user wants to start TimescaleDB now
Write-Host ""
$StartChoice = Read-Host "Start TimescaleDB database now? (y/n)"
if ($StartChoice -eq "" -or $StartChoice -eq "Y" -or $StartChoice -eq "y") {
    Write-Host "Starting TimescaleDB database..." -ForegroundColor Green
    docker-compose up -d
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "TimescaleDB database started successfully!" -ForegroundColor Green
        
        Write-Host "Waiting for database to initialize..." -ForegroundColor Yellow
        Start-Sleep -Seconds 15
        
        # Check status
        Write-Host "Checking database status..." -ForegroundColor White
        $Status = docker-compose ps --format json | ConvertFrom-Json
        $TimescaleDBStatus = $Status | Where-Object { $_.Service -eq "timescaledb" }
        
        if ($TimescaleDBStatus -and $TimescaleDBStatus.State -eq "running") {
            Write-Host "[OK] TimescaleDB database is running successfully!" -ForegroundColor Green
            Write-Host "[OK] Ready to accept connections" -ForegroundColor Green
            
            if ($EnableSSL) {
                Write-Host "[OK] SSL/TLS encryption enabled" -ForegroundColor Green
                Write-Host "[OK] Connect with: psql 'postgresql://$Username@localhost:5432/$DatabaseName?sslmode=require'" -ForegroundColor Cyan
            } else {
                Write-Host "[OK] Connect with: psql -h localhost -U $Username -d $DatabaseName" -ForegroundColor Cyan
            }
        } else {
            Write-Host "[WARN] Database may still be initializing" -ForegroundColor Yellow
            Write-Host "Check logs with: docker-compose logs timescaledb" -ForegroundColor Gray
        }
    } else {
        Write-Host "Failed to start TimescaleDB database" -ForegroundColor Red
        Write-Host "Check configuration and try: docker-compose up -d" -ForegroundColor Gray
    }
} else {
    Write-Host "TimescaleDB database not started" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To start manually:" -ForegroundColor Cyan
    Write-Host "1. Start the database: docker-compose up -d" -ForegroundColor White
    Write-Host "2. Check status: docker-compose ps" -ForegroundColor White
    Write-Host "3. View logs: docker-compose logs -f timescaledb" -ForegroundColor White
}

Write-Host ""
Write-Host "Management Commands:" -ForegroundColor Cyan
Write-Host "===================" -ForegroundColor Gray
if ($UseCAProvided) {
    Write-Host "- Install CA certificates: .\management\manage-ssl.ps1 -Enable -Domain '$Domain'" -ForegroundColor Cyan
}
Write-Host "- SSL management: .\management\manage-ssl.ps1 -Enable/-Disable" -ForegroundColor White
Write-Host ""
Write-Host "Configuration files:" -ForegroundColor Cyan
Write-Host "  - docker-compose.yml (main configuration)" -ForegroundColor White
Write-Host "  - .env (environment variables)" -ForegroundColor White
Write-Host "  - init/01-init-timescaledb.sql (TimescaleDB initialization)" -ForegroundColor White
Write-Host "  - init/02-init-postgrest.sql (PostgREST roles and api schema)" -ForegroundColor White
Write-Host "  - config/postgresql.conf (PostgreSQL configuration)" -ForegroundColor White
Write-Host "  - pgadmin/servers.json (pgAdmin server configuration)" -ForegroundColor White
if ($EnableSSL) {
    Write-Host "  - certs/ (SSL certificates)" -ForegroundColor White
    Write-Host "  - postgrest/nginx.conf (PostgREST HTTPS proxy)" -ForegroundColor White
}

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "Automated Backup System" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "Backup Configuration:" -ForegroundColor White
Write-Host "  - Automated backups: ENABLED" -ForegroundColor Green
Write-Host "  - Schedule: Daily at 2:00 AM" -ForegroundColor Gray
Write-Host "  - Retention: $BackupRetentionDays days" -ForegroundColor Gray
Write-Host "  - Compression: Enabled (gzip)" -ForegroundColor Gray
Write-Host "  - Storage: ./backups directory" -ForegroundColor Gray
Write-Host ""
Write-Host "Data Storage:" -ForegroundColor White
Write-Host "  - Database data: Docker volume 'timescaledb_data' (persistent)" -ForegroundColor Gray
Write-Host "  - Automated backups: ./backups directory" -ForegroundColor Gray
Write-Host ""
Write-Host "The Docker volume persists data even when containers are recreated." -ForegroundColor Green
Write-Host "Automated backups run continuously via backup container." -ForegroundColor Green
Write-Host ""
Write-Host "Backup Management:" -ForegroundColor White
Write-Host "  - View backups: ls -lh ./backups" -ForegroundColor Cyan
Write-Host "  - Manual backup: docker exec timescaledb-backup /usr/local/bin/backup.sh" -ForegroundColor Cyan
Write-Host "  - View logs: docker-compose logs backup" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

# Return to appropriate directory based on how script was called
if (-not $Force) {
    Set-Location management
}
