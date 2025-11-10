#!/bin/bash
# =================================================================
# Install/Remove CA Certificates (Linux)
# Installs self-signed CA certificates to system trust store
# =================================================================

set -euo pipefail

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
    echo "  -i, --install-path PATH    Installation directory (default: current directory)"
    echo "  -r, --remove               Remove CA certificates instead of installing"
    echo "  -h, --help                 Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                         # Install CA certificates from current directory"
    echo "  $0 --remove                # Remove previously installed CA certificates"
    echo "  $0 -i /path/to/install     # Install from specific directory"
    echo ""
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
    INSTALL_PATH="$(pwd)"
fi

print_color "$CYAN" "=================================================================="
if [ "$REMOVE" = true ]; then
    print_color "$CYAN" "Remove CA Certificates"
else
    print_color "$CYAN" "Install CA Certificates"
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
    print_color "$YELLOW" "This script requires root privileges."
    print_color "$YELLOW" "Please run with sudo: sudo $0 $*"
    exit 1
fi

# CA certificate paths
NEO4J_CA="$INSTALL_PATH/neo4j/certs/bolt/trusted/ca.crt"
MILVUS_CA="$INSTALL_PATH/milvus/tls/ca.pem"
MQTT_CA="$INSTALL_PATH/mqtt/certs/ca.crt"

# Certificate names for system store
NEO4J_CERT_NAME="neo4j-ca"
MILVUS_CERT_NAME="milvus-ca"
MQTT_CERT_NAME="mqtt-ca"

if [ "$REMOVE" = true ]; then
    # Remove certificates
    echo ""
    print_color "$CYAN" "Removing CA Certificates..."
    print_color "$GRAY" "============================"
    
    case "$DISTRO" in
        ubuntu|debian)
            # Ubuntu/Debian
            REMOVED=0
            
            if [ -f "/usr/local/share/ca-certificates/${NEO4J_CERT_NAME}.crt" ]; then
                rm -f "/usr/local/share/ca-certificates/${NEO4J_CERT_NAME}.crt"
                print_color "$GREEN" "  Removed Neo4j CA certificate"
                ((REMOVED++))
            fi
            
            if [ -f "/usr/local/share/ca-certificates/${MILVUS_CERT_NAME}.crt" ]; then
                rm -f "/usr/local/share/ca-certificates/${MILVUS_CERT_NAME}.crt"
                print_color "$GREEN" "  Removed Milvus CA certificate"
                ((REMOVED++))
            fi
            
            if [ -f "/usr/local/share/ca-certificates/${MQTT_CERT_NAME}.crt" ]; then
                rm -f "/usr/local/share/ca-certificates/${MQTT_CERT_NAME}.crt"
                print_color "$GREEN" "  Removed MQTT CA certificate"
                ((REMOVED++))
            fi
            
            if [ $REMOVED -gt 0 ]; then
                print_color "$YELLOW" "  Updating CA certificates..."
                update-ca-certificates
                print_color "$GREEN" "  CA certificates updated"
            else
                print_color "$GRAY" "  No certificates found to remove"
            fi
            ;;
            
        rhel|centos|fedora)
            # RHEL/CentOS/Fedora
            REMOVED=0
            
            if [ -f "/etc/pki/ca-trust/source/anchors/${NEO4J_CERT_NAME}.crt" ]; then
                rm -f "/etc/pki/ca-trust/source/anchors/${NEO4J_CERT_NAME}.crt"
                print_color "$GREEN" "  Removed Neo4j CA certificate"
                ((REMOVED++))
            fi
            
            if [ -f "/etc/pki/ca-trust/source/anchors/${MILVUS_CERT_NAME}.pem" ]; then
                rm -f "/etc/pki/ca-trust/source/anchors/${MILVUS_CERT_NAME}.pem"
                print_color "$GREEN" "  Removed Milvus CA certificate"
                ((REMOVED++))
            fi
            
            if [ -f "/etc/pki/ca-trust/source/anchors/${MQTT_CERT_NAME}.crt" ]; then
                rm -f "/etc/pki/ca-trust/source/anchors/${MQTT_CERT_NAME}.crt"
                print_color "$GREEN" "  Removed MQTT CA certificate"
                ((REMOVED++))
            fi
            
            if [ $REMOVED -gt 0 ]; then
                print_color "$YELLOW" "  Updating CA trust..."
                update-ca-trust
                print_color "$GREEN" "  CA trust updated"
            else
                print_color "$GRAY" "  No certificates found to remove"
            fi
            ;;
            
        *)
            print_color "$RED" "Unsupported distribution: $DISTRO"
            print_color "$YELLOW" "Supported: Ubuntu, Debian, RHEL, CentOS, Fedora"
            exit 1
            ;;
    esac
    
