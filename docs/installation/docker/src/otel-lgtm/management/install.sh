#!/bin/bash
# =================================================================
# OpenTelemetry LGTM Stack Installation Script for Linux
# Description: Interactive installation wizard for LGTM Docker deployment
# (Grafana + Loki + Tempo + Mimir + OpenTelemetry Collector)
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
GRAFANA_PORT="3000"
GRAFANA_HTTPS_PORT="3443"
OTEL_GRPC_PORT="4317"
OTEL_HTTP_PORT="4318"
ENABLE_SSL=false
DOMAIN="localhost"
GRAFANA_PASSWORD=""
AUTO_START=false
FORCE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --port)
            GRAFANA_PORT="$2"
            shift 2
            ;;
        --https-port)
            GRAFANA_HTTPS_PORT="$2"
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
        --password)
            GRAFANA_PASSWORD="$2"
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

# Ensure we're in the otel-lgtm directory (not management subdirectory)
if [[ $(basename "$PWD") == "management" ]]; then
    cd ..
fi

echo -e "${CYAN}==================================================================${NC}"
echo -e "${CYAN}OpenTelemetry LGTM Stack Installation Script${NC}"
echo -e "${CYAN}(Grafana + Loki + Tempo + Mimir + OTEL Collector)${NC}"
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

