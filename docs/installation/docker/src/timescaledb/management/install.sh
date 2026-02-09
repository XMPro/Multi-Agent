#!/bin/bash
# =================================================================
# TimescaleDB Time-Series Database Installation Script (Linux)
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
USERNAME="postgres"
PASSWORD=""
DATABASE_NAME="timescaledb"
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
    echo "  -u, --username USER    PostgreSQL username (default: postgres)"
    echo "  -p, --password PASS    PostgreSQL password (will prompt if not provided)"
    echo "  -d, --database NAME    Database name (default: timescaledb)"
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
        -d|--database)
            DATABASE_NAME="$2"
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

# Ensure we're in the timescaledb directory
CURRENT_DIR=$(basename "$(pwd)")
if [ "$CURRENT_DIR" = "management" ]; then
    cd ..
    print_color "$GRAY" "Changed from management directory to timescaledb directory"
elif [ -d "management" ]; then
    print_color "$GRAY" "Already in timescaledb directory"
else
    print_color "$YELLOW" "Warning: Current directory may not be correct for TimescaleDB installation"
fi

print_color "$CYAN" "=================================================================="
print_color "$CYAN" "TimescaleDB Time-Series Database Installation Script"
print_color "$CYAN" "=================================================================="

# Check Docker
echo "Checking Docker availability..."
if ! command -v docker &> /dev/null || ! docker version &> /dev/null; then
    print_color "$RED" "Docker is not available!"
    print_color "$YELLOW" "Please install Docker and ensure it's running."
    exit 1
fi
print_color "$GREEN" "Docker is available"

# Check Docker Compose
if command -v docker-compose &> /dev/null || docker compose version &> /dev/null; then
    print_color "$GREEN" "Docker Compose is available"
else
    print_color "$RED" "Docker Compose is not available!"
    print_color "$YELLOW" "Please ensure Docker Compose is installed."
    exit 1
fi

# Check existing containers (only if .env exists)
if [ -f ".env" ]; then
    echo "Checking existing TimescaleDB containers..."
    if docker-compose ps 2>/dev/null | grep -q "timescaledb.*Up"; then
        print_color "$YELLOW" "TimescaleDB container is already running"
        read -p "Stop existing container to reconfigure? (y/n): " stop_choice
        if [[ "$stop_choice" =~ ^[Yy]$ ]]; then
            docker-compose down
            print_color "$GREEN" "Container stopped"
        else
            print_color "$YELLOW" "Installation cancelled - container still running"
            exit 0
        fi
    fi
fi

# Create directory structure
echo "Creating directory structure..."
DIRECTORIES=(
    "init"
    "backups"
    "certs"
    "config"
    "pgadmin"
    "timescaledb-data"
    "timescaledb-data/data"
    "timescaledb-data/pgadmin"
)

for dir in "${DIRECTORIES[@]}"; do
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        print_color "$GREEN" "Created directory: $dir"
    else
        print_color "$GRAY" "Directory exists: $dir"
    fi
done

# Ask about backup retention
echo ""
print_color "$CYAN" "Backup Retention Configuration:"
echo "How many days should automated backups be retained?"
print_color "$GRAY" "  7 days   - Minimal retention (development/testing)"
print_color "$GRAY" "  30 days  - Standard production (recommended)"
print_color "$GRAY" "  90 days  - Extended retention (compliance)"
print_color "$GRAY" "  365 days - Long-term retention (regulatory)"
read -p "Enter retention days (default: 30): " retention_choice
if [[ "$retention_choice" =~ ^[0-9]+$ ]]; then
    BACKUP_RETENTION_DAYS=$retention_choice
else
    BACKUP_RETENTION_DAYS=30
fi
print_color "$GREEN" "Backup retention set to: $BACKUP_RETENTION_DAYS days"

# Ask about SSL
if [ "$ENABLE_SSL" = false ]; then
    echo ""
    print_color "$CYAN" "SSL Configuration:"
    read -p "Enable SSL/TLS encryption for TimescaleDB? (y/n): " ssl_choice
    [[ "$ssl_choice" =~ ^[Yy]$ ]] && ENABLE_SSL=true
