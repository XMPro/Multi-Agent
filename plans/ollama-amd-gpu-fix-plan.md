# Ollama AMD GPU Configuration Fix - Analysis & Action Plan

## Executive Summary

The user's Ollama deployment is experiencing critical performance issues due to **complete lack of GPU acceleration**. All 25 model layers are running on CPU with the model spilling into swap memory, causing 500 errors and ~30 second timeouts.

---

## Root Cause Analysis

### 1. **Wrong Docker Image**
- **Current:** `ollama/ollama:latest` (CPU/NVIDIA only)
- **Required:** `ollama/ollama:rocm` (AMD GPU support)
- **Impact:** AMD GPU completely ignored, no ROCm runtime loaded

### 2. **Missing GPU Device Passthrough**
The current [`docker-compose.yml`](../docs/installation/docker/src/ollama/docker-compose.yml:3) lacks AMD-specific device mappings:
```yaml
# Missing from current configuration:
--device=/dev/kfd        # Kernel Fusion Driver
--device=/dev/dri        # Direct Rendering Infrastructure
--group-add video        # Video group access
--group-add render       # Render group access
```

### 3. **Insufficient System Resources**
- **Model Size:** 12.8 GiB (likely a Q4 quantized 13B model)
- **Available RAM:** 8 GiB physical + 14 GiB swap
- **Result:** Model loading into swap = extreme slowness
- **Evidence:** `offloaded 0/25 layers to GPU` + `model weights device=CPU`

### 4. **Installation Script Limitations**
The current [`install.sh`](../docs/installation/docker/src/ollama/management/install.sh:169) detects AMD GPUs but:
- Only adds generic `driver: amd` to docker-compose.yml
- Doesn't switch to ROCm image
- Doesn't add required device mappings
- Doesn't verify ROCm drivers are installed

---

## Verification Evidence

From user's logs:
```
offloaded 0/25 layers to GPU
model weights device=CPU size="12.8 GiB"
500 | 29.960955985s | POST "/api/chat"
```

This confirms:
- ✗ Zero GPU utilization
- ✗ CPU-only inference
- ✗ Swap thrashing
- ✗ Request timeouts

---

## Solution Architecture

### Phase 1: Immediate Fix (User Action Required)

**Replace the container with proper AMD ROCm configuration:**

```bash
# Stop and remove current container
docker stop ollama
docker rm ollama

# Run with ROCm image and proper device passthrough
docker run -d \
  --name ollama \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add video \
  --group-add render \
  -p 11434:11434 \
  -v ollama:/root/.ollama \
  ollama/ollama:rocm

# Verify GPU is detected
docker exec ollama rocm-smi

# Check layer offloading in logs
docker logs ollama
# Should see: "offloaded 25/25 layers to GPU" or similar
```

**Expected Result:**
- All 25 layers offloaded to GPU
- Model weights on GPU VRAM
- Sub-second inference times
- No 500 errors

### Phase 2: Update Project Configuration

Update the project's Docker Compose and installation scripts to properly support AMD GPUs.

---

## Detailed Action Plan

### 1. Update docker-compose.yml

**File:** [`docs/installation/docker/src/ollama/docker-compose.yml`](../docs/installation/docker/src/ollama/docker-compose.yml)

**Changes Required:**

