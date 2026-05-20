# =================================================================
# Ollama Installation Script for Windows
# Description: Interactive installation wizard for Ollama
#              Supports two deployment modes:
#                docker  - Ollama runs in a Docker container (default)
#                hybrid  - Ollama runs natively on the host; only nginx
#                          HTTPS proxy runs in Docker
# Version: 1.1.0
# =================================================================

param(
    [string]$Port = "11434",
    [string]$HttpsPort = "11443",
    [switch]$EnableSSL = $false,
    [string]$Domain = "localhost",
    [ValidateSet("self-signed", "ca-provided", "")]
    [string]$CertType = "",
    [string]$MachineIPsParam = "",
    [ValidateSet("nvidia", "amd", "none")]
    [string]$GPUDriver = "none",
    [string]$HsaGfxOverride = "",
    [switch]$AutoStart = $false,
    [switch]$Force = $false,
    [ValidateSet("docker", "hybrid", "")]
    [string]$DeploymentMode = ""
)

# Ensure we're in the ollama directory (not management subdirectory)
$CurrentLocation = Get-Location
if ($CurrentLocation.Path.EndsWith("management")) {
    Set-Location ..
}

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "Ollama Installation Script (Docker / Hybrid)" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

# Check if Docker is running
Write-Host "Checking Docker availability..." -ForegroundColor White
try {
    docker version | Out-Null
    Write-Host "[OK] Docker is available" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Docker is not running or not installed!" -ForegroundColor Red
    Write-Host "Please install Docker Desktop and ensure it's running." -ForegroundColor Yellow
    exit 1
}

