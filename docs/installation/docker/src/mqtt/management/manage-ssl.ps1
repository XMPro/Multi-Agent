# =================================================================
# MQTT SSL Certificate Management Script
# =================================================================

param(
    [ValidateSet("generate", "enable", "disable", "status", "renew")]
    [string]$Action = "",
    
    [string]$Domain = "localhost",
    [int]$ValidDays = 365,
    [switch]$Force = $false
)

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "MQTT SSL Certificate Management Script" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

# Show help if no action provided
if (-not $Action) {
    Write-Host "Usage: .\manage-ssl.ps1 <action> [options]" -ForegroundColor White
    Write-Host ""
    Write-Host "Actions:" -ForegroundColor Cyan
    Write-Host "  generate    Generate new SSL certificates" -ForegroundColor White
    Write-Host "  enable      Enable SSL in MQTT broker" -ForegroundColor White
    Write-Host "  disable     Disable SSL in MQTT broker" -ForegroundColor White
    Write-Host "  status      Show SSL certificate status" -ForegroundColor White
    Write-Host "  renew       Renew existing SSL certificates" -ForegroundColor White
    Write-Host ""
    Write-Host "Parameters:" -ForegroundColor Cyan
    Write-Host "  -Domain     Certificate domain name (default: localhost)" -ForegroundColor White
    Write-Host "  -ValidDays  Certificate validity in days (default: 365)" -ForegroundColor White
    Write-Host "  -Force      Overwrite existing certificates without prompting" -ForegroundColor White
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Cyan
    Write-Host "  .\manage-ssl.ps1 generate" -ForegroundColor Gray
    Write-Host "  .\manage-ssl.ps1 generate -Domain 'mqtt.company.com' -ValidDays 730" -ForegroundColor Gray
    Write-Host "  .\manage-ssl.ps1 enable" -ForegroundColor Gray
    Write-Host "  .\manage-ssl.ps1 status" -ForegroundColor Gray
    Write-Host "  .\manage-ssl.ps1 renew -Force" -ForegroundColor Gray
    Write-Host ""
    Write-Host "==================================================================" -ForegroundColor Cyan
    exit 0
}

# Change to parent directory (mqtt folder)
Set-Location ..

# Check if Docker is available
function Test-Docker {
    try {
        docker version | Out-Null
        return $true
    } catch {
        Write-Host "Docker is not available!" -ForegroundColor Red
        Write-Host "Please ensure Docker Desktop is running." -ForegroundColor Yellow
        return $false
    }
}

# Function to restart MQTT broker
function Restart-MQTTBroker {
    Write-Host "Restarting MQTT broker to apply SSL changes..." -ForegroundColor Yellow
    docker-compose restart mosquitto
    Start-Sleep -Seconds 5
    Write-Host "MQTT broker restarted" -ForegroundColor Green
}

