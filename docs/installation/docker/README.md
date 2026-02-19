# Docker Stack Installation

This directory contains scripts for creating and deploying a complete Docker stack with Neo4j, Milvus, MQTT, TimescaleDB, and Ollama services.

## Platform Selection

Both platforms deploy the same services with identical functionality:
- **Neo4j** - Graph database for knowledge graphs and relationships
- **Milvus** - Vector database for embeddings and similarity search
- **MQTT** - Message broker for real-time communication
- **TimescaleDB** - Time-series database for temporal data and metrics
- **Ollama** - Local LLM provider for AI inference and embeddings

## Quick Start

| Scenario | Development Machine | Target Machine | Steps |
|----------|-------------------|----------------|-------|
| **1. Windows → Windows** | Windows | Windows | **Dev:** `cd windows` → `.\prepare-stack.ps1`<br>**Copy:** `windows/dist/docker-stack-*.zip` + `windows/dist/docker-stack-installer.ps1`<br>**Target:** `.\docker-stack-installer.ps1` |
| **2. Windows → Linux** | Windows | Linux | **Dev:** `cd windows` → `.\prepare-stack.ps1`<br>**Copy:** `windows/dist/docker-stack-*.zip` + `linux/management/docker-stack-installer.sh`<br>**Target:** `chmod +x docker-stack-installer.sh` → `./docker-stack-installer.sh` |
| **3. Linux → Linux** | Linux | Linux | **Dev:** `cd linux` → `chmod +x prepare-stack.sh` → `./prepare-stack.sh`<br>**Copy:** `linux/dist/docker-stack-*.zip` + `linux/dist/docker-stack-installer.sh`<br>**Target:** `chmod +x docker-stack-installer.sh` → `./docker-stack-installer.sh` |
| **4. Linux → Windows** | Linux | Windows | **Dev:** `cd linux` → `chmod +x prepare-stack.sh` → `./prepare-stack.sh`<br>**Copy:** `linux/dist/docker-stack-*.zip` + `windows/management/docker-stack-installer.ps1`<br>**Target:** `.\docker-stack-installer.ps1` |

**Key Points:**
- 📦 The ZIP file is **platform-agnostic** (contains Docker Compose configs)
- 🔧 Use the **prepare script** that matches your **development machine**
- 🚀 Use the **installer script** that matches your **target machine**
- 🔄 You can mix and match platforms (prepare on one, deploy to another)

## Directory Structure

```
docs/installation/docker/
├── README.md                    # This file - platform selection
├── complete-deployment-flowchart.md
├── windows/                     # Windows-specific scripts
│   ├── README.md               # Windows installation guide
│   ├── prepare-stack.ps1       # Create deployment package
│   ├── management/
│   │   ├── docker-stack-installer.ps1
│   │   ├── install-ca-certificates.ps1
│   │   └── stop-all-services.ps1
│   └── dist/                   # Generated packages
├── linux/                       # Linux-specific scripts
│   ├── README.md               # Linux installation guide
│   ├── prepare-stack.sh        # Create deployment package
│   ├── management/
│   │   ├── docker-stack-installer.sh
│   │   ├── install-ca-certificates.sh
│   │   └── stop-all-services.sh
│   └── dist/                   # Generated packages
└── src/                        # Shared service configurations
    ├── neo4j/
    │   ├── docker-compose.yml  # Works on both platforms
    │   ├── watcher.py
    │   └── management/
    │       ├── install.ps1 / install.sh
    │       ├── backup.ps1 / backup.sh
    │       ├── restore.ps1 / restore.sh
    │       └── manage-ssl.ps1 / manage-ssl.sh
    ├── milvus/
    │   ├── docker-compose.yml
    │   └── management/
    │       └── (similar scripts)
    └── mqtt/
        ├── docker-compose.yml
        └── management/
            └── (similar scripts)
```

## Features

### Common Features (Both Platforms)
- ✅ Interactive installation with guided prompts
- ✅ SSL/TLS support with self-signed or CA certificates
- ✅ Automatic password generation
- ✅ Comprehensive backup and restore
- ✅ Offline/airgapped deployment support
- ✅ Automatic Cypher script execution (Neo4j)
- ✅ User management (MQTT)
- ✅ Health monitoring and status checks