# Check if docker-compose is available
try {
    docker-compose version | Out-Null
    Write-Host "[OK] Docker Compose is available" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Docker Compose is not available!" -ForegroundColor Red
    Write-Host "Please ensure Docker Compose is installed." -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# Deployment Mode Selection
if (-not $DeploymentMode) {
    Write-Host "Deployment Mode:" -ForegroundColor Cyan
    Write-Host "  1) Docker  - Ollama runs in a Docker container (default)" -ForegroundColor White
    Write-Host "  2) Hybrid  - Ollama runs natively on the host; only nginx HTTPS proxy in Docker" -ForegroundColor White
    Write-Host ""
    Write-Host "  Choose Hybrid if you have a GPU that's awkward to pass through to Docker" -ForegroundColor Gray
    Write-Host "  (e.g. AMD on Windows), if Ollama is already installed natively, or if you" -ForegroundColor Gray
    Write-Host "  prefer to manage Ollama and its models outside Docker." -ForegroundColor Gray
    Write-Host ""
    $ModeChoice = Read-Host "Select deployment mode (1 or 2, default: 1)"
    if ($ModeChoice -eq "2") {
        $DeploymentMode = "hybrid"
    } else {
        $DeploymentMode = "docker"
    }
}
Write-Host "[OK] Deployment mode: $DeploymentMode" -ForegroundColor Green
Write-Host ""

# Hybrid mode pre-flight: verify native Ollama is installed and listening on 0.0.0.0
if ($DeploymentMode -eq "hybrid") {
    Write-Host "Hybrid Mode Pre-flight Checks" -ForegroundColor Cyan
    Write-Host "==================================================================" -ForegroundColor Gray

    # Check Ollama is installed natively
    $OllamaCmd = Get-Command ollama -ErrorAction SilentlyContinue
    if (-not $OllamaCmd) {
        Write-Host "[ERROR] Native Ollama not found on the host." -ForegroundColor Red
        Write-Host ""
        Write-Host "Hybrid mode requires Ollama to be installed natively on Windows." -ForegroundColor Yellow
        Write-Host "Install steps:" -ForegroundColor Yellow
        Write-Host "  1. Download the Windows installer from https://ollama.com/download" -ForegroundColor White
        Write-Host "  2. Run OllamaSetup.exe and complete the installer." -ForegroundColor White
        Write-Host "  3. Verify by running: ollama --version" -ForegroundColor White
        Write-Host "  4. Re-run this installer." -ForegroundColor White
        Write-Host ""
        exit 1
    }
    $OllamaVersionOutput = & ollama --version 2>&1
    Write-Host "[OK] Native Ollama found: $OllamaVersionOutput" -ForegroundColor Green

    # Set OLLAMA_HOST so the native server binds to all interfaces (reachable from Docker)
    $CurrentOllamaHost = [Environment]::GetEnvironmentVariable("OLLAMA_HOST", "User")
    if ($CurrentOllamaHost -ne "0.0.0.0:11434") {
        Write-Host "Setting OLLAMA_HOST=0.0.0.0:11434 (User scope)..." -ForegroundColor White
        [Environment]::SetEnvironmentVariable("OLLAMA_HOST", "0.0.0.0:11434", "User")
        Write-Host "[OK] OLLAMA_HOST set" -ForegroundColor Green
        Write-Host ""
        Write-Host "[ACTION REQUIRED] You must restart Ollama for this env var to take effect:" -ForegroundColor Yellow
        Write-Host "  1. Right-click the Ollama icon in the system tray and choose Quit." -ForegroundColor White
        Write-Host "  2. Re-launch Ollama from the Start menu." -ForegroundColor White
        Write-Host ""
        Read-Host "Press Enter once Ollama has been restarted"
    } else {
        Write-Host "[OK] OLLAMA_HOST already set to 0.0.0.0:11434" -ForegroundColor Green
    }

    # Verify Ollama is reachable on the configured host:port
    Write-Host "Verifying native Ollama is reachable..." -ForegroundColor White
    $MaxWait = 30
    $Waited = 0
    $OllamaReady = $false
    while ($Waited -lt $MaxWait) {
        try {
            $resp = Invoke-WebRequest -Uri "http://localhost:11434/api/version" -TimeoutSec 2 -UseBasicParsing -ErrorAction SilentlyContinue
            if ($resp.StatusCode -eq 200) {
                $OllamaReady = $true
                break
            }
        } catch {
            # still starting
        }
        Start-Sleep -Seconds 2
        $Waited += 2
        Write-Host "." -NoNewline -ForegroundColor Gray
    }
    Write-Host ""
    if (-not $OllamaReady) {
        Write-Host "[ERROR] Native Ollama is not responding on http://localhost:11434." -ForegroundColor Red
        Write-Host "  - Confirm Ollama is running (system tray icon present)." -ForegroundColor Yellow
        Write-Host "  - Confirm OLLAMA_HOST=0.0.0.0:11434 is set, then fully restart Ollama." -ForegroundColor Yellow
        Write-Host "  - Test with: curl http://localhost:11434/api/version" -ForegroundColor Yellow
        exit 1
    }
    Write-Host "[OK] Native Ollama is responding on port 11434" -ForegroundColor Green

    # Verify Ollama is bound to 0.0.0.0 (not 127.0.0.1) so the container can reach it
    $ListenLine = netstat -ano | Select-String ":11434\s" | Select-String "LISTENING" | Select-Object -First 1
    if ($ListenLine -and $ListenLine.Line -match "127\.0\.0\.1:11434") {
        Write-Host "[ERROR] Ollama is bound to 127.0.0.1:11434, not 0.0.0.0:11434." -ForegroundColor Red
        Write-Host "  Docker containers cannot reach 127.0.0.1 on the host." -ForegroundColor Yellow
        Write-Host "  Confirm OLLAMA_HOST is set, then fully quit and relaunch Ollama:" -ForegroundColor Yellow
        Write-Host "    [Environment]::GetEnvironmentVariable('OLLAMA_HOST', 'User')" -ForegroundColor Gray
        exit 1
    }
    Write-Host "[OK] Ollama is bound to all interfaces (Docker can reach it via host.docker.internal)" -ForegroundColor Green
    Write-Host ""
}

# Check if Ollama container is already running
Write-Host "Checking existing Ollama containers..." -ForegroundColor White
try {
    $ExistingContainers = docker-compose ps --format json 2>$null | ConvertFrom-Json
    $OllamaContainer = $ExistingContainers | Where-Object { $_.Service -eq "ollama" }
    
    if ($OllamaContainer -and $OllamaContainer.State -eq "running") {
        Write-Host "Ollama container is already running" -ForegroundColor Yellow
        if (-not $Force) {
            $StopChoice = Read-Host "Stop existing container to reconfigure? (y/n)"
            if ($StopChoice -eq "Y" -or $StopChoice -eq "y") {
                Write-Host "Stopping existing Ollama container..." -ForegroundColor Yellow
                docker-compose down
                Write-Host "[OK] Container stopped" -ForegroundColor Green
            } else {
                Write-Host "Installation cancelled - container still running" -ForegroundColor Yellow
                exit 0
            }
        } else {
            Write-Host "Force mode: Stopping existing container..." -ForegroundColor Yellow
            docker-compose down
        }
    } elseif ($OllamaContainer) {
        Write-Host "Ollama container exists but is not running" -ForegroundColor Gray
    } else {
        Write-Host "[OK] No existing Ollama containers found" -ForegroundColor Green
    }
} catch {
    Write-Host "[OK] No existing containers found" -ForegroundColor Green
}

Write-Host ""

# Create directory structure
Write-Host "Creating directory structure..." -ForegroundColor White
$Directories = @(
    "certs",
    "nginx"
)

foreach ($Dir in $Directories) {
    if (-not (Test-Path $Dir)) {
        New-Item -ItemType Directory -Force -Path $Dir | Out-Null
        Write-Host "[OK] Created directory: $Dir" -ForegroundColor Green
    } else {
        Write-Host "  Directory exists: $Dir" -ForegroundColor Gray
    }
}

Write-Host ""

# Check available disk space
Write-Host "Checking disk space..." -ForegroundColor White
$Drive = (Get-Location).Drive.Name
$DiskInfo = Get-PSDrive $Drive
$FreeSpaceGB = [math]::Round($DiskInfo.Free / 1GB, 2)
Write-Host "Available disk space: $FreeSpaceGB GB" -ForegroundColor White

if ($FreeSpaceGB -lt 20) {
    Write-Host "Warning: Low disk space! Recommended: 20 GB minimum" -ForegroundColor Yellow
    Write-Host "Models can be large (1-40 GB each)" -ForegroundColor Yellow
    $ContinueChoice = Read-Host "Continue anyway? (y/n)"
    if ($ContinueChoice -ne "Y" -and $ContinueChoice -ne "y") {
        Write-Host "Installation cancelled" -ForegroundColor Yellow
        exit 0
    }
} else {
    Write-Host "[OK] Sufficient disk space available" -ForegroundColor Green
}

Write-Host ""

# GPU Detection (Docker mode only — native Ollama handles its own GPU)
if ($DeploymentMode -eq "hybrid") {
    Write-Host "Skipping Docker GPU detection (native Ollama handles GPU directly)" -ForegroundColor Gray
    $GPUDriver = "none"
    $DetectedGPU = "none"
    Write-Host ""
} else {
Write-Host "Detecting GPU configuration..." -ForegroundColor White
$DetectedGPU = "none"

if ($GPUDriver -eq "none") {
    # Try to detect NVIDIA GPU
    try {
        nvidia-smi 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] NVIDIA GPU detected" -ForegroundColor Green
            $DetectedGPU = "nvidia"
            
            # Check for NVIDIA Docker runtime
            $DockerInfo = docker info 2>$null | Select-String "nvidia"
            if ($DockerInfo) {
                Write-Host "[OK] NVIDIA Docker runtime available" -ForegroundColor Green
            } else {
                Write-Host "⚠ NVIDIA Docker runtime not detected" -ForegroundColor Yellow
                Write-Host "  You may need to install nvidia-docker2" -ForegroundColor Gray
            }
        }
    } catch {
        # No NVIDIA GPU
    }
    
    # If no NVIDIA, check for AMD (basic check)
    if ($DetectedGPU -eq "none") {
        try {
            $GPU = Get-WmiObject Win32_VideoController | Where-Object { $_.Name -like "*AMD*" -or $_.Name -like "*Radeon*" }
            if ($GPU) {
                Write-Host "[OK] AMD GPU detected: $($GPU.Name)" -ForegroundColor Green
                Write-Host ""
                Write-Host "[WARN] AMD ROCm GPU passthrough is NOT supported in Docker Desktop on Windows." -ForegroundColor Yellow
                Write-Host "  Docker Desktop only supports NVIDIA GPU passthrough via the NVIDIA Container Toolkit." -ForegroundColor Gray
                Write-Host "  The ROCm Docker image (ollama/ollama:rocm) only works on Linux hosts with native Docker." -ForegroundColor Gray
                Write-Host ""
                Write-Host "  Recommendation: Install Ollama natively on Windows from https://ollama.com/download" -ForegroundColor Cyan
                Write-Host "  Native Ollama will auto-detect your AMD GPU via DirectML and provide GPU acceleration." -ForegroundColor Cyan
                Write-Host "  Then point your configuration to http://localhost:11434 instead of the Docker container." -ForegroundColor Cyan
                Write-Host ""
                Write-Host "  Continuing with CPU-only Docker mode..." -ForegroundColor Gray
                # AMD GPU detected but not usable in Docker on Windows - fall back to CPU
                $DetectedGPU = "none"
            }
        } catch {
            # No AMD GPU
        }
    }

    if ($DetectedGPU -eq "none") {
        Write-Host "Docker Ollama will use CPU only" -ForegroundColor Gray
        Write-Host "  CPU-only mode will be slower for model inference" -ForegroundColor Yellow
    }

    # Ask user to confirm GPU selection (only for NVIDIA on Windows)
    if ($DetectedGPU -ne "none") {
        Write-Host ""
        $GPUChoice = Read-Host "Use detected $DetectedGPU GPU? (y/n, default: y)"
        if ($GPUChoice -eq "n" -or $GPUChoice -eq "N") {
            $DetectedGPU = "none"
            Write-Host "GPU support disabled by user" -ForegroundColor Gray
        } else {
            $GPUDriver = $DetectedGPU
        }
    }
} else {
    Write-Host "GPU driver specified: $GPUDriver" -ForegroundColor White
    $DetectedGPU = $GPUDriver
}