# Check if container is already running
echo -e "${GRAY}Checking existing LGTM containers...${NC}"
if docker-compose ps 2>/dev/null | grep -q "otel-lgtm.*running"; then
    echo -e "${YELLOW}LGTM container is already running${NC}"
    if [ "$FORCE" = false ]; then
        read -p "Stop existing container to reconfigure? (y/n): " stop_choice
        if [[ "$stop_choice" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Stopping existing LGTM containers...${NC}"
            docker-compose down
            echo -e "${GREEN}[OK] Containers stopped${NC}"
        else
            echo -e "${YELLOW}Installation cancelled - containers still running${NC}"
            exit 0
        fi
    else
        echo -e "${YELLOW}Force mode: Stopping existing containers...${NC}"
        docker-compose down
    fi
else
    echo -e "${GREEN}[OK] No existing LGTM containers found${NC}"
fi

echo ""

# Create directory structure
echo -e "${GRAY}Creating directory structure...${NC}"
for dir in certs nginx collector otel-lgtm-data; do
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        echo -e "${GREEN}[OK] Created directory: $dir${NC}"
    else
        echo -e "${GRAY}  Directory exists: $dir${NC}"
    fi
done

echo ""

# Port configuration
if [ "$FORCE" = false ]; then
    read -p "Grafana UI port (default: 3000): " port_choice
    if [ -n "$port_choice" ]; then
        GRAFANA_PORT="$port_choice"
    fi
fi

# Check if port is available
if netstat -tuln 2>/dev/null | grep -q ":$GRAFANA_PORT "; then
    echo -e "${YELLOW}⚠ Warning: Port $GRAFANA_PORT is already in use!${NC}"
    if [ "$FORCE" = false ]; then
        read -p "Enter a different port or press Enter to continue anyway: " port_choice
        if [ -n "$port_choice" ]; then
            GRAFANA_PORT="$port_choice"
        fi
    fi
fi

echo -e "${GRAY}Grafana UI will be accessible on port: $GRAFANA_PORT${NC}"
echo -e "${GRAY}OTLP gRPC will be accessible on port: $OTEL_GRPC_PORT${NC}"
echo -e "${GRAY}OTLP HTTP will be accessible on port: $OTEL_HTTP_PORT${NC}"

echo ""

# Grafana admin password
if [ -z "$GRAFANA_PASSWORD" ] && [ "$FORCE" = false ]; then
    echo -e "${CYAN}Grafana Admin Configuration:${NC}"
    read -sp "Grafana admin password (default: admin): " pass_choice
    echo ""
    if [ -n "$pass_choice" ]; then
        GRAFANA_PASSWORD="$pass_choice"
    else
        GRAFANA_PASSWORD="admin"
    fi
else
    [ -z "$GRAFANA_PASSWORD" ] && GRAFANA_PASSWORD="admin"
fi

echo ""

# SSL Configuration
if [ "$FORCE" = false ]; then
    echo -e "${CYAN}SSL/TLS Configuration:${NC}"
    echo -e "${GRAY}LGTM uses Nginx reverse proxy for HTTPS support on Grafana UI${NC}"
    read -p "Enable SSL/TLS encryption? (y/n, default: n): " ssl_choice

    GENERATE_SSL=false
    if [[ "$ssl_choice" =~ ^[Yy]$ ]]; then
        ENABLE_SSL=true
        echo -e "${GREEN}[OK] SSL/TLS will be enabled${NC}"

        # Ask for HTTPS port
        read -p "Grafana HTTPS port (default: 3443): " https_port_choice
        if [ -n "$https_port_choice" ]; then
            GRAFANA_HTTPS_PORT="$https_port_choice"
        fi
        echo -e "${GRAY}Grafana HTTPS will be accessible on port: $GRAFANA_HTTPS_PORT${NC}"

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
                            index=$(echo "$index" | xargs)
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
    else
        echo -e "${GRAY}SSL/TLS will be disabled (HTTP only)${NC}"
        MACHINE_IPS=()
    fi
else
    GENERATE_SSL=false
    MACHINE_IPS=()
    if [ "$ENABLE_SSL" = true ]; then
        GENERATE_SSL=true
    fi
fi

echo ""

# If SSL not enabled, still detect IPs for display purposes
if [ "$ENABLE_SSL" = false ]; then
    echo -e "${GRAY}Detecting network configuration...${NC}"
    MACHINE_IPS=()
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

# Create .env file from template
echo -e "${GRAY}Creating configuration files...${NC}"

if [ ! -f ".env.template" ]; then
    echo -e "${RED}[ERROR] .env.template not found!${NC}"
    echo -e "${YELLOW}Please ensure you're running this script from the otel-lgtm directory${NC}"
    exit 1
fi

# Copy template to .env
cp .env.template .env
echo -e "${GREEN}[OK] Created .env file from template${NC}"

# Update .env file with configuration
sed -i "s/GRAFANA_PORT=.*/GRAFANA_PORT=$GRAFANA_PORT/" .env
sed -i "s/GRAFANA_HTTPS_PORT=.*/GRAFANA_HTTPS_PORT=$GRAFANA_HTTPS_PORT/" .env
sed -i "s/OTEL_GRPC_PORT=.*/OTEL_GRPC_PORT=$OTEL_GRPC_PORT/" .env
sed -i "s/OTEL_HTTP_PORT=.*/OTEL_HTTP_PORT=$OTEL_HTTP_PORT/" .env
sed -i "s/OTEL_LGTM_ENABLE_SSL=.*/OTEL_LGTM_ENABLE_SSL=$ENABLE_SSL/" .env
sed -i "s/OTEL_LGTM_DOMAIN=.*/OTEL_LGTM_DOMAIN=$DOMAIN/" .env
sed -i "s/GRAFANA_ADMIN_PASSWORD=.*/GRAFANA_ADMIN_PASSWORD=$GRAFANA_PASSWORD/" .env

# Try to read credentials from other service .env files
# TimescaleDB
if [ -f "../timescaledb/.env" ]; then
    TS_HOST=$(grep "^POSTGRES_HOST=" ../timescaledb/.env 2>/dev/null | cut -d= -f2)
    TS_DB=$(grep "^POSTGRES_DB=" ../timescaledb/.env 2>/dev/null | cut -d= -f2)
    TS_USER=$(grep "^POSTGRES_USER=" ../timescaledb/.env 2>/dev/null | cut -d= -f2)
    TS_PASS=$(grep "^POSTGRES_PASSWORD=" ../timescaledb/.env 2>/dev/null | cut -d= -f2)
    [ -n "$TS_DB" ] && sed -i "s/TIMESCALEDB_DB=.*/TIMESCALEDB_DB=$TS_DB/" .env
    [ -n "$TS_USER" ] && sed -i "s/TIMESCALEDB_USER=.*/TIMESCALEDB_USER=$TS_USER/" .env
    [ -n "$TS_PASS" ] && sed -i "s/TIMESCALEDB_PASSWORD=.*/TIMESCALEDB_PASSWORD=$TS_PASS/" .env
    echo -e "${GREEN}[OK] Auto-configured TimescaleDB connection from existing .env${NC}"
fi

# MQTT
if [ -f "../mqtt/.env" ]; then
    MQTT_USER_VAL=$(grep "^MQTT_USERNAME=" ../mqtt/.env 2>/dev/null | cut -d= -f2)
    MQTT_PASS_VAL=$(grep "^MQTT_PASSWORD=" ../mqtt/.env 2>/dev/null | cut -d= -f2)
    [ -n "$MQTT_USER_VAL" ] && sed -i "s/MQTT_USER=.*/MQTT_USER=$MQTT_USER_VAL/" .env
    [ -n "$MQTT_PASS_VAL" ] && sed -i "s/MQTT_PASSWORD=.*/MQTT_PASSWORD=$MQTT_PASS_VAL/" .env
    echo -e "${GREEN}[OK] Auto-configured MQTT connection from existing .env${NC}"
fi

# Add COMPOSE_PROFILES if SSL is enabled
if [ "$ENABLE_SSL" = true ]; then
    echo "COMPOSE_PROFILES=ssl" >> .env
fi

echo -e "${GREEN}[OK] Updated .env with configuration${NC}"

echo ""

# Generate SSL certificates if requested
if [ "$GENERATE_SSL" = true ]; then
    echo -e "${GRAY}Generating SSL certificates...${NC}"

    # Build SAN entries
    SAN_ENTRIES="DNS:localhost,DNS:$DOMAIN,IP:127.0.0.1"
    for ip in "${MACHINE_IPS[@]}"; do
        SAN_ENTRIES="$SAN_ENTRIES,IP:$ip"
    done

    # Generate CA private key
    echo -e "${GRAY}  Generating CA certificate...${NC}"
    docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine/openssl genrsa -out ca.key 4096 2>/dev/null
    docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine/openssl req -new -x509 -days 365 -key ca.key -out ca.crt -subj "/C=US/ST=State/L=City/O=OTEL-LGTM/CN=OTEL-LGTM-CA" 2>/dev/null

    # Generate server private key
    echo -e "${GRAY}  Generating server certificate...${NC}"
    docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine/openssl genrsa -out server.key 4096 2>/dev/null

    # Create OpenSSL config with SAN
    cat > certs/openssl.cnf <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req

[req_distinguished_name]

[v3_req]
subjectAltName = $SAN_ENTRIES
EOF

    # Generate CSR and sign certificate
    docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine/openssl req -new -key server.key -out server.csr -subj "/C=US/ST=State/L=City/O=OTEL-LGTM/CN=$DOMAIN" -config openssl.cnf 2>/dev/null
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

# Start Docker containers
echo -e "${GRAY}Starting LGTM stack...${NC}"
echo -e "${GRAY}This may take a minute on first run (pulling images)...${NC}"

docker-compose up -d

# Wait for health check
echo -e "${GRAY}Waiting for Grafana to become healthy...${NC}"
MAX_WAIT=90
WAITED=0
HEALTHY=false

while [ $WAITED -lt $MAX_WAIT ]; do
    sleep 2
    WAITED=$((WAITED + 2))

    if curl -sf "http://localhost:$GRAFANA_PORT/api/health" > /dev/null 2>&1; then
        HEALTHY=true
        break
    fi

    echo -n "."
done

echo ""

if [ "$HEALTHY" = true ]; then
    echo -e "${GREEN}[OK] LGTM stack is running and healthy${NC}"

    # Start nginx-ssl if SSL is enabled
    if [ "$ENABLE_SSL" = true ]; then
        echo -e "${GRAY}Starting grafana-nginx-ssl service...${NC}"
        docker-compose up -d grafana-nginx-ssl 2>&1 > /dev/null
        sleep 3
        echo -e "${GREEN}[OK] grafana-nginx-ssl service started${NC}"
    fi
else
    echo -e "${YELLOW}⚠ LGTM stack started but health check timed out${NC}"
    echo -e "${GRAY}  Check logs with: docker-compose logs otel-lgtm${NC}"
    if [ "$ENABLE_SSL" = true ]; then
        echo -e "${GRAY}  grafana-nginx-ssl will start once otel-lgtm becomes healthy${NC}"
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
echo -e "${CYAN}==================================================================${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${CYAN}==================================================================${NC}"
echo ""

# Display connection information
echo -e "${CYAN}Connection Information:${NC}"
echo -e "${GRAY}  Grafana UI:   http://localhost:$GRAFANA_PORT${NC}"
echo -e "${GRAY}  OTLP gRPC:    localhost:$OTEL_GRPC_PORT${NC}"
echo -e "${GRAY}  OTLP HTTP:    http://localhost:$OTEL_HTTP_PORT${NC}"
for ip in "${MACHINE_IPS[@]}"; do
    echo -e "${GRAY}                http://$ip:$GRAFANA_PORT${NC}"
done

if [ "$ENABLE_SSL" = true ]; then
    echo -e "${GRAY}  Grafana HTTPS: https://localhost:$GRAFANA_HTTPS_PORT${NC}"
    for ip in "${MACHINE_IPS[@]}"; do
        echo -e "${GRAY}                 https://$ip:$GRAFANA_HTTPS_PORT${NC}"
    done
    echo ""
    echo -e "${YELLOW}  CA Certificate: certs/ca.crt (distribute to clients)${NC}"
fi

echo ""
echo -e "${CYAN}Grafana Credentials:${NC}"
echo -e "${GRAY}  Username: admin${NC}"
echo -e "${GRAY}  Password: $GRAFANA_PASSWORD${NC}"

echo ""
echo -e "${CYAN}OpenTelemetry SDK Configuration:${NC}"
echo -e "${GRAY}  OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:$OTEL_HTTP_PORT${NC}"
echo -e "${GRAY}  OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf${NC}"

echo ""

# Display firewall configuration
echo -e "${CYAN}Firewall Configuration:${NC}"
echo -e "${GRAY}To allow external access, configure your firewall:${NC}"
echo ""
echo -e "${GRAY}For ufw:${NC}"
echo -e "${GRAY}  sudo ufw allow $GRAFANA_PORT/tcp${NC}"
echo -e "${GRAY}  sudo ufw allow $OTEL_GRPC_PORT/tcp${NC}"
echo -e "${GRAY}  sudo ufw allow $OTEL_HTTP_PORT/tcp${NC}"
if [ "$ENABLE_SSL" = true ]; then
    echo -e "${GRAY}  sudo ufw allow $GRAFANA_HTTPS_PORT/tcp${NC}"
fi
echo -e "${GRAY}  sudo ufw reload${NC}"
echo ""

# Management commands
echo -e "${CYAN}Management Commands:${NC}"
echo -e "${GRAY}  Logs:    docker-compose logs -f otel-lgtm${NC}"
if [ "$ENABLE_SSL" = true ]; then
    echo -e "${GRAY}  SSL:     ./management/manage-ssl.sh status${NC}"
fi
echo ""

echo -e "${CYAN}Observability Features:${NC}"
echo -e "${GRAY}  • Metrics: Prometheus scraping from Neo4j, TimescaleDB, MQTT, Milvus${NC}"
echo -e "${GRAY}  • Traces:  Distributed tracing via OTLP from agents${NC}"
echo -e "${GRAY}  • Logs:    Log aggregation via OTLP from agents${NC}"
echo -e "${GRAY}  • Grafana: Pre-configured data sources for Loki, Tempo, and Mimir${NC}"
echo ""
echo -e "${CYAN}==================================================================${NC}"
