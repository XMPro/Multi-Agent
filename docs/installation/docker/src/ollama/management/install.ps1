# =================================================================
# Ollama Installation Script for Windows
# Description: Interactive installation wizard for Ollama Docker deployment
# Version: 1.0.0
# =================================================================

param(
    [string]$Port = "11434",
    [string]$HttpsPort = "11443",
    [switch]$EnableSSL = $false,
    [string]$Domain = "localhost",
    [ValidateSet("nvidia", "amd", "none")]
    [string]$GPUDriver = "none",
    [switch]$AutoStart = $false,
    [switch]$Force = $false
)

# Ensure we're in the ollama directory (not management subdirectory)
$CurrentLocation = Get-Location
if ($CurrentLocation.Path.EndsWith("management")) {
    Set-Location ..
}

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "Ollama Docker Installation Script" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

# Check if Docker is running
Write-Host "Checking Docker availability..." -ForegroundColor White
try {
    docker version | Out-Null
    Write-Host "✓ Docker is available" -ForegroundColor Green
} catch {
    Write-Host "✗ Docker is not running or not installed!" -ForegroundColor Red
    Write-Host "Please install Docker Desktop and ensure it's running." -ForegroundColor Yellow
    exit 1
}

# Check if docker-compose is available
try {
    docker-compose version | Out-Null
    Write-Host "✓ Docker Compose is available" -ForegroundColor Green
} catch {
    Write-Host "✗ Docker Compose is not available!" -ForegroundColor Red
    Write-Host "Please ensure Docker Compose is installed." -ForegroundColor Yellow
    exit 1
}

Write-Host ""

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
                Write-Host "✓ Container stopped" -ForegroundColor Green
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
        Write-Host "✓ No existing Ollama containers found" -ForegroundColor Green
    }
} catch {
    Write-Host "✓ No existing containers found" -ForegroundColor Green
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
        Write-Host "✓ Created directory: $Dir" -ForegroundColor Green
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
    Write-Host "✓ Sufficient disk space available" -ForegroundColor Green
}

Write-Host ""

# GPU Detection
Write-Host "Detecting GPU configuration..." -ForegroundColor White
$DetectedGPU = "none"

if ($GPUDriver -eq "none") {
    # Try to detect NVIDIA GPU
    try {
        $NvidiaSmi = nvidia-smi 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ NVIDIA GPU detected" -ForegroundColor Green
            $DetectedGPU = "nvidia"
            
            # Check for NVIDIA Docker runtime
            $DockerInfo = docker info 2>$null | Select-String "nvidia"
            if ($DockerInfo) {
                Write-Host "✓ NVIDIA Docker runtime available" -ForegroundColor Green
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
                Write-Host "✓ AMD GPU detected" -ForegroundColor Green
                Write-Host "⚠ AMD GPU support requires ROCm drivers" -ForegroundColor Yellow
                $DetectedGPU = "amd"
            }
        } catch {
            # No AMD GPU
        }
    }
    
    if ($DetectedGPU -eq "none") {
        Write-Host "No GPU detected - will use CPU only" -ForegroundColor Gray
        Write-Host "⚠ CPU-only mode will be slower for model inference" -ForegroundColor Yellow
    }
    
    # Ask user to confirm GPU selection
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
if (-not $PSBoundParameters.ContainsKey('EnableSSL')) {
    Write-Host "SSL/TLS Configuration:" -ForegroundColor Cyan
    Write-Host "Ollama uses Nginx reverse proxy for HTTPS support" -ForegroundColor Gray
    $SSLChoice = Read-Host "Enable SSL/TLS encryption? (y/n, default: n)"
    if ($SSLChoice -eq "Y" -or $SSLChoice -eq "y") {
        $EnableSSL = $true
    }
}

$GenerateSSL = $false
if ($EnableSSL) {
    Write-Host "✓ SSL/TLS will be enabled" -ForegroundColor Green
    
    # Ask for HTTPS port
    if (-not $PSBoundParameters.ContainsKey('HttpsPort')) {
        $HttpsPortChoice = Read-Host "HTTPS API port (default: 11443)"
        if ($HttpsPortChoice) {
            $HttpsPort = $HttpsPortChoice
        }
    }
    Write-Host "HTTPS API will be accessible on port: $HttpsPort" -ForegroundColor White
    
    # Ask for certificate type
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
        
        # Ask for domain name
        if (-not $PSBoundParameters.ContainsKey('Domain')) {
            $DomainChoice = Read-Host "Enter domain name for SSL certificate (default: localhost)"
            if ($DomainChoice) {
                $Domain = $DomainChoice
            }
        }
        Write-Host "SSL certificates will be generated for domain: $Domain" -ForegroundColor White
    }
} else {
    Write-Host "SSL/TLS will be disabled (HTTP only)" -ForegroundColor Gray
}

Write-Host ""

