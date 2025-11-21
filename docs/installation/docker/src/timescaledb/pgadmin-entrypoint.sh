#!/bin/sh
set -e

# Fix certificate permissions if they exist
if [ -f /certs/server.cert ] && [ -f /certs/server.key ]; then
    chmod 644 /certs/server.cert
    chmod 644 /certs/server.key
fi

# Execute the original entrypoint
exec /entrypoint.sh