```yaml
services:
  ollama:
    # Dynamic image selection based on GPU type
    image: ${OLLAMA_IMAGE:-ollama/ollama:latest}
    container_name: ollama
    restart: unless-stopped
    
    # AMD ROCm specific device mappings (when GPU_DRIVER=amd)
    devices:
      - /dev/kfd:/dev/kfd      # Only added when AMD GPU detected
      - /dev/dri:/dev/dri      # Only added when AMD GPU detected
    
    # Group memberships for AMD GPU access
    group_add:
      - video                   # Only added when AMD GPU detected
      - render                  # Only added when AMD GPU detected
    
    ports:
      - "${OLLAMA_PORT:-11434}:11434"
    
    volumes:
      - ollama-data:/root/.ollama
      - ./certs:/certs
    
    environment:
      - OLLAMA_HOST=0.0.0.0:11434
      - OLLAMA_ORIGINS=*
      - OLLAMA_NUM_PARALLEL=${OLLAMA_NUM_PARALLEL:-4}
      - OLLAMA_MAX_LOADED_MODELS=${OLLAMA_MAX_LOADED_MODELS:-2}
      - OLLAMA_KEEP_ALIVE=${OLLAMA_KEEP_ALIVE:-5m}
      - OLLAMA_DEBUG=${OLLAMA_DEBUG:-0}
      - TZ=${TZ:-UTC}
      # AMD ROCm specific (when GPU_DRIVER=amd)
      - HSA_OVERRIDE_GFX_VERSION=${HSA_OVERRIDE_GFX_VERSION:-}
    
    # NVIDIA GPU configuration (when GPU_DRIVER=nvidia)
    deploy:
      resources:
        limits:
          cpus: '4'
          memory: 8G
        reservations:
          cpus: '2'
          memory: 4G
          # NVIDIA devices (only when GPU_DRIVER=nvidia)
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
```

**Note:** Docker Compose doesn't support conditional device mappings natively, so we'll need to:
- Create separate compose files for different GPU types, OR
- Dynamically modify the compose file during installation

### 2. Update .env.template

**File:** [`docs/installation/docker/src/ollama/.env.template`](../docs/installation/docker/src/ollama/.env.template)

**Add:**
```env
# Docker Image Selection (auto-configured by install script)
# Options: ollama/ollama:latest (CPU/NVIDIA), ollama/ollama:rocm (AMD)
OLLAMA_IMAGE=ollama/ollama:latest

# AMD ROCm Configuration (only used when OLLAMA_GPU_DRIVER=amd)
# Override GFX version if needed (e.g., 10.3.0 for some Radeon cards)
HSA_OVERRIDE_GFX_VERSION=
```

### 3. Update install.sh Script

**File:** [`docs/installation/docker/src/ollama/management/install.sh`](../docs/installation/docker/src/ollama/management/install.sh)

**Changes Required:**

#### A. Enhanced AMD GPU Detection (lines 169-176)

```bash
# If no NVIDIA, check for AMD
if [ "$DETECTED_GPU" = "none" ]; then
    if lspci 2>/dev/null | grep -iE "VGA|3D" | grep -iq "AMD\|Radeon"; then
        echo -e "${GREEN}[OK] AMD GPU detected${NC}"
        
        # Check for ROCm installation
        if command -v rocm-smi &> /dev/null; then
            if rocm-smi &> /dev/null 2>&1; then
                echo -e "${GREEN}[OK] ROCm drivers detected${NC}"
                DETECTED_GPU="amd"
            else
                echo -e "${YELLOW}⚠ AMD GPU found but ROCm drivers not working${NC}"
                echo -e "${GRAY}  Install ROCm: https://rocm.docs.amd.com/en/latest/deploy/linux/quick_start.html${NC}"
                DETECTED_GPU="none"
            fi
        else
            echo -e "${YELLOW}⚠ AMD GPU found but ROCm drivers not installed${NC}"
            echo -e "${GRAY}  Install ROCm: https://rocm.docs.amd.com/en/latest/deploy/linux/quick_start.html${NC}"
            echo -e "${GRAY}  Or continue with CPU-only mode${NC}"
            read -p "Continue with CPU-only mode? (y/n): " cpu_choice
            if [[ ! "$cpu_choice" =~ ^[Yy]$ ]]; then
                echo -e "${YELLOW}Installation cancelled${NC}"
                exit 1
            fi
            DETECTED_GPU="none"
        fi
    fi
fi
```

#### B. Update .env Configuration (after line 348)

