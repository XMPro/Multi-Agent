#!/bin/bash
# =================================================================
# Ollama Installation Script for Linux
# Description: Interactive installation wizard for Ollama
#              Supports two deployment modes:
#                docker  - Ollama runs in a Docker container (default)
#                hybrid  - Ollama runs natively on the host; only nginx
#                          HTTPS proxy runs in Docker
# Version: 1.1.0
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
HSA_GFX_OVERRIDE=""
AUTO_START=false
FORCE=false
CERT_TYPE=""
MACHINE_IPS_PARAM=""
DEPLOYMENT_MODE=""

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
        --cert-type)
            CERT_TYPE="$2"
            shift 2
            ;;
        --machine-ips)
            MACHINE_IPS_PARAM="$2"
            shift 2
            ;;
        --deployment-mode)
            DEPLOYMENT_MODE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Validate deployment mode if provided
if [ -n "$DEPLOYMENT_MODE" ] && [ "$DEPLOYMENT_MODE" != "docker" ] && [ "$DEPLOYMENT_MODE" != "hybrid" ]; then
    echo "Invalid --deployment-mode: $DEPLOYMENT_MODE (must be 'docker' or 'hybrid')"
    exit 1
fi

# Ensure we're in the ollama directory (not management subdirectory)
if [[ $(basename "$PWD") == "management" ]]; then
    cd ..
fi

echo -e "${CYAN}==================================================================${NC}"
echo -e "${CYAN}Ollama Installation Script (Docker / Hybrid)${NC}"
echo -e "${CYAN}==================================================================${NC}"
echo ""

# Check if Docker is running
echo -e "${GRAY}Checking Docker availability...${NC}"
if ! docker version &> /dev/null; then
    echo -e "${RED}✗ Docker is not running or not installed!${NC}"
    echo -e "${YELLOW}Please install Docker and ensure it's running.${NC}"
    exit 1
fi
echo -e "${GREEN}[OK] Docker is available${NC}"

# Check if docker-compose is available
if ! docker-compose version &> /dev/null; then
    echo -e "${RED}[ERROR] Docker Compose is not available!${NC}"
    echo -e "${YELLOW}Please ensure Docker Compose is installed.${NC}"
    exit 1
fi
echo -e "${GREEN}[OK] Docker Compose is available${NC}"

echo ""

# Deployment Mode Selection
if [ -z "$DEPLOYMENT_MODE" ]; then
    echo -e "${CYAN}Deployment Mode:${NC}"
    echo -e "  1) Docker  - Ollama runs in a Docker container (default)"
    echo -e "  2) Hybrid  - Ollama runs natively on the host; only nginx HTTPS proxy in Docker"
    echo ""
    echo -e "${GRAY}  Choose Hybrid if Ollama is already installed natively (the canonical Linux${NC}"
    echo -e "${GRAY}  install via curl ... | sh + systemd), or if you prefer to manage Ollama and${NC}"
    echo -e "${GRAY}  its models outside Docker (e.g. for cleaner GPU access).${NC}"
    echo ""
    read -p "Select deployment mode (1 or 2, default: 1): " mode_choice
    if [ "$mode_choice" = "2" ]; then
        DEPLOYMENT_MODE="hybrid"
    else
        DEPLOYMENT_MODE="docker"
    fi
fi
echo -e "${GREEN}[OK] Deployment mode: $DEPLOYMENT_MODE${NC}"
echo ""

