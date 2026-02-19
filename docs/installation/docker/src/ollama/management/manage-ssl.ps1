# =================================================================
# Ollama SSL Certificate Management Script for Windows
# Description: Generate and manage SSL/TLS certificates for Nginx reverse proxy
# Version: 1.0.0
# =================================================================

param(
    [ValidateSet("generate", "enable", "disable", "status", "renew", "install-ca")]
    [string]$Action = "",
    
    [string]$Domain = "localhost",
    [int]$ValidDays = 365,
    [string]$CACertPath = "",
    [string]$CAKeyPath = "",
    [string]$ServerCertPath = "",
    [string]$ServerKeyPath = "",
    [string[]]$IPAddresses = @(),
    [switch]$Force = $false
)

# Ensure we're in the ollama directory (not management subdirectory)
$CurrentLocation = Get-Location
if ($CurrentLocation.Path.EndsWith("management")) {
    Set-Location ..
}

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "Ollama SSL Certificate Management" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

# Show help if no action provided
if (-not $Action) {
    Write-Host "Usage: .\manage-ssl.ps1 <action> [options]" -ForegroundColor White
    Write-Host ""
    Write-Host "Actions:" -ForegroundColor Cyan
    Write-Host "  generate      Generate new self-signed SSL certificates" -ForegroundColor White
    Write-Host "  install-ca    Install CA-provided SSL certificates" -ForegroundColor White
    Write-Host "  enable        Enable SSL (start nginx-ssl service)" -ForegroundColor White
    Write-Host "  disable       Disable SSL (stop nginx-ssl service)" -ForegroundColor White
    Write-Host "  status        Show SSL certificate status" -ForegroundColor White
    Write-Host "  renew         Renew existing SSL certificates" -ForegroundColor White
    Write-Host ""
    Write-Host "Parameters:" -ForegroundColor Cyan
    Write-Host "  -Domain         Certificate domain name (default: localhost)" -ForegroundColor White
    Write-Host "  -ValidDays      Certificate validity in days (default: 365)" -ForegroundColor White
    Write-Host "  -CACertPath     Path to CA certificate file (for install-ca)" -ForegroundColor White
    Write-Host "  -CAKeyPath      Path to CA private key file (for install-ca)" -ForegroundColor White
    Write-Host "  -ServerCertPath Path to server certificate file (for install-ca)" -ForegroundColor White
    Write-Host "  -ServerKeyPath  Path to server private key file (for install-ca)" -ForegroundColor White
    Write-Host "  -IPAddresses    Additional IP addresses for SAN (comma-separated)" -ForegroundColor White
    Write-Host "  -Force          Overwrite existing certificates without prompting" -ForegroundColor White
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Cyan
    Write-Host "  # Generate self-signed certificates" -ForegroundColor Gray
    Write-Host "  .\manage-ssl.ps1 generate" -ForegroundColor Gray
    Write-Host "  .\manage-ssl.ps1 generate -Domain 'ollama.company.com' -ValidDays 730" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  # Install CA-provided certificates" -ForegroundColor Gray
    Write-Host "  .\manage-ssl.ps1 install-ca -ServerCertPath 'C:\certs\server.crt' -ServerKeyPath 'C:\certs\server.key'" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  # Management commands" -ForegroundColor Gray
    Write-Host "  .\manage-ssl.ps1 enable" -ForegroundColor Gray
    Write-Host "  .\manage-ssl.ps1 status" -ForegroundColor Gray
    Write-Host "  .\manage-ssl.ps1 renew -Force" -ForegroundColor Gray
    Write-Host ""
    Write-Host "==================================================================" -ForegroundColor Cyan
    exit 0
}

# Check if Docker is available
function Test-Docker {
    try {
        docker version | Out-Null
        return $true
    } catch {
        Write-Host "✗ Docker is not available!" -ForegroundColor Red
        Write-Host "Please ensure Docker Desktop is running." -ForegroundColor Yellow
        return $false
    }
}

