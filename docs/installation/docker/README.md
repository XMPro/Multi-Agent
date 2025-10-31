# Docker Stack - Neo4j, Milvus, and MQTT

A complete Docker stack with Neo4j graph database, Milvus vector database, and MQTT broker, designed for production use with comprehensive management tools.

## 🚀 One-Click Installation

### Prerequisites
- Windows 10/11 with PowerShell 5.0+
- Docker Desktop installed and running
- OpenSSL (optional, for SSL certificate generation)

### Quick Start

1. **Download the ZIP file** containing the Docker stack
2. **Run the installer script:**
   ```powershell
   .\docker-stack-installer.ps1
   ```
3. **Follow the prompts:**
   - Select the ZIP file location
   - Choose installation directory
   - Configure environment variables for each service
   - Wait for services to start

The installer will:
- ✅ Check prerequisites (Docker, OpenSSL, PowerShell)
- ✅ Extract the ZIP file to your chosen location
- ✅ Configure environment variables for all services
- ✅ Initialize MQTT authentication with secure passwords
- ✅ Start all Docker services
- ✅ Verify service status

## 📁 Directory Structure

```
docker-stack/
├── docker-stack-installer.ps1    # One-click installer
├── README.md                      # This file
├── neo4j/
│   ├── docker-compose.yml
│   ├── .env
│   ├── neo4j_readme.md
│   └── management/
│       ├── backup.ps1
│       └── restore.ps1
├── milvus/
│   ├── docker-compose.yml
│   ├── .env
│   ├── milvus_readme.md
│   └── management/
│       ├── backup.ps1
│       └── restore.ps1
└── mqtt/
    ├── docker-compose.yml
    ├── .env
    ├── mqtt_readme.md
    ├── config/
    │   ├── mosquitto.conf
    │   ├── passwords.txt
    │   └── acl.txt
    └── management/
        ├── install.ps1
        ├── backup.ps1
        ├── restore.ps1
        ├── manage-users.ps1
        └── manage-ssl.ps1
```

## 🌐 Service Access

After installation, services will be available at:

### Neo4j
- **Browser UI:** http://localhost:7474
- **Bolt Protocol:** bolt://localhost:7687
- **Default Auth:** neo4j/password123 (configurable during install)

### Milvus
- **API Endpoint:** localhost:19530
- **Web UI:** http://localhost:9091
- **MinIO Console:** http://localhost:9001

### MQTT
- **Broker:** localhost:1883
- **WebSocket:** ws://localhost:9001
- **SSL/TLS:** localhost:8883 (if enabled)
- **Default User:** xmpro (with generated secure password)

## 🔧 Management

### Backup Services
Each service has backup scripts in their `management` folder:

```powershell
# Neo4j backup
cd neo4j
.\management\backup.ps1

# Milvus backup
cd milvus
.\management\backup.ps1

# MQTT backup
cd mqtt
.\management\backup.ps1
```

### Restore Services
```powershell
# Neo4j restore
cd neo4j
.\management\restore.ps1 -BackupPath "neo4j-data\backups\20241024_140000"

# Milvus restore
cd milvus
.\management\restore.ps1 -BackupPath "milvus-data\backups\20241024_140000"

# MQTT restore
cd mqtt
.\management\restore.ps1 -BackupPath "data\backups\20241024_140000"
```

### MQTT User Management
```powershell
cd mqtt

# Add user
.\management\manage-users.ps1 add -Username "newuser"

# Remove user
.\management\manage-users.ps1 remove -Username "olduser"

# List users
.\management\manage-users.ps1 list

# Change password
.\management\manage-users.ps1 change-password -Username "user"
```

### MQTT SSL Management
```powershell
cd mqtt

# Generate SSL certificates
.\management\manage-ssl.ps1 generate

# Enable SSL
.\management\manage-ssl.ps1 enable

# Check SSL status
.\management\manage-ssl.ps1 status
```

## 🔄 Service Control

### Start Services
```powershell
# Start all services
docker-compose -f neo4j/docker-compose.yml -f milvus/docker-compose.yml -f mqtt/docker-compose.yml up -d

# Or start individually
cd neo4j && docker-compose up -d
cd milvus && docker-compose up -d
cd mqtt && docker-compose up -d
```

### Stop Services
```powershell
# Stop all services
docker-compose -f neo4j/docker-compose.yml -f milvus/docker-compose.yml -f mqtt/docker-compose.yml down

# Or stop individually
cd neo4j && docker-compose down
cd milvus && docker-compose down
cd mqtt && docker-compose down
```

### Check Status
```powershell
# Check all services
docker-compose -f neo4j/docker-compose.yml ps
docker-compose -f milvus/docker-compose.yml ps
docker-compose -f mqtt/docker-compose.yml ps
```

## 📊 Monitoring

### View Logs
```powershell
# Neo4j logs
cd neo4j && docker-compose logs -f

# Milvus logs
cd milvus && docker-compose logs -f

# MQTT logs
cd mqtt && docker-compose logs -f
```

### Health Checks
All services include health checks in their Docker configurations. Check container health with:
```powershell
docker ps
```

## 🛠️ Troubleshooting

### Common Issues

1. **Services won't start:**
   - Ensure Docker Desktop is running
   - Check port conflicts (7474, 7687, 19530, 9091, 1883, 8883, 9001)
   - Review logs: `docker-compose logs [service-name]`

2. **MQTT authentication fails:**
   - Check password file: `mqtt\config\passwords.txt`
   - Regenerate passwords: `.\management\manage-users.ps1 change-password`

3. **Neo4j browser won't load:**
   - Wait for initialization (can take 30-60 seconds)
   - Check if port 7474 is available
   - Verify credentials in `.env` file

4. **Milvus connection issues:**
   - Ensure all dependencies (etcd, minio) are running
   - Check network connectivity between containers
   - Verify MinIO credentials in `.env` file

### Reset Everything
```powershell
# Stop all services
docker-compose -f neo4j/docker-compose.yml down -v
docker-compose -f milvus/docker-compose.yml down -v
docker-compose -f mqtt/docker-compose.yml down -v

# Remove all data (WARNING: This deletes all data!)
Remove-Item -Recurse -Force neo4j\neo4j-data, milvus\milvus-data, mqtt\data

# Restart installation
.\docker-stack-installer.ps1
```

## 📝 Configuration

### Environment Variables
Each service has its own `.env` file with configurable parameters:

- **neo4j\.env** - Database authentication, plugins, memory settings
- **milvus\.env** - Storage configuration, etcd/minio settings
- **mqtt\.env** - Port configuration, SSL settings, authentication

### Persistent Data
All services store data in local directories:
- **Neo4j:** `neo4j\neo4j-data\`
- **Milvus:** `milvus\milvus-data\`
- **MQTT:** `mqtt\data\`

## 🔐 Security

- All services require authentication
- MQTT supports SSL/TLS encryption
- Passwords are securely hashed
- Access control lists (ACL) for MQTT topics
- Regular backup capabilities
- Network isolation through Docker networks

## 📚 Documentation

Detailed documentation for each service:
- **Neo4j:** `neo4j\neo4j_readme.md`
- **Milvus:** `milvus\milvus_readme.md`
- **MQTT:** `mqtt\mqtt_readme.md`

---

**Version:** 1.0  
**Last Updated:** October 2024  
**Compatibility:** Windows 10/11, Docker Desktop, PowerShell 5.0+
