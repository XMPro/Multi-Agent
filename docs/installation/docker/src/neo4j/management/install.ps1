param(
    [string]$Username = "neo4j",
    [string]$Password = "",
    [switch]$EnableSSL = $false,
    [string]$Domain = "localhost",
    [switch]$Force = $false
)

# Ensure we're in the neo4j directory (not management subdirectory)
$CurrentLocation = Get-Location
if ($CurrentLocation.Path.EndsWith("management")) {
    # If we're in the management directory, go up one level to neo4j directory
    Set-Location ..
    Write-Host "Changed from management directory to neo4j directory" -ForegroundColor Gray
} elseif (Test-Path "management") {
    # If we're already in neo4j directory (has management subdirectory), stay here
    Write-Host "Already in neo4j directory" -ForegroundColor Gray
} else {
    # We might be in the wrong location
    Write-Host "Warning: Current directory may not be correct for Neo4j installation" -ForegroundColor Yellow
    Write-Host "Expected to be in neo4j directory or neo4j/management directory" -ForegroundColor Yellow
}

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "Neo4j Graph Database Installation Script" -ForegroundColor Cyan
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

# Check if Neo4j container is already running
Write-Host "Checking existing Neo4j containers..." -ForegroundColor White
try {
    $ExistingContainers = docker-compose ps --format json | ConvertFrom-Json
    $Neo4jContainer = $ExistingContainers | Where-Object { $_.Service -eq "neo4j" }
    
    if ($Neo4jContainer -and $Neo4jContainer.State -eq "running") {
        Write-Host "Neo4j container is already running" -ForegroundColor Yellow
        $StopChoice = Read-Host "Stop existing container to reconfigure? (y/n)"
        if ($StopChoice -eq "Y" -or $StopChoice -eq "y") {
            Write-Host "Stopping existing Neo4j container..." -ForegroundColor Yellow
            docker-compose down
            Write-Host "Container stopped" -ForegroundColor Green
        } else {
            Write-Host "Installation cancelled - container still running" -ForegroundColor Yellow
            exit 0
        }
    } elseif ($Neo4jContainer) {
        Write-Host "Neo4j container exists but is not running" -ForegroundColor Gray
    } else {
        Write-Host "No existing Neo4j containers found" -ForegroundColor Green
    }
} catch {
    Write-Host "No existing containers found" -ForegroundColor Green
}

# Create directory structure
Write-Host "Creating directory structure..." -ForegroundColor White
$Directories = @(
    "neo4j-data",
    "neo4j-data\data", 
    "neo4j-data\logs", 
    "neo4j-data\plugins", 
    "neo4j-data\import", 
    "neo4j-data\backups",
    "init-scripts",
    "updates",
    "updates\processed",
    "certs",
    "certs\bolt",
    "certs\https",
    "certs\bolt\trusted",
    "certs\https\trusted"
)

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
    $SSLChoice = Read-Host "Enable SSL/TLS encryption for Neo4j? (y/n)"
    if ($SSLChoice -eq "Y" -or $SSLChoice -eq "y") {
        $EnableSSL = $true
    }
}

if ($EnableSSL) {
    $EnableSSL = $true
    Write-Host "SSL will be enabled for both Browser UI (HTTPS) and Bolt protocol (TLS)" -ForegroundColor Green
    
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
        
        # Ask for domain name
        $DomainChoice = Read-Host "Enter domain name for SSL certificate (default: localhost)"
        if ($DomainChoice) {
            $Domain = $DomainChoice
        }
        Write-Host "SSL certificates will be generated for domain: $Domain" -ForegroundColor White
        
        # Detect machine IP addresses
        Write-Host ""
        Write-Host "Detecting machine IP addresses..." -ForegroundColor White
        try {
            $AllIPs = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notmatch '^127\.' -and ($_.PrefixOrigin -eq 'Dhcp' -or $_.PrefixOrigin -eq 'Manual') }
            
            if ($AllIPs.Count -gt 0) {
                Write-Host "Detected IP addresses:" -ForegroundColor Green
                for ($i = 0; $i -lt $AllIPs.Count; $i++) {
                    $adapter = Get-NetAdapter -InterfaceIndex $AllIPs[$i].InterfaceIndex
                    Write-Host "  [$i] $($AllIPs[$i].IPAddress) - $($adapter.InterfaceDescription)" -ForegroundColor White
                }
                
                Write-Host ""
                $IPChoice = Read-Host "Enter IP numbers to include (comma-separated, e.g., '0,1') or press Enter to skip"
                
                if ($IPChoice) {
                    $SelectedIndices = $IPChoice -split ',' | ForEach-Object { $_.Trim() }
                    $MachineIPs = @()
                    foreach ($index in $SelectedIndices) {
                        if ($index -match '^\d+$' -and [int]$index -lt $AllIPs.Count) {
                            $MachineIPs += $AllIPs[[int]$index].IPAddress
                        }
                    }
                    
                    if ($MachineIPs.Count -gt 0) {
                        Write-Host "Selected IPs: $($MachineIPs -join ', ')" -ForegroundColor Cyan
                        $MachineIP = $MachineIPs -join ','
                    } else {
                        $MachineIP = ""
                        Write-Host "No valid IPs selected" -ForegroundColor Gray
                    }
                } else {
                    $MachineIP = ""
                    Write-Host "IP addresses not included (localhost/domain only)" -ForegroundColor Gray
                }
            } else {
                $MachineIP = ""
                Write-Host "Could not detect IP addresses, skipping" -ForegroundColor Gray
            }
        } catch {
            $MachineIP = ""
            Write-Host "Could not detect IP addresses: $($_.Exception.Message)" -ForegroundColor Gray
        }
    }
} else {
    Write-Host "SSL will be disabled (unencrypted connections only)" -ForegroundColor Yellow
    $UseCAProvided = $false
}

