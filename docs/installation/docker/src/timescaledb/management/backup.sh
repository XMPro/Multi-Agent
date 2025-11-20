#!/bin/bash
# =================================================================
# TimescaleDB Backup Script (Bash)
# Production-Grade Database Backup
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
BACKUP_NAME=""
BACKUP_DIR="../backups"
COMPRESS=true
INCLUDE_SCHEMA=true
VERBOSE=false

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
    echo "  --name NAME              Backup name (default: auto-generated)"
    echo "  --dir DIRECTORY          Backup directory (default: ../backups)"
    echo "  --no-compress            Don't compress backup"
    echo "  --no-schema              Don't include schema in backup"
    echo "  --verbose                Verbose output"
    echo "  -h, --help               Show this help message"
    echo ""
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --name)
            BACKUP_NAME="$2"
            shift 2
            ;;
        --dir)
            BACKUP_DIR="$2"
            shift 2
            ;;
        --no-compress)
            COMPRESS=false
            shift
            ;;
        --no-schema)
            INCLUDE_SCHEMA=false
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
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
print_color "$CYAN" "TimescaleDB Backup Script"
print_color "$CYAN" "=================================================================="

# Load environment variables
if [ -f ".env" ]; then
    set -a
    source .env
    set +a
    print_color "$GREEN" "Loaded configuration from .env"
else
    print_color "$YELLOW" "Warning: .env file not found"
    exit 1
fi

# Get database configuration
DB_NAME="${POSTGRES_DB:-}"
DB_USER="${POSTGRES_USER:-}"
DB_PASSWORD="${POSTGRES_PASSWORD:-}"

