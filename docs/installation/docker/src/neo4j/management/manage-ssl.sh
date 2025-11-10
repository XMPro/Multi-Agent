#!/bin/bash
# =================================================================
# Neo4j SSL Management Script (Linux)
# =================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; GRAY='\033[0;37m'; NC='\033[0m'

print_color() { echo -e "${1}${@:2}${NC}"; }

COMMAND="${1:-status}"

[ "$(basename "$(pwd)")" = "management" ] && cd ..

print_color "$CYAN" "=================================================================="
print_color "$CYAN" "Neo4j SSL Management"
print_color "$CYAN" "=================================================================="

case "$COMMAND" in
    status)
        echo "Checking SSL certificates..."
        if [ -f "certs/bolt/private.key" ] && [ -f "certs/https/private.key" ]; then
            print_color "$GREEN" "SSL certificates found"
            ls -lh certs/bolt/*.crt certs/https/*.crt 2>/dev/null
        else
            print_color "$YELLOW" "No SSL certificates found"
        fi
        
        if grep -q "ENABLE_SSL=true" .env 2>/dev/null; then
            print_color "$GREEN" "SSL is enabled in configuration"
        else
            print_color "$GRAY" "SSL is disabled in configuration"
        fi
        ;;
    enable)
        print_color "$GREEN" "Enabling SSL..."
        sed -i 's/ENABLE_SSL=false/ENABLE_SSL=true/' .env
        print_color "$GREEN" "SSL enabled in .env"
        print_color "$YELLOW" "Restart Neo4j: docker-compose restart"
        ;;
    disable)
        print_color "$YELLOW" "Disabling SSL..."
        sed -i 's/ENABLE_SSL=true/ENABLE_SSL=false/' .env
        print_color "$GREEN" "SSL disabled in .env"
        print_color "$YELLOW" "Restart Neo4j: docker-compose restart"
        ;;
    *)
        echo "Usage: $0 {status|enable|disable}"
        exit 1
        ;;
esac