### Platform-Specific Features

**Windows:**
- PowerShell 5.0+ scripts
- Docker Desktop integration
- Windows Certificate Store integration
- GUI file browser for ZIP selection

**Linux:**
- Bash 4.0+ scripts
- Docker Engine support
- Distribution-specific certificate installation (Ubuntu/Debian/RHEL/CentOS)
- Systemd service integration

## Workflow Overview

### 1. Prepare Deployment Package

**Purpose:** Create a deployment ZIP file containing all service configurations and scripts.

**Windows:**
```powershell
cd windows
.\prepare-stack.ps1
```

**Linux:**
```bash
cd linux
chmod +x prepare-stack.sh
./prepare-stack.sh
```

**What it does:**
- Copies all service directories from `../src/` folder
- Copies Cypher scripts from `docs/installation/` to `neo4j/updates/`
- Downloads Python packages for offline Neo4j watcher
- Creates a comprehensive README for deployment
- Generates a timestamped ZIP file in `dist/` folder
- Copies installer script to `dist/` folder

**Options:**

Windows:
```powershell
# Custom output path and name
.\prepare-stack.ps1 -OutputPath "C:\MyDeployments" -ZipName "my-stack.zip"

# Force overwrite existing ZIP
.\prepare-stack.ps1 -Force

# Create offline package with Docker images
.\prepare-stack.ps1 -Offline
```

Linux:
```bash
# Custom output path and name
./prepare-stack.sh --output /path/to/output --name my-stack.zip

# Force overwrite existing ZIP
./prepare-stack.sh --force

# Create offline package with Docker images
./prepare-stack.sh --offline
```

### 2. Deploy on Target Machine

#### Online Deployment (Internet Required)

Copy the deployment files to your target machine:
1. Copy `docker-stack-installer.ps1` (Windows) or `docker-stack-installer.sh` (Linux)
2. Copy the generated ZIP file from `dist/` folder
3. Place both files in your desired installation directory

**Windows:**
```powershell
.\docker-stack-installer.ps1
```

**Linux:**
```bash
chmod +x docker-stack-installer.sh
./docker-stack-installer.sh
```

**Password Handling (Production-Safe):**

Passwords are handled securely through:
1. **Environment variables** (recommended for CI/CD)
2. **Interactive prompts** (recommended for manual deployment)
3. **Auto-generation** (if not provided)

**Never pass passwords as command-line parameters in production!**

**Interactive Deployment (Recommended):**

Windows:
```powershell
# Script will prompt for passwords securely
.\docker-stack-installer.ps1 -EnableSSL -Domain "mycompany.local" -InstallCertificates
```

Linux:
```bash
# Script will prompt for passwords securely
./docker-stack-installer.sh --enable-ssl --domain mycompany.local --install-certificates
```

**Automated Deployment (CI/CD):**

Windows:
```powershell
# Set passwords from secure vault (Azure Key Vault, AWS Secrets Manager, etc.)
$env:NEO4J_PASSWORD = (Get-SecretFromVault "Neo4jPassword")
$env:MILVUS_PASSWORD = (Get-SecretFromVault "MilvusPassword")
$env:MQTT_PASSWORD = (Get-SecretFromVault "MqttPassword")

# Run installer in automation mode
.\docker-stack-installer.ps1 -EnableSSL -Domain "mycompany.local" -AutoStart -InstallCertificates
```

Linux:
```bash
# Set passwords from secure vault
export NEO4J_PASSWORD=$(get-secret-from-vault "Neo4jPassword")
export MILVUS_PASSWORD=$(get-secret-from-vault "MilvusPassword")
export MQTT_PASSWORD=$(get-secret-from-vault "MqttPassword")

# Run installer in automation mode
./docker-stack-installer.sh --enable-ssl --domain mycompany.local --auto-start --install-certificates
```

**Fully Automated (Auto-generate passwords):**

Windows:
```powershell
# Passwords will be auto-generated and saved to CREDENTIALS.txt
.\docker-stack-installer.ps1 -EnableSSL -Domain "mycompany.local" -AutoStart -InstallCertificates
```

