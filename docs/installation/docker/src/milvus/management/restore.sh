#!/bin/bash
set -euo pipefail
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
print_color() { echo -e "${1}${@:2}${NC}"; }

BACKUP_FILE="${1:-}"
[ "$(basename "$(pwd)")" = "management" ] && cd ..

print_color "$CYAN" "=================================================================="
print_color "$CYAN" "Milvus Restore Script"
print_color "$CYAN" "=================================================================="

[ -z "$BACKUP_FILE" ] && { echo "Available backups:"; ls -1 milvus-data/backups/*.tar.gz 2>/dev/null || echo "None"; read -p "Enter backup file: " BACKUP_FILE; }
[ ! -f "$BACKUP_FILE" ] && { print_color "$RED" "Backup not found!"; exit 1; }

print_color "$YELLOW" "Stopping Milvus..."
docker-compose down
echo "Restoring from: $BACKUP_FILE"
tar -xzf "$BACKUP_FILE" -C milvus-data
print_color "$GREEN" "Restore completed! Start with: docker-compose up -d"
