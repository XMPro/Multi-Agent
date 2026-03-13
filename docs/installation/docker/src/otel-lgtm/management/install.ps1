# =================================================================
# OpenTelemetry LGTM Stack Installation Script for Windows
# Description: Interactive installation wizard for LGTM Docker deployment
# (Grafana + Loki + Tempo + Mimir + OpenTelemetry Collector)
# Version: 1.0.0
# =================================================================

param(
    [string]$Port = "3000",
    [string]$HttpsPort = "3443",
    [switch]$EnableSSL = $false,
    [string]$Domain = "localhost",
    [string]$Password = "",
    [switch]$AutoStart = $false,
    [switch]$Force = $false
)

# Ensure we're in the otel-lgtm directory (not management subdirectory)
$CurrentLocation = Get-Location
if ($CurrentLocation.Path.EndsWith("management")) {
    Set-Location ..
}

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "OpenTelemetry LGTM Stack Installation Script" -ForegroundColor Cyan
Write-Host "(Grafana + Loki + Tempo + Mimir + OTEL Collector)" -ForegroundColor Cyan
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

# Check if containers are already running
Write-Host "Checking existing LGTM containers..." -ForegroundColor White
try {
    $ExistingContainers = docker-compose ps --format json 2>$null | ConvertFrom-Json
    $LgtmContainer = $ExistingContainers | Where-Object { $_.Service -eq "otel-lgtm" }

    if ($LgtmContainer -and $LgtmContainer.State -eq "running") {
        Write-Host "LGTM container is already running" -ForegroundColor Yellow
        if (-not $Force) {
            $StopChoice = Read-Host "Stop existing container to reconfigure? (y/n)"
            if ($StopChoice -eq "Y" -or $StopChoice -eq "y") {
                Write-Host "Stopping existing LGTM containers..." -ForegroundColor Yellow
                docker-compose down
                Write-Host "[OK] Containers stopped" -ForegroundColor Green
            } else {
                Write-Host "Installation cancelled - containers still running" -ForegroundColor Yellow
                exit 0
            }
        } else {
            Write-Host "Force mode: Stopping existing containers..." -ForegroundColor Yellow
            docker-compose down
        }
    } else {
        Write-Host "[OK] No existing LGTM containers found" -ForegroundColor Green
    }
} catch {
    Write-Host "[OK] No existing containers found" -ForegroundColor Green
}

Write-Host ""

# Create directory structure
Write-Host "Creating directory structure..." -ForegroundColor White
$Directories = @("certs", "nginx", "collector", "otel-lgtm-data")

foreach ($Dir in $Directories) {
    if (-not (Test-Path $Dir)) {
        New-Item -ItemType Directory -Force -Path $Dir | Out-Null
        Write-Host "[OK] Created directory: $Dir" -ForegroundColor Green
    } else {
        Write-Host "  Directory exists: $Dir" -ForegroundColor Gray
    }
}

Write-Host ""

# Port configuration
if (-not $PSBoundParameters.ContainsKey('Port') -and -not $Force) {
    $PortChoice = Read-Host "Grafana UI port (default: 3000)"
    if ($PortChoice) {
        $Port = $PortChoice
    }
}

# Check if port is available
$PortInUse = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue
if ($PortInUse) {
    Write-Host "Warning: Port $Port is already in use!" -ForegroundColor Yellow
    $Process = Get-Process -Id $PortInUse[0].OwningProcess -ErrorAction SilentlyContinue
    if ($Process) {
        Write-Host "  Used by: $($Process.ProcessName)" -ForegroundColor Gray
    }
    if (-not $Force) {
        $PortChoice = Read-Host "Enter a different port or press Enter to continue anyway"
        if ($PortChoice) {
            $Port = $PortChoice
        }
    }
}

Write-Host "Grafana UI will be accessible on port: $Port" -ForegroundColor White
Write-Host "OTLP gRPC will be accessible on port: 4317" -ForegroundColor White
Write-Host "OTLP HTTP will be accessible on port: 4318" -ForegroundColor White