Write-Host ""
} # end Docker-mode GPU detection

# Port configuration
if (-not $PSBoundParameters.ContainsKey('Port')) {
    $PortChoice = Read-Host "HTTP API port (default: 11434)"
    if ($PortChoice) {
        $Port = $PortChoice
    }
}

# Check if port is available
$PortInUse = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue
if ($PortInUse) {
    Write-Host "⚠ Warning: Port $Port is already in use!" -ForegroundColor Yellow
    $Process = Get-Process -Id $PortInUse[0].OwningProcess -ErrorAction SilentlyContinue
    if ($Process) {
        Write-Host "  Used by: $($Process.ProcessName)" -ForegroundColor Gray
    }
    $PortChoice = Read-Host "Enter a different port or press Enter to continue anyway"
    if ($PortChoice) {
        $Port = $PortChoice
    }
}

Write-Host "HTTP API will be accessible on port: $Port" -ForegroundColor White

Write-Host ""

# SSL Configuration
# In hybrid mode SSL is mandatory — otherwise the Docker container has no purpose
# (clients would talk to native Ollama directly on port 11434).
if ($DeploymentMode -eq "hybrid") {
    Write-Host "Hybrid mode: SSL is enabled automatically (the nginx container exists to provide HTTPS)" -ForegroundColor Cyan
    $EnableSSL = $true
} elseif (-not $PSBoundParameters.ContainsKey('EnableSSL')) {
    Write-Host "SSL/TLS Configuration:" -ForegroundColor Cyan
    Write-Host "Ollama uses Nginx reverse proxy for HTTPS support" -ForegroundColor Gray
    $SSLChoice = Read-Host "Enable SSL/TLS encryption? (y/n, default: n)"
    if ($SSLChoice -eq "Y" -or $SSLChoice -eq "y") {
        $EnableSSL = $true
    }
}