```bash
sed -i "s/OLLAMA_GPU_DRIVER=.*/OLLAMA_GPU_DRIVER=$GPU_DRIVER/" .env

# Set appropriate Docker image based on GPU type
if [ "$GPU_DRIVER" = "amd" ]; then
    sed -i "s|OLLAMA_IMAGE=.*|OLLAMA_IMAGE=ollama/ollama:rocm|" .env
    echo -e "${GREEN}[OK] Configured to use ROCm image${NC}"
elif [ "$GPU_DRIVER" = "nvidia" ]; then
    sed -i "s|OLLAMA_IMAGE=.*|OLLAMA_IMAGE=ollama/ollama:latest|" .env
    echo -e "${GREEN}[OK] Configured to use NVIDIA image${NC}"
else
    sed -i "s|OLLAMA_IMAGE=.*|OLLAMA_IMAGE=ollama/ollama:latest|" .env
    echo -e "${GRAY}Configured to use CPU-only image${NC}"
fi
```

#### C. AMD-Specific docker-compose.yml Modifications (replace lines 357-385)

```bash
# Update docker-compose.yml based on GPU type
if [ "$GPU_DRIVER" = "amd" ]; then
    echo -e "${GRAY}Configuring AMD ROCm support in docker-compose.yml...${NC}"
    
    # Create temporary file with AMD device configuration
    cat > /tmp/amd_devices.txt <<'EOF'
    devices:
      - /dev/kfd:/dev/kfd
      - /dev/dri:/dev/dri
    group_add:
      - video
      - render
EOF
    
    # Insert AMD devices after the image line
    awk '
    /^    image:/ {
        print
        system("cat /tmp/amd_devices.txt")
        next
    }
    { print }
    ' docker-compose.yml > docker-compose.yml.tmp
    
    mv docker-compose.yml.tmp docker-compose.yml
    rm -f /tmp/amd_devices.txt
    
    echo -e "${GREEN}[OK] AMD ROCm support enabled in docker-compose.yml${NC}"
    
elif [ "$GPU_DRIVER" = "nvidia" ]; then
    echo -e "${GRAY}Configuring NVIDIA GPU support in docker-compose.yml...${NC}"
    
    # Create temporary file with NVIDIA GPU configuration
    cat > /tmp/gpu_config.txt <<'EOF'
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
EOF
    
    # Insert NVIDIA devices in deploy.resources.reservations section
    awk '
    /reservations:/ { in_reservations=1 }
    in_reservations && /memory:/ {
        print
        system("cat /tmp/gpu_config.txt")
        in_reservations=0
        next
    }
    { print }
    ' docker-compose.yml > docker-compose.yml.tmp
    
    mv docker-compose.yml.tmp docker-compose.yml
    rm -f /tmp/gpu_config.txt
    
    echo -e "${GREEN}[OK] NVIDIA GPU support enabled in docker-compose.yml${NC}"
fi
```

#### D. Add GPU Verification After Container Start (after line 485)

```bash
echo ""

# Verify GPU configuration if GPU is enabled
if [ "$GPU_DRIVER" != "none" ] && [ "$HEALTHY" = true ]; then
    echo -e "${CYAN}Verifying GPU Configuration:${NC}"
    
    if [ "$GPU_DRIVER" = "amd" ]; then
        echo -e "${GRAY}Checking AMD GPU access...${NC}"
        if docker exec ollama rocm-smi &> /dev/null; then
            echo -e "${GREEN}[OK] AMD GPU accessible via ROCm${NC}"
            docker exec ollama rocm-smi | head -n 20
        else
            echo -e "${YELLOW}⚠ AMD GPU not accessible in container${NC}"
            echo -e "${GRAY}  Check ROCm installation and device permissions${NC}"
        fi
    elif [ "$GPU_DRIVER" = "nvidia" ]; then
        echo -e "${GRAY}Checking NVIDIA GPU access...${NC}"
        if docker exec ollama nvidia-smi &> /dev/null; then
            echo -e "${GREEN}[OK] NVIDIA GPU accessible${NC}"
            docker exec ollama nvidia-smi | head -n 20
        else
            echo -e "${YELLOW}⚠ NVIDIA GPU not accessible in container${NC}"
            echo -e "${GRAY}  Check nvidia-docker2 installation${NC}"
        fi
    fi
    
    echo ""
    echo -e "${CYAN}Testing Model Loading:${NC}"
    echo -e "${GRAY}Pull a small model to verify GPU offloading...${NC}"
    echo -e "${GRAY}  docker exec ollama ollama pull llama3.2:1b${NC}"
    echo -e "${GRAY}Then check logs for 'offloaded X/Y layers to GPU'${NC}"
fi
```