# Generate or prompt for password if not provided
if (-not $Password) {
    Write-Host "Password Setup:" -ForegroundColor White
    $Choice = Read-Host "Generate secure password automatically? (y/n)"
    
    if ($Choice -eq "" -or $Choice -eq "Y" -or $Choice -eq "y") {
        Write-Host "Generating secure password..." -ForegroundColor White
        # Generate a secure password for Neo4j (avoiding $ and other problematic characters for .env files)
        $Password = -join ((65..90) + (97..122) + (48..57) + @(33,35,37,38,42,43,45,61,63,64) | Get-Random -Count 20 | ForEach-Object {[char]$_})
        Write-Host "Generated password for user '$Username': $Password" -ForegroundColor Green
    } else {
        $Password = Read-Host "Enter password for user '$Username'" -AsSecureString
        $Password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password))
        if (-not $Password) {
            Write-Host "Password cannot be empty!" -ForegroundColor Red
            exit 1
        }
    }
} else {
    Write-Host "Using provided password for user '$Username'" -ForegroundColor Gray
}

# Update .env file with configuration
Write-Host "Creating configuration files..." -ForegroundColor White
# Determine NEO4J_URI based on SSL configuration
$Neo4jUri = if ($EnableSSL -or $UseCAProvided) { "bolt+s://neo4j:7687" } else { "bolt://neo4j:7687" }

$EnvContent = @"
# Neo4j Authentication
# Change these to secure values!
NEO4J_USER=$Username
NEO4J_PASSWORD=$Password

# Connection Configuration
NEO4J_URI=$Neo4jUri

# SSL Configuration
ENABLE_SSL=$($EnableSSL.ToString().ToLower())
SSL_DOMAIN=$Domain

# Neo4j Ports
NEO4J_HTTP_PORT=7474
NEO4J_HTTPS_PORT=7473
NEO4J_BOLT_PORT=7687

# Memory Configuration
NEO4J_HEAP_INITIAL_SIZE=2G
NEO4J_HEAP_MAX_SIZE=4G
NEO4J_PAGECACHE_SIZE=2G

# Timezone
TZ=UTC
"@

$EnvContent | Out-File -FilePath ".env" -Encoding ASCII
Write-Host "Created .env file with configuration" -ForegroundColor Green

# Set proper permissions for data directories
Write-Host "Setting directory permissions..." -ForegroundColor White
# On Windows, Docker handles most permissions, but we ensure directories are accessible
icacls "neo4j-data" /grant "Everyone:(OI)(CI)F" /T | Out-Null
icacls "updates" /grant "Everyone:(OI)(CI)F" /T | Out-Null
icacls "init-scripts" /grant "Everyone:(OI)(CI)F" /T | Out-Null
Write-Host "Directory permissions configured" -ForegroundColor Green

