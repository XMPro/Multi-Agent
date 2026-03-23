# =================================================================
# OTEL LGTM SSL Certificate Management Script for Windows
# Description: Generate and manage SSL/TLS certificates for Grafana Nginx reverse proxy
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

# Ensure we're in the otel-lgtm directory (not management subdirectory)
$CurrentLocation = Get-Location
if ($CurrentLocation.Path.EndsWith("management")) {
    Set-Location ..
}

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "OTEL LGTM SSL Certificate Management" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

# Show help if no action provided
if (-not $Action) {
    Write-Host "Usage: .\manage-ssl.ps1 <action> [options]" -ForegroundColor White
    Write-Host ""
    Write-Host "Actions:" -ForegroundColor Cyan
    Write-Host "  generate      Generate new self-signed SSL certificates" -ForegroundColor White
    Write-Host "  install-ca    Install CA-provided SSL certificates" -ForegroundColor White
    Write-Host "  enable        Enable SSL (start grafana-nginx-ssl service)" -ForegroundColor White
    Write-Host "  disable       Disable SSL (stop grafana-nginx-ssl service)" -ForegroundColor White
    Write-Host "  status        Show SSL certificate status" -ForegroundColor White
    Write-Host "  renew         Renew existing SSL certificates" -ForegroundColor White
    Write-Host ""
    Write-Host "Parameters:" -ForegroundColor Cyan
    Write-Host "  -Domain         Certificate domain name (default: localhost)" -ForegroundColor White
    Write-Host "  -ValidDays      Certificate validity in days (default: 365)" -ForegroundColor White
    Write-Host "  -CACertPath     Path to CA certificate file" -ForegroundColor White
    Write-Host "  -CAKeyPath      Path to CA private key file" -ForegroundColor White
    Write-Host "  -ServerCertPath Path to server certificate file" -ForegroundColor White
    Write-Host "  -ServerKeyPath  Path to server private key file" -ForegroundColor White
    Write-Host "  -Force          Overwrite existing certificates without prompting" -ForegroundColor White
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Cyan
    Write-Host "  .\manage-ssl.ps1 generate" -ForegroundColor Gray
    Write-Host "  .\manage-ssl.ps1 generate -Domain 'grafana.company.com' -ValidDays 730" -ForegroundColor Gray
    Write-Host "  .\manage-ssl.ps1 install-ca -ServerCertPath 'C:\certs\server.crt' -ServerKeyPath 'C:\certs\server.key'" -ForegroundColor Gray
    Write-Host "  .\manage-ssl.ps1 enable" -ForegroundColor Gray
    Write-Host "  .\manage-ssl.ps1 status" -ForegroundColor Gray
    Write-Host ""
    Write-Host "==================================================================" -ForegroundColor Cyan
    exit 0
}

function Test-Docker {
    try {
        docker version | Out-Null
        return $true
    } catch {
        Write-Host "Docker is not available!" -ForegroundColor Red
        return $false
    }
}

function Get-MachineIPs {
    $IPs = @()
    try {
        $AllIPs = Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
            $_.IPAddress -notmatch '^127\.' -and
            ($_.PrefixOrigin -eq 'Dhcp' -or $_.PrefixOrigin -eq 'Manual')
        }
        foreach ($IP in $AllIPs) { $IPs += $IP.IPAddress }
    } catch { }
    return $IPs
}

