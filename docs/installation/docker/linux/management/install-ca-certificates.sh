#!/bin/bash
# =================================================================
# Install/Remove CA Certificates (Linux)
# Installs self-signed CA certificates to system trust store
# =================================================================

# Don't exit on errors - we want to process all certificates
set +e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

# Default parameters
INSTALL_PATH=""
REMOVE=false
FORCE=false

# Function to print colored output
print_color() {
    local color=$1
    shift
    echo -e "${color}$@${NC}"
}

# Function to show usage
show_usage() {
    print_color "$CYAN" "=================================================================="
    print_color "$CYAN" "CA Certificate Management Script"
    print_color "$CYAN" "=================================================================="
    echo ""
    print_color "$CYAN" "Usage:"
    print_color "$GRAY" "  $0 [options]"
    echo ""
    print_color "$CYAN" "Options:"
    print_color "$GRAY" "  -i, --install-path PATH    Installation directory (default: current directory)"
    print_color "$GRAY" "  -r, --remove               Remove CA certificates instead of installing"
    print_color "$GRAY" "  -f, --force                Skip confirmation prompts and overwrite existing"
    print_color "$GRAY" "  -h, --help                 Show this help message"
    echo ""
    print_color "$CYAN" "Examples:"
    print_color "$GRAY" "  # Install CA certificates from current directory"
    print_color "$GRAY" "  $0"
    echo ""
    print_color "$GRAY" "  # Install CA certificates from specific path"
    print_color "$GRAY" "  $0 -i /path/to/docker/stack"
    echo ""
    print_color "$GRAY" "  # Remove all Docker stack CA certificates"
    print_color "$GRAY" "  $0 --remove"
    echo ""
    print_color "$GRAY" "  # Force reinstall existing certificates"
    print_color "$GRAY" "  $0 --force"
    echo ""
    print_color "$CYAN" "=================================================================="
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -i|--install-path)
            INSTALL_PATH="$2"
            shift 2
            ;;
        -r|--remove)
            REMOVE=true
            shift
            ;;
        -f|--force)
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

# Set default install path
if [ -z "$INSTALL_PATH" ]; then
    CURRENT_DIR=$(pwd)
    if [[ "$CURRENT_DIR" == */management ]]; then
        INSTALL_PATH=$(dirname "$CURRENT_DIR")
        print_color "$GRAY" "Detected management subfolder, using parent directory: $INSTALL_PATH"
    else
        INSTALL_PATH="$CURRENT_DIR"
        print_color "$GRAY" "Using current directory: $INSTALL_PATH"
    fi
else
    print_color "$GRAY" "Installation path: $INSTALL_PATH"
fi

print_color "$CYAN" "=================================================================="
if [ "$REMOVE" = true ]; then
    print_color "$CYAN" "Remove CA Certificates from System Trust Store"
else
    print_color "$CYAN" "Install CA Certificates to System Trust Store"
fi
print_color "$CYAN" "=================================================================="

# Detect Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    elif [ -f /etc/redhat-release ]; then
        echo "rhel"
    else
        echo "unknown"
    fi
}

DISTRO=$(detect_distro)

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_color "$RED" "This script requires root privileges."
    print_color "$YELLOW" "Please run with sudo: sudo $0 $*"
    exit 1
fi

print_color "$GREEN" "Running as root"

# Define service certificates
declare -A SERVICE_CERTS=(
    ["neo4j_bolt"]="neo4j/certs/bolt/trusted/ca.crt|Neo4j Bolt CA|neo4j-bolt-ca"
    ["neo4j_https"]="neo4j/certs/https/trusted/ca.crt|Neo4j HTTPS CA|neo4j-https-ca"
    ["milvus"]="milvus/tls/ca.pem|Milvus CA|milvus-ca"
    ["mqtt"]="mqtt/certs/ca.crt|MQTT CA|mqtt-ca"
)

# Arrays to track certificates
declare -a AVAILABLE_CERTS
declare -A SERVICES_SUMMARY

