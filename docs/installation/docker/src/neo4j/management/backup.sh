#!/bin/bash
# =================================================================
# Neo4j Backup Script (Linux)
# =================================================================

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m'

# Default parameters
BACKUP_NAME=""
BACKUP_PATH=""

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
    echo "  -n, --name NAME        Backup name (default: neo4j-backup-TIMESTAMP)"
    echo "  -p, --path PATH        Backup directory (default: ./neo4j-data/backups)"
    echo "  -h, --help             Show this help message"
    echo ""
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--name) BACKUP_NAME="$2"; shift 2 ;;
        -p|--path) BACKUP_PATH="$2"; shift 2 ;;
        -h|--help) show_usage ;;
        *) print_color "$RED" "Unknown option: $1"; show_usage ;;
    esac
done

# Navigate to neo4j directory
[ "$(basename "$(pwd)")" = "management" ] && cd ..

print_color "$CYAN" "=================================================================="
print_color "$CYAN" "Neo4j Backup Script"
print_color "$CYAN" "=================================================================="

# Set defaults
[ -z "$BACKUP_PATH" ] && BACKUP_PATH="./neo4j-data/backups"
[ -z "$BACKUP_NAME" ] && BACKUP_NAME="neo4j-backup-$(date +%Y%m%d-%H%M%S)"

mkdir -p "$BACKUP_PATH"

# Check if Neo4j is running
if ! docker-compose ps | grep -q "neo4j.*Up"; then
    print_color "$YELLOW" "Neo4j is not running. Starting for backup..."
    docker-compose up -d
    sleep 10
fi

# Create backup
echo "Creating backup: $BACKUP_NAME"
BACKUP_FILE="$BACKUP_PATH/$BACKUP_NAME.tar.gz"

# Backup data directory
tar -czf "$BACKUP_FILE" -C neo4j-data data logs 2>/dev/null

if [ -f "$BACKUP_FILE" ]; then
    SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    print_color "$GREEN" "Backup created: $BACKUP_FILE ($SIZE)"
    print_color "$CYAN" "=================================================================="
    print_color "$GREEN" "Backup completed successfully!"
else
    print_color "$RED" "Backup failed!"
    exit 1
fi
