#!/bin/bash
# =================================================================
# Milvus Vector Database Installation Script (Linux)
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
USERNAME="milvus"
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
    echo "  -u, --username USER    Milvus username (default: milvus)"
    echo "  -p, --password PASS    Milvus password (will prompt if not provided)"
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

# Ensure we're in the milvus directory
CURRENT_DIR=$(basename "$(pwd)")
if [ "$CURRENT_DIR" = "management" ]; then
    cd ..
    print_color "$GRAY" "Changed from management directory to milvus directory"
elif [ -d "management" ]; then
    print_color "$GRAY" "Already in milvus directory"
else
    print_color "$YELLOW" "Warning: Current directory may not be correct for Milvus installation"
fi

print_color "$CYAN" "=================================================================="
print_color "$CYAN" "Milvus Vector Database Installation Script"
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
echo "Checking existing Milvus containers..."
if docker-compose ps 2>/dev/null | grep -q "Up"; then
    print_color "$YELLOW" "Milvus containers are already running"
    read -p "Stop existing containers to reconfigure? (y/n): " stop_choice
    if [[ "$stop_choice" =~ ^[Yy]$ ]]; then
        echo "Stopping existing containers..."
        docker-compose down
        print_color "$GREEN" "Containers stopped"
    else
        print_color "$YELLOW" "Installation cancelled"
        exit 0
    fi
else
    print_color "$GREEN" "No existing Milvus containers found"
fi

# Create directories
echo "Creating directory structure..."
DIRECTORIES=("milvus-data" "milvus-data/backups" "milvus-data/etcd" "milvus-data/milvus" "milvus-data/minio" "tls")
for dir in "${DIRECTORIES[@]}"; do
    mkdir -p "$dir"
    print_color "$GREEN" "Created directory: $dir"
done

# Ask about SSL
if [ "$ENABLE_SSL" = false ]; then
    echo "SSL Configuration:"
    read -p "Enable SSL/TLS encryption for Milvus? (y/n): " ssl_choice
    [[ "$ssl_choice" =~ ^[Yy]$ ]] && ENABLE_SSL=true
fi

[ "$ENABLE_SSL" = true ] && print_color "$GREEN" "SSL will be enabled"

# Generate or prompt for password
if [ -z "$PASSWORD" ]; then
    echo "Password Setup:"
    read -p "Generate secure password automatically? (y/n): " pass_choice
    
    if [[ "$pass_choice" =~ ^[Yy]$ ]] || [ -z "$pass_choice" ]; then
        echo "Generating secure password..."
        PASSWORD=$(openssl rand -base64 15 | tr -dc 'A-Za-z0-9' | head -c 18)
        print_color "$GREEN" "Generated password: $PASSWORD"
    else
        read -s -p "Enter password: " PASSWORD
        echo
        [ -z "$PASSWORD" ] && { print_color "$RED" "Password cannot be empty!"; exit 1; }
    fi
else
    print_color "$GRAY" "Using provided password for user '$USERNAME'"
fi

# Generate MinIO credentials
echo "Generating MinIO credentials..."
MINIO_ACCESS_KEY=$(openssl rand -base64 12 | tr -dc 'A-Za-z0-9' | head -c 16)
MINIO_SECRET_KEY=$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 32)
print_color "$GREEN" "MinIO Access Key: $MINIO_ACCESS_KEY"
print_color "$GREEN" "MinIO Secret Key: $MINIO_SECRET_KEY"

# Create .env file
echo "Creating configuration files..."
cat > .env << EOF
# Milvus Authentication
MILVUS_AUTH_ENABLED=true
MILVUS_ROOT_PASSWORD=$PASSWORD

# SSL Configuration
ENABLE_SSL=$ENABLE_SSL
SSL_DOMAIN=$DOMAIN

# Milvus Ports
MILVUS_PORT=19530
MILVUS_HTTP_PORT=8080

# MinIO Configuration
MINIO_ROOT_USER=$MINIO_ACCESS_KEY
MINIO_ROOT_PASSWORD=$MINIO_SECRET_KEY

# Timezone
TZ=UTC
EOF

print_color "$GREEN" "Created .env file"

# Set permissions
chmod -R 777 milvus-data 2>/dev/null || true
print_color "$GREEN" "Directory permissions configured"