$GenerateSSL = $false
$MachineIPs = @()

if ($EnableSSL) {
    Write-Host "[OK] SSL/TLS will be enabled" -ForegroundColor Green

    # Ask for HTTPS port
    if (-not $PSBoundParameters.ContainsKey('HttpsPort')) {
        $HttpsPortChoice = Read-Host "HTTPS API port (default: 11443)"
        if ($HttpsPortChoice) {
            $HttpsPort = $HttpsPortChoice
        }
    }
    Write-Host "HTTPS API will be accessible on port: $HttpsPort" -ForegroundColor White

    if ($CertType) {
        if ($CertType -eq "ca-provided") {
            Write-Host "CA-provided certificates selected (from stack installer)" -ForegroundColor Green
            $GenerateSSL = $false
        } else {
            Write-Host "Self-signed certificates selected (from stack installer)" -ForegroundColor Green
            $GenerateSSL = $true
        }
        if ($MachineIPsParam) {
            $MachineIPs = $MachineIPsParam -split ','
        }
    } else {
        Write-Host ""
        Write-Host "Certificate Options:" -ForegroundColor White
        Write-Host "1. Generate self-signed certificates (for development/testing)" -ForegroundColor Gray
        Write-Host "2. Use CA-provided certificates (install later)" -ForegroundColor Gray
        $CertChoice = Read-Host "Select certificate type (1 or 2, default: 1)"

        if ($CertChoice -eq "2") {
            Write-Host "CA-provided certificates selected" -ForegroundColor Green
            Write-Host "You can install them after setup using: .\management\manage-ssl.ps1 install-ca" -ForegroundColor Cyan
            $GenerateSSL = $false
        } else {
            Write-Host "Self-signed certificates selected" -ForegroundColor Green
            $GenerateSSL = $true

            if (-not $PSBoundParameters.ContainsKey('Domain')) {
                $DomainChoice = Read-Host "Enter domain name for SSL certificate (default: localhost)"
                if ($DomainChoice) {
                    $Domain = $DomainChoice
                }
            }
            Write-Host "SSL certificates will be generated for domain: $Domain" -ForegroundColor White

            Write-Host ""
            Write-Host "Detecting machine IP addresses..." -ForegroundColor White
            try {
                $AllIPs = Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
                    $_.IPAddress -notmatch '^127\.' -and
                    ($_.PrefixOrigin -eq 'Dhcp' -or $_.PrefixOrigin -eq 'Manual')
                }

                if ($AllIPs.Count -gt 0) {
                    Write-Host "Detected IP addresses:" -ForegroundColor Green
                    for ($i = 0; $i -lt $AllIPs.Count; $i++) {
                        $adapter = Get-NetAdapter -InterfaceIndex $AllIPs[$i].InterfaceIndex
                        Write-Host "  [$i] $($AllIPs[$i].IPAddress) - $($adapter.InterfaceDescription)" -ForegroundColor White
                    }

                    Write-Host ""
                    $IPChoice = Read-Host "Enter IP numbers to include in certificate (comma-separated, e.g., '0,1') or press Enter to skip"

                    if ($IPChoice) {
                        $SelectedIndices = $IPChoice -split ',' | ForEach-Object { $_.Trim() }
                        foreach ($index in $SelectedIndices) {
                            if ($index -match '^\d+$' -and [int]$index -lt $AllIPs.Count) {
                                $MachineIPs += $AllIPs[[int]$index].IPAddress
                            }
                        }

                        if ($MachineIPs.Count -gt 0) {
                            Write-Host "Selected IPs: $($MachineIPs -join ', ')" -ForegroundColor Cyan
                        } else {
                            Write-Host "No valid IPs selected" -ForegroundColor Gray
                        }
                    } else {
                        Write-Host "IP addresses not included (localhost/domain only)" -ForegroundColor Gray
                    }
                } else {
                    Write-Host "Could not detect IP addresses, skipping" -ForegroundColor Gray
                }
            } catch {
                Write-Host "Could not detect IP addresses: $($_.Exception.Message)" -ForegroundColor Gray
            }
        }
    }
} else {
    Write-Host "SSL/TLS will be disabled (HTTP only)" -ForegroundColor Gray
}

Write-Host ""

