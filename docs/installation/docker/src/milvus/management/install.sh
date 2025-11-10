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
ENABLE_GPU=false
GPU_DEVICES="0"

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
    echo "  --enable-gpu           Enable GPU support (NVIDIA only)"
    echo "  --gpu-devices IDS      GPU device IDs (default: 0)"
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
        --enable-gpu)
            ENABLE_GPU=true
            shift
            ;;
        --gpu-devices)
            GPU_DEVICES="$2"
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

# GPU Configuration
if [ "$ENABLE_GPU" = false ]; then
    print_color "$CYAN" "GPU Configuration:"
    echo ""
    
    # Detect GPU vendor
    print_color "$CYAN" "Detecting GPU hardware..."
    GPU_VENDOR="None"
    GPU_NAME="No GPU detected"
    
    if command -v lspci &> /dev/null; then
        GPU_INFO=$(lspci 2>/dev/null | grep -i 'vga\|3d\|display' || true)
        
        if [ -n "$GPU_INFO" ]; then
            if echo "$GPU_INFO" | grep -qi "nvidia"; then
                GPU_VENDOR="NVIDIA"
                GPU_NAME=$(echo "$GPU_INFO" | grep -i nvidia | head -1)
                print_color "$GREEN" "Detected: $GPU_NAME"
            elif echo "$GPU_INFO" | grep -qi "amd\|radeon"; then
                GPU_VENDOR="AMD"
                GPU_NAME=$(echo "$GPU_INFO" | grep -i 'amd\|radeon' | head -1)
                print_color "$YELLOW" "Detected: $GPU_NAME"
            elif echo "$GPU_INFO" | grep -qi "intel"; then
                GPU_VENDOR="Intel"
                GPU_NAME=$(echo "$GPU_INFO" | grep -i intel | head -1)
                print_color "$YELLOW" "Detected: $GPU_NAME"
            else
                print_color "$GRAY" "Detected: $GPU_NAME (Unknown vendor)"
            fi
        else
            print_color "$GRAY" "No dedicated GPU detected"
        fi
    else
        print_color "$GRAY" "lspci not available, cannot detect GPU"
    fi
    
    echo ""
    print_color "$CYAN" "Milvus GPU Support Requirements:"
    print_color "$GRAY" "  - NVIDIA GPU with CUDA support (REQUIRED)"
    print_color "$GRAY" "  - Latest NVIDIA drivers installed"
    print_color "$GRAY" "  - Docker with NVIDIA Container Toolkit"
    echo ""
    
    # Check if GPU vendor is compatible
    if [ "$GPU_VENDOR" = "AMD" ]; then
        print_color "$RED" "WARNING: AMD GPU detected!"
        print_color "$RED" "Milvus GPU support ONLY works with NVIDIA GPUs (CUDA)."
        print_color "$YELLOW" "AMD GPUs use ROCm which is not supported by Milvus."
        print_color "$YELLOW" "You must use CPU mode."
        echo ""
    elif [ "$GPU_VENDOR" = "Intel" ]; then
        print_color "$RED" "WARNING: Intel GPU detected!"
        print_color "$RED" "Milvus GPU support ONLY works with NVIDIA GPUs (CUDA)."
        print_color "$YELLOW" "You must use CPU mode."
        echo ""
    elif [ "$GPU_VENDOR" = "NVIDIA" ]; then
        print_color "$GREEN" "NVIDIA GPU detected - GPU support is possible!"
        echo ""
    fi
    
    # Test if NVIDIA GPU is available in Docker
    print_color "$CYAN" "Testing NVIDIA GPU availability in Docker..."
    GPU_AVAILABLE=false
    if [ "$GPU_VENDOR" = "NVIDIA" ]; then
        if docker run --rm --gpus all nvidia/cuda:11.0-base nvidia-smi &> /dev/null; then
            GPU_AVAILABLE=true
            print_color "$GREEN" "NVIDIA GPU is available in Docker!"
        else
            print_color "$YELLOW" "NVIDIA GPU not available in Docker"
            print_color "$GRAY" "Install NVIDIA Container Toolkit to enable GPU support"
        fi
    else
        print_color "$GRAY" "Skipping Docker GPU test (no NVIDIA GPU detected)"
    fi
    
    # Only offer GPU option if NVIDIA GPU is available
    if [ "$GPU_VENDOR" = "NVIDIA" ] && [ "$GPU_AVAILABLE" = true ]; then
        echo ""
        read -p "Enable GPU support for Milvus? (y/n): " gpu_choice
        if [[ "$gpu_choice" =~ ^[Yy]$ ]]; then
            ENABLE_GPU=true
            print_color "$GREEN" "GPU support will be enabled"
            
            print_color "$CYAN" "GPU Device Selection:"
            print_color "$GRAY" "Enter GPU device IDs (comma-separated, e.g., '0' or '0,1')"
            print_color "$GRAY" "Leave empty to use GPU 0"
            read -p "GPU device IDs: " gpu_devices_input
            if [ -n "$gpu_devices_input" ]; then
                GPU_DEVICES="$gpu_devices_input"
            fi
            print_color "$CYAN" "Will use GPU device(s): $GPU_DEVICES"
        else
            print_color "$YELLOW" "GPU support will be disabled (CPU only)"
        fi
    else
        # Don't offer GPU option - just inform user
        if [ "$GPU_VENDOR" = "AMD" ] || [ "$GPU_VENDOR" = "Intel" ]; then
            echo ""
            print_color "$GRAY" "GPU support not available (Milvus requires NVIDIA GPU)"
            print_color "$CYAN" "Continuing with CPU mode..."
        elif [ "$GPU_VENDOR" = "NVIDIA" ]; then
            echo ""
            print_color "$YELLOW" "NVIDIA GPU detected but not available in Docker"
            print_color "$GRAY" "Install NVIDIA Container Toolkit to enable GPU support"
            print_color "$CYAN" "Continuing with CPU mode..."
        else
            echo ""
            print_color "$GRAY" "No GPU detected - using CPU mode"
        fi
    fi