### 4. Create AMD ROCm Setup Documentation

**New File:** `docs/installation/docker/src/ollama/AMD_ROCM_SETUP.md`

**Content:**

```markdown
# AMD ROCm Setup for Ollama

## Overview

This guide covers setting up AMD GPUs with ROCm drivers for Ollama GPU acceleration.

## Prerequisites

- AMD GPU with ROCm support (check: https://rocm.docs.amd.com/en/latest/release/gpu_os_support.html)
- Ubuntu 20.04/22.04 or RHEL 8/9
- Docker installed

## Supported AMD GPUs

### RDNA Architecture (Recommended)
- RX 6000 series (6600, 6700, 6800, 6900)
- RX 7000 series (7600, 7700, 7800, 7900)
- Radeon Pro W6000/W7000 series

### CDNA Architecture (Data Center)
- MI100, MI200, MI300 series

### Older GCN Architecture (Limited Support)
- RX 5000 series (may require HSA_OVERRIDE_GFX_VERSION)
- Vega series (may require HSA_OVERRIDE_GFX_VERSION)

## Installation Steps

### 1. Verify GPU Detection

```bash
lspci | grep -i "VGA\|3D"
# Should show your AMD GPU
```

### 2. Install ROCm Drivers

#### Ubuntu 22.04

```bash
# Add ROCm repository
wget https://repo.radeon.com/amdgpu-install/latest/ubuntu/jammy/amdgpu-install_6.0.60000-1_all.deb
sudo dpkg -i amdgpu-install_6.0.60000-1_all.deb
sudo apt update

# Install ROCm
sudo amdgpu-install --usecase=rocm

# Add user to render and video groups
sudo usermod -a -G render,video $USER

# Reboot required
sudo reboot
```

#### Ubuntu 20.04

```bash
# Add ROCm repository
wget https://repo.radeon.com/amdgpu-install/latest/ubuntu/focal/amdgpu-install_6.0.60000-1_all.deb
sudo dpkg -i amdgpu-install_6.0.60000-1_all.deb
sudo apt update

# Install ROCm
sudo amdgpu-install --usecase=rocm

# Add user to groups
sudo usermod -a -G render,video $USER

# Reboot required
sudo reboot
```

### 3. Verify ROCm Installation

```bash
# Check ROCm version
rocm-smi --showproductname

# Expected output: GPU information with temperature, usage, etc.
```

### 4. Configure Docker for ROCm

```bash
# Verify Docker can access GPU devices
ls -la /dev/kfd /dev/dri

# Should show:
# crw-rw---- 1 root render /dev/kfd
# drwxr-xr-x 3 root root   /dev/dri
```

### 5. Run Ollama Installation

```bash
cd ~/containers/ollama
./management/install.sh

# The script will:
# - Detect AMD GPU
# - Configure ROCm image
# - Add device mappings
# - Start container with GPU access
```

### 6. Verify GPU Offloading

```bash
# Pull a test model
docker exec ollama ollama pull llama3.2:1b

# Check logs for GPU offloading
docker logs ollama 2>&1 | grep -i "offload\|gpu"

# Should see: "offloaded X/X layers to GPU"
```

## Troubleshooting

### Issue: "No GPU detected" in container

**Solution:**
```bash
# Check device permissions
ls -la /dev/kfd /dev/dri

# Verify user is in render/video groups
groups $USER

# If not, add and reboot:
sudo usermod -a -G render,video $USER
sudo reboot
```

### Issue: "HSA Error" or GPU not recognized

**Solution:**
```bash
# Some older AMD GPUs need GFX version override
# Find your GPU's GFX version:
rocminfo | grep "gfx"

