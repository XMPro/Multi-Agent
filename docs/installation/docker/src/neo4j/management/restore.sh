#!/bin/bash
# =================================================================
# Neo4j Restore Script (Linux)
# =================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; GRAY='\033[0;37m'; NC='\033[0m'

print_color() { echo -e "${1}${@:2}${NC}"; }

BACKUP_FILE=""
[ $# -gt 0 ] && BACKUP_FILE="$1"

[ "$(basename "$(pwd)")" = "management" ] && cd ..

print_color "$CYAN" "=================================================================="
print_color "$CYAN" "Neo4j Restore Script"
print_color "$CYAN" "=================================================================="

if [ -z "$BACKUP_FILE" ]; then
    echo "Available backups:"
    ls -1 neo4j-data/backups/*.tar.gz 2>/dev/null || echo "No backups found"
    read -p "Enter backup file path: " BACKUP_FILE
fi

[ ! -f "$BACKUP_FILE" ] && { print_color "$RED" "Backup file not found!"; exit 1; }

print_color "$YELLOW" "Stopping Neo4j..."
docker-compose down

echo "Restoring from: $BACKUP_FILE"
tar -xzf "$BACKUP_FILE" -C neo4j-data

print_color "$GREEN" "Restore completed!"
print_color "$CYAN" "Start Neo4j with: docker-compose up -d"
