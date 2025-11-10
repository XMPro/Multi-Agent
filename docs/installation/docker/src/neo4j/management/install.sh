#!/bin/bash
# =================================================================
# Neo4j Graph Database Installation Script (Linux)
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
USERNAME="neo4j"
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
    echo "  -u, --username USER    Neo4j username (default: neo4j)"
    echo "  -p, --password PASS    Neo4j password (will prompt if not provided)"
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

# Ensure we're in the neo4j directory
CURRENT_DIR=$(basename "$(pwd)")
if [ "$CURRENT_DIR" = "management" ]; then
    cd ..
    print_color "$GRAY" "Changed from management directory to neo4j directory"
elif [ -d "management" ]; then
    print_color "$GRAY" "Already in neo4j directory"
else
    print_color "$YELLOW" "Warning: Current directory may not be correct for Neo4j installation"
fi

print_color "$CYAN" "=================================================================="
print_color "$CYAN" "Neo4j Graph Database Installation Script"
print_color "$CYAN" "=================================================================="

# Check Docker
echo "Checking Docker availability..."
if ! command -v docker &> /dev/null; then
    print_color "$RED" "Docker is not installed!"
    exit 1
fi

if ! docker version &> /dev/null; then
    print_color "$RED" "Docker is not running!"
    print_color "$YELLOW" "Start Docker: sudo service docker start (WSL2) or sudo systemctl start docker"
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
echo "Checking existing Neo4j containers..."
if docker-compose ps 2>/dev/null | grep -q "neo4j.*Up"; then
    print_color "$YELLOW" "Neo4j container is already running"
    read -p "Stop existing container to reconfigure? (y/n): " stop_choice
    if [[ "$stop_choice" =~ ^[Yy]$ ]]; then
        echo "Stopping existing Neo4j container..."
        docker-compose down
        print_color "$GREEN" "Container stopped"
    else
        print_color "$YELLOW" "Installation cancelled"
        exit 0
    fi
else
    print_color "$GREEN" "No existing Neo4j containers found"
fi

# Create directory structure
echo "Creating directory structure..."
DIRECTORIES=(
    "neo4j-data"
    "neo4j-data/data"
    "neo4j-data/logs"
    "neo4j-data/plugins"
    "neo4j-data/import"
    "neo4j-data/backups"
    "init-scripts"
    "updates"
    "updates/processed"
    "certs"
    "certs/bolt"
    "certs/https"
    "certs/bolt/trusted"
    "certs/https/trusted"
)

for dir in "${DIRECTORIES[@]}"; do
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        print_color "$GREEN" "Created directory: $dir"
    else
        print_color "$GRAY" "Directory exists: $dir"
    fi
done

# Ask about SSL if not specified
if [ "$ENABLE_SSL" = false ]; then
    echo "SSL Configuration:"
    read -p "Enable SSL/TLS encryption for Neo4j? (y/n): " ssl_choice
    if [[ "$ssl_choice" =~ ^[Yy]$ ]]; then
        ENABLE_SSL=true
    fi
fi

if [ "$ENABLE_SSL" = true ]; then
    print_color "$GREEN" "SSL will be enabled for both Browser UI (HTTPS) and Bolt protocol (TLS)"
    
    # Ask for domain if not provided
    if [ "$DOMAIN" = "localhost" ]; then
        read -p "Enter domain name for SSL certificate (default: localhost): " domain_input
        if [ -n "$domain_input" ]; then
            DOMAIN="$domain_input"
        fi
    fi
    print_color "$CYAN" "SSL certificates will be generated for domain: $DOMAIN"
fi

# Generate or prompt for password
if [ -z "$PASSWORD" ]; then
    echo "Password Setup:"
    read -p "Generate secure password automatically? (y/n): " pass_choice
    
    if [[ "$pass_choice" =~ ^[Yy]$ ]] || [ -z "$pass_choice" ]; then
        echo "Generating secure password..."
        PASSWORD=$(openssl rand -base64 15 | tr -dc 'A-Za-z0-9' | head -c 20)
        print_color "$GREEN" "Generated password for user '$USERNAME': $PASSWORD"
    else
        read -s -p "Enter password for user '$USERNAME': " PASSWORD
        echo
        if [ -z "$PASSWORD" ]; then
            print_color "$RED" "Password cannot be empty!"
            exit 1
        fi
    fi
else
    print_color "$GRAY" "Using provided password for user '$USERNAME'"
fi

