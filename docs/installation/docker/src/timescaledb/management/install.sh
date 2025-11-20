#!/bin/bash
# =================================================================
# TimescaleDB Installation Script (Bash)
# Production-Grade Time-Series Database Setup
# =================================================================

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

# Default parameters
FORCE=false
ENABLE_SSL=false
DOMAIN="localhost"
PASSWORD=""
PORT=5432
DATABASE_NAME="timescaledb"
USERNAME="postgres"

# Function to print colored output
print_color() {
    local color=$1
    shift
    echo -e "${color}$@${NC}"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --force                  Skip confirmation prompts"
    echo "  --enable-ssl             Enable SSL/TLS encryption"
    echo "  --domain DOMAIN          Domain for SSL certificates (default: localhost)"
    echo "  --password PASSWORD      Database password (not recommended)"
    echo "  --port PORT              Database port (default: 5432)"
    echo "  --database DATABASE      Database name (default: timescaledb)"
    echo "  --username USERNAME      Database username (default: postgres)"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  TIMESCALEDB_PASSWORD     Database password (recommended method)"
    echo ""
    exit 0
}

# Function to generate secure password
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-32
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE=true
            shift
            ;;
        --enable-ssl)
            ENABLE_SSL=true
            shift
            ;;
        --domain)
            DOMAIN="$2"
            shift 2
            ;;
        --password)
            PASSWORD="$2"
            shift 2
            ;;
        --port)
            PORT="$2"
            shift 2
            ;;
        --database)
            DATABASE_NAME="$2"
            shift 2
            ;;
        --username)
            USERNAME="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            ;;
        *)
            print_color "$RED" "Unknown option: $1"
            show_usage
            ;;
    esac
done

print_color "$CYAN" "=================================================================="
print_color "$CYAN" "TimescaleDB Time-Series Database - Installation"
print_color "$CYAN" "=================================================================="

# Check if Docker is running
if ! docker version >/dev/null 2>&1; then
    print_color "$RED" "Docker is not running! Please start Docker and try again."
    exit 1
fi
print_color "$GREEN" "Docker is running"

# Get or generate database password
if [ -z "$PASSWORD" ]; then
    PASSWORD="${TIMESCALEDB_PASSWORD:-}"
    if [ -z "$PASSWORD" ]; then
        if [ "$FORCE" = true ]; then
            PASSWORD=$(generate_password)
            print_color "$GREEN" "Generated secure password automatically"
        else
            echo ""
            print_color "$YELLOW" "Database Password Configuration"
            print_color "$GRAY" "=============================="
            print_color "$WHITE" "You can:"
            print_color "$WHITE" "  1. Enter a password now"
            print_color "$WHITE" "  2. Press Enter to auto-generate a secure password"
            echo ""
            
            read -s -p "Enter database password (or press Enter to auto-generate): " ENTERED_PASSWORD
            echo ""
            
            if [ -n "$ENTERED_PASSWORD" ]; then
                PASSWORD="$ENTERED_PASSWORD"
                print_color "$GREEN" "Using provided password"
            else
                PASSWORD=$(generate_password)
                print_color "$GREEN" "Generated secure password"
            fi
        fi
    else
        print_color "$GREEN" "Using password from TIMESCALEDB_PASSWORD environment variable"
    fi
fi

# Create necessary directories
echo ""
echo "Creating Directory Structure..."
print_color "$GRAY" "=============================="

for dir in config init backups certs; do
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        print_color "$GREEN" "Created directory: $dir"
    else
        print_color "$GRAY" "Directory exists: $dir"
    fi
done

# Create PostgreSQL configuration file
echo ""
echo "Creating PostgreSQL Configuration..."
print_color "$GRAY" "===================================="

SSL_ENABLED="off"
[ "$ENABLE_SSL" = true ] && SSL_ENABLED="on"

cat > config/postgresql.conf << 'EOF'
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
ssl = SSL_ENABLED_PLACEHOLDER
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
EOF

# Replace SSL placeholder
sed -i "s/SSL_ENABLED_PLACEHOLDER/$SSL_ENABLED/" config/postgresql.conf

print_color "$GREEN" "Created: config/postgresql.conf"

# Create initialization SQL script
echo ""
echo "Creating Initialization Script..."
print_color "$GRAY" "================================="

cat > init/01-init-timescaledb.sql << EOF
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
GRANT CREATE ON SCHEMA timeseries TO $USERNAME;

-- Log successful initialization
DO \$\$
BEGIN
    RAISE NOTICE 'TimescaleDB initialized successfully';
    RAISE NOTICE 'Version: %', (SELECT extversion FROM pg_extension WHERE extname = 'timescaledb');
