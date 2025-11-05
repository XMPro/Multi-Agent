# Milvus Vector Database Setup

## Quick Start

Run the installation script which will guide you through configuration options:

```powershell
cd docs/installation/docker/src/milvus
powershell -ExecutionPolicy Bypass -File .\management\install.ps1
```

The installer will ask you about:
1. **GPU Support** - Enable if you have NVIDIA GPU
2. **SSL/TLS** - Enable for encrypted connections
3. **Passwords** - Auto-generate or provide your own

---

## Installation Options

### Standard Installation (CPU, No SSL)
```powershell
.\management\install.ps1
# Answer 'n' to GPU and SSL prompts
```

### GPU-Enabled Installation (NVIDIA GPUs Only)
```powershell
.\management\install.ps1
# Script will detect your GPU vendor (AMD/NVIDIA/Intel)
# GPU option only shown if NVIDIA GPU is detected and available
# Specify GPU device IDs (e.g., "0" or "0,1")
```

**GPU Requirements:**
- NVIDIA GPU with CUDA support (AMD and Intel GPUs are NOT supported)
- Latest NVIDIA drivers installed
- Docker Desktop with WSL2 backend
- NVIDIA Container Toolkit installed in WSL2

**Note:** The installer automatically detects your GPU vendor and only offers GPU support if an NVIDIA GPU is available.

### SSL-Enabled Installation
```powershell
.\management\install.ps1
# Answer 'y' to SSL prompt
# Choose self-signed or CA-provided certificates
```

### Full Installation (GPU + SSL)
```powershell
.\management\install.ps1
# Answer 'y' to both GPU and SSL prompts
```

---

## What Gets Configured

The installation script automatically:
- ✅ Generates secure random MinIO credentials (no more default password warnings)
- ✅ Configures GPU support if requested (modifies docker-compose.yml and milvus.yaml)
- ✅ Sets up SSL/TLS if requested (generates certificates, updates configuration)
- ✅ Creates all necessary directories and configuration files
- ✅ Validates Docker Compose configuration before starting

---

## SSL/TLS Security

### Automatic SSL Configuration

When you enable SSL during installation, the script:
1. Generates self-signed certificates for all services (Milvus, etcd, MinIO)
2. Configures milvus.yaml with TLS mode
3. Updates docker-compose.yml with certificate mounts
4. Sets up Attu to connect via SSL

### SSL Ports and Access
- **Milvus gRPC API**: localhost:19530 (TLS encrypted when SSL enabled)
- **Milvus HTTP API**: localhost:8080 (HTTPS when SSL enabled)
- **MinIO Console**: https://localhost:9001 (HTTPS when SSL enabled)
- **Attu Web UI**: http://localhost:8001 (connects to Milvus via SSL)

### Client Certificate Distribution

**CA Certificate Location**: `tls/ca.pem`

**Install on Client Machines:**
```powershell
# Install CA certificate to Windows trusted root store
Import-Certificate -FilePath "tls\ca.pem" -CertStoreLocation Cert:\LocalMachine\Root
```

**Milvus Client Configuration:**
```python
# Python pymilvus with SSL
from pymilvus import MilvusClient

client = MilvusClient(
    uri="https://localhost:19530",
    secure=True,
    server_pem_path="path/to/ca.pem",
    server_name="localhost"
)
```

---

## GPU Support

### Prerequisites
- NVIDIA GPU with CUDA support
- NVIDIA Docker runtime installed
- Docker Compose v1.28.0 or later

### What Gets Configured

When you enable GPU during installation:
1. Docker image changes to `milvusdb/milvus:v2.6.3-gpu`
2. GPU devices are configured in docker-compose.yml
3. GPU memory pool settings added to milvus.yaml
4. NVIDIA Docker runtime configured

### GPU Memory Configuration

Default settings in `milvus.yaml`:
```yaml
gpu:
  initMemSize: 1024  # Initial GPU memory pool (MB)
  maxMemSize: 2048   # Maximum GPU memory pool (MB)
```

To adjust after installation, edit `milvus.yaml` and restart:
```powershell
docker-compose restart milvus-standalone
```

### Verify GPU Usage
```powershell
# Check GPU is detected
docker exec milvus-standalone nvidia-smi
```

---

# Milvus Vector Database Setup

## Overview
This Docker Compose setup runs a complete Milvus vector database stack on a single Windows machine. Milvus is used for storing and searching vector embeddings (for AI/ML applications like RAG, semantic search, recommendation systems, image similarity, etc.).

