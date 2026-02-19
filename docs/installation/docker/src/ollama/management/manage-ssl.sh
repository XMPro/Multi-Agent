#!/bin/bash
# =================================================================
# Ollama SSL Certificate Management Script for Linux
# Description: Generate and manage SSL/TLS certificates for Nginx reverse proxy
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
ACTION=""
DOMAIN="localhost"
VALID_DAYS=365
CA_CERT_PATH=""
CA_KEY_PATH=""
SERVER_CERT_PATH=""
SERVER_KEY_PATH=""
FORCE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        generate|enable|disable|status|renew|install-ca)
            ACTION="$1"
            shift
            ;;
        --domain)
            DOMAIN="$2"
            shift 2
            ;;
        --valid-days)
            VALID_DAYS="$2"
            shift 2
            ;;
        --ca-cert)
            CA_CERT_PATH="$2"
            shift 2
            ;;
        --ca-key)
            CA_KEY_PATH="$2"
            shift 2
            ;;
        --server-cert)
            SERVER_CERT_PATH="$2"
            shift 2
            ;;
        --server-key)
            SERVER_KEY_PATH="$2"
            shift 2
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
echo -e "${CYAN}Ollama SSL Certificate Management${NC}"
echo -e "${CYAN}==================================================================${NC}"
echo ""

# Show help if no action provided
if [ -z "$ACTION" ]; then
    echo -e "${GRAY}Usage: ./manage-ssl.sh <action> [options]${NC}"
    echo ""
    echo -e "${CYAN}Actions:${NC}"
    echo -e "${GRAY}  generate      Generate new self-signed SSL certificates${NC}"
    echo -e "${GRAY}  install-ca    Install CA-provided SSL certificates${NC}"
    echo -e "${GRAY}  enable        Enable SSL (start nginx-ssl service)${NC}"
    echo -e "${GRAY}  disable       Disable SSL (stop nginx-ssl service)${NC}"
    echo -e "${GRAY}  status        Show SSL certificate status${NC}"
    echo -e "${GRAY}  renew         Renew existing SSL certificates${NC}"
    echo ""
    echo -e "${CYAN}Parameters:${NC}"
    echo -e "${GRAY}  --domain         Certificate domain name (default: localhost)${NC}"
    echo -e "${GRAY}  --valid-days     Certificate validity in days (default: 365)${NC}"
    echo -e "${GRAY}  --ca-cert        Path to CA certificate file (for install-ca)${NC}"
    echo -e "${GRAY}  --ca-key         Path to CA private key file (for install-ca)${NC}"
    echo -e "${GRAY}  --server-cert    Path to server certificate file (for install-ca)${NC}"
    echo -e "${GRAY}  --server-key     Path to server private key file (for install-ca)${NC}"
    echo -e "${GRAY}  --force          Overwrite existing certificates without prompting${NC}"
    echo ""
    echo -e "${CYAN}Examples:${NC}"
    echo -e "${GRAY}  # Generate self-signed certificates${NC}"
    echo -e "${GRAY}  ./manage-ssl.sh generate${NC}"
    echo -e "${GRAY}  ./manage-ssl.sh generate --domain ollama.company.com --valid-days 730${NC}"
    echo ""
    echo -e "${GRAY}  # Install CA-provided certificates${NC}"
    echo -e "${GRAY}  ./manage-ssl.sh install-ca --server-cert /path/to/server.crt --server-key /path/to/server.key${NC}"
    echo ""
    echo -e "${GRAY}  # Management commands${NC}"
    echo -e "${GRAY}  ./manage-ssl.sh enable${NC}"
    echo -e "${GRAY}  ./manage-ssl.sh status${NC}"
    echo -e "${GRAY}  ./manage-ssl.sh renew --force${NC}"
    echo ""
    echo -e "${CYAN}==================================================================${NC}"
    exit 0
fi

# Check if Docker is available
check_docker() {
    if ! docker version &> /dev/null; then
        echo -e "${RED}✗ Docker is not available!${NC}"
        echo -e "${YELLOW}Please ensure Docker is running.${NC}"
        return 1
    fi
    return 0
}

# Get machine IP addresses
get_machine_ips() {
    local ips=()
    if command -v hostname &> /dev/null; then
        while IFS= read -r ip; do
            ips+=("$ip")
        done < <(hostname -I 2>/dev/null | tr ' ' '\n' | grep -v '^127\.' | grep -v '^::')
    fi
    echo "${ips[@]}"
}

