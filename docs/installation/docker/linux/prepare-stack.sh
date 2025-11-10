#!/bin/bash
# =================================================================
# Docker Stack Prepare Script (Linux)
# Creates deployment ZIP with Cypher scripts
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
OUTPUT_PATH=""
ZIP_NAME=""
FORCE=false
OFFLINE=false

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
    echo "  -o, --output PATH     Output directory path (default: ./dist)"
    echo "  -n, --name NAME       ZIP file name (default: docker-stack-TIMESTAMP.zip)"
    echo "  -f, --force           Overwrite existing ZIP file"
    echo "  --offline             Create offline deployment package with Docker images"
    echo "  -h, --help            Show this help message"
    echo ""
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--output)
            OUTPUT_PATH="$2"
            shift 2
            ;;
        -n|--name)
            ZIP_NAME="$2"
            shift 2
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        --offline)
            OFFLINE=true
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

print_color "$CYAN" "Docker Stack Prepare Script (Linux)"
print_color "$CYAN" "=================================================================="

# Get current directory (should be docs/installation/docker/linux)
CURRENT_DIR="$(pwd)"
PARENT_DIR="$(dirname "$CURRENT_DIR")"

# Validate we're in the correct directory
if [ ! -d "$PARENT_DIR/src" ]; then
    print_color "$RED" "Error: This script must be run from the docs/installation/docker/linux directory!"
    exit 1
fi

# Set default output path if not provided
if [ -z "$OUTPUT_PATH" ]; then
    OUTPUT_PATH="$CURRENT_DIR/dist"
fi

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_PATH"

# Set default zip name if not provided
if [ -z "$ZIP_NAME" ]; then
    TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
    ZIP_NAME="docker-stack-$TIMESTAMP.zip"
fi

# Ensure .zip extension
if [[ ! "$ZIP_NAME" =~ \.zip$ ]]; then
    ZIP_NAME="${ZIP_NAME}.zip"
fi

ZIP_PATH="$OUTPUT_PATH/$ZIP_NAME"

# Check if zip already exists
if [ -f "$ZIP_PATH" ] && [ "$FORCE" = false ]; then
    print_color "$RED" "ZIP file already exists: $ZIP_PATH"
    print_color "$YELLOW" "Use --force to overwrite existing file."
    exit 1
fi

echo "Output: $ZIP_PATH"

# Create temporary working directory
TEMP_DIR=$(mktemp -d -t docker-stack-prep-XXXXXX)

