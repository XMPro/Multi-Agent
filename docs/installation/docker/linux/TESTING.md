# Testing Linux Scripts

This guide provides multiple approaches for testing the Linux Docker installation scripts on a Windows development machine.

## Testing Options

### Option 1: WSL2 (Recommended - Easiest)

**Windows Subsystem for Linux 2** provides a full Linux kernel on Windows.

#### Setup WSL2

```powershell
# Install WSL2 with Ubuntu
wsl --install Ubuntu

# Or install a specific distribution
wsl --install -d Ubuntu-22.04

# After installation, restart your computer
```

#### Install Docker Engine in WSL2

```bash
# Update package list
sudo apt-get update

# Install Docker Engine and Docker Compose
sudo apt-get install -y docker.io docker-compose

# Start Docker daemon
sudo service docker start

# Add your user to docker group (to run docker without sudo)
sudo usermod -aG docker $USER

# Apply group changes (logout/login or use newgrp)
newgrp docker

# Verify Docker is working
docker version
docker ps
```

**Note for WSL2:** Use `sudo service docker start` instead of `systemctl` since WSL2 doesn't use systemd by default.

**To start Docker automatically in WSL2**, add to your `~/.bashrc`:
```bash
# Auto-start Docker in WSL2
if ! pgrep -x dockerd > /dev/null; then
    sudo service docker start > /dev/null 2>&1
fi
```

#### Test the Scripts

```bash
# Navigate to the project (WSL can access Windows files)
cd /mnt/c/Development/Github/Multi-Agent/docs/installation/docker/linux

# Make scripts executable
chmod +x prepare-stack.sh
chmod +x management/*.sh

# Test prepare script
./prepare-stack.sh

# Test installer (after creating package)
cd dist
chmod +x docker-stack-installer.sh
./docker-stack-installer.sh
```

**Advantages:**
- ✅ Full Linux environment on Windows
- ✅ Access to Windows files via `/mnt/c/`
- ✅ Fast and lightweight
- ✅ Can test Docker commands
- ✅ No separate VM needed

**Limitations:**
- ⚠️ Docker Desktop integration can be tricky
- ⚠️ May need Docker Desktop with WSL2 backend enabled

---

### Option 2: Docker Desktop with Linux Containers

Your Docker Desktop is already running Linux containers, so you can test inside a container.

#### Create a Test Container

```powershell
# Run an Ubuntu container with your project mounted
docker run -it --rm `
  -v C:\Development\Github\Multi-Agent:/workspace `
  -v /var/run/docker.sock:/var/run/docker.sock `
  ubuntu:22.04 bash

# Inside the container:
apt-get update
apt-get install -y docker.io docker-compose unzip zip

cd /workspace/docs/installation/docker/linux
chmod +x prepare-stack.sh
./prepare-stack.sh
```

**Advantages:**
- ✅ Uses your existing Docker Desktop
- ✅ Clean environment for each test
- ✅ Can test Docker commands (via socket mount)

**Limitations:**
- ⚠️ Mounting Docker socket has security implications
- ⚠️ More complex setup

---

### Option 3: Virtual Machine

Use VirtualBox, VMware, or Hyper-V to run a full Linux VM.

#### Quick Setup with VirtualBox

1. **Download Ubuntu ISO**: https://ubuntu.com/download/server
2. **Create VM** in VirtualBox:
   - 2+ CPU cores
   - 4+ GB RAM
   - 20+ GB disk
3. **Install Ubuntu**
4. **Install Docker**:
   ```bash
   sudo apt-get update
   sudo apt-get install -y docker.io docker-compose
   sudo systemctl start docker
   sudo usermod -aG docker $USER
   ```
5. **Transfer files** via shared folder or SCP

**Advantages:**
- ✅ Full Linux environment
- ✅ Most realistic testing
- ✅ Can test everything including systemd

**Limitations:**
- ⚠️ Requires more resources
- ⚠️ Slower to set up
- ⚠️ File transfer needed

---

### Option 4: Cloud VM (Azure/AWS)

Quick cloud-based testing environment.

#### Azure VM

```powershell
# Create a quick Ubuntu VM
az vm create `
  --resource-group MyResourceGroup `
  --name docker-test-vm `
  --image Ubuntu2204 `
  --size Standard_B2s `
  --admin-username azureuser `
  --generate-ssh-keys

# SSH into the VM
ssh azureuser@<vm-ip-address>

# Install Docker
sudo apt-get update
sudo apt-get install -y docker.io docker-compose
sudo systemctl start docker
sudo usermod -aG docker $USER
```

**Advantages:**
- ✅ Real Linux environment
- ✅ Can test from anywhere
- ✅ Easy to create/destroy

**Limitations:**
- ⚠️ Costs money (though minimal for testing)
- ⚠️ Need to transfer files
- ⚠️ Requires Azure/AWS account

---

## Recommended Testing Workflow

### For Quick Testing: Use WSL2

```bash
# 1. Install WSL2 (one-time setup)
wsl --install Ubuntu

