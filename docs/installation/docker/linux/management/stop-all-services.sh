#!/bin/bash
# =================================================================
# Stop All Docker Stack Services (Linux)
# =================================================================

set -eo pipefail

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

# Ensure we're in the installation root directory (not management subdirectory)
if [ -d "neo4j" ] && [ -d "milvus" ] && [ -d "mqtt" ]; then
    print_color "$GRAY" "Running from installation directory"
elif [ -d "../neo4j" ] && [ -d "../milvus" ] && [ -d "../mqtt" ]; then
    cd ..
    print_color "$GRAY" "Changed to installation directory"
else
    print_color "$RED" "Error: Cannot find service directories!"
    print_color "$YELLOW" "Run this script from the installation directory or management/ subdirectory"
    exit 1
fi

# Verify expected folders exist
EXPECTED_FOLDERS=("neo4j" "milvus" "mqtt" "timescaledb" "ollama")
MISSING_FOLDERS=()

for folder in "${EXPECTED_FOLDERS[@]}"; do
    if [ ! -d "$folder" ]; then
        MISSING_FOLDERS+=("$folder")
    fi
done

if [ ${#MISSING_FOLDERS[@]} -eq 4 ]; then
    print_color "$RED" "No service folders found in: $(pwd)"
    print_color "$YELLOW" "Expected folders: neo4j, milvus, mqtt, timescaledb, ollama"
    exit 1
fi

if [ ${#MISSING_FOLDERS[@]} -gt 0 ]; then
    print_color "$YELLOW" "Warning: Missing service folders: ${MISSING_FOLDERS[*]}"
fi

# Confirm action
echo ""
if [ "$REMOVE_VOLUMES" = true ]; then
    print_color "$RED" "WARNING: This will stop all services AND remove their data volumes!"
    print_color "$RED" "All data will be permanently deleted."
else
    print_color "$CYAN" "This will stop all running services (data will be preserved)."
fi

echo ""
read -p "Continue? (y/n): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    print_color "$YELLOW" "Operation cancelled"
    exit 0
fi

# Services to stop
SERVICES=("neo4j" "milvus" "mqtt" "timescaledb" "ollama")
STOPPED_SERVICES=()
FAILED_SERVICES=()

# Stop services
echo ""
print_color "$CYAN" "Stopping Services..."
print_color "$GRAY" "===================="

# Stop each service
for SERVICE in "${SERVICES[@]}"; do
    if [ -d "$SERVICE" ]; then
        echo ""
        print_color "$CYAN" "Stopping $SERVICE..."
        
        cd "$SERVICE"
        
        # Check if docker-compose.yml exists
        if [ ! -f "docker-compose.yml" ]; then
            print_color "$YELLOW" "No docker-compose.yml found, skipping"
            cd ..
            continue
        fi
        
        # Stop the service
        if [ "$REMOVE_VOLUMES" = true ]; then
            docker-compose down -v 2>&1
        else
            docker-compose down 2>&1
        fi
        
        if [ $? -eq 0 ]; then
            print_color "$GREEN" "$SERVICE stopped successfully"
            STOPPED_SERVICES+=("$SERVICE")
        else
            print_color "$RED" "Failed to stop $SERVICE (exit code: $?)"
            FAILED_SERVICES+=("$SERVICE")
        fi
        
        cd ..
    else
        print_color "$YELLOW" "$SERVICE directory not found, skipping"
    fi
done

# Summary
echo ""
print_color "$CYAN" "=================================================================="
print_color "$CYAN" "Summary"
print_color "$CYAN" "=================================================================="

if [ ${#STOPPED_SERVICES[@]} -gt 0 ]; then
    print_color "$GREEN" "Successfully stopped: ${STOPPED_SERVICES[*]}"
fi

if [ ${#FAILED_SERVICES[@]} -gt 0 ]; then
    print_color "$RED" "Failed to stop: ${FAILED_SERVICES[*]}"
fi

if [ "$REMOVE_VOLUMES" = true ]; then
    echo ""
    print_color "$YELLOW" "Data volumes have been removed"
fi

echo ""
print_color "$GREEN" "All operations completed"
print_color "$CYAN" "=================================================================="