# If SSL not enabled, still detect IPs for display purposes
if (-not $EnableSSL) {
    Write-Host "Detecting network configuration..." -ForegroundColor White
    try {
        $AllIPs = Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
            $_.IPAddress -notmatch '^127\.' -and
            ($_.PrefixOrigin -eq 'Dhcp' -or $_.PrefixOrigin -eq 'Manual')
        }
        
        if ($AllIPs.Count -gt 0) {
            Write-Host "[OK] Detected IP addresses:" -ForegroundColor Green
            foreach ($IP in $AllIPs) {
                $adapter = Get-NetAdapter -InterfaceIndex $IP.InterfaceIndex -ErrorAction SilentlyContinue
                if ($adapter) {
                    Write-Host "  • $($IP.IPAddress) - $($adapter.InterfaceDescription)" -ForegroundColor White
                    $MachineIPs += $IP.IPAddress
                }
            }
        } else {
            Write-Host "Could not detect IP addresses" -ForegroundColor Gray
        }
    } catch {
        Write-Host "Could not detect IP addresses: $($_.Exception.Message)" -ForegroundColor Gray
    }
}

Write-Host ""

# Create .env file
Write-Host "Creating configuration files..." -ForegroundColor White

if ($DeploymentMode -eq "hybrid") {
    # Hybrid mode: write a minimal .env with only the keys the hybrid compose actually uses.
    # COMPOSE_FILE makes docker-compose pick the hybrid compose by default — no -f flag needed
    # for any management commands.
    $envContent = @"
# =================================================================
# Ollama Hybrid Deployment Configuration
# Native Ollama runs on the host; only nginx HTTPS proxy runs in Docker.
# =================================================================
COMPOSE_FILE=docker-compose.hybrid.yml
OLLAMA_HTTPS_PORT=$HttpsPort
OLLAMA_DOMAIN=$Domain
"@
    $envContent | Set-Content ".env" -Encoding ASCII
    Write-Host "[OK] Wrote hybrid .env (COMPOSE_FILE=docker-compose.hybrid.yml)" -ForegroundColor Green
} else {
    # Docker mode: derive .env from .env.template
    if (-not (Test-Path ".env.template")) {
        Write-Host "[ERROR] .env.template not found!" -ForegroundColor Red
        Write-Host "Please ensure you're running this script from the ollama directory" -ForegroundColor Yellow
        exit 1
    }

    Copy-Item ".env.template" ".env" -Force
    Write-Host "[OK] Created .env file from template" -ForegroundColor Green

    # Update .env file with configuration
    $envContent = Get-Content ".env"
    $envContent = $envContent -replace "OLLAMA_PORT=.*", "OLLAMA_PORT=$Port"
    $envContent = $envContent -replace "OLLAMA_HTTPS_PORT=.*", "OLLAMA_HTTPS_PORT=$HttpsPort"
    $envContent = $envContent -replace "OLLAMA_ENABLE_SSL=.*", "OLLAMA_ENABLE_SSL=$($EnableSSL.ToString().ToLower())"
    $envContent = $envContent -replace "OLLAMA_DOMAIN=.*", "OLLAMA_DOMAIN=$Domain"
    $envContent = $envContent -replace "OLLAMA_GPU_DRIVER=.*", "OLLAMA_GPU_DRIVER=$GPUDriver"

    # Set Docker image based on GPU type
    if ($GPUDriver -eq "amd") {
        $envContent = $envContent -replace "OLLAMA_IMAGE=.*", "OLLAMA_IMAGE=ollama/ollama:rocm"
        Write-Host "[OK] Configured to use ROCm image (ollama/ollama:rocm)" -ForegroundColor Green
        $envContent = $envContent -replace "HSA_OVERRIDE_GFX_VERSION=.*", "HSA_OVERRIDE_GFX_VERSION=$HsaGfxOverride"
    } else {
        $envContent = $envContent -replace "OLLAMA_IMAGE=.*", "OLLAMA_IMAGE=ollama/ollama:latest"
    }

    # Add COMPOSE_PROFILES if SSL is enabled
    if ($EnableSSL) {
        $envContent += "`nCOMPOSE_PROFILES=ssl"
    }

    $envContent | Set-Content ".env"
    Write-Host "[OK] Updated .env with configuration" -ForegroundColor Green
}

# Update docker-compose.yml based on GPU type
# Note: AMD ROCm is not offered on Windows - GPU detection falls back to CPU-only
if ($GPUDriver -eq "nvidia") {
    Write-Host "Configuring NVIDIA GPU support in docker-compose.yml..." -ForegroundColor White

    # Insert deploy block with GPU reservations before the logging section of the ollama service
    $composeContent = Get-Content "docker-compose.yml" -Raw
    # Insert deploy block before the first "    logging:" line (ollama service)
    $lines = $composeContent -split "`n"
    $result = @()
    $inserted = $false
    foreach ($line in $lines) {
        if (-not $inserted -and $line -match '^    logging:$') {
            $result += "    deploy:"
            $result += "      resources:"
            $result += "        reservations:"
            $result += "          devices:"
            $result += "            - driver: nvidia"
            $result += "              count: all"
            $result += "              capabilities: [gpu]"
            $inserted = $true
        }
        $result += $line
    }
    ($result -join "`n") | Set-Content "docker-compose.yml" -NoNewline
    Write-Host "[OK] NVIDIA GPU support enabled in docker-compose.yml" -ForegroundColor Green
}