# Detect machine IP addresses for network accessibility info
Write-Host "Detecting network configuration..." -ForegroundColor White
$MachineIPs = @()
try {
    $AllIPs = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { 
        $_.IPAddress -notmatch '^127\.' -and 
        ($_.PrefixOrigin -eq 'Dhcp' -or $_.PrefixOrigin -eq 'Manual') 
    }
    
    if ($AllIPs.Count -gt 0) {
        Write-Host "✓ Detected IP addresses:" -ForegroundColor Green
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

Write-Host ""

# Create .env file from template
Write-Host "Creating configuration files..." -ForegroundColor White

if (-not (Test-Path ".env.template")) {
    Write-Host "✗ Error: .env.template not found!" -ForegroundColor Red
    Write-Host "Please ensure you're running this script from the ollama directory" -ForegroundColor Yellow
    exit 1
}

# Copy template to .env
Copy-Item ".env.template" ".env" -Force
Write-Host "✓ Created .env file from template" -ForegroundColor Green

# Update .env file with configuration
$envContent = Get-Content ".env"
$envContent = $envContent -replace "OLLAMA_PORT=.*", "OLLAMA_PORT=$Port"
$envContent = $envContent -replace "OLLAMA_HTTPS_PORT=.*", "OLLAMA_HTTPS_PORT=$HttpsPort"
$envContent = $envContent -replace "OLLAMA_ENABLE_SSL=.*", "OLLAMA_ENABLE_SSL=$($EnableSSL.ToString().ToLower())"
$envContent = $envContent -replace "OLLAMA_DOMAIN=.*", "OLLAMA_DOMAIN=$Domain"
$envContent = $envContent -replace "OLLAMA_GPU_DRIVER=.*", "OLLAMA_GPU_DRIVER=$GPUDriver"

# Add COMPOSE_PROFILES if SSL is enabled
if ($EnableSSL) {
    $envContent += "`nCOMPOSE_PROFILES=ssl"
}

$envContent | Set-Content ".env"
Write-Host "✓ Updated .env with configuration" -ForegroundColor Green

# Update docker-compose.yml if GPU is enabled
if ($GPUDriver -ne "none") {
    Write-Host "Configuring GPU support in docker-compose.yml..." -ForegroundColor White
    
    $composeContent = Get-Content "docker-compose.yml"
    $updatedContent = @()
    $inDeploySection = $false
    $skipLine = $false
    
    for ($i = 0; $i -lt $composeContent.Count; $i++) {
        $line = $composeContent[$i]
        
        # Detect the commented deploy section
        if ($line -match '^\s*#\s*deploy:') {
            $updatedContent += $line -replace '^\s*#\s*', '    '
            $inDeploySection = $true
        }
        elseif ($inDeploySection -and $line -match '^\s*#') {
            # Uncomment lines in the deploy section
            $updatedContent += $line -replace '^\s*#\s*', '    '
            
            # Update driver if needed
            if ($line -match 'driver:' -and $GPUDriver -eq "amd") {
                $updatedContent[-1] = $updatedContent[-1] -replace 'nvidia', 'amd'
            }
            
            # Check if we're at the end of the deploy section
            if ($line -match 'capabilities:') {
                $inDeploySection = $false
            }
        }
        else {
            $updatedContent += $line
            $inDeploySection = $false
        }
    }
    
    $updatedContent | Set-Content "docker-compose.yml"
    Write-Host "✓ GPU support enabled in docker-compose.yml" -ForegroundColor Green
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
            Write-Host "✓ SSL certificates generated successfully" -ForegroundColor Green
        } else {
            Write-Host "✗ Certificate generation failed" -ForegroundColor Red
            $EnableSSL = $false
        }
    } catch {
        Write-Host "✗ SSL certificate generation failed: $($_.Exception.Message)" -ForegroundColor Red
        $EnableSSL = $false
    }
}

Write-Host ""

# Start Docker containers
Write-Host "Starting Ollama service..." -ForegroundColor White
Write-Host "This may take a minute..." -ForegroundColor Gray

