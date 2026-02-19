#!/bin/bash
# =================================================================
# Ollama Installation Script for Linux
# Description: Interactive installation wizard for Ollama Docker deployment
# Version: 1.0.0
# =================================================================

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

# Default parameters
PORT="11434"
HTTPS_PORT="11443"
ENABLE_SSL=false
DOMAIN="localhost"
GPU_DRIVER="none"
AUTO_START=false
FORCE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --port)
            PORT="$2"
            shift 2
            ;;
        --https-port)
            HTTPS_PORT="$2"
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
        --gpu-driver)
            GPU_DRIVER="$2"
            shift 2
            ;;
        --auto-start)
            AUTO_START=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Ensure we're in the ollama directory (not management subdirectory)
if [[ $(basename "$PWD") == "management" ]]; then
    cd ..
fi

echo -e "${CYAN}==================================================================${NC}"
echo -e "${CYAN}Ollama Docker Installation Script${NC}"
echo -e "${CYAN}==================================================================${NC}"
echo ""

# Check if Docker is running
echo -e "${GRAY}Checking Docker availability...${NC}"
if ! docker version &> /dev/null; then
    echo -e "${RED}✗ Docker is not running or not installed!${NC}"
    echo -e "${YELLOW}Please install Docker and ensure it's running.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker is available${NC}"

# Check if docker-compose is available
if ! docker-compose version &> /dev/null; then
    echo -e "${RED}✗ Docker Compose is not available!${NC}"
    echo -e "${YELLOW}Please ensure Docker Compose is installed.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker Compose is available${NC}"

echo ""

