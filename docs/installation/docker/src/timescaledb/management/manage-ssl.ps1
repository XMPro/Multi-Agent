# =================================================================
# TimescaleDB SSL Management Script (PowerShell)
# Production-Grade SSL/TLS Configuration
# =================================================================

param(
    [switch]$Enable = $false,
    [switch]$Disable = $false,
    [string]$Domain = "localhost",
    [switch]$Force = $false,
    [int]$ValidityDays = 365
)

$ErrorActionPreference = "Stop"

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "TimescaleDB SSL Management" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

if (-not $Enable -and -not $Disable) {
    Write-Host "Error: You must specify either -Enable or -Disable" -ForegroundColor Red
    Write-Host "Usage:" -ForegroundColor White
    Write-Host "  Enable SSL:  .\manage-ssl.ps1 -Enable [-Domain <domain>]" -ForegroundColor Gray
    Write-Host "  Disable SSL: .\manage-ssl.ps1 -Disable" -ForegroundColor Gray
    exit 1
}

# Create certs directory if it doesn't exist
if (-not (Test-Path "certs")) {
    New-Item -ItemType Directory -Force -Path "certs" | Out-Null
}

if ($Enable) {
    Write-Host ""
    Write-Host "Enabling SSL/TLS..." -ForegroundColor White
    Write-Host "Domain: $Domain" -ForegroundColor Gray
    Write-Host "Validity: $ValidityDays days" -ForegroundColor Gray
    
    # Check if certificates already exist
    if ((Test-Path "certs\server.crt") -and -not $Force) {
        Write-Host ""
        Write-Host "SSL certificates already exist!" -ForegroundColor Yellow
        $Recreate = Read-Host "Recreate certificates? (y/n)"
        if ($Recreate -ne "Y" -and $Recreate -ne "y") {
            Write-Host "Using existing certificates" -ForegroundColor Green
            exit 0
        }
    }
    
    Write-Host ""
    Write-Host "Generating SSL certificates..." -ForegroundColor White
    
    # Check if OpenSSL is available
    $opensslPath = Get-Command openssl -ErrorAction SilentlyContinue
    if (-not $opensslPath) {
        Write-Host "Error: OpenSSL is not installed or not in PATH" -ForegroundColor Red
        Write-Host "Please install OpenSSL:" -ForegroundColor Yellow
        Write-Host "  - Download from: https://slproweb.com/products/Win32OpenSSL.html" -ForegroundColor Gray
        Write-Host "  - Or use: choco install openssl" -ForegroundColor Gray
        exit 1
    }
    
    # Generate CA private key
    Write-Host "Generating CA private key..." -ForegroundColor Gray
    & openssl genrsa -out "certs\ca.key" 4096 2>&1 | Out-Null
    
    # Generate CA certificate
    Write-Host "Generating CA certificate..." -ForegroundColor Gray
    & openssl req -new -x509 -days $ValidityDays -key "certs\ca.key" -out "certs\ca.crt" `
        -subj "/C=US/ST=State/L=City/O=Organization/OU=IT/CN=TimescaleDB-CA" 2>&1 | Out-Null
    
    # Generate server private key
    Write-Host "Generating server private key..." -ForegroundColor Gray
    & openssl genrsa -out "certs\server.key" 4096 2>&1 | Out-Null
    
    # Generate server certificate signing request
    Write-Host "Generating server CSR..." -ForegroundColor Gray
    & openssl req -new -key "certs\server.key" -out "certs\server.csr" `
        -subj "/C=US/ST=State/L=City/O=Organization/OU=IT/CN=$Domain" 2>&1 | Out-Null
    
    # Create OpenSSL config for SAN
    $opensslConfig = @"
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = State
L = City
O = Organization
OU = IT
CN = $Domain

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = $Domain
DNS.2 = localhost
IP.1 = 127.0.0.1
"@
    $opensslConfig | Out-File -FilePath "certs\openssl.cnf" -Encoding ASCII
    
    # Sign server certificate with CA
    Write-Host "Signing server certificate..." -ForegroundColor Gray
    & openssl x509 -req -in "certs\server.csr" -CA "certs\ca.crt" -CAkey "certs\ca.key" `
        -CAcreateserial -out "certs\server.crt" -days $ValidityDays `
        -extensions v3_req -extfile "certs\openssl.cnf" 2>&1 | Out-Null
    
    # Set proper permissions on private keys
    $acl = Get-Acl "certs\server.key"
    $acl.SetAccessRuleProtection($true, $false)
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        [System.Security.Principal.WindowsIdentity]::GetCurrent().Name,
        "FullControl",
        "Allow"
    )
    $acl.SetAccessRule($rule)
    Set-Acl "certs\server.key" $acl
    
    # Clean up temporary files
    Remove-Item "certs\server.csr" -Force -ErrorAction SilentlyContinue
    Remove-Item "certs\openssl.cnf" -Force -ErrorAction SilentlyContinue
    Remove-Item "certs\ca.srl" -Force -ErrorAction SilentlyContinue
    
    Write-Host ""
    Write-Host "SSL certificates generated successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Certificate Details:" -ForegroundColor White
    Write-Host "  CA Certificate: certs\ca.crt" -ForegroundColor Gray
    Write-Host "  Server Certificate: certs\server.crt" -ForegroundColor Gray
    Write-Host "  Server Key: certs\server.key" -ForegroundColor Gray
    Write-Host "  Domain: $Domain" -ForegroundColor Gray
    Write-Host "  Valid for: $ValidityDays days" -ForegroundColor Gray
    
    # Update .env file
    if (Test-Path ".env") {
        $envContent = Get-Content ".env" -Raw
        $envContent = $envContent -replace 'ENABLE_SSL=false', 'ENABLE_SSL=true'
        $envContent = $envContent -replace "DOMAIN=.*", "DOMAIN=$Domain"
        $envContent | Out-File -FilePath ".env" -Encoding UTF8 -NoNewline
        Write-Host ""
        Write-Host "Updated .env file with SSL settings" -ForegroundColor Green
    }
    
    # Update postgresql.conf
    if (Test-Path "config\postgresql.conf") {
        $confContent = Get-Content "config\postgresql.conf" -Raw
        $confContent = $confContent -replace 'ssl = off', 'ssl = on'
        $confContent | Out-File -FilePath "config\postgresql.conf" -Encoding UTF8 -NoNewline
        Write-Host "Updated postgresql.conf with SSL settings" -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor White
    Write-Host "  1. Restart the database: docker-compose restart" -ForegroundColor Gray
    Write-Host "  2. Connect with SSL: psql 'postgresql://user:pass@localhost:5432/db?sslmode=require'" -ForegroundColor Gray
    Write-Host "  3. Distribute ca.crt to client machines for trusted connections" -ForegroundColor Gray
    
} elseif ($Disable) {
    Write-Host ""
    Write-Host "Disabling SSL/TLS..." -ForegroundColor White
    
    # Update .env file
    if (Test-Path ".env") {
        $envContent = Get-Content ".env" -Raw
        $envContent = $envContent -replace 'ENABLE_SSL=true', 'ENABLE_SSL=false'
        $envContent | Out-File -FilePath ".env" -Encoding UTF8 -NoNewline
        Write-Host "Updated .env file" -ForegroundColor Green
    }
    
    # Update postgresql.conf
    if (Test-Path "config\postgresql.conf") {
        $confContent = Get-Content "config\postgresql.conf" -Raw
        $confContent = $confContent -replace 'ssl = on', 'ssl = off'
        $confContent | Out-File -FilePath "config\postgresql.conf" -Encoding UTF8 -NoNewline
        Write-Host "Updated postgresql.conf" -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "SSL/TLS disabled successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor White
    Write-Host "  1. Restart the database: docker-compose restart" -ForegroundColor Gray
    Write-Host "  2. Connect without SSL: psql -h localhost -U postgres -d timescaledb" -ForegroundColor Gray
}

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan

exit 0