# Add to .env file:
HSA_OVERRIDE_GFX_VERSION=10.3.0  # Example for RX 5700

# Restart container:
docker-compose down && docker-compose up -d
```

### Issue: "offloaded 0/X layers to GPU"

**Causes:**
1. Wrong Docker image (using `latest` instead of `rocm`)
2. Missing device mappings
3. ROCm drivers not installed
4. Insufficient VRAM for model

**Solution:**
```bash
# Verify ROCm image is being used
docker inspect ollama | grep Image
# Should show: ollama/ollama:rocm

# Check docker-compose.yml has device mappings
grep -A 5 "devices:" docker-compose.yml
# Should show /dev/kfd and /dev/dri

# Verify GPU is accessible in container
docker exec ollama rocm-smi
```

### Issue: Model too large for VRAM

**Solution:**
Use smaller or more quantized models:

| VRAM | Recommended Models |
|------|-------------------|
| 4GB  | llama3.2:1b, llama3.2:3b (Q4) |
| 6GB  | llama3.1:8b (Q4), mistral:7b (Q4) |
| 8GB  | llama3.1:8b, qwen2.5:7b, deepseek-r1:8b |
| 12GB | llama3.1:8b (Q8), mixtral:8x7b (Q4) |
| 16GB+ | llama3.1:70b (Q4), qwen2.5:72b (Q4) |

```bash
# Pull quantized version
docker exec ollama ollama pull llama3.1:8b-q4_0
```

## Performance Optimization

### 1. Maximize GPU Offloading

```bash
# In .env file:
OLLAMA_GPU_LAYERS=999  # Offload all layers possible
```

### 2. Reduce Memory Footprint

```bash
# Keep only 1 model loaded
OLLAMA_MAX_LOADED_MODELS=1

# Unload after 1 minute
OLLAMA_KEEP_ALIVE=1m
```

### 3. Monitor GPU Usage

```bash
# Real-time monitoring
watch -n 1 'docker exec ollama rocm-smi'

# Check VRAM usage
docker exec ollama rocm-smi --showmeminfo vram
```

## Model Size vs VRAM Requirements

| Model | Parameters | Quantization | VRAM Required |
|-------|-----------|--------------|---------------|
| llama3.2:1b | 1B | Q4_0 | ~1 GB |
| llama3.2:3b | 3B | Q4_0 | ~2 GB |
| llama3.1:8b | 8B | Q4_0 | ~4.5 GB |
| llama3.1:8b | 8B | Q8_0 | ~8 GB |
| mistral:7b | 7B | Q4_0 | ~4 GB |
| qwen2.5:7b | 7B | Q4_0 | ~4.5 GB |
| deepseek-r1:8b | 8B | Q4_0 | ~5 GB |
| llama3.1:70b | 70B | Q4_0 | ~40 GB |

**Note:** Add ~500MB overhead for context and processing.

## References

- ROCm Documentation: https://rocm.docs.amd.com/
- Ollama ROCm Support: https://github.com/ollama/ollama/blob/main/docs/gpu.md
- AMD GPU Support Matrix: https://rocm.docs.amd.com/en/latest/release/gpu_os_support.html
```

### 5. Update Main README

**File:** [`docs/installation/docker/src/ollama/ollama_readme.md`](../docs/installation/docker/src/ollama/ollama_readme.md)

**Add section after line 553 (after NVIDIA GPU setup):**