Linux:
```bash
# Passwords will be auto-generated and saved to CREDENTIALS.txt
./docker-stack-installer.sh --enable-ssl --domain mycompany.local --auto-start --install-certificates
```

#### Offline Deployment (Zero Internet Access)

For machines with no internet access, create an offline package:

**Development Machine (with Internet):**

Windows:
```powershell
.\prepare-stack.ps1 -Offline
```

Linux:
```bash
./prepare-stack.sh --offline
```

**Target Machine (Zero Internet Access):**

Windows:
```powershell
# Step 1: Install Docker Desktop (if needed)
.\Docker-Desktop-Installer.exe

# Step 2: Load pre-downloaded Docker images
docker load -i docker-stack-YYYYMMDD-HHMMSS-docker-images.tar

# Step 3: Deploy services
.\docker-stack-installer.ps1
```

Linux:
```bash
# Step 1: Install Docker Engine (if needed)
# Ubuntu/Debian:
sudo apt-get install -y docker.io docker-compose

# RHEL/CentOS:
sudo yum install -y docker docker-compose

# Step 2: Load pre-downloaded Docker images
docker load -i docker-stack-YYYYMMDD-HHMMSS-docker-images.tar

# Step 3: Deploy services
chmod +x docker-stack-installer.sh
./docker-stack-installer.sh
```

## Services Included

### Neo4j Graph Database
- **Ports**: 7474 (HTTP), 7473 (HTTPS), 7687 (Bolt/TLS)
- **Features**: SSL/TLS support, automatic Cypher script execution, backup/restore
- **Default User**: neo4j (password set during installation)

### Milvus Vector Database
- **Ports**: 19530 (gRPC), 9091 (HTTP), 9001 (MinIO Console), 8002 (Attu UI)
- **Features**: SSL/TLS support, vector similarity search, backup/restore
- **Default User**: root (password set during installation)

### MQTT Message Broker
- **Ports**: 1883 (MQTT), 8883 (MQTT SSL), 9002 (WebSocket)
- **Features**: SSL/TLS support, user management, backup/restore
- **Default User**: xmpro (password set during installation)

### TimescaleDB Time-Series Database
- **Ports**: 5432 (PostgreSQL), 5050/5051 (pgAdmin)
- **Features**: SSL/TLS support, automated backups, hypertables, continuous aggregates
- **Default User**: postgres (password set during installation)

### Ollama Local LLM Provider
- **Ports**: 11434 (HTTP API), 11443 (HTTPS with reverse proxy)
- **Features**: Local LLM inference, embedding generation, GPU acceleration, offline operation
- **Models**: User-selected (not included in offline package due to size)

## SSL/TLS Support

All services support SSL/TLS encryption:

- **Self-signed certificates**: Generated automatically during installation
- **CA-provided certificates**: Install using `manage-ssl` commands
- **Certificate management**: Renewal, status checking, enable/disable

### Certificate Distribution

When using self-signed SSL certificates, client machines need the CA certificate.

**CA Certificate Locations (on server):**
- **Neo4j**: `neo4j/certs/bolt/trusted/ca.crt`
- **Milvus**: `milvus/tls/ca.pem`
- **MQTT**: `mqtt/certs/ca.crt`

**Client Machine Installation:**

Windows:
```powershell
# Automatic installation
.\management\install-ca-certificates.ps1

# Manual installation
Import-Certificate -FilePath "ca.crt" -CertStoreLocation Cert:\LocalMachine\Root
```

Linux:
```bash
# Automatic installation
./management/install-ca-certificates.sh

# Manual installation (Ubuntu/Debian)
sudo cp ca.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates

# Manual installation (RHEL/CentOS)
sudo cp ca.crt /etc/pki/ca-trust/source/anchors/
sudo update-ca-trust
```

## Management Scripts

Each service includes comprehensive management scripts in both PowerShell (.ps1) and Bash (.sh) formats:

### Installation & Configuration
- `install` - Interactive installation with SSL options
- `manage-ssl` - SSL certificate management

### Operations
- `backup` - Create service backups
- `restore` - Restore from backups
- `manage-users` - User management (MQTT only)

### Stack-Level Management
- `docker-stack-installer` - Deploy and configure all services
- `install-ca-certificates` - Install/remove CA certificates
- `stop-all-services` - Stop all services at once