Write-Host ""

# Grafana admin password
if (-not $Password -and -not $Force) {
    Write-Host "Grafana Admin Configuration:" -ForegroundColor Cyan
    $PassChoice = Read-Host "Grafana admin password (default: admin)"
    if ($PassChoice) {
        $Password = $PassChoice
    } else {
        $Password = "admin"
    }
} elseif (-not $Password) {
    $Password = "admin"
}

Write-Host ""

# SSL Configuration
if (-not $PSBoundParameters.ContainsKey('EnableSSL') -and -not $Force) {
    Write-Host "SSL/TLS Configuration:" -ForegroundColor Cyan
    Write-Host "LGTM uses Nginx reverse proxy for HTTPS support on Grafana UI" -ForegroundColor Gray
    $SSLChoice = Read-Host "Enable SSL/TLS encryption? (y/n, default: n)"
    if ($SSLChoice -eq "Y" -or $SSLChoice -eq "y") {
        $EnableSSL = $true
    }
}

$GenerateSSL = $false
$MachineIPs = @()

if ($EnableSSL) {
    Write-Host "[OK] SSL/TLS will be enabled" -ForegroundColor Green

    if (-not $PSBoundParameters.ContainsKey('HttpsPort') -and -not $Force) {
        $HttpsPortChoice = Read-Host "Grafana HTTPS port (default: 3443)"
        if ($HttpsPortChoice) {
            $HttpsPort = $HttpsPortChoice
        }
    }
    Write-Host "Grafana HTTPS will be accessible on port: $HttpsPort" -ForegroundColor White

    if (-not $Force) {
        Write-Host ""
        Write-Host "Certificate Options:" -ForegroundColor White
        Write-Host "1. Generate self-signed certificates (for development/testing)" -ForegroundColor Gray
        Write-Host "2. Use CA-provided certificates (install later)" -ForegroundColor Gray
        $CertChoice = Read-Host "Select certificate type (1 or 2, default: 1)"

        if ($CertChoice -eq "2") {
            Write-Host "CA-provided certificates selected" -ForegroundColor Green
            Write-Host "You can install them after setup using: .\management\manage-ssl.ps1 install-ca" -ForegroundColor Cyan
        } else {
            $GenerateSSL = $true
            Write-Host "Self-signed certificates selected" -ForegroundColor Green

            if (-not $PSBoundParameters.ContainsKey('Domain')) {
                $DomainChoice = Read-Host "Enter domain name for SSL certificate (default: localhost)"
                if ($DomainChoice) {
                    $Domain = $DomainChoice
                }
            }
            Write-Host "SSL certificates will be generated for domain: $Domain" -ForegroundColor White

            # Detect machine IP addresses
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
                        }
                    }
                }
            } catch {
                Write-Host "Could not detect IP addresses" -ForegroundColor Gray
            }
        }
    } else {
        $GenerateSSL = $true
    }
} else {
    Write-Host "SSL/TLS will be disabled (HTTP only)" -ForegroundColor Gray

    # Detect IPs for display
    if (-not $Force) {
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
                        Write-Host "  * $($IP.IPAddress) - $($adapter.InterfaceDescription)" -ForegroundColor White
                        $MachineIPs += $IP.IPAddress
                    }
                }
            }
        } catch {
            Write-Host "Could not detect IP addresses" -ForegroundColor Gray
        }
    }
}

Write-Host ""

# Create .env file from template
Write-Host "Creating configuration files..." -ForegroundColor White

if (-not (Test-Path ".env.template")) {
    Write-Host "[ERROR] .env.template not found!" -ForegroundColor Red
    Write-Host "Please ensure you're running this script from the otel-lgtm directory" -ForegroundColor Yellow
    exit 1
}

Copy-Item ".env.template" ".env" -Force
Write-Host "[OK] Created .env file from template" -ForegroundColor Green