```markdown
## AMD GPU Setup for Ollama (ROCm)

### Complete Setup Steps

#### 1. Verify AMD GPU
```bash
lspci | grep -i "VGA\|3D"
```
Expected output: AMD/Radeon GPU listed

#### 2. Check ROCm Installation
```bash
rocm-smi --showproductname
```
If command not found, install ROCm drivers (see AMD_ROCM_SETUP.md)

#### 3. Install ROCm Drivers (if needed)

**Ubuntu 22.04:**
```bash
wget https://repo.radeon.com/amdgpu-install/latest/ubuntu/jammy/amdgpu-install_6.0.60000-1_all.deb
sudo dpkg -i amdgpu-install_6.0.60000-1_all.deb
sudo apt update
sudo amdgpu-install --usecase=rocm
sudo usermod -a -G render,video $USER
sudo reboot
```

#### 4. Verify Device Access
```bash
ls -la /dev/kfd /dev/dri
groups $USER  # Should include 'render' and 'video'
```

#### 5. Run Ollama Installation
```bash
cd ~/containers/ollama
./management/install.sh
```
The script will auto-detect AMD GPU and configure ROCm support.

#### 6. Verify GPU Offloading
```bash
# Pull a test model
docker exec ollama ollama pull llama3.2:1b

# Check logs for GPU offloading
docker logs ollama 2>&1 | grep -i "offload"
```
✅ Should see: `offloaded X/X layers to GPU`

### Verification Checklist

| Component | Command | Expected Result |
|-----------|---------|-----------------|
| AMD GPU | `lspci \| grep -i amd` | Shows AMD GPU |
| ROCm Drivers | `rocm-smi` | Shows GPU info |
| Device Access | `ls -la /dev/kfd /dev/dri` | Devices exist with render group |
| User Groups | `groups $USER` | Includes render and video |
| Docker Image | `docker inspect ollama \| grep Image` | Shows ollama/ollama:rocm |
| GPU in Container | `docker exec ollama rocm-smi` | Shows GPU inside container |
| Layer Offloading | `docker logs ollama` | Shows "offloaded X/X layers" |

### Troubleshooting

**Issue: Wrong Docker image (ollama/ollama:latest instead of rocm)**

Solution:
```bash
# Stop container
docker-compose down

# Update .env file
sed -i 's|OLLAMA_IMAGE=.*|OLLAMA_IMAGE=ollama/ollama:rocm|' .env

# Restart
docker-compose up -d
```

**Issue: Missing device mappings**

Verify docker-compose.yml contains:
```yaml
devices:
  - /dev/kfd:/dev/kfd
  - /dev/dri:/dev/dri
group_add:
  - video
  - render
```

**Issue: Model too large for VRAM**

Use smaller models:
- 4GB VRAM: llama3.2:1b, llama3.2:3b
- 6GB VRAM: llama3.1:8b (Q4)
- 8GB VRAM: llama3.1:8b, mistral:7b

For detailed AMD ROCm setup, see [AMD_ROCM_SETUP.md](./AMD_ROCM_SETUP.md)
```

### 6. Create Troubleshooting Guide

**New File:** `docs/installation/docker/src/ollama/TROUBLESHOOTING_GPU.md`

```markdown
# Ollama GPU Troubleshooting Guide

## Quick Diagnosis

### Check Current GPU Status

```bash
# View container logs
docker logs ollama 2>&1 | grep -i "gpu\|offload\|device"

# Expected (working):
# "offloaded 25/25 layers to GPU"
# "model weights device=GPU"

# Problem (not working):
# "offloaded 0/25 layers to GPU"
# "model weights device=CPU"
```

## Common Issues & Solutions

### Issue 1: "offloaded 0/X layers to GPU" (AMD)

**Root Cause:** Wrong Docker image or missing device mappings

**Diagnosis:**
```bash
# Check Docker image
docker inspect ollama | grep -i image
# Should show: ollama/ollama:rocm (NOT ollama/ollama:latest)

# Check device mappings
docker inspect ollama | grep -A 10 Devices
# Should show /dev/kfd and /dev/dri
```

**Solution:**
```bash
# Stop container
docker-compose down

# Fix 1: Update image in .env
echo "OLLAMA_IMAGE=ollama/ollama:rocm" >> .env

# Fix 2: Ensure docker-compose.yml has AMD devices
# Edit docker-compose.yml and add:
#   devices:
#     - /dev/kfd:/dev/kfd
#     - /dev/dri:/dev/dri
#   group_add:
#     - video
#     - render

# Restart
docker-compose up -d

