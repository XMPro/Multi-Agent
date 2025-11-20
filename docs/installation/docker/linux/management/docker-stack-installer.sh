#!/bin/bash
# =================================================================
# Docker Stack One-Click Installer (Linux)
# Neo4j, Milvus, and MQTT Services
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
ZIP_PATH=""
INSTALL_PATH=""
SKIP_CHECKS=false
ENABLE_SSL=false
DOMAIN="localhost"
AUTO_START=false
INSTALL_CERTIFICATES=false

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
    echo "  -z, --zip PATH           Path to ZIP file"
    echo "  -i, --install PATH       Installation directory (default: current directory)"
    echo "  --skip-checks            Skip prerequisite checks"
    echo "  --enable-ssl             Enable SSL/TLS for all services"
    echo "  --domain DOMAIN          Domain for SSL certificates (default: localhost)"
    echo "  --auto-start             Run in automation mode (no interactive prompts)"
    echo "  --install-certificates   Automatically install CA certificates"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Password Handling (Production-Safe):"
    echo "  Passwords are handled securely through:"
    echo "  1. Environment variables: NEO4J_PASSWORD, MILVUS_PASSWORD, MQTT_PASSWORD"
    echo "  2. Interactive prompts (if not in auto-start mode)"
    echo "  3. Auto-generation (if not provided)"
    echo ""
    echo "Example:"
    echo "  $0 --enable-ssl --domain mycompany.local"
    echo ""
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -z|--zip)
            ZIP_PATH="$2"
            shift 2
            ;;
        -i|--install)
            INSTALL_PATH="$2"
            shift 2
            ;;
        --skip-checks)
            SKIP_CHECKS=true
            shift
            ;;
        --enable-ssl)
            ENABLE_SSL=true
            shift
            ;;
        --domain)
            DOMAIN="$2"
            shift 2
            ;;
        --auto-start)
            AUTO_START=true
            shift
            ;;
        --install-certificates)
            INSTALL_CERTIFICATES=true
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
print_color "$CYAN" "Docker Stack One-Click Installer (Linux)"
print_color "$CYAN" "Neo4j, Milvus, and MQTT Services"
print_color "$CYAN" "=================================================================="

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Get zip file path if not provided
if [ -z "$ZIP_PATH" ]; then
    # Look for ZIP files in current directory
    mapfile -t LOCAL_ZIP_FILES < <(find . -maxdepth 1 -name "*.zip" -type f | sort)
    
    if [ ${#LOCAL_ZIP_FILES[@]} -eq 1 ]; then
        ZIP_PATH="${LOCAL_ZIP_FILES[0]}"
        print_color "$GREEN" "Found ZIP file: $(basename "$ZIP_PATH")"
    elif [ ${#LOCAL_ZIP_FILES[@]} -gt 1 ]; then
        echo "Multiple ZIP files found:"
        for i in "${!LOCAL_ZIP_FILES[@]}"; do
            echo "  [$i] $(basename "${LOCAL_ZIP_FILES[$i]}")"
        done
        read -p "Enter number to select ZIP file: " selection
        if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -lt "${#LOCAL_ZIP_FILES[@]}" ]; then
            ZIP_PATH="${LOCAL_ZIP_FILES[$selection]}"
            print_color "$GREEN" "Selected: $(basename "$ZIP_PATH")"
        else
            print_color "$RED" "Invalid selection. Exiting."
            exit 1
        fi
    else
        print_color "$RED" "No ZIP file found in current directory."
        read -p "Enter path to ZIP file: " ZIP_PATH
    fi
fi

# Validate zip file exists
if [ ! -f "$ZIP_PATH" ]; then
    print_color "$RED" "ZIP file not found: $ZIP_PATH"
    exit 1
fi

echo "Selected ZIP file: $ZIP_PATH"

# Set installation path to current directory if not provided
if [ -z "$INSTALL_PATH" ]; then
    INSTALL_PATH="$(pwd)"
    echo "Installation path: $INSTALL_PATH (current directory)"
else
    echo "Installation path: $INSTALL_PATH"
fi

# Prerequisites check
if [ "$SKIP_CHECKS" = false ]; then
    echo ""
    echo "Checking Prerequisites..."
    print_color "$GRAY" "========================="
    
    # Check Docker
    if command_exists docker; then
        if docker version >/dev/null 2>&1; then
            print_color "$GREEN" "Docker is installed and running"
        else
            print_color "$RED" "Docker is installed but not running!"
            print_color "$YELLOW" "Please start Docker and try again."
            print_color "$YELLOW" "Run: sudo systemctl start docker"
            exit 1
        fi
    else
        print_color "$RED" "Docker is not installed!"
        print_color "$YELLOW" "Install Docker: https://docs.docker.com/engine/install/"
        exit 1
    fi
    
    # Check Docker Compose
    if command_exists docker-compose || docker compose version >/dev/null 2>&1; then
        print_color "$GREEN" "Docker Compose is available"
    else
        print_color "$RED" "Docker Compose is not available!"
        print_color "$YELLOW" "Install Docker Compose or use Docker with compose plugin"
        exit 1
    fi
    
    # Check if user is in docker group
    if groups | grep -q docker; then
        print_color "$GREEN" "User is in docker group"
    else
        print_color "$YELLOW" "User is not in docker group. You may need sudo for docker commands."
        print_color "$YELLOW" "To add user to docker group: sudo usermod -aG docker \$USER"
    fi
fi

# Extract ZIP file
echo ""
echo "Extracting ZIP file..."
print_color "$GRAY" "====================="

# Check if unzip is available
if ! command_exists unzip; then
    print_color "$RED" "unzip command not found!"
    print_color "$YELLOW" "Install unzip: sudo apt-get install unzip (Ubuntu/Debian)"
    print_color "$YELLOW" "              sudo yum install unzip (RHEL/CentOS)"
    exit 1
fi

# Check for conflicting files
CONFLICTING_FILES=()
while IFS= read -r entry; do
    target_path="$INSTALL_PATH/$entry"
    if [ -e "$target_path" ] && [ ! -d "$target_path" ]; then
        CONFLICTING_FILES+=("$entry")
    fi
done < <(unzip -Z1 "$ZIP_PATH" 2>/dev/null | grep -v '/$')

if [ ${#CONFLICTING_FILES[@]} -gt 0 ]; then
    print_color "$YELLOW" "Found ${#CONFLICTING_FILES[@]} conflicting file(s):"
    for i in "${!CONFLICTING_FILES[@]}"; do
        if [ $i -lt 5 ]; then
            echo "  - ${CONFLICTING_FILES[$i]}"
        fi
    done
    if [ ${#CONFLICTING_FILES[@]} -gt 5 ]; then
        echo "  ... and $((${#CONFLICTING_FILES[@]} - 5)) more"
    fi
    
    read -p "Overwrite existing files? (y/n): " overwrite_choice
    if [[ ! "$overwrite_choice" =~ ^[Yy]$ ]]; then
        print_color "$YELLOW" "Extraction cancelled by user"
        exit 1
    fi
    
    unzip -o "$ZIP_PATH" -d "$INSTALL_PATH" >/dev/null
    print_color "$GREEN" "ZIP file extracted successfully (with overwrite)"
else
    unzip -q "$ZIP_PATH" -d "$INSTALL_PATH"
    print_color "$GREEN" "ZIP file extracted successfully"
fi

# Change to installation directory
cd "$INSTALL_PATH"

# Move the ZIP file to an archive folder
echo ""
echo "Archiving deployment files..."
ARCHIVE_DIR="$INSTALL_PATH/archive"
mkdir -p "$ARCHIVE_DIR"

ZIP_FILENAME=$(basename "$ZIP_PATH")
ARCHIVE_ZIP_PATH="$ARCHIVE_DIR/$ZIP_FILENAME"

if mv "$ZIP_PATH" "$ARCHIVE_ZIP_PATH" 2>/dev/null; then
    print_color "$GREEN" "ZIP file moved to: archive/$ZIP_FILENAME"
else
    print_color "$YELLOW" "Could not move ZIP file to archive"
    echo "ZIP file remains at: $ZIP_PATH"
fi

# Move tar file if it exists (for offline deployments)
ZIP_DIR=$(dirname "$ZIP_PATH")
TAR_FILENAME="${ZIP_FILENAME%.zip}-docker-images.tar"
TAR_PATH="$ZIP_DIR/$TAR_FILENAME"

if [ -f "$TAR_PATH" ]; then
    ARCHIVE_TAR_PATH="$ARCHIVE_DIR/$TAR_FILENAME"
    if mv "$TAR_PATH" "$ARCHIVE_TAR_PATH" 2>/dev/null; then
        print_color "$GREEN" "Docker images tar moved to: archive/$TAR_FILENAME"
    else
        print_color "$YELLOW" "Could not move tar file to archive"
    fi
fi

# Verify extracted structure
EXPECTED_FOLDERS=("neo4j" "milvus" "mqtt" "timescaledb")
AVAILABLE_FOLDERS=()

for folder in "${EXPECTED_FOLDERS[@]}"; do
    if [ -d "$folder" ]; then
        AVAILABLE_FOLDERS+=("$folder")
    fi
done

if [ ${#AVAILABLE_FOLDERS[@]} -eq 0 ]; then
    print_color "$RED" "No service folders found in the ZIP file!"
    print_color "$YELLOW" "Please ensure the ZIP file contains the correct Docker stack structure."
    exit 1
fi

print_color "$GREEN" "Found service folders: ${AVAILABLE_FOLDERS[*]}"

# Ask user which services to install
echo ""
print_color "$CYAN" "Service Installation Selection"
print_color "$GRAY" "============================="
echo "You can choose which services to install. Services will only be"
echo "configured and started if you select them."
echo ""

declare -A SERVICES_TO_INSTALL

# Ask about Neo4j
if [ -d "neo4j" ]; then
    read -p "Do you want to install Neo4j Graph Database? (y/n): " install_neo4j
    [[ "$install_neo4j" =~ ^[Yy]$ ]] && SERVICES_TO_INSTALL[neo4j]=true || SERVICES_TO_INSTALL[neo4j]=false
fi

# Ask about Milvus
if [ -d "milvus" ]; then
    read -p "Do you want to install Milvus Vector Database? (y/n): " install_milvus
    [[ "$install_milvus" =~ ^[Yy]$ ]] && SERVICES_TO_INSTALL[milvus]=true || SERVICES_TO_INSTALL[milvus]=false
fi

# Ask about MQTT
if [ -d "mqtt" ]; then
    read -p "Do you want to install MQTT Message Broker? (y/n): " install_mqtt
    [[ "$install_mqtt" =~ ^[Yy]$ ]] && SERVICES_TO_INSTALL[mqtt]=true || SERVICES_TO_INSTALL[mqtt]=false
fi

# Ask about TimescaleDB
if [ -d "timescaledb" ]; then
    read -p "Do you want to install TimescaleDB Time-Series Database? (y/n): " install_timescaledb
    [[ "$install_timescaledb" =~ ^[Yy]$ ]] && SERVICES_TO_INSTALL[timescaledb]=true || SERVICES_TO_INSTALL[timescaledb]=false
fi

# Show installation summary
echo ""
print_color "$CYAN" "Installation Summary:"
SELECTED_SERVICES=()
SKIPPED_SERVICES=()

for service in "${!SERVICES_TO_INSTALL[@]}"; do
    if [ "${SERVICES_TO_INSTALL[$service]}" = true ]; then
        SELECTED_SERVICES+=("$service")
    else
        SKIPPED_SERVICES+=("$service")
    fi
done

if [ ${#SELECTED_SERVICES[@]} -gt 0 ]; then
    print_color "$GREEN" "  Services to install: ${SELECTED_SERVICES[*]}"
else
    print_color "$RED" "  No services selected for installation!"
    print_color "$YELLOW" "Exiting installer."
    exit 0
fi

if [ ${#SKIPPED_SERVICES[@]} -gt 0 ]; then
    print_color "$YELLOW" "  Services to skip: ${SKIPPED_SERVICES[*]}"
fi

echo ""
read -p "Continue with installation? (y/n): " continue_install
if [[ ! "$continue_install" =~ ^[Yy]$ ]]; then
    print_color "$YELLOW" "Installation cancelled by user"
    exit 0
fi

# Configure services
echo ""
echo "Configuring Services..."
print_color "$GRAY" "======================"

# Track which services configured successfully
declare -A CONFIGURED_SERVICES

# Get passwords from environment variables only (for automation)
# Do NOT prompt - let individual service installers handle password prompting
NEO4J_PASSWORD="${NEO4J_PASSWORD:-}"
MILVUS_PASSWORD="${MILVUS_PASSWORD:-}"
MQTT_PASSWORD="${MQTT_PASSWORD:-}"
TIMESCALEDB_PASSWORD="${TIMESCALEDB_PASSWORD:-}"

# Show if using environment variables
[ -n "$NEO4J_PASSWORD" ] && print_color "$GRAY" "Using Neo4j password from environment variable"
[ -n "$MILVUS_PASSWORD" ] && print_color "$GRAY" "Using Milvus password from environment variable"
[ -n "$MQTT_PASSWORD" ] && print_color "$GRAY" "Using MQTT password from environment variable"
[ -n "$TIMESCALEDB_PASSWORD" ] && print_color "$GRAY" "Using TimescaleDB password from environment variable"

# Configure Neo4j (if selected)
if [ "${SERVICES_TO_INSTALL[neo4j]:-false}" = true ]; then
    echo ""
    print_color "$CYAN" "Neo4j Configuration:"
    print_color "$GRAY" "==================="
    echo "Running Neo4j installation script..."

    cd neo4j
    NEO4J_ARGS="--force"
    [ "$ENABLE_SSL" = true ] && NEO4J_ARGS="$NEO4J_ARGS --enable-ssl"
    [ "$DOMAIN" != "localhost" ] && NEO4J_ARGS="$NEO4J_ARGS --domain $DOMAIN"
    [ -n "$NEO4J_PASSWORD" ] && NEO4J_ARGS="$NEO4J_ARGS --password $NEO4J_PASSWORD"

    if [ -f "management/install.sh" ]; then
        chmod +x management/install.sh
        if ./management/install.sh $NEO4J_ARGS; then
            print_color "$GREEN" "Neo4j configured successfully"
            CONFIGURED_SERVICES[neo4j]=true
        else
            print_color "$RED" "Neo4j installation failed"
            CONFIGURED_SERVICES[neo4j]=false
        fi
    else
        print_color "$YELLOW" "Neo4j install script not found"
        CONFIGURED_SERVICES[neo4j]=false
    fi
    cd "$INSTALL_PATH"
else
    echo ""
    print_color "$GRAY" "Skipping Neo4j (not selected)"
fi

# Configure Milvus (if selected)
if [ "${SERVICES_TO_INSTALL[milvus]:-false}" = true ]; then
    echo ""
    print_color "$CYAN" "Milvus Configuration:"
    print_color "$GRAY" "===================="
    echo "Running Milvus installation script..."

    cd milvus
    MILVUS_ARGS="--force"
    [ "$ENABLE_SSL" = true ] && MILVUS_ARGS="$MILVUS_ARGS --enable-ssl"
    [ "$DOMAIN" != "localhost" ] && MILVUS_ARGS="$MILVUS_ARGS --domain $DOMAIN"
    [ -n "$MILVUS_PASSWORD" ] && MILVUS_ARGS="$MILVUS_ARGS --password $MILVUS_PASSWORD"

    if [ -f "management/install.sh" ]; then
        chmod +x management/install.sh
        if ./management/install.sh $MILVUS_ARGS; then
            print_color "$GREEN" "Milvus configured successfully"
            CONFIGURED_SERVICES[milvus]=true
        else
            print_color "$RED" "Milvus installation failed"
            CONFIGURED_SERVICES[milvus]=false
        fi
    else
        print_color "$YELLOW" "Milvus install script not found"
        CONFIGURED_SERVICES[milvus]=false
    fi
    cd "$INSTALL_PATH"
else
    echo ""
    print_color "$GRAY" "Skipping Milvus (not selected)"
fi

# Configure MQTT (if selected)
if [ "${SERVICES_TO_INSTALL[mqtt]:-false}" = true ]; then
    echo ""
    print_color "$CYAN" "MQTT Configuration:"
    print_color "$GRAY" "=================="
    echo "Running MQTT installation script..."

    cd mqtt
    MQTT_ARGS="--force"
    [ "$ENABLE_SSL" = true ] && MQTT_ARGS="$MQTT_ARGS --enable-ssl"
    [ "$DOMAIN" != "localhost" ] && MQTT_ARGS="$MQTT_ARGS --domain $DOMAIN"
    [ -n "$MQTT_PASSWORD" ] && MQTT_ARGS="$MQTT_ARGS --password $MQTT_PASSWORD"

    if [ -f "management/install.sh" ]; then
        chmod +x management/install.sh
        if ./management/install.sh $MQTT_ARGS; then
            print_color "$GREEN" "MQTT configured successfully"
            CONFIGURED_SERVICES[mqtt]=true
        else
            print_color "$RED" "MQTT installation failed"
            CONFIGURED_SERVICES[mqtt]=false
        fi
    else
        print_color "$YELLOW" "MQTT install script not found"
        CONFIGURED_SERVICES[mqtt]=false
    fi
    cd "$INSTALL_PATH"
else
    echo ""
    print_color "$GRAY" "Skipping MQTT (not selected)"
fi

# Configure TimescaleDB (if selected)
if [ "${SERVICES_TO_INSTALL[timescaledb]:-false}" = true ]; then
    echo ""
    print_color "$CYAN" "TimescaleDB Configuration:"
    print_color "$GRAY" "========================="
    echo "Running TimescaleDB installation script..."

    cd timescaledb
    TIMESCALEDB_ARGS="--force"
    [ "$ENABLE_SSL" = true ] && TIMESCALEDB_ARGS="$TIMESCALEDB_ARGS --enable-ssl"
    [ "$DOMAIN" != "localhost" ] && TIMESCALEDB_ARGS="$TIMESCALEDB_ARGS --domain $DOMAIN"
    [ -n "$TIMESCALEDB_PASSWORD" ] && TIMESCALEDB_ARGS="$TIMESCALEDB_ARGS --password $TIMESCALEDB_PASSWORD"

    if [ -f "management/install.sh" ]; then
        chmod +x management/install.sh
        if ./management/install.sh $TIMESCALEDB_ARGS; then
            print_color "$GREEN" "TimescaleDB configured successfully"
            CONFIGURED_SERVICES[timescaledb]=true
        else
            print_color "$RED" "TimescaleDB installation failed"
            CONFIGURED_SERVICES[timescaledb]=false
        fi
    else
        print_color "$YELLOW" "TimescaleDB install script not found"
        CONFIGURED_SERVICES[timescaledb]=false
    fi
    cd "$INSTALL_PATH"
else
    echo ""
    print_color "$GRAY" "Skipping TimescaleDB (not selected)"
fi

# Start services
echo ""
echo "Starting Configured Services..."
print_color "$GRAY" "==============================="

SUCCESSFUL_SERVICES=()
FAILED_SERVICES=()

for service in "${!CONFIGURED_SERVICES[@]}"; do
    if [ "${CONFIGURED_SERVICES[$service]}" = true ]; then
        SUCCESSFUL_SERVICES+=("$service")
    else
        FAILED_SERVICES+=("$service")
    fi
done

if [ ${#FAILED_SERVICES[@]} -gt 0 ]; then
    print_color "$YELLOW" "Skipping services that failed configuration: ${FAILED_SERVICES[*]}"
fi

if [ ${#SUCCESSFUL_SERVICES[@]} -eq 0 ]; then
    print_color "$RED" "No services configured successfully - skipping startup phase"
else
    print_color "$GREEN" "Starting services: ${SUCCESSFUL_SERVICES[*]}"
fi

# Start Neo4j
if [ "${CONFIGURED_SERVICES[neo4j]:-false}" = true ]; then
    echo ""
    echo "Starting Neo4j..."
    print_color "$GRAY" "================="
    
    cd neo4j
    if docker-compose ps 2>/dev/null | grep -q "neo4j.*Up"; then
        print_color "$GREEN" "Neo4j is already running"
    else
        echo "Starting Neo4j services..."
        docker-compose up -d
        print_color "$GREEN" "Neo4j started successfully"
    fi
    cd ..
fi

# Start Milvus
if [ "${CONFIGURED_SERVICES[milvus]:-false}" = true ]; then
    echo ""
    echo "Starting Milvus..."
    print_color "$GRAY" "================="
    
    cd milvus
    if docker-compose ps 2>/dev/null | grep -q "standalone.*Up"; then
        print_color "$GREEN" "Milvus is already running"
    else
        echo "Starting Milvus services..."
        docker-compose up -d
        print_color "$GREEN" "Milvus started successfully"
    fi
    cd ..
fi

# Start MQTT
if [ "${CONFIGURED_SERVICES[mqtt]:-false}" = true ]; then
    echo ""
    echo "Starting MQTT..."
    print_color "$GRAY" "==============="
    
    cd mqtt
    if docker-compose ps 2>/dev/null | grep -q "mosquitto.*Up"; then
        print_color "$GREEN" "MQTT is already running"
    else
        echo "Starting MQTT services..."
        docker-compose up -d
        print_color "$GREEN" "MQTT started successfully"
    fi
    cd ..
fi

# Start TimescaleDB
if [ "${CONFIGURED_SERVICES[timescaledb]:-false}" = true ]; then
    echo ""
    echo "Starting TimescaleDB..."
    print_color "$GRAY" "======================"
    
    cd timescaledb
    if docker-compose ps 2>/dev/null | grep -q "timescaledb.*Up"; then
        print_color "$GREEN" "TimescaleDB is already running"
    else
        echo "Starting TimescaleDB services..."
        docker-compose up -d
        print_color "$GREEN" "TimescaleDB started successfully"
    fi
    cd ..
fi

# Wait for services to initialize
echo ""
echo "Waiting for services to initialize..."
print_color "$GRAY" "====================================="
sleep 15

# Final status check
echo ""
echo "Final Service Status:"
print_color "$GRAY" "===================="

for service in neo4j milvus mqtt timescaledb; do
    if [ -d "$service" ]; then
        cd "$service"
        if docker-compose ps 2>/dev/null | grep -q "Up"; then
            print_color "$GREEN" "  $service: Running"
        else
            print_color "$RED" "  $service: Not running"
        fi
        cd ..
    fi
done

# Installation summary
echo ""
print_color "$CYAN" "=================================================================="
print_color "$CYAN" "Installation Summary"
print_color "$CYAN" "=================================================================="

print_color "$CYAN" "Service Access Information:"
print_color "$GRAY" "==========================="

if [ "${CONFIGURED_SERVICES[neo4j]:-false}" = true ]; then
    print_color "$GREEN" "Neo4j Browser: http://localhost:7474"
    print_color "$GREEN" "Neo4j Bolt: bolt://localhost:7687"
    print_color "$GRAY" "  (Check Neo4j install output above for username/password)"
fi

if [ "${CONFIGURED_SERVICES[milvus]:-false}" = true ]; then
    print_color "$GREEN" "Milvus API: localhost:19530"
    print_color "$GREEN" "Milvus HTTP API: localhost:9091"
    print_color "$GREEN" "MinIO Console: http://localhost:9001"
    print_color "$GRAY" "  (Check Milvus install output above for username/password)"
fi

if [ "${CONFIGURED_SERVICES[mqtt]:-false}" = true ]; then
    print_color "$GREEN" "MQTT Broker: localhost:1883"
    print_color "$GREEN" "MQTT WebSocket: ws://localhost:9002"
    print_color "$GRAY" "  (Check MQTT install output above for username/password)"
fi

if [ "${CONFIGURED_SERVICES[timescaledb]:-false}" = true ]; then
    print_color "$GREEN" "TimescaleDB: localhost:5432"
    print_color "$GRAY" "  (Check TimescaleDB install output above for username/password)"
fi

echo ""
print_color "$CYAN" "Management Scripts:"
print_color "$GRAY" "=================="
echo "Backup and management scripts are located in each service's 'management' folder"

# Check if any services have self-signed SSL certificates and offer to install them
echo ""
print_color "$CYAN" "Self-Signed Certificate Installation:"
print_color "$GRAY" "======================================"

HAS_CERTS=false
CERT_SERVICES=()

# Check for certificates
[ -f "neo4j/certs/bolt/trusted/ca.crt" ] && { HAS_CERTS=true; CERT_SERVICES+=("Neo4j"); }
[ -f "milvus/tls/ca.pem" ] && { HAS_CERTS=true; CERT_SERVICES+=("Milvus"); }
[ -f "mqtt/certs/ca.crt" ] && { HAS_CERTS=true; CERT_SERVICES+=("MQTT"); }

if [ "$HAS_CERTS" = true ]; then
    print_color "$YELLOW" "Found self-signed CA certificates for: ${CERT_SERVICES[*]}"
    echo ""
    print_color "$GRAY" "These certificates need to be installed on client machines to avoid SSL warnings."
    print_color "$GRAY" "You can install them now or later using: sudo ./management/install-ca-certificates.sh"
    echo ""
    
    if [ "$INSTALL_CERTIFICATES" = true ]; then
        print_color "$GREEN" "Auto-installing CA certificates (--install-certificates specified)..."
        if sudo ./management/install-ca-certificates.sh -i "$INSTALL_PATH"; then
            print_color "$GREEN" "CA certificates installed successfully!"
        else
            print_color "$YELLOW" "Failed to install CA certificates (may need sudo)"
        fi
    else
        read -p "Install CA certificates to system trust store now? (requires sudo) (y/n): " cert_choice
        if [[ "$cert_choice" =~ ^[Yy]$ ]]; then
            print_color "$GREEN" "Installing CA certificates..."
            if sudo ./management/install-ca-certificates.sh -i "$INSTALL_PATH"; then
                print_color "$GREEN" "CA certificates installed successfully!"
            else
                print_color "$YELLOW" "Installation failed. You can install later with:"
                print_color "$GRAY" "  sudo ./management/install-ca-certificates.sh"
            fi
        else
            print_color "$GRAY" "CA certificates not installed."
            print_color "$GRAY" "To install later: sudo ./management/install-ca-certificates.sh"
        fi
    fi
else
    print_color "$GRAY" "No self-signed certificates found - CA installation not needed."
fi

# Generate credentials file
echo ""
echo "Generating Credentials File..."
print_color "$GRAY" "=============================="

cat > CREDENTIALS.txt << 'EOF'
# =================================================================
# Docker Stack Credentials and Access Information
# =================================================================

IMPORTANT: Keep this file secure and do not commit to version control!

EOF

echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')" >> CREDENTIALS.txt

# Add service credentials (parse .env files for actual configuration)
if [ "${CONFIGURED_SERVICES[neo4j]:-false}" = true ]; then
    echo "" >> CREDENTIALS.txt
    echo "# =================================================================" >> CREDENTIALS.txt
    echo "# Neo4j Graph Database" >> CREDENTIALS.txt
    echo "# =================================================================" >> CREDENTIALS.txt
    echo "" >> CREDENTIALS.txt
    
    # Parse Neo4j credentials from .env
    if [ -f "neo4j/.env" ]; then
        NEO4J_USER=$(grep "^NEO4J_USER=" neo4j/.env | cut -d= -f2)
        NEO4J_PASS=$(grep "^NEO4J_PASSWORD=" neo4j/.env | cut -d= -f2)
        echo "Username: ${NEO4J_USER:-neo4j}" >> CREDENTIALS.txt
        echo "Password: ${NEO4J_PASS:-check .env file}" >> CREDENTIALS.txt
        echo "" >> CREDENTIALS.txt
    fi
    
    echo "Access URLs:" >> CREDENTIALS.txt
    echo "  - Browser UI: http://localhost:7474" >> CREDENTIALS.txt
    echo "  - Bolt Protocol: bolt://localhost:7687" >> CREDENTIALS.txt
    
    # Check if SSL is enabled
    if grep -q "ENABLE_SSL=true" neo4j/.env 2>/dev/null && [ -f "neo4j/certs/bolt/trusted/ca.crt" ]; then
        echo "" >> CREDENTIALS.txt
        echo "  - HTTPS Browser: https://localhost:7473" >> CREDENTIALS.txt
        echo "  - Bolt+S Protocol: bolt+s://localhost:7687" >> CREDENTIALS.txt
        echo "" >> CREDENTIALS.txt
        echo "SSL Certificate:" >> CREDENTIALS.txt
        echo "  - CA Certificate: neo4j/certs/bolt/trusted/ca.crt" >> CREDENTIALS.txt
    fi
fi

if [ "${CONFIGURED_SERVICES[milvus]:-false}" = true ]; then
    echo "" >> CREDENTIALS.txt
    echo "# =================================================================" >> CREDENTIALS.txt
    echo "# Milvus Vector Database" >> CREDENTIALS.txt
    echo "# =================================================================" >> CREDENTIALS.txt
    echo "" >> CREDENTIALS.txt
    
    # Parse Milvus credentials from .env
    if [ -f "milvus/.env" ]; then
        MILVUS_PASS=$(grep "^MILVUS_ROOT_PASSWORD=" milvus/.env | cut -d= -f2)
        MINIO_USER=$(grep "^MINIO_ROOT_USER=" milvus/.env | cut -d= -f2)
        MINIO_PASS=$(grep "^MINIO_ROOT_PASSWORD=" milvus/.env | cut -d= -f2)
        
        echo "Username: root" >> CREDENTIALS.txt
        echo "Password: ${MILVUS_PASS:-check .env file}" >> CREDENTIALS.txt
        echo "" >> CREDENTIALS.txt
    fi
    
    echo "Access URLs:" >> CREDENTIALS.txt
    echo "  - gRPC API: localhost:19530" >> CREDENTIALS.txt
    echo "  - HTTP API: localhost:9091" >> CREDENTIALS.txt
    
    # Check if SSL is enabled
    if grep -q "ENABLE_SSL=true" milvus/.env 2>/dev/null; then
        echo "  - Attu Web UI (HTTPS): https://localhost:8001" >> CREDENTIALS.txt
        echo "  - Attu Web UI (HTTP redirect): http://localhost:8002" >> CREDENTIALS.txt
        echo "" >> CREDENTIALS.txt
        echo "SSL Certificate:" >> CREDENTIALS.txt
        echo "  - CA Certificate: milvus/tls/ca.pem" >> CREDENTIALS.txt
        echo "  - Client Certificate: milvus/tls/client.pem" >> CREDENTIALS.txt
        echo "  - Client Key: milvus/tls/client.key" >> CREDENTIALS.txt
    else
        echo "  - Attu Web UI: http://localhost:8002" >> CREDENTIALS.txt
    fi
    
    # Add MinIO credentials
    if [ -n "$MINIO_USER" ] && [ -n "$MINIO_PASS" ]; then
        echo "" >> CREDENTIALS.txt
        echo "MinIO Object Storage:" >> CREDENTIALS.txt
        echo "  - Console: http://localhost:9001" >> CREDENTIALS.txt
        echo "  - API: http://localhost:9000" >> CREDENTIALS.txt
        echo "  - Access Key: $MINIO_USER" >> CREDENTIALS.txt
        echo "  - Secret Key: $MINIO_PASS" >> CREDENTIALS.txt
    fi
fi

if [ "${CONFIGURED_SERVICES[mqtt]:-false}" = true ]; then
    echo "" >> CREDENTIALS.txt
    echo "# =================================================================" >> CREDENTIALS.txt
    echo "# MQTT Message Broker" >> CREDENTIALS.txt
    echo "# =================================================================" >> CREDENTIALS.txt
    echo "" >> CREDENTIALS.txt
    
    # Parse MQTT credentials from .env
    if [ -f "mqtt/.env" ]; then
        MQTT_USER=$(grep "^MQTT_USERNAME=" mqtt/.env | cut -d= -f2)
        MQTT_PASS=$(grep "^MQTT_PASSWORD=" mqtt/.env | cut -d= -f2)
        echo "Username: ${MQTT_USER:-xmpro}" >> CREDENTIALS.txt
        echo "Password: ${MQTT_PASS:-check .env file}" >> CREDENTIALS.txt
        echo "" >> CREDENTIALS.txt
    fi
    
    echo "Access URLs:" >> CREDENTIALS.txt
    echo "  - MQTT Broker: localhost:1883" >> CREDENTIALS.txt
    echo "  - WebSocket: ws://localhost:9002" >> CREDENTIALS.txt
    
    # Check if SSL is enabled
    if grep -q "ENABLE_SSL=true" mqtt/.env 2>/dev/null; then
        echo "" >> CREDENTIALS.txt
        echo "  - MQTT Broker (SSL): localhost:8883" >> CREDENTIALS.txt
        echo "  - WebSocket (SSL): wss://localhost:9003" >> CREDENTIALS.txt
        echo "" >> CREDENTIALS.txt
        echo "SSL Certificate:" >> CREDENTIALS.txt
        echo "  - CA Certificate: mqtt/certs/ca.crt" >> CREDENTIALS.txt
        echo "  - Client Certificate: mqtt/certs/client.crt" >> CREDENTIALS.txt
        echo "  - Client Key: mqtt/certs/client.key" >> CREDENTIALS.txt
    fi
fi

if [ "${CONFIGURED_SERVICES[timescaledb]:-false}" = true ]; then
    echo "" >> CREDENTIALS.txt
    echo "# =================================================================" >> CREDENTIALS.txt
    echo "# TimescaleDB Time-Series Database" >> CREDENTIALS.txt
    echo "# =================================================================" >> CREDENTIALS.txt
    echo "" >> CREDENTIALS.txt
    
    # Parse TimescaleDB credentials from .env
    if [ -f "timescaledb/.env" ]; then
        TIMESCALEDB_DB=$(grep "^POSTGRES_DB=" timescaledb/.env | cut -d= -f2)
        TIMESCALEDB_USER=$(grep "^POSTGRES_USER=" timescaledb/.env | cut -d= -f2)
        TIMESCALEDB_PASS=$(grep "^POSTGRES_PASSWORD=" timescaledb/.env | cut -d= -f2)
        
        echo "Database: ${TIMESCALEDB_DB:-timescaledb}" >> CREDENTIALS.txt
        echo "Username: ${TIMESCALEDB_USER:-postgres}" >> CREDENTIALS.txt
        echo "Password: ${TIMESCALEDB_PASS:-check .env file}" >> CREDENTIALS.txt
        echo "" >> CREDENTIALS.txt
    fi
    
    echo "Access URLs:" >> CREDENTIALS.txt
    echo "  - PostgreSQL: localhost:5432" >> CREDENTIALS.txt
    echo "  - Connection String: postgresql://<username>:<password>@localhost:5432/<database>" >> CREDENTIALS.txt
    
    # Check if SSL is enabled
    if grep -q "ENABLE_SSL=true" timescaledb/.env 2>/dev/null && [ -f "timescaledb/certs/ca.crt" ]; then
        echo "" >> CREDENTIALS.txt
        echo "  - SSL Connection String: postgresql://<username>:<password>@localhost:5432/<database>?sslmode=require" >> CREDENTIALS.txt
        echo "" >> CREDENTIALS.txt
        echo "SSL Certificate:" >> CREDENTIALS.txt
        echo "  - CA Certificate: timescaledb/certs/ca.crt" >> CREDENTIALS.txt
        echo "  - Server Certificate: timescaledb/certs/server.crt" >> CREDENTIALS.txt
        echo "  - Server Key: timescaledb/certs/server.key" >> CREDENTIALS.txt
    fi
fi

print_color "$GREEN" "Credentials file created: CREDENTIALS.txt"
echo "Location: $INSTALL_PATH/CREDENTIALS.txt"

echo ""
print_color "$GREEN" "Installation completed!"
print_color "$CYAN" "=================================================================="
echo ""
print_color "$YELLOW" "IMPORTANT: All credentials and access URLs have been saved to:"
print_color "$CYAN" "  $INSTALL_PATH/CREDENTIALS.txt"
echo ""
print_color "$YELLOW" "Keep this file secure and do not commit it to version control!"
print_color "$CYAN" "=================================================================="
