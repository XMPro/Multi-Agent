#!/bin/bash
# =================================================================
# TimescaleDB Restore Script (Bash)
# Production-Grade Database Restore
# =================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m'

BACKUP_FILE=""
FORCE=false
DROP_DATABASE=false

print_color() {
    local color=$1
    shift
    echo -e "${color}$@${NC}"
}

show_usage() {
    echo "Usage: $0 --file BACKUP_FILE [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --file FILE              Backup file to restore (required)"
    echo "  --force                  Skip confirmation prompt"
    echo "  --drop-database          Drop and recreate database before restore"
    echo "  -h, --help               Show this help message"
    exit 0
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --file) BACKUP_FILE="$2"; shift 2 ;;
        --force) FORCE=true; shift ;;
        --drop-database) DROP_DATABASE=true; shift ;;
        -h|--help) show_usage ;;
        *) print_color "$RED" "Unknown option: $1"; show_usage ;;
    esac
done

if [ -z "$BACKUP_FILE" ]; then
    print_color "$RED" "Error: Backup file is required"
    show_usage
fi

print_color "$CYAN" "=================================================================="
print_color "$CYAN" "TimescaleDB Restore Script"
print_color "$CYAN" "=================================================================="

if [ ! -f "$BACKUP_FILE" ]; then
    print_color "$RED" "Error: Backup file not found: $BACKUP_FILE"
    exit 1
fi

print_color "$WHITE" "Backup file: $BACKUP_FILE"

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

DB_NAME="${POSTGRES_DB:-}"
DB_USER="${POSTGRES_USER:-}"
DB_PASSWORD="${POSTGRES_PASSWORD:-}"

if [ "$FORCE" = false ]; then
    echo ""
    print_color "$YELLOW" "WARNING: This will restore the database from backup!"
    print_color "$GRAY" "  Database: $DB_NAME"
    print_color "$GRAY" "  User: $DB_USER"
    print_color "$RED" "  All current data will be replaced!"
    echo ""
    read -p "Continue with restore? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        print_color "$YELLOW" "Restore cancelled"
        exit 0
    fi
fi

# Check if file is compressed
RESTORE_FILE="$BACKUP_FILE"
TEMP_FILE=""

if [[ "$BACKUP_FILE" == *.gz ]]; then
    echo ""
    echo "Decompressing backup..."
    TEMP_FILE=$(mktemp)
    gunzip -c "$BACKUP_FILE" > "$TEMP_FILE"
    RESTORE_FILE="$TEMP_FILE"
    print_color "$GREEN" "Decompressed successfully"
fi

echo ""
echo "Restoring database..."

# Stop any active connections
docker exec -e PGPASSWORD="$DB_PASSWORD" timescaledb psql -U "$DB_USER" -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$DB_NAME' AND pid <> pg_backend_pid();" 2>/dev/null || true

if [ "$DROP_DATABASE" = true ]; then
    print_color "$YELLOW" "Dropping existing database..."
    docker exec -e PGPASSWORD="$DB_PASSWORD" timescaledb psql -U "$DB_USER" -d postgres -c "DROP DATABASE IF EXISTS $DB_NAME;" 2>/dev/null
    docker exec -e PGPASSWORD="$DB_PASSWORD" timescaledb psql -U "$DB_USER" -d postgres -c "CREATE DATABASE $DB_NAME;" 2>/dev/null
fi

# Restore database
if cat "$RESTORE_FILE" | docker exec -i -e PGPASSWORD="$DB_PASSWORD" timescaledb psql -U "$DB_USER" -d "$DB_NAME" > /dev/null 2>&1; then
    print_color "$GREEN" "Database restored successfully"
else
    print_color "$RED" "Error during restore"
    [ -n "$TEMP_FILE" ] && rm -f "$TEMP_FILE"
    exit 1
fi

# Cleanup temp file
[ -n "$TEMP_FILE" ] && rm -f "$TEMP_FILE"

echo ""
print_color "$CYAN" "=================================================================="
print_color "$GREEN" "Restore completed successfully!"
print_color "$CYAN" "=================================================================="

exit 0
