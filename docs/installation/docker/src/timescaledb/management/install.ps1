# =================================================================
# TimescaleDB Installation Script (PowerShell)
# Production-Grade Time-Series Database Setup
# =================================================================

param(
    [switch]$Force = $false,
    [switch]$EnableSSL = $false,
    [string]$Domain = "localhost",
    [string]$Password = "",
    [int]$Port = 5432,
    [string]$DatabaseName = "timescaledb",
    [string]$Username = "postgres"
)

$ErrorActionPreference = "Stop"

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "TimescaleDB Time-Series Database - Installation" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

# Function to generate secure password
function New-SecurePassword {
    $length = 32
    $chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()-_=+"
    $password = -join ((1..$length) | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
    return $password
}

# Check if Docker is running
try {
    docker version | Out-Null
    Write-Host "Docker is running" -ForegroundColor Green
} catch {
    Write-Host "Docker is not running! Please start Docker and try again." -ForegroundColor Red
    exit 1
}

# Get or generate database password
if (-not $Password) {
    $Password = $env:TIMESCALEDB_PASSWORD
    if (-not $Password) {
        if ($Force) {
            $Password = New-SecurePassword
            Write-Host "Generated secure password automatically" -ForegroundColor Green
        } else {
            Write-Host ""
            Write-Host "Database Password Configuration" -ForegroundColor Yellow
            Write-Host "==============================" -ForegroundColor Gray
            Write-Host "You can:" -ForegroundColor White
            Write-Host "  1. Enter a password now" -ForegroundColor White
            Write-Host "  2. Press Enter to auto-generate a secure password" -ForegroundColor White
            Write-Host ""
            
            $SecurePassword = Read-Host "Enter database password (or press Enter to auto-generate)" -AsSecureString
            $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)
            $PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
            
            if ($PlainPassword) {
                $Password = $PlainPassword
                Write-Host "Using provided password" -ForegroundColor Green
            } else {
                $Password = New-SecurePassword
                Write-Host "Generated secure password" -ForegroundColor Green
            }
        }
    } else {
        Write-Host "Using password from TIMESCALEDB_PASSWORD environment variable" -ForegroundColor Green
    }
}

# Create necessary directories
Write-Host ""
Write-Host "Creating Directory Structure..." -ForegroundColor White
Write-Host "==============================" -ForegroundColor Gray

$directories = @("config", "init", "backups", "certs")
foreach ($dir in $directories) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        Write-Host "Created directory: $dir" -ForegroundColor Green
    } else {
        Write-Host "Directory exists: $dir" -ForegroundColor Gray
    }
}

# Create PostgreSQL configuration file
Write-Host ""
Write-Host "Creating PostgreSQL Configuration..." -ForegroundColor White
Write-Host "====================================" -ForegroundColor Gray

$postgresqlConf = @"
# =================================================================
# PostgreSQL Configuration for TimescaleDB
# Production-Grade Settings
# =================================================================

# Connection Settings
listen_addresses = '*'
port = 5432
max_connections = 100
superuser_reserved_connections = 3

# Memory Settings (adjust based on your server's RAM)
# For a system with 8GB RAM:
shared_buffers = 2GB                    # 25% of RAM
effective_cache_size = 6GB              # 75% of RAM
work_mem = 20MB                         # RAM / max_connections / 4
maintenance_work_mem = 512MB            # RAM / 16

# Query Tuning
random_page_cost = 1.1                  # For SSD storage
effective_io_concurrency = 200          # For SSD storage
default_statistics_target = 100

# Write Ahead Log (WAL)
wal_level = replica
wal_buffers = 16MB
min_wal_size = 1GB
max_wal_size = 4GB
checkpoint_completion_target = 0.9
archive_mode = on
archive_command = 'test ! -f /backups/wal/%f && cp %p /backups/wal/%f'

# Replication (for future HA setup)
max_wal_senders = 10
max_replication_slots = 10
hot_standby = on

# Logging
logging_collector = on
log_directory = 'log'
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
log_rotation_age = 1d
log_rotation_size = 100MB
log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '
log_checkpoints = on
log_connections = on
log_disconnections = on
log_duration = off
log_lock_waits = on
log_statement = 'ddl'
log_temp_files = 0
log_autovacuum_min_duration = 0

# Autovacuum
autovacuum = on
autovacuum_max_workers = 4
autovacuum_naptime = 10s
autovacuum_vacuum_threshold = 50
autovacuum_analyze_threshold = 50
autovacuum_vacuum_scale_factor = 0.02
autovacuum_analyze_scale_factor = 0.01
autovacuum_vacuum_cost_delay = 2ms
autovacuum_vacuum_cost_limit = 200

# Background Writer
bgwriter_delay = 200ms
bgwriter_lru_maxpages = 100
bgwriter_lru_multiplier = 2.0

# Async Commit (trade-off between performance and durability)
synchronous_commit = on                 # Set to 'off' for better performance with acceptable data loss risk

# TimescaleDB Specific Settings
shared_preload_libraries = 'timescaledb'
timescaledb.telemetry_level = off
timescaledb.max_background_workers = 8

# SSL Configuration (if enabled)
ssl = {SSL_ENABLED}
ssl_cert_file = '/var/lib/postgresql/certs/server.crt'
ssl_key_file = '/var/lib/postgresql/certs/server.key'
ssl_ca_file = '/var/lib/postgresql/certs/ca.crt'
ssl_prefer_server_ciphers = on
ssl_ciphers = 'HIGH:MEDIUM:+3DES:!aNULL'
ssl_min_protocol_version = 'TLSv1.2'