cleanup() {
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT

# Copy source directories
echo "Copying services..."

SERVICES=("neo4j" "milvus" "mqtt")
for SERVICE in "${SERVICES[@]}"; do
    SOURCE_PATH="$PARENT_DIR/src/$SERVICE"
    DEST_PATH="$TEMP_DIR/$SERVICE"
    
    if [ -d "$SOURCE_PATH" ]; then
        cp -r "$SOURCE_PATH" "$DEST_PATH"
    else
        print_color "$YELLOW" "Warning: $SERVICE not found"
    fi
done

# Copy Cypher scripts to Neo4j updates folder
echo "Processing Cypher scripts..."

CYPHER_SOURCE_DIR="$(dirname "$PARENT_DIR")"
NEO4J_UPDATES_DIR="$TEMP_DIR/neo4j/updates"

# Find all .cypher files in the installation directory
CYPHER_COUNT=0
if compgen -G "$CYPHER_SOURCE_DIR/*.cypher" > /dev/null; then
    for CYPHER_FILE in "$CYPHER_SOURCE_DIR"/*.cypher; do
        if [ -f "$CYPHER_FILE" ]; then
            cp "$CYPHER_FILE" "$NEO4J_UPDATES_DIR/"
            ((CYPHER_COUNT++))
        fi
    done
    print_color "$GREEN" "  Added $CYPHER_COUNT Cypher script(s)"
else
    print_color "$YELLOW" "  No Cypher scripts found"
fi

# Download Python packages for Neo4j watcher (for airgapped installations)
echo "Downloading Python packages for Neo4j watcher..."
NEO4J_PACKAGES_DIR="$TEMP_DIR/neo4j/neo4j-packages"
mkdir -p "$NEO4J_PACKAGES_DIR"

# Check if pip is available
if command -v pip3 &> /dev/null || command -v pip &> /dev/null; then
    PIP_CMD=$(command -v pip3 || command -v pip)
    
    if $PIP_CMD download neo4j -d "$NEO4J_PACKAGES_DIR" &> /dev/null; then
        PACKAGE_COUNT=$(find "$NEO4J_PACKAGES_DIR" -name "*.whl" | wc -l)
        print_color "$GREEN" "  Downloaded $PACKAGE_COUNT Python package(s) for offline installation"
        
        # Create README for the packages
        cat > "$NEO4J_PACKAGES_DIR/README.md" << 'EOF'
# Neo4j Python Packages

This directory contains Python packages required for the Neo4j watcher service.
These packages enable the watcher to work in airgapped/offline environments.

## Contents
- neo4j Python driver
- All dependencies required by the neo4j driver

## Usage
These packages are automatically used by the watcher when it starts.
The watcher will install from these local packages instead of downloading from PyPI.

## Updating Packages
To update the packages, run on a machine with internet access:
```bash
pip3 download neo4j -d neo4j-packages --upgrade
```

EOF
        echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')" >> "$NEO4J_PACKAGES_DIR/README.md"
    else
        print_color "$YELLOW" "  Failed to download Python packages"
        print_color "$GRAY" "  Watcher will attempt online installation if deployed with internet access"
    fi
else
    print_color "$YELLOW" "  pip not found, skipping Python package download"
fi

# Copy management scripts
echo "Copying management scripts..."

# Create management folder for supporting scripts
MANAGEMENT_DIR="$TEMP_DIR/management"
mkdir -p "$MANAGEMENT_DIR"

# Copy supporting management scripts to management folder
MANAGEMENT_SCRIPTS=("install-ca-certificates.sh" "stop-all-services.sh")

for SCRIPT in "${MANAGEMENT_SCRIPTS[@]}"; do
    SCRIPT_SOURCE="$CURRENT_DIR/$SCRIPT"
    SCRIPT_DEST="$MANAGEMENT_DIR/$SCRIPT"
    
    if [ -f "$SCRIPT_SOURCE" ]; then
        cp "$SCRIPT_SOURCE" "$SCRIPT_DEST"
        chmod +x "$SCRIPT_DEST"
        print_color "$GREEN" "  Added $SCRIPT to management/"
    else
        print_color "$YELLOW" "  Warning: $SCRIPT not found"
    fi
done

# Note: docker-stack-installer.sh is NOT included in ZIP - it should be copied separately
print_color "$GRAY" "  Note: docker-stack-installer.sh not included in ZIP (copy separately)"

# Create README file for the deployment
cat > "$TEMP_DIR/README.md" << 'EOF'
# Docker Stack Deployment (Linux)

This package contains a complete Docker stack deployment for:
- **Neo4j** - Graph database
- **Milvus** - Vector database  
- **MQTT** - Message broker

## Directory Structure

```
.
├── README.md                          # This file
├── docker-stack-installer.sh          # Main installer (run this)
├── management/                        # Supporting management scripts
│   ├── install-ca-certificates.sh    # CA certificate installer
│   └── stop-all-services.sh          # Stop all services
├── neo4j/                            # Neo4j service
│   ├── docker-compose.yml
│   ├── watcher.py
│   ├── neo4j-packages/               # Python packages for offline
│   └── management/                   # Neo4j management scripts
├── milvus/                           # Milvus service
│   ├── docker-compose.yml
│   └── management/                   # Milvus management scripts
└── mqtt/                             # MQTT service
    ├── docker-compose.yml
    └── management/                   # MQTT management scripts
```

## Quick Start

1. **Place files** in your desired installation directory:
   - Copy `docker-stack-installer.sh` to the directory
   - Copy the ZIP file to the same directory

2. **Make installer executable**:
   ```bash
   chmod +x docker-stack-installer.sh
   ```

3. **Run the installer** (extracts to current directory):
   ```bash
   ./docker-stack-installer.sh
   ```

4. **Follow** the interactive prompts to configure each service

5. **Access** your services using the credentials provided during installation

**Note:** The installer extracts the ZIP to the current directory and moves the ZIP to an `archive/` folder.

## Requirements

- **Docker Engine** - Must be installed and running
- **Docker Compose** - V2 or later
- **Bash 4.0+** - For running installation scripts
- **Linux** - Tested on Ubuntu 20.04+, Debian 11+, RHEL 8+

## Service Access (after installation)

### Neo4j
- Browser UI: http://localhost:7474
- Bolt Protocol: bolt://localhost:7687
- HTTPS (if SSL enabled): https://localhost:7473

### Milvus  
- gRPC API: localhost:19530
- HTTP API: localhost:9091
- MinIO Console: http://localhost:9001

### MQTT
- Broker: localhost:1883
- WebSocket: ws://localhost:9002
- SSL (if enabled): localhost:8883

## Management Scripts

### Stack-Level Management
- **docker-stack-installer.sh** (root) - Install and configure all services
- **management/install-ca-certificates.sh** - Install SSL CA certificates to system
- **management/stop-all-services.sh** - Stop all services at once

### Service-Level Management (in each service's management/ folder)
- **install.sh** - Service installation and configuration
- **backup.sh** - Create service backups
- **restore.sh** - Restore from backups
- **manage-ssl.sh** - SSL certificate management
- **manage-users.sh** - User management (MQTT only)

## Features

- Interactive configuration for all services
- SSL/TLS support for secure connections
- Automatic password generation
- Comprehensive management scripts
- Backup and restore capabilities
- Airgapped/offline installation support

## Support

For issues or questions, refer to the documentation in each service directory.

---
EOF
echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')" >> "$TEMP_DIR/README.md"

# Create the ZIP file
echo "Creating ZIP..."

# Remove existing zip if Force is specified
if [ -f "$ZIP_PATH" ] && [ "$FORCE" = true ]; then
    rm -f "$ZIP_PATH"
fi

# Create ZIP
cd "$TEMP_DIR"
zip -r "$ZIP_PATH" . > /dev/null 2>&1
cd "$CURRENT_DIR"

# Get ZIP file size
ZIP_SIZE_MB=$(du -m "$ZIP_PATH" | cut -f1)
print_color "$GREEN" "  Created: ${ZIP_SIZE_MB} MB"

# Copy docker-stack-installer.sh to dist folder
echo "Copying installer to dist folder..."
INSTALLER_SOURCE="$CURRENT_DIR/docker-stack-installer.sh"
INSTALLER_DEST="$OUTPUT_PATH/docker-stack-installer.sh"

if [ -f "$INSTALLER_SOURCE" ]; then
    cp "$INSTALLER_SOURCE" "$INSTALLER_DEST"
    chmod +x "$INSTALLER_DEST"
    print_color "$GREEN" "  Copied docker-stack-installer.sh to dist/"
else
    print_color "$YELLOW" "  Warning: docker-stack-installer.sh not found"
fi

# Handle offline deployment if requested
if [ "$OFFLINE" = true ]; then
    echo ""
    print_color "$CYAN" "Offline Deployment Preparation"
    print_color "$CYAN" "=================================================================="
    
    # Check for Docker
    echo "Checking Docker..."
    if command -v docker &> /dev/null && docker version &> /dev/null; then
        print_color "$GREEN" "  Docker available"
    else
        echo ""
        print_color "$RED" "ERROR: Docker required for offline package creation"
        print_color "$YELLOW" "Install Docker Engine: https://docs.docker.com/engine/install/"
        exit 1
    fi
    
    # Define required Docker images
    declare -A DOCKER_IMAGES=(
        ["neo4j:2025.08-community"]="Neo4j"
        ["python:3.11-slim"]="Python"
        ["alpine/openssl:latest"]="OpenSSL (for SSL cert generation)"
        ["alpine:latest"]="Alpine (for file operations)"
        ["eclipse-mosquitto:2.0.22"]="MQTT"
        ["milvusdb/milvus:v2.6.3"]="Milvus"
        ["minio/minio:latest"]="MinIO"
        ["quay.io/coreos/etcd:v3.6.5"]="etcd"
        ["zilliz/attu:v2.6"]="Attu"
        ["nginx:alpine"]="Nginx"
    )
    
    echo "Downloading Docker images..."
    
    SUCCESSFUL_DOWNLOADS=()
    FAILED_DOWNLOADS=()
    
    for IMAGE in "${!DOCKER_IMAGES[@]}"; do
        DESC="${DOCKER_IMAGES[$IMAGE]}"
        echo "  $DESC: $IMAGE"
        
        if docker pull "$IMAGE" &> /dev/null; then
            SUCCESSFUL_DOWNLOADS+=("$IMAGE")
        else
            print_color "$RED" "    FAILED"
            FAILED_DOWNLOADS+=("$IMAGE")
        fi
    done
    
    # Save images to tar archive
    if [ ${#SUCCESSFUL_DOWNLOADS[@]} -gt 0 ]; then
        echo "Saving to tar archive..."
        
        IMAGES_ARCHIVE_NAME="${ZIP_NAME%.zip}-docker-images.tar"
        IMAGES_ARCHIVE_PATH="$OUTPUT_PATH/$IMAGES_ARCHIVE_NAME"
        
        if [ -f "$IMAGES_ARCHIVE_PATH" ] && [ "$FORCE" = true ]; then
            rm -f "$IMAGES_ARCHIVE_PATH"
        fi
        
        if docker save -o "$IMAGES_ARCHIVE_PATH" "${SUCCESSFUL_DOWNLOADS[@]}" 2> /dev/null; then
            ARCHIVE_SIZE_GB=$(du -h "$IMAGES_ARCHIVE_PATH" | cut -f1)
            print_color "$GREEN" "  Created: $ARCHIVE_SIZE_GB"
        else
            print_color "$RED" "  Docker save failed"
        fi
    fi
    
    # Handle failures
    if [ ${#FAILED_DOWNLOADS[@]} -gt 0 ]; then
        echo ""
        print_color "$YELLOW" "WARNING: ${#FAILED_DOWNLOADS[@]} image(s) failed - will download during install"
    fi
    
    # Create offline installation instructions
    echo "Creating offline instructions..."
    
    cat > "$OUTPUT_PATH/OFFLINE-INSTALLATION-INSTRUCTIONS.md" << EOF
# Offline Docker Stack Deployment (Linux)

This package was created using **Docker** and contains everything needed for offline deployment.

## Package Contents

1. **$ZIP_NAME** - Service configuration files and scripts
2. **$IMAGES_ARCHIVE_NAME** - Pre-downloaded Docker images
   - Contains ${#SUCCESSFUL_DOWNLOADS[@]} Docker images
EOF

    if [ ${#FAILED_DOWNLOADS[@]} -gt 0 ]; then
        cat >> "$OUTPUT_PATH/OFFLINE-INSTALLATION-INSTRUCTIONS.md" << EOF
   - **WARNING**: Missing ${#FAILED_DOWNLOADS[@]} images (will download during install):
EOF
        for FAILED in "${FAILED_DOWNLOADS[@]}"; do
            echo "     - $FAILED" >> "$OUTPUT_PATH/OFFLINE-INSTALLATION-INSTRUCTIONS.md"
        done
    fi

    cat >> "$OUTPUT_PATH/OFFLINE-INSTALLATION-INSTRUCTIONS.md" << 'EOF'

3. **docker-stack-installer.sh** - Main installation script (copy separately)

## Offline Installation Steps

### Step 1: Install Docker Engine (if not already installed)

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install -y docker.io docker-compose
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER
```

**RHEL/CentOS:**
```bash
sudo yum install -y docker docker-compose
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER
```

**Note:** Log out and back in for group membership to take effect.

### Step 2: Load Docker Images (CRITICAL - DO NOT SKIP)

Before running the installer, load the pre-downloaded images:

```bash
# In the directory containing the .tar file
docker load -i docker-stack-*-docker-images.tar
```

**Verify images are loaded:**
```bash
docker images
```

You should see all the required images listed.

### Step 3: Run the Installer

1. Copy `docker-stack-installer.sh` to the same directory as the ZIP file
2. Make it executable and run:

```bash
chmod +x docker-stack-installer.sh
./docker-stack-installer.sh
```

3. The installer will:
   - Extract the ZIP to the current directory
   - Move the ZIP file to an `archive/` folder
   - Configure all services
4. Follow the interactive prompts to configure each service

---
EOF
    echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')" >> "$OUTPUT_PATH/OFFLINE-INSTALLATION-INSTRUCTIONS.md"
    echo "Package Type: Offline Deployment" >> "$OUTPUT_PATH/OFFLINE-INSTALLATION-INSTRUCTIONS.md"
    echo "Images Included: ${#SUCCESSFUL_DOWNLOADS[@]}" >> "$OUTPUT_PATH/OFFLINE-INSTALLATION-INSTRUCTIONS.md"
    echo "Missing Images: ${#FAILED_DOWNLOADS[@]}" >> "$OUTPUT_PATH/OFFLINE-INSTALLATION-INSTRUCTIONS.md"
fi

echo ""
print_color "$CYAN" "=================================================================="
if [ "$OFFLINE" = true ]; then
    print_color "$CYAN" "Offline Deployment Package Ready!"
else
    print_color "$CYAN" "Deployment Package Ready!"
fi
print_color "$CYAN" "=================================================================="
print_color "$GREEN" "ZIP File: $ZIP_PATH"
echo "Size: ${ZIP_SIZE_MB} MB"

if [ "$OFFLINE" = true ]; then
    echo ""
    print_color "$CYAN" "Offline Package Contents:"
    print_color "$GRAY" "========================"
    echo "1. Service configuration ZIP: $ZIP_NAME"
    
    IMAGES_ARCHIVE_PATH="$OUTPUT_PATH/${ZIP_NAME%.zip}-docker-images.tar"
    if [ -f "$IMAGES_ARCHIVE_PATH" ]; then
        IMAGES_SIZE=$(du -h "$IMAGES_ARCHIVE_PATH" | cut -f1)
        echo "2. Docker images archive: $(basename "$IMAGES_ARCHIVE_PATH") ($IMAGES_SIZE)"
    fi
    
    echo "3. Installation script: docker-stack-installer.sh (copy separately)"
    echo "4. Offline instructions: OFFLINE-INSTALLATION-INSTRUCTIONS.md"
    
    echo ""
    print_color "$CYAN" "CRITICAL: Offline Installation Steps:"
    echo "1. Copy ALL files to target machine"
    echo "2. Install Docker Engine if needed"
    print_color "$YELLOW" "3. LOAD images FIRST: docker load -i [images-archive].tar"
    echo "4. Extract services ZIP"
    echo "5. Run installer: ./docker-stack-installer.sh"
    echo ""
    print_color "$YELLOW" "Read OFFLINE-INSTALLATION-INSTRUCTIONS.md for detailed steps!"
else
    echo ""
    print_color "$CYAN" "Next Steps:"
    echo "1. Copy the ZIP file to your target machine"
    echo "2. Copy docker-stack-installer.sh to your target machine"
    echo "3. Make installer executable: chmod +x docker-stack-installer.sh"
    echo "4. Run: ./docker-stack-installer.sh"
    echo "5. Follow the interactive installation prompts"
fi

echo ""
print_color "$GREEN" "The installer will configure all services with the included Cypher scripts!"
print_color "$CYAN" "=================================================================="
