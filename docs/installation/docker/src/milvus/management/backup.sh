#!/bin/bash
# =================================================================
# Milvus Backup Script (Linux)
# =================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'

print_color() { echo -e "${1}${@:2}${NC}"; }

BACKUP_NAME="${1:-milvus-backup-$(date +%Y%m%d-%H%M%S)}"
BACKUP_PATH="./milvus-data/backups"

[ "$(basename "$(pwd)")" = "management" ] && cd ..

print_color "$CYAN" "=================================================================="
print_color "$CYAN" "Milvus Backup Script"
print_color "$CYAN" "=================================================================="

mkdir -p "$BACKUP_PATH"

if ! docker-compose ps | grep -q "Up"; then
    print_color "$YELLOW" "Starting Milvus for backup..."
    docker-compose up -d
    sleep 10
fi

echo "Creating backup: $BACKUP_NAME"
tar -czf "$BACKUP_PATH/$BACKUP_NAME.tar.gz" -C milvus-data milvus etcd minio 2>/dev/null

SIZE=$(du -h "$BACKUP_PATH/$BACKUP_NAME.tar.gz" | cut -f1)
print_color "$GREEN" "Backup created: $BACKUP_PATH/$BACKUP_NAME.tar.gz ($SIZE)"
print_color "$GREEN" "Backup completed!"