fi

USE_CA_PROVIDED=false
MACHINE_IP=""

if [ "$ENABLE_SSL" = true ]; then
    print_color "$GREEN" "SSL will be enabled for PostgreSQL connections"
    
    # Ask for certificate type
    echo ""
    print_color "$CYAN" "Certificate Options:"
    print_color "$GRAY" "1. Generate self-signed certificates (for development/testing)"
    print_color "$GRAY" "2. Use CA-provided certificates (for production)"
    read -p "Select certificate type (1 or 2, default: 1): " cert_choice
    
    if [ "$cert_choice" = "2" ]; then
        print_color "$GREEN" "CA-provided certificates selected"
        print_color "$CYAN" "You can install them after setup using: ./management/manage-ssl.sh --enable"
        print_color "$YELLOW" "SSL will be configured but not enabled until certificates are installed"
        ENABLE_SSL=false
        USE_CA_PROVIDED=true
    else
        print_color "$GREEN" "Self-signed certificates selected"
        
        # Ask for domain name
        read -p "Enter domain name for SSL certificate (default: localhost): " domain_choice
        if [ -n "$domain_choice" ]; then
            DOMAIN="$domain_choice"
        fi
        print_color "$CYAN" "SSL certificates will be generated for domain: $DOMAIN"
        
        # Detect machine IP addresses
        echo ""
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
                    else
                        print_color "$GRAY" "No valid IPs selected"
                    fi
                else
                    print_color "$GRAY" "IP addresses not included (localhost/domain only)"
                fi
            else
                print_color "$GRAY" "Could not detect IP addresses, skipping"
            fi
        else
            print_color "$GRAY" "Could not detect IP addresses (ip command not found)"
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
        PASSWORD=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-32)
        print_color "$GREEN" "Generated password for user '$USERNAME': $PASSWORD"
    else
        read -sp "Enter password for user '$USERNAME': " PASSWORD
        echo ""
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
cat > .env << EOF
# =================================================================
# TimescaleDB Environment Configuration
# =================================================================

# Database Configuration
POSTGRES_DB=$DATABASE_NAME
POSTGRES_USER=$USERNAME
POSTGRES_PASSWORD=$PASSWORD
POSTGRES_PORT=5432

# TimescaleDB Settings
TIMESCALEDB_TELEMETRY=off

# SSL Configuration
ENABLE_SSL=$(echo "$ENABLE_SSL" | tr '[:upper:]' '[:lower:]')
SSL_DOMAIN=$DOMAIN

# Backup Configuration
BACKUP_RETENTION_DAYS=$BACKUP_RETENTION_DAYS

# Generated on: $(date '+%Y-%m-%d %H:%M:%S')
EOF

# Generate pgAdmin password and email
echo ""
print_color "$CYAN" "pgAdmin Configuration:"
read -p "Enter email for pgAdmin login (default: admin@example.com): " pgadmin_email_choice
if [[ "$pgadmin_email_choice" =~ ^[^@]+@[^@]+\.[^@]+$ ]]; then
    PGADMIN_EMAIL="$pgadmin_email_choice"
else
    PGADMIN_EMAIL="admin@example.com"
fi
print_color "$GREEN" "pgAdmin email set to: $PGADMIN_EMAIL"

echo "Generating pgAdmin password..."
PGADMIN_PASSWORD=$(openssl rand -base64 18 | tr -d "=+/" | cut -c1-24)
print_color "$GREEN" "Generated pgAdmin password: $PGADMIN_PASSWORD"

# Add pgAdmin configuration to .env
cat >> .env << EOF

# pgAdmin Configuration
PGADMIN_EMAIL=$PGADMIN_EMAIL
PGADMIN_PASSWORD=$PGADMIN_PASSWORD
PGADMIN_PORT=5050
EOF

print_color "$GREEN" "Created .env file with configuration"