# SSL Certificate setup
if ($EnableSSL) {
    Write-Host "Setting up SSL certificates..." -ForegroundColor White
    
    if (-not (Test-Path "certs\bolt\private.key") -or $Force) {
        Write-Host "Generating SSL certificates for Neo4j..." -ForegroundColor Gray
        
        try {
            # Use OpenSSL in Docker container to generate certificates
            Write-Host "Generating certificates using OpenSSL in Docker..." -ForegroundColor Gray
            
            # Generate CA private key
            docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl genrsa -out ca.key 4096
            
            # Generate CA certificate
            docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl req -new -x509 -days 365 -key ca.key -out ca.crt -subj "/C=US/ST=State/L=City/O=Neo4j-Database/CN=Neo4j-CA"
            
            # Build SAN list
            $SANList = "DNS:$Domain,DNS:localhost,DNS:127.0.0.1,DNS:neo4j,IP:127.0.0.1,IP:::1"
            if ($MachineIP) {
                # Add each selected IP to the SAN list
                $IPArray = $MachineIP -split ','
                foreach ($IP in $IPArray) {
                    $SANList += ",IP:$($IP.Trim())"
                }
            }
            
            # Generate Bolt protocol certificates with SAN
            Write-Host "Generating Bolt protocol certificates..." -ForegroundColor Gray
            docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl genrsa -out bolt_private.key 4096
            docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl req -new -key bolt_private.key -out bolt.csr -subj "/C=US/ST=State/L=City/O=Neo4j-Database/CN=$Domain" -addext "subjectAltName=$SANList"
            docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl x509 -req -in bolt.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out bolt_public.crt -days 365 -copy_extensions copy
            
            # Generate HTTPS certificates with SAN
            Write-Host "Generating HTTPS certificates..." -ForegroundColor Gray
            docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl genrsa -out https_private.key 4096
            docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl req -new -key https_private.key -out https.csr -subj "/C=US/ST=State/L=City/O=Neo4j-Database/CN=$Domain" -addext "subjectAltName=$SANList"
            docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine/openssl x509 -req -in https.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out https_public.crt -days 365 -copy_extensions copy
            
            # Move certificates to proper directories
            docker run --rm -v "${PWD}\certs:/certs" -w /certs alpine sh -c "
                mv bolt_private.key bolt/private.key &&
                mv bolt_public.crt bolt/public.crt &&
                cp ca.crt bolt/trusted/ca.crt &&
                mv https_private.key https/private.key &&
                mv https_public.crt https/public.crt &&
                cp ca.crt https/trusted/ca.crt &&
                rm -f *.csr ca.srl cert_extensions.conf
            "
            
            # Verify certificates were created
            if ((Test-Path "certs\bolt\private.key") -and (Test-Path "certs\bolt\public.crt") -and 
                (Test-Path "certs\https\private.key") -and (Test-Path "certs\https\public.crt")) {
                Write-Host "SSL certificates generated successfully" -ForegroundColor Green
                
                # Note: alpine/openssl image is preserved for potential future SSL operations
                # It's included in offline packages and is small (~8MB), so keeping it doesn't hurt
                Write-Host "SSL certificate generation complete" -ForegroundColor Green
                Write-Host "Note: alpine/openssl image preserved for future SSL operations" -ForegroundColor Gray
            } else {
                throw "Certificate files not created properly"
            }
        } catch {
            Write-Host "SSL certificate generation failed: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "SSL will be disabled for this installation" -ForegroundColor Yellow
            $EnableSSL = $false
            
            # Update .env file to disable SSL
            $EnvContent = $EnvContent -replace "ENABLE_SSL=true", "ENABLE_SSL=false"
            Set-Content -Path ".env" -Value $EnvContent
        }
    } elseif (Test-Path "certs\bolt\private.key") {
        Write-Host "SSL certificates already exist" -ForegroundColor Gray
    }
}