# Hybrid mode pre-flight: verify native Ollama is installed and listening on 0.0.0.0
if [ "$DEPLOYMENT_MODE" = "hybrid" ]; then
    echo -e "${CYAN}Hybrid Mode Pre-flight Checks${NC}"
    echo -e "${GRAY}==================================================================${NC}"

    # Check Ollama is installed natively
    if ! command -v ollama &> /dev/null; then
        echo -e "${RED}[ERROR] Native Ollama not found on the host.${NC}"
        echo ""
        echo -e "${YELLOW}Hybrid mode requires Ollama to be installed natively.${NC}"
        echo -e "${YELLOW}Install steps:${NC}"
        echo -e "  1. Run: ${CYAN}curl -fsSL https://ollama.com/install.sh | sh${NC}"
        echo -e "  2. Verify: ${CYAN}ollama --version${NC}"
        echo -e "  3. Confirm the systemd service is active: ${CYAN}systemctl status ollama${NC}"
        echo -e "  4. Re-run this installer."
        echo ""
        exit 1
    fi
    OLLAMA_VERSION_OUTPUT=$(ollama --version 2>&1)
    echo -e "${GREEN}[OK] Native Ollama found: ${OLLAMA_VERSION_OUTPUT}${NC}"

    # Configure systemd override to bind Ollama to all interfaces
    OVERRIDE_DIR="/etc/systemd/system/ollama.service.d"
    OVERRIDE_FILE="$OVERRIDE_DIR/override.conf"

    NEEDS_RESTART=false
    if [ ! -f "$OVERRIDE_FILE" ] || ! grep -q 'OLLAMA_HOST=0.0.0.0:11434' "$OVERRIDE_FILE" 2>/dev/null; then
        echo -e "${GRAY}Configuring systemd override to set OLLAMA_HOST=0.0.0.0:11434...${NC}"
        if ! sudo mkdir -p "$OVERRIDE_DIR"; then
            echo -e "${RED}[ERROR] Could not create $OVERRIDE_DIR (need sudo).${NC}"
            exit 1
        fi
        echo -e "[Service]\nEnvironment=\"OLLAMA_HOST=0.0.0.0:11434\"" | sudo tee "$OVERRIDE_FILE" > /dev/null
        echo -e "${GREEN}[OK] systemd override written: $OVERRIDE_FILE${NC}"
        sudo systemctl daemon-reload
        NEEDS_RESTART=true
    else
        echo -e "${GREEN}[OK] systemd override already configured${NC}"
    fi

    if [ "$NEEDS_RESTART" = true ]; then
        echo -e "${GRAY}Restarting ollama.service...${NC}"
        if ! sudo systemctl restart ollama; then
            echo -e "${RED}[ERROR] Failed to restart ollama.service${NC}"
            exit 1
        fi
        echo -e "${GREEN}[OK] ollama.service restarted${NC}"
    fi

    # Verify Ollama is reachable
    echo -e "${GRAY}Verifying native Ollama is reachable...${NC}"
    MAX_WAIT=30
    WAITED=0
    OLLAMA_READY=false
    while [ $WAITED -lt $MAX_WAIT ]; do
        if curl -sf "http://localhost:11434/api/version" > /dev/null 2>&1; then
            OLLAMA_READY=true
            break
        fi
        sleep 2
        WAITED=$((WAITED + 2))
        echo -n "."
    done
    echo ""
    if [ "$OLLAMA_READY" = false ]; then
        echo -e "${RED}[ERROR] Native Ollama is not responding on http://localhost:11434.${NC}"
        echo -e "${YELLOW}  - Check the service:  systemctl status ollama${NC}"
        echo -e "${YELLOW}  - Check the journal:  journalctl -u ollama -n 50${NC}"
        echo -e "${YELLOW}  - Test manually:      curl http://localhost:11434/api/version${NC}"
        exit 1
    fi
    echo -e "${GREEN}[OK] Native Ollama is responding on port 11434${NC}"

    # Verify Ollama is bound to 0.0.0.0 (not 127.0.0.1) so the container can reach it
    if command -v ss &> /dev/null; then
        LISTEN_LINE=$(ss -tlnp 2>/dev/null | grep ':11434' | head -1)
    elif command -v netstat &> /dev/null; then
        LISTEN_LINE=$(netstat -tln 2>/dev/null | grep ':11434' | head -1)
    else
        LISTEN_LINE=""
    fi
    if [ -n "$LISTEN_LINE" ] && echo "$LISTEN_LINE" | grep -q '127\.0\.0\.1:11434'; then
        echo -e "${RED}[ERROR] Ollama is bound to 127.0.0.1:11434, not 0.0.0.0:11434.${NC}"
        echo -e "${YELLOW}  Docker containers cannot reach 127.0.0.1 on the host.${NC}"
        echo -e "${YELLOW}  Confirm the override file exists: cat $OVERRIDE_FILE${NC}"
        echo -e "${YELLOW}  Then: sudo systemctl daemon-reload && sudo systemctl restart ollama${NC}"
        exit 1
    fi
    echo -e "${GREEN}[OK] Ollama is bound to all interfaces (Docker can reach it via host.docker.internal)${NC}"
    echo ""
