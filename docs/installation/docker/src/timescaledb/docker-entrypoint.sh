#!/bin/bash
set -e

# Fix SSL certificate permissions if they exist
if [ -d "/var/lib/postgresql/certs" ] && [ -f "/var/lib/postgresql/certs/server.key" ]; then
    echo "Fixing SSL certificate permissions..."
    chown postgres:postgres /var/lib/postgresql/certs/server.key /var/lib/postgresql/certs/server.crt /var/lib/postgresql/certs/ca.crt 2>/dev/null || true
    chmod 600 /var/lib/postgresql/certs/server.key 2>/dev/null || true
    chmod 644 /var/lib/postgresql/certs/server.crt /var/lib/postgresql/certs/ca.crt 2>/dev/null || true
    echo "SSL certificate permissions fixed"
fi

# Execute the original docker entrypoint with all arguments
exec docker-entrypoint.sh "$@"
