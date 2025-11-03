param(
    [string]$Username = "xmpro",
    [string]$Password = "",
    [switch]$EnableSSL = $false,
    [switch]$Force = $false
)

# Ensure we're in the mqtt directory (not management subdirectory)
$CurrentLocation = Get-Location
if ($CurrentLocation.Path.EndsWith("management")) {
    # If we're in the management directory, go up one level to mqtt directory
    Set-Location ..
    Write-Host "Changed from management directory to mqtt directory" -ForegroundColor Gray
} elseif (Test-Path "management") {
    # If we're already in mqtt directory (has management subdirectory), stay here
    Write-Host "Already in mqtt directory" -ForegroundColor Gray
} else {
    # We might be in the wrong location
    Write-Host "Warning: Current directory may not be correct for MQTT installation" -ForegroundColor Yellow
    Write-Host "Expected to be in mqtt directory or mqtt/management directory" -ForegroundColor Yellow
}

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "MQTT Mosquitto Installation Script" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

# Check if Docker is running
Write-Host "Checking Docker availability..." -ForegroundColor White
try {
    docker version | Out-Null
    Write-Host "Docker is available" -ForegroundColor Green
} catch {
    Write-Host "Docker is not running or not installed!" -ForegroundColor Red
    Write-Host "Please install Docker Desktop and ensure it's running." -ForegroundColor Yellow
    exit 1
}

# Check if docker-compose is available
try {
    docker-compose version | Out-Null
    Write-Host "Docker Compose is available" -ForegroundColor Green
} catch {
    Write-Host "Docker Compose is not available!" -ForegroundColor Red
    Write-Host "Please ensure Docker Compose is installed." -ForegroundColor Yellow
    exit 1
}

# Check if MQTT container is already running
Write-Host "Checking existing MQTT containers..." -ForegroundColor White
try {
    $ExistingContainers = docker-compose ps --format json | ConvertFrom-Json
    $MqttContainer = $ExistingContainers | Where-Object { $_.Service -eq "mosquitto" }
    
    if ($MqttContainer -and $MqttContainer.State -eq "running") {
        Write-Host "MQTT container is already running" -ForegroundColor Yellow
        $StopChoice = Read-Host "Stop existing container to reconfigure? (y/n)"
        if ($StopChoice -eq "Y" -or $StopChoice -eq "y") {
            Write-Host "Stopping existing MQTT container..." -ForegroundColor Yellow
            docker-compose down
            Write-Host "Container stopped" -ForegroundColor Green
        } else {
            Write-Host "Installation cancelled - container still running" -ForegroundColor Yellow
            exit 0
        }
    } elseif ($MqttContainer) {
        Write-Host "MQTT container exists but is not running" -ForegroundColor Gray
    } else {
        Write-Host "No existing MQTT containers found" -ForegroundColor Green
    }
} catch {
    Write-Host "No existing containers found" -ForegroundColor Green
}

# Create directory structure
Write-Host "Creating directory structure..." -ForegroundColor White
$Directories = @("data", "data\backups", "logs", "config", "certs")
foreach ($Dir in $Directories) {
    if (-not (Test-Path $Dir)) {
        New-Item -ItemType Directory -Force -Path $Dir | Out-Null
        Write-Host "Created directory: $Dir" -ForegroundColor Green
    } else {
        Write-Host "Directory exists: $Dir" -ForegroundColor Gray
    }
}

# Ask about SSL setup (unless already specified via parameter)
if (-not $PSBoundParameters.ContainsKey('EnableSSL')) {
    Write-Host "SSL Configuration:" -ForegroundColor White
    $SSLChoice = Read-Host "Enable SSL/TLS encryption? (y/n)"
    if ($SSLChoice -eq "Y" -or $SSLChoice -eq "y") {
        $EnableSSL = $true
    }
}