# Verify
docker logs ollama 2>&1 | grep offload
```

### Issue 2: "offloaded 0/X layers to GPU" (NVIDIA)

**Root Cause:** NVIDIA Docker runtime not configured

**Diagnosis:**
```bash
# Check NVIDIA runtime
docker info | grep -i nvidia

# Check nvidia-smi in container
docker exec ollama nvidia-smi
```

**Solution:**
```bash
# Install NVIDIA Container Toolkit
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
  sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt update
sudo apt install nvidia-container-toolkit

# Configure Docker
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

# Restart Ollama
docker-compose restart
```

### Issue 3: "500 Internal Server Error" + Slow Response

**Root Cause:** Model too large for available resources

**Diagnosis:**
```bash
# Check model size vs available memory
docker exec ollama ollama list

# Check system resources
free -h
docker stats ollama
```

**Solution:**

Use smaller or more quantized models:

```bash
# Remove large model
docker exec ollama ollama rm large-model:latest

# Pull smaller alternative
docker exec ollama ollama pull llama3.2:3b  # Instead of 13B+
docker exec ollama ollama pull llama3.1:8b-q4_0  # Quantized version
```

### Issue 4: AMD GPU Not Detected in Container

**Root Cause:** ROCm drivers not installed or user not in correct groups

**Diagnosis:**
```bash
# Check ROCm on host
rocm-smi

# Check user groups
groups $USER
# Should include: render, video

# Check device permissions
ls -la /dev/kfd /dev/dri
```

**Solution:**
```bash
# Install ROCm (Ubuntu 22.04)
wget https://repo.radeon.com/amdgpu-install/latest/ubuntu/jammy/amdgpu-install_6.0.60000-1_all.deb
sudo dpkg -i amdgpu-install_6.0.60000-1_all.deb
sudo apt update
sudo amdgpu-install --usecase=rocm

# Add user to groups
sudo usermod -a -G render,video $USER

# Reboot required
sudo reboot

# Verify after reboot
rocm-smi
docker exec ollama rocm-smi
```

### Issue 5: "HSA Error" with AMD GPU

**Root Cause:** GPU architecture not recognized (older AMD GPUs)

**Solution:**
```bash
# Find your GPU's GFX version
rocminfo | grep "gfx"

# Add override to .env
echo "HSA_OVERRIDE_GFX_VERSION=10.3.0" >> .env  # Adjust version

# Restart container
docker-compose restart
```

### Issue 6: Out of Memory Errors

**Root Cause:** Model + context exceeds VRAM

**Solution:**
```bash
# Reduce loaded models
sed -i 's/OLLAMA_MAX_LOADED_MODELS=.*/OLLAMA_MAX_LOADED_MODELS=1/' .env

# Reduce keep-alive time
sed -i 's/OLLAMA_KEEP_ALIVE=.*/OLLAMA_KEEP_ALIVE=1m/' .env

# Restart
docker-compose restart
```

## Model Size Recommendations by VRAM

| Available VRAM | Recommended Models | Avoid |
|----------------|-------------------|-------|
| 4GB | llama3.2:1b, llama3.2:3b | 7B+ models |
| 6GB | llama3.1:8b (Q4), mistral:7b (Q4) | 13B+ models |
| 8GB | llama3.1:8b, qwen2.5:7b, deepseek-r1:8b | 70B models |
| 12GB | llama3.1:8b (Q8), mixtral:8x7b (Q4) | 70B (Q8) |
| 16GB+ | llama3.1:70b (Q4), qwen2.5:72b (Q4) | - |

## Verification Commands

```bash
# 1. Check Docker image
docker inspect ollama | grep -i image

# 2. Check GPU access (AMD)
docker exec ollama rocm-smi

# 3. Check GPU access (NVIDIA)
docker exec ollama nvidia-smi

# 4. Check layer offloading
docker logs ollama 2>&1 | grep -i offload

# 5. Check model device placement
docker logs ollama 2>&1 | grep -i "model weights device"

# 6. Monitor real-time GPU usage (AMD)