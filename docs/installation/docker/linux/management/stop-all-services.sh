#!/bin/bash
# =================================================================
# Stop All Docker Stack Services (Linux)
# =================================================================

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

# Default parameters
REMOVE_VOLUMES=false

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
    echo "  --remove-volumes    Remove data volumes (WARNING: This deletes all data!)"
    echo "  -h, --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                      # Stop all services"
    echo "  $0 --remove-volumes     # Stop all services and remove data"
    echo ""
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --remove-volumes)
            REMOVE_VOLUMES=true
            shift
            ;;
        -h|--help)
            show_usage
            ;;
        *)
            print_color "$RED" "Unknown option: $1"
            show_usage
            ;;
    esac
done

print_color "$CYAN" "=================================================================="
print_color "$CYAN" "Stop All Docker Stack Services"
print_color "$CYAN" "=================================================================="

# Services to stop
SERVICES=("neo4j" "milvus" "mqtt")

# Stop each service
for SERVICE in "${SERVICES[@]}"; do
    if [ -d "$SERVICE" ]; then
        echo ""
        print_color "$CYAN" "Stopping $SERVICE..."
        print_color "$GRAY" "===================="
        
        cd "$SERVICE"
        
        # Check if docker-compose.yml exists
        if [ ! -f "docker-compose.yml" ]; then
            print_color "$YELLOW" "  No docker-compose.yml found, skipping"
            cd ..
            continue
        fi
        
        # Stop the service
        if docker-compose ps 2>/dev/null | grep -q "Up"; then
            if [ "$REMOVE_VOLUMES" = true ]; then
                print_color "$YELLOW" "  Stopping and removing containers and volumes..."
                docker-compose down -v
            else
                print_color "$YELLOW" "  Stopping containers..."
                docker-compose down
            fi
            print_color "$GREEN" "  $SERVICE stopped successfully"
        else
            print_color "$GRAY" "  $SERVICE is not running"
        fi
        
        cd ..
    else
        print_color "$YELLOW" "$SERVICE directory not found, skipping"
    fi
done

echo ""
print_color "$CYAN" "=================================================================="

if [ "$REMOVE_VOLUMES" = true ]; then
    print_color "$GREEN" "All services stopped and data volumes removed!"
    print_color "$YELLOW" "WARNING: All data has been deleted!"
else
    print_color "$GREEN" "All services stopped successfully!"
    print_color "$GRAY" "Data volumes preserved. Use --remove-volumes to delete data."
fi

print_color "$CYAN" "=================================================================="