if [ -z "$DB_NAME" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASSWORD" ]; then
    print_color "$RED" "Error: Database configuration not found in .env file"
    exit 1
fi

# Generate backup name if not provided
if [ -z "$BACKUP_NAME" ]; then
    BACKUP_NAME="timescaledb_backup_$(date +%Y%m%d_%H%M%S)"
fi

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"
mkdir -p "$BACKUP_DIR/wal"

echo ""
echo "Backup Configuration:"
print_color "$GRAY" "  Database: $DB_NAME"
print_color "$GRAY" "  User: $DB_USER"
print_color "$GRAY" "  Backup Name: $BACKUP_NAME"
print_color "$GRAY" "  Compression: $COMPRESS"
print_color "$GRAY" "  Include Schema: $INCLUDE_SCHEMA"

# Check if container is running
echo ""
echo "Checking database status..."

if ! docker ps --filter "name=timescaledb" --format "{{.Status}}" | grep -q "Up"; then
    print_color "$RED" "Error: TimescaleDB container is not running"
    print_color "$YELLOW" "Start the container with: docker-compose up -d"
    exit 1
fi

print_color "$GREEN" "Container is running"

# Perform backup
echo ""
echo "Creating backup..."
print_color "$GRAY" "=================="

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
print_color "$GRAY" "Backup started at: $TIMESTAMP"

BACKUP_FILE="$BACKUP_DIR/$BACKUP_NAME.sql"

# Build pg_dump command
PG_DUMP_ARGS="-U $DB_USER -d $DB_NAME --format=plain --no-owner --no-acl"

if [ "$INCLUDE_SCHEMA" = true ]; then
    PG_DUMP_ARGS="$PG_DUMP_ARGS --create"
fi

if [ "$VERBOSE" = true ]; then
    PG_DUMP_ARGS="$PG_DUMP_ARGS --verbose"
fi

# Execute pg_dump
if docker exec -e PGPASSWORD="$DB_PASSWORD" timescaledb pg_dump $PG_DUMP_ARGS > "$BACKUP_FILE" 2>&1; then
    print_color "$GREEN" "Database dump created successfully"
    
    # Get file size
    FILE_SIZE=$(stat -f%z "$BACKUP_FILE" 2>/dev/null || stat -c%s "$BACKUP_FILE" 2>/dev/null)
    FILE_SIZE_MB=$(awk "BEGIN {printf \"%.2f\", $FILE_SIZE/1024/1024}")
    print_color "$GRAY" "Backup size: ${FILE_SIZE_MB} MB"
    
    # Compress if requested
    if [ "$COMPRESS" = true ]; then
        echo ""
        echo "Compressing backup..."
        
        gzip -9 "$BACKUP_FILE"
        COMPRESSED_FILE="${BACKUP_FILE}.gz"
        
        COMPRESSED_SIZE=$(stat -f%z "$COMPRESSED_FILE" 2>/dev/null || stat -c%s "$COMPRESSED_FILE" 2>/dev/null)
        COMPRESSED_SIZE_MB=$(awk "BEGIN {printf \"%.2f\", $COMPRESSED_SIZE/1024/1024}")
        COMPRESSION_RATIO=$(awk "BEGIN {printf \"%.1f\", ($FILE_SIZE-$COMPRESSED_SIZE)/$FILE_SIZE*100}")
        
        print_color "$GREEN" "Compressed successfully"
        print_color "$GRAY" "  Compressed size: ${COMPRESSED_SIZE_MB} MB"
        print_color "$GRAY" "  Compression ratio: ${COMPRESSION_RATIO}%"
        
        FINAL_BACKUP_FILE="$COMPRESSED_FILE"
    else
        FINAL_BACKUP_FILE="$BACKUP_FILE"
    fi
    
    # Create backup metadata
    METADATA_FILE="${FINAL_BACKUP_FILE}.meta"
    PG_VERSION=$(docker exec timescaledb psql -U "$DB_USER" -d "$DB_NAME" -t -c 'SELECT version();' 2>/dev/null | xargs)
    TS_VERSION=$(docker exec timescaledb psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT extversion FROM pg_extension WHERE extname = 'timescaledb';" 2>/dev/null | xargs)
    
    cat > "$METADATA_FILE" << EOF
Backup Metadata
===============
Database: $DB_NAME
User: $DB_USER
Backup Time: $TIMESTAMP
Backup File: $(basename "$FINAL_BACKUP_FILE")
Original Size: ${FILE_SIZE_MB} MB
Compressed: $COMPRESS
PostgreSQL Version: $PG_VERSION
TimescaleDB Version: $TS_VERSION
EOF
    
else
    print_color "$RED" "Error during backup"
    exit 1
fi

# Backup retention cleanup
echo ""
echo "Checking backup retention..."

RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
CUTOFF_DATE=$(date -d "$RETENTION_DAYS days ago" +%s 2>/dev/null || date -v-${RETENTION_DAYS}d +%s 2>/dev/null)

OLD_BACKUPS=()
for backup in "$BACKUP_DIR"/*.sql*; do
    if [ -f "$backup" ]; then
        BACKUP_TIME=$(stat -f%m "$backup" 2>/dev/null || stat -c%Y "$backup" 2>/dev/null)
        if [ "$BACKUP_TIME" -lt "$CUTOFF_DATE" ]; then
            OLD_BACKUPS+=("$backup")
        fi
    fi
done

if [ ${#OLD_BACKUPS[@]} -gt 0 ]; then
    print_color "$YELLOW" "Found ${#OLD_BACKUPS[@]} backup(s) older than $RETENTION_DAYS days"
    for old_backup in "${OLD_BACKUPS[@]}"; do
        print_color "$GRAY" "  Removing: $(basename "$old_backup")"
        rm -f "$old_backup"
        rm -f "${old_backup}.meta"
    done
    print_color "$GREEN" "Old backups removed"
else
    print_color "$GRAY" "No old backups to remove (retention: $RETENTION_DAYS days)"
fi

# Display summary
echo ""
print_color "$CYAN" "=================================================================="
print_color "$CYAN" "Backup Summary"
print_color "$CYAN" "=================================================================="

echo ""
print_color "$GREEN" "Backup completed successfully!"
echo ""
echo "Backup Details:"
print_color "$GRAY" "  Location: $FINAL_BACKUP_FILE"
print_color "$GRAY" "  Metadata: $METADATA_FILE"
print_color "$GRAY" "  Retention: $RETENTION_DAYS days"

echo ""
echo "To restore this backup:"
print_color "$GRAY" "  ./restore.sh --file \"$FINAL_BACKUP_FILE\""

echo ""
print_color "$CYAN" "=================================================================="

exit 0
