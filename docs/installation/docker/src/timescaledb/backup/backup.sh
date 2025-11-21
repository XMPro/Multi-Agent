#!/bin/sh
set -e

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/backups"
RETENTION_DAYS=${BACKUP_RETENTION_DAYS:-30}

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Backup filename
BACKUP_FILE="$BACKUP_DIR/timescaledb_${TIMESTAMP}.sql.gz"

echo "$(date): Starting backup to $BACKUP_FILE"

# Perform backup using pg_dump
pg_dump -Fc "$PGDATABASE" | gzip > "$BACKUP_FILE"

if [ $? -eq 0 ]; then
    echo "$(date): Backup completed successfully: $BACKUP_FILE"
    
    # Clean up old backups
    echo "$(date): Cleaning up backups older than $RETENTION_DAYS days"
    find "$BACKUP_DIR" -name "*.sql.gz" -type f -mtime +$RETENTION_DAYS -delete
    
    # List current backups
    BACKUP_COUNT=$(ls -1 "$BACKUP_DIR"/*.sql.gz 2>/dev/null | wc -l)
    BACKUP_SIZE=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
    echo "$(date): Current backups: $BACKUP_COUNT files, Total size: $BACKUP_SIZE"
else
    echo "$(date): Backup failed!"
    exit 1
fi
