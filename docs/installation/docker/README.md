# Docker Stack Installation

This directory contains scripts for creating and deploying a complete Docker stack with Neo4j, Milvus, and MQTT services.

## Workflow Overview

### 1. Prepare Deployment Package
Run the prepare script to create a deployment ZIP file:

```powershell
.\prepare-stack.ps1
```

**What it does:**
- Copies all service directories from `src/` folder
- Copies Cypher scripts from `docs/installation/` to `neo4j/updates/`
- Creates a comprehensive README for deployment
- Generates a timestamped ZIP file in `dist/` folder

**Options:**
```powershell
# Custom output path and name
.\prepare-stack.ps1 -OutputPath "C:\MyDeployments" -ZipName "my-stack.zip"

# Force overwrite existing ZIP
.\prepare-stack.ps1 -Force
```

### 2. Deploy on Target Machine

#### **Online Deployment (Internet Required):**
Copy the ZIP file and installer script to your target machine:

1. Copy the generated ZIP file (e.g., `docker-stack-20241031-123456.zip`)
2. Copy `management/docker-stack-installer.ps1` separately
3. Run the installer:

```powershell
.\docker-stack-installer.ps1
```

**Automation Parameters (Optional):**
```powershell
# Fully automated SSL installation
.\docker-stack-installer.ps1 -EnableSSL -Domain "mycompany.local" -Neo4jPassword "MyNeo4jPass123!" -MilvusPassword "MyMilvusPass456!" -MqttPassword "MyMqttPass789!" -InstallCertificates

# Automated non-SSL installation
.\docker-stack-installer.ps1 -Neo4jPassword "MyNeo4jPass123!" -MilvusPassword "MyMilvusPass456!" -MqttPassword "MyMqttPass789!"
```

**Available Parameters:**
- `-EnableSSL` - Enable SSL for all services
- `-Domain` - SSL certificate domain (default: localhost)
- `-Neo4jPassword` - Neo4j password (bypasses prompt)
- `-MilvusPassword` - Milvus password (bypasses prompt)
- `-MqttPassword` - MQTT password (bypasses prompt)
- `-InstallCertificates` - Auto-install CA certificates to Windows store
- `-SkipChecks` - Skip prerequisite checks

#### **Offline Deployment (Zero Internet Access):**
For machines with no internet access, create an offline package:

**Development Machine (with Internet):**
```powershell
# Create offline deployment package
.\prepare-stack.ps1 -Offline
```

**Target Machine (Zero Internet Access):**
```powershell
# Step 1: Install Docker Desktop (if needed)
.\Docker-Desktop-Installer.exe

# Step 2: Load pre-downloaded Docker images
docker load -i docker-stack-YYYYMMDD-HHMMSS-docker-images.tar

# Step 3: Deploy services
.\docker-stack-installer.ps1
# All images are pre-loaded, no internet required
```

**What the installer does:**
- Extracts the ZIP file to your chosen directory
- Runs individual install scripts for each service:
  - `neo4j/management/install.ps1` - Sets up Neo4j with SSL support
  - `milvus/management/install.ps1` - Sets up Milvus with SSL support  
  - `mqtt/management/install.ps1` - Sets up MQTT with SSL support
- Starts all services automatically
- Provides connection details and management commands

## Services Included

### Neo4j Graph Database
- **Ports**: 7474 (HTTP), 7473 (HTTPS), 7687 (Bolt/TLS)
- **Features**: SSL/TLS support, automatic Cypher script execution, backup/restore
- **Management**: `neo4j/management/` folder

### Milvus Vector Database  
- **Ports**: 19530 (gRPC), 9091 (HTTP), 9001 (MinIO Console)
- **Features**: SSL/TLS support, vector similarity search, backup/restore
- **Management**: `milvus/management/` folder

### MQTT Message Broker
- **Ports**: 1883 (MQTT), 8883 (MQTT SSL), 9002 (WebSocket)
- **Features**: SSL/TLS support, user management, backup/restore
- **Management**: `mqtt/management/` folder

## SSL/TLS Support

All services support SSL/TLS encryption:

- **Self-signed certificates**: Generated automatically during installation
- **CA-provided certificates**: Install using `manage-ssl.ps1 install-ca` commands
- **Certificate management**: Renewal, status checking, enable/disable

### Self-Signed SSL Certificate Distribution

When using self-signed SSL certificates, client machines need the Certificate Authority (CA) certificate to trust the connections.

#### **CA Certificate Locations (on server)**
After enabling SSL, CA certificates are located at:
- **Neo4j**: `neo4j/certs/bolt/trusted/ca.crt` or `neo4j/certs/https/trusted/ca.crt`
- **Milvus**: `milvus/certs/milvus/trusted/ca.crt`
- **MQTT**: `mqtt/certs/ca.crt`

#### **Client Machine Installation**