# Create .env file
echo "Creating configuration files..."
if [ "$ENABLE_SSL" = true ]; then
    NEO4J_URI="bolt+s://neo4j:7687"
else
    NEO4J_URI="bolt://neo4j:7687"
fi

cat > .env << EOF
# Neo4j Authentication
NEO4J_USER=$USERNAME
NEO4J_PASSWORD=$PASSWORD

# Connection Configuration
NEO4J_URI=$NEO4J_URI

# SSL Configuration
ENABLE_SSL=$ENABLE_SSL
SSL_DOMAIN=$DOMAIN

# Neo4j Ports
NEO4J_HTTP_PORT=7474
NEO4J_HTTPS_PORT=7473
NEO4J_BOLT_PORT=7687

# Memory Configuration
NEO4J_HEAP_INITIAL_SIZE=2G
NEO4J_HEAP_MAX_SIZE=4G
NEO4J_PAGECACHE_SIZE=2G

# Timezone
TZ=UTC
EOF

print_color "$GREEN" "Created .env file with configuration"

# Set permissions
echo "Setting directory permissions..."
chmod -R 777 neo4j-data updates init-scripts 2>/dev/null || true
print_color "$GREEN" "Directory permissions configured"

# SSL Certificate setup
if [ "$ENABLE_SSL" = true ]; then
    echo "Setting up SSL certificates..."
    
    if [ ! -f "certs/bolt/private.key" ] || [ "$FORCE" = true ]; then
        echo "Generating SSL certificates for Neo4j..."
        
        # Generate CA
        docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine/openssl genrsa -out ca.key 4096
        docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine/openssl req -new -x509 -days 365 -key ca.key -out ca.crt -subj "/C=US/ST=State/L=City/O=Neo4j-Database/CN=Neo4j-CA"
        
        # Build SAN list
        SAN_LIST="DNS:$DOMAIN,DNS:localhost,DNS:127.0.0.1,DNS:neo4j,IP:127.0.0.1,IP:::1"
        
        # Generate Bolt certificates
        print_color "$GRAY" "Generating Bolt protocol certificates..."
        docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine/openssl genrsa -out bolt_private.key 4096
        docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine/openssl req -new -key bolt_private.key -out bolt.csr -subj "/C=US/ST=State/L=City/O=Neo4j-Database/CN=$DOMAIN" -addext "subjectAltName=$SAN_LIST"
        docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine/openssl x509 -req -in bolt.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out bolt_public.crt -days 365 -copy_extensions copy
        
        # Generate HTTPS certificates
        print_color "$GRAY" "Generating HTTPS certificates..."
        docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine/openssl genrsa -out https_private.key 4096
        docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine/openssl req -new -key https_private.key -out https.csr -subj "/C=US/ST=State/L=City/O=Neo4j-Database/CN=$DOMAIN" -addext "subjectAltName=$SAN_LIST"
        docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine/openssl x509 -req -in https.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out https_public.crt -days 365 -copy_extensions copy
        
        # Move certificates
        docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine sh -c "
            mv bolt_private.key bolt/private.key &&
            mv bolt_public.crt bolt/public.crt &&
            cp ca.crt bolt/trusted/ca.crt &&
            mv https_private.key https/private.key &&
            mv https_public.crt https/public.crt &&
            cp ca.crt https/trusted/ca.crt &&
            rm -f *.csr ca.srl
        "
        
        if [ -f "certs/bolt/private.key" ] && [ -f "certs/bolt/public.crt" ]; then
            print_color "$GREEN" "SSL certificates generated successfully"
        else
            print_color "$RED" "Certificate generation failed"
            ENABLE_SSL=false
        fi
    else
        print_color "$GRAY" "SSL certificates already exist"
    fi
fi