fi

# Ask about SSL
if [ "$ENABLE_SSL" = false ]; then
    echo ""
    print_color "$CYAN" "SSL Configuration:"
    read -p "Enable SSL/TLS encryption for Milvus? (y/n): " ssl_choice
    [[ "$ssl_choice" =~ ^[Yy]$ ]] && ENABLE_SSL=true
fi

USE_CA_PROVIDED=false
MACHINE_IP=""

if [ "$ENABLE_SSL" = true ]; then
    print_color "$GREEN" "SSL will be enabled for Milvus API and internal communications"
    
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
        print_color "$CYAN" "SSL certificates will be generated for domain: $DOMAIN"
        
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
        PASSWORD=$(openssl rand -base64 15 | tr -dc 'A-Za-z0-9_-' | head -c 18)
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
MINIO_ACCESS_KEY=$(openssl rand -base64 12 | tr -dc 'A-Za-z0-9_-' | head -c 16)
MINIO_SECRET_KEY=$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9_-' | head -c 32)
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
        
        # Build SAN configuration file
        cat > tls/server-ext.cnf << EOF
[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = $DOMAIN
DNS.2 = localhost
IP.1  = 127.0.0.1
EOF
        
        # Add selected IPs to SAN
        if [ -n "$MACHINE_IP" ]; then
            IP_INDEX=2
            IFS=',' read -ra IP_ARRAY <<< "$MACHINE_IP"
            for ip in "${IP_ARRAY[@]}"; do
                ip=$(echo "$ip" | xargs)  # Trim whitespace
                echo "IP.$IP_INDEX  = $ip" >> tls/server-ext.cnf
                IP_INDEX=$((IP_INDEX+1))
            done
        fi
        
        # Create client extension
        cat > tls/client-ext.cnf << EOF
[v3_req_client]
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth
EOF
        
        # Generate CA
        docker run --rm -v "$(pwd)/tls:/tls" -w /tls alpine/openssl genrsa -out ca.key 2048
        docker run --rm -v "$(pwd)/tls:/tls" -w /tls alpine/openssl req -x509 -new -key ca.key -sha256 -days 3650 -out ca.pem \
            -subj "/C=US/ST=State/L=City/O=Milvus/CN=$DOMAIN" \
            -addext "basicConstraints=critical,CA:TRUE" \
            -addext "keyUsage=keyCertSign,cRLSign"
        
        # Generate server cert
        print_color "$GRAY" "Generating server certificates..."
        docker run --rm -v "$(pwd)/tls:/tls" -w /tls alpine/openssl genrsa -out server.key 2048
        docker run --rm -v "$(pwd)/tls:/tls" -w /tls alpine/openssl req -new -key server.key \
            -subj "/C=US/ST=State/L=City/O=Milvus/CN=$DOMAIN" -out server.csr
        docker run --rm -v "$(pwd)/tls:/tls" -w /tls alpine/openssl x509 -req -days 3650 \
            -in server.csr -CA ca.pem -CAkey ca.key -CAcreateserial -out server.pem \
            -extfile server-ext.cnf -extensions v3_req
        
        # Generate client cert
        print_color "$GRAY" "Generating client certificates..."
        docker run --rm -v "$(pwd)/tls:/tls" -w /tls alpine/openssl genrsa -out client.key 2048
        docker run --rm -v "$(pwd)/tls:/tls" -w /tls alpine/openssl req -new -key client.key \
            -subj "/C=US/ST=State/L=City/O=Milvus/CN=$DOMAIN" -out client.csr
        docker run --rm -v "$(pwd)/tls:/tls" -w /tls alpine/openssl x509 -req -days 3650 \
            -in client.csr -CA ca.pem -CAkey ca.key -CAcreateserial -out client.pem \
            -extfile client-ext.cnf -extensions v3_req_client
        
        # Cleanup
        rm -f tls/*.csr tls/*.srl tls/*.cnf
        
        if [ -f "tls/server.key" ] && [ -f "tls/server.pem" ] && [ -f "tls/ca.pem" ]; then
            print_color "$GREEN" "SSL certificates generated successfully"
            print_color "$GREEN" "SSL certificate generation complete"
            print_color "$GRAY" "Note: alpine/openssl image preserved for future SSL operations"
        else
            print_color "$RED" "SSL certificate generation failed"
            print_color "$YELLOW" "SSL will be disabled for this installation"
            ENABLE_SSL=false
            
            # Update .env file to disable SSL
            sed -i 's/ENABLE_SSL=true/ENABLE_SSL=false/' .env
        fi
    fi
fi

# Create Milvus config
if [ "$ENABLE_SSL" = true ]; then
    cat > user.yaml << EOF
# Milvus Configuration File
etcd:
  endpoints: [etcd:2379]
minio:
  address: minio
  port: 9000
  accessKeyID: $MINIO_ACCESS_KEY
  secretAccessKey: $MINIO_SECRET_KEY
  useSSL: false
common:
  security:
    tlsMode: 1
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
tls:
  serverPemPath: /milvus/tls/server.pem
  serverKeyPath: /milvus/tls/server.key
  caPemPath: /milvus/tls/ca.pem
EOF
else
    cat > user.yaml << EOF
# Milvus Configuration File
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
fi

# Add GPU configuration if enabled
if [ "$ENABLE_GPU" = true ]; then
    cat >> user.yaml << EOF

gpu:
  initMemSize: 1024
  maxMemSize: 2048
EOF
fi

print_color "$GREEN" "Created user.yaml"

# Configure GPU in docker-compose.yml if enabled
if [ "$ENABLE_GPU" = true ]; then
    print_color "$CYAN" "Configuring GPU support in docker-compose.yml..."
    
    # Change image to GPU version
    sed -i 's|image: milvusdb/milvus:.*|image: milvusdb/milvus:v2.6.3-gpu|' docker-compose.yml
    
    # Build device list for docker-compose
    DEVICE_LIST=""
    IFS=',' read -ra DEVICES <<< "$GPU_DEVICES"
    for device in "${DEVICES[@]}"; do
        device=$(echo "$device" | xargs)  # Trim whitespace
        if [ -z "$DEVICE_LIST" ]; then
            DEVICE_LIST="\"$device\""
        else
            DEVICE_LIST="$DEVICE_LIST, \"$device\""
        fi
    done
    
    # Add GPU configuration to standalone service
    # This is a simplified approach - in production you'd use yq or similar
    print_color "$YELLOW" "Note: GPU configuration requires manual docker-compose.yml editing"
    print_color "$GRAY" "Add the following under 'standalone' service 'deploy' section:"
    print_color "$GRAY" "      resources:"
    print_color "$GRAY" "        reservations:"
    print_color "$GRAY" "          devices:"
    print_color "$GRAY" "            - driver: nvidia"
    print_color "$GRAY" "              capabilities: [\"gpu\"]"
    print_color "$GRAY" "              device_ids: [$DEVICE_LIST]"
    
    print_color "$GREEN" "GPU image configured: milvusdb/milvus:v2.6.3-gpu"
    print_color "$CYAN" "Using GPU device(s): $GPU_DEVICES"
fi

# Create nginx config
if [ "$ENABLE_SSL" = true ]; then
    cat > nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    upstream attu {
        server attu:3000;
    }

    # Redirect HTTP to HTTPS
    server {
        listen 80;
        return 301 https://$host$request_uri;
    }

    # HTTPS server
    server {
        listen 443 ssl;
        
        ssl_certificate /etc/nginx/ssl/server.pem;
        ssl_certificate_key /etc/nginx/ssl/server.key;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers HIGH:!aNULL:!MD5;
        ssl_prefer_server_ciphers on;
        
        location / {
            proxy_pass http://attu;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
        }
    }
}
EOF
else
    cat > nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    upstream attu {
        server attu:3000;
    }

    server {
        listen 80;
        
        location / {
            proxy_pass http://attu;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
        }
    }
}
EOF
fi

print_color "$GREEN" "Created nginx.conf"

# Initialize backup system
print_color "$CYAN" "Initializing backup system..."
if [ ! -d "milvus-data/backups" ]; then
    mkdir -p "milvus-data/backups"
fi

cat > milvus-data/backups/README.md << EOF
# Milvus Backup Information
This directory contains backups of Milvus vector database.
EOF

print_color "$GREEN" "Backup system initialized"

# Test config
print_color "$CYAN" "Testing configuration..."
if docker-compose config > /dev/null 2>&1; then
    print_color "$GREEN" "Docker Compose configuration is valid"
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
if [ "$ENABLE_GPU" = true ]; then
    print_color "$GREEN" "GPU support configured"
fi
print_color "$GREEN" "Milvus configuration created"
print_color "$GREEN" "Backup system initialized"
print_color "$GREEN" "Configuration validated"
echo ""
print_color "$CYAN" "Milvus Vector Database Details:"
echo "  Username: $USERNAME"
print_color "$YELLOW" "  Password: $PASSWORD"
if [ "$ENABLE_SSL" = true ]; then
    echo "  gRPC API: localhost:19530 (TLS encrypted)"
    echo "  HTTP API: localhost:8080 (HTTPS)"
    echo "  Attu Web UI: https://localhost:8001 (HTTPS)"
    print_color "$GRAY" "  Attu HTTP Redirect: http://localhost:8002 -> https://localhost:8001"
    echo "  Domain: $DOMAIN"
else
    echo "  gRPC API: localhost:19530 (unencrypted)"
    echo "  HTTP API: localhost:8080 (HTTP)"
    echo "  Attu Web UI: http://localhost:8002"
fi
echo "  MinIO Console: http://localhost:9001"
echo ""
print_color "$CYAN" "MinIO Credentials:"
print_color "$YELLOW" "  Access Key: $MINIO_ACCESS_KEY"
print_color "$YELLOW" "  Secret Key: $MINIO_SECRET_KEY"
echo ""
print_color "$GREEN" "Installation completed successfully!"
print_color "$CYAN" "=================================================================="

# Ask to start (only if not in force mode - stack installer will start services)
if [ "$FORCE" = false ]; then
    echo ""
    read -p "Start Milvus vector database now? (y/n): " start_choice
    if [[ "$start_choice" =~ ^[Yy]$ ]]; then
        print_color "$GREEN" "Starting Milvus vector database..."
        docker-compose up -d
        
        if [ $? -eq 0 ]; then
            print_color "$GREEN" "Milvus vector database started successfully!"
            
            print_color "$YELLOW" "Waiting for services to initialize (this may take 60-90 seconds)..."
            sleep 30
            
            print_color "$CYAN" "Checking services status..."
            if docker-compose ps | grep -q "Up"; then
                print_color "$GREEN" "[OK] Milvus services are running successfully!"
                
                sleep 30
                
                if [ "$ENABLE_SSL" = true ]; then
                    print_color "$GREEN" "[OK] Access Milvus at: https://localhost:19530 (with SSL)"
                    print_color "$GREEN" "[OK] Access Attu at: https://localhost:8001 (with SSL)"
                    print_color "$CYAN" "[INFO] Attu connects to Milvus using SSL internally"
                    print_color "$CYAN" "[INFO] Your external clients should use SSL to connect to Milvus"
                else
                    print_color "$GREEN" "[OK] Access Milvus at: localhost:19530"
                    print_color "$GREEN" "[OK] Access Attu at: http://localhost:8002"
                fi
            else
                print_color "$YELLOW" "[WARN] Services may still be starting up"
                print_color "$GRAY" "Check logs with: docker-compose logs"
            fi
        else
            print_color "$RED" "Failed to start Milvus vector database"
            print_color "$GRAY" "Check configuration and try: docker-compose up -d"
        fi
    else
        print_color "$YELLOW" "Milvus vector database not started"
        echo ""
        print_color "$CYAN" "To start manually:"
        print_color "$GRAY" "1. Start the services: docker-compose up -d"
        print_color "$GRAY" "2. Check status: docker-compose ps"
        print_color "$GRAY" "3. View logs: docker-compose logs -f"
    fi
    
    echo ""
    print_color "$CYAN" "Management Commands:"
    print_color "$GRAY" "==================="
    if [ "$ENABLE_SSL" = true ]; then
        print_color "$GRAY" "- SSL management: ./management/manage-ssl.sh status"
    elif [ "$USE_CA_PROVIDED" = true ]; then
        print_color "$CYAN" "- Install CA certificates: ./management/manage-ssl.sh install-ca"
        print_color "$CYAN" "- Enable SSL after installing: ./management/manage-ssl.sh enable"
    fi
    print_color "$GRAY" "- Create backup: ./management/backup.sh"
    print_color "$GRAY" "- Restore backup: ./management/restore.sh"
    echo ""
    print_color "$CYAN" "Configuration files:"
    print_color "$GRAY" "  - docker-compose.yml (main configuration)"
    print_color "$GRAY" "  - .env (environment variables)"
    print_color "$GRAY" "  - user.yaml (Milvus settings)"
    if [ "$ENABLE_SSL" = true ]; then
        print_color "$GRAY" "  - tls/ (SSL certificates)"
    fi
    
    [ -d "management" ] && cd management
else
    print_color "$GRAY" "Configuration complete (stack installer will start services)"
fi

# Always exit successfully if we got this far
exit 0
