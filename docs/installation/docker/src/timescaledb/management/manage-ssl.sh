#!/bin/bash
# =================================================================
# TimescaleDB SSL Management Script (Bash)
# Production-Grade SSL/TLS Configuration
# =================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m'

ENABLE=false
DISABLE=false
DOMAIN="localhost"
FORCE=false
VALIDITY_DAYS=365

print_color() {
    local color=$1
    shift
    echo -e "${color}$@${NC}"
}

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --enable                 Enable SSL/TLS"
    echo "  --disable                Disable SSL/TLS"
    echo "  --domain DOMAIN          Domain for SSL certificates (default: localhost)"
    echo "  --force                  Force recreation of certificates"
    echo "  --validity DAYS          Certificate validity in days (default: 365)"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  Enable SSL:  $0 --enable --domain mycompany.local"
    echo "  Disable SSL: $0 --disable"
    exit 0
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --enable) ENABLE=true; shift ;;
        --disable) DISABLE=true; shift ;;
        --domain) DOMAIN="$2"; shift 2 ;;
        --force) FORCE=true; shift ;;
        --validity) VALIDITY_DAYS="$2"; shift 2 ;;
        -h|--help) show_usage ;;
        *) print_color "$RED" "Unknown option: $1"; show_usage ;;
    esac
done

print_color "$CYAN" "=================================================================="
print_color "$CYAN" "TimescaleDB SSL Management"
print_color "$CYAN" "=================================================================="

if [ "$ENABLE" = false ] && [ "$DISABLE" = false ]; then
    print_color "$RED" "Error: You must specify either --enable or --disable"
    show_usage
fi

# Create certs directory if it doesn't exist
mkdir -p certs

if [ "$ENABLE" = true ]; then
    echo ""
    echo "Enabling SSL/TLS..."
    print_color "$GRAY" "Domain: $DOMAIN"
    print_color "$GRAY" "Validity: $VALIDITY_DAYS days"
    
    # Check if certificates already exist
    if [ -f "certs/server.crt" ] && [ "$FORCE" = false ]; then
        echo ""
        print_color "$YELLOW" "SSL certificates already exist!"
        read -p "Recreate certificates? (y/n): " recreate
        if [[ ! "$recreate" =~ ^[Yy]$ ]]; then
            print_color "$GREEN" "Using existing certificates"
            exit 0
        fi
    fi
    
    echo ""
    echo "Generating SSL certificates..."
    
    # Check if OpenSSL is available
    if ! command -v openssl >/dev/null 2>&1; then
        print_color "$RED" "Error: OpenSSL is not installed"
        print_color "$YELLOW" "Please install OpenSSL:"
        print_color "$GRAY" "  Ubuntu/Debian: sudo apt-get install openssl"
        print_color "$GRAY" "  RHEL/CentOS: sudo yum install openssl"
        print_color "$GRAY" "  macOS: brew install openssl"
        exit 1
    fi
    
    # Generate CA private key
    print_color "$GRAY" "Generating CA private key..."
    openssl genrsa -out certs/ca.key 4096 2>/dev/null
    
    # Generate CA certificate
    print_color "$GRAY" "Generating CA certificate..."
    openssl req -new -x509 -days "$VALIDITY_DAYS" -key certs/ca.key -out certs/ca.crt \
        -subj "/C=US/ST=State/L=City/O=Organization/OU=IT/CN=TimescaleDB-CA" 2>/dev/null
    
    # Generate server private key
    print_color "$GRAY" "Generating server private key..."
    openssl genrsa -out certs/server.key 4096 2>/dev/null
    
    # Generate server certificate signing request
    print_color "$GRAY" "Generating server CSR..."
    openssl req -new -key certs/server.key -out certs/server.csr \
        -subj "/C=US/ST=State/L=City/O=Organization/OU=IT/CN=$DOMAIN" 2>/dev/null
    
    # Create OpenSSL config for SAN
    cat > certs/openssl.cnf << EOF
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = State
L = City
O = Organization
OU = IT
CN = $DOMAIN

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = $DOMAIN
DNS.2 = localhost
IP.1 = 127.0.0.1
EOF
    
    # Sign server certificate with CA
    print_color "$GRAY" "Signing server certificate..."
    openssl x509 -req -in certs/server.csr -CA certs/ca.crt -CAkey certs/ca.key \
        -CAcreateserial -out certs/server.crt -days "$VALIDITY_DAYS" \
        -extensions v3_req -extfile certs/openssl.cnf 2>/dev/null
    
    # Set proper permissions on private keys
    chmod 600 certs/server.key certs/ca.key
    chmod 644 certs/server.crt certs/ca.crt
    
    # Clean up temporary files
    rm -f certs/server.csr certs/openssl.cnf certs/ca.srl
    
    echo ""
    print_color "$GREEN" "SSL certificates generated successfully!"
    echo ""
    echo "Certificate Details:"
    print_color "$GRAY" "  CA Certificate: certs/ca.crt"
    print_color "$GRAY" "  Server Certificate: certs/server.crt"
    print_color "$GRAY" "  Server Key: certs/server.key"
    print_color "$GRAY" "  Domain: $DOMAIN"
    print_color "$GRAY" "  Valid for: $VALIDITY_DAYS days"
    
    # Update .env file
    if [ -f ".env" ]; then
        sed -i.bak 's/ENABLE_SSL=false/ENABLE_SSL=true/' .env
        sed -i.bak "s/DOMAIN=.*/DOMAIN=$DOMAIN/" .env
        rm -f .env.bak
        echo ""
        print_color "$GREEN" "Updated .env file with SSL settings"
    fi
    
    # Update postgresql.conf
    if [ -f "config/postgresql.conf" ]; then
        sed -i.bak 's/ssl = off/ssl = on/' config/postgresql.conf
        rm -f config/postgresql.conf.bak
        print_color "$GREEN" "Updated postgresql.conf with SSL settings"
    fi
    
    echo ""
    echo "Next Steps:"
    print_color "$GRAY" "  1. Restart the database: docker-compose restart"
    print_color "$GRAY" "  2. Connect with SSL: psql 'postgresql://user:pass@localhost:5432/db?sslmode=require'"
    print_color "$GRAY" "  3. Distribute ca.crt to client machines for trusted connections"
    
elif [ "$DISABLE" = true ]; then
    echo ""
    echo "Disabling SSL/TLS..."
    
    # Update .env file
    if [ -f ".env" ]; then
        sed -i.bak 's/ENABLE_SSL=true/ENABLE_SSL=false/' .env
        rm -f .env.bak
        print_color "$GREEN" "Updated .env file"
    fi
    
    # Update postgresql.conf
    if [ -f "config/postgresql.conf" ]; then
        sed -i.bak 's/ssl = on/ssl = off/' config/postgresql.conf
        rm -f config/postgresql.conf.bak
        print_color "$GREEN" "Updated postgresql.conf"
    fi
    
    echo ""
    print_color "$GREEN" "SSL/TLS disabled successfully!"
    echo ""
    echo "Next Steps:"
    print_color "$GRAY" "  1. Restart the database: docker-compose restart"
    print_color "$GRAY" "  2. Connect without SSL: psql -h localhost -U postgres -d timescaledb"
fi

echo ""
print_color "$CYAN" "=================================================================="

exit 0
