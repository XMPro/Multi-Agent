#!/bin/bash
set -euo pipefail
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; GRAY='\033[0;37m'; NC='\033[0m'
print_color() { echo -e "${1}${@:2}${NC}"; }

COMMAND="${1:-status}"
[ "$(basename "$(pwd)")" = "management" ] && cd ..

print_color "$CYAN" "=================================================================="
print_color "$CYAN" "Milvus SSL Management"
print_color "$CYAN" "=================================================================="

case "$COMMAND" in
    status)
        echo "Checking SSL certificates..."
        [ -f "tls/server.pem" ] && print_color "$GREEN" "SSL certificates found" || print_color "$YELLOW" "No certificates"
        grep -q "ENABLE_SSL=true" .env 2>/dev/null && print_color "$GREEN" "SSL enabled" || print_color "$GRAY" "SSL disabled"
        ;;
    enable)
        sed -i 's/ENABLE_SSL=false/ENABLE_SSL=true/' .env
        print_color "$GREEN" "SSL enabled. Restart: docker-compose restart"
        ;;
    disable)
        sed -i 's/ENABLE_SSL=true/ENABLE_SSL=false/' .env
        print_color "$GREEN" "SSL disabled. Restart: docker-compose restart"
        ;;
    *) echo "Usage: $0 {status|enable|disable}"; exit 1 ;;
esac