# Check if Ollama container is already running
echo -e "${GRAY}Checking existing Ollama containers...${NC}"
if docker-compose ps 2>/dev/null | grep -q "ollama.*running"; then
    echo -e "${YELLOW}Ollama container is already running${NC}"
    if [ "$FORCE" = false ]; then
        read -p "Stop existing container to reconfigure? (y/n): " stop_choice
        if [[ "$stop_choice" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Stopping existing Ollama container...${NC}"
            docker-compose down
            echo -e "${GREEN}✓ Container stopped${NC}"
        else
            echo -e "${YELLOW}Installation cancelled - container still running${NC}"
            exit 0
        fi
    else
        echo -e "${YELLOW}Force mode: Stopping existing container...${NC}"
        docker-compose down
    fi
else
    echo -e "${GREEN}✓ No existing Ollama containers found${NC}"
fi

echo ""

# Create directory structure
echo -e "${GRAY}Creating directory structure...${NC}"
for dir in certs nginx; do
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        echo -e "${GREEN}✓ Created directory: $dir${NC}"
    else
        echo -e "${GRAY}  Directory exists: $dir${NC}"
    fi
done

echo ""

# Check available disk space
echo -e "${GRAY}Checking disk space...${NC}"
FREE_SPACE=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')
echo -e "${GRAY}Available disk space: ${FREE_SPACE} GB${NC}"

if [ "$FREE_SPACE" -lt 20 ]; then
    echo -e "${YELLOW}Warning: Low disk space! Recommended: 20 GB minimum${NC}"
    echo -e "${YELLOW}Models can be large (1-40 GB each)${NC}"
    read -p "Continue anyway? (y/n): " continue_choice
    if [[ ! "$continue_choice" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Installation cancelled${NC}"
        exit 0
    fi
else
    echo -e "${GREEN}✓ Sufficient disk space available${NC}"
fi

echo ""

# GPU Detection
echo -e "${GRAY}Detecting GPU configuration...${NC}"
DETECTED_GPU="none"

if [ "$GPU_DRIVER" = "none" ]; then
    # Try to detect NVIDIA GPU
    if command -v nvidia-smi &> /dev/null; then
        if nvidia-smi &> /dev/null; then
            echo -e "${GREEN}✓ NVIDIA GPU detected${NC}"
            DETECTED_GPU="nvidia"
            
            # Check for NVIDIA Docker runtime
            if docker info 2>/dev/null | grep -q nvidia; then
                echo -e "${GREEN}✓ NVIDIA Docker runtime available${NC}"
            else
                echo -e "${YELLOW}⚠ NVIDIA Docker runtime not detected${NC}"
                echo -e "${GRAY}  You may need to install nvidia-docker2${NC}"
            fi
        fi
    fi
    
    # If no NVIDIA, check for AMD
    if [ "$DETECTED_GPU" = "none" ]; then
        if lspci 2>/dev/null | grep -iE "VGA|3D" | grep -iq "AMD\|Radeon"; then
            echo -e "${GREEN}✓ AMD GPU detected${NC}"
            echo -e "${YELLOW}⚠ AMD GPU support requires ROCm drivers${NC}"
            DETECTED_GPU="amd"
        fi
    fi
    
    if [ "$DETECTED_GPU" = "none" ]; then
        echo -e "${GRAY}No GPU detected - will use CPU only${NC}"
        echo -e "${YELLOW}⚠ CPU-only mode will be slower for model inference${NC}"
    fi
    
    # Ask user to confirm GPU selection
    if [ "$DETECTED_GPU" != "none" ]; then
        echo ""
        read -p "Use detected $DETECTED_GPU GPU? (y/n, default: y): " gpu_choice
        if [[ "$gpu_choice" =~ ^[Nn]$ ]]; then
            DETECTED_GPU="none"
            echo -e "${GRAY}GPU support disabled by user${NC}"
        else
            GPU_DRIVER="$DETECTED_GPU"
        fi
    fi
else
    echo -e "${GRAY}GPU driver specified: $GPU_DRIVER${NC}"
    DETECTED_GPU="$GPU_DRIVER"
fi

echo ""

# Port configuration
read -p "HTTP API port (default: 11434): " port_choice
if [ -n "$port_choice" ]; then
    PORT="$port_choice"
fi

# Check if port is available
if netstat -tuln 2>/dev/null | grep -q ":$PORT "; then
    echo -e "${YELLOW}⚠ Warning: Port $PORT is already in use!${NC}"
    read -p "Enter a different port or press Enter to continue anyway: " port_choice
    if [ -n "$port_choice" ]; then
        PORT="$port_choice"
    fi
fi

echo -e "${GRAY}HTTP API will be accessible on port: $PORT${NC}"

echo ""

# SSL Configuration
echo -e "${CYAN}SSL/TLS Configuration:${NC}"
echo -e "${GRAY}Ollama uses Nginx reverse proxy for HTTPS support${NC}"
read -p "Enable SSL/TLS encryption? (y/n, default: n): " ssl_choice

GENERATE_SSL=false
if [[ "$ssl_choice" =~ ^[Yy]$ ]]; then
    ENABLE_SSL=true
    echo -e "${GREEN}✓ SSL/TLS will be enabled${NC}"
    
    # Ask for HTTPS port
    read -p "HTTPS API port (default: 11443): " https_port_choice
    if [ -n "$https_port_choice" ]; then
        HTTPS_PORT="$https_port_choice"
    fi
    echo -e "${GRAY}HTTPS API will be accessible on port: $HTTPS_PORT${NC}"
    
    # Ask for certificate type
    echo ""
    echo -e "${GRAY}Certificate Options:${NC}"
    echo -e "${GRAY}1. Generate self-signed certificates (for development/testing)${NC}"
    echo -e "${GRAY}2. Use CA-provided certificates (install later)${NC}"
    read -p "Select certificate type (1 or 2, default: 1): " cert_choice
    
    if [ "$cert_choice" = "2" ]; then
        echo -e "${GREEN}CA-provided certificates selected${NC}"
        echo -e "${CYAN}You can install them after setup using: ./management/manage-ssl.sh install-ca${NC}"
        GENERATE_SSL=false
    else
        echo -e "${GREEN}Self-signed certificates selected${NC}"
        GENERATE_SSL=true
        
        # Ask for domain name
        read -p "Enter domain name for SSL certificate (default: localhost): " domain_choice
        if [ -n "$domain_choice" ]; then
            DOMAIN="$domain_choice"
        fi
        echo -e "${GRAY}SSL certificates will be generated for domain: $DOMAIN${NC}"
    fi
else
    echo -e "${GRAY}SSL/TLS will be disabled (HTTP only)${NC}"
fi

echo ""

# Detect machine IP addresses
echo -e "${GRAY}Detecting network configuration...${NC}"
MACHINE_IPS=()
if command -v hostname &> /dev/null; then
    IPS=$(hostname -I 2>/dev/null | tr ' ' '\n' | grep -v '^127\.' | grep -v '^::')
    if [ -n "$IPS" ]; then
        echo -e "${GREEN}✓ Detected IP addresses:${NC}"
        while IFS= read -r ip; do
            echo -e "${GRAY}  • $ip${NC}"
            MACHINE_IPS+=("$ip")
        done <<< "$IPS"
    else
        echo -e "${GRAY}Could not detect IP addresses${NC}"
    fi
else
    echo -e "${GRAY}Could not detect IP addresses${NC}"
fi

echo ""

# Create .env file from template
echo -e "${GRAY}Creating configuration files...${NC}"

if [ ! -f ".env.template" ]; then
    echo -e "${RED}✗ Error: .env.template not found!${NC}"
    echo -e "${YELLOW}Please ensure you're running this script from the ollama directory${NC}"
    exit 1
fi

# Copy template to .env
cp .env.template .env
echo -e "${GREEN}✓ Created .env file from template${NC}"

# Update .env file with configuration
sed -i "s/OLLAMA_PORT=.*/OLLAMA_PORT=$PORT/" .env
sed -i "s/OLLAMA_HTTPS_PORT=.*/OLLAMA_HTTPS_PORT=$HTTPS_PORT/" .env
sed -i "s/OLLAMA_ENABLE_SSL=.*/OLLAMA_ENABLE_SSL=$ENABLE_SSL/" .env
sed -i "s/OLLAMA_DOMAIN=.*/OLLAMA_DOMAIN=$DOMAIN/" .env
sed -i "s/OLLAMA_GPU_DRIVER=.*/OLLAMA_GPU_DRIVER=$GPU_DRIVER/" .env

# Add COMPOSE_PROFILES if SSL is enabled
if [ "$ENABLE_SSL" = true ]; then
    echo "COMPOSE_PROFILES=ssl" >> .env
fi

echo -e "${GREEN}✓ Updated .env with configuration${NC}"

# Update docker-compose.yml if GPU is enabled
if [ "$GPU_DRIVER" != "none" ]; then
    echo -e "${GRAY}Configuring GPU support in docker-compose.yml...${NC}"
    
    # Uncomment the deploy section
    sed -i '/^[[:space:]]*#[[:space:]]*deploy:/,/^[[:space:]]*#[[:space:]]*capabilities:/ s/^[[:space:]]*#[[:space:]]*/    /' docker-compose.yml
    
    # Update driver if AMD
    if [ "$GPU_DRIVER" = "amd" ]; then
        sed -i 's/driver: nvidia/driver: amd/' docker-compose.yml
    fi
    
    echo -e "${GREEN}✓ GPU support enabled in docker-compose.yml${NC}"
fi

echo ""

# Generate SSL certificates if requested
if [ "$GENERATE_SSL" = true ]; then
    echo -e "${GRAY}Generating SSL certificates...${NC}"
    
    # Build IP list for SAN
    IP_LIST="127.0.0.1"
    for ip in "${MACHINE_IPS[@]}"; do
        IP_LIST="$IP_LIST,$ip"
    done
    
    # Generate CA private key
    echo -e "${GRAY}  Generating CA certificate...${NC}"
    docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine/openssl genrsa -out ca.key 4096 2>/dev/null
    docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine/openssl req -new -x509 -days 365 -key ca.key -out ca.crt -subj "/C=US/ST=State/L=City/O=Ollama/CN=Ollama-CA" 2>/dev/null
    
    # Generate server private key
    echo -e "${GRAY}  Generating server certificate...${NC}"
    docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine/openssl genrsa -out server.key 4096 2>/dev/null
    
    # Create OpenSSL config with SAN
    SAN_ENTRIES="DNS:localhost,DNS:$DOMAIN,IP:127.0.0.1"
    for ip in "${MACHINE_IPS[@]}"; do
        SAN_ENTRIES="$SAN_ENTRIES,IP:$ip"
    done
    
    cat > certs/openssl.cnf <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req

[req_distinguished_name]

[v3_req]
subjectAltName = $SAN_ENTRIES
EOF
    
    # Generate CSR and sign certificate
    docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine/openssl req -new -key server.key -out server.csr -subj "/C=US/ST=State/L=City/O=Ollama/CN=$DOMAIN" -config openssl.cnf 2>/dev/null
    docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine/openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 365 -extensions v3_req -extfile openssl.cnf 2>/dev/null
    
    # Cleanup temporary files
    rm -f certs/server.csr certs/ca.srl certs/openssl.cnf
    
    if [ -f "certs/server.crt" ] && [ -f "certs/server.key" ]; then
        echo -e "${GREEN}✓ SSL certificates generated successfully${NC}"
    else
        echo -e "${RED}✗ Certificate generation failed${NC}"
        ENABLE_SSL=false
    fi
fi

echo ""

# Start Docker containers
echo -e "${GRAY}Starting Ollama service...${NC}"
echo -e "${GRAY}This may take a minute...${NC}"

docker-compose up -d 2>&1 > /dev/null

# Wait for health check
echo -e "${GRAY}Waiting for Ollama to become healthy...${NC}"
MAX_WAIT=60
WAITED=0
HEALTHY=false

while [ $WAITED -lt $MAX_WAIT ]; do
    sleep 2
    WAITED=$((WAITED + 2))
    
    if curl -sf "http://localhost:$PORT/api/version" > /dev/null 2>&1; then
        HEALTHY=true
        break
    fi
    
    echo -n "."
done

echo ""

if [ "$HEALTHY" = true ]; then
    echo -e "${GREEN}✓ Ollama service is running and healthy${NC}"
else
    echo -e "${YELLOW}⚠ Ollama service started but health check timed out${NC}"
    echo -e "${GRAY}  Check logs with: docker-compose logs ollama${NC}"
fi

echo ""

# Display service status
echo -e "${CYAN}Service Status:${NC}"
docker-compose ps 2>/dev/null | tail -n +2 | while read line; do
    if echo "$line" | grep -q "running"; then
        echo -e "${GREEN}  ✓ $line${NC}"
    else
        echo -e "${RED}  ✗ $line${NC}"
    fi
done

echo ""

# Ask about model downloads
echo -e "${CYAN}Model Downloads:${NC}"
echo -e "${GRAY}Ollama requires at least one embedding model to function properly${NC}"
read -p "Download required models now? (y/n, default: y): " download_choice

if [[ ! "$download_choice" =~ ^[Nn]$ ]]; then
    echo ""
    echo -e "${GRAY}Launching model download wizard...${NC}"
    sleep 1
    ./management/pull-models.sh
fi

echo ""
echo -e "${CYAN}==================================================================${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${CYAN}==================================================================${NC}"
echo ""

# Display connection information
echo -e "${CYAN}Connection Information:${NC}"
echo -e "${GRAY}  HTTP API:  http://localhost:$PORT${NC}"
for ip in "${MACHINE_IPS[@]}"; do
    echo -e "${GRAY}             http://$ip:$PORT${NC}"
done

if [ "$ENABLE_SSL" = true ]; then
    echo -e "${GRAY}  HTTPS API: https://localhost:$HTTPS_PORT${NC}"
    for ip in "${MACHINE_IPS[@]}"; do
        echo -e "${GRAY}             https://$ip:$HTTPS_PORT${NC}"
    done
    echo ""
    echo -e "${YELLOW}  CA Certificate: certs/ca.crt (distribute to clients)${NC}"
fi

echo ""
echo -e "${GRAY}GPU Support: $GPU_DRIVER${NC}"
echo ""

# Display firewall configuration
echo -e "${CYAN}Firewall Configuration:${NC}"
echo -e "${GRAY}To allow external access, configure your firewall:${NC}"
echo ""
echo -e "${GRAY}For ufw:${NC}"
echo -e "${GRAY}  sudo ufw allow $PORT/tcp${NC}"
if [ "$ENABLE_SSL" = true ]; then
    echo -e "${GRAY}  sudo ufw allow $HTTPS_PORT/tcp${NC}"
fi
echo -e "${GRAY}  sudo ufw reload${NC}"
echo ""
echo -e "${GRAY}For firewalld:${NC}"
echo -e "${GRAY}  sudo firewall-cmd --permanent --add-port=$PORT/tcp${NC}"
if [ "$ENABLE_SSL" = true ]; then
    echo -e "${GRAY}  sudo firewall-cmd --permanent --add-port=$HTTPS_PORT/tcp${NC}"
fi
echo -e "${GRAY}  sudo firewall-cmd --reload${NC}"
echo ""

# Test commands
echo -e "${CYAN}Test Commands:${NC}"
echo -e "${GRAY}  curl http://localhost:$PORT/api/version${NC}"
if [ "$ENABLE_SSL" = true ]; then
    echo -e "${GRAY}  curl -k https://localhost:$HTTPS_PORT/api/version${NC}"
fi
echo ""

# Management commands
echo -e "${CYAN}Management Commands:${NC}"
echo -e "${GRAY}  Status:  ./management/manage-ollama.sh status${NC}"
echo -e "${GRAY}  Logs:    ./management/manage-ollama.sh logs${NC}"
echo -e "${GRAY}  Models:  ./management/pull-models.sh${NC}"
if [ "$ENABLE_SSL" = true ]; then
    echo -e "${GRAY}  SSL:     ./management/manage-ssl.sh status${NC}"
fi
echo ""

# Create CREDENTIALS.txt
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
cat > CREDENTIALS.txt <<EOF
Ollama Service Configuration
=============================
Installation Date: $TIMESTAMP

Connection Information:
-----------------------
HTTP API:  http://localhost:$PORT
EOF

for ip in "${MACHINE_IPS[@]}"; do
    echo "           http://$ip:$PORT" >> CREDENTIALS.txt
done

if [ "$ENABLE_SSL" = true ]; then
    echo "" >> CREDENTIALS.txt
    echo "HTTPS API: https://localhost:$HTTPS_PORT" >> CREDENTIALS.txt
    for ip in "${MACHINE_IPS[@]}"; do
        echo "           https://$ip:$HTTPS_PORT" >> CREDENTIALS.txt
    done
fi

cat >> CREDENTIALS.txt <<EOF


Service Configuration:
----------------------
Container:   ollama (Running)
GPU Support: $GPU_DRIVER
Network:     Accessible from other machines (configure firewall)

EOF

if [ "$ENABLE_SSL" = true ]; then
    cat >> CREDENTIALS.txt <<EOF
SSL Configuration:
------------------
Enabled:     Yes
CA Cert:     certs/ca.crt (distribute to clients)
Server Cert: certs/server.crt
Domain:      $DOMAIN

EOF
else
    cat >> CREDENTIALS.txt <<EOF
SSL Configuration:
------------------
Enabled:     No (HTTP only)

EOF
fi

cat >> CREDENTIALS.txt <<EOF
Firewall Configuration:
-----------------------
For ufw:
  sudo ufw allow $PORT/tcp
EOF

if [ "$ENABLE_SSL" = true ]; then
    echo "  sudo ufw allow $HTTPS_PORT/tcp" >> CREDENTIALS.txt
fi

cat >> CREDENTIALS.txt <<EOF
  sudo ufw reload

For firewalld:
  sudo firewall-cmd --permanent --add-port=$PORT/tcp
EOF

if [ "$ENABLE_SSL" = true ]; then
    echo "  sudo firewall-cmd --permanent --add-port=$HTTPS_PORT/tcp" >> CREDENTIALS.txt
fi

cat >> CREDENTIALS.txt <<EOF
  sudo firewall-cmd --reload

Test Connection:
----------------
curl http://localhost:$PORT/api/version
EOF

if [ "$ENABLE_SSL" = true ]; then
    echo "curl -k https://localhost:$HTTPS_PORT/api/version" >> CREDENTIALS.txt
fi

cat >> CREDENTIALS.txt <<EOF


Management Commands:
--------------------
Status:  ./management/manage-ollama.sh status
Logs:    ./management/manage-ollama.sh logs
Models:  ./management/pull-models.sh
EOF

if [ "$ENABLE_SSL" = true ]; then
    echo "SSL:     ./management/manage-ssl.sh status" >> CREDENTIALS.txt
fi

cat >> CREDENTIALS.txt <<EOF

Downloaded Models:
------------------
Run: docker exec ollama ollama list

Next Steps:
-----------
1. Configure firewall rules (see above)
2. Download required models: ./management/pull-models.sh
3. Test API connectivity from another machine
4. Distribute CA certificate to clients (if using SSL)

EOF

echo -e "${GREEN}✓ Configuration saved to CREDENTIALS.txt${NC}"
echo ""
echo -e "${CYAN}==================================================================${NC}"