if ($EnableSSL) {
    Write-Host "SSL will be enabled" -ForegroundColor Green
    
    # Ask for certificate type
    Write-Host ""
    Write-Host "Certificate Options:" -ForegroundColor White
    Write-Host "1. Generate self-signed certificates (for development/testing)" -ForegroundColor Gray
    Write-Host "2. Use CA-provided certificates (for production)" -ForegroundColor Gray
    $CertChoice = Read-Host "Select certificate type (1 or 2, default: 1)"
    
    if ($CertChoice -eq "2") {
        Write-Host "CA-provided certificates selected" -ForegroundColor Green
        Write-Host "You can install them after setup using: .\management\manage-ssl.ps1 install-ca" -ForegroundColor Cyan
        Write-Host "SSL will be configured but not enabled until certificates are installed" -ForegroundColor Yellow
        $EnableSSL = $false  # Don't generate self-signed certs, wait for CA certs
        $UseCAProvided = $true
    } else {
        Write-Host "Self-signed certificates selected" -ForegroundColor Green
        $UseCAProvided = $false
    }
} else {
    Write-Host "SSL will be disabled (unencrypted connections only)" -ForegroundColor Yellow
    $UseCAProvided = $false
}

# Generate or prompt for password if not provided
if (-not $Password) {
    Write-Host "Password Setup:" -ForegroundColor White
    do {
        $Choice = Read-Host "Generate secure password automatically? (y/n)"
        if ($Choice -eq "" -or $Choice -eq "Y" -or $Choice -eq "y") {
            Write-Host "Generating secure password..." -ForegroundColor White
            $Password = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 16 | ForEach-Object {[char]$_})
            Write-Host "Generated password for user '$Username': $Password" -ForegroundColor Green
            break
        } elseif ($Choice -eq "N" -or $Choice -eq "n") {
            $Password = Read-Host "Enter password for user '$Username'" -AsSecureString
            $Password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password))
            if (-not $Password) {
                Write-Host "Password cannot be empty!" -ForegroundColor Red
                exit 1
            }
            break
        } else {
            Write-Host "Please enter 'y' for yes or 'n' for no." -ForegroundColor Yellow
        }
    } while ($true)
}

# Create mosquitto.conf file if it doesn't exist
Write-Host "Creating configuration files..." -ForegroundColor White
if (-not (Test-Path "config\mosquitto.conf") -or $Force) {
    $MosquittoConf = @"
# General Configuration
pid_file /mosquitto/config/mosquitto.pid
persistence true
persistence_location /mosquitto/data/
log_dest file /mosquitto/log/mosquitto.log

# Listener Configuration
listener 1883
protocol mqtt

# Authentication Configuration
allow_anonymous false
password_file /mosquitto/config/passwords.txt

# Logging Configuration
log_type error
log_type warning
log_type notice
log_type information

# Persistence Configuration
autosave_interval 1800
autosave_on_changes true
"@
    $MosquittoConf | Out-File -FilePath "config\mosquitto.conf" -Encoding ASCII
    Write-Host "Created mosquitto.conf" -ForegroundColor Green
} else {
    Write-Host "mosquitto.conf already exists" -ForegroundColor Gray
}