# SSL setup
if [ "$ENABLE_SSL" = true ]; then
    echo "Setting up SSL certificates..."
    
    if [ ! -f "tls/server.key" ] || [ "$FORCE" = true ]; then
        echo "Generating SSL certificates..."
        
        # Generate CA
        docker run --rm -v "$(pwd)/tls:/tls" -w /tls alpine/openssl genrsa -out ca.key 2048
        docker run --rm -v "$(pwd)/tls:/tls" -w /tls alpine/openssl req -x509 -new -key ca.key -sha256 -days 3650 -out ca.pem -subj "/C=US/ST=State/L=City/O=Milvus/CN=$DOMAIN"
        
        # Generate server cert
        docker run --rm -v "$(pwd)/tls:/tls" -w /tls alpine/openssl genrsa -out server.key 2048
        docker run --rm -v "$(pwd)/tls:/tls" -w /tls alpine/openssl req -new -key server.key -subj "/C=US/ST=State/L=City/O=Milvus/CN=$DOMAIN" -out server.csr
        docker run --rm -v "$(pwd)/tls:/tls" -w /tls alpine/openssl x509 -req -days 3650 -in server.csr -CA ca.pem -CAkey ca.key -CAcreateserial -out server.pem
        
        # Generate client cert
        docker run --rm -v "$(pwd)/tls:/tls" -w /tls alpine/openssl genrsa -out client.key 2048
        docker run --rm -v "$(pwd)/tls:/tls" -w /tls alpine/openssl req -new -key client.key -subj "/C=US/ST=State/L=City/O=Milvus/CN=$DOMAIN" -out client.csr
        docker run --rm -v "$(pwd)/tls:/tls" -w /tls alpine/openssl x509 -req -days 3650 -in client.csr -CA ca.pem -CAkey ca.key -CAcreateserial -out client.pem
        
        # Cleanup
        rm -f tls/*.csr tls/*.srl
        
        [ -f "tls/server.key" ] && print_color "$GREEN" "SSL certificates generated"
    fi
fi

# Create Milvus config
cat > user.yaml << EOF
etcd:
  endpoints: [etcd:2379]
minio:
  address: minio
  port: 9000
  accessKeyID: $MINIO_ACCESS_KEY
  secretAccessKey: $MINIO_SECRET_KEY
  useSSL: false
common:
  defaultPartitionName: _default
proxy:
  grpc:
    serverAddress: 0.0.0.0
  port: 19530
  http:
    enabled: true
    port: 8080
log:
  level: info
grpc:
  serverMaxRecvSize: 268435456
EOF

[ "$ENABLE_SSL" = true ] && cat >> user.yaml << EOF
tls:
  serverPemPath: /milvus/tls/server.pem
  serverKeyPath: /milvus/tls/server.key
  caPemPath: /milvus/tls/ca.pem
EOF

print_color "$GREEN" "Created user.yaml"

# Update docker-compose.yml for SSL if enabled
if [ "$ENABLE_SSL" = true ]; then
    echo "Updating Docker Compose configuration for SSL..."
    
    # Ensure TLS volumes are mounted (should already be in docker-compose.yml)
    if ! grep -q "./tls:/milvus/tls" docker-compose.yml; then
        print_color "$YELLOW" "Adding TLS volume mount to docker-compose.yml"
        sed -i '/user.yaml/a\      - ./tls:/milvus/tls:ro' docker-compose.yml
    fi
    
    print_color "$GREEN" "Docker Compose configuration updated for SSL"
fi

# Create nginx config
if [ "$ENABLE_SSL" = true ]; then
    cat > nginx.conf << 'EOF'
events { worker_connections 1024; }
http {
    upstream attu { server attu:3000; }
    server {
        listen 80;
        return 301 https://$host$request_uri;
    }
    server {
        listen 443 ssl;
        ssl_certificate /etc/nginx/ssl/server.pem;
        ssl_certificate_key /etc/nginx/ssl/server.key;
        location / {
            proxy_pass http://attu;
            proxy_set_header Host $host;
        }
    }
}
EOF
else
    cat > nginx.conf << 'EOF'
events { worker_connections 1024; }
http {
    upstream attu { server attu:3000; }
    server {
        listen 80;
        location / {
            proxy_pass http://attu;
            proxy_set_header Host $host;
        }
    }
}
EOF
fi

print_color "$GREEN" "Created nginx.conf"

# Test config
docker-compose config > /dev/null 2>&1 && print_color "$GREEN" "Configuration valid"

# Summary
print_color "$CYAN" "=================================================================="
print_color "$CYAN" "Installation Summary"
print_color "$CYAN" "=================================================================="
echo "  Username: $USERNAME"
print_color "$YELLOW" "  Password: $PASSWORD"
echo "  MinIO Access: $MINIO_ACCESS_KEY"
print_color "$GREEN" "Installation completed!"

# Ask to start (only if not in force mode - stack installer will start services)
if [ "$FORCE" = false ]; then
    read -p "Start Milvus now? (y/n): " start_choice
    if [[ "$start_choice" =~ ^[Yy]$ ]]; then
        docker-compose up -d
        print_color "$GREEN" "Milvus started!"
    else
        print_color "$GRAY" "Milvus not started (will be started by stack installer)"
    fi
    [ -d "management" ] && cd management
else
    print_color "$GRAY" "Configuration complete (stack installer will start services)"
fi

# Always exit successfully if we got this far
exit 0
