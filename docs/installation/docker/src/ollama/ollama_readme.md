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

### Option 3: Hybrid (Native Ollama + Docker nginx for HTTPS)

Install Ollama natively on the host and run only the nginx reverse proxy in Docker. The Docker container terminates HTTPS on port 11443 and forwards plain HTTP to the host's native Ollama on port 11434. This is a complete deployment path on its own — you do **not** need a prior Docker or native install.

**Advantages:**
- Native GPU performance (no Docker GPU passthrough needed)
- Models live on the host filesystem — no Docker volume management
- Simple Ollama upgrades via the official installer
- HTTPS termination handled by a single nginx container — small footprint, easy to redeploy

**Disadvantages:**
- Two moving parts (host service + container) instead of one
- Native Ollama must be configured to listen on a host-accessible interface (`0.0.0.0`), which has firewall implications
- Container reaches the host via `host.docker.internal` — supported on Docker Desktop for Windows/macOS by default; Linux requires the explicit `host-gateway` mapping shown below

See the [Hybrid Deployment](#hybrid-deployment) section below for the full procedure.

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

## Hybrid Deployment

This is a complete from-scratch deployment. You will install Ollama natively on the host and run a single nginx container in Docker that terminates HTTPS on port 11443 and proxies plain HTTP to the native Ollama on port 11434.

### Recommended: use the installer

The interactive installer at `management/install.ps1` (Windows) and `management/install.sh` (Linux) supports hybrid mode out of the box. Running it is the easiest path:

**Windows:**

```powershell
cd C:\Docker\ollama
.\management\install.ps1
```

When prompted, choose **2) Hybrid**. The installer will:

- Verify native Ollama is installed (you'll be told to install it from <https://ollama.com/download> if missing).
- Set `OLLAMA_HOST=0.0.0.0:11434` in your User environment, prompt you to restart the Ollama tray app, and verify the new binding.
- Generate the hybrid `docker-compose.yml` and `nginx/nginx.conf` for you.
- Generate self-signed SSL certificates (or accept CA-provided ones).
- Start the nginx HTTPS proxy and verify it can reach your native Ollama.

**Linux:**

```bash
cd ~/docker/ollama
./management/install.sh
```

When prompted, choose **2) Hybrid**. The installer will:

- Verify native Ollama is installed (you'll be told to install it via `curl -fsSL https://ollama.com/install.sh | sh` if missing).
- Write a systemd override at `/etc/systemd/system/ollama.service.d/override.conf` setting `OLLAMA_HOST=0.0.0.0:11434`, then `systemctl daemon-reload && systemctl restart ollama`.
- Generate the hybrid `docker-compose.yml` and `nginx/nginx.conf`.
- Generate self-signed SSL certificates.
- Start the nginx HTTPS proxy and verify it can reach your native Ollama.

You can also pass the mode as a parameter to skip the prompt:

```powershell
.\management\install.ps1 -DeploymentMode hybrid
```

```bash
./management/install.sh --deployment-mode hybrid
```

The remainder of this section is the **manual procedure** that the installer automates — useful as reference or if you prefer to set things up by hand.

---


```
┌──────────────────────────────────────┐
│  Client (HTTPS)                      │
└─────────────────┬────────────────────┘
                  │ https://<host>:11443
┌─────────────────▼────────────────────┐
│  nginx-ssl container                 │
│  (Docker: ollama-nginx-ssl)          │
└─────────────────┬────────────────────┘
                  │ http://host.docker.internal:11434
┌─────────────────▼────────────────────┐
│  Ollama (native on host OS)          │
│  Listens on 0.0.0.0:11434            │
└──────────────────────────────────────┘
```

### Prerequisites

- Docker Desktop installed and running (for Windows/macOS) or Docker Engine (Linux)
- 8GB RAM minimum (16GB+ recommended)
- 20GB+ free disk space (models can be large)
- GPU drivers if you want native GPU acceleration (NVIDIA, AMD ROCm, or Apple Metal)

### Step 1 — Install Ollama natively on the host

Follow the platform-specific instructions in the [Native Installation](#native-installation) section above to install Ollama on Windows, Linux, or macOS. Once installed, verify:

```powershell
ollama --version
```

Do **not** start pulling models yet — first configure the listening interface (Step 2), because models pulled before that change are still accessible afterwards but the verification commands later assume Ollama is reachable from Docker.

### Step 2 — Make native Ollama reachable from Docker

By default Ollama binds only to `127.0.0.1:11434`, which Docker containers cannot reach. Set `OLLAMA_HOST` so Ollama listens on all host interfaces.

**Windows (PowerShell):**

```powershell
[Environment]::SetEnvironmentVariable("OLLAMA_HOST", "0.0.0.0:11434", "User")
```

Then quit the Ollama tray icon and relaunch it (or restart the Ollama service). Verify:

```powershell
curl http://localhost:11434/api/version
netstat -ano | findstr 11434
```

The first should return JSON with the Ollama version. The second should show `0.0.0.0:11434  LISTENING` (not `127.0.0.1:11434`). If you still see `127.0.0.1`, the env var did not take effect — confirm with `[Environment]::GetEnvironmentVariable("OLLAMA_HOST", "User")` and fully relaunch Ollama.

**Linux (systemd):**

```bash
sudo systemctl edit ollama
```

Add:

```ini
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
```

Then:

```bash
sudo systemctl daemon-reload
sudo systemctl restart ollama
curl http://localhost:11434/api/version
ss -tlnp | grep 11434
```

**macOS:** Set the env var in your shell profile (`~/.zshrc` or `~/.bash_profile`):

```bash
export OLLAMA_HOST=0.0.0.0:11434
```

Then restart the Ollama menubar app.

> **Security note:** `0.0.0.0` exposes Ollama on every host interface, including any LAN you are connected to. If only Docker should reach it, restrict access at the firewall — for example, allow inbound to TCP 11434 only from the Docker bridge subnet (typically `172.16.0.0/12` on Docker Desktop). On Windows: New-NetFirewallRule with `-RemoteAddress 172.16.0.0/12`.

### Step 3 — Pull the models you need (natively)

Pull the embedding and inference models you intend to use. Models live under `~/.ollama/models/` on the host, not in any Docker volume.

```powershell
ollama pull nomic-embed-text
ollama pull llama3.2:3b
```

See the [Native Installation - Direct Commands](#native-installation---direct-commands) section for more model commands.

### Step 4 — Set up the Docker stack directory

The repo ships parallel hybrid files alongside the Docker-mode ones — you don't need to author the compose or nginx config from scratch:

```
ollama/
  docker-compose.yml             ← Docker mode
  docker-compose.hybrid.yml      ← Hybrid mode (this file)
  nginx/
    nginx.conf                   ← Docker mode
    nginx.hybrid.conf            ← Hybrid mode (this file)
  certs/                         ← (created here)
  management/
```

Copy or extract the `ollama/` directory to your deployment location:

- Windows: `C:\Docker\ollama\`
- Linux/macOS: `~/docker/ollama/`

```powershell
cd C:\Docker\ollama
mkdir certs -ErrorAction SilentlyContinue
```

### Step 5 — Create the .env file

The `.env` tells docker-compose which compose file to use (via the `COMPOSE_FILE` variable, which is one of [Docker Compose's built-in CLI environment variables](https://docs.docker.com/compose/environment-variables/envvars/#compose_file)). Create `.env` in the deployment directory with this content:

```
COMPOSE_FILE=docker-compose.hybrid.yml
OLLAMA_HTTPS_PORT=11443
OLLAMA_DOMAIN=localhost
```

After this, every `docker-compose ...` command in this directory will operate on `docker-compose.hybrid.yml` automatically — no `-f` flag needed.

`docker-compose.hybrid.yml` mounts `nginx/nginx.hybrid.conf` into the container as `/etc/nginx/nginx.conf` (so the same file path works inside the container as the Docker-mode setup), and adds `extra_hosts: host.docker.internal:host-gateway` so the container can reach the host. No edits required.

### Step 6 — Generate self-signed certificates

The nginx container expects three files in `./certs/`: `server.crt`, `server.key`, and `ca.crt`. Generate them with a one-shot Docker run (no need to install OpenSSL on the host):

```powershell
cd C:\Docker\ollama
docker run --rm -v ${PWD}\certs:/certs -w /certs alpine/openssl `
    req -x509 -nodes -newkey rsa:4096 -days 365 `
    -keyout server.key -out server.crt `
    -subj "/CN=localhost" `
    -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"

docker run --rm -v ${PWD}\certs:/certs -w /certs alpine sh -c "cp server.crt ca.crt"
```

(Linux/macOS: same commands, replace `${PWD}` with `$(pwd)`.)

For production, replace these self-signed certificates with CA-issued ones — copy your issued `server.crt`, `server.key`, and `ca.crt` into `./certs/` and skip this step.

### Step 7 — Bring the proxy up

```powershell
docker-compose up -d
docker-compose logs -f nginx-ssl
```

Watch for nginx starting cleanly with no error lines. Press `Ctrl+C` to detach from the log follower once it looks quiet.

### Step 8 — Verify end-to-end

```powershell
curl -k https://localhost:11443/api/version
curl -k https://localhost:11443/api/tags
```

The first call proves nginx can reach the native Ollama. The second lists the models you pulled in Step 3. Both should return JSON.

### Troubleshooting

**502 Bad Gateway from nginx:**

```powershell
docker exec ollama-nginx-ssl wget -qO- http://host.docker.internal:11434/api/version
```

- Returns JSON → nginx config issue; re-check the `upstream` block in `nginx/nginx.conf`.
- Connection refused / timeout → the container cannot reach the host's Ollama. Either `OLLAMA_HOST=0.0.0.0:11434` did not take effect (restart Ollama after setting the env var, see Step 2) or your firewall is blocking the Docker bridge subnet.

**`host.docker.internal` does not resolve:**

This name is provided automatically on Docker Desktop. On Linux Docker Engine, the `extra_hosts: host.docker.internal:host-gateway` line in `docker-compose.yml` (Step 5) handles it — confirm that line is present.

**Certificate warnings in the browser / curl:**

Self-signed certificates from Step 7 will trigger warnings. Either accept the warning, install `ca.crt` to your OS trust store, or replace with CA-issued certificates.

---

## Pulling Models

### Docker Deployment - Using docker exec

When running Ollama in Docker, use `docker exec` to pull models into the container:

```bash
# Required Embedding Models (pull at least one)
docker exec ollama ollama pull nomic-embed-text:latest    # 768 dimensions
docker exec ollama ollama pull mxbai-embed-large:latest   # 1024 dimensions

# Recommended Inference Models - Choose based on hardware
docker exec ollama ollama pull llama3.2:3b                # Small/Fast (~2GB)
docker exec ollama ollama pull llama3.1:8b                # Medium (~5GB)
docker exec ollama ollama pull mistral:7b                 # Medium (~4GB)
docker exec ollama ollama pull qwen2.5:7b                 # Medium (~5GB)
docker exec ollama ollama pull deepseek-r1:8b             # Medium (~5GB)

# Coding-Optimized Models (GPT-4o-mini alternative)
docker exec ollama ollama pull qwen2.5-coder:7b           # Best for code (~5GB)

# Large Models (requires 24GB+ VRAM)
docker exec ollama ollama pull llama3.1:70b               # Large (~40GB)
docker exec ollama ollama pull qwen2.5:72b                # Large (~40GB)

# Verify models are loaded
docker exec ollama ollama list

# Test a model
docker exec ollama ollama run llama3.2:3b "Hello, how are you?"
```

### Native Installation - Direct Commands

For native Ollama installations (non-Docker):

```bash
# Required Embedding Models
ollama pull nomic-embed-text:latest
ollama pull mxbai-embed-large:latest

# Recommended Inference Models
ollama pull llama3.2:3b
ollama pull llama3.1:8b
ollama pull mistral:7b
ollama pull qwen2.5:7b
ollama pull deepseek-r1:8b
ollama pull qwen2.5-coder:7b

# Large Models
ollama pull llama3.1:70b
ollama pull qwen2.5:72b
```

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

## Ubuntu NVIDIA GPU Setup for Ollama

### Complete Setup Steps

#### 1. Detect GPUs
```bash
lspci | grep -i -E "vga|3d|display"
```
Expected output: NVIDIA GPU listed (e.g., `NVIDIA Corporation AD104GL [L4]`)

#### 2. Check Active Drivers
```bash
lspci -k | grep -A 3 -i "vga\|3d\|display"
```
If using `nouveau` driver, you need to switch to the official NVIDIA driver.

#### 3. Identify Available NVIDIA Drivers
```bash
ubuntu-drivers devices
```
Note the recommended driver (e.g., `nvidia-driver-590-open`)

#### 4. Install NVIDIA Driver
```bash
sudo apt install nvidia-driver-590-open
sudo reboot
```

After reboot, verify:
```bash
nvidia-smi
```
Should show your GPU, driver version, and CUDA version.

#### 5. Add NVIDIA Container Toolkit Repository
```bash
# Add GPG key
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
  sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

# Add repository
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

# Update and install
sudo apt update
sudo apt install nvidia-container-toolkit
```

#### 6. Configure Docker NVIDIA Runtime
```bash
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

#### 7. Verify GPU Works Inside Docker
```bash
docker run --rm --gpus all ubuntu nvidia-smi
```
✅ Should show your NVIDIA GPU with VRAM, driver version, and CUDA version.

#### 8. Run Ollama Installation
```bash
cd ~/containers/ollama
bash management/install.sh
```
- The script will auto-detect the NVIDIA GPU via `nvidia-smi`
- Confirm GPU with `y` when prompted
- GPU configuration will be automatically added to docker-compose.yml

### Verification Checklist

| Component | Command | Expected Result |
|-----------|---------|-----------------|
| NVIDIA Driver | `nvidia-smi` | Shows GPU, driver version, CUDA |
| Docker NVIDIA Runtime | `docker info \| grep -i nvidia` | Shows nvidia runtime |
| GPU in Docker | `docker run --rm --gpus all ubuntu nvidia-smi` | Shows GPU inside container |
| Ollama GPU | `docker exec ollama nvidia-smi` | Shows GPU usage by Ollama |

### Troubleshooting

**Issue: "nouveau" driver in use**
- Solution: Install official NVIDIA driver as shown in step 4

**Issue: "nvidia-container-toolkit not found"**
- Solution: Add NVIDIA repository as shown in step 5

**Issue: Docker can't access GPU**
- Solution: Configure runtime and restart Docker (step 6)

**Issue: Ollama not using GPU**
- Check docker-compose.yml has GPU devices configuration
- Verify with: `docker exec ollama nvidia-smi`

---

## Performance Optimization

### Hardware Acceleration

**NVIDIA GPU (CUDA):**

Docker (automatically configured by install.sh):
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