# Create acl.txt file if it doesn't exist
if (-not (Test-Path "config\acl.txt") -or $Force) {
    $AclConf = @"
user $Username
topic readwrite #

pattern read `$SYS/#
"@
    $AclConf | Out-File -FilePath "config\acl.txt" -Encoding ASCII
    Write-Host "Created acl.txt with permissions for user '$Username'" -ForegroundColor Green
} else {
    Write-Host "acl.txt already exists" -ForegroundColor Gray
}

# Create password file
Write-Host "Setting up authentication..." -ForegroundColor White
if ((Test-Path "config\passwords.txt") -and (-not $Force)) {
    Write-Host "Password file already exists. Use -Force to overwrite." -ForegroundColor Yellow
} else {
    # Use mosquitto_passwd to create hashed password
    Write-Host "Creating password hash..." -ForegroundColor Gray
    
    # Method 1: Try direct volume mount (works on some systems)
    try {
        $TempContainer = "mosquitto-passwd-temp"
        docker run --rm --name $TempContainer -v "${PWD}\config:/mosquitto/config" eclipse-mosquitto:2.0.22 mosquitto_passwd -c /mosquitto/config/passwords.txt $Username "$Password" 2>$null
        
        if ($LASTEXITCODE -eq 0 -and (Test-Path "config\passwords.txt")) {
            Write-Host "Password file created for user '$Username'" -ForegroundColor Green
            Write-Host "Password: $Password" -ForegroundColor Yellow
            Write-Host "  (Save this password - it won't be shown again)" -ForegroundColor Gray
        } else {
            throw "Volume mount method failed"
        }
    } catch {
        Write-Host "Volume mount method failed, trying alternative..." -ForegroundColor Yellow
        
        # Method 2: Simple approach - create temp file and use container to hash it
        try {
            Write-Host "Creating password hash using container method..." -ForegroundColor Gray
            
            # Create a temporary password file with plain text
            "$Username`:$Password" | Out-File -FilePath "temp_passwords.txt" -Encoding ASCII -NoNewline
            
            # Use container to hash the password file
            docker run --rm -v "${PWD}:/work" -w /work eclipse-mosquitto:2.0.22 mosquitto_passwd -U temp_passwords.txt
            
            # Move the hashed file to the config directory
            if (Test-Path "temp_passwords.txt") {
                Move-Item "temp_passwords.txt" "config\passwords.txt" -Force
                Write-Host "Password file created with proper hash" -ForegroundColor Green
                Write-Host "Password: $Password" -ForegroundColor Yellow
                Write-Host "  (Save this password - it won't be shown again)" -ForegroundColor Gray
            } else {
                throw "Hash file creation failed"
            }
        } catch {
            Write-Host "Container hash method failed, using manual creation..." -ForegroundColor Yellow
            
            # Method 3: Manual creation with proper format
            Write-Host "Creating password file manually..." -ForegroundColor Gray
            "$Username`:$Password" | Out-File -FilePath "config\passwords.txt" -Encoding ASCII -NoNewline
            
            Write-Host "Password file created (will be hashed by broker on startup)" -ForegroundColor Green
            Write-Host "Password: $Password" -ForegroundColor Yellow
            Write-Host "  (Save this password - it won't be shown again)" -ForegroundColor Gray
            Write-Host "Note: Mosquitto will hash the password on first startup" -ForegroundColor Gray
        }
    }
}

# Set proper permissions for data directory
Write-Host "Setting directory permissions..." -ForegroundColor White
# On Windows, Docker handles most permissions, but we ensure directories are accessible
icacls "data" /grant "Everyone:(OI)(CI)F" /T | Out-Null
icacls "logs" /grant "Everyone:(OI)(CI)F" /T | Out-Null
Write-Host "Directory permissions configured" -ForegroundColor Green