# Function to generate SSL certificates using Docker OpenSSL
function Generate-SSLCertificates {
    param([string]$Domain, [int]$ValidDays)
    
    Write-Host "Generating SSL certificates for domain: $Domain" -ForegroundColor White
    Write-Host "Certificate validity: $ValidDays days" -ForegroundColor Gray
    
    # Create certs directory if it doesn't exist
    if (-not (Test-Path "certs")) {
        New-Item -ItemType Directory -Force -Path "certs" | Out-Null
        Write-Host "Created certs directory" -ForegroundColor Green
    }
    
    try {
        # Generate CA private key
        Write-Host "Generating CA private key..." -ForegroundColor Gray
        docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl genrsa -out ca.key 2048
        
        # Generate CA certificate
        Write-Host "Generating CA certificate..." -ForegroundColor Gray
        docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl req -new -x509 -days $ValidDays -key ca.key -out ca.crt -subj "/C=US/ST=State/L=City/O=MQTT-Broker/CN=MQTT-CA"
        
        # Generate server private key
        Write-Host "Generating server private key..." -ForegroundColor Gray
        docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl genrsa -out server.key 2048
        
        # Generate server certificate signing request
        Write-Host "Generating server certificate signing request..." -ForegroundColor Gray
        docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl req -new -key server.key -out server.csr -subj "/C=US/ST=State/L=City/O=MQTT-Broker/CN=$Domain"
        
        # Generate server certificate
        Write-Host "Generating server certificate..." -ForegroundColor Gray
        docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days $ValidDays
        
        # Clean up temporary files
        docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl sh -c "rm -f server.csr ca.srl"
        
        # Verify certificates were created
        if ((Test-Path "certs\ca.crt") -and (Test-Path "certs\server.crt") -and (Test-Path "certs\server.key")) {
            Write-Host "SSL certificates generated successfully using Docker OpenSSL" -ForegroundColor Green
            
            # Clean up the alpine/openssl image
            Write-Host "Cleaning up temporary Docker image..." -ForegroundColor Gray
            docker rmi alpine/openssl -f 2>$null | Out-Null
            Write-Host "Temporary Docker image removed" -ForegroundColor Green
            
            return $true
        } else {
            Write-Host "Certificate files not created" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "SSL certificate generation failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to enable SSL in configuration
function Enable-SSL {
    Write-Host "Enabling SSL in MQTT configuration..." -ForegroundColor White
    
    # Add SSL configuration to mosquitto.conf
    $ConfigContent = Get-Content "config\mosquitto.conf" -Raw
    if ($ConfigContent -notmatch "listener 8883") {
        $ConfigContent += "`n`n# SSL Configuration`nlistener 8883`nprotocol mqtt`ncafile /mosquitto/certs/ca.crt`ncertfile /mosquitto/certs/server.crt`nkeyfile /mosquitto/certs/server.key`ntls_version tlsv1.2`nrequire_certificate false"
        Set-Content -Path "config\mosquitto.conf" -Value $ConfigContent
    }
    
    # Update .env file
    $EnvContent = Get-Content ".env" -Raw
    $EnvContent = $EnvContent -replace "ENABLE_SSL=false", "ENABLE_SSL=true"
    Set-Content -Path ".env" -Value $EnvContent
    
    Write-Host "SSL enabled in configuration" -ForegroundColor Green
}

# Function to disable SSL in configuration
function Disable-SSL {
    Write-Host "Disabling SSL in MQTT configuration..." -ForegroundColor White
    
    # Remove SSL configuration from mosquitto.conf
    $ConfigContent = Get-Content "config\mosquitto.conf" -Raw
    $ConfigContent = $ConfigContent -replace "(?s)`n`n# SSL Configuration.*?require_certificate false", ""
    Set-Content -Path "config\mosquitto.conf" -Value $ConfigContent
    
    # Update .env file
    $EnvContent = Get-Content ".env" -Raw
    $EnvContent = $EnvContent -replace "ENABLE_SSL=true", "ENABLE_SSL=false"
    Set-Content -Path ".env" -Value $EnvContent
    
    Write-Host "SSL disabled in configuration" -ForegroundColor Green
}

# Function to show SSL status
function Show-SSLStatus {
    Write-Host "SSL Certificate Status:" -ForegroundColor White
    Write-Host "======================" -ForegroundColor Gray
    
    # Check if certificates exist
    $CertFiles = @("ca.crt", "ca.key", "server.crt", "server.key")
    $AllCertsExist = $true
    
    foreach ($CertFile in $CertFiles) {
        $FilePath = "certs\$CertFile"
        if (Test-Path $FilePath) {
            $FileInfo = Get-Item $FilePath
            Write-Host "$CertFile - $($FileInfo.Length) bytes - Created: $($FileInfo.LastWriteTime)" -ForegroundColor Green
        } else {
            Write-Host "$CertFile - Missing" -ForegroundColor Red
            $AllCertsExist = $false
        }
    }
    
    # Show certificate expiry information
    if ($AllCertsExist) {
        Write-Host ""
        Write-Host "Certificate Expiry:" -ForegroundColor White
        Write-Host "==================" -ForegroundColor Gray
        
        try {
            # Use Docker OpenSSL to check certificate expiry
            $ExpiryInfo = docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl x509 -in server.crt -noout -dates
            if ($ExpiryInfo) {
                $NotAfterLine = $ExpiryInfo | Where-Object { $_ -match "notAfter=" }
                if ($NotAfterLine) {
                    $ExpiryDateStr = ($NotAfterLine -split "notAfter=")[1]
                    Write-Host "Expires: $ExpiryDateStr" -ForegroundColor White
                    
                    # Try to parse expiry date and calculate days remaining
                    try {
                        $ExpiryDate = [DateTime]::ParseExact($ExpiryDateStr, "MMM dd HH:mm:ss yyyy GMT", $null)
                        $DaysUntilExpiry = ($ExpiryDate - (Get-Date)).Days
                        
                        if ($DaysUntilExpiry -lt 0) {
                            Write-Host "Certificate EXPIRED $([Math]::Abs($DaysUntilExpiry)) days ago!" -ForegroundColor Red
                        } elseif ($DaysUntilExpiry -lt 30) {
                            Write-Host "Certificate expires in $DaysUntilExpiry days" -ForegroundColor Yellow
                        } else {
                            Write-Host "Certificate valid for $DaysUntilExpiry more days" -ForegroundColor Green
                        }
                    } catch {
                        Write-Host "Days remaining: Unable to calculate" -ForegroundColor Gray
                    }
                }
            }
            # Clean up the alpine/openssl image after checking expiry
            Write-Host "Cleaning up temporary Docker image..." -ForegroundColor Gray
            docker rmi alpine/openssl -f 2>$null | Out-Null
        } catch {
            Write-Host "Could not check certificate expiry" -ForegroundColor Yellow
        }
    }
    
    # Check configuration status
    Write-Host ""
    Write-Host "Configuration Status:" -ForegroundColor White
    Write-Host "====================" -ForegroundColor Gray
    
    $ConfigContent = Get-Content "config\mosquitto.conf" -Raw
    if ($ConfigContent -match "listener 8883") {
        Write-Host "SSL listener enabled (port 8883)" -ForegroundColor Green
    } else {
        Write-Host "SSL listener disabled" -ForegroundColor Red
    }
    
    $EnvContent = Get-Content ".env" -Raw
    if ($EnvContent -match "ENABLE_SSL=true") {
        Write-Host "SSL enabled in environment" -ForegroundColor Green
    } else {
        Write-Host "SSL disabled in environment" -ForegroundColor Red
    }
}

# Main script logic
switch ($Action) {
    "generate" {
        if (-not (Test-Docker)) { exit 1 }
        
        if ((Test-Path "certs\server.crt") -and -not $Force) {
            Write-Host "SSL certificates already exist!" -ForegroundColor Red
            Write-Host "Use -Force to overwrite existing certificates." -ForegroundColor Yellow
            exit 1
        }
        
        if (Generate-SSLCertificates -Domain $Domain -ValidDays $ValidDays) {
            Write-Host ""
            Write-Host "SSL certificates generated successfully!" -ForegroundColor Green
            Write-Host "Domain: $Domain" -ForegroundColor White
            Write-Host "Valid for: $ValidDays days" -ForegroundColor White
            Write-Host ""
            Write-Host "Use 'manage-ssl.ps1 enable' to activate SSL in the MQTT broker." -ForegroundColor Cyan
        }
    }
    
    "enable" {
        if (-not (Test-Path "certs\server.crt")) {
            Write-Host "SSL certificates not found!" -ForegroundColor Red
            Write-Host "Run 'manage-ssl.ps1 generate' first to create certificates." -ForegroundColor Yellow
            exit 1
        }
        
        Enable-SSL
        Restart-MQTTBroker
        
        Write-Host ""
        Write-Host "SSL enabled successfully!" -ForegroundColor Green
        Write-Host "MQTT SSL port: 8883" -ForegroundColor White
        Write-Host "Connect using SSL/TLS with your MQTT client." -ForegroundColor Cyan
    }
    
    "disable" {
        Disable-SSL
        Restart-MQTTBroker
        
        Write-Host ""
        Write-Host "SSL disabled successfully!" -ForegroundColor Green
        Write-Host "MQTT will only accept unencrypted connections on port 1883." -ForegroundColor Yellow
    }
    
    "status" {
        Show-SSLStatus
    }
    
    "renew" {
        if (-not (Test-Docker)) { exit 1 }
        
        if (-not (Test-Path "certs\server.crt")) {
            Write-Host "No existing certificates to renew!" -ForegroundColor Red
            Write-Host "Run 'manage-ssl.ps1 generate' to create new certificates." -ForegroundColor Yellow
            exit 1
        }
        
        Write-Host "Renewing SSL certificates..." -ForegroundColor White
        
        # Backup existing certificates
        $BackupDir = "certs\backup-$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
        Copy-Item -Path "certs\*.crt" -Destination $BackupDir -Force -ErrorAction SilentlyContinue
        Copy-Item -Path "certs\*.key" -Destination $BackupDir -Force -ErrorAction SilentlyContinue
        Write-Host "Existing certificates backed up to: $BackupDir" -ForegroundColor Green
        
        if (Generate-SSLCertificates -Domain $Domain -ValidDays $ValidDays) {
            Restart-MQTTBroker
            Write-Host ""
            Write-Host "SSL certificates renewed successfully!" -ForegroundColor Green
            Write-Host "Domain: $Domain" -ForegroundColor White
            Write-Host "Valid for: $ValidDays days" -ForegroundColor White
        }
    }
}

Write-Host ""
Write-Host "SSL management completed!" -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Cyan

# Return to management directory
Set-Location management