## Architecture

```
┌─────────────────────────────────────────────────┐
│                    Attu                         │
│            (Web UI - Port 8001)                 │
└─────────────────┬───────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────┐
│              Milvus Standalone                  │
│         (Vector Database - Port 19530)          │
└──────────┬──────────────────────┬────────────────┘
           │                      │
     ┌─────▼──────┐        ┌─────▼──────┐
     │    etcd    │        │   MinIO    │
     │ (Metadata) │        │  (Storage) │
     └────────────┘        └────────────┘
```

## Components

### 1. **etcd** (Port: Internal only)
**What it does:** Distributed key-value store for metadata  
**Why we need it:** 
- Stores Milvus configuration, collection schemas, and index metadata
- Handles cluster coordination (tracks system state)
- Keeps track of all your collections, fields, and indexes
- Without it: Milvus can't remember what collections you created

**Data stored:** Collection definitions, user permissions, system state  
**Version:** v3.6.5 (Latest stable - better memory usage than v3.5)  
**Resources:** 1 CPU, 2GB RAM limit  
**Data location:** `./milvus-data/etcd/`

---

### 2. **MinIO** (Port: 9001)
**What it does:** S3-compatible object storage  
**Why we need it:** 
- Stores the actual vector data, logs, and index files
- Acts like AWS S3 but runs locally on your machine
- Handles all the heavy data storage (vectors can be huge!)
- Without it: Your vectors have nowhere to live

**Data stored:** Vector embeddings, index files, write-ahead logs  
**Version:** latest (stable and well-maintained)  
**Resources:** 1 CPU, 2GB RAM limit  
**Data location:** `./milvus-data/minio/`  
**Credentials:** Auto-generated during installation (saved in .env and CREDENTIALS.txt)

---

### 3. **Milvus Standalone** (Ports: 19530, 9091)
**What it does:** The main vector database engine  
**Why we need it:** 
- Handles all vector operations (insert, search, query)
- Performs similarity searches using various algorithms (HNSW, IVF, etc.)
- Manages indexes and query optimization
- This is the actual database you connect to from your applications

**Ports:**
- `19530` - Main API endpoint (connect your Python/Node/Java apps here)
- `9091` - Metrics endpoint (for monitoring)

**Version:** v2.6.3 (Latest stable with Storage Format V2, JSON improvements)  
**Resources:** 4 CPU, 8GB RAM limit (this is the workhorse)  
**Data location:** `./milvus-data/milvus/`

---

### 4. **Attu** (Port: 8001)
**What it does:** Web-based GUI for Milvus management  
**Why we need it:** 
- Provides visual interface to browse collections
- Easy data inspection without writing code
- Perform searches and queries through web UI
- Useful for debugging and quick data checks
- **Note:** Now closed-source as of v2.6 (still free to use)

**Access:** http://localhost:8001  
**Version:** v2.6  
**No persistent storage needed** (just a UI layer)

---

## File Structure

```
C:\Docker\milvus\
├── docker-compose.yml          # Main configuration file
├── .env              			# Environment variables for secrets
├── backup.ps1                  # Backup script
├── restore.ps1                 # Restore script
└── milvus-data\                # All persistent data lives here
    ├── etcd\                   # Metadata & configuration
    ├── minio\                  # Vector data & indexes
    ├── milvus\                 # Milvus internal state
    └── backups\                # Your backup storage
```

---

## Backup & Restore

### Manual Offline Backup (Recommended)
```powershell
powershell -ExecutionPolicy Bypass -File .\backup.ps1
```