# Hybrid mode: verify the parallel hybrid compose + nginx config exist.
# These are committed parallel files (not generated) — selected by COMPOSE_FILE in .env.
if ($DeploymentMode -eq "hybrid") {
    if (-not (Test-Path "docker-compose.hybrid.yml")) {
        Write-Host "[ERROR] docker-compose.hybrid.yml is missing." -ForegroundColor Red
        Write-Host "  Re-extract the source ZIP — this file ships alongside docker-compose.yml." -ForegroundColor Yellow
        exit 1
    }
    if (-not (Test-Path "nginx/nginx.hybrid.conf")) {
        Write-Host "[ERROR] nginx/nginx.hybrid.conf is missing." -ForegroundColor Red
        Write-Host "  Re-extract the source ZIP — this file ships alongside nginx/nginx.conf." -ForegroundColor Yellow
        exit 1
    }
    Write-Host "[OK] Hybrid compose and nginx config present (selected via COMPOSE_FILE in .env)" -ForegroundColor Green
}

Write-Host ""

# Generate SSL certificates if requested
if ($GenerateSSL) {
    Write-Host "Generating SSL certificates..." -ForegroundColor White
    
    # Build IP list for SAN
    $IPList = @("127.0.0.1")
    if ($MachineIPs.Count -gt 0) {
        $IPList += $MachineIPs
    }
    
    try {
        # Generate CA private key
        Write-Host "  Generating CA certificate..." -ForegroundColor Gray
        docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl genrsa -out ca.key 4096 2>$null
        docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl req -new -x509 -days 365 -key ca.key -out ca.crt -subj "/C=US/ST=State/L=City/O=Ollama/CN=Ollama-CA" 2>$null
        
        # Generate server private key
        Write-Host "  Generating server certificate..." -ForegroundColor Gray
        docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl genrsa -out server.key 4096 2>$null
        
        # Create OpenSSL config with SAN
        $SANEntries = @("DNS:localhost", "DNS:$Domain", "IP:127.0.0.1")
        foreach ($IP in $MachineIPs) {
            $SANEntries += "IP:$IP"
        }
        $SANString = $SANEntries -join ","
        
        $opensslConfig = @"
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req

[req_distinguished_name]

[v3_req]
subjectAltName = $SANString
"@
        $opensslConfig | Out-File -FilePath "certs\openssl.cnf" -Encoding ASCII
        
        # Generate CSR and sign certificate
        docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl req -new -key server.key -out server.csr -subj "/C=US/ST=State/L=City/O=Ollama/CN=$Domain" -config openssl.cnf 2>$null
        docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 365 -extensions v3_req -extfile openssl.cnf 2>$null
        
        # Cleanup temporary files
        Remove-Item "certs\server.csr" -ErrorAction SilentlyContinue
        Remove-Item "certs\ca.srl" -ErrorAction SilentlyContinue
        Remove-Item "certs\openssl.cnf" -ErrorAction SilentlyContinue
        
        if ((Test-Path "certs\server.crt") -and (Test-Path "certs\server.key")) {
            Write-Host "[OK] SSL certificates generated successfully" -ForegroundColor Green
        } else {
            Write-Host "[ERROR] Certificate generation failed" -ForegroundColor Red
            $EnableSSL = $false
        }
    } catch {
        Write-Host "[ERROR] SSL certificate generation failed: $($_.Exception.Message)" -ForegroundColor Red
        $EnableSSL = $false
    }
}

Write-Host ""

# When called from stack installer (-Force), only configure - don't start services
if ($Force) {
    Write-Host ""
    Write-Host "[OK] Ollama configuration complete (services will be started by stack installer)" -ForegroundColor Green
    exit 0
}

# Ask if user wants to start the service now
Write-Host ""
$StartPrompt = if ($DeploymentMode -eq "hybrid") { "Start nginx HTTPS proxy now? (y/n, default: y)" } else { "Start Ollama service now? (y/n, default: y)" }
$StartChoice = Read-Host $StartPrompt
if ($StartChoice -eq "n" -or $StartChoice -eq "N") {
    Write-Host ""
    Write-Host "==================================================================" -ForegroundColor Cyan
    Write-Host "Configuration Complete!" -ForegroundColor Green
    Write-Host "==================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "To start later, run:" -ForegroundColor Gray
    Write-Host "  docker-compose up -d" -ForegroundColor Gray
    Write-Host ""
    exit 0
}