# Update docker-compose.yml with SSL configuration if enabled
if ($EnableSSL) {
    Write-Host "Updating Docker Compose configuration for SSL..." -ForegroundColor White
    
    # Read current docker-compose.yml
    $ComposeContent = Get-Content "docker-compose.yml" -Raw
    
    # Add HTTPS port if not present
    if ($ComposeContent -notmatch "7473:7473") {
        $ComposeContent = $ComposeContent -replace '(\s+- "7474:7474")', "`$1`n      - `"7473:7473`"   # HTTPS Browser UI"
    }
    
    # Add SSL certificate volumes if not present
    if ($ComposeContent -notmatch "certificates") {
        $ComposeContent = $ComposeContent -replace '(\s+- \.\/neo4j-data\/import:\/var\/lib\/neo4j\/import)', "`$1`n      - ./certs:/var/lib/neo4j/certificates"
    }
    
    # Add SSL certificate volumes to watcher for SSL connections
    if ($ComposeContent -notmatch "neo4j-watcher.*certs") {
        $ComposeContent = $ComposeContent -replace '(neo4j-watcher:.*?volumes:\s+- \.\/updates:\/updates\s+- \.\/watcher\.py:\/watcher\.py)', "`$1`n      - ./certs:/certs"
    }
    
    # Add SSL environment variables
    $SSLEnvVars = @"

      # SSL Configuration
      - NEO4J_server_https_enabled=true
      - NEO4J_server_http_enabled=false
      
      # Bolt TLS Configuration
      - NEO4J_server_bolt_tls__level=REQUIRED
      
      # SSL Policies
      - NEO4J_dbms_ssl_policy_bolt_enabled=true
      - NEO4J_dbms_ssl_policy_bolt_base__directory=certificates/bolt
      - NEO4J_dbms_ssl_policy_bolt_private__key=private.key
      - NEO4J_dbms_ssl_policy_bolt_public__certificate=public.crt
      - NEO4J_dbms_ssl_policy_bolt_client__auth=NONE
      
      - NEO4J_dbms_ssl_policy_https_enabled=true
      - NEO4J_dbms_ssl_policy_https_base__directory=certificates/https
      - NEO4J_dbms_ssl_policy_https_private__key=private.key
      - NEO4J_dbms_ssl_policy_https_public__certificate=public.crt
      - NEO4J_dbms_ssl_policy_https_client__auth=NONE
"@
    
    if ($ComposeContent -notmatch "NEO4J_server_https_enabled") {
        $ComposeContent = $ComposeContent -replace '(\s+# Disable telemetry\s+- NEO4J_dbms_usage__report_enabled=false)', "`$1$SSLEnvVars"
    }
    
    # Update watcher to use SSL Bolt connection
    $ComposeContent = $ComposeContent -replace 'NEO4J_URI=bolt://neo4j:7687', 'NEO4J_URI=bolt+s://neo4j:7687'
    
    Set-Content -Path "docker-compose.yml" -Value $ComposeContent
    Write-Host "Docker Compose configuration updated for SSL" -ForegroundColor Green
    Write-Host "Neo4j watcher updated to use SSL Bolt connection" -ForegroundColor Green
}

# Create initial Cypher scripts directory structure
Write-Host "Initializing Cypher scripts system..." -ForegroundColor White
if (-not (Test-Path "init-scripts\README.md")) {
    $InitReadme = @"
# Neo4j Initialization Scripts

This directory contains Cypher scripts that will be executed when Neo4j starts for the first time.

## Usage
- Place .cypher files in this directory
- Scripts are executed in alphabetical order
- Use numbered prefixes for execution order (e.g., 01-constraints.cypher, 02-indexes.cypher)

## Examples
- 01-constraints.cypher - Create database constraints
- 02-indexes.cypher - Create database indexes  
- 03-initial-data.cypher - Load initial data
"@
    $InitReadme | Out-File -FilePath "init-scripts\README.md" -Encoding UTF8
}

if (-not (Test-Path "updates\README.md")) {
    $UpdatesReadme = @"
# Neo4j Updates Directory

This directory is monitored by the Neo4j watcher service for new Cypher scripts.

## Usage
- Drop .cypher files here to execute them automatically
- Files are processed once and moved to processed/ directory
- Monitor logs with: docker-compose logs neo4j-watcher

## File Naming
- Use descriptive names: add-user-nodes.cypher
- Include timestamps if needed: 2024-01-15-update-schema.cypher
"@
    $UpdatesReadme | Out-File -FilePath "updates\README.md" -Encoding UTF8
}

Write-Host "Cypher scripts system initialized" -ForegroundColor Green

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
Write-Host "Cypher scripts system initialized" -ForegroundColor Green
Write-Host "Configuration validated" -ForegroundColor Green
Write-Host ""
Write-Host "Neo4j Database Details:" -ForegroundColor Cyan
Write-Host "  Username: $Username" -ForegroundColor White
Write-Host "  Password: $Password" -ForegroundColor Yellow
if ($EnableSSL) {
    Write-Host "  Browser UI: https://localhost:7473 (HTTPS)" -ForegroundColor White
    Write-Host "  Bolt URI: bolt+s://localhost:7687 (TLS encrypted)" -ForegroundColor White
    Write-Host "  Domain: $Domain" -ForegroundColor White
} else {
    Write-Host "  Browser UI: http://localhost:7474 (HTTP)" -ForegroundColor White
    Write-Host "  Bolt URI: bolt://localhost:7687 (unencrypted)" -ForegroundColor White
}
Write-Host ""
Write-Host "Installation completed successfully!" -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Cyan