try {
    docker-compose up -d 2>&1 | Out-Null
    
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
        Write-Host "✓ Ollama service is running and healthy" -ForegroundColor Green
    } else {
        Write-Host "⚠ Ollama service started but health check timed out" -ForegroundColor Yellow
        Write-Host "  Check logs with: docker-compose logs ollama" -ForegroundColor Gray
    }
} catch {
    Write-Host "✗ Failed to start Ollama service: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Check logs with: docker-compose logs ollama" -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# Display service status
Write-Host "Service Status:" -ForegroundColor Cyan
try {
    $containers = docker-compose ps --format json | ConvertFrom-Json
    foreach ($container in $containers) {
        $status = if ($container.State -eq "running") { "✓" } else { "✗" }
        $color = if ($container.State -eq "running") { "Green" } else { "Red" }
        Write-Host "  $status $($container.Service): $($container.State)" -ForegroundColor $color
    }
} catch {
    Write-Host "  Could not retrieve container status" -ForegroundColor Gray
}

Write-Host ""

# Ask about model downloads
Write-Host "Model Downloads:" -ForegroundColor Cyan
Write-Host "Ollama requires at least one embedding model to function properly" -ForegroundColor White
$DownloadChoice = Read-Host "Download required models now? (y/n, default: y)"

if ($DownloadChoice -ne "n" -and $DownloadChoice -ne "N") {
    Write-Host ""
    Write-Host "Launching model download wizard..." -ForegroundColor White
    Start-Sleep -Seconds 1
    & ".\management\pull-models.ps1"
}

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "Installation Complete!" -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

# Display connection information
Write-Host "Connection Information:" -ForegroundColor Cyan
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

Write-Host ""
Write-Host "GPU Support: $GPUDriver" -ForegroundColor White
Write-Host ""

# Display firewall configuration
Write-Host "Firewall Configuration:" -ForegroundColor Cyan
Write-Host "To allow external access, configure Windows Firewall:" -ForegroundColor White
Write-Host ""
Write-Host "  New-NetFirewallRule -DisplayName 'Ollama HTTP' -Direction Inbound -LocalPort $Port -Protocol TCP -Action Allow" -ForegroundColor Gray
if ($EnableSSL) {
    Write-Host "  New-NetFirewallRule -DisplayName 'Ollama HTTPS' -Direction Inbound -LocalPort $HttpsPort -Protocol TCP -Action Allow" -ForegroundColor Gray
}
Write-Host ""

# Test commands
Write-Host "Test Commands:" -ForegroundColor Cyan
Write-Host "  curl http://localhost:$Port/api/version" -ForegroundColor Gray
if ($EnableSSL) {
    Write-Host "  curl -k https://localhost:$HttpsPort/api/version" -ForegroundColor Gray
}
Write-Host ""

# Management commands
Write-Host "Management Commands:" -ForegroundColor Cyan
Write-Host "  Status:  .\management\manage-ollama.ps1 status" -ForegroundColor Gray
Write-Host "  Logs:    .\management\manage-ollama.ps1 logs" -ForegroundColor Gray
Write-Host "  Models:  .\management\pull-models.ps1" -ForegroundColor Gray
if ($EnableSSL) {
    Write-Host "  SSL:     .\management\manage-ssl.ps1 status" -ForegroundColor Gray
}
Write-Host ""

# Create CREDENTIALS.txt
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$credentialsContent = @"
Ollama Service Configuration
=============================
Installation Date: $timestamp

Connection Information:
-----------------------
HTTP API:  http://localhost:$Port
"@

if ($MachineIPs.Count -gt 0) {
    foreach ($IP in $MachineIPs) {
        $credentialsContent += "`n           http://${IP}:$Port"
    }
}

if ($EnableSSL) {
    $credentialsContent += "`n`nHTTPS API: https://localhost:$HttpsPort"
    if ($MachineIPs.Count -gt 0) {
        foreach ($IP in $MachineIPs) {
            $credentialsContent += "`n           https://${IP}:$HttpsPort"
        }
    }
}

$credentialsContent += @"


Service Configuration:
----------------------
Container:   ollama (Running)
GPU Support: $GPUDriver
Network:     Accessible from other machines (configure firewall)

"@

if ($EnableSSL) {
    $credentialsContent += @"
SSL Configuration:
------------------
Enabled:     Yes
CA Cert:     certs\ca.crt (distribute to clients)
Server Cert: certs\server.crt
Domain:      $Domain

"@
} else {
    $credentialsContent += @"
SSL Configuration:
------------------
Enabled:     No (HTTP only)

"@
}

$credentialsContent += @"
Firewall Configuration:
-----------------------
Run these commands to allow external access:

New-NetFirewallRule -DisplayName "Ollama HTTP" -Direction Inbound -LocalPort $Port -Protocol TCP -Action Allow
"@

if ($EnableSSL) {
    $credentialsContent += "New-NetFirewallRule -DisplayName `"Ollama HTTPS`" -Direction Inbound -LocalPort $HttpsPort -Protocol TCP -Action Allow`n"
}

$credentialsContent += @"

Test Connection:
----------------
curl http://localhost:$Port/api/version
"@

if ($EnableSSL) {
    $credentialsContent += "`ncurl -k https://localhost:$HttpsPort/api/version"
}

$credentialsContent += @"


Management Commands:
--------------------
Status:  .\management\manage-ollama.ps1 status
Logs:    .\management\manage-ollama.ps1 logs
Models:  .\management\pull-models.ps1
"@

if ($EnableSSL) {
    $credentialsContent += "SSL:     .\management\manage-ssl.ps1 status`n"
}

$credentialsContent += @"

Downloaded Models:
------------------
Run: docker exec ollama ollama list

Next Steps:
-----------
1. Configure firewall rules (see above)
2. Download required models: .\management\pull-models.ps1
3. Test API connectivity from another machine
4. Distribute CA certificate to clients (if using SSL)

"@

$credentialsContent | Out-File -FilePath "CREDENTIALS.txt" -Encoding UTF8
Write-Host "✓ Configuration saved to CREDENTIALS.txt" -ForegroundColor Green
Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