if ($DeploymentMode -eq "hybrid") {
    # Hybrid mode: only nginx-ssl needs to start. Native Ollama is already running.
    Write-Host "Starting nginx HTTPS proxy..." -ForegroundColor White

    try {
        docker-compose up -d

        # Wait for nginx to start serving HTTPS
        Write-Host "Waiting for nginx to become ready..." -ForegroundColor Gray
        $maxWait = 30
        $waited = 0
        $healthy = $false

        while ($waited -lt $maxWait) {
            Start-Sleep -Seconds 2
            $waited += 2

            try {
                # -k to skip cert verification on self-signed certs
                $response = Invoke-WebRequest -Uri "https://localhost:$HttpsPort/api/version" -TimeoutSec 2 -UseBasicParsing -SkipCertificateCheck -ErrorAction SilentlyContinue
                if ($response.StatusCode -eq 200) {
                    $healthy = $true
                    break
                }
            } catch {
                # still starting
            }

            Write-Host "." -NoNewline -ForegroundColor Gray
        }

        Write-Host ""

        if ($healthy) {
            Write-Host "[OK] nginx HTTPS proxy is running and reaching native Ollama" -ForegroundColor Green
        } else {
            Write-Host "⚠ nginx started but HTTPS health check timed out" -ForegroundColor Yellow
            Write-Host "  Probe from inside the container to find the cause:" -ForegroundColor Gray
            Write-Host "    docker exec ollama-nginx-ssl wget -qO- http://host.docker.internal:11434/api/version" -ForegroundColor Gray
            Write-Host "  See logs: docker-compose logs nginx-ssl" -ForegroundColor Gray
        }
    } catch {
        Write-Host "[ERROR] Failed to start nginx-ssl: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Check logs: docker-compose logs nginx-ssl" -ForegroundColor Yellow
        exit 1
    }
} else {
    # Docker mode: full Ollama-in-container startup with health check
    Write-Host "Starting Ollama service..." -ForegroundColor White
    Write-Host "This may take a minute..." -ForegroundColor Gray

    try {
        docker-compose up -d

        # Wait for health check
        Write-Host "Waiting for Ollama to become healthy..." -ForegroundColor Gray
        $maxWait = 60
        $waited = 0
        $healthy = $false

        while ($waited -lt $maxWait) {
            Start-Sleep -Seconds 2
            $waited += 2

            try {
                $response = Invoke-WebRequest -Uri "http://localhost:$Port/api/version" -TimeoutSec 2 -UseBasicParsing -ErrorAction SilentlyContinue
                if ($response.StatusCode -eq 200) {
                    $healthy = $true
                    break
                }
            } catch {
                # Still waiting
            }

            Write-Host "." -NoNewline -ForegroundColor Gray
        }

        Write-Host ""

        if ($healthy) {
            Write-Host "[OK] Ollama service is running and healthy" -ForegroundColor Green

            # Verify GPU access if GPU is enabled (only NVIDIA is supported in Docker on Windows)
            if ($GPUDriver -eq "nvidia") {
                Write-Host ""
                Write-Host "Verifying NVIDIA GPU access..." -ForegroundColor Cyan
                Start-Sleep -Seconds 3
                docker exec ollama nvidia-smi 2>$null | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "[OK] NVIDIA GPU accessible in container" -ForegroundColor Green
                } else {
                    Write-Host "⚠ NVIDIA GPU not accessible in container" -ForegroundColor Yellow
                    Write-Host "  Verify nvidia-container-toolkit is installed" -ForegroundColor Gray
                }
            }

            # Start nginx-ssl if SSL is enabled
            if ($EnableSSL) {
                Write-Host "Starting nginx-ssl service..." -ForegroundColor Gray
                docker-compose up -d nginx-ssl 2>&1 | Out-Null
                Start-Sleep -Seconds 3
                Write-Host "[OK] nginx-ssl service started" -ForegroundColor Green
            }
        } else {
            Write-Host "⚠ Ollama service started but health check timed out" -ForegroundColor Yellow
            Write-Host "  Check logs with: docker-compose logs ollama" -ForegroundColor Gray
            if ($EnableSSL) {
                Write-Host "  nginx-ssl will start once ollama becomes healthy" -ForegroundColor Gray
            }
        }
    } catch {
        Write-Host "[ERROR] Failed to start Ollama service: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Check logs with: docker-compose logs ollama" -ForegroundColor Yellow
        exit 1
    }
}

Write-Host ""

# Display service status
Write-Host "Service Status:" -ForegroundColor Cyan
try {
    $containers = docker-compose ps --format json | ConvertFrom-Json
    foreach ($container in $containers) {
        $status = if ($container.State -eq "running") { "[OK]" } else { "[STOPPED]" }
        $color = if ($container.State -eq "running") { "Green" } else { "Red" }
        Write-Host "  $status $($container.Service): $($container.State)" -ForegroundColor $color
    }
} catch {
    Write-Host "  Could not retrieve container status" -ForegroundColor Gray
}

Write-Host ""

Write-Host ""
Write-Host "Model Downloads:" -ForegroundColor Cyan
Write-Host "Ollama requires at least one embedding model to function properly" -ForegroundColor White
Write-Host ""
Write-Host "Download models using:" -ForegroundColor White
if ($DeploymentMode -eq "hybrid") {
    Write-Host "  ollama pull nomic-embed-text:latest" -ForegroundColor Gray
    Write-Host "  ollama pull llama3.2:3b" -ForegroundColor Gray
    Write-Host ""
    Write-Host "(Hybrid mode: models are managed natively, not via docker exec)" -ForegroundColor Gray
} else {
    Write-Host "  docker exec ollama ollama pull nomic-embed-text:latest" -ForegroundColor Gray
    Write-Host "  docker exec ollama ollama pull llama3.2:3b" -ForegroundColor Gray
}
Write-Host ""
Write-Host "List available models: https://ollama.com/library" -ForegroundColor Gray
Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "Installation Complete!" -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