fi

# Check if Ollama container is already running
echo -e "${GRAY}Checking existing Ollama containers...${NC}"
if docker-compose ps 2>/dev/null | grep -q "ollama.*running"; then
    echo -e "${YELLOW}Ollama container is already running${NC}"
    if [ "$FORCE" = false ]; then
        read -p "Stop existing container to reconfigure? (y/n): " stop_choice
        if [[ "$stop_choice" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Stopping existing Ollama container...${NC}"
            docker-compose down
            echo -e "${GREEN}[OK] Container stopped${NC}"
        else
            echo -e "${YELLOW}Installation cancelled - container still running${NC}"
            exit 0
        fi
    else
        echo -e "${YELLOW}Force mode: Stopping existing container...${NC}"
        docker-compose down
    fi
else
    echo -e "${GREEN}[OK] No existing Ollama containers found${NC}"
fi

echo ""

# Create directory structure
echo -e "${GRAY}Creating directory structure...${NC}"
for dir in certs nginx; do
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        echo -e "${GREEN}[OK] Created directory: $dir${NC}"
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
    echo -e "${GREEN}[OK] Sufficient disk space available${NC}"
fi

echo ""

# GPU Detection (Docker mode only — native Ollama handles its own GPU)
if [ "$DEPLOYMENT_MODE" = "hybrid" ]; then
    echo -e "${GRAY}Skipping Docker GPU detection (native Ollama handles GPU directly)${NC}"
    GPU_DRIVER="none"
    DETECTED_GPU="none"
    echo ""
else
echo -e "${GRAY}Detecting GPU configuration...${NC}"
DETECTED_GPU="none"

if [ "$GPU_DRIVER" = "none" ]; then
    # Try to detect NVIDIA GPU
    if command -v nvidia-smi &> /dev/null; then
        if nvidia-smi &> /dev/null; then
            echo -e "${GREEN}[OK] NVIDIA GPU detected${NC}"
            DETECTED_GPU="nvidia"
            
            # Check for NVIDIA Docker runtime
            if docker info 2>/dev/null | grep -q nvidia; then
                echo -e "${GREEN}[OK] NVIDIA Docker runtime available${NC}"
            else
                echo -e "${YELLOW}⚠ NVIDIA Docker runtime not detected${NC}"
                echo -e "${GRAY}  You may need to install nvidia-docker2${NC}"
            fi
        fi
    fi
    
    # If no NVIDIA, check for AMD
    if [ "$DETECTED_GPU" = "none" ]; then
        if lspci 2>/dev/null | grep -iE "VGA|3D" | grep -iq "AMD\|Radeon"; then
            echo -e "${GREEN}[OK] AMD GPU detected${NC}"
            DETECTED_GPU="amd"

            # Check for ROCm installation
            if command -v rocm-smi &> /dev/null && rocm-smi &> /dev/null 2>&1; then
                echo -e "${GREEN}[OK] ROCm drivers detected${NC}"
            else
                echo -e "${YELLOW}⚠ AMD GPU found but ROCm drivers not installed${NC}"
                echo -e "${GRAY}  Install ROCm: https://rocm.docs.amd.com/en/latest/deploy/linux/quick_start.html${NC}"
                echo -e "${GRAY}  Or continue with CPU-only mode${NC}"
                read -p "Continue with GPU mode anyway? (y/n, default: n): " rocm_choice
                if [[ ! "$rocm_choice" =~ ^[Yy]$ ]]; then
                    DETECTED_GPU="none"
                    echo -e "${GRAY}Falling back to CPU-only mode${NC}"
                fi
            fi
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

            # For AMD, prompt for optional GFX version override
            if [ "$GPU_DRIVER" = "amd" ]; then
                echo ""
                echo -e "${GRAY}Some older AMD GPUs require a GFX version override to work with ROCm.${NC}"
                echo -e "${GRAY}If unsure, press Enter to skip (most modern GPUs don't need this).${NC}"
                echo -e "${GRAY}To check your GPU's GFX version, run: rocminfo | grep gfx${NC}"
                read -p "HSA_OVERRIDE_GFX_VERSION (e.g. 10.3.0, or press Enter to skip): " gfx_choice
                if [ -n "$gfx_choice" ]; then
                    HSA_GFX_OVERRIDE="$gfx_choice"
                    echo -e "${GREEN}[OK] GFX version override set to: $HSA_GFX_OVERRIDE${NC}"
                else
                    echo -e "${GRAY}GFX version override not set${NC}"
                fi
            fi
        fi
    fi
else
    echo -e "${GRAY}GPU driver specified: $GPU_DRIVER${NC}"
    DETECTED_GPU="$GPU_DRIVER"
fi

echo ""
fi # end Docker-mode GPU detection

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
# In hybrid mode SSL is mandatory — otherwise the Docker container has no purpose
# (clients would talk to native Ollama directly on port 11434).
GENERATE_SSL=false
if [ "$DEPLOYMENT_MODE" = "hybrid" ]; then
    echo -e "${CYAN}Hybrid mode: SSL is enabled automatically (the nginx container exists to provide HTTPS)${NC}"
    ENABLE_SSL=true
    ssl_choice="y"
else
echo -e "${CYAN}SSL/TLS Configuration:${NC}"
echo -e "${GRAY}Ollama uses Nginx reverse proxy for HTTPS support${NC}"
read -p "Enable SSL/TLS encryption? (y/n, default: n): " ssl_choice
fi

if [[ "$ssl_choice" =~ ^[Yy]$ ]]; then
    ENABLE_SSL=true
    echo -e "${GREEN}[OK] SSL/TLS will be enabled${NC}"
    
    # Ask for HTTPS port
    read -p "HTTPS API port (default: 11443): " https_port_choice
    if [ -n "$https_port_choice" ]; then
        HTTPS_PORT="$https_port_choice"
    fi
    echo -e "${GRAY}HTTPS API will be accessible on port: $HTTPS_PORT${NC}"
    
    if [ -n "$CERT_TYPE" ]; then
        # Cert type provided by stack installer
        if [ "$CERT_TYPE" = "ca-provided" ]; then
            echo -e "${GREEN}CA-provided certificates selected (from stack installer)${NC}"
            GENERATE_SSL=false
        else
            echo -e "${GREEN}Self-signed certificates selected (from stack installer)${NC}"
            GENERATE_SSL=true
        fi
        MACHINE_IPS=()
        if [ -n "$MACHINE_IPS_PARAM" ]; then
            IFS=',' read -ra MACHINE_IPS <<< "$MACHINE_IPS_PARAM"
        fi
    else
        # Interactive prompts
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

            # Detect machine IP addresses for SSL certificate SAN
            echo ""
            echo -e "${GRAY}Detecting machine IP addresses...${NC}"
            MACHINE_IPS=()
            if command -v hostname &> /dev/null; then
                IPS=$(hostname -I 2>/dev/null | tr ' ' '\n' | grep -v '^127\.' | grep -v '^::')
                if [ -n "$IPS" ]; then
                    echo -e "${GREEN}Detected IP addresses:${NC}"
                    i=0
                    declare -a ALL_IPS_ARRAY
                    while IFS= read -r ip; do
                        echo -e "${GRAY}  [$i] $ip${NC}"
                        ALL_IPS_ARRAY+=("$ip")
                        ((i++))
                    done <<< "$IPS"

                    echo ""
                    read -p "Enter IP numbers to include in certificate (comma-separated, e.g., '0,1') or press Enter to skip: " ip_choice

                    if [ -n "$ip_choice" ]; then
                        IFS=',' read -ra SELECTED_INDICES <<< "$ip_choice"
                        for index in "${SELECTED_INDICES[@]}"; do
                            index=$(echo "$index" | xargs) # Trim whitespace
                            if [[ "$index" =~ ^[0-9]+$ ]] && [ "$index" -lt "${#ALL_IPS_ARRAY[@]}" ]; then
                                MACHINE_IPS+=("${ALL_IPS_ARRAY[$index]}")
                            fi
                        done

                        if [ ${#MACHINE_IPS[@]} -gt 0 ]; then
                            echo -e "${CYAN}Selected IPs: ${MACHINE_IPS[*]}${NC}"
                        else
                            echo -e "${GRAY}No valid IPs selected${NC}"
                        fi
                    else
                        echo -e "${GRAY}IP addresses not included (localhost/domain only)${NC}"
                    fi
                else
                    echo -e "${GRAY}Could not detect IP addresses, skipping${NC}"
                fi
            else
                echo -e "${GRAY}Could not detect IP addresses${NC}"
            fi
        fi
    fi
else
    echo -e "${GRAY}SSL/TLS will be disabled (HTTP only)${NC}"
    MACHINE_IPS=()
fi

echo ""

# If SSL not enabled, still detect IPs for display purposes
if [ "$ENABLE_SSL" = false ]; then
    echo -e "${GRAY}Detecting network configuration...${NC}"
    if command -v hostname &> /dev/null; then
        IPS=$(hostname -I 2>/dev/null | tr ' ' '\n' | grep -v '^127\.' | grep -v '^::')
        if [ -n "$IPS" ]; then
            echo -e "${GREEN}[OK] Detected IP addresses:${NC}"
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
fi

echo ""

# Create .env file
echo -e "${GRAY}Creating configuration files...${NC}"

if [ "$DEPLOYMENT_MODE" = "hybrid" ]; then
    # Hybrid mode: write a minimal .env with only the keys the hybrid compose actually uses.
    # COMPOSE_FILE makes docker-compose pick the hybrid compose by default — no -f flag needed.
    cat > .env <<EOF
# =================================================================
# Ollama Hybrid Deployment Configuration
# Native Ollama runs on the host; only nginx HTTPS proxy runs in Docker.
# =================================================================
COMPOSE_FILE=docker-compose.hybrid.yml
OLLAMA_HTTPS_PORT=$HTTPS_PORT
OLLAMA_DOMAIN=$DOMAIN
EOF
    echo -e "${GREEN}[OK] Wrote hybrid .env (COMPOSE_FILE=docker-compose.hybrid.yml)${NC}"
else
    # Docker mode: derive .env from .env.template
    if [ ! -f ".env.template" ]; then
        echo -e "${RED}[ERROR] .env.template not found!${NC}"
        echo -e "${YELLOW}Please ensure you're running this script from the ollama directory${NC}"
        exit 1
    fi

    cp .env.template .env
    echo -e "${GREEN}[OK] Created .env file from template${NC}"

    # Update .env file with configuration
    sed -i "s/OLLAMA_PORT=.*/OLLAMA_PORT=$PORT/" .env
    sed -i "s/OLLAMA_HTTPS_PORT=.*/OLLAMA_HTTPS_PORT=$HTTPS_PORT/" .env
    sed -i "s/OLLAMA_ENABLE_SSL=.*/OLLAMA_ENABLE_SSL=$ENABLE_SSL/" .env
    sed -i "s/OLLAMA_DOMAIN=.*/OLLAMA_DOMAIN=$DOMAIN/" .env
    sed -i "s/OLLAMA_GPU_DRIVER=.*/OLLAMA_GPU_DRIVER=$GPU_DRIVER/" .env

    # Set Docker image based on GPU type
    if [ "$GPU_DRIVER" = "amd" ]; then
        sed -i "s|OLLAMA_IMAGE=.*|OLLAMA_IMAGE=ollama/ollama:rocm|" .env
        echo -e "${GREEN}[OK] Configured to use ROCm image (ollama/ollama:rocm)${NC}"
        sed -i "s|HSA_OVERRIDE_GFX_VERSION=.*|HSA_OVERRIDE_GFX_VERSION=$HSA_GFX_OVERRIDE|" .env
    else
        sed -i "s|OLLAMA_IMAGE=.*|OLLAMA_IMAGE=ollama/ollama:latest|" .env
    fi

    # Add COMPOSE_PROFILES if SSL is enabled
    if [ "$ENABLE_SSL" = true ]; then
        echo "COMPOSE_PROFILES=ssl" >> .env
    fi

    echo -e "${GREEN}[OK] Updated .env with configuration${NC}"
fi

# Update docker-compose.yml based on GPU type
if [ "$GPU_DRIVER" = "amd" ]; then
    echo -e "${GRAY}Configuring AMD ROCm support in docker-compose.yml...${NC}"

    # AMD requires service-level device passthrough, not deploy.resources syntax
    awk '
    /container_name: ollama$/ {
        print
        print "    devices:"
        print "      - /dev/kfd:/dev/kfd"
        print "      - /dev/dri:/dev/dri"
        print "    group_add:"
        print "      - video"
        print "      - render"
        next
    }
    { print }
    ' docker-compose.yml > docker-compose.yml.tmp

    mv docker-compose.yml.tmp docker-compose.yml
    echo -e "${GREEN}[OK] AMD ROCm device passthrough configured in docker-compose.yml${NC}"

elif [ "$GPU_DRIVER" = "nvidia" ]; then
    echo -e "${GRAY}Configuring NVIDIA GPU support in docker-compose.yml...${NC}"

    # Insert deploy block with GPU reservations before the logging section of the ollama service
    awk '
    /^    logging:/ && !done {
        print "    deploy:"
        print "      resources:"
        print "        reservations:"
        print "          devices:"
        print "            - driver: nvidia"
        print "              count: all"
        print "              capabilities: [gpu]"
        done=1
    }
    { print }
    ' docker-compose.yml > docker-compose.yml.tmp

    mv docker-compose.yml.tmp docker-compose.yml
    echo -e "${GREEN}[OK] NVIDIA GPU support enabled in docker-compose.yml${NC}"
fi

# Hybrid mode: verify the parallel hybrid compose + nginx config exist.
# These are committed parallel files (not generated) — selected by COMPOSE_FILE in .env.
if [ "$DEPLOYMENT_MODE" = "hybrid" ]; then
    if [ ! -f "docker-compose.hybrid.yml" ]; then
        echo -e "${RED}[ERROR] docker-compose.hybrid.yml is missing.${NC}"
        echo -e "${YELLOW}  Re-extract the source ZIP — this file ships alongside docker-compose.yml.${NC}"
        exit 1
    fi
    if [ ! -f "nginx/nginx.hybrid.conf" ]; then
        echo -e "${RED}[ERROR] nginx/nginx.hybrid.conf is missing.${NC}"
        echo -e "${YELLOW}  Re-extract the source ZIP — this file ships alongside nginx/nginx.conf.${NC}"
        exit 1
    fi
    echo -e "${GREEN}[OK] Hybrid compose and nginx config present (selected via COMPOSE_FILE in .env)${NC}"
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
        echo -e "${GREEN}[OK] SSL certificates generated successfully${NC}"
    else
        echo -e "${RED}[ERROR] Certificate generation failed${NC}"
        ENABLE_SSL=false
    fi
fi

echo ""

# When called from stack installer (--force), only configure - don't start services
if [ "$FORCE" = true ]; then
    echo ""
    echo -e "${GREEN}[OK] Ollama configuration complete (services will be started by stack installer)${NC}"
    exit 0
fi

# Ask if user wants to start the service now
echo ""
if [ "$DEPLOYMENT_MODE" = "hybrid" ]; then
    read -p "Start nginx HTTPS proxy now? (y/n, default: y): " start_choice
else
    read -p "Start Ollama service now? (y/n, default: y): " start_choice
fi
if [[ "$start_choice" =~ ^[Nn]$ ]]; then
    echo ""
    echo -e "${CYAN}==================================================================${NC}"
    echo -e "${GREEN}Configuration Complete!${NC}"
    echo -e "${CYAN}==================================================================${NC}"
    echo ""
    echo -e "${GRAY}To start later, run:${NC}"
    echo -e "${GRAY}  docker-compose up -d${NC}"
    echo ""
    exit 0
fi

if [ "$DEPLOYMENT_MODE" = "hybrid" ]; then
    # Hybrid mode: only nginx-ssl needs to start. Native Ollama is already running.
    echo -e "${GRAY}Starting nginx HTTPS proxy...${NC}"
    docker-compose up -d

    echo -e "${GRAY}Waiting for nginx to become ready...${NC}"
    MAX_WAIT=30
    WAITED=0
    HEALTHY=false
    while [ $WAITED -lt $MAX_WAIT ]; do
        sleep 2
        WAITED=$((WAITED + 2))
        if curl -sfk "https://localhost:$HTTPS_PORT/api/version" > /dev/null 2>&1; then
            HEALTHY=true
            break
        fi
        echo -n "."
    done
    echo ""

    if [ "$HEALTHY" = true ]; then
        echo -e "${GREEN}[OK] nginx HTTPS proxy is running and reaching native Ollama${NC}"
    else
        echo -e "${YELLOW}⚠ nginx started but HTTPS health check timed out${NC}"
        echo -e "${GRAY}  Probe from inside the container to find the cause:${NC}"
        echo -e "${GRAY}    docker exec ollama-nginx-ssl wget -qO- http://host.docker.internal:11434/api/version${NC}"
        echo -e "${GRAY}  See logs: docker-compose logs nginx-ssl${NC}"
    fi
else
    # Docker mode: full Ollama-in-container startup with health check
    echo -e "${GRAY}Starting Ollama service...${NC}"
    echo -e "${GRAY}This may take a minute...${NC}"

    docker-compose up -d

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
        echo -e "${GREEN}[OK] Ollama service is running and healthy${NC}"

        # Verify GPU access if GPU is enabled
        if [ "$GPU_DRIVER" = "amd" ]; then
            echo ""
            echo -e "${CYAN}Verifying AMD GPU access...${NC}"
            sleep 3
            if docker exec ollama rocm-smi &> /dev/null 2>&1; then
                echo -e "${GREEN}[OK] AMD GPU accessible via ROCm in container${NC}"
            else
                echo -e "${YELLOW}⚠ AMD GPU not accessible in container${NC}"
                echo -e "${GRAY}  Verify ROCm drivers are installed and user is in render/video groups${NC}"
                echo -e "${GRAY}  Run: sudo usermod -a -G render,video \$USER && sudo reboot${NC}"
            fi
        elif [ "$GPU_DRIVER" = "nvidia" ]; then
            echo ""
            echo -e "${CYAN}Verifying NVIDIA GPU access...${NC}"
            sleep 3
            if docker exec ollama nvidia-smi &> /dev/null 2>&1; then
                echo -e "${GREEN}[OK] NVIDIA GPU accessible in container${NC}"
            else
                echo -e "${YELLOW}⚠ NVIDIA GPU not accessible in container${NC}"
                echo -e "${GRAY}  Verify nvidia-container-toolkit is installed${NC}"
            fi
        fi

        # Start nginx-ssl if SSL is enabled
        if [ "$ENABLE_SSL" = true ]; then
            echo -e "${GRAY}Starting nginx-ssl service...${NC}"
            docker-compose up -d nginx-ssl 2>&1 > /dev/null
            sleep 3
            echo -e "${GREEN}[OK] nginx-ssl service started${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ Ollama service started but health check timed out${NC}"
        echo -e "${GRAY}  Check logs with: docker-compose logs ollama${NC}"
        if [ "$ENABLE_SSL" = true ]; then
            echo -e "${GRAY}  nginx-ssl will start once ollama becomes healthy${NC}"
        fi
    fi
fi

echo ""

# Display service status
echo -e "${CYAN}Service Status:${NC}"
docker-compose ps 2>/dev/null | tail -n +2 | while read line; do
    if echo "$line" | grep -q "running"; then
        echo -e "${GREEN}  [OK] $line${NC}"
    else
        echo -e "${RED}  [STOPPED] $line${NC}"
    fi
done

echo ""

echo ""
echo -e "${CYAN}Model Downloads:${NC}"
echo -e "${GRAY}Ollama requires at least one embedding model to function properly${NC}"
echo ""
echo -e "${GRAY}Download models using:${NC}"
if [ "$DEPLOYMENT_MODE" = "hybrid" ]; then
    echo -e "${GRAY}  ollama pull nomic-embed-text:latest${NC}"
    echo -e "${GRAY}  ollama pull llama3.2:3b${NC}"
    echo ""
    echo -e "${GRAY}(Hybrid mode: models are managed natively, not via docker exec)${NC}"
else
    echo -e "${GRAY}  docker exec ollama ollama pull nomic-embed-text:latest${NC}"
    echo -e "${GRAY}  docker exec ollama ollama pull llama3.2:3b${NC}"
fi
echo ""
echo -e "${GRAY}List available models: https://ollama.com/library${NC}"
echo ""
echo -e "${CYAN}==================================================================${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${CYAN}==================================================================${NC}"
echo ""

# Display connection information
echo -e "${CYAN}Connection Information:${NC}"
if [ "$DEPLOYMENT_MODE" = "hybrid" ]; then
    echo -e "${GRAY}  HTTP API:  http://localhost:11434  (native Ollama on host, not via Docker)${NC}"
    echo -e "${GRAY}  HTTPS API: https://localhost:$HTTPS_PORT  (via nginx Docker container)${NC}"
    for ip in "${MACHINE_IPS[@]}"; do
        echo -e "${GRAY}             https://$ip:$HTTPS_PORT${NC}"
    done
    echo ""
    echo -e "${YELLOW}  CA Certificate: certs/ca.crt (distribute to clients)${NC}"
else
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
fi

echo ""
if [ "$DEPLOYMENT_MODE" = "hybrid" ]; then
    echo -e "${GRAY}Deployment: Hybrid (native Ollama + Docker nginx)${NC}"
else
    echo -e "${GRAY}GPU Support: $GPU_DRIVER${NC}"
fi
echo ""

# Display firewall configuration
echo -e "${CYAN}Firewall Configuration:${NC}"
echo -e "${GRAY}To allow external access, configure your firewall:${NC}"
echo ""
if [ "$DEPLOYMENT_MODE" = "hybrid" ]; then
    echo -e "${GRAY}For ufw:${NC}"
    echo -e "${GRAY}  sudo ufw allow $HTTPS_PORT/tcp${NC}"
    echo -e "${GRAY}  sudo ufw reload${NC}"
    echo ""
    echo -e "${GRAY}For firewalld:${NC}"
    echo -e "${GRAY}  sudo firewall-cmd --permanent --add-port=$HTTPS_PORT/tcp${NC}"
    echo -e "${GRAY}  sudo firewall-cmd --reload${NC}"
    echo ""
    echo -e "${GRAY}Note: native Ollama listens on 0.0.0.0:11434 already. To restrict that to${NC}"
    echo -e "${GRAY}      Docker only (recommended), allow inbound 11434 only from the Docker${NC}"
    echo -e "${GRAY}      bridge subnet (typically 172.16.0.0/12).${NC}"
else
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
fi
echo ""

# Test commands
echo -e "${CYAN}Test Commands:${NC}"
if [ "$DEPLOYMENT_MODE" = "hybrid" ]; then
    echo -e "${GRAY}  curl http://localhost:11434/api/version    (direct to native Ollama)${NC}"
    echo -e "${GRAY}  curl -k https://localhost:$HTTPS_PORT/api/version    (via nginx HTTPS proxy)${NC}"
else
    echo -e "${GRAY}  curl http://localhost:$PORT/api/version${NC}"
    if [ "$ENABLE_SSL" = true ]; then
        echo -e "${GRAY}  curl -k https://localhost:$HTTPS_PORT/api/version${NC}"
    fi
fi
echo ""

# Management commands
echo -e "${CYAN}Management Commands:${NC}"
if [ "$DEPLOYMENT_MODE" = "hybrid" ]; then
    echo -e "${GRAY}  nginx logs:    docker-compose logs -f nginx-ssl${NC}"
    echo -e "${GRAY}  nginx status:  docker-compose ps${NC}"
    echo -e "${GRAY}  Models:        ollama list  /  ollama pull <name>  (native commands)${NC}"
    echo -e "${GRAY}  SSL:           ./management/manage-ssl.sh status${NC}"
else
    echo -e "${GRAY}  Status:  ./management/manage-ollama.sh status${NC}"
    echo -e "${GRAY}  Logs:    ./management/manage-ollama.sh logs${NC}"
    echo -e "${GRAY}  Models:  ./management/pull-models.sh${NC}"
    if [ "$ENABLE_SSL" = true ]; then
        echo -e "${GRAY}  SSL:     ./management/manage-ssl.sh status${NC}"
    fi
fi
echo ""
echo -e "${CYAN}==================================================================${NC}"