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

for dir in init backups; do
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        print_color "$GREEN" "Created directory: $dir"
    else
        print_color "$GRAY" "Directory exists: $dir"
    fi
done

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

# TimescaleDB Settings
TIMESCALEDB_TELEMETRY=off

# Backup Configuration
BACKUP_RETENTION_DAYS=30

# Generated on: $(date '+%Y-%m-%d %H:%M:%S')
EOF

print_color "$GREEN" "Created: .env"

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

echo ""
echo "Next Steps:"
print_color "$GRAY" "  1. Start the database: docker-compose up -d"
print_color "$GRAY" "  2. Check status: docker-compose ps"
print_color "$GRAY" "  3. View logs: docker-compose logs -f"
print_color "$GRAY" "  4. Connect: docker exec -it timescaledb psql -U $USERNAME -d $DATABASE_NAME"

echo ""
print_color "$YELLOW" "Security Notes:"
print_color "$WHITE" "  - Store the password securely"
print_color "$WHITE" "  - Configure firewall rules for port $PORT"
print_color "$WHITE" "  - Regularly backup your data"

echo ""
print_color "$GREEN" "Installation completed successfully!"
print_color "$CYAN" "=================================================================="

exit 0