END
\$\$;
EOF

print_color "$GREEN" "Created: init/01-init-timescaledb.sql"

# Create .env file
echo ""
echo "Creating Environment Configuration..."
print_color "$GRAY" "====================================="

cat > .env << EOF
# =================================================================
# TimescaleDB Environment Configuration
# =================================================================

# Database Configuration
POSTGRES_DB=$DATABASE_NAME
POSTGRES_USER=$USERNAME
POSTGRES_PASSWORD=$PASSWORD
POSTGRES_PORT=$PORT

# Performance Tuning (adjust based on your server)
POSTGRES_SHARED_BUFFERS=2GB
POSTGRES_EFFECTIVE_CACHE_SIZE=6GB
POSTGRES_WORK_MEM=20MB
POSTGRES_MAINTENANCE_WORK_MEM=512MB

# TimescaleDB Settings
TIMESCALEDB_TELEMETRY=off

# SSL Configuration
ENABLE_SSL=$( [ "$ENABLE_SSL" = true ] && echo "true" || echo "false" )
DOMAIN=$DOMAIN

# Backup Configuration
BACKUP_RETENTION_DAYS=30

# Generated on: $(date '+%Y-%m-%d %H:%M:%S')
EOF

print_color "$GREEN" "Created: .env"

# Handle SSL configuration
if [ "$ENABLE_SSL" = true ]; then
    echo ""
    echo "Configuring SSL/TLS..."
    print_color "$GRAY" "======================"
    
    # Check if certificates already exist
    if [ -f "certs/server.crt" ]; then
        print_color "$YELLOW" "SSL certificates already exist"
        if [ "$FORCE" = false ]; then
            read -p "Recreate certificates? (y/n): " recreate
            if [[ "$recreate" =~ ^[Yy]$ ]]; then
                chmod +x manage-ssl.sh
                ./manage-ssl.sh --enable --domain "$DOMAIN" --force
            else
                print_color "$GREEN" "Using existing certificates"
            fi
        fi
    else
        chmod +x manage-ssl.sh
        ./manage-ssl.sh --enable --domain "$DOMAIN" --force
    fi
else
    echo ""
    print_color "$YELLOW" "SSL/TLS is disabled"
    print_color "$GRAY" "To enable SSL later, run: ./manage-ssl.sh --enable"
fi

# Check docker-compose.yml
if [ ! -f "../docker-compose.yml" ]; then
    echo ""
    print_color "$YELLOW" "Warning: docker-compose.yml not found in parent directory"
fi

# Display installation summary
echo ""
print_color "$CYAN" "=================================================================="
print_color "$CYAN" "Installation Summary"
print_color "$CYAN" "=================================================================="

echo ""
echo "Database Configuration:"
print_color "$GRAY" "  Database Name: $DATABASE_NAME"
print_color "$GRAY" "  Username: $USERNAME"
print_color "$GRAY" "  Password: $PASSWORD"
print_color "$GRAY" "  Port: $PORT"

echo ""
echo "Connection String:"
print_color "$GRAY" "  postgresql://${USERNAME}:${PASSWORD}@localhost:${PORT}/${DATABASE_NAME}"

if [ "$ENABLE_SSL" = true ]; then
    echo ""
    echo "SSL Configuration:"
    print_color "$GREEN" "  Enabled: Yes"
    print_color "$GRAY" "  Domain: $DOMAIN"
    print_color "$GRAY" "  Certificates: certs/"
    echo "  Connection String (SSL):"
    print_color "$GRAY" "    postgresql://${USERNAME}:${PASSWORD}@localhost:${PORT}/${DATABASE_NAME}?sslmode=require"
fi

echo ""
echo "Next Steps:"
print_color "$GRAY" "  1. Start the database: docker-compose up -d"
print_color "$GRAY" "  2. Check status: docker-compose ps"
print_color "$GRAY" "  3. View logs: docker-compose logs -f"
print_color "$GRAY" "  4. Connect: docker exec -it timescaledb psql -U $USERNAME -d $DATABASE_NAME"

echo ""
print_color "$YELLOW" "Security Notes:"
print_color "$WHITE" "  - Store the password securely"
print_color "$WHITE" "  - Consider enabling SSL for production"
print_color "$WHITE" "  - Configure firewall rules for port $PORT"
print_color "$WHITE" "  - Regularly backup your data"

echo ""
print_color "$GREEN" "Installation completed successfully!"
print_color "$CYAN" "=================================================================="

exit 0