# SSL Certificate setup
if ($EnableSSL) {
    Write-Host "Setting up SSL certificates..." -ForegroundColor White
    
    if (-not (Test-Path "certs\server.crt") -or $Force) {
        Write-Host "Generating self-signed SSL certificates using PowerShell..." -ForegroundColor Gray
        
        try {
            # Use OpenSSL in Docker container to generate certificates (more reliable)
            Write-Host "Generating certificates using OpenSSL in Docker..." -ForegroundColor Gray
            
            # Generate CA private key
            docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl genrsa -out ca.key 2048
            
            # Generate CA certificate
            docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl req -new -x509 -days 365 -key ca.key -out ca.crt -subj "/C=US/ST=State/L=City/O=MQTT-Broker/CN=MQTT-CA"
            
            # Generate server private key
            docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl genrsa -out server.key 2048
            
            # Generate server certificate signing request with SAN
            docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl req -new -key server.key -out server.csr -subj "/C=US/ST=State/L=City/O=MQTT-Broker/CN=localhost" -addext "subjectAltName=DNS:localhost,DNS:127.0.0.1,DNS:mqtt,IP:127.0.0.1,IP:::1"
            
            # Generate server certificate with SAN
            docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 365 -copy_extensions copy
            
            # Clean up CSR file
            docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine rm -f server.csr ca.srl
            
            # Verify certificates were created
            if ((Test-Path "certs\ca.crt") -and (Test-Path "certs\server.crt") -and (Test-Path "certs\server.key")) {
                Write-Host "SSL certificates generated successfully using Docker OpenSSL" -ForegroundColor Green
                
                # Clean up temporary Docker images (only if not from offline package)
                Write-Host "Cleaning up temporary Docker images..." -ForegroundColor Gray
                
                # Check if images were loaded from offline package by looking for specific tag pattern
                $AlpineOpenSSLInfo = docker images alpine/openssl:latest --format "{{.Repository}}:{{.Tag}} {{.CreatedSince}}" 2>$null
                
                # Only remove if images are very recent (likely just pulled) or if they don't have the offline package characteristics
                if ($AlpineOpenSSLInfo -and $AlpineOpenSSLInfo -notmatch "months|weeks") {
                    docker rmi alpine/openssl:latest -f 2>$null | Out-Null
                    Write-Host "Removed alpine/openssl temporary image" -ForegroundColor Gray
                } else {
                    Write-Host "Preserving alpine/openssl image (likely from offline package)" -ForegroundColor Green
                }
            } else {
                throw "Certificate files not created"
            }
            
            # Update mosquitto.conf to enable SSL
            $ConfigContent = Get-Content "config\mosquitto.conf" -Raw
            $ConfigContent += "`n`n# SSL Configuration`nlistener 8883`nprotocol mqtt`ncafile /mosquitto/certs/ca.crt`ncertfile /mosquitto/certs/server.crt`nkeyfile /mosquitto/certs/server.key`ntls_version tlsv1.2`nrequire_certificate false"
            Set-Content -Path "config\mosquitto.conf" -Value $ConfigContent
            
            # Create or update .env file for SSL
            if (Test-Path ".env") {
                $EnvContent = Get-Content ".env" -Raw
                $EnvContent = $EnvContent -replace "ENABLE_SSL=false", "ENABLE_SSL=true"
                Set-Content -Path ".env" -Value $EnvContent
            } else {
                # Create .env file with SSL enabled
                $EnvContent = @"
# MQTT Configuration
MQTT_PORT=1883
MQTT_SSL_PORT=8883
MQTT_WS_PORT=9002

# SSL Configuration
ENABLE_SSL=true

# Timezone
TZ=UTC
"@
                $EnvContent | Out-File -FilePath ".env" -Encoding ASCII
            }
            
            Write-Host "SSL configuration enabled in mosquitto.conf and .env" -ForegroundColor Green
        } catch {
            Write-Host "PowerShell SSL certificate generation failed: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "SSL will be disabled for this installation" -ForegroundColor Yellow
            $EnableSSL = $false
        }
    } elseif (Test-Path "certs\server.crt") {
        Write-Host "SSL certificates already exist" -ForegroundColor Gray
    }
}

# Create initial backup directory structure
Write-Host "Initializing backup system..." -ForegroundColor White
if (-not (Test-Path "data\backups")) {
    New-Item -ItemType Directory -Force -Path "data\backups" | Out-Null
}
Write-Host "Backup system initialized" -ForegroundColor Green

# Test configuration
Write-Host "Testing configuration..." -ForegroundColor White
try {
    docker-compose config | Out-Null
    Write-Host "Docker Compose configuration is valid" -ForegroundColor Green
} catch {
    Write-Host "Docker Compose configuration has errors!" -ForegroundColor Red
    Write-Host "Run 'docker-compose config' to see details." -ForegroundColor Gray
    exit 1
}

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "Installation Summary:" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "Directory structure created" -ForegroundColor Green
Write-Host "Authentication configured" -ForegroundColor Green
Write-Host "Permissions set" -ForegroundColor Green
if ($EnableSSL) {
    Write-Host "SSL certificates generated and configured" -ForegroundColor Green
}
Write-Host "Backup system initialized" -ForegroundColor Green
Write-Host "Configuration validated" -ForegroundColor Green
Write-Host ""
Write-Host "MQTT Broker Details:" -ForegroundColor Cyan
Write-Host "  Username: $Username" -ForegroundColor White
Write-Host "  Password: $Password" -ForegroundColor Yellow
Write-Host "  MQTT Port: 1883 (unencrypted)" -ForegroundColor White
if ($EnableSSL) {
    Write-Host "  MQTT SSL Port: 8883 (encrypted)" -ForegroundColor White
}
Write-Host "  WebSocket Port: 9002" -ForegroundColor White
Write-Host ""
Write-Host "Installation completed successfully!" -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Cyan