# 2. Install Docker in WSL2 (one-time setup)
sudo apt-get update
sudo apt-get install -y docker.io docker-compose
sudo systemctl start docker
sudo usermod -aG docker $USER

# 3. Test scripts
cd /mnt/c/Development/Github/Multi-Agent/docs/installation/docker/linux
chmod +x prepare-stack.sh management/*.sh
./prepare-stack.sh

# 4. Test installer
cd dist
chmod +x docker-stack-installer.sh
./docker-stack-installer.sh
```

### For Comprehensive Testing: Use VM or Cloud

Test on actual distributions:
- Ubuntu 22.04 LTS
- Debian 11
- RHEL 8
- CentOS Stream 8

---

## Testing Checklist

### Prepare Script Tests
- [ ] Script runs without errors
- [ ] Creates ZIP file in dist/ folder
- [ ] ZIP contains all service folders (neo4j, milvus, mqtt)
- [ ] ZIP contains management scripts
- [ ] ZIP contains Cypher scripts in neo4j/updates/
- [ ] Python packages downloaded (if pip available)
- [ ] Offline mode creates Docker images tar
- [ ] Installer script copied to dist/

### Installer Script Tests
- [ ] Detects and validates prerequisites
- [ ] Extracts ZIP correctly
- [ ] Prompts for passwords securely (interactive mode)
- [ ] Reads passwords from environment variables
- [ ] Configures all three services
- [ ] Starts all services successfully
- [ ] Creates CREDENTIALS.txt file
- [ ] Services accessible at documented ports

### CA Certificate Script Tests
- [ ] Detects Linux distribution correctly
- [ ] Installs certificates to correct location
- [ ] Updates system trust store
- [ ] Removes certificates when --remove flag used
- [ ] Works on Ubuntu/Debian
- [ ] Works on RHEL/CentOS

### Stop Services Script Tests
- [ ] Stops all running services
- [ ] Preserves data by default
- [ ] Removes volumes when --remove-volumes flag used
- [ ] Handles services that aren't running gracefully

---

## Syntax Validation (Without Running)

You can validate Bash syntax on Windows using:

```powershell
# Install shellcheck (Bash linter)
# Via Chocolatey:
choco install shellcheck

# Or download from: https://github.com/koalaman/shellcheck/releases

# Check syntax
shellcheck linux/prepare-stack.sh
shellcheck linux/management/*.sh
```

---

## Quick WSL2 Test Commands

```bash
# Start WSL2
wsl

# Navigate to project
cd /mnt/c/Development/Github/Multi-Agent/docs/installation/docker/linux

# Make executable
chmod +x prepare-stack.sh management/*.sh

# Test prepare script (dry run - just check syntax)
bash -n prepare-stack.sh

# Test installer script syntax
bash -n management/docker-stack-installer.sh

# Actually run prepare script
./prepare-stack.sh

# Check output
ls -la dist/
```

---

## Common Issues and Solutions

### Issue: "Permission denied" when running scripts
**Solution:**
```bash
chmod +x script.sh
```

### Issue: "Docker daemon not running"
**Solution:**
```bash
sudo systemctl start docker
sudo systemctl status docker
```

### Issue: "User not in docker group"
**Solution:**
```bash
sudo usermod -aG docker $USER
# Log out and back in
```

### Issue: "unzip command not found"
**Solution:**
```bash
# Ubuntu/Debian
sudo apt-get install unzip

# RHEL/CentOS
sudo yum install unzip
```

---

## Automated Testing Script

Create a simple test script to validate all Linux scripts:

```bash
#!/bin/bash
# test-linux-scripts.sh

echo "Testing Linux Scripts..."

# Test syntax
echo "1. Checking syntax..."
bash -n prepare-stack.sh && echo "  ✓ prepare-stack.sh" || echo "  ✗ prepare-stack.sh"
bash -n management/docker-stack-installer.sh && echo "  ✓ docker-stack-installer.sh" || echo "  ✗ docker-stack-installer.sh"
bash -n management/stop-all-services.sh && echo "  ✓ stop-all-services.sh" || echo "  ✓ stop-all-services.sh"
bash -n management/install-ca-certificates.sh && echo "  ✓ install-ca-certificates.sh" || echo "  ✗ install-ca-certificates.sh"

# Test executability
echo "2. Checking execute permissions..."
[ -x prepare-stack.sh ] && echo "  ✓ prepare-stack.sh" || echo "  ✗ prepare-stack.sh (run: chmod +x)"
[ -x management/docker-stack-installer.sh ] && echo "  ✓ docker-stack-installer.sh" || echo "  ✗ docker-stack-installer.sh"
[ -x management/stop-all-services.sh ] && echo "  ✓ stop-all-services.sh" || echo "  ✗ stop-all-services.sh"
[ -x management/install-ca-certificates.sh ] && echo "  ✓ install-ca-certificates.sh" || echo "  ✗ install-ca-certificates.sh"

echo "Testing complete!"
```

Save this as `test-linux-scripts.sh` and run it in WSL2 or a Linux environment.
