# Ollama Local LLM Setup

## Overview

This setup provides instructions and scripts for deploying Ollama as a local Large Language Model provider for the XMPro AI Agents system. Ollama enables you to run LLMs locally without relying on cloud-based API providers, offering cost savings, data privacy, and reduced latency.

---

## Architecture

```
┌─────────────────────────────────────────────────┐
│         XMPro AI Agents System                  │
│    (Connects to Ollama via REST API)            │
└─────────────────┬───────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────┐
│              Ollama Service                     │
│         (HTTP API - Port 11434)                 │
│                                                  │
│  ┌──────────────────────────────────────────┐  │
│  │   Embedding Models                       │  │
│  │   • nomic-embed-text (768 dimensions)    │  │
│  │   • mxbai-embed-large (1024 dimensions)  │  │
│  └──────────────────────────────────────────┘  │
│                                                  │
│  ┌──────────────────────────────────────────┐  │
│  │   Inference Models (Examples)            │  │
│  │   • llama3.2 (3B parameters)             │  │
│  │   • llama3.1 (8B parameters)             │  │
│  │   • mistral (7B parameters)              │  │
│  │   • qwen2.5 (7B parameters)              │  │
│  │   • deepseek-r1:8b (8B parameters)       │  │
│  └──────────────────────────────────────────┘  │
└──────────────────────────────────────────────────┘
```

---

## Components

### 1. Ollama Runtime

- **Default Port:** 11434 (HTTP REST API)
- **Protocol:** HTTP/HTTPS
- **API:** OpenAI-compatible endpoints
- **GPU Support:** NVIDIA CUDA, AMD ROCm, Apple Metal
- **CPU Fallback:** Automatic if no GPU detected

### 2. Required Models for XMPro AI Agents

**Embedding Models (Required - Choose at least one):**
- `nomic-embed-text:latest` - 768 dimensions, 2048 max tokens
- `mxbai-embed-large:latest` - 1024 dimensions, 512 max tokens

**Inference Models (Recommended):**
- `llama3.2:3b` - Fast, efficient, good for general tasks (3B parameters)
- `llama3.1:8b` - Balanced performance and quality (8B parameters)
- `mistral:7b` - Excellent for reasoning tasks (7B parameters)
- `qwen2.5:7b` - Strong multilingual support (7B parameters)
- `deepseek-r1:8b` - Advanced reasoning capabilities (8B parameters)

**Note:** You can choose any models from the Ollama library that suit your needs. The above are recommendations based on common use cases.

---

## Installation Methods

### Option 1: Docker Deployment (Recommended)

**Advantages:**
- Isolated environment
- Easy updates and rollbacks
- Consistent across different host systems
- GPU passthrough support
- Automatic restarts

**Disadvantages:**
- Additional Docker overhead
- Requires Docker knowledge
- Model storage in Docker volumes

### Option 2: Native Installation

**Advantages:**
- Direct GPU access
- Lower overhead
- Easier model management
- Better performance on Windows/macOS

**Disadvantages:**
- System-wide installation
- Manual updates required
- OS-specific configurations

---

## Docker Deployment

### File Structure

```
C:\Docker\ollama\
├── docker-compose.yml           # Main configuration
├── .env                         # Environment variables
├── management\
│   ├── install.ps1             # Windows installation script
│   ├── install.sh              # Linux installation script
│   ├── pull-models.ps1         # Windows model downloader
│   ├── pull-models.sh          # Linux model downloader
│   ├── manage-ollama.ps1       # Windows management script
│   ├── manage-ollama.sh        # Linux management script
│   ├── manage-ssl.ps1          # Windows SSL management
│   └── manage-ssl.sh           # Linux SSL management
└── ollama-data\                # Model storage (Docker volume)
```

### Prerequisites

**Both Platforms:**
- Docker Engine installed and running
- Docker Compose V2 or later
- Minimum 8GB RAM (16GB+ recommended)
- 20GB+ free disk space (models can be large)

**For GPU Support:**
- **NVIDIA:** NVIDIA Docker runtime installed
- **AMD:** ROCm drivers and Docker support
- **Apple:** Docker Desktop for Mac with Metal support

### Installation Scripts

The installation scripts handle:
1. Docker availability verification
2. Directory structure creation
3. Environment file (.env) setup
4. Docker Compose deployment
5. Service health checks
6. Model pulling (embedding models + chosen inference models)

**Scripts will prompt for:**
- Port configuration (default: 11434)
- GPU enablement (NVIDIA/AMD/None)
- Model selection (which models to download)
- Auto-start on system boot

---

## Native Installation

### Windows

**System Requirements:**
- Windows 10/11 (64-bit)
- 8GB RAM minimum (16GB+ recommended)
- GPU: NVIDIA (CUDA) or AMD (ROCm) optional

**Installation Steps:**
1. Download Ollama for Windows from https://ollama.ai
2. Run the installer (OllamaSetup.exe)
3. Ollama runs as a background service automatically
4. Open PowerShell and verify: `ollama --version`

**Default Installation Path:**
- Executable: `C:\Users\<username>\AppData\Local\Programs\Ollama\`
- Models: `C:\Users\<username>\.ollama\models\`

### Linux

**System Requirements:**
- Ubuntu 20.04+, Debian 11+, RHEL 8+, or similar
- 8GB RAM minimum (16GB+ recommended)
- GPU: NVIDIA (CUDA) or AMD (ROCm) optional

**Installation Steps:**

```bash
# Download and install Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# Verify installation
ollama --version

# Start Ollama service (systemd)
sudo systemctl start ollama
sudo systemctl enable ollama

# Check service status
sudo systemctl status ollama
```

**Default Installation Path:**
- Executable: `/usr/local/bin/ollama`
- Models: `/usr/share/ollama/.ollama/models/`
- Service: `/etc/systemd/system/ollama.service`

### macOS

**System Requirements:**
- macOS 11 Big Sur or later
- 8GB RAM minimum (16GB+ recommended)
- Apple Silicon (M1/M2/M3) or Intel

**Installation Steps:**

```bash
# Download and install Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# Or download from https://ollama.ai and install the .dmg

# Verify installation
ollama --version

# Ollama runs automatically as a service
```

**Default Installation Path:**
- Application: `/Applications/Ollama.app`
- Models: `~/.ollama/models/`

---

## Pulling Models

### Required Embedding Models

**Pull both embedding models (or at least one):**

```bash
# Nomic Embed Text (768 dimensions)
ollama pull nomic-embed-text:latest

# MxBai Embed Large (1024 dimensions)
ollama pull mxbai-embed-large:latest
```

### Recommended Inference Models

**Choose based on your hardware capabilities:**

```bash
# Small/Fast - Good for low-end hardware (3B parameters, ~2GB)
ollama pull llama3.2:3b

# Medium - Balanced quality and speed (7-8B parameters, ~4-5GB each)
ollama pull llama3.1:8b
ollama pull mistral:7b
ollama pull qwen2.5:7b
ollama pull deepseek-r1:8b

# Large - Best quality, requires more resources (70B+ parameters, ~40GB+)
ollama pull llama3.1:70b
ollama pull qwen2.5:72b
```

### Model Selection Guide

| Hardware Profile | Recommended Models | Total Disk Space |
|-----------------|-------------------|------------------|
| **Minimal** (8GB RAM, CPU) | nomic-embed-text + llama3.2:3b | ~3GB |
| **Standard** (16GB RAM, GPU 8GB) | Both embeddings + llama3.1:8b + mistral:7b | ~12GB |
| **Performance** (32GB RAM, GPU 16GB) | Both embeddings + qwen2.5:7b + deepseek-r1:8b | ~15GB |
| **High-End** (64GB+ RAM, GPU 24GB+) | Both embeddings + llama3.1:70b | ~45GB |

---

## Configuration

### Environment Variables

**Docker Deployment (.env file):**

```env
# Ollama Configuration
OLLAMA_HOST=0.0.0.0
OLLAMA_PORT=11434
OLLAMA_ORIGINS=*

# GPU Support (NVIDIA)
OLLAMA_GPU_DRIVER=nvidia
OLLAMA_GPU_LAYERS=999  # Use all available GPU layers

# Model Storage
OLLAMA_MODELS=/root/.ollama/models