# Function to get machine IP addresses
function Get-MachineIPs {
    $IPs = @()
    try {
        $AllIPs = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { 
            $_.IPAddress -notmatch '^127\.' -and 
            ($_.PrefixOrigin -eq 'Dhcp' -or $_.PrefixOrigin -eq 'Manual') 
        }
        foreach ($IP in $AllIPs) {
            $IPs += $IP.IPAddress
        }
    } catch {
        # Could not detect IPs
    }
    return $IPs
}

# Function to generate SSL certificates
function Generate-SSLCertificates {
    param(
        [string]$Domain,
        [int]$ValidDays,
        [string[]]$AdditionalIPs
    )
    
    Write-Host "Generating SSL certificates for domain: $Domain" -ForegroundColor White
    Write-Host "Certificate validity: $ValidDays days" -ForegroundColor Gray
    Write-Host ""
    
    # Create certs directory if it doesn't exist
    if (-not (Test-Path "certs")) {
        New-Item -ItemType Directory -Force -Path "certs" | Out-Null
        Write-Host "✓ Created certs directory" -ForegroundColor Green
    }
    
    # Check if certificates already exist
    if ((Test-Path "certs\server.crt") -and -not $Force) {
        Write-Host "⚠ Certificates already exist!" -ForegroundColor Yellow
        $Overwrite = Read-Host "Overwrite existing certificates? (y/n)"
        if ($Overwrite -ne "Y" -and $Overwrite -ne "y") {
            Write-Host "Certificate generation cancelled" -ForegroundColor Yellow
            return $false
        }
    }
    
    try {
        # Detect machine IPs
        Write-Host "Detecting machine IP addresses..." -ForegroundColor Gray
        $MachineIPs = Get-MachineIPs
        
        if ($MachineIPs.Count -gt 0) {
            Write-Host "Detected IPs:" -ForegroundColor Gray
            foreach ($IP in $MachineIPs) {
                Write-Host "  • $IP" -ForegroundColor Gray
            }
        }
        
        # Combine with additional IPs
        $AllIPs = $MachineIPs + $AdditionalIPs | Select-Object -Unique
        
        # Generate CA private key
        Write-Host ""
        Write-Host "Generating CA certificate..." -ForegroundColor Gray
        docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl genrsa -out ca.key 4096 2>$null
        
        # Generate CA certificate
        docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl req -new -x509 -days $ValidDays -key ca.key -out ca.crt -subj "/C=US/ST=State/L=City/O=Ollama/CN=Ollama-CA" 2>$null
        
        # Generate server private key
        Write-Host "Generating server certificate..." -ForegroundColor Gray
        docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl genrsa -out server.key 4096 2>$null
        
        # Create OpenSSL config with SAN
        $SANEntries = @("DNS:localhost", "DNS:$Domain", "IP:127.0.0.1")
        foreach ($IP in $AllIPs) {
            $SANEntries += "IP:$IP"
        }
        $SANString = $SANEntries -join ","
        
        Write-Host "Subject Alternative Names: $SANString" -ForegroundColor Gray
        
        $opensslConfig = @"
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req

[req_distinguished_name]

[v3_req]
subjectAltName = $SANString
"@
        $opensslConfig | Out-File -FilePath "certs\openssl.cnf" -Encoding ASCII
        
        # Generate CSR
        docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl req -new -key server.key -out server.csr -subj "/C=US/ST=State/L=City/O=Ollama/CN=$Domain" -config openssl.cnf 2>$null
        
        # Sign certificate
        docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days $ValidDays -extensions v3_req -extfile openssl.cnf 2>$null
        
        # Cleanup temporary files
        Remove-Item "certs\server.csr" -ErrorAction SilentlyContinue
        Remove-Item "certs\ca.srl" -ErrorAction SilentlyContinue
        Remove-Item "certs\openssl.cnf" -ErrorAction SilentlyContinue
        
        # Verify certificates were created
        if ((Test-Path "certs\server.crt") -and (Test-Path "certs\server.key") -and (Test-Path "certs\ca.crt")) {
            Write-Host ""
            Write-Host "✓ SSL certificates generated successfully!" -ForegroundColor Green
            Write-Host ""
            Write-Host "Certificate Details:" -ForegroundColor Cyan
            Write-Host "  Domain: $Domain" -ForegroundColor White
            Write-Host "  Valid for: $ValidDays days" -ForegroundColor White
            Write-Host "  Subject Alternative Names:" -ForegroundColor White
            foreach ($Entry in $SANEntries) {
                Write-Host "    • $Entry" -ForegroundColor Gray
            }
            Write-Host ""
            Write-Host "Files created:" -ForegroundColor Cyan
            Write-Host "  • certs\ca.crt (CA Certificate - distribute to clients)" -ForegroundColor White
            Write-Host "  • certs\ca.key (CA Private Key - keep secure!)" -ForegroundColor White
            Write-Host "  • certs\server.crt (Server Certificate)" -ForegroundColor White
            Write-Host "  • certs\server.key (Server Private Key)" -ForegroundColor White
            Write-Host ""
            Write-Host "Next steps:" -ForegroundColor Cyan
            Write-Host "  1. Enable SSL: .\management\manage-ssl.ps1 enable" -ForegroundColor Gray
            Write-Host "  2. Distribute ca.crt to client machines" -ForegroundColor Gray
            Write-Host ""
            return $true
        } else {
            Write-Host "✗ Certificate files not created properly" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "✗ SSL certificate generation failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to install CA-provided certificates
function Install-CACertificates {
    param(
        [string]$CACertPath,
        [string]$CAKeyPath,
        [string]$ServerCertPath,
        [string]$ServerKeyPath
    )
    
    Write-Host "Installing CA-provided SSL certificates..." -ForegroundColor White
    Write-Host ""
    
    # Create certs directory if it doesn't exist
    if (-not (Test-Path "certs")) {
        New-Item -ItemType Directory -Force -Path "certs" | Out-Null
        Write-Host "✓ Created certs directory" -ForegroundColor Green
    }
    
    try {
        # Validate required certificate files exist
        if (-not $ServerCertPath -or -not (Test-Path $ServerCertPath)) {
            throw "Server certificate file not found or not specified: $ServerCertPath"
        }
        if (-not $ServerKeyPath -or -not (Test-Path $ServerKeyPath)) {
            throw "Server private key file not found or not specified: $ServerKeyPath"
        }
        
        # Copy server certificates
        Copy-Item -Path $ServerCertPath -Destination "certs\server.crt" -Force
        Copy-Item -Path $ServerKeyPath -Destination "certs\server.key" -Force
        Write-Host "✓ Server certificates installed" -ForegroundColor Green
        
        # Copy CA certificate if provided
        if ($CACertPath -and (Test-Path $CACertPath)) {
            Copy-Item -Path $CACertPath -Destination "certs\ca.crt" -Force
            Write-Host "✓ CA certificate installed" -ForegroundColor Green
        }
        
        # Copy CA private key if provided
        if ($CAKeyPath -and (Test-Path $CAKeyPath)) {
            Copy-Item -Path $CAKeyPath -Destination "certs\ca.key" -Force
            Write-Host "✓ CA private key installed" -ForegroundColor Green
        }
        
        # Validate certificates using Docker OpenSSL
        Write-Host ""
        Write-Host "Validating certificates..." -ForegroundColor Gray
        
        $CertModulus = docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl x509 -noout -modulus -in server.crt 2>$null | docker run --rm -i alpine/openssl md5
        $KeyModulus = docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl rsa -noout -modulus -in server.key 2>$null | docker run --rm -i alpine/openssl md5
        
        if ($CertModulus -eq $KeyModulus) {
            Write-Host "✓ Certificate and key match" -ForegroundColor Green
        } else {
            Write-Host "⚠ Warning: Certificate and key may not match" -ForegroundColor Yellow
        }
        
        # Check certificate expiration
        $CertInfo = docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl x509 -noout -dates -in server.crt 2>$null
        Write-Host "Certificate validity:" -ForegroundColor Gray
        Write-Host $CertInfo -ForegroundColor Gray
        
        Write-Host ""
        Write-Host "✓ CA-provided certificates installed successfully!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor Cyan
        Write-Host "  1. Enable SSL: .\management\manage-ssl.ps1 enable" -ForegroundColor Gray
        Write-Host ""
        
        return $true
    } catch {
        Write-Host "✗ Certificate installation failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to enable SSL
function Enable-SSL {
    Write-Host "Enabling SSL/TLS for Ollama..." -ForegroundColor White
    Write-Host ""
    
    # Check if certificates exist
    if (-not (Test-Path "certs\server.crt") -or -not (Test-Path "certs\server.key")) {
        Write-Host "✗ SSL certificates not found!" -ForegroundColor Red
        Write-Host "Generate certificates first:" -ForegroundColor Yellow
        Write-Host "  .\management\manage-ssl.ps1 generate" -ForegroundColor Gray
        Write-Host "Or install CA-provided certificates:" -ForegroundColor Yellow
        Write-Host "  .\management\manage-ssl.ps1 install-ca -ServerCertPath <path> -ServerKeyPath <path>" -ForegroundColor Gray
        return $false
    }
    
    # Update .env file to enable SSL profile
    if (Test-Path ".env") {
        $envContent = Get-Content ".env"
        
        # Check if COMPOSE_PROFILES already exists
        if ($envContent -match "COMPOSE_PROFILES=") {
            $envContent = $envContent -replace "COMPOSE_PROFILES=.*", "COMPOSE_PROFILES=ssl"
        } else {
            $envContent += "`nCOMPOSE_PROFILES=ssl"
        }
        
        # Update SSL enabled flag
        $envContent = $envContent -replace "OLLAMA_ENABLE_SSL=.*", "OLLAMA_ENABLE_SSL=true"
        
        $envContent | Set-Content ".env"
        Write-Host "✓ Updated .env configuration" -ForegroundColor Green
    }
    
    # Start nginx-ssl service
    Write-Host "Starting nginx-ssl service..." -ForegroundColor Gray
    docker-compose up -d nginx-ssl 2>&1 | Out-Null
    
    Start-Sleep -Seconds 3
    
    # Check if nginx-ssl is running
    $Containers = docker-compose ps --format json 2>$null | ConvertFrom-Json
    $NginxContainer = $Containers | Where-Object { $_.Service -eq "nginx-ssl" }
    
    if ($NginxContainer -and $NginxContainer.State -eq "running") {
        Write-Host "✓ nginx-ssl service is running" -ForegroundColor Green
        
        # Get HTTPS port from .env
        $HttpsPort = "11443"
        if (Test-Path ".env") {
            $envContent = Get-Content ".env"
            $portLine = $envContent | Where-Object { $_ -match "OLLAMA_HTTPS_PORT=" }
            if ($portLine) {
                $HttpsPort = $portLine -replace "OLLAMA_HTTPS_PORT=", ""
            }
        }
        
        Write-Host ""
        Write-Host "✓ SSL/TLS enabled successfully!" -ForegroundColor Green
        Write-Host ""
        Write-Host "HTTPS Endpoint:" -ForegroundColor Cyan
        Write-Host "  https://localhost:$HttpsPort" -ForegroundColor White
        
        $MachineIPs = Get-MachineIPs
        foreach ($IP in $MachineIPs) {
            Write-Host "  https://${IP}:$HttpsPort" -ForegroundColor White
        }
        
        Write-Host ""
        Write-Host "Test command:" -ForegroundColor Cyan
        Write-Host "  curl -k https://localhost:$HttpsPort/api/version" -ForegroundColor Gray
        Write-Host ""
        Write-Host "CA Certificate for clients:" -ForegroundColor Cyan
        Write-Host "  certs\ca.crt" -ForegroundColor White
        Write-Host ""
        
        return $true
    } else {
        Write-Host "✗ Failed to start nginx-ssl service" -ForegroundColor Red
        Write-Host "Check logs: docker-compose logs nginx-ssl" -ForegroundColor Yellow
        return $false
    }
}

# Function to disable SSL
function Disable-SSL {
    Write-Host "Disabling SSL/TLS for Ollama..." -ForegroundColor White
    Write-Host ""
    
    # Stop nginx-ssl service
    Write-Host "Stopping nginx-ssl service..." -ForegroundColor Gray
    docker-compose stop nginx-ssl 2>&1 | Out-Null
    
    # Update .env file
    if (Test-Path ".env") {
        $envContent = Get-Content ".env"
        $envContent = $envContent -replace "COMPOSE_PROFILES=ssl", "# COMPOSE_PROFILES=ssl"
        $envContent = $envContent -replace "OLLAMA_ENABLE_SSL=true", "OLLAMA_ENABLE_SSL=false"
        $envContent | Set-Content ".env"
        Write-Host "✓ Updated .env configuration" -ForegroundColor Green
    }
    
    Write-Host "✓ SSL/TLS disabled" -ForegroundColor Green
    Write-Host ""
    Write-Host "Ollama is now accessible via HTTP only" -ForegroundColor White
    Write-Host ""
}

# Function to show SSL status
function Show-SSLStatus {
    Write-Host "SSL/TLS Status" -ForegroundColor Cyan
    Write-Host "==============" -ForegroundColor Cyan
    Write-Host ""
    
    # Check service status
    Write-Host "Service Status:" -ForegroundColor Cyan
    $Containers = docker-compose ps --format json 2>$null | ConvertFrom-Json
    $OllamaContainer = $Containers | Where-Object { $_.Service -eq "ollama" }
    $NginxContainer = $Containers | Where-Object { $_.Service -eq "nginx-ssl" }
    
    if ($OllamaContainer) {
        $status = if ($OllamaContainer.State -eq "running") { "✓ Running" } else { "✗ Stopped" }
        $color = if ($OllamaContainer.State -eq "running") { "Green" } else { "Red" }
        Write-Host "  Ollama: $status" -ForegroundColor $color
    }
    
    if ($NginxContainer) {
        $status = if ($NginxContainer.State -eq "running") { "✓ Running" } else { "✗ Stopped" }
        $color = if ($NginxContainer.State -eq "running") { "Green" } else { "Red" }
        Write-Host "  nginx-ssl: $status" -ForegroundColor $color
    } else {
        Write-Host "  nginx-ssl: Not configured" -ForegroundColor Gray
    }
    
    Write-Host ""
    
    # Check certificate files
    Write-Host "Certificate Files:" -ForegroundColor Cyan
    $certFiles = @("certs\ca.crt", "certs\server.crt", "certs\server.key")
    foreach ($file in $certFiles) {
        if (Test-Path $file) {
            Write-Host "  ✓ $file" -ForegroundColor Green
        } else {
            Write-Host "  ✗ $file (not found)" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    
    # Show certificate details if they exist
    if (Test-Path "certs\server.crt") {
        Write-Host "Server Certificate Details:" -ForegroundColor Cyan
        $CertInfo = docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl x509 -noout -subject -issuer -dates -in server.crt 2>$null
        Write-Host $CertInfo -ForegroundColor Gray
        
        Write-Host ""
        Write-Host "Subject Alternative Names:" -ForegroundColor Cyan
        $SANInfo = docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl x509 -noout -text -in server.crt 2>$null | Select-String -Pattern "DNS:|IP Address:"
        if ($SANInfo) {
            Write-Host $SANInfo -ForegroundColor Gray
        } else {
            Write-Host "  No SAN entries found" -ForegroundColor Gray
        }
    }
    
    Write-Host ""
    
    # Show endpoints
    Write-Host "API Endpoints:" -ForegroundColor Cyan
    $HttpPort = "11434"
    $HttpsPort = "11443"
    
    if (Test-Path ".env") {
        $envContent = Get-Content ".env"
        $httpPortLine = $envContent | Where-Object { $_ -match "OLLAMA_PORT=" }
        if ($httpPortLine) {
            $HttpPort = $httpPortLine -replace "OLLAMA_PORT=", ""
        }
        $httpsPortLine = $envContent | Where-Object { $_ -match "OLLAMA_HTTPS_PORT=" }
        if ($httpsPortLine) {
            $HttpsPort = $httpsPortLine -replace "OLLAMA_HTTPS_PORT=", ""
        }
    }
    
    Write-Host "  HTTP:  http://localhost:$HttpPort" -ForegroundColor White
    if ($NginxContainer -and $NginxContainer.State -eq "running") {
        Write-Host "  HTTPS: https://localhost:$HttpsPort" -ForegroundColor White
    } else {
        Write-Host "  HTTPS: Not enabled" -ForegroundColor Gray
    }
    
    Write-Host ""
}

# Function to renew certificates
function Renew-Certificates {
    Write-Host "Renewing SSL certificates..." -ForegroundColor White
    Write-Host ""
    
    if (-not (Test-Path "certs\server.crt")) {
        Write-Host "✗ No existing certificates found to renew" -ForegroundColor Red
        return $false
    }
    
    # Backup existing certificates
    $BackupDir = "certs\backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
    
    Copy-Item "certs\*.crt" $BackupDir -ErrorAction SilentlyContinue
    Copy-Item "certs\*.key" $BackupDir -ErrorAction SilentlyContinue
    
    Write-Host "✓ Backed up existing certificates to: $BackupDir" -ForegroundColor Green
    Write-Host ""
    
    # Get domain from existing certificate
    $CertSubject = docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl x509 -noout -subject -in server.crt 2>$null
    if ($CertSubject -match "CN\s*=\s*([^,]+)") {
        $Domain = $Matches[1].Trim()
    }
    
    # Generate new certificates
    $Success = Generate-SSLCertificates -Domain $Domain -ValidDays $ValidDays -AdditionalIPs $IPAddresses
    
    if ($Success) {
        # Restart nginx-ssl if it's running
        $Containers = docker-compose ps --format json 2>$null | ConvertFrom-Json
        $NginxContainer = $Containers | Where-Object { $_.Service -eq "nginx-ssl" }
        
        if ($NginxContainer -and $NginxContainer.State -eq "running") {
            Write-Host "Restarting nginx-ssl service..." -ForegroundColor Gray
            docker-compose restart nginx-ssl 2>&1 | Out-Null
            Write-Host "✓ nginx-ssl service restarted" -ForegroundColor Green
        }
        
        Write-Host ""
        Write-Host "✓ Certificates renewed successfully!" -ForegroundColor Green
        Write-Host ""
    }
    
    return $Success
}

# Main script logic
if (-not (Test-Docker)) {
    exit 1
}

switch ($Action) {
    "generate" {
        $Success = Generate-SSLCertificates -Domain $Domain -ValidDays $ValidDays -AdditionalIPs $IPAddresses
        if (-not $Success) { exit 1 }
    }
    
    "install-ca" {
        $Success = Install-CACertificates -CACertPath $CACertPath -CAKeyPath $CAKeyPath -ServerCertPath $ServerCertPath -ServerKeyPath $ServerKeyPath
        if (-not $Success) { exit 1 }
    }
    
    "enable" {
        $Success = Enable-SSL
        if (-not $Success) { exit 1 }
    }
    
    "disable" {
        Disable-SSL
    }
    
    "status" {
        Show-SSLStatus
    }
    
    "renew" {
        $Success = Renew-Certificates
        if (-not $Success) { exit 1 }
    }
    
    default {
        Write-Host "Unknown action: $Action" -ForegroundColor Red
        exit 1
    }
}

Write-Host "==================================================================" -ForegroundColor Cyan
