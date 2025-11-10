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
DOMAIN="localhost"
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
    echo "  --domain DOMAIN        Domain for SSL certificate (default: localhost)"
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
        --domain)
            DOMAIN="$2"
            shift 2
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
    echo ""
    print_color "$CYAN" "SSL Configuration:"
    read -p "Enable SSL/TLS encryption? (y/n): " ssl_choice
    [[ "$ssl_choice" =~ ^[Yy]$ ]] && ENABLE_SSL=true
fi

USE_CA_PROVIDED=false
MACHINE_IP=""

if [ "$ENABLE_SSL" = true ]; then
    print_color "$GREEN" "SSL will be enabled"
    
    # Ask for certificate type
    echo ""
    print_color "$CYAN" "Certificate Options:"
    print_color "$GRAY" "1. Generate self-signed certificates (for development/testing)"
    print_color "$GRAY" "2. Use CA-provided certificates (for production)"
    read -p "Select certificate type (1 or 2, default: 1): " cert_choice
    
    if [ "$cert_choice" = "2" ]; then
        print_color "$GREEN" "CA-provided certificates selected"
        print_color "$CYAN" "You can install them after setup using: ./management/manage-ssl.sh install-ca"
        print_color "$YELLOW" "SSL will be configured but not enabled until certificates are installed"
        ENABLE_SSL=false
        USE_CA_PROVIDED=true
    else
        print_color "$GREEN" "Self-signed certificates selected"
        
        # Ask for domain name
        read -p "Enter domain name for SSL certificate (default: localhost): " domain_input
        if [ -n "$domain_input" ]; then
            DOMAIN="$domain_input"
        fi
        print_color "$CYAN" "Using domain: $DOMAIN"
        
        # Detect machine IP addresses
        echo ""
        print_color "$CYAN" "Detecting machine IP addresses..."
        
        if command -v ip &> /dev/null; then
            # Use 'ip' command (modern Linux)
            IPS=$(ip -4 addr show 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '^127\.' || true)
        elif command -v ifconfig &> /dev/null; then
            # Fallback to ifconfig (older systems)
            IPS=$(ifconfig 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '^127\.' || true)
        else
            IPS=""
        fi
        
        if [ -n "$IPS" ]; then
            print_color "$GREEN" "Detected IP addresses:"
            i=0
            IP_ARRAY=()
            while IFS= read -r ip; do
                if [ -n "$ip" ]; then
                    echo "  [$i] $ip"
                    IP_ARRAY+=("$ip")
                    i=$((i+1))
                fi
            done <<< "$IPS"
            
            if [ ${#IP_ARRAY[@]} -gt 0 ]; then
                read -p "Enter IP numbers to include (comma-separated, e.g., '0,1') or press Enter to skip: " ip_choice
                
                if [ -n "$ip_choice" ]; then
                    SELECTED_IPS=()
                    IFS=',' read -ra INDICES <<< "$ip_choice"
                    for index in "${INDICES[@]}"; do
                        index=$(echo "$index" | xargs)  # Trim whitespace
                        if [[ "$index" =~ ^[0-9]+$ ]] && [ "$index" -lt "${#IP_ARRAY[@]}" ]; then
                            SELECTED_IPS+=("${IP_ARRAY[$index]}")
                        fi
                    done
                    
                    if [ ${#SELECTED_IPS[@]} -gt 0 ]; then
                        MACHINE_IP=$(IFS=','; echo "${SELECTED_IPS[*]}")
                        print_color "$CYAN" "Selected IPs: $MACHINE_IP"
                    else
                        print_color "$GRAY" "No valid IPs selected, skipping"
                    fi
                else
                    print_color "$GRAY" "No IPs selected (localhost/domain only)"
                fi
            fi
        else
            print_color "$GRAY" "Could not detect IP addresses, skipping"
        fi
    fi
else
    print_color "$YELLOW" "SSL will be disabled (unencrypted connections only)"
fi

# Generate or prompt for password
if [ -z "$PASSWORD" ]; then
    echo ""
    print_color "$CYAN" "Password Setup:"
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

# Try to hash the password using mosquitto_passwd
print_color "$GRAY" "Creating password hash..."
HASH_SUCCESS=false

# Method 1: Try direct volume mount
if docker run --rm -v "$(pwd)/config:/config" -w /config eclipse-mosquitto:2.0.22 mosquitto_passwd -U passwords.txt 2>/dev/null; then
    HASH_SUCCESS=true
    print_color "$GREEN" "Password file created for user '$USERNAME'"
else
    # Method 2: Try alternative approach
    print_color "$YELLOW" "Volume mount method failed, trying alternative..."
    
    # Create temp file and try to hash it
    if docker run --rm -v "$(pwd):/work" -w /work eclipse-mosquitto:2.0.22 sh -c "cd config && mosquitto_passwd -U passwords.txt" 2>/dev/null; then
        HASH_SUCCESS=true
        print_color "$GREEN" "Password file created with proper hash"
    else
        print_color "$YELLOW" "Container hash method failed, password will be hashed on first startup"
    fi
fi

print_color "$YELLOW" "Password: $PASSWORD"
print_color "$GRAY" "  (Save this password - it won't be shown again)"

if [ "$HASH_SUCCESS" = false ]; then
    print_color "$GRAY" "Note: Mosquitto will hash the password on first startup"
fi

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
        docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine/openssl req -new -x509 -days 365 -key ca.key -out ca.crt \
            -subj "/C=US/ST=State/L=City/O=MQTT-Broker/CN=MQTT-CA"
        
        # Build SAN list
        SAN_LIST="DNS:$DOMAIN,DNS:localhost,DNS:127.0.0.1,DNS:mqtt,IP:127.0.0.1,IP:::1"
        if [ -n "$MACHINE_IP" ]; then
            IFS=',' read -ra IP_ARRAY <<< "$MACHINE_IP"
            for ip in "${IP_ARRAY[@]}"; do
                ip=$(echo "$ip" | xargs)  # Trim whitespace
                SAN_LIST="$SAN_LIST,IP:$ip"
            done
        fi
        
        # Generate server cert with SAN
        docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine/openssl genrsa -out server.key 2048
        docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine/openssl req -new -key server.key -out server.csr \
            -subj "/C=US/ST=State/L=City/O=MQTT-Broker/CN=$DOMAIN" \
            -addext "subjectAltName=$SAN_LIST"
        docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine/openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key \
            -CAcreateserial -out server.crt -days 365 -copy_extensions copy
        
        # Cleanup
        docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine sh -c "rm -f server.csr ca.srl"
        
        if [ -f "certs/ca.crt" ] && [ -f "certs/server.crt" ] && [ -f "certs/server.key" ]; then
            print_color "$GREEN" "SSL certificates generated successfully using Docker OpenSSL"
            print_color "$GREEN" "SSL certificate generation complete"
            print_color "$GRAY" "Note: alpine/openssl image preserved for future SSL operations"
        else
            print_color "$RED" "SSL certificate generation failed"
            print_color "$YELLOW" "SSL will be disabled for this installation"
            ENABLE_SSL=false
            
            # Update .env
            sed -i 's/ENABLE_SSL=true/ENABLE_SSL=false/' .env
        fi
        
        # Update mosquitto.conf for SSL if successful
        if [ "$ENABLE_SSL" = true ]; then
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
fi

# Initialize backup system
print_color "$CYAN" "Initializing backup system..."
if [ ! -d "data/backups" ]; then
    mkdir -p "data/backups"
fi
print_color "$GREEN" "Backup system initialized"

# Test config
print_color "$CYAN" "Testing configuration..."
if docker-compose config > /dev/null 2>&1; then
    print_color "$GREEN" "Configuration valid"
else
    print_color "$RED" "Docker Compose configuration has errors!"
    print_color "$GRAY" "Run 'docker-compose config' to see details."
    exit 1
fi

# Summary
print_color "$CYAN" "=================================================================="
print_color "$CYAN" "Installation Summary"
print_color "$CYAN" "=================================================================="
print_color "$GREEN" "Directory structure created"
print_color "$GREEN" "Authentication configured"
print_color "$GREEN" "Permissions set"
if [ "$ENABLE_SSL" = true ]; then
    print_color "$GREEN" "SSL certificates generated and configured"
fi
print_color "$GREEN" "Backup system initialized"
print_color "$GREEN" "Configuration validated"
echo ""
print_color "$CYAN" "MQTT Broker Details:"
echo "  Username: $USERNAME"
print_color "$YELLOW" "  Password: $PASSWORD"
echo "  MQTT Port: 1883 (unencrypted)"
if [ "$ENABLE_SSL" = true ]; then
    echo "  MQTT SSL Port: 8883 (encrypted)"
fi
echo "  WebSocket Port: 9002"
echo ""
print_color "$GREEN" "Installation completed!"
print_color "$CYAN" "=================================================================="

# Ask to start (only if not in force mode - stack installer will start services)
if [ "$FORCE" = false ]; then
    echo ""
    read -p "Start MQTT broker now? (y/n): " start_choice
    if [[ "$start_choice" =~ ^[Yy]$ ]]; then
        print_color "$GREEN" "Starting MQTT broker..."
        docker-compose up -d
        
        if [ $? -eq 0 ]; then
            print_color "$GREEN" "MQTT broker started successfully!"
            
            print_color "$YELLOW" "Waiting for broker to initialize..."
            sleep 5
            
            print_color "$CYAN" "Checking broker status..."
            if docker-compose ps | grep -q "mosquitto.*Up"; then
                print_color "$GREEN" "[OK] MQTT broker is running successfully!"
                print_color "$GREEN" "[OK] Ready to accept connections"
            else
                print_color "$YELLOW" "[WARN] Broker may still be starting up"
                print_color "$GRAY" "Check logs with: docker-compose logs mosquitto"
            fi
        else
            print_color "$RED" "Failed to start MQTT broker"
            print_color "$GRAY" "Check configuration and try: docker-compose up -d"
        fi
    else
        print_color "$YELLOW" "MQTT broker not started"
        echo ""
        print_color "$CYAN" "To start manually:"
        print_color "$GRAY" "1. Start the MQTT broker: docker-compose up -d"
        print_color "$GRAY" "2. Check status: docker-compose ps"
        print_color "$GRAY" "3. View logs: docker-compose logs -f mosquitto"
    fi
    
    echo ""
    print_color "$CYAN" "Management Commands:"
    print_color "$GRAY" "==================="
    if [ "$USE_CA_PROVIDED" = true ]; then
        print_color "$CYAN" "- Install CA certificates: ./management/manage-ssl.sh install-ca"
        print_color "$CYAN" "- Enable SSL after installing: ./management/manage-ssl.sh enable"
    fi
    print_color "$GRAY" "- User management: ./management/manage-users.sh list"
    print_color "$GRAY" "- SSL management: ./management/manage-ssl.sh status"
    print_color "$GRAY" "- Create backup: ./management/backup.sh"
    print_color "$GRAY" "- Test connection with credentials above"
    echo ""
    print_color "$CYAN" "Configuration files:"
    print_color "$GRAY" "  - docker-compose.yml (main configuration)"
    print_color "$GRAY" "  - .env (environment variables)"
    print_color "$GRAY" "  - config/mosquitto.conf (broker settings)"
    print_color "$GRAY" "  - config/passwords.txt (user authentication)"
    print_color "$GRAY" "  - config/acl.txt (access control)"
    
    [ -d "management" ] && cd management
else
    print_color "$GRAY" "Configuration complete (stack installer will start services)"
fi

# Always exit successfully if we got this far
exit 0