# Ask if user wants to start Neo4j now
Write-Host ""
$StartChoice = Read-Host "Start Neo4j database now? (y/n)"
if ($StartChoice -eq "" -or $StartChoice -eq "Y" -or $StartChoice -eq "y") {
    Write-Host "Starting Neo4j database..." -ForegroundColor Green
    docker-compose up -d
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Neo4j database started successfully!" -ForegroundColor Green
        
        # Wait for Neo4j to initialize (it takes longer than MQTT)
        Write-Host "Waiting for database to initialize (this may take 60-90 seconds)..." -ForegroundColor Yellow
        Start-Sleep -Seconds 30
        
        # Check status
        Write-Host "Checking database status..." -ForegroundColor White
        $Status = docker-compose ps --format json | ConvertFrom-Json
        $Neo4jStatus = $Status | Where-Object { $_.Service -eq "neo4j" }
        
        if ($Neo4jStatus -and $Neo4jStatus.State -eq "running") {
            Write-Host "[OK] Neo4j database is running successfully!" -ForegroundColor Green
            Write-Host "[OK] Ready to accept connections" -ForegroundColor Green
            
            # Test connection
            Write-Host "Testing database connection..." -ForegroundColor White
            Start-Sleep -Seconds 30  # Give more time for full initialization
            
            try {
                if ($EnableSSL) {
                    Write-Host "[OK] Access Neo4j Browser at: https://localhost:7473" -ForegroundColor Green
                    Write-Host "[OK] Connect with Bolt+TLS: bolt+s://localhost:7687" -ForegroundColor Green
                } else {
                    Write-Host "[OK] Access Neo4j Browser at: http://localhost:7474" -ForegroundColor Green
                    Write-Host "[OK] Connect with Bolt: bolt://localhost:7687" -ForegroundColor Green
                }
            } catch {
                Write-Host "[WARN] Database may still be initializing" -ForegroundColor Yellow
            }
        } else {
            Write-Host "[WARN] Database may still be starting up" -ForegroundColor Yellow
            Write-Host "Check logs with: docker-compose logs neo4j" -ForegroundColor Gray
        }
    } else {
        Write-Host "Failed to start Neo4j database" -ForegroundColor Red
        Write-Host "Check configuration and try: docker-compose up -d" -ForegroundColor Gray
    }
} else {
    Write-Host "Neo4j database not started" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To start manually:" -ForegroundColor Cyan
    Write-Host "1. Start the database: docker-compose up -d" -ForegroundColor White
    Write-Host "2. Check status: docker-compose ps" -ForegroundColor White
    Write-Host "3. View logs: docker-compose logs -f neo4j" -ForegroundColor White
}

Write-Host ""
Write-Host "Management Commands:" -ForegroundColor Cyan
Write-Host "===================" -ForegroundColor Gray
if ($EnableSSL) {
    Write-Host "- SSL management: .\management\manage-ssl.ps1 status" -ForegroundColor White
} elseif ($UseCAProvided) {
    Write-Host "- Install CA certificates: .\management\manage-ssl.ps1 install-ca -ServerCertPath 'path\to\server.crt' -ServerKeyPath 'path\to\server.key'" -ForegroundColor Cyan
    Write-Host "- Enable SSL after installing: .\management\manage-ssl.ps1 enable" -ForegroundColor Cyan
}
Write-Host "- Create backup: .\management\backup.ps1" -ForegroundColor White
Write-Host "- Restore backup: .\management\restore.ps1" -ForegroundColor White
Write-Host "- Monitor updates: docker-compose logs -f neo4j-watcher" -ForegroundColor White
Write-Host ""
Write-Host "Configuration files:" -ForegroundColor Cyan
Write-Host "  - docker-compose.yml (main configuration)" -ForegroundColor White
Write-Host "  - .env (environment variables)" -ForegroundColor White
Write-Host "  - init-scripts/ (startup Cypher scripts)" -ForegroundColor White
Write-Host "  - updates/ (monitored for new scripts)" -ForegroundColor White
if ($EnableSSL) {
    Write-Host "  - certs/ (SSL certificates)" -ForegroundColor White
}

# Return to appropriate directory based on how script was called
if ($Force) {
    # If called with -Force (from stack installer), stay in service directory
    Write-Host "Staying in neo4j directory for stack installer" -ForegroundColor Gray
} else {
    # If called manually, return to management directory
    Set-Location management
}