# Create pgAdmin servers.json configuration
echo "Creating pgAdmin configuration..."
cat > pgadmin/servers.json << EOF
{
  "Servers": {
    "1": {
      "Name": "TimescaleDB",
      "Group": "Servers",
      "Host": "timescaledb",
      "Port": 5432,
      "MaintenanceDB": "$DATABASE_NAME",
      "Username": "$USERNAME",
      "SSLMode": "$([ "$ENABLE_SSL" = true ] && echo 'require' || echo 'prefer')",
      "PassFile": "/tmp/pgpassfile"
    }
  }
}
EOF
print_color "$GREEN" "Created pgAdmin configuration"

# Create nginx configuration for pgAdmin
if [ "$ENABLE_SSL" = true ]; then
    echo "Creating nginx configuration for pgAdmin HTTPS..."
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
    print_color "$GREEN" "Created nginx.conf for pgAdmin HTTPS"
else
    echo "Creating nginx configuration for pgAdmin HTTP..."
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
    print_color "$GREEN" "Created nginx.conf for pgAdmin HTTP"
fi

# Create backup script
echo "Creating automated backup script..."
cat > management/backup.sh << 'EOF'
#!/bin/sh
set -e

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/backups"
RETENTION_DAYS=${BACKUP_RETENTION_DAYS:-30}

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Backup filename
BACKUP_FILE="$BACKUP_DIR/timescaledb_${TIMESTAMP}.sql.gz"

echo "$(date): Starting backup to $BACKUP_FILE"

# Perform backup using pg_dump
pg_dump -Fc "$PGDATABASE" | gzip > "$BACKUP_FILE"

