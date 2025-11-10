#!/bin/bash
# =================================================================
# MQTT Mosquitto Installation Script (Linux)
# =================================================================

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m'

# Default parameters
USERNAME="xmpro"
PASSWORD=""
ENABLE_SSL=false
FORCE=false

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
    echo "  -u, --username USER    MQTT username (default: xmpro)"
    echo "  -p, --password PASS    MQTT password (will prompt if not provided)"
    echo "  --enable-ssl           Enable SSL/TLS encryption"
    echo "  --force                Force reconfiguration"
    echo "  -h, --help             Show this help message"
    echo ""
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--username)
            USERNAME="$2"
            shift 2
            ;;
        -p|--password)
            PASSWORD="$2"
            shift 2
            ;;
        --enable-ssl)
            ENABLE_SSL=true
            shift
            ;;
        --force)
            FORCE=true
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

# Ensure we're in the mqtt directory
CURRENT_DIR=$(basename "$(pwd)")
if [ "$CURRENT_DIR" = "management" ]; then
    cd ..
    print_color "$GRAY" "Changed from management directory to mqtt directory"
elif [ -d "management" ]; then
    print_color "$GRAY" "Already in mqtt directory"
else
    print_color "$YELLOW" "Warning: Current directory may not be correct for MQTT installation"
fi

print_color "$CYAN" "=================================================================="
print_color "$CYAN" "MQTT Mosquitto Installation Script"
print_color "$CYAN" "=================================================================="

# Check Docker
echo "Checking Docker availability..."
if ! command -v docker &> /dev/null || ! docker version &> /dev/null; then
    print_color "$RED" "Docker is not available!"
    exit 1
fi
print_color "$GREEN" "Docker is available"

# Check Docker Compose
if command -v docker-compose &> /dev/null || docker compose version &> /dev/null; then
    print_color "$GREEN" "Docker Compose is available"
else
    print_color "$RED" "Docker Compose is not available!"
    exit 1
fi

# Check existing containers
echo "Checking existing MQTT containers..."
if docker-compose ps 2>/dev/null | grep -q "mosquitto.*Up"; then
    print_color "$YELLOW" "MQTT container is already running"
    read -p "Stop existing container to reconfigure? (y/n): " stop_choice
    if [[ "$stop_choice" =~ ^[Yy]$ ]]; then
        docker-compose down
        print_color "$GREEN" "Container stopped"
    else
        print_color "$YELLOW" "Installation cancelled"
        exit 0
    fi
else
    print_color "$GREEN" "No existing MQTT containers found"
fi

# Create directories
echo "Creating directory structure..."
DIRECTORIES=("data" "data/backups" "logs" "config" "certs")
for dir in "${DIRECTORIES[@]}"; do
    mkdir -p "$dir"
    print_color "$GREEN" "Created directory: $dir"
done

# Ask about SSL
if [ "$ENABLE_SSL" = false ]; then
    echo "SSL Configuration:"
    read -p "Enable SSL/TLS encryption? (y/n): " ssl_choice
    [[ "$ssl_choice" =~ ^[Yy]$ ]] && ENABLE_SSL=true
fi

[ "$ENABLE_SSL" = true ] && print_color "$GREEN" "SSL will be enabled"

# Generate or prompt for password
if [ -z "$PASSWORD" ]; then
    echo "Password Setup:"
    read -p "Generate secure password automatically? (y/n): " pass_choice
    
    if [[ "$pass_choice" =~ ^[Yy]$ ]] || [ -z "$pass_choice" ]; then
        echo "Generating secure password..."
        PASSWORD=$(openssl rand -base64 12 | tr -dc 'A-Za-z0-9' | head -c 16)
        print_color "$GREEN" "Generated password for '$USERNAME': $PASSWORD"
    else
        read -s -p "Enter password for '$USERNAME': " PASSWORD
        echo
        [ -z "$PASSWORD" ] && { print_color "$RED" "Password cannot be empty!"; exit 1; }
    fi
else
    print_color "$GRAY" "Using provided password for user '$USERNAME'"
fi

# Create .env file
echo "Creating configuration files..."
cat > .env << EOF
# MQTT Configuration
MQTT_PORT=1883
MQTT_SSL_PORT=8883
MQTT_WS_PORT=9002

# MQTT Authentication
MQTT_USERNAME=$USERNAME
MQTT_PASSWORD=$PASSWORD

# SSL Configuration
ENABLE_SSL=$ENABLE_SSL

# Timezone
TZ=UTC
EOF

print_color "$GREEN" "Created .env file"