# Update docker-compose.yml with SSL configuration if enabled
if [ "$ENABLE_SSL" = true ]; then
    echo "Updating Docker Compose configuration for SSL..."
    
    # Add HTTPS port if not present
    if ! grep -q "7473:7473" docker-compose.yml; then
        sed -i '/7474:7474/a\      - "7473:7473"   # HTTPS Browser UI' docker-compose.yml
    fi
    
    # Add SSL certificate volumes if not present
    if ! grep -q "certificates" docker-compose.yml; then
        sed -i '/neo4j-data\/import/a\      - ./certs:/var/lib/neo4j/certificates' docker-compose.yml
    fi
    
    # Add SSL environment variables
    if ! grep -q "NEO4J_server_https_enabled" docker-compose.yml; then
        cat >> docker-compose.yml << 'EOF'

      # SSL Configuration
      - NEO4J_server_https_enabled=true
      - NEO4J_server_http_enabled=false
      - NEO4J_server_bolt_tls__level=REQUIRED
      - NEO4J_dbms_ssl_policy_bolt_enabled=true
      - NEO4J_dbms_ssl_policy_bolt_base__directory=certificates/bolt
      - NEO4J_dbms_ssl_policy_bolt_private__key=private.key
      - NEO4J_dbms_ssl_policy_bolt_public__certificate=public.crt
      - NEO4J_dbms_ssl_policy_bolt_client__auth=NONE
      - NEO4J_dbms_ssl_policy_https_enabled=true
      - NEO4J_dbms_ssl_policy_https_base__directory=certificates/https
      - NEO4J_dbms_ssl_policy_https_private__key=private.key
      - NEO4J_dbms_ssl_policy_https_public__certificate=public.crt
      - NEO4J_dbms_ssl_policy_https_client__auth=NONE
EOF
    fi
    
    # Update watcher to use SSL
    sed -i 's|NEO4J_URI=bolt://neo4j:7687|NEO4J_URI=bolt+s://neo4j:7687|' docker-compose.yml
    
    print_color "$GREEN" "Docker Compose configuration updated for SSL"
fi

# Create README files
cat > init-scripts/README.md << 'EOF'
# Neo4j Initialization Scripts

Place `.cypher` files here to execute on first startup.
Scripts execute in alphabetical order.
EOF

cat > updates/README.md << 'EOF'
# Neo4j Updates Directory

Drop `.cypher` files here for automatic execution.
Files are processed once and moved to `processed/` directory.
Monitor with: `docker-compose logs neo4j-watcher`
EOF

print_color "$GREEN" "Cypher scripts system initialized"

# Test configuration
echo "Testing configuration..."
if docker-compose config > /dev/null 2>&1; then
    print_color "$GREEN" "Docker Compose configuration is valid"
else
    print_color "$RED" "Docker Compose configuration has errors!"
    exit 1
fi

# Summary
print_color "$CYAN" "=================================================================="
print_color "$CYAN" "Installation Summary:"
print_color "$CYAN" "=================================================================="
print_color "$GREEN" "Directory structure created"
print_color "$GREEN" "Authentication configured"
print_color "$GREEN" "Permissions set"
[ "$ENABLE_SSL" = true ] && print_color "$GREEN" "SSL certificates generated"
print_color "$GREEN" "Configuration validated"
echo ""
print_color "$CYAN" "Neo4j Database Details:"
echo "  Username: $USERNAME"
print_color "$YELLOW" "  Password: $PASSWORD"
if [ "$ENABLE_SSL" = true ]; then
    echo "  Browser UI: https://localhost:7473 (HTTPS)"
    echo "  Bolt URI: bolt+s://localhost:7687 (TLS)"
else
    echo "  Browser UI: http://localhost:7474 (HTTP)"
    echo "  Bolt URI: bolt://localhost:7687"
fi
echo ""
print_color "$GREEN" "Installation completed successfully!"
print_color "$CYAN" "=================================================================="

# Ask to start (only if not in force mode - stack installer will start services)
if [ "$FORCE" = false ]; then
    echo ""
    read -p "Start Neo4j database now? (y/n): " start_choice
    if [[ "$start_choice" =~ ^[Yy]$ ]] || [ -z "$start_choice" ]; then
        print_color "$GREEN" "Starting Neo4j database..."
        docker-compose up -d
        
        if [ $? -eq 0 ]; then
            print_color "$GREEN" "Neo4j database started successfully!"
            echo "Waiting for initialization (60-90 seconds)..."
            sleep 30
            
            if docker-compose ps | grep -q "neo4j.*Up"; then
                print_color "$GREEN" "[OK] Neo4j is running!"
                if [ "$ENABLE_SSL" = true ]; then
                    print_color "$GREEN" "[OK] Access at: https://localhost:7473"
                else
                    print_color "$GREEN" "[OK] Access at: http://localhost:7474"
                fi
            fi
        fi
    else
        print_color "$GRAY" "Neo4j not started (will be started by stack installer)"
    fi
    [ -d "management" ] && cd management
else
    print_color "$GRAY" "Configuration complete (stack installer will start services)"
fi

# Always exit successfully if we got this far
exit 0