$envContent = Get-Content ".env"
$envContent = $envContent -replace "GRAFANA_PORT=.*", "GRAFANA_PORT=$Port"
$envContent = $envContent -replace "GRAFANA_HTTPS_PORT=.*", "GRAFANA_HTTPS_PORT=$HttpsPort"
$envContent = $envContent -replace "OTEL_LGTM_ENABLE_SSL=.*", "OTEL_LGTM_ENABLE_SSL=$($EnableSSL.ToString().ToLower())"
$envContent = $envContent -replace "OTEL_LGTM_DOMAIN=.*", "OTEL_LGTM_DOMAIN=$Domain"
$envContent = $envContent -replace "GRAFANA_ADMIN_PASSWORD=.*", "GRAFANA_ADMIN_PASSWORD=$Password"

# Try to read credentials from other service .env files
if (Test-Path "..\timescaledb\.env") {
    $tsEnv = Get-Content "..\timescaledb\.env"
    $tsDb = ($tsEnv | Where-Object { $_ -match "^POSTGRES_DB=" }) -replace "POSTGRES_DB=", ""
    $tsUser = ($tsEnv | Where-Object { $_ -match "^POSTGRES_USER=" }) -replace "POSTGRES_USER=", ""
    $tsPass = ($tsEnv | Where-Object { $_ -match "^POSTGRES_PASSWORD=" }) -replace "POSTGRES_PASSWORD=", ""
    if ($tsDb) { $envContent = $envContent -replace "TIMESCALEDB_DB=.*", "TIMESCALEDB_DB=$tsDb" }
    if ($tsUser) { $envContent = $envContent -replace "TIMESCALEDB_USER=.*", "TIMESCALEDB_USER=$tsUser" }
    if ($tsPass) { $envContent = $envContent -replace "TIMESCALEDB_PASSWORD=.*", "TIMESCALEDB_PASSWORD=$tsPass" }
    Write-Host "[OK] Auto-configured TimescaleDB connection from existing .env" -ForegroundColor Green
}

if (Test-Path "..\mqtt\.env") {
    $mqttEnv = Get-Content "..\mqtt\.env"
    $mqttUser = ($mqttEnv | Where-Object { $_ -match "^MQTT_USERNAME=" }) -replace "MQTT_USERNAME=", ""
    $mqttPass = ($mqttEnv | Where-Object { $_ -match "^MQTT_PASSWORD=" }) -replace "MQTT_PASSWORD=", ""
    if ($mqttUser) { $envContent = $envContent -replace "MQTT_USER=.*", "MQTT_USER=$mqttUser" }
    if ($mqttPass) { $envContent = $envContent -replace "MQTT_PASSWORD=.*", "MQTT_PASSWORD=$mqttPass" }
    Write-Host "[OK] Auto-configured MQTT connection from existing .env" -ForegroundColor Green
}

if ($EnableSSL) {
    $envContent += "`nCOMPOSE_PROFILES=ssl"
}

$envContent | Set-Content ".env"
Write-Host "[OK] Updated .env with configuration" -ForegroundColor Green

Write-Host ""