**Automatic Installation (Recommended)**
```powershell
# Install all service CA certificates automatically
.\install-ca-certificates.ps1

# Remove all service CA certificates
.\install-ca-certificates.ps1 -Remove

# Show help and usage options
.\install-ca-certificates.ps1 -Help
```

**Manual Installation**
```powershell
# Install CA certificate to Windows trusted root store
Import-Certificate -FilePath "ca.crt" -CertStoreLocation Cert:\LocalMachine\Root

# Or use Certificate Manager GUI
certlm.msc  # Navigate to Trusted Root Certification Authorities > Import
```

#### **Browser Access (Neo4j HTTPS)**
For Neo4j browser access via HTTPS:
1. Navigate to `https://your-server:7473`
2. Browser shows security warning for self-signed certificate
3. **Option A**: Click "Advanced" → "Proceed to site" (accept risk)
4. **Option B**: Install `ca.crt` in browser's certificate store for permanent trust

#### **Production Recommendations**
- **Use proper domain names** instead of localhost when generating certificates
- **Consider CA-provided certificates** for production environments
- **Automate CA distribution** via Group Policy or configuration management tools
- **Certificate rotation**: Set up automated renewal processes

#### **Security Notes**
- **Distribute only CA certificates** (`ca.crt` files) - never private keys
- **Self-signed certificates provide encryption** but not identity verification
- **Clients must explicitly trust** your CA certificate
- **For production**: Consider using certificates from trusted Certificate Authorities

## Management Scripts

Each service includes comprehensive management scripts:

### Installation & Configuration
- `install.ps1` - Interactive installation with SSL options
- `manage-ssl.ps1` - SSL certificate management

### Operations  
- `backup.ps1` - Create service backups
- `restore.ps1` - Restore from backups
- `manage-users.ps1` - User management (MQTT only)

## Directory Structure

```
docs/installation/docker/
├── prepare-stack.ps1           # Creates deployment ZIP
├── docker-stack-installer.ps1  # Deploys and configures services
├── install-ca-certificates.ps1 # Install/remove CA certificates to Windows store
├── README.md                   # This file
├── dist/                       # Generated ZIP files
└── src/                        # Service source files
    ├── neo4j/
    │   ├── docker-compose.yml
    │   ├── .env
    │   └── management/
    │       ├── install.ps1
    │       ├── manage-ssl.ps1
    │       ├── backup.ps1
    │       └── restore.ps1
    ├── milvus/
    │   ├── docker-compose.yml
    │   ├── .env
    │   └── management/
    │       ├── install.ps1
    │       ├── manage-ssl.ps1
    │       ├── backup.ps1
    │       └── restore.ps1
    └── mqtt/
        ├── docker-compose.yml
        ├── .env
        └── management/
            ├── install.ps1
            ├── manage-ssl.ps1
            ├── manage-users.ps1
            ├── backup.ps1
            └── restore.ps1
```

## Requirements

- **Docker Desktop** - Must be installed and running
- **PowerShell 5.0+** - For running installation scripts  
- **Windows 10/11** - Tested on Windows environments

## Quick Start Example

1. **Prepare deployment package:**
   ```powershell
   cd docs/installation/docker
   .\prepare-stack.ps1
```
docs/installation/docker/
├── prepare-stack.ps1           # Creates deployment ZIP
├── README.md                   # This file
├── dist/                       # Generated ZIP files
├── management/                 # Management scripts
│   ├── docker-stack-installer.ps1  # Deploys and configures services
│   └── install-ca-certificates.ps1 # Install/remove CA certificates to Windows store
└── src/                        # Service source files
```

4. **Access services:**
   - Neo4j: http://localhost:7474
   - Milvus: localhost:19530  
   - MQTT: localhost:1883

## Cypher Scripts Integration

The prepare script automatically copies all `.cypher` files from `docs/installation/` into the Neo4j updates folder. These scripts will be executed automatically by the Neo4j watcher service after deployment.

**Cypher Script Execution:**
- Scripts are placed in `neo4j/updates/` folder
- Neo4j watcher monitors this folder for new `.cypher` files
- Scripts are executed automatically and moved to `processed/` folder
- Monitor execution with: `docker-compose logs neo4j-watcher`

## Troubleshooting

### Common Issues
- **Docker not running**: Ensure Docker Desktop is started
- **Port conflicts**: Check if ports are already in use
- **Permission errors**: Run PowerShell as Administrator if needed
- **SSL certificate issues**: Use `manage-ssl.ps1 status` to check certificates

### Logs and Monitoring
```powershell
# View service logs
docker-compose logs -f neo4j
docker-compose logs -f milvus  
docker-compose logs -f mosquitto

# Check service status
docker-compose ps
```

### Management Commands
```powershell
# SSL management
.\management\manage-ssl.ps1 status
.\management\manage-ssl.ps1 generate -Domain "your-domain.com"

# User management (MQTT)
.\management\manage-users.ps1 list
.\management\manage-users.ps1 add -Username "newuser"

# Backup services
.\management\backup.ps1