if [ $? -eq 0 ]; then
    echo "$(date): Backup completed successfully: $BACKUP_FILE"
    
    # Clean up old backups
    echo "$(date): Cleaning up backups older than $RETENTION_DAYS days"
    find "$BACKUP_DIR" -name "*.sql.gz" -type f -mtime +$RETENTION_DAYS -delete
    
    # List current backups
    BACKUP_COUNT=$(ls -1 "$BACKUP_DIR"/*.sql.gz 2>/dev/null | wc -l)
    BACKUP_SIZE=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
    echo "$(date): Current backups: $BACKUP_COUNT files, Total size: $BACKUP_SIZE"
else
    echo "$(date): Backup failed!"
    exit 1
fi
EOF
chmod +x management/backup.sh
print_color "$GREEN" "Created automated backup script (retention: $BACKUP_RETENTION_DAYS days)"

# Create docker-entrypoint.sh with Unix line endings
echo "Creating docker-entrypoint.sh..."
cat > docker-entrypoint.sh << 'EOF'
#!/bin/bash
set -e

# Fix SSL certificate permissions if they exist
if [ -d "/var/lib/postgresql/certs" ] && [ -f "/var/lib/postgresql/certs/server.key" ]; then
    echo "Fixing SSL certificate permissions..."
    chown postgres:postgres /var/lib/postgresql/certs/server.key /var/lib/postgresql/certs/server.crt /var/lib/postgresql/certs/ca.crt 2>/dev/null || true
    chmod 600 /var/lib/postgresql/certs/server.key 2>/dev/null || true
    chmod 644 /var/lib/postgresql/certs/server.crt /var/lib/postgresql/certs/ca.crt 2>/dev/null || true
    echo "SSL certificate permissions fixed"
fi

# Execute the original docker entrypoint with all arguments
exec docker-entrypoint.sh "$@"
EOF
chmod +x docker-entrypoint.sh
print_color "$GREEN" "Created docker-entrypoint.sh with Unix line endings"

# Create initialization SQL script (if it doesn't exist)
if [ ! -f "init/01-init-timescaledb.sql" ]; then
    echo "Creating initialization script..."
    cat > init/01-init-timescaledb.sql << EOF
-- =================================================================
-- TimescaleDB Initialization Script
-- =================================================================

-- Create TimescaleDB extension
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- Enable additional useful extensions
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Log successful initialization
DO \$\$
BEGIN
    RAISE NOTICE 'TimescaleDB initialized successfully';
    RAISE NOTICE 'Version: %', (SELECT extversion FROM pg_extension WHERE extname = 'timescaledb');
END
\$\$;
EOF
    print_color "$GREEN" "Created initialization script"
else
    print_color "$GRAY" "Initialization script already exists"
fi

# Generate PostgreSQL configuration file from template
echo "Generating PostgreSQL configuration..."
TEMPLATE_PATH="config/postgresql.conf.template"
CONFIG_PATH="config/postgresql.conf"

if [ -f "$TEMPLATE_PATH" ]; then
    cp "$TEMPLATE_PATH" "$CONFIG_PATH"
    
    if [ "$ENABLE_SSL" = true ]; then
        sed -i "s/{{SSL_STATUS}}/enabled/g" "$CONFIG_PATH"
        sed -i "s/{{SSL_ENABLED}}/on/g" "$CONFIG_PATH"
        sed -i "s|{{SSL_CERT_LINE}}|ssl_cert_file = '/var/lib/postgresql/certs/server.crt'|g" "$CONFIG_PATH"
        sed -i "s|{{SSL_KEY_LINE}}|ssl_key_file = '/var/lib/postgresql/certs/server.key'|g" "$CONFIG_PATH"
        sed -i "s|{{SSL_CA_LINE}}|ssl_ca_file = '/var/lib/postgresql/certs/ca.crt'|g" "$CONFIG_PATH"
        sed -i "s|{{SSL_MIN_PROTOCOL_LINE}}|ssl_min_protocol_version = 'TLSv1.2'|g" "$CONFIG_PATH"
    else
        sed -i "s/{{SSL_STATUS}}/disabled/g" "$CONFIG_PATH"
        sed -i "s/{{SSL_ENABLED}}/off/g" "$CONFIG_PATH"
        sed -i "s/{{SSL_CERT_LINE}}/# ssl_cert_file not configured (SSL disabled)/g" "$CONFIG_PATH"
        sed -i "s/{{SSL_KEY_LINE}}/# ssl_key_file not configured (SSL disabled)/g" "$CONFIG_PATH"
        sed -i "s/{{SSL_CA_LINE}}/# ssl_ca_file not configured (SSL disabled)/g" "$CONFIG_PATH"
        sed -i "s/{{SSL_MIN_PROTOCOL_LINE}}/# ssl_min_protocol_version not configured (SSL disabled)/g" "$CONFIG_PATH"
    fi
    
    print_color "$GREEN" "Created PostgreSQL configuration file"
else
    print_color "$YELLOW" "Warning: Template file not found at $TEMPLATE_PATH"
    print_color "$YELLOW" "Creating basic configuration file..."
    
    cat > "$CONFIG_PATH" << EOF
# Basic PostgreSQL Configuration
listen_addresses = '*'
port = 5432
max_connections = 100
shared_preload_libraries = 'timescaledb'
timescaledb.telemetry_level = off
ssl = off
EOF
    print_color "$GREEN" "Created basic configuration file"
fi

# Set proper permissions for data directories
echo "Setting directory permissions..."
chmod -R 755 backups 2>/dev/null || true
print_color "$GREEN" "Directory permissions configured"

# SSL Certificate setup
if [ "$ENABLE_SSL" = true ]; then
    echo "Setting up SSL certificates..."
    
    if [ ! -f "certs/server.crt" ] || [ "$FORCE" = true ]; then
        echo "Generating SSL certificates for TimescaleDB..."
        
        # Generate CA private key
        docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine/openssl genrsa -out ca.key 4096
        
        # Generate CA certificate
        docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine/openssl req -new -x509 -days 365 -key ca.key -out ca.crt -subj "/C=US/ST=State/L=City/O=TimescaleDB/CN=TimescaleDB-CA"
        
        # Generate server private key
        docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine/openssl genrsa -out temp_server.key 4096
        
        # Build SAN list
        SAN_LIST="DNS:$DOMAIN,DNS:localhost,DNS:127.0.0.1,DNS:timescaledb,IP:127.0.0.1,IP:::1"
        if [ -n "$MACHINE_IP" ]; then
            IFS=',' read -ra IP_ARRAY <<< "$MACHINE_IP"
            for ip in "${IP_ARRAY[@]}"; do
                SAN_LIST="$SAN_LIST,IP:$ip"
            done
        fi
        
        # Generate server CSR with SAN
        docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine/openssl req -new -key temp_server.key -out temp_server.csr -subj "/C=US/ST=State/L=City/O=TimescaleDB/CN=$DOMAIN" -addext "subjectAltName=$SAN_LIST"
        
        # Sign server certificate
        docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine/openssl x509 -req -in temp_server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out temp_server.crt -days 365 -copy_extensions copy
        
        # Move temp files to final names and set permissions
        docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine sh -c "mv temp_server.key server.key && mv temp_server.crt server.crt && chmod 600 server.key && chmod 644 server.crt ca.crt && rm -f temp_server.csr ca.srl ca.key"
        
        if [ -f "certs/ca.crt" ] && [ -f "certs/server.crt" ] && [ -f "certs/server.key" ]; then
            print_color "$GREEN" "SSL certificates generated successfully"
            print_color "$GRAY" "Note: alpine/openssl image preserved for future SSL operations"
        else
            print_color "$RED" "SSL certificate generation failed"
            print_color "$YELLOW" "SSL will be disabled for this installation"
            ENABLE_SSL=false
            
            # Update .env to disable SSL
            sed -i 's/ENABLE_SSL=true/ENABLE_SSL=false/g' .env
        fi
    else
        print_color "$GRAY" "SSL certificates already exist"
    fi
fi

# Test configuration
echo "Testing configuration..."
if docker-compose config > /dev/null 2>&1; then
    print_color "$GREEN" "Docker Compose configuration is valid"
else
    print_color "$RED" "Docker Compose configuration has errors!"
    print_color "$GRAY" "Run 'docker-compose config' to see details."
    exit 1
fi

print_color "$CYAN" "=================================================================="
print_color "$CYAN" "Installation Summary:"
print_color "$CYAN" "=================================================================="
print_color "$GREEN" "Directory structure created"
print_color "$GREEN" "Authentication configured"
print_color "$GREEN" "Permissions set"
[ "$ENABLE_SSL" = true ] && print_color "$GREEN" "SSL certificates generated and configured"
print_color "$GREEN" "Initialization script created"
print_color "$GREEN" "Configuration validated"
echo ""
print_color "$CYAN" "TimescaleDB Database Details:"
echo "  Database: $DATABASE_NAME"
echo "  Username: $USERNAME"
print_color "$YELLOW" "  Password: $PASSWORD"
echo "  Port: 5432"
if [ "$ENABLE_SSL" = true ]; then
    print_color "$GREEN" "  SSL: Enabled (TLSv1.2+)"
    echo "  Domain: $DOMAIN"
    echo "  Connection: postgresql://$USERNAME:<password>@localhost:5432/$DATABASE_NAME?sslmode=require"
else
    print_color "$YELLOW" "  SSL: Disabled"
    echo "  Connection: postgresql://$USERNAME:<password>@localhost:5432/$DATABASE_NAME"
fi
echo ""
print_color "$CYAN" "pgAdmin Web UI Details:"
if [ "$ENABLE_SSL" = true ]; then
    echo "  URL: https://localhost:5051 (HTTPS)"
    print_color "$GRAY" "  HTTP Redirect: http://localhost:5050 -> https://localhost:5051"
else
    echo "  URL: http://localhost:5050"
fi
echo "  Email: $PGADMIN_EMAIL"
print_color "$YELLOW" "  Password: $PGADMIN_PASSWORD"
print_color "$GRAY" "  Note: TimescaleDB server is pre-configured in pgAdmin"
echo ""
print_color "$GREEN" "Installation completed successfully!"
print_color "$CYAN" "=================================================================="

# Ask if user wants to start TimescaleDB now
echo ""
read -p "Start TimescaleDB database now? (y/n): " start_choice
if [[ "$start_choice" =~ ^[Yy]$ ]] || [ -z "$start_choice" ]; then
    print_color "$GREEN" "Starting TimescaleDB database..."
    docker-compose up -d
    
    if [ $? -eq 0 ]; then
        print_color "$GREEN" "TimescaleDB database started successfully!"
        
        echo "Waiting for database to initialize..."
        sleep 15
        
        # Check status
        echo "Checking database status..."
        if docker-compose ps | grep -q "timescaledb.*Up"; then
            print_color "$GREEN" "[OK] TimescaleDB database is running successfully!"
            print_color "$GREEN" "[OK] Ready to accept connections"
            
            if [ "$ENABLE_SSL" = true ]; then
                print_color "$GREEN" "[OK] SSL/TLS encryption enabled"
                print_color "$CYAN" "[OK] Connect with: psql 'postgresql://$USERNAME@localhost:5432/$DATABASE_NAME?sslmode=require'"
            else
                print_color "$CYAN" "[OK] Connect with: psql -h localhost -U $USERNAME -d $DATABASE_NAME"
            fi
        else
            print_color "$YELLOW" "[WARN] Database may still be initializing"
            print_color "$GRAY" "Check logs with: docker-compose logs timescaledb"
        fi
    else
        print_color "$RED" "Failed to start TimescaleDB database"
        print_color "$GRAY" "Check configuration and try: docker-compose up -d"
    fi
else
    print_color "$YELLOW" "TimescaleDB database not started"
    echo ""
    print_color "$CYAN" "To start manually:"
    echo "1. Start the database: docker-compose up -d"
    echo "2. Check status: docker-compose ps"
    echo "3. View logs: docker-compose logs -f timescaledb"
fi

echo ""
print_color "$CYAN" "Management Commands:"
print_color "$GRAY" "==================="
[ "$USE_CA_PROVIDED" = true ] && print_color "$CYAN" "- Install CA certificates: ./management/manage-ssl.sh --enable --domain '$DOMAIN'"
echo "- SSL management: ./management/manage-ssl.sh --enable/--disable"
echo ""
print_color "$CYAN" "Configuration files:"
echo "  - docker-compose.yml (main configuration)"
echo "  - .env (environment variables)"
echo "  - init/01-init-timescaledb.sql (initialization script)"
echo "  - config/postgresql.conf (PostgreSQL configuration)"
echo "  - pgadmin/servers.json (pgAdmin server configuration)"
[ "$ENABLE_SSL" = true ] && echo "  - certs/ (SSL certificates)"

echo ""
print_color "$CYAN" "=================================================================="
print_color "$CYAN" "Automated Backup System"
print_color "$CYAN" "=================================================================="
print_color "$CYAN" "Backup Configuration:"
print_color "$GREEN" "  - Automated backups: ENABLED"
print_color "$GRAY" "  - Schedule: Daily at 2:00 AM"
print_color "$GRAY" "  - Retention: $BACKUP_RETENTION_DAYS days"
print_color "$GRAY" "  - Compression: Enabled (gzip)"
print_color "$GRAY" "  - Storage: ./backups directory"
echo ""
print_color "$CYAN" "Data Storage:"
print_color "$GRAY" "  - Database data: Docker volume 'timescaledb_data' (persistent)"
print_color "$GRAY" "  - Automated backups: ./backups directory"
echo ""
print_color "$GREEN" "The Docker volume persists data even when containers are recreated."
print_color "$GREEN" "Automated backups run continuously via backup container."
echo ""
print_color "$CYAN" "Backup Management:"
print_color "$CYAN" "  - View backups: ls -lh ./backups"
print_color "$CYAN" "  - Manual backup: docker exec timescaledb-backup /usr/local/bin/backup.sh"
print_color "$CYAN" "  - View logs: docker-compose logs backup"
print_color "$CYAN" "=================================================================="

# Return to management directory if we changed from it
if [ "$CURRENT_DIR" = "management" ]; then
    cd management
fi