# Performance Tuning
OLLAMA_NUM_PARALLEL=4        # Number of parallel requests
OLLAMA_MAX_LOADED_MODELS=2   # Keep 2 models in memory
OLLAMA_KEEP_ALIVE=5m         # Keep models loaded for 5 minutes
```

**Native Installation:**

Linux/macOS - Edit `/etc/systemd/system/ollama.service` or create `~/.ollama/config`:
```bash
# Set environment variables
export OLLAMA_HOST=0.0.0.0:11434
export OLLAMA_ORIGINS=*
export OLLAMA_NUM_PARALLEL=4
export OLLAMA_MAX_LOADED_MODELS=2
```

Windows - Set via PowerShell (persistent):
```powershell
[Environment]::SetEnvironmentVariable("OLLAMA_HOST", "0.0.0.0:11434", "Machine")
[Environment]::SetEnvironmentVariable("OLLAMA_ORIGINS", "*", "Machine")
[Environment]::SetEnvironmentVariable("OLLAMA_NUM_PARALLEL", "4", "Machine")
[Environment]::SetEnvironmentVariable("OLLAMA_MAX_LOADED_MODELS", "2", "Machine")

# Restart Ollama service
Restart-Service Ollama
```

## Networking & Security

### Exposing Ollama API

**Docker Deployment:**

The `docker-compose.yml` exposes port 11434 by default:
```yaml
ports:
  - "11434:11434"
```

**Native Installation:**

Ollama listens on `localhost:11434` by default. To expose to network:

Linux:
```bash
# Edit service file
sudo systemctl edit ollama

# Add environment variable
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"

# Restart service
sudo systemctl restart ollama
```

Windows:
```powershell
# Set environment variable
[Environment]::SetEnvironmentVariable("OLLAMA_HOST", "0.0.0.0:11434", "Machine")

