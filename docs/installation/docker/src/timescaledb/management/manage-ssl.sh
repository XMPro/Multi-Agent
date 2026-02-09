#!/bin/bash
# =================================================================
# TimescaleDB SSL Management Script (Linux)
# Production-Grade SSL/TLS Configuration
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
ENABLE=false
DISABLE=false
DOMAIN="localhost"
FORCE=false
VALIDITY_DAYS=365

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
    echo "  --enable               Enable SSL/TLS encryption"
    echo "  --disable              Disable SSL/TLS encryption"
    echo "  --domain DOMAIN        Domain for SSL certificate (default: localhost)"
    echo "  --force                Force certificate regeneration"
    echo "  --validity-days DAYS   Certificate validity in days (default: 365)"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  Enable SSL:  $0 --enable --domain example.com"
    echo "  Disable SSL: $0 --disable"
    echo "  Regenerate:  $0 --enable --force"
    echo ""
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --enable)
            ENABLE=true
            shift
            ;;
        --disable)
            DISABLE=true
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
        --validity-days)
            VALIDITY_DAYS="$2"
            shift 2
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

# Ensure we're in the timescaledb directory
CURRENT_DIR=$(basename "$(pwd)")
if [ "$CURRENT_DIR" = "management" ]; then
    cd ..
fi

print_color "$CYAN" "=================================================================="
print_color "$CYAN" "TimescaleDB SSL Management"
print_color "$CYAN" "=================================================================="