function Generate-SSLCertificates {
    param([string]$Domain, [int]$ValidDays, [string[]]$AdditionalIPs)

    Write-Host "Generating SSL certificates for domain: $Domain" -ForegroundColor White

    if (-not (Test-Path "certs")) {
        New-Item -ItemType Directory -Force -Path "certs" | Out-Null
    }

    if ((Test-Path "certs\server.crt") -and -not $Force) {
        $Overwrite = Read-Host "Overwrite existing certificates? (y/n)"
        if ($Overwrite -ne "Y" -and $Overwrite -ne "y") { return $false }
    }

    try {
        $MachineIPs = Get-MachineIPs
        $AllIPs = $MachineIPs + $AdditionalIPs | Select-Object -Unique

        docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl genrsa -out ca.key 4096 2>$null
        docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl req -new -x509 -days $ValidDays -key ca.key -out ca.crt -subj "/C=US/ST=State/L=City/O=OTEL-LGTM/CN=OTEL-LGTM-CA" 2>$null
        docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl genrsa -out server.key 4096 2>$null

        $SANEntries = @("DNS:localhost", "DNS:$Domain", "IP:127.0.0.1")
        foreach ($IP in $AllIPs) { $SANEntries += "IP:$IP" }
        $SANString = $SANEntries -join ","

        @"
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req

[req_distinguished_name]

[v3_req]
subjectAltName = $SANString
"@ | Out-File -FilePath "certs\openssl.cnf" -Encoding ASCII

        docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl req -new -key server.key -out server.csr -subj "/C=US/ST=State/L=City/O=OTEL-LGTM/CN=$Domain" -config openssl.cnf 2>$null
        docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days $ValidDays -extensions v3_req -extfile openssl.cnf 2>$null

        Remove-Item "certs\server.csr", "certs\ca.srl", "certs\openssl.cnf" -ErrorAction SilentlyContinue

        if ((Test-Path "certs\server.crt") -and (Test-Path "certs\server.key")) {
            Write-Host "SSL certificates generated successfully!" -ForegroundColor Green
            return $true
        }
        Write-Host "Certificate generation failed" -ForegroundColor Red
        return $false
    } catch {
        Write-Host "SSL generation failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

if (-not (Test-Docker)) { exit 1 }

switch ($Action) {
    "generate" {
        if (-not (Generate-SSLCertificates -Domain $Domain -ValidDays $ValidDays -AdditionalIPs $IPAddresses)) { exit 1 }
    }
    "install-ca" {
        if (-not (Test-Path "certs")) { New-Item -ItemType Directory -Force -Path "certs" | Out-Null }
        if (-not $ServerCertPath -or -not (Test-Path $ServerCertPath)) { Write-Host "Server cert not found" -ForegroundColor Red; exit 1 }
        if (-not $ServerKeyPath -or -not (Test-Path $ServerKeyPath)) { Write-Host "Server key not found" -ForegroundColor Red; exit 1 }
        Copy-Item $ServerCertPath "certs\server.crt" -Force
        Copy-Item $ServerKeyPath "certs\server.key" -Force
        if ($CACertPath -and (Test-Path $CACertPath)) { Copy-Item $CACertPath "certs\ca.crt" -Force }
        Write-Host "Certificates installed. Run: .\management\manage-ssl.ps1 enable" -ForegroundColor Green
    }
    "enable" {
        if (-not (Test-Path "certs\server.crt")) { Write-Host "No certificates found" -ForegroundColor Red; exit 1 }
        if (Test-Path ".env") {
            $env = Get-Content ".env"
            if ($env -match "COMPOSE_PROFILES=") { $env = $env -replace "COMPOSE_PROFILES=.*", "COMPOSE_PROFILES=ssl" }
            else { $env += "`nCOMPOSE_PROFILES=ssl" }
            $env = $env -replace "OTEL_LGTM_ENABLE_SSL=.*", "OTEL_LGTM_ENABLE_SSL=true"
            $env | Set-Content ".env"
        }
        docker-compose up -d grafana-nginx-ssl 2>&1 | Out-Null
        Start-Sleep -Seconds 3
        Write-Host "SSL enabled" -ForegroundColor Green
    }
    "disable" {
        docker-compose stop grafana-nginx-ssl 2>&1 | Out-Null
        if (Test-Path ".env") {
            $env = Get-Content ".env"
            $env = $env -replace "COMPOSE_PROFILES=ssl", "# COMPOSE_PROFILES=ssl"
            $env = $env -replace "OTEL_LGTM_ENABLE_SSL=true", "OTEL_LGTM_ENABLE_SSL=false"
            $env | Set-Content ".env"
        }
        Write-Host "SSL disabled" -ForegroundColor Green
    }
    "status" {
        Write-Host "SSL/TLS Status" -ForegroundColor Cyan
        Write-Host ""
        $certFiles = @("certs\ca.crt", "certs\server.crt", "certs\server.key")
        foreach ($f in $certFiles) {
            $status = if (Test-Path $f) { "Found" } else { "Missing" }
            $color = if (Test-Path $f) { "Green" } else { "Red" }
            Write-Host "  $f : $status" -ForegroundColor $color
        }
        if (Test-Path "certs\server.crt") {
            Write-Host ""
            docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl x509 -noout -subject -issuer -dates -in server.crt 2>$null
        }
    }
    "renew" {
        if (-not (Test-Path "certs\server.crt")) { Write-Host "No certificates to renew" -ForegroundColor Red; exit 1 }
        $BackupDir = "certs\backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
        Copy-Item "certs\*.crt" $BackupDir -ErrorAction SilentlyContinue
        Copy-Item "certs\*.key" $BackupDir -ErrorAction SilentlyContinue
        Write-Host "Backed up to: $BackupDir" -ForegroundColor Green
        if (Generate-SSLCertificates -Domain $Domain -ValidDays $ValidDays -AdditionalIPs $IPAddresses) {
            $containers = docker-compose ps --format json 2>$null | ConvertFrom-Json
            $nginx = $containers | Where-Object { $_.Service -eq "grafana-nginx-ssl" -and $_.State -eq "running" }
            if ($nginx) { docker-compose restart grafana-nginx-ssl 2>&1 | Out-Null }
            Write-Host "Certificates renewed!" -ForegroundColor Green
        }
    }
}

Write-Host "==================================================================" -ForegroundColor Cyan