# Locale
lc_messages = 'en_US.utf8'
lc_monetary = 'en_US.utf8'
lc_numeric = 'en_US.utf8'
lc_time = 'en_US.utf8'
default_text_search_config = 'pg_catalog.english'
"@

$sslEnabled = if ($EnableSSL) { "on" } else { "off" }
$postgresqlConf = $postgresqlConf -replace '{SSL_ENABLED}', $sslEnabled

$postgresqlConf | Out-File -FilePath "config\postgresql.conf" -Encoding UTF8
Write-Host "Created: config\postgresql.conf" -ForegroundColor Green

# Create initialization SQL script
Write-Host ""
Write-Host "Creating Initialization Script..." -ForegroundColor White
Write-Host "=================================" -ForegroundColor Gray

$initSQL = @"
-- =================================================================
-- TimescaleDB Initialization Script
-- =================================================================

-- Create TimescaleDB extension
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- Enable additional useful extensions
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Create a sample schema for time-series data (optional - can be removed)
CREATE SCHEMA IF NOT EXISTS timeseries;

-- Set default privileges for the schema
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
Write-Host "Created: init\01-init-timescaledb.sql" -ForegroundColor Green

# Create .env file
Write-Host ""
Write-Host "Creating Environment Configuration..." -ForegroundColor White
Write-Host "=====================================" -ForegroundColor Gray

$envContent = @"
# =================================================================
# TimescaleDB Environment Configuration
# =================================================================

# Database Configuration
POSTGRES_DB=$DatabaseName
POSTGRES_USER=$Username
POSTGRES_PASSWORD=$Password
POSTGRES_PORT=$Port

# Performance Tuning (adjust based on your server)
POSTGRES_SHARED_BUFFERS=2GB
POSTGRES_EFFECTIVE_CACHE_SIZE=6GB
POSTGRES_WORK_MEM=20MB
POSTGRES_MAINTENANCE_WORK_MEM=512MB

# TimescaleDB Settings
TIMESCALEDB_TELEMETRY=off

# SSL Configuration
ENABLE_SSL=$($EnableSSL.ToString().ToLower())
DOMAIN=$Domain

# Backup Configuration
BACKUP_RETENTION_DAYS=30

# Generated on: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
"@

$envContent | Out-File -FilePath ".env" -Encoding UTF8
Write-Host "Created: .env" -ForegroundColor Green

# Handle SSL configuration
if ($EnableSSL) {
    Write-Host ""
    Write-Host "Configuring SSL/TLS..." -ForegroundColor White
    Write-Host "======================" -ForegroundColor Gray
    
    # Check if certificates already exist
    if (Test-Path "certs\server.crt") {
        Write-Host "SSL certificates already exist" -ForegroundColor Yellow
        if (-not $Force) {
            $Recreate = Read-Host "Recreate certificates? (y/n)"
            if ($Recreate -ne "Y" -and $Recreate -ne "y") {
                Write-Host "Using existing certificates" -ForegroundColor Green
            } else {
                & ".\manage-ssl.ps1" -Enable -Domain $Domain -Force
            }
        }
    } else {
        & ".\manage-ssl.ps1" -Enable -Domain $Domain -Force
    }
} else {
    Write-Host ""
    Write-Host "SSL/TLS is disabled" -ForegroundColor Yellow
    Write-Host "To enable SSL later, run: .\manage-ssl.ps1 -Enable" -ForegroundColor Gray
}

# Create docker-compose.yml if it doesn't exist
if (-not (Test-Path "..\docker-compose.yml")) {
    Write-Host ""
    Write-Host "Warning: docker-compose.yml not found in parent directory" -ForegroundColor Yellow
}

# Display installation summary
Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "Installation Summary" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "Database Configuration:" -ForegroundColor White
Write-Host "  Database Name: $DatabaseName" -ForegroundColor Gray
Write-Host "  Username: $Username" -ForegroundColor Gray
Write-Host "  Password: $Password" -ForegroundColor Gray
Write-Host "  Port: $Port" -ForegroundColor Gray

Write-Host ""
Write-Host "Connection String:" -ForegroundColor White
Write-Host "  postgresql://${Username}:${Password}@localhost:${Port}/${DatabaseName}" -ForegroundColor Gray

if ($EnableSSL) {
    Write-Host ""
    Write-Host "SSL Configuration:" -ForegroundColor White
    Write-Host "  Enabled: Yes" -ForegroundColor Green
    Write-Host "  Domain: $Domain" -ForegroundColor Gray
    Write-Host "  Certificates: certs\" -ForegroundColor Gray
    Write-Host "  Connection String (SSL):" -ForegroundColor White
    Write-Host "    postgresql://${Username}:${Password}@localhost:${Port}/${DatabaseName}?sslmode=require" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Next Steps:" -ForegroundColor White
Write-Host "  1. Start the database: docker-compose up -d" -ForegroundColor Gray
Write-Host "  2. Check status: docker-compose ps" -ForegroundColor Gray
Write-Host "  3. View logs: docker-compose logs -f" -ForegroundColor Gray
Write-Host "  4. Connect: docker exec -it timescaledb psql -U $Username -d $DatabaseName" -ForegroundColor Gray

Write-Host ""
Write-Host "Security Notes:" -ForegroundColor Yellow
Write-Host "  - Store the password securely" -ForegroundColor White
Write-Host "  - Consider enabling SSL for production" -ForegroundColor White
Write-Host "  - Configure firewall rules for port $Port" -ForegroundColor White
Write-Host "  - Regularly backup your data" -ForegroundColor White

Write-Host ""
Write-Host "Installation completed successfully!" -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Cyan

exit 0