if [ "$ENABLE" = false ] && [ "$DISABLE" = false ]; then
    print_color "$RED" "Error: You must specify either --enable or --disable"
    echo ""
    print_color "$CYAN" "Usage:"
    print_color "$GRAY" "  Enable SSL:  $0 --enable [--domain <domain>]"
    print_color "$GRAY" "  Disable SSL: $0 --disable"
    exit 1
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
    
    # Detect machine IP addresses for SAN
    echo "Detecting machine IP addresses..."
    MACHINE_IP=""
    if command -v ip &> /dev/null; then
        IPS=($(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '^127\.'))
        if [ ${#IPS[@]} -gt 0 ]; then
            print_color "$GREEN" "Detected IP addresses:"
            for i in "${!IPS[@]}"; do
                echo "  [$i] ${IPS[$i]}"
            done
            
            echo ""
            read -p "Enter IP numbers to include (comma-separated, e.g., '0,1') or press Enter to skip: " ip_choice
            
            if [ -n "$ip_choice" ]; then
                IFS=',' read -ra INDICES <<< "$ip_choice"
                SELECTED_IPS=()
                for idx in "${INDICES[@]}"; do
                    idx=$(echo "$idx" | xargs)
                    if [[ "$idx" =~ ^[0-9]+$ ]] && [ "$idx" -lt "${#IPS[@]}" ]; then
                        SELECTED_IPS+=("${IPS[$idx]}")
                    fi
                done
                
                if [ ${#SELECTED_IPS[@]} -gt 0 ]; then
                    MACHINE_IP=$(IFS=,; echo "${SELECTED_IPS[*]}")
                    print_color "$CYAN" "Selected IPs: $MACHINE_IP"
                fi
            fi
        fi
    fi
    
    # Generate CA private key
    print_color "$GRAY" "Generating CA private key..."
    docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine/openssl genrsa -out ca.key 4096 2>/dev/null
    
    # Generate CA certificate
    print_color "$GRAY" "Generating CA certificate..."
    docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine/openssl req -new -x509 -days "$VALIDITY_DAYS" -key ca.key -out ca.crt -subj "/C=US/ST=State/L=City/O=TimescaleDB/CN=TimescaleDB-CA" 2>/dev/null
    
    # Generate server private key
    print_color "$GRAY" "Generating server private key..."
    docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine/openssl genrsa -out temp_server.key 4096 2>/dev/null
    
    # Build SAN list
    SAN_LIST="DNS:$DOMAIN,DNS:localhost,DNS:127.0.0.1,DNS:timescaledb,IP:127.0.0.1,IP:::1"
    if [ -n "$MACHINE_IP" ]; then
        IFS=',' read -ra IP_ARRAY <<< "$MACHINE_IP"
        for ip in "${IP_ARRAY[@]}"; do
            SAN_LIST="$SAN_LIST,IP:$ip"
        done
    fi
    
    # Generate server CSR with SAN
    print_color "$GRAY" "Generating server CSR..."
    docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine/openssl req -new -key temp_server.key -out temp_server.csr -subj "/C=US/ST=State/L=City/O=TimescaleDB/CN=$DOMAIN" -addext "subjectAltName=$SAN_LIST" 2>/dev/null
    
    # Sign server certificate
    print_color "$GRAY" "Signing server certificate..."
    docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine/openssl x509 -req -in temp_server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out temp_server.crt -days "$VALIDITY_DAYS" -copy_extensions copy 2>/dev/null
    
    # Move temp files to final names and set permissions
    docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine sh -c "mv temp_server.key server.key && mv temp_server.crt server.crt && chmod 600 server.key && chmod 644 server.crt ca.crt && rm -f temp_server.csr ca.srl ca.key" 2>/dev/null
    
    echo ""
    print_color "$GREEN" "SSL certificates generated successfully!"
    echo ""
    print_color "$CYAN" "Certificate Details:"
    print_color "$GRAY" "  CA Certificate: certs/ca.crt"
    print_color "$GRAY" "  Server Certificate: certs/server.crt"
    print_color "$GRAY" "  Server Key: certs/server.key"
    print_color "$GRAY" "  Domain: $DOMAIN"
    print_color "$GRAY" "  Valid for: $VALIDITY_DAYS days"
    
    # Update .env file
    if [ -f ".env" ]; then
        sed -i 's/ENABLE_SSL=false/ENABLE_SSL=true/g' .env
        sed -i "s/SSL_DOMAIN=.*/SSL_DOMAIN=$DOMAIN/g" .env
        echo ""
        print_color "$GREEN" "Updated .env file with SSL settings"
    fi
    
    # Update postgresql.conf
    if [ -f "config/postgresql.conf" ]; then
        sed -i 's/ssl = off/ssl = on/g' config/postgresql.conf
        sed -i "s|# ssl_cert_file not configured (SSL disabled)|ssl_cert_file = '/var/lib/postgresql/certs/server.crt'|g" config/postgresql.conf
        sed -i "s|# ssl_key_file not configured (SSL disabled)|ssl_key_file = '/var/lib/postgresql/certs/server.key'|g" config/postgresql.conf
        sed -i "s|# ssl_ca_file not configured (SSL disabled)|ssl_ca_file = '/var/lib/postgresql/certs/ca.crt'|g" config/postgresql.conf
        sed -i "s|# ssl_min_protocol_version not configured (SSL disabled)|ssl_min_protocol_version = 'TLSv1.2'|g" config/postgresql.conf
        print_color "$GREEN" "Updated postgresql.conf with SSL settings"
    fi
    
    # Update nginx.conf for pgAdmin
    if [ -f "pgadmin/nginx.conf" ]; then
        # Check if it's already HTTPS config
        if ! grep -q "listen 443 ssl" pgadmin/nginx.conf; then
            cat > pgadmin/nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    upstream pgadmin {
        server pgadmin:80;
    }

    # Redirect HTTP to HTTPS
    server {
        listen 80;
        server_name DOMAIN_PLACEHOLDER;
        # Use explicit domain and port to preserve in redirect
        return 301 https://DOMAIN_PLACEHOLDER:5051$request_uri;
    }

    # HTTPS server
    server {
        listen 443 ssl;
        server_name DOMAIN_PLACEHOLDER;

        ssl_certificate /etc/nginx/ssl/server.crt;
        ssl_certificate_key /etc/nginx/ssl/server.key;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers HIGH:!aNULL:!MD5;
        ssl_prefer_server_ciphers on;

        location / {
            proxy_pass http://pgadmin;
            # Use $http_host to preserve port in Host header
            proxy_set_header Host $http_host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            # Force https scheme for pgAdmin redirects
            proxy_set_header X-Forwarded-Proto https;
            proxy_set_header X-Script-Name /;
            # Disable proxy redirect rewriting
            proxy_redirect off;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
        }
    }
}
EOF
            sed -i "s/DOMAIN_PLACEHOLDER/$DOMAIN/g" pgadmin/nginx.conf
            print_color "$GREEN" "Updated nginx.conf for HTTPS"
        fi
    fi
    
    echo ""
    print_color "$CYAN" "Next Steps:"
    print_color "$GRAY" "  1. Restart the database: docker-compose restart"
    print_color "$GRAY" "  2. Connect with SSL: psql 'postgresql://user:pass@localhost:5432/db?sslmode=require'"
    print_color "$GRAY" "  3. Access pgAdmin: https://localhost:5051"
    print_color "$GRAY" "  4. Distribute ca.crt to client machines for trusted connections"
    
elif [ "$DISABLE" = true ]; then
    echo ""
    echo "Disabling SSL/TLS..."
    
    # Update .env file
    if [ -f ".env" ]; then
        sed -i 's/ENABLE_SSL=true/ENABLE_SSL=false/g' .env
        print_color "$GREEN" "Updated .env file"
    fi
    
    # Update postgresql.conf
    if [ -f "config/postgresql.conf" ]; then
        sed -i 's/ssl = on/ssl = off/g' config/postgresql.conf
        sed -i "s|ssl_cert_file = '/var/lib/postgresql/certs/server.crt'|# ssl_cert_file not configured (SSL disabled)|g" config/postgresql.conf
        sed -i "s|ssl_key_file = '/var/lib/postgresql/certs/server.key'|# ssl_key_file not configured (SSL disabled)|g" config/postgresql.conf
        sed -i "s|ssl_ca_file = '/var/lib/postgresql/certs/ca.crt'|# ssl_ca_file not configured (SSL disabled)|g" config/postgresql.conf
        sed -i "s|ssl_min_protocol_version = 'TLSv1.2'|# ssl_min_protocol_version not configured (SSL disabled)|g" config/postgresql.conf
        print_color "$GREEN" "Updated postgresql.conf"
    fi
    
    # Update nginx.conf for pgAdmin to HTTP only
    if [ -f "pgadmin/nginx.conf" ]; then
        cat > pgadmin/nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    upstream pgadmin {
        server pgadmin:80;
    }

    server {
        listen 80;
        server_name DOMAIN_PLACEHOLDER;

        location / {
            proxy_pass http://pgadmin;
            # Use $http_host to preserve port in Host header
            proxy_set_header Host $http_host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Script-Name /;
            # Disable proxy redirect rewriting
            proxy_redirect off;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
        }
    }
}
EOF
        sed -i "s/DOMAIN_PLACEHOLDER/$DOMAIN/g" pgadmin/nginx.conf
        print_color "$GREEN" "Updated nginx.conf for HTTP"
    fi
    
    echo ""
    print_color "$GREEN" "SSL/TLS disabled successfully!"
    echo ""
    print_color "$CYAN" "Next Steps:"
    print_color "$GRAY" "  1. Restart the database: docker-compose restart"
    print_color "$GRAY" "  2. Connect without SSL: psql -h localhost -U postgres -d timescaledb"
    print_color "$GRAY" "  3. Access pgAdmin: http://localhost:5050"
fi

echo ""
print_color "$CYAN" "=================================================================="

exit 0