# Create mosquitto.conf
cat > config/mosquitto.conf << EOF
# General Configuration
pid_file /mosquitto/config/mosquitto.pid
persistence true
persistence_location /mosquitto/data/
log_dest file /mosquitto/log/mosquitto.log

# Listener Configuration
listener 1883
protocol mqtt

# Authentication
allow_anonymous false
password_file /mosquitto/config/passwords.txt

# Logging
log_type error
log_type warning
log_type notice
log_type information

# Persistence
autosave_interval 1800
autosave_on_changes true
EOF

print_color "$GREEN" "Created mosquitto.conf"

# Create ACL
cat > config/acl.txt << EOF
user $USERNAME
topic readwrite #

pattern read \$SYS/#
EOF

print_color "$GREEN" "Created acl.txt"

# Create password file
echo "Setting up authentication..."
echo "$USERNAME:$PASSWORD" > config/passwords.txt
docker run --rm -v "$(pwd)/config:/config" -w /config eclipse-mosquitto:2.0.22 mosquitto_passwd -U passwords.txt 2>/dev/null || {
    print_color "$YELLOW" "Password will be hashed on first startup"
}
print_color "$GREEN" "Password file created"
print_color "$YELLOW" "Password: $PASSWORD"

# Set permissions
chmod -R 777 data logs 2>/dev/null || true
print_color "$GREEN" "Directory permissions configured"

# SSL setup
if [ "$ENABLE_SSL" = true ]; then
    echo "Setting up SSL certificates..."
    
    if [ ! -f "certs/server.crt" ] || [ "$FORCE" = true ]; then
        echo "Generating SSL certificates..."
        
        # Generate CA
        docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine/openssl genrsa -out ca.key 2048
        docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine/openssl req -new -x509 -days 365 -key ca.key -out ca.crt -subj "/C=US/ST=State/L=City/O=MQTT/CN=MQTT-CA"
        
        # Generate server cert
        docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine/openssl genrsa -out server.key 2048
        docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine/openssl req -new -key server.key -out server.csr -subj "/C=US/ST=State/L=City/O=MQTT/CN=localhost"
        docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine/openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 365
        
        # Cleanup
        rm -f certs/*.csr certs/*.srl
        
        [ -f "certs/server.crt" ] && print_color "$GREEN" "SSL certificates generated"
        
        # Update mosquitto.conf for SSL
        cat >> config/mosquitto.conf << EOF

# SSL Configuration
listener 8883
protocol mqtt
cafile /mosquitto/certs/ca.crt
certfile /mosquitto/certs/server.crt
keyfile /mosquitto/certs/server.key
tls_version tlsv1.2
require_certificate false
EOF
        
        # Update .env
        sed -i 's/ENABLE_SSL=false/ENABLE_SSL=true/' .env
        print_color "$GREEN" "SSL configuration enabled"
    fi
fi

# Update docker-compose.yml for SSL if enabled
if [ "$ENABLE_SSL" = true ]; then
    echo "Updating Docker Compose configuration for SSL..."
    
    # Ensure certificate volumes are mounted (should already be in docker-compose.yml)
    if ! grep -q "./certs:/mosquitto/certs" docker-compose.yml; then
        print_color "$YELLOW" "Adding certs volume mount to docker-compose.yml"
        sed -i '/mosquitto.conf/a\      - ./certs:/mosquitto/certs' docker-compose.yml
    fi
    
    print_color "$GREEN" "Docker Compose configuration updated for SSL"
fi

# Test config
docker-compose config > /dev/null 2>&1 && print_color "$GREEN" "Configuration valid"

# Summary
print_color "$CYAN" "=================================================================="
print_color "$CYAN" "Installation Summary"
print_color "$CYAN" "=================================================================="
echo "  Username: $USERNAME"
print_color "$YELLOW" "  Password: $PASSWORD"
echo "  MQTT Port: 1883"
[ "$ENABLE_SSL" = true ] && echo "  MQTT SSL Port: 8883"
print_color "$GREEN" "Installation completed!"

# Ask to start (only if not in force mode - stack installer will start services)
if [ "$FORCE" = false ]; then
    read -p "Start MQTT broker now? (y/n): " start_choice
    if [[ "$start_choice" =~ ^[Yy]$ ]]; then
        docker-compose up -d
        print_color "$GREEN" "MQTT broker started!"
    else
        print_color "$GRAY" "MQTT not started (will be started by stack installer)"
    fi
    [ -d "management" ] && cd management
else
    print_color "$GRAY" "Configuration complete (stack installer will start services)"
fi

# Always exit successfully if we got this far
exit 0