if [ "$REMOVE" = true ]; then
    # Remove certificates
    echo ""
    print_color "$CYAN" "Scanning certificate store for Docker stack CA certificates..."
    print_color "$GRAY" "============================================================="
    
    FOUND_CERTS=0
    REMOVED_COUNT=0
    ERROR_COUNT=0
    
    case "$DISTRO" in
        ubuntu|debian)
            # Ubuntu/Debian
            for key in "${!SERVICE_CERTS[@]}"; do
                IFS='|' read -r path name cert_name <<< "${SERVICE_CERTS[$key]}"
                
                if [ -f "/usr/local/share/ca-certificates/${cert_name}.crt" ]; then
                    print_color "$GREEN" "Found: $name"
                    ((FOUND_CERTS++))
                fi
            done
            
            if [ $FOUND_CERTS -eq 0 ]; then
                print_color "$YELLOW" "No Docker stack CA certificates found in certificate store."
                exit 0
            fi
            
            print_color "$CYAN" "Found $FOUND_CERTS Docker stack CA certificate(s)"
            
            if [ "$FORCE" = false ]; then
                echo ""
                read -p "Remove all Docker stack CA certificates? (y/n): " CONFIRM
                if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
                    print_color "$YELLOW" "Certificate removal cancelled."
                    exit 0
                fi
            fi
            
            echo ""
            print_color "$CYAN" "Removing CA certificates..."
            
            for key in "${!SERVICE_CERTS[@]}"; do
                IFS='|' read -r path name cert_name <<< "${SERVICE_CERTS[$key]}"
                
                if [ -f "/usr/local/share/ca-certificates/${cert_name}.crt" ]; then
                    echo ""
                    print_color "$CYAN" "Removing: $name"
                    if rm -f "/usr/local/share/ca-certificates/${cert_name}.crt" 2>/dev/null; then
                        print_color "$GREEN" "  Certificate removed successfully!"
                        ((REMOVED_COUNT++))
                    else
                        print_color "$RED" "  Failed to remove certificate"
                        ((ERROR_COUNT++))
                    fi
                fi
            done
            
            if [ $REMOVED_COUNT -gt 0 ]; then
                echo ""
                print_color "$YELLOW" "Updating CA certificates..."
                update-ca-certificates
                print_color "$GREEN" "CA certificates updated"
            fi
            ;;
            
        rhel|centos|fedora)
            # RHEL/CentOS/Fedora
            for key in "${!SERVICE_CERTS[@]}"; do
                IFS='|' read -r path name cert_name <<< "${SERVICE_CERTS[$key]}"
                
                CERT_FILE="/etc/pki/ca-trust/source/anchors/${cert_name}.crt"
                if [ ! -f "$CERT_FILE" ]; then
                    CERT_FILE="/etc/pki/ca-trust/source/anchors/${cert_name}.pem"
                fi
                
                if [ -f "$CERT_FILE" ]; then
                    print_color "$GREEN" "Found: $name"
                    ((FOUND_CERTS++))
                fi
            done
            
            if [ $FOUND_CERTS -eq 0 ]; then
                print_color "$YELLOW" "No Docker stack CA certificates found in certificate store."
                exit 0
            fi
            
            print_color "$CYAN" "Found $FOUND_CERTS Docker stack CA certificate(s)"
            
            if [ "$FORCE" = false ]; then
                echo ""
                read -p "Remove all Docker stack CA certificates? (y/n): " CONFIRM
                if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
                    print_color "$YELLOW" "Certificate removal cancelled."
                    exit 0
                fi
            fi
            
            echo ""
            print_color "$CYAN" "Removing CA certificates..."
            
            for key in "${!SERVICE_CERTS[@]}"; do
                IFS='|' read -r path name cert_name <<< "${SERVICE_CERTS[$key]}"
                
                CERT_FILE="/etc/pki/ca-trust/source/anchors/${cert_name}.crt"
                if [ ! -f "$CERT_FILE" ]; then
                    CERT_FILE="/etc/pki/ca-trust/source/anchors/${cert_name}.pem"
                fi
                
                if [ -f "$CERT_FILE" ]; then
                    echo ""
                    print_color "$CYAN" "Removing: $name"
                    if rm -f "$CERT_FILE" 2>/dev/null; then
                        print_color "$GREEN" "  Certificate removed successfully!"
                        ((REMOVED_COUNT++))
                    else
                        print_color "$RED" "  Failed to remove certificate"
                        ((ERROR_COUNT++))
                    fi
                fi
            done
            
            if [ $REMOVED_COUNT -gt 0 ]; then
                echo ""
                print_color "$YELLOW" "Updating CA trust..."
                update-ca-trust
                print_color "$GREEN" "CA trust updated"
            fi
            ;;
            
        *)
            print_color "$RED" "Unsupported distribution: $DISTRO"
            print_color "$YELLOW" "Supported: Ubuntu, Debian, RHEL, CentOS, Fedora"
            exit 1
            ;;
    esac
    
    # Summary
    echo ""
    print_color "$CYAN" "=================================================================="
    print_color "$CYAN" "Removal Summary"
    print_color "$CYAN" "=================================================================="
    print_color "$GREEN" "Certificates removed: $REMOVED_COUNT"
    if [ $ERROR_COUNT -gt 0 ]; then
        print_color "$RED" "Certificates failed: $ERROR_COUNT"
    fi
    
    if [ $REMOVED_COUNT -gt 0 ]; then
        echo ""
        print_color "$GREEN" "CA certificates have been removed from system trust store."
        print_color "$YELLOW" "SSL connections will now show security warnings again."
    fi
    
    echo ""
    print_color "$GREEN" "CA certificate removal completed!"
    print_color "$CYAN" "=================================================================="
    exit 0
