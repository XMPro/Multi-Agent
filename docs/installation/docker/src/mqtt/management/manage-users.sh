#!/bin/bash
# =================================================================
# MQTT User Management Script (Linux)
# =================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; GRAY='\033[0;37m'; NC='\033[0m'

print_color() { echo -e "${1}${@:2}${NC}"; }

COMMAND="${1:-list}"
USERNAME="${2:-}"

[ "$(basename "$(pwd)")" = "management" ] && cd ..

print_color "$CYAN" "=================================================================="
print_color "$CYAN" "MQTT User Management"
print_color "$CYAN" "=================================================================="

case "$COMMAND" in
    list)
        echo "MQTT Users:"
        if [ -f "config/passwords.txt" ]; then
            cut -d: -f1 config/passwords.txt
        else
            print_color "$YELLOW" "No users found"
        fi
        ;;
    add)
        [ -z "$USERNAME" ] && read -p "Enter username: " USERNAME
        read -s -p "Enter password: " PASSWORD
        echo
        
        echo "$USERNAME:$PASSWORD" >> config/passwords.txt
        docker run --rm -v "$(pwd)/config:/config" -w /config eclipse-mosquitto:2.0.22 mosquitto_passwd -U passwords.txt 2>/dev/null
        
        print_color "$GREEN" "User '$USERNAME' added"
        print_color "$YELLOW" "Restart broker: docker-compose restart"
        ;;
    remove)
        [ -z "$USERNAME" ] && read -p "Enter username to remove: " USERNAME
        sed -i "/^$USERNAME:/d" config/passwords.txt
        print_color "$GREEN" "User '$USERNAME' removed"
        print_color "$YELLOW" "Restart broker: docker-compose restart"
        ;;
    change-password)
        [ -z "$USERNAME" ] && read -p "Enter username: " USERNAME
        read -s -p "Enter new password: " PASSWORD
        echo
        
        # Remove old entry
        sed -i "/^$USERNAME:/d" config/passwords.txt
        # Add new entry
        echo "$USERNAME:$PASSWORD" >> config/passwords.txt
        docker run --rm -v "$(pwd)/config:/config" -w /config eclipse-mosquitto:2.0.22 mosquitto_passwd -U passwords.txt 2>/dev/null
        
        print_color "$GREEN" "Password changed for '$USERNAME'"
        print_color "$YELLOW" "Restart broker: docker-compose restart"
        ;;
    *)
        echo "Usage: $0 {list|add|remove|change-password} [username]"
        echo ""
        echo "Examples:"
        echo "  $0 list"
        echo "  $0 add newuser"
        echo "  $0 remove olduser"
        echo "  $0 change-password existinguser"
        exit 1
        ;;
esac