else
    # Install certificates
    echo ""
    print_color "$CYAN" "Installing CA Certificates..."
    print_color "$GRAY" "=============================="
    
    # Find certificates
    FOUND_CERTS=()
    
    if [ -f "$NEO4J_CA" ]; then
        FOUND_CERTS+=("neo4j")
        print_color "$GREEN" "  Found Neo4j CA certificate"
    fi
    
    if [ -f "$MILVUS_CA" ]; then
        FOUND_CERTS+=("milvus")
        print_color "$GREEN" "  Found Milvus CA certificate"
    fi
    
    if [ -f "$MQTT_CA" ]; then
        FOUND_CERTS+=("mqtt")
        print_color "$GREEN" "  Found MQTT CA certificate"
    fi
    
    if [ ${#FOUND_CERTS[@]} -eq 0 ]; then
        print_color "$YELLOW" "No CA certificates found to install"
        print_color "$GRAY" "Certificates are created when SSL is enabled during service installation"
        exit 0
    fi
    
    echo ""
    print_color "$CYAN" "Installing to system trust store..."
    
    case "$DISTRO" in
        ubuntu|debian)
            # Ubuntu/Debian
            INSTALLED=0
            
            if [ -f "$NEO4J_CA" ]; then
                cp "$NEO4J_CA" "/usr/local/share/ca-certificates/${NEO4J_CERT_NAME}.crt"
                print_color "$GREEN" "  Installed Neo4j CA certificate"
                ((INSTALLED++))
            fi
            
            if [ -f "$MILVUS_CA" ]; then
                cp "$MILVUS_CA" "/usr/local/share/ca-certificates/${MILVUS_CERT_NAME}.crt"
                print_color "$GREEN" "  Installed Milvus CA certificate"
                ((INSTALLED++))
            fi
            
            if [ -f "$MQTT_CA" ]; then
                cp "$MQTT_CA" "/usr/local/share/ca-certificates/${MQTT_CERT_NAME}.crt"
                print_color "$GREEN" "  Installed MQTT CA certificate"
                ((INSTALLED++))
            fi
            
            if [ $INSTALLED -gt 0 ]; then
                print_color "$YELLOW" "  Updating CA certificates..."
                update-ca-certificates
                print_color "$GREEN" "  CA certificates updated"
            fi
            ;;
            
        rhel|centos|fedora)
            # RHEL/CentOS/Fedora
            INSTALLED=0
            
            if [ -f "$NEO4J_CA" ]; then
                cp "$NEO4J_CA" "/etc/pki/ca-trust/source/anchors/${NEO4J_CERT_NAME}.crt"
                print_color "$GREEN" "  Installed Neo4j CA certificate"
                ((INSTALLED++))
            fi
            
            if [ -f "$MILVUS_CA" ]; then
                cp "$MILVUS_CA" "/etc/pki/ca-trust/source/anchors/${MILVUS_CERT_NAME}.pem"
                print_color "$GREEN" "  Installed Milvus CA certificate"
                ((INSTALLED++))
            fi
            
            if [ -f "$MQTT_CA" ]; then
                cp "$MQTT_CA" "/etc/pki/ca-trust/source/anchors/${MQTT_CERT_NAME}.crt"
                print_color "$GREEN" "  Installed MQTT CA certificate"
                ((INSTALLED++))
            fi
            
            if [ $INSTALLED -gt 0 ]; then
                print_color "$YELLOW" "  Updating CA trust..."
                update-ca-trust
                print_color "$GREEN" "  CA trust updated"
            fi
            ;;
            
        *)
            print_color "$RED" "Unsupported distribution: $DISTRO"
            print_color "$YELLOW" "Supported: Ubuntu, Debian, RHEL, CentOS, Fedora"
            print_color "$YELLOW" ""
            print_color "$YELLOW" "Manual installation:"
            print_color "$GRAY" "  Ubuntu/Debian:"
            print_color "$GRAY" "    sudo cp ca.crt /usr/local/share/ca-certificates/"
            print_color "$GRAY" "    sudo update-ca-certificates"
            print_color "$GRAY" "  RHEL/CentOS:"
            print_color "$GRAY" "    sudo cp ca.crt /etc/pki/ca-trust/source/anchors/"
            print_color "$GRAY" "    sudo update-ca-trust"
            exit 1
            ;;
    esac
fi

echo ""
print_color "$CYAN" "=================================================================="
if [ "$REMOVE" = true ]; then
    print_color "$GREEN" "CA certificates removed successfully!"
else
    print_color "$GREEN" "CA certificates installed successfully!"
    echo ""
    print_color "$YELLOW" "Note: Applications may need to be restarted to use the new certificates"
fi
print_color "$CYAN" "=================================================================="