# Generate SSL certificates
generate_ssl_certificates() {
    echo -e "${GRAY}Generating SSL certificates for domain: $DOMAIN${NC}"
    echo -e "${GRAY}Certificate validity: $VALID_DAYS days${NC}"
    echo ""
    
    # Create certs directory if it doesn't exist
    if [ ! -d "certs" ]; then
        mkdir -p certs
        echo -e "${GREEN}✓ Created certs directory${NC}"
    fi
    
    # Check if certificates already exist
    if [ -f "certs/server.crt" ] && [ "$FORCE" = false ]; then
        echo -e "${YELLOW}⚠ Certificates already exist!${NC}"
        read -p "Overwrite existing certificates? (y/n): " overwrite
        if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Certificate generation cancelled${NC}"
            return 1
        fi
    fi
    
    # Detect machine IPs
    echo -e "${GRAY}Detecting machine IP addresses...${NC}"
    MACHINE_IPS=($(get_machine_ips))
    
    if [ ${#MACHINE_IPS[@]} -gt 0 ]; then
        echo -e "${GRAY}Detected IPs:${NC}"
        for ip in "${MACHINE_IPS[@]}"; do
            echo -e "${GRAY}  • $ip${NC}"
        done
    fi
    
    # Generate CA private key
    echo ""
    echo -e "${GRAY}Generating CA certificate...${NC}"
    docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine/openssl genrsa -out ca.key 4096 2>/dev/null
    
    # Generate CA certificate
    docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine/openssl req -new -x509 -days $VALID_DAYS -key ca.key -out ca.crt -subj "/C=US/ST=State/L=City/O=Ollama/CN=Ollama-CA" 2>/dev/null
    
    # Generate server private key
    echo -e "${GRAY}Generating server certificate...${NC}"
    docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine/openssl genrsa -out server.key 4096 2>/dev/null
    
    # Create OpenSSL config with SAN
    SAN_ENTRIES="DNS:localhost,DNS:$DOMAIN,IP:127.0.0.1"
    for ip in "${MACHINE_IPS[@]}"; do
        SAN_ENTRIES="$SAN_ENTRIES,IP:$ip"
    done
    
    echo -e "${GRAY}Subject Alternative Names: $SAN_ENTRIES${NC}"
    
    cat > certs/openssl.cnf <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req

[req_distinguished_name]

[v3_req]
subjectAltName = $SAN_ENTRIES
EOF
    
    # Generate CSR
    docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine/openssl req -new -key server.key -out server.csr -subj "/C=US/ST=State/L=City/O=Ollama/CN=$DOMAIN" -config openssl.cnf 2>/dev/null
    
    # Sign certificate
    docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine/openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days $VALID_DAYS -extensions v3_req -extfile openssl.cnf 2>/dev/null
    
    # Cleanup temporary files
    rm -f certs/server.csr certs/ca.srl certs/openssl.cnf
    
    # Verify certificates were created
    if [ -f "certs/server.crt" ] && [ -f "certs/server.key" ] && [ -f "certs/ca.crt" ]; then
        echo ""
        echo -e "${GREEN}✓ SSL certificates generated successfully!${NC}"
        echo ""
        echo -e "${CYAN}Certificate Details:${NC}"
        echo -e "${GRAY}  Domain: $DOMAIN${NC}"
        echo -e "${GRAY}  Valid for: $VALID_DAYS days${NC}"
        echo -e "${GRAY}  Subject Alternative Names:${NC}"
        IFS=',' read -ra SAN_ARRAY <<< "$SAN_ENTRIES"
        for entry in "${SAN_ARRAY[@]}"; do
            echo -e "${GRAY}    • $entry${NC}"
        done
        echo ""
        echo -e "${CYAN}Files created:${NC}"
        echo -e "${GRAY}  • certs/ca.crt (CA Certificate - distribute to clients)${NC}"
        echo -e "${GRAY}  • certs/ca.key (CA Private Key - keep secure!)${NC}"
        echo -e "${GRAY}  • certs/server.crt (Server Certificate)${NC}"
        echo -e "${GRAY}  • certs/server.key (Server Private Key)${NC}"
        echo ""
        echo -e "${CYAN}Next steps:${NC}"
        echo -e "${GRAY}  1. Enable SSL: ./management/manage-ssl.sh enable${NC}"
        echo -e "${GRAY}  2. Distribute ca.crt to client machines${NC}"
        echo ""
        return 0
    else
        echo -e "${RED}✗ Certificate files not created properly${NC}"
        return 1
    fi
}

# Install CA-provided certificates
install_ca_certificates() {
    echo -e "${GRAY}Installing CA-provided SSL certificates...${NC}"
    echo ""
    
    # Create certs directory if it doesn't exist
    if [ ! -d "certs" ]; then
        mkdir -p certs
        echo -e "${GREEN}✓ Created certs directory${NC}"
    fi
    
    # Validate required certificate files exist
    if [ -z "$SERVER_CERT_PATH" ] || [ ! -f "$SERVER_CERT_PATH" ]; then
        echo -e "${RED}✗ Server certificate file not found or not specified: $SERVER_CERT_PATH${NC}"
        return 1
    fi
    if [ -z "$SERVER_KEY_PATH" ] || [ ! -f "$SERVER_KEY_PATH" ]; then
        echo -e "${RED}✗ Server private key file not found or not specified: $SERVER_KEY_PATH${NC}"
        return 1
    fi
    
    # Copy server certificates
    cp "$SERVER_CERT_PATH" certs/server.crt
    cp "$SERVER_KEY_PATH" certs/server.key
    echo -e "${GREEN}✓ Server certificates installed${NC}"
    
    # Copy CA certificate if provided
    if [ -n "$CA_CERT_PATH" ] && [ -f "$CA_CERT_PATH" ]; then
        cp "$CA_CERT_PATH" certs/ca.crt
        echo -e "${GREEN}✓ CA certificate installed${NC}"
    fi
    
    # Copy CA private key if provided
    if [ -n "$CA_KEY_PATH" ] && [ -f "$CA_KEY_PATH" ]; then
        cp "$CA_KEY_PATH" certs/ca.key
        echo -e "${GREEN}✓ CA private key installed${NC}"
    fi
    
    # Validate certificates
    echo ""
    echo -e "${GRAY}Validating certificates...${NC}"
    
    CERT_MODULUS=$(docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine/openssl x509 -noout -modulus -in server.crt 2>/dev/null | docker run --rm -i alpine/openssl md5)
    KEY_MODULUS=$(docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine/openssl rsa -noout -modulus -in server.key 2>/dev/null | docker run --rm -i alpine/openssl md5)
    
    if [ "$CERT_MODULUS" = "$KEY_MODULUS" ]; then
        echo -e "${GREEN}✓ Certificate and key match${NC}"
    else
        echo -e "${YELLOW}⚠ Warning: Certificate and key may not match${NC}"
    fi
    
    # Check certificate expiration
    CERT_INFO=$(docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine/openssl x509 -noout -dates -in server.crt 2>/dev/null)
    echo -e "${GRAY}Certificate validity:${NC}"
    echo -e "${GRAY}$CERT_INFO${NC}"
    
    echo ""
    echo -e "${GREEN}✓ CA-provided certificates installed successfully!${NC}"
    echo ""
    echo -e "${CYAN}Next steps:${NC}"
    echo -e "${GRAY}  1. Enable SSL: ./management/manage-ssl.sh enable${NC}"
    echo ""
    
    return 0
}

# Enable SSL
enable_ssl() {
    echo -e "${GRAY}Enabling SSL/TLS for Ollama...${NC}"
    echo ""
    
    # Check if certificates exist
    if [ ! -f "certs/server.crt" ] || [ ! -f "certs/server.key" ]; then
        echo -e "${RED}✗ SSL certificates not found!${NC}"
        echo -e "${YELLOW}Generate certificates first:${NC}"
        echo -e "${GRAY}  ./management/manage-ssl.sh generate${NC}"
        echo -e "${YELLOW}Or install CA-provided certificates:${NC}"
        echo -e "${GRAY}  ./management/manage-ssl.sh install-ca --server-cert <path> --server-key <path>${NC}"
        return 1
    fi
    
    # Update .env file to enable SSL profile
    if [ -f ".env" ]; then
        # Check if COMPOSE_PROFILES already exists
        if grep -q "COMPOSE_PROFILES=" .env; then
            sed -i 's/COMPOSE_PROFILES=.*/COMPOSE_PROFILES=ssl/' .env
        else
            echo "COMPOSE_PROFILES=ssl" >> .env
        fi
        
        # Update SSL enabled flag
        sed -i 's/OLLAMA_ENABLE_SSL=.*/OLLAMA_ENABLE_SSL=true/' .env
        
        echo -e "${GREEN}✓ Updated .env configuration${NC}"
    fi
    
    # Start nginx-ssl service
    echo -e "${GRAY}Starting nginx-ssl service...${NC}"
    docker-compose up -d nginx-ssl 2>&1 > /dev/null
    
    sleep 3
    
    # Check if nginx-ssl is running
    if docker-compose ps 2>/dev/null | grep -q "nginx-ssl.*running"; then
        echo -e "${GREEN}✓ nginx-ssl service is running${NC}"
        
        # Get HTTPS port from .env
        HTTPS_PORT="11443"
        if [ -f ".env" ]; then
            HTTPS_PORT=$(grep "OLLAMA_HTTPS_PORT=" .env | cut -d'=' -f2)
        fi
        
        echo ""
        echo -e "${GREEN}✓ SSL/TLS enabled successfully!${NC}"
        echo ""
        echo -e "${CYAN}HTTPS Endpoint:${NC}"
        echo -e "${GRAY}  https://localhost:$HTTPS_PORT${NC}"
        
        MACHINE_IPS=($(get_machine_ips))
        for ip in "${MACHINE_IPS[@]}"; do
            echo -e "${GRAY}  https://$ip:$HTTPS_PORT${NC}"
        done
        
        echo ""
        echo -e "${CYAN}Test command:${NC}"
        echo -e "${GRAY}  curl -k https://localhost:$HTTPS_PORT/api/version${NC}"
        echo ""
        echo -e "${CYAN}CA Certificate for clients:${NC}"
        echo -e "${GRAY}  certs/ca.crt${NC}"
        echo ""
        
        return 0
    else
        echo -e "${RED}✗ Failed to start nginx-ssl service${NC}"
        echo -e "${YELLOW}Check logs: docker-compose logs nginx-ssl${NC}"
        return 1
    fi
}

# Disable SSL
disable_ssl() {
    echo -e "${GRAY}Disabling SSL/TLS for Ollama...${NC}"
    echo ""
    
    # Stop nginx-ssl service
    echo -e "${GRAY}Stopping nginx-ssl service...${NC}"
    docker-compose stop nginx-ssl 2>&1 > /dev/null
    
    # Update .env file
    if [ -f ".env" ]; then
        sed -i 's/COMPOSE_PROFILES=ssl/# COMPOSE_PROFILES=ssl/' .env
        sed -i 's/OLLAMA_ENABLE_SSL=true/OLLAMA_ENABLE_SSL=false/' .env
        echo -e "${GREEN}✓ Updated .env configuration${NC}"
    fi
    
    echo -e "${GREEN}✓ SSL/TLS disabled${NC}"
    echo ""
    echo -e "${GRAY}Ollama is now accessible via HTTP only${NC}"
    echo ""
}

# Show SSL status
show_ssl_status() {
    echo -e "${CYAN}SSL/TLS Status${NC}"
    echo -e "${CYAN}==============${NC}"
    echo ""
    
    # Check service status
    echo -e "${CYAN}Service Status:${NC}"
    if docker-compose ps 2>/dev/null | grep -q "ollama.*running"; then
        echo -e "${GREEN}  ✓ Ollama: Running${NC}"
    else
        echo -e "${RED}  ✗ Ollama: Stopped${NC}"
    fi
    
    if docker-compose ps 2>/dev/null | grep -q "nginx-ssl"; then
        if docker-compose ps 2>/dev/null | grep -q "nginx-ssl.*running"; then
            echo -e "${GREEN}  ✓ nginx-ssl: Running${NC}"
        else
            echo -e "${RED}  ✗ nginx-ssl: Stopped${NC}"
        fi
    else
        echo -e "${GRAY}  nginx-ssl: Not configured${NC}"
    fi
    
    echo ""
    
    # Check certificate files
    echo -e "${CYAN}Certificate Files:${NC}"
    for file in certs/ca.crt certs/server.crt certs/server.key; do
        if [ -f "$file" ]; then
            echo -e "${GREEN}  ✓ $file${NC}"
        else
            echo -e "${RED}  ✗ $file (not found)${NC}"
        fi
    done
    
    echo ""
    
    # Show certificate details if they exist
    if [ -f "certs/server.crt" ]; then
        echo -e "${CYAN}Server Certificate Details:${NC}"
        CERT_INFO=$(docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine/openssl x509 -noout -subject -issuer -dates -in server.crt 2>/dev/null)
        echo -e "${GRAY}$CERT_INFO${NC}"
        
        echo ""
        echo -e "${CYAN}Subject Alternative Names:${NC}"
        SAN_INFO=$(docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine/openssl x509 -noout -text -in server.crt 2>/dev/null | grep -A1 "Subject Alternative Name")
        if [ -n "$SAN_INFO" ]; then
            echo -e "${GRAY}$SAN_INFO${NC}"
        else
            echo -e "${GRAY}  No SAN entries found${NC}"
        fi
    fi
    
    echo ""
    
    # Show endpoints
    echo -e "${CYAN}API Endpoints:${NC}"
    HTTP_PORT="11434"
    HTTPS_PORT="11443"
    
    if [ -f ".env" ]; then
        HTTP_PORT=$(grep "OLLAMA_PORT=" .env | cut -d'=' -f2)
        HTTPS_PORT=$(grep "OLLAMA_HTTPS_PORT=" .env | cut -d'=' -f2)
    fi
    
    echo -e "${GRAY}  HTTP:  http://localhost:$HTTP_PORT${NC}"
    if docker-compose ps 2>/dev/null | grep -q "nginx-ssl.*running"; then
        echo -e "${GRAY}  HTTPS: https://localhost:$HTTPS_PORT${NC}"
    else
        echo -e "${GRAY}  HTTPS: Not enabled${NC}"
    fi
    
    echo ""
}

# Renew certificates
renew_certificates() {
    echo -e "${GRAY}Renewing SSL certificates...${NC}"
    echo ""
    
    if [ ! -f "certs/server.crt" ]; then
        echo -e "${RED}✗ No existing certificates found to renew${NC}"
        return 1
    fi
    
    # Backup existing certificates
    BACKUP_DIR="certs/backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    cp certs/*.crt "$BACKUP_DIR/" 2>/dev/null
    cp certs/*.key "$BACKUP_DIR/" 2>/dev/null
    
    echo -e "${GREEN}✓ Backed up existing certificates to: $BACKUP_DIR${NC}"
    echo ""
    
    # Get domain from existing certificate
    CERT_SUBJECT=$(docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine/openssl x509 -noout -subject -in server.crt 2>/dev/null)
    if [[ $CERT_SUBJECT =~ CN[[:space:]]*=[[:space:]]*([^,]+) ]]; then
        DOMAIN="${BASH_REMATCH[1]}"
        DOMAIN=$(echo "$DOMAIN" | xargs) # Trim whitespace
    fi
    
    # Generate new certificates
    if generate_ssl_certificates; then
        # Restart nginx-ssl if it's running
        if docker-compose ps 2>/dev/null | grep -q "nginx-ssl.*running"; then
            echo -e "${GRAY}Restarting nginx-ssl service...${NC}"
            docker-compose restart nginx-ssl 2>&1 > /dev/null
            echo -e "${GREEN}✓ nginx-ssl service restarted${NC}"
        fi
        
        echo ""
        echo -e "${GREEN}✓ Certificates renewed successfully!${NC}"
        echo ""
        return 0
    else
        return 1
    fi
}

# Main script logic
if ! check_docker; then
    exit 1
fi

case $ACTION in
    generate)
        if ! generate_ssl_certificates; then
            exit 1
        fi
        ;;
    
    install-ca)
        if ! install_ca_certificates; then
            exit 1
        fi
        ;;
    
    enable)
        if ! enable_ssl; then
            exit 1
        fi
        ;;
    
    disable)
        disable_ssl
        ;;
    
    status)
        show_ssl_status
        ;;
    
    renew)
        if ! renew_certificates; then
            exit 1
        fi
        ;;
    
    *)
        echo -e "${RED}Unknown action: $ACTION${NC}"
        exit 1
        ;;
esac

echo -e "${CYAN}==================================================================${NC}"