**What it does:**
1. Stops all Milvus services (ensures data consistency)
2. Creates timestamped backup: `milvus-data\backups\yyyyMMdd_HHmmss\`
3. Backs up:
   - `etcd/` - All collection schemas and metadata
   - `minio/` - All vector data and indexes
   - `milvus/` - Milvus internal state
   - `docker-compose.yml` - Configuration
4. Restarts services

**Expected downtime:** Depends on data size (typically 30 seconds to 5 minutes)

---

### Restore from Backup
```powershell
powershell -ExecutionPolicy Bypass -File .\restore.ps1
```

**What it does:**
1. Shows list of available backups
2. Requires typing "yes" for safety
3. Creates automatic rollback backup (named `timestamp_ROLLBACK`)
4. Stops services
5. Restores all data from selected backup
6. Optionally restores configuration files
7. Restarts services

**Features:**
- ✅ Automatic rollback protection
- ✅ No rollback created when restoring from a rollback (prevents chains)
- ✅ Interactive selection of backup to restore
- ✅ Optional restoration of docker-compose.yml

### Backup Strategy Recommendations

**Development Environment:**
- Backup before major changes
- Keep last 5-10 backups

**Production Environment:**
- Daily automated backups (use Task Scheduler)
- Keep 7 daily + 4 weekly + 3 monthly backups
- Test restores regularly!

**Before Updates:**
```powershell
# Always backup before upgrading Milvus versions
powershell -ExecutionPolicy Bypass -File .\backup.ps1
```

---

### Automated Backups (Windows Task Scheduler)

Create a scheduled task to run backups automatically:

1. Open Task Scheduler
2. Create Basic Task
3. Name: "Milvus Daily Backup"
4. Trigger: Daily at 2:30 AM
5. Action: Start a program
   - Program: `powershell.exe`
   - Arguments: `-ExecutionPolicy Bypass -File "C:\Docker\milvus\backup.ps1"`
   - Start in: `C:\Docker\milvus`

---

## Key Features Enabled

### Health Checks
- Containers wait for dependencies to be healthy before starting
- Prevents startup race conditions
- Auto-restarts on failure with `restart: unless-stopped`

### Resource Limits
- Prevents any single container from eating all system resources
- Milvus gets more resources (4 CPU, 8GB) as it does the heavy lifting
- etcd and MinIO get 1 CPU, 2GB each

### Log Rotation
- Logs limited to 100MB per file, max 3 files
- Prevents disk space exhaustion from runaway logging

---

## Access Points

| Service | URL | Purpose |
|---------|-----|---------|
| Milvus API | `localhost:19530` | Connect your applications here |
| Attu Web UI | http://localhost:8001 | Browse/manage data visually |
| MinIO API | `localhost:9001` | Direct storage access (rarely needed) |
| Metrics | http://localhost:9091 | Prometheus metrics for monitoring |

---

## Important Notes

### Production Readiness
- ✅ Good for single-machine production workloads
- ✅ Data persists across container restarts
- ✅ Automated backup scripts included
- ❌ No high availability (single point of failure)
- ❌ Cannot scale horizontally (need Milvus Cluster for that)

### Security
- **MinIO credentials**: Auto-generated secure random strings during installation
- **Milvus authentication**: Username is always `root`, password is auto-generated
- All credentials saved in `.env` file and `CREDENTIALS.txt`
- To change passwords: Edit `.env` file and restart services

### Versions Used
- **Milvus:** v2.6.3 (Oct 2025) - Latest stable
- **etcd:** v3.6.5 - Latest with 72% memory reduction
- **MinIO:** latest - Stable and widely used
- **Attu:** v2.6 - Now proprietary but free to use

---

## Troubleshooting

### Containers won't start
```cmd
# Check logs
docker-compose logs

# Restart fresh
docker-compose down
docker-compose up -d
```

### Out of memory
- Reduce resource limits in docker-compose.yml
- Close other applications
- Increase Docker Desktop memory allocation

### Can't connect to Milvus
- Verify containers are running: `docker-compose ps`
- Check health: `docker-compose exec standalone curl http://localhost:9091/healthz`
- Review logs: `docker-compose logs milvus-standalone`

### Attu won't connect
- Ensure Milvus is healthy first
- Check connection string in Attu UI matches `milvus-standalone:19530`

### Restore failed
- Check if backup directory exists and contains all folders
- Ensure services are fully stopped before restore
- Check available disk space
- Try restoring from rollback backup if recent restore caused issues

---

## When to Scale Up

Move to Milvus Cluster (distributed) when you need:
- More than 10 million vectors
- High availability (no downtime)
- Horizontal scaling (add more machines)
- Multiple query nodes for better throughput

For now, this standalone setup handles most single-machine use cases efficiently.

---

## Useful Commands

```cmd
# View resource usage
docker stats

# Enter a container
docker-compose exec standalone bash
docker-compose exec minio bash

# Restart single service
docker-compose restart milvus-standalone

# View specific service logs
docker-compose logs -f attu

# Remove everything and start fresh
docker-compose down -v
rm -rf milvus-data/*
docker-compose up -d

```

---

**Last Updated:** October 24, 2025  
**Maintained by:** Gavin Green