## Requirements

### Windows
- **Docker Desktop** - Must be installed and running
- **PowerShell 5.0+** - For running installation scripts
- **Windows 10/11** - Tested on Windows environments

### Linux
- **Docker Engine** - Must be installed and running
- **Docker Compose** - V2 or later
- **Bash 4.0+** - For running installation scripts
- **Linux** - Tested on Ubuntu 20.04+, Debian 11+, RHEL 8+, CentOS 8+

## After Installation

The installer automatically creates a **CREDENTIALS.txt** file containing:
- All usernames and passwords for each service
- Access URLs (HTTP, HTTPS, WebSocket, Bolt, etc.)
- SSL certificate locations (if SSL enabled)
- MinIO access keys and secrets
- Management commands reference

**IMPORTANT: Keep this file secure and do not commit it to version control!**

## Troubleshooting

### Common Issues

**Docker not running:**
- Windows: Ensure Docker Desktop is started
- Linux: `sudo systemctl start docker`

**Port conflicts:**
- Check if ports are already in use: `netstat -an | grep LISTEN` (Linux) or `netstat -an | findstr LISTEN` (Windows)

**Permission errors:**
- Windows: Run PowerShell as Administrator
- Linux: Ensure user is in docker group: `sudo usermod -aG docker $USER`

**SSL certificate issues:**
- Use `manage-ssl status` to check certificates
- Verify CA certificates are installed on client machines

**CA Certificate Installation Requires Elevated Privileges:**

The `install-ca-certificates` script requires administrator/root privileges to install certificates to the system trust store.

Windows:
```powershell
# Run PowerShell as Administrator, then:
.\management\install-ca-certificates.ps1
```

Linux:
```bash
# Use sudo to run with root privileges:
sudo ./management/install-ca-certificates.sh

# If running from management subfolder:
cd management
sudo ./install-ca-certificates.sh
```

**Why elevated privileges are required:**
- System certificate stores are protected system resources
- Installing CA certificates affects all users and applications on the system
- This is a security feature to prevent unauthorized certificate installation

**Alternative for non-admin users:**
- Windows: Certificates can be installed to CurrentUser store (limited to your user account)
- Linux: Manual installation to user-specific certificate stores (application-dependent)

### Logs and Monitoring

```bash
# View service logs
docker-compose logs -f neo4j
docker-compose logs -f milvus
docker-compose logs -f mosquitto

# Check service status
docker-compose ps
```

### Management Commands

Windows:
```powershell
# Stop all services
.\management\stop-all-services.ps1

# Stop all services and remove data
.\management\stop-all-services.ps1 -RemoveVolumes

# SSL management
.\neo4j\management\manage-ssl.ps1 status
.\neo4j\management\manage-ssl.ps1 generate -Domain "your-domain.com"

# User management (MQTT)
.\mqtt\management\manage-users.ps1 list
.\mqtt\management\manage-users.ps1 add -Username "newuser"
```

Linux:
```bash
# Stop all services
./management/stop-all-services.sh

# Stop all services and remove data
./management/stop-all-services.sh --remove-volumes

# SSL management
./neo4j/management/manage-ssl.sh status
./neo4j/management/manage-ssl.sh generate --domain your-domain.com

# User management (MQTT)
./mqtt/management/manage-users.sh list
./mqtt/management/manage-users.sh add --username newuser
```

## Cypher Scripts Integration

The prepare script automatically copies all `.cypher` files from `docs/installation/` into the Neo4j updates folder. These scripts will be executed automatically by the Neo4j watcher service after deployment.

**Cypher Script Execution:**
- Scripts are placed in `neo4j/updates/` folder
- Neo4j watcher monitors this folder for new `.cypher` files
- Scripts are executed automatically and moved to `processed/` folder
- Monitor execution with: `docker-compose logs neo4j-watcher`

## Support

For service-specific documentation:
- **Neo4j**: See `src/neo4j/neo4j_readme.md`
- **Milvus**: See `src/milvus/milvus_readme.md`
- **MQTT**: See `src/mqtt/mqtt_readme.md`
- **TimescaleDB**: See `src/timescaledb/timescaledb_readme.md`
- **Ollama**: See `src/ollama/ollama_readme.md`