# Display connection information
Write-Host "Connection Information:" -ForegroundColor Cyan
if ($DeploymentMode -eq "hybrid") {
    Write-Host "  HTTP API:  http://localhost:11434  (native Ollama on host, not via Docker)" -ForegroundColor White
    Write-Host "  HTTPS API: https://localhost:$HttpsPort  (via nginx Docker container)" -ForegroundColor White
    if ($MachineIPs.Count -gt 0) {
        foreach ($IP in $MachineIPs) {
            Write-Host "             https://${IP}:$HttpsPort" -ForegroundColor White
        }
    }
    Write-Host ""
    Write-Host "  CA Certificate: certs\ca.crt (distribute to clients)" -ForegroundColor Yellow
} else {
    Write-Host "  HTTP API:  http://localhost:$Port" -ForegroundColor White
    if ($MachineIPs.Count -gt 0) {
        foreach ($IP in $MachineIPs) {
            Write-Host "             http://${IP}:$Port" -ForegroundColor White
        }
    }

    if ($EnableSSL) {
        Write-Host "  HTTPS API: https://localhost:$HttpsPort" -ForegroundColor White
        if ($MachineIPs.Count -gt 0) {
            foreach ($IP in $MachineIPs) {
                Write-Host "             https://${IP}:$HttpsPort" -ForegroundColor White
            }
        }
        Write-Host ""
        Write-Host "  CA Certificate: certs\ca.crt (distribute to clients)" -ForegroundColor Yellow
    }
}

Write-Host ""
if ($DeploymentMode -eq "hybrid") {
    Write-Host "Deployment: Hybrid (native Ollama + Docker nginx)" -ForegroundColor White
} else {
    Write-Host "GPU Support: $GPUDriver" -ForegroundColor White
}
Write-Host ""

# Display firewall configuration
Write-Host "Firewall Configuration:" -ForegroundColor Cyan
Write-Host "To allow external access, configure Windows Firewall:" -ForegroundColor White
Write-Host ""
if ($DeploymentMode -eq "hybrid") {
    Write-Host "  New-NetFirewallRule -DisplayName 'Ollama HTTPS' -Direction Inbound -LocalPort $HttpsPort -Protocol TCP -Action Allow" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Note: native Ollama listens on 0.0.0.0:11434 already. To restrict that to" -ForegroundColor Gray
    Write-Host "        Docker only (recommended), allow inbound 11434 only from the Docker" -ForegroundColor Gray
    Write-Host "        bridge subnet (typically 172.16.0.0/12)." -ForegroundColor Gray
} else {
    Write-Host "  New-NetFirewallRule -DisplayName 'Ollama HTTP' -Direction Inbound -LocalPort $Port -Protocol TCP -Action Allow" -ForegroundColor Gray
    if ($EnableSSL) {
        Write-Host "  New-NetFirewallRule -DisplayName 'Ollama HTTPS' -Direction Inbound -LocalPort $HttpsPort -Protocol TCP -Action Allow" -ForegroundColor Gray
    }
}
Write-Host ""

# Test commands
Write-Host "Test Commands:" -ForegroundColor Cyan
if ($DeploymentMode -eq "hybrid") {
    Write-Host "  curl http://localhost:11434/api/version    (direct to native Ollama)" -ForegroundColor Gray
    Write-Host "  curl -k https://localhost:$HttpsPort/api/version    (via nginx HTTPS proxy)" -ForegroundColor Gray
} else {
    Write-Host "  curl http://localhost:$Port/api/version" -ForegroundColor Gray
    if ($EnableSSL) {
        Write-Host "  curl -k https://localhost:$HttpsPort/api/version" -ForegroundColor Gray
    }
}
Write-Host ""

# Management commands
Write-Host "Management Commands:" -ForegroundColor Cyan
if ($DeploymentMode -eq "hybrid") {
    Write-Host "  nginx logs:    docker-compose logs -f nginx-ssl" -ForegroundColor Gray
    Write-Host "  nginx status:  docker-compose ps" -ForegroundColor Gray
    Write-Host "  Models:        ollama list  /  ollama pull <name>  (native commands)" -ForegroundColor Gray
    Write-Host "  SSL:           .\management\manage-ssl.ps1 status" -ForegroundColor Gray
} else {
    Write-Host "  Status:  .\management\manage-ollama.ps1 status" -ForegroundColor Gray
    Write-Host "  Logs:    .\management\manage-ollama.ps1 logs" -ForegroundColor Gray
    Write-Host "  Models:  .\management\pull-models.ps1" -ForegroundColor Gray
    if ($EnableSSL) {
        Write-Host "  SSL:     .\management\manage-ssl.ps1 status" -ForegroundColor Gray
    }
}
Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