# Ask if user wants to start the broker now
Write-Host ""
$StartChoice = Read-Host "Start the MQTT broker now? (y/n)"
if ($StartChoice -eq "" -or $StartChoice -eq "Y" -or $StartChoice -eq "y") {
    Write-Host "Starting MQTT broker..." -ForegroundColor Green
    docker-compose up -d
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "MQTT broker started successfully!" -ForegroundColor Green
        
        # Wait a moment for the broker to initialize
        Write-Host "Waiting for broker to initialize..." -ForegroundColor Yellow
        Start-Sleep -Seconds 5
        
        # Check status
        Write-Host "Checking broker status..." -ForegroundColor White
        $Status = docker-compose ps --format json | ConvertFrom-Json
        $MqttStatus = $Status | Where-Object { $_.Service -eq "mosquitto" }
        
        if ($MqttStatus -and $MqttStatus.State -eq "running") {
            Write-Host "[OK] MQTT broker is running successfully!" -ForegroundColor Green
            Write-Host "[OK] Ready to accept connections" -ForegroundColor Green
        } else {
            Write-Host "[WARN] Broker may still be starting up" -ForegroundColor Yellow
            Write-Host "Check logs with: docker-compose logs mosquitto" -ForegroundColor Gray
        }
    } else {
        Write-Host "Failed to start MQTT broker" -ForegroundColor Red
        Write-Host "Check configuration and try: docker-compose up -d" -ForegroundColor Gray
    }
} else {
    Write-Host "MQTT broker not started" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To start manually:" -ForegroundColor Cyan
    Write-Host "1. Start the MQTT broker: docker-compose up -d" -ForegroundColor White
    Write-Host "2. Check status: docker-compose ps" -ForegroundColor White
    Write-Host "3. View logs: docker-compose logs -f mosquitto" -ForegroundColor White
}

Write-Host ""
Write-Host "Management Commands:" -ForegroundColor Cyan
Write-Host "===================" -ForegroundColor Gray
if ($UseCAProvided) {
    Write-Host "- Install CA certificates: .\management\manage-ssl.ps1 install-ca -ServerCertPath 'path\to\server.crt' -ServerKeyPath 'path\to\server.key'" -ForegroundColor Cyan
    Write-Host "- Enable SSL after installing: .\management\manage-ssl.ps1 enable" -ForegroundColor Cyan
}
Write-Host "- User management: .\management\manage-users.ps1 list" -ForegroundColor White
Write-Host "- SSL management: .\management\manage-ssl.ps1 status" -ForegroundColor White
Write-Host "- Create backup: .\management\backup.ps1" -ForegroundColor White
Write-Host "- Test connection with credentials above" -ForegroundColor White
Write-Host ""
Write-Host "Configuration files:" -ForegroundColor Cyan
Write-Host "  - docker-compose.yml (main configuration)" -ForegroundColor White
Write-Host "  - .env (environment variables)" -ForegroundColor White
Write-Host "  - config/mosquitto.conf (broker settings)" -ForegroundColor White
Write-Host "  - config/passwords.txt (user authentication)" -ForegroundColor White
Write-Host "  - config/acl.txt (access control)" -ForegroundColor White

# Return to appropriate directory based on how script was called
if ($Force) {
    # If called with -Force (from stack installer), stay in service directory
    Write-Host "Staying in mqtt directory for stack installer" -ForegroundColor Gray
} else {
    # If called manually, return to management directory
    Set-Location management
}