fi

# Install certificates
echo ""
print_color "$CYAN" "Scanning for CA certificates..."
print_color "$GRAY" "==============================="

# Find available certificates
for key in "${!SERVICE_CERTS[@]}"; do
    IFS='|' read -r path name cert_name <<< "${SERVICE_CERTS[$key]}"
    FULL_PATH="$INSTALL_PATH/$path"
    
    if [ -f "$FULL_PATH" ]; then
        AVAILABLE_CERTS+=("$key")
        print_color "$GREEN" "Found: $name at $path"
        
        # Extract service name
        SERVICE=$(echo "$key" | cut -d'_' -f1)
        if [ -z "${SERVICES_SUMMARY[$SERVICE]}" ]; then
            SERVICES_SUMMARY[$SERVICE]=1
        else
            SERVICES_SUMMARY[$SERVICE]=$((SERVICES_SUMMARY[$SERVICE] + 1))
        fi
    else
        print_color "$GRAY" "Missing: $name at $path"
    fi
done

if [ ${#AVAILABLE_CERTS[@]} -eq 0 ]; then
    echo ""
    print_color "$RED" "No CA certificates found!"
    print_color "$YELLOW" "This script should be run after services have been installed with SSL enabled."
    echo ""
    print_color "$CYAN" "To generate SSL certificates:"
    print_color "$GRAY" "  cd neo4j && ./management/manage-ssl.sh generate && ./management/manage-ssl.sh enable"
    print_color "$GRAY" "  cd milvus && ./management/manage-ssl.sh generate && ./management/manage-ssl.sh enable"
    print_color "$GRAY" "  cd mqtt && ./management/manage-ssl.sh generate && ./management/manage-ssl.sh enable"
    exit 1
fi

echo ""
print_color "$CYAN" "Services with SSL certificates:"
for service in "${!SERVICES_SUMMARY[@]}"; do
    print_color "$GREEN" "  $service: ${SERVICES_SUMMARY[$service]} certificate(s)"
done

echo ""
case "$DISTRO" in
    ubuntu|debian)
        print_color "$CYAN" "Installing CA certificates to: /usr/local/share/ca-certificates/"
        ;;
    rhel|centos|fedora)
        print_color "$CYAN" "Installing CA certificates to: /etc/pki/ca-trust/source/anchors/"
        ;;
    *)
        print_color "$RED" "Unsupported distribution: $DISTRO"
        print_color "$YELLOW" "Supported: Ubuntu, Debian, RHEL, CentOS, Fedora"
        exit 1
        ;;
esac

INSTALLED_COUNT=0
SKIPPED_COUNT=0
ERROR_COUNT=0