# Generate SSL certificates if requested
if ($GenerateSSL) {
    Write-Host "Generating SSL certificates..." -ForegroundColor White

    try {
        Write-Host "  Generating CA certificate..." -ForegroundColor Gray
        docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl genrsa -out ca.key 4096 2>$null
        docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl req -new -x509 -days 365 -key ca.key -out ca.crt -subj "/C=US/ST=State/L=City/O=OTEL-LGTM/CN=OTEL-LGTM-CA" 2>$null

        Write-Host "  Generating server certificate..." -ForegroundColor Gray
        docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl genrsa -out server.key 4096 2>$null

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

        docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl req -new -key server.key -out server.csr -subj "/C=US/ST=State/L=City/O=OTEL-LGTM/CN=$Domain" -config openssl.cnf 2>$null
        docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 365 -extensions v3_req -extfile openssl.cnf 2>$null

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

# Start Docker containers
Write-Host "Starting LGTM stack..." -ForegroundColor White
Write-Host "This may take a minute on first run (pulling images)..." -ForegroundColor Gray

try {
    docker-compose up -d

    Write-Host "Waiting for Grafana to become healthy..." -ForegroundColor Gray
    $maxWait = 90
    $waited = 0
    $healthy = $false

    while ($waited -lt $maxWait) {
        Start-Sleep -Seconds 2
        $waited += 2

        try {
            $response = Invoke-WebRequest -Uri "http://localhost:$Port/api/health" -TimeoutSec 2 -UseBasicParsing -ErrorAction SilentlyContinue
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
        Write-Host "[OK] LGTM stack is running and healthy" -ForegroundColor Green

        if ($EnableSSL) {
            Write-Host "Starting grafana-nginx-ssl service..." -ForegroundColor Gray
            docker-compose up -d grafana-nginx-ssl 2>&1 | Out-Null
            Start-Sleep -Seconds 3
            Write-Host "[OK] grafana-nginx-ssl service started" -ForegroundColor Green
        }
    } else {
        Write-Host "LGTM stack started but health check timed out" -ForegroundColor Yellow
        Write-Host "  Check logs with: docker-compose logs otel-lgtm" -ForegroundColor Gray
    }
} catch {
    Write-Host "[ERROR] Failed to start LGTM stack: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Check logs with: docker-compose logs otel-lgtm" -ForegroundColor Yellow
    exit 1
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
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "Installation Complete!" -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

# Display connection information
Write-Host "Connection Information:" -ForegroundColor Cyan
Write-Host "  Grafana UI:   http://localhost:$Port" -ForegroundColor White
Write-Host "  OTLP gRPC:    localhost:4317" -ForegroundColor White
Write-Host "  OTLP HTTP:    http://localhost:4318" -ForegroundColor White
if ($MachineIPs.Count -gt 0) {
    foreach ($IP in $MachineIPs) {
        Write-Host "                http://${IP}:$Port" -ForegroundColor White
    }
}

if ($EnableSSL) {
    Write-Host "  Grafana HTTPS: https://localhost:$HttpsPort" -ForegroundColor White
    if ($MachineIPs.Count -gt 0) {
        foreach ($IP in $MachineIPs) {
            Write-Host "                 https://${IP}:$HttpsPort" -ForegroundColor White
        }
    }
    Write-Host ""
    Write-Host "  CA Certificate: certs\ca.crt (distribute to clients)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Grafana Credentials:" -ForegroundColor Cyan
Write-Host "  Username: admin" -ForegroundColor White
Write-Host "  Password: $Password" -ForegroundColor White

Write-Host ""
Write-Host "OpenTelemetry SDK Configuration:" -ForegroundColor Cyan
Write-Host "  OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318" -ForegroundColor White
Write-Host "  OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf" -ForegroundColor White

Write-Host ""

# Firewall configuration
Write-Host "Firewall Configuration:" -ForegroundColor Cyan
Write-Host "To allow external access, configure Windows Firewall:" -ForegroundColor White
Write-Host ""
Write-Host "  New-NetFirewallRule -DisplayName 'Grafana HTTP' -Direction Inbound -LocalPort $Port -Protocol TCP -Action Allow" -ForegroundColor Gray
Write-Host "  New-NetFirewallRule -DisplayName 'OTLP gRPC' -Direction Inbound -LocalPort 4317 -Protocol TCP -Action Allow" -ForegroundColor Gray
Write-Host "  New-NetFirewallRule -DisplayName 'OTLP HTTP' -Direction Inbound -LocalPort 4318 -Protocol TCP -Action Allow" -ForegroundColor Gray
if ($EnableSSL) {
    Write-Host "  New-NetFirewallRule -DisplayName 'Grafana HTTPS' -Direction Inbound -LocalPort $HttpsPort -Protocol TCP -Action Allow" -ForegroundColor Gray
}
Write-Host ""

# Management commands
Write-Host "Management Commands:" -ForegroundColor Cyan
Write-Host "  Logs:    docker-compose logs -f otel-lgtm" -ForegroundColor Gray
if ($EnableSSL) {
    Write-Host "  SSL:     .\management\manage-ssl.ps1 status" -ForegroundColor Gray
}
Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
