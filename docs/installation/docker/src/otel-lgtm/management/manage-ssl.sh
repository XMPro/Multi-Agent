#!/bin/bash
# =================================================================
# OTEL LGTM SSL Certificate Management Script for Linux
# Description: Generate and manage SSL/TLS certificates for Grafana Nginx reverse proxy
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

# Ensure we're in the otel-lgtm directory (not management subdirectory)
if [[ $(basename "$PWD") == "management" ]]; then
    cd ..
fi

echo -e "${CYAN}==================================================================${NC}"
echo -e "${CYAN}OTEL LGTM SSL Certificate Management${NC}"
echo -e "${CYAN}==================================================================${NC}"
echo ""

# Show help if no action provided
if [ -z "$ACTION" ]; then
    echo -e "${GRAY}Usage: ./manage-ssl.sh <action> [options]${NC}"
    echo ""
    echo -e "${CYAN}Actions:${NC}"
    echo -e "${GRAY}  generate      Generate new self-signed SSL certificates${NC}"
    echo -e "${GRAY}  install-ca    Install CA-provided SSL certificates${NC}"
    echo -e "${GRAY}  enable        Enable SSL (start grafana-nginx-ssl service)${NC}"
    echo -e "${GRAY}  disable       Disable SSL (stop grafana-nginx-ssl service)${NC}"
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
    echo -e "${GRAY}  ./manage-ssl.sh generate${NC}"
    echo -e "${GRAY}  ./manage-ssl.sh generate --domain grafana.company.com --valid-days 730${NC}"
    echo -e "${GRAY}  ./manage-ssl.sh install-ca --server-cert /path/to/server.crt --server-key /path/to/server.key${NC}"
    echo -e "${GRAY}  ./manage-ssl.sh enable${NC}"
    echo -e "${GRAY}  ./manage-ssl.sh status${NC}"
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

    if [ ! -d "certs" ]; then
        mkdir -p certs
    fi

    if [ -f "certs/server.crt" ] && [ "$FORCE" = false ]; then
        echo -e "${YELLOW}⚠ Certificates already exist!${NC}"
        read -p "Overwrite existing certificates? (y/n): " overwrite
        if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Certificate generation cancelled${NC}"
            return 1
        fi
    fi

    echo -e "${GRAY}Detecting machine IP addresses...${NC}"
    MACHINE_IPS=($(get_machine_ips))

    if [ ${#MACHINE_IPS[@]} -gt 0 ]; then
        echo -e "${GRAY}Detected IPs:${NC}"
        for ip in "${MACHINE_IPS[@]}"; do
            echo -e "${GRAY}  • $ip${NC}"
        done
    fi

    echo ""
    echo -e "${GRAY}Generating CA certificate...${NC}"
    docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine/openssl genrsa -out ca.key 4096 2>/dev/null
    docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine/openssl req -new -x509 -days $VALID_DAYS -key ca.key -out ca.crt -subj "/C=US/ST=State/L=City/O=OTEL-LGTM/CN=OTEL-LGTM-CA" 2>/dev/null

    echo -e "${GRAY}Generating server certificate...${NC}"
    docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine/openssl genrsa -out server.key 4096 2>/dev/null

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

    docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine/openssl req -new -key server.key -out server.csr -subj "/C=US/ST=State/L=City/O=OTEL-LGTM/CN=$DOMAIN" -config openssl.cnf 2>/dev/null
    docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine/openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days $VALID_DAYS -extensions v3_req -extfile openssl.cnf 2>/dev/null

    rm -f certs/server.csr certs/ca.srl certs/openssl.cnf

    if [ -f "certs/server.crt" ] && [ -f "certs/server.key" ] && [ -f "certs/ca.crt" ]; then
        echo -e "${GREEN}✓ SSL certificates generated successfully!${NC}"
        echo -e "${CYAN}Next steps:${NC}"
        echo -e "${GRAY}  1. Enable SSL: ./management/manage-ssl.sh enable${NC}"
        echo -e "${GRAY}  2. Distribute ca.crt to client machines${NC}"
        return 0
    else
        echo -e "${RED}✗ Certificate files not created properly${NC}"
        return 1
    fi
}

# Install CA-provided certificates
install_ca_certificates() {
    echo -e "${GRAY}Installing CA-provided SSL certificates...${NC}"

    if [ ! -d "certs" ]; then
        mkdir -p certs
    fi

    if [ -z "$SERVER_CERT_PATH" ] || [ ! -f "$SERVER_CERT_PATH" ]; then
        echo -e "${RED}✗ Server certificate file not found: $SERVER_CERT_PATH${NC}"
        return 1
    fi
    if [ -z "$SERVER_KEY_PATH" ] || [ ! -f "$SERVER_KEY_PATH" ]; then
        echo -e "${RED}✗ Server private key file not found: $SERVER_KEY_PATH${NC}"
        return 1
    fi

    cp "$SERVER_CERT_PATH" certs/server.crt
    cp "$SERVER_KEY_PATH" certs/server.key
    echo -e "${GREEN}✓ Server certificates installed${NC}"

    [ -n "$CA_CERT_PATH" ] && [ -f "$CA_CERT_PATH" ] && cp "$CA_CERT_PATH" certs/ca.crt && echo -e "${GREEN}✓ CA certificate installed${NC}"
    [ -n "$CA_KEY_PATH" ] && [ -f "$CA_KEY_PATH" ] && cp "$CA_KEY_PATH" certs/ca.key && echo -e "${GREEN}✓ CA private key installed${NC}"

    echo -e "${GREEN}✓ CA-provided certificates installed successfully!${NC}"
    echo -e "${GRAY}  Next: ./management/manage-ssl.sh enable${NC}"
    return 0
}

# Enable SSL
enable_ssl() {
    if [ ! -f "certs/server.crt" ] || [ ! -f "certs/server.key" ]; then
        echo -e "${RED}✗ SSL certificates not found!${NC}"
        echo -e "${GRAY}  Generate: ./management/manage-ssl.sh generate${NC}"
        return 1
    fi

    if [ -f ".env" ]; then
        if grep -q "COMPOSE_PROFILES=" .env; then
            sed -i 's/COMPOSE_PROFILES=.*/COMPOSE_PROFILES=ssl/' .env
        else
            echo "COMPOSE_PROFILES=ssl" >> .env
        fi
        sed -i 's/OTEL_LGTM_ENABLE_SSL=.*/OTEL_LGTM_ENABLE_SSL=true/' .env
    fi

    docker-compose up -d grafana-nginx-ssl 2>&1 > /dev/null
    sleep 3

    if docker-compose ps 2>/dev/null | grep -q "grafana-nginx-ssl.*running"; then
        HTTPS_PORT="3443"
        [ -f ".env" ] && HTTPS_PORT=$(grep "GRAFANA_HTTPS_PORT=" .env | cut -d'=' -f2)
        echo -e "${GREEN}✓ SSL/TLS enabled! HTTPS: https://localhost:$HTTPS_PORT${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to start grafana-nginx-ssl${NC}"
        return 1
    fi
}

# Disable SSL
disable_ssl() {
    docker-compose stop grafana-nginx-ssl 2>&1 > /dev/null
    if [ -f ".env" ]; then
        sed -i 's/COMPOSE_PROFILES=ssl/# COMPOSE_PROFILES=ssl/' .env
        sed -i 's/OTEL_LGTM_ENABLE_SSL=true/OTEL_LGTM_ENABLE_SSL=false/' .env
    fi
    echo -e "${GREEN}✓ SSL/TLS disabled${NC}"
}

# Show SSL status
show_ssl_status() {
    echo -e "${CYAN}SSL/TLS Status${NC}"
    echo ""

    echo -e "${CYAN}Service Status:${NC}"
    if docker-compose ps 2>/dev/null | grep -q "otel-lgtm.*running"; then
        echo -e "${GREEN}  ✓ otel-lgtm: Running${NC}"
    else
        echo -e "${RED}  ✗ otel-lgtm: Stopped${NC}"
    fi

    if docker-compose ps 2>/dev/null | grep -q "grafana-nginx-ssl.*running"; then
        echo -e "${GREEN}  ✓ grafana-nginx-ssl: Running${NC}"
    elif docker-compose ps 2>/dev/null | grep -q "grafana-nginx-ssl"; then
        echo -e "${RED}  ✗ grafana-nginx-ssl: Stopped${NC}"
    else
        echo -e "${GRAY}  grafana-nginx-ssl: Not configured${NC}"
    fi

    echo ""
    echo -e "${CYAN}Certificate Files:${NC}"
    for file in certs/ca.crt certs/server.crt certs/server.key; do
        if [ -f "$file" ]; then
            echo -e "${GREEN}  ✓ $file${NC}"
        else
            echo -e "${RED}  ✗ $file (not found)${NC}"
        fi
    done

    if [ -f "certs/server.crt" ]; then
        echo ""
        echo -e "${CYAN}Server Certificate Details:${NC}"
        docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine/openssl x509 -noout -subject -issuer -dates -in server.crt 2>/dev/null
    fi
    echo ""
}

# Renew certificates
renew_certificates() {
    if [ ! -f "certs/server.crt" ]; then
        echo -e "${RED}✗ No existing certificates to renew${NC}"
        return 1
    fi

    BACKUP_DIR="certs/backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    cp certs/*.crt "$BACKUP_DIR/" 2>/dev/null
    cp certs/*.key "$BACKUP_DIR/" 2>/dev/null
    echo -e "${GREEN}✓ Backed up to: $BACKUP_DIR${NC}"

    CERT_SUBJECT=$(docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine/openssl x509 -noout -subject -in server.crt 2>/dev/null)
    if [[ $CERT_SUBJECT =~ CN[[:space:]]*=[[:space:]]*([^,]+) ]]; then
        DOMAIN="${BASH_REMATCH[1]}"
        DOMAIN=$(echo "$DOMAIN" | xargs)
    fi

    if generate_ssl_certificates; then
        if docker-compose ps 2>/dev/null | grep -q "grafana-nginx-ssl.*running"; then
            docker-compose restart grafana-nginx-ssl 2>&1 > /dev/null
            echo -e "${GREEN}✓ grafana-nginx-ssl restarted${NC}"
        fi
        echo -e "${GREEN}✓ Certificates renewed successfully!${NC}"
        return 0
    fi
    return 1
}

# Main logic
if ! check_docker; then
    exit 1
fi

case $ACTION in
    generate)    generate_ssl_certificates || exit 1 ;;
    install-ca)  install_ca_certificates || exit 1 ;;
    enable)      enable_ssl || exit 1 ;;
    disable)     disable_ssl ;;
    status)      show_ssl_status ;;
    renew)       renew_certificates || exit 1 ;;
    *)           echo -e "${RED}Unknown action: $ACTION${NC}"; exit 1 ;;
esac

echo -e "${CYAN}==================================================================${NC}"