for key in "${AVAILABLE_CERTS[@]}"; do
    IFS='|' read -r path name cert_name <<< "${SERVICE_CERTS[$key]}"
    FULL_PATH="$INSTALL_PATH/$path"
    
    echo ""
    print_color "$CYAN" "Processing: $name"
    
    case "$DISTRO" in
        ubuntu|debian)
            DEST_FILE="/usr/local/share/ca-certificates/${cert_name}.crt"
            
            if [ -f "$DEST_FILE" ] && [ "$FORCE" = false ]; then
                print_color "$YELLOW" "  Certificate already installed"
                ((SKIPPED_COUNT++))
            else
                if [ -f "$DEST_FILE" ] && [ "$FORCE" = true ]; then
                    print_color "$YELLOW" "  Removing existing certificate..."
                    rm -f "$DEST_FILE"
                fi
                
                # Copy certificate (error handling already set with set +e at top)
                cp "$FULL_PATH" "$DEST_FILE" 2>/dev/null
                CP_RESULT=$?
                
                if [ $CP_RESULT -eq 0 ]; then
                    print_color "$GREEN" "  Certificate installed successfully!"
                    INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
                else
                    print_color "$RED" "  Failed to install certificate: $FULL_PATH"
                    ERROR_COUNT=$((ERROR_COUNT + 1))
                fi
            fi
            ;;
            
        rhel|centos|fedora)
            # Use .pem extension for Milvus, .crt for others
            if [[ "$path" == *".pem" ]]; then
                DEST_FILE="/etc/pki/ca-trust/source/anchors/${cert_name}.pem"
            else
                DEST_FILE="/etc/pki/ca-trust/source/anchors/${cert_name}.crt"
            fi
            
            if [ -f "$DEST_FILE" ] && [ "$FORCE" = false ]; then
                print_color "$YELLOW" "  Certificate already installed"
                ((SKIPPED_COUNT++))
            else
                if [ -f "$DEST_FILE" ] && [ "$FORCE" = true ]; then
                    print_color "$YELLOW" "  Removing existing certificate..."
                    rm -f "$DEST_FILE"
                fi
                
                # Copy certificate (error handling already set with set +e at top)
                cp "$FULL_PATH" "$DEST_FILE" 2>/dev/null
                CP_RESULT=$?
                
                if [ $CP_RESULT -eq 0 ]; then
                    print_color "$GREEN" "  Certificate installed successfully!"
                    INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
                else
                    print_color "$RED" "  Failed to install certificate: $FULL_PATH"
                    ERROR_COUNT=$((ERROR_COUNT + 1))
                fi
            fi
            ;;
    esac
done

# Update certificate store
if [ $INSTALLED_COUNT -gt 0 ] || [ $ERROR_COUNT -gt 0 ]; then
    echo ""
    case "$DISTRO" in
        ubuntu|debian)
            print_color "$YELLOW" "Updating CA certificates..."
            update-ca-certificates 2>&1
            UPDATE_RESULT=$?
            if [ $UPDATE_RESULT -eq 0 ]; then
                print_color "$GREEN" "CA certificates updated"
            else
                print_color "$YELLOW" "CA certificate update completed with warnings"
            fi
            ;;
        rhel|centos|fedora)
            print_color "$YELLOW" "Updating CA trust..."
            update-ca-trust 2>&1
            UPDATE_RESULT=$?
            if [ $UPDATE_RESULT -eq 0 ]; then
                print_color "$GREEN" "CA trust updated"
            else
                print_color "$YELLOW" "CA trust update completed with warnings"
            fi
            ;;
    esac
fi

# Summary
echo ""
print_color "$CYAN" "=================================================================="
print_color "$CYAN" "Installation Summary"
print_color "$CYAN" "=================================================================="
print_color "$GREEN" "Certificates installed: $INSTALLED_COUNT"
if [ $SKIPPED_COUNT -gt 0 ]; then
    print_color "$YELLOW" "Certificates skipped: $SKIPPED_COUNT"
fi
if [ $ERROR_COUNT -gt 0 ]; then
    print_color "$RED" "Certificates failed: $ERROR_COUNT"
fi

if [ $INSTALLED_COUNT -gt 0 ]; then
    echo ""
    print_color "$CYAN" "Benefits:"
    print_color "$GREEN" "- Browser SSL warnings eliminated for HTTPS connections"
    print_color "$GREEN" "- Applications can connect without certificate validation errors"
    print_color "$GREEN" "- Secure connections work seamlessly across all services"
    
    echo ""
    print_color "$CYAN" "Test SSL connections:"
    if [ -n "${SERVICES_SUMMARY[neo4j]}" ]; then
        print_color "$GRAY" "- Neo4j Browser: https://localhost:7473"
        print_color "$GRAY" "- Neo4j Bolt+TLS: bolt+s://localhost:7687"
    fi
    if [ -n "${SERVICES_SUMMARY[milvus]}" ]; then
        print_color "$GRAY" "- Milvus gRPC: localhost:19530 (TLS)"
        print_color "$GRAY" "- MinIO Console: https://localhost:9001"
    fi
    if [ -n "${SERVICES_SUMMARY[mqtt]}" ]; then
        print_color "$GRAY" "- MQTT SSL: localhost:8883"
    fi
fi

if [ $SKIPPED_COUNT -gt 0 ]; then
    echo ""
    print_color "$GRAY" "To reinstall existing certificates, use: --force parameter"
fi

echo ""
print_color "$CYAN" "Certificate Management:"
print_color "$GRAY" "======================"
print_color "$GRAY" "To remove installed certificates:"
print_color "$GREEN" "  sudo $0 --remove"

echo ""
print_color "$GREEN" "CA certificate installation completed!"
print_color "$CYAN" "=================================================================="