# Restart service
Restart-Service Ollama
```

### Firewall Configuration

**Allow Ollama Port:**

Windows:
```powershell
New-NetFirewallRule -DisplayName "Ollama API" -Direction Inbound -LocalPort 11434 -Protocol TCP -Action Allow
```

Linux (ufw):
```bash
sudo ufw allow 11434/tcp
sudo ufw reload
```

Linux (firewalld):
```bash
sudo firewall-cmd --permanent --add-port=11434/tcp
sudo firewall-cmd --reload
```

### SSL/TLS Support

Ollama doesn't natively support SSL/TLS. For secure connections, use a reverse proxy:

**Option 1: Nginx Reverse Proxy**

```nginx
server {
    listen 443 ssl;
    server_name ollama.yourdomain.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass http://localhost:11434;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

**Option 2: Caddy (Automatic HTTPS)**

```
ollama.yourdomain.com {
    reverse_proxy localhost:11434
}
```

---

## Testing & Validation

### Test Ollama Service

**Check service status:**

```bash
# Test API endpoint
curl http://localhost:11434/api/version

# Expected response:
# {"version":"0.x.x"}
```

### Test Embedding Models

```bash
# Test nomic-embed-text
curl http://localhost:11434/api/embeddings -d '{
  "model": "nomic-embed-text:latest",
  "prompt": "This is a test embedding"
}'

# Should return an array of 768 floating-point numbers
```

### Test Inference Models

```bash
# Test llama3.2
curl http://localhost:11434/api/generate -d '{
  "model": "llama3.2:3b",
  "prompt": "Explain quantum computing in simple terms.",
  "stream": false
}'

# Should return a JSON response with generated text
```

### Integration Test with XMPro

**From your XMPro AI Agents system:**

1. Configure Ollama as an AI Provider
2. Test embedding generation:
   - Select Ollama as embedding provider
   - Use `nomic-embed-text:latest` model
   - Generate embeddings for sample text
3. Test inference:
   - Create a test agent profile using Ollama
   - Select one of your pulled models (e.g., `llama3.2:3b`)
   - Send a test query and verify response

---

## Performance Optimization

### Hardware Acceleration

**NVIDIA GPU (CUDA):**

Docker:
```yaml
services:
  ollama:
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
```

Native: Automatically detected and used.

**AMD GPU (ROCm):**

Docker: Requires ROCm Docker runtime
Native: Set `HSA_OVERRIDE_GFX_VERSION` if needed

**Apple Silicon (Metal):**

Native: Automatically uses Metal for acceleration
Docker: Limited Metal support in Docker for Mac

### Memory Management

**Reduce memory footprint:**

```bash
# Keep only 1 model loaded at a time
export OLLAMA_MAX_LOADED_MODELS=1

# Unload models after 1 minute of inactivity
export OLLAMA_KEEP_ALIVE=1m
```

**Increase model capacity:**

```bash
# Load up to 3 models simultaneously (if you have enough RAM/VRAM)
export OLLAMA_MAX_LOADED_MODELS=3

# Keep models loaded for 30 minutes
export OLLAMA_KEEP_ALIVE=30m
```

### Concurrent Requests

```bash
# Allow 8 parallel requests
export OLLAMA_NUM_PARALLEL=8
```

---

## Management Scripts

The following management scripts are provided for both Windows (PowerShell) and Linux (Bash):

### install.ps1 / install.sh
Interactive installation wizard with:
- Docker verification
- GPU detection (NVIDIA/AMD)
- SSL/TLS configuration
- Network accessibility setup
- Automatic model download option

**Usage:**
```powershell
# Windows
.\management\install.ps1

# Linux
./management/install.sh
```

### pull-models.ps1 / pull-models.sh
Model download wizard with:
- Predefined profiles (Minimal, Standard, Performance, High-End)
- Custom model selection
- Disk space checking
- Progress tracking

**Usage:**
```powershell
# Windows
.\management\pull-models.ps1

# Linux
./management/pull-models.sh
```

### manage-ssl.ps1 / manage-ssl.sh
SSL certificate management:
- Generate self-signed certificates
- Install CA-provided certificates
- Enable/disable SSL
- Certificate status and renewal
- SAN (Subject Alternative Name) support

**Usage:**
```powershell
# Windows
.\management\manage-ssl.ps1 generate -Domain "ollama.company.com"
.\management\manage-ssl.ps1 enable
.\management\manage-ssl.ps1 status

# Linux
./management/manage-ssl.sh generate --domain ollama.company.com
./management/manage-ssl.sh enable
./management/manage-ssl.sh status
```

### manage-ollama.ps1 / manage-ollama.sh
Service operations:
- Start/stop/restart
- Status monitoring
- Log viewing
- Model management
- Resource statistics
- Service updates

**Usage:**
```powershell
# Windows
.\management\manage-ollama.ps1 status
.\management\manage-ollama.ps1 logs --follow
.\management\manage-ollama.ps1 models
.\management\manage-ollama.ps1 stats

# Linux
./management/manage-ollama.sh status
./management/manage-ollama.sh logs --follow
./management/manage-ollama.sh models
./management/manage-ollama.sh stats
```

---

## Offline Model Transfer

**IMPORTANT:** Models are NOT included in the offline package due to their large size (1-40GB each). For offline/airgapped installations, you must transfer models separately.

### Option 1: Docker cp Method (Recommended for Docker Deployments)

**On source machine (with internet):**
```bash
# Pull required models
ollama pull nomic-embed-text:latest
ollama pull llama3.2:3b

# Export models from Docker container
docker cp ollama:/root/.ollama/models ./ollama-models-backup

# Create archive
tar czf ollama-models.tar.gz ollama-models-backup/
```

**On target machine (offline):**
```bash
# Extract archive
tar xzf ollama-models.tar.gz

# Copy models into running container
docker cp ollama-models-backup/. ollama:/root/.ollama/models/

# Restart container to recognize models
docker-compose restart ollama

# Verify models
docker exec ollama ollama list
```

### Option 2: Volume Backup/Restore (Docker)

**On source machine:**
```bash
# Stop Ollama container
docker-compose down

# Backup Docker volume
docker run --rm -v ollama_ollama-data:/data -v $(pwd):/backup ubuntu tar czf /backup/ollama-models-$(date +%Y%m%d).tar.gz -C /data .

# Restart container
docker-compose up -d
```

**On target machine:**
```bash
# Stop Ollama container
docker-compose down

# Restore from backup
docker run --rm -v ollama_ollama-data:/data -v $(pwd):/backup ubuntu tar xzf /backup/ollama-models-YYYYMMDD.tar.gz -C /data

# Start container
docker-compose up -d

# Verify models
docker exec ollama ollama list
```

### Option 3: Manual File Transfer (Native Installation)

**On source machine:**

Windows:
```powershell
# Locate models directory
$ModelsDir = "$env:USERPROFILE\.ollama\models"

# Create archive
Compress-Archive -Path $ModelsDir -DestinationPath "ollama-models.zip"
```

Linux/macOS:
```bash
# Locate models directory
MODELS_DIR="$HOME/.ollama/models"

# Create archive
tar czf ollama-models.tar.gz -C "$HOME/.ollama" models/
```

**On target machine:**

Windows:
```powershell
# Stop Ollama service
Stop-Service Ollama

# Extract to models directory
Expand-Archive -Path "ollama-models.zip" -DestinationPath "$env:USERPROFILE\.ollama\" -Force

# Start Ollama service
Start-Service Ollama

# Verify models
ollama list
```

Linux/macOS:
```bash
# Stop Ollama service
sudo systemctl stop ollama

# Extract to models directory
tar xzf ollama-models.tar.gz -C "$HOME/.ollama/"

# Fix permissions
chown -R $(whoami):$(whoami) "$HOME/.ollama/models"

# Start Ollama service
sudo systemctl start ollama

# Verify models
ollama list
```

### Model Transfer Size Estimates

| Model | Approximate Size |
|-------|-----------------|
| nomic-embed-text:latest | ~274MB |
| mxbai-embed-large:latest | ~669MB |
| llama3.2:3b | ~2.0GB |
| llama3.1:8b | ~4.7GB |
| mistral:7b | ~4.1GB |
| qwen2.5:7b | ~4.7GB |
| deepseek-r1:8b | ~4.9GB |
| llama3.1:70b | ~40GB |

**Planning Tip:** For a standard offline deployment with both embedding models and 2-3 inference models, plan for 10-15GB of transfer data.

---

## Troubleshooting

### Common Issues

**Issue: "Connection refused" or "Cannot connect to Ollama"**

Solutions:
1. Verify Ollama is running:
   - Docker: `docker-compose ps`
   - Native Linux: `sudo systemctl status ollama`
   - Native Windows: `Get-Service Ollama`
2. Check port binding: `netstat -an | grep 11434` (Linux) or `netstat -an | findstr 11434` (Windows)
3. Verify firewall rules allow port 11434
4. Check OLLAMA_HOST is set correctly

**Issue: "Model not found"**

Solutions:
1. List pulled models: `ollama list`
2. Pull the missing model: `ollama pull model-name:tag`
3. Verify exact model name (case-sensitive)

**Issue: "Out of memory" errors**

Solutions:
1. Use smaller models (e.g., llama3.2:3b instead of llama3.1:70b)
2. Reduce `OLLAMA_MAX_LOADED_MODELS`
3. Set `OLLAMA_KEEP_ALIVE` to a shorter duration
4. Close other applications consuming RAM/VRAM
5. Enable GPU acceleration if available

**Issue: Slow inference/generation**

Solutions:
1. Enable GPU acceleration (NVIDIA/AMD/Metal)
2. Use quantized models (e.g., `:q4` or `:q8` variants)
3. Increase `OLLAMA_NUM_PARALLEL` for concurrent requests
4. Use smaller models for faster responses
5. Ensure SSD storage for model files

**Issue: Docker container keeps restarting**

Solutions:
1. Check Docker logs: `docker-compose logs ollama`
2. Verify GPU drivers are installed (if using GPU)
3. Check disk space: `df -h`
4. Verify Docker has enough resources allocated (Settings → Resources)

### Debug Mode

**Enable verbose logging:**

Docker (.env):
```env
OLLAMA_DEBUG=1
```

Native:
```bash
# Linux
export OLLAMA_DEBUG=1
sudo systemctl restart ollama
sudo journalctl -u ollama -f

# Windows
[Environment]::SetEnvironmentVariable("OLLAMA_DEBUG", "1", "Machine")
Restart-Service Ollama
Get-EventLog -LogName Application -Source Ollama -Newest 50
```

### Health Checks

**Automated health monitoring:**

```bash
#!/bin/bash
# Check if Ollama is responding
if curl -s http://localhost:11434/api/version > /dev/null; then
    echo "Ollama is healthy"
    exit 0
else
    echo "Ollama is not responding"
    exit 1
fi
```

---

## Model Management

### Listing Models

```bash
# List all downloaded models
ollama list

# Example output:
# NAME                     ID              SIZE      MODIFIED
# nomic-embed-text:latest  0123456789ab    274MB     2 days ago
# llama3.2:3b             abcdef123456    2.0GB     1 week ago
```

### Removing Models

```bash
# Remove a specific model
ollama rm model-name:tag

# Example:
ollama rm llama3.1:70b
```

### Updating Models

```bash
# Pull latest version
ollama pull model-name:latest

# This will download only the changed layers (delta update)
```

### Custom Models

You can create custom models based on existing ones:

```bash
# Create a Modelfile
cat > Modelfile <<EOF
FROM llama3.2:3b
PARAMETER temperature 0.7
PARAMETER top_p 0.9
SYSTEM You are a helpful AI assistant specializing in industrial IoT.
EOF

# Build custom model
ollama create my-custom-model -f Modelfile

# Use it
ollama run my-custom-model "What is predictive maintenance?"
```

---

## Backup & Restore

### Docker Deployment

**Backup (includes models and configuration):**

Windows:
```powershell
# Stop containers
docker-compose down

# Backup Docker volume
docker run --rm -v ollama_ollama-data:/data -v ${PWD}:/backup ubuntu tar czf /backup/ollama-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').tar.gz -C /data .

# Restart containers
docker-compose up -d
```

Linux:
```bash
# Stop containers
docker-compose down

# Backup Docker volume
docker run --rm -v ollama_ollama-data:/data -v $(pwd):/backup ubuntu tar czf /backup/ollama-backup-$(date +%Y%m%d-%H%M%S).tar.gz -C /data .

# Restart containers
docker-compose up -d
```

**Restore:**

```bash
# Stop containers
docker-compose down

# Restore from backup
docker run --rm -v ollama_ollama-data:/data -v $(pwd):/backup ubuntu tar xzf /backup/ollama-backup-YYYYMMDD-HHMMSS.tar.gz -C /data

# Restart containers
docker-compose up -d
```

### Native Installation

**Backup Models:**

Windows:
```powershell
# Backup models directory
$BackupPath = "C:\Backups\Ollama\$(Get-Date -Format 'yyyyMMdd-HHmmss')"
New-Item -ItemType Directory -Path $BackupPath
Copy-Item -Recurse "$env:USERPROFILE\.ollama\models\*" $BackupPath
```

Linux/macOS:
```bash
# Backup models directory
BACKUP_DIR="/backup/ollama/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp -r ~/.ollama/models/* "$BACKUP_DIR/"
```

**Restore Models:**

Windows:
```powershell
# Stop Ollama service
Stop-Service Ollama

# Restore models
Remove-Item -Recurse -Force "$env:USERPROFILE\.ollama\models\*"
Copy-Item -Recurse "C:\Backups\Ollama\YYYYMMDD-HHMMSS\*" "$env:USERPROFILE\.ollama\models\"

# Start Ollama service
Start-Service Ollama
```

Linux/macOS:
```bash
# Stop Ollama service
sudo systemctl stop ollama

# Restore models
rm -rf ~/.ollama/models/*
cp -r /backup/ollama/YYYYMMDD-HHMMSS/* ~/.ollama/models/

# Start Ollama service
sudo systemctl start ollama
```

---

## Upgrading Ollama

### Docker Deployment

```bash
# Pull latest Ollama image
docker-compose pull

# Restart containers with new image
docker-compose down
docker-compose up -d

# Verify version
docker exec -it ollama ollama --version
```

### Native Installation

**Windows:**
1. Download latest installer from https://ollama.ai
2. Run installer (will upgrade existing installation)
3. Verify: `ollama --version`

**Linux:**
```bash
# Re-run install script
curl -fsSL https://ollama.ai/install.sh | sh

# Restart service
sudo systemctl restart ollama

# Verify version
ollama --version
```

**macOS:**
1. Download latest .dmg from https://ollama.ai
2. Replace existing application
3. Verify: `ollama --version`

---

## Production Checklist

Before deploying Ollama for production use with XMPro AI Agents:

- [ ] Hardware requirements met (RAM, disk space, GPU if needed)
- [ ] Ollama service installed and running
- [ ] Required embedding models pulled and tested
- [ ] At least one inference model pulled and tested
- [ ] Network access configured (firewall rules, port bindings)
- [ ] SSL/TLS configured via reverse proxy (if needed)
- [ ] Performance optimizations applied (GPU, memory, concurrency)
- [ ] Backup strategy implemented
- [ ] Monitoring and health checks configured
- [ ] XMPro AI Agents integration tested
- [ ] Load testing completed (if high-volume usage expected)
- [ ] Documentation updated with your specific configuration

---

## Resources

**Official Documentation:**
- Ollama Website: https://ollama.ai
- Ollama GitHub: https://github.com/ollama/ollama
- Model Library: https://ollama.ai/library

**XMPro Integration:**
- XMPro AI Agents Documentation: [Link to your docs]
- AI Provider Configuration Guide: [Link to your docs]

**Community:**
- Ollama Discord: https://discord.gg/ollama
- Ollama Reddit: https://reddit.com/r/ollama

---

## Support

For issues specific to:
- **Ollama setup**: Create issue at https://github.com/ollama/ollama/issues
- **XMPro integration**: Contact XMPro support
- **Docker deployment**: Check Docker logs and configuration

For general LLM and embedding questions, consult the model documentation at https://ollama.ai/library
