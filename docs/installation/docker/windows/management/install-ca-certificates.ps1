# =================================================================
# Install/Remove Self-Signed CA Certificates to/from Windows Certificate Store
# =================================================================

param(
    [string]$InstallPath = "",
    [switch]$Force = $false,
    [switch]$Remove = $false,
    [switch]$Help = $false
)

# Show help if requested
if ($Help) {
    Write-Host "==================================================================" -ForegroundColor Cyan
    Write-Host "CA Certificate Management Script" -ForegroundColor Cyan
    Write-Host "==================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor White
    Write-Host "  .\install-ca-certificates.ps1 [options]" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Options:" -ForegroundColor Cyan
    Write-Host "  -InstallPath <path>  Path to Docker stack installation (default: current directory)" -ForegroundColor White
    Write-Host "  -Remove              Remove CA certificates instead of installing them" -ForegroundColor White
    Write-Host "  -Force               Skip confirmation prompts and overwrite existing certificates" -ForegroundColor White
    Write-Host "  -Help                Show this help message" -ForegroundColor White
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Cyan
    Write-Host "  # Install CA certificates from current directory" -ForegroundColor Gray
    Write-Host "  .\install-ca-certificates.ps1" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  # Install CA certificates from specific path" -ForegroundColor Gray
    Write-Host "  .\install-ca-certificates.ps1 -InstallPath 'C:\Docker'" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  # Remove all Docker stack CA certificates" -ForegroundColor Gray
    Write-Host "  .\install-ca-certificates.ps1 -Remove" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  # Force reinstall existing certificates" -ForegroundColor Gray
    Write-Host "  .\install-ca-certificates.ps1 -Force" -ForegroundColor Gray
    Write-Host ""
    Write-Host "==================================================================" -ForegroundColor Cyan
    exit 0
}

if ($Remove) {
    Write-Host "==================================================================" -ForegroundColor Cyan
    Write-Host "Remove Self-Signed CA Certificates from Windows Certificate Store" -ForegroundColor Cyan
    Write-Host "==================================================================" -ForegroundColor Cyan
} else {
    Write-Host "==================================================================" -ForegroundColor Cyan
    Write-Host "Install Self-Signed CA Certificates to Windows Certificate Store" -ForegroundColor Cyan
    Write-Host "==================================================================" -ForegroundColor Cyan
}

# Get installation path if not provided
if (-not $InstallPath) {
    # Check if we're in the management subfolder
    $CurrentLocation = Get-Location
    if ($CurrentLocation.Path.EndsWith("management")) {
        # Go up one level to the installation root
        $InstallPath = Split-Path $CurrentLocation -Parent
        Write-Host "Detected management subfolder, using parent directory: $InstallPath" -ForegroundColor White
    } else {
        $InstallPath = $CurrentLocation
        Write-Host "Using current directory: $InstallPath" -ForegroundColor White
    }
} else {
    Write-Host "Installation path: $InstallPath" -ForegroundColor White
}

# Check if running as Administrator
$IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

if (-not $IsAdmin) {
    Write-Host "Warning: Not running as Administrator" -ForegroundColor Yellow
    Write-Host "Installing to CurrentUser certificate store instead of LocalMachine" -ForegroundColor Yellow
    $CertStore = "Cert:\CurrentUser\Root"
    $StoreDescription = "Current User Trusted Root Certification Authorities"
} else {
    Write-Host "Running as Administrator" -ForegroundColor Green
    Write-Host "Installing to LocalMachine certificate store" -ForegroundColor Green
    $CertStore = "Cert:\LocalMachine\Root"
    $StoreDescription = "Local Machine Trusted Root Certification Authorities"
}

# Find all CA certificates from all services
$ServiceCerts = @(
    @{Service="Neo4j"; Path="neo4j\certs\bolt\trusted\ca.crt"; Name="Neo4j Bolt CA"},
    @{Service="Neo4j"; Path="neo4j\certs\https\trusted\ca.crt"; Name="Neo4j HTTPS CA"},
    @{Service="Milvus"; Path="milvus\tls\ca.pem"; Name="Milvus CA"},
    @{Service="MQTT"; Path="mqtt\certs\ca.crt"; Name="MQTT CA"},
    @{Service="TimescaleDB"; Path="timescaledb\certs\ca.crt"; Name="TimescaleDB CA"}
)

$AvailableCerts = @()
$ServicesSummary = @{}

Write-Host ""
Write-Host "Scanning for CA certificates..." -ForegroundColor White
Write-Host "===============================" -ForegroundColor Gray

foreach ($CertInfo in $ServiceCerts) {
    $FullPath = Join-Path $InstallPath $CertInfo.Path
    if (Test-Path $FullPath) {
        $AvailableCerts += @{
            Service = $CertInfo.Service
            Path = $FullPath
            Name = $CertInfo.Name
        }
        Write-Host "Found: $($CertInfo.Name) at $($CertInfo.Path)" -ForegroundColor Green
        
        if (-not $ServicesSummary.ContainsKey($CertInfo.Service)) {
            $ServicesSummary[$CertInfo.Service] = 0
        }
        $ServicesSummary[$CertInfo.Service]++
    } else {
        Write-Host "Missing: $($CertInfo.Name) at $($CertInfo.Path)" -ForegroundColor Gray
    }
}

if ($Remove) {
    # For remove operation, scan the certificate store instead of files
    Write-Host ""
    Write-Host "Scanning certificate store for Docker stack CA certificates..." -ForegroundColor White
    Write-Host "=============================================================" -ForegroundColor Gray
    
    $InstalledCerts = Get-ChildItem -Path $CertStore | Where-Object { 
        $_.Subject -match "Neo4j-CA|MQTT-CA" -or ($_.Subject -match "O=Milvus" -and $_.Issuer -match "O=Milvus")
    }
    
    if ($InstalledCerts.Count -eq 0) {
        Write-Host "No Docker stack CA certificates found in certificate store." -ForegroundColor Yellow
        Write-Host "Certificate store: $StoreDescription" -ForegroundColor Gray
        exit 0
    }
    
    Write-Host "Found $($InstalledCerts.Count) Docker stack CA certificate(s):" -ForegroundColor White
    foreach ($Cert in $InstalledCerts) {
        Write-Host "  - Subject: $($Cert.Subject)" -ForegroundColor Green
        Write-Host "    Thumbprint: $($Cert.Thumbprint)" -ForegroundColor Gray
        Write-Host "    Valid Until: $($Cert.NotAfter)" -ForegroundColor Gray
    }
    
    if (-not $Force) {
        Write-Host ""
        $ConfirmRemove = Read-Host "Remove all Docker stack CA certificates? (y/n)"
        if ($ConfirmRemove -ne "Y" -and $ConfirmRemove -ne "y") {
            Write-Host "Certificate removal cancelled." -ForegroundColor Yellow
            exit 0
        }
    }
    
    Write-Host ""
    Write-Host "Removing CA certificates from: $StoreDescription" -ForegroundColor White
    
    $RemovedCount = 0
    $ErrorCount = 0
    
    foreach ($Cert in $InstalledCerts) {
        try {
            Write-Host ""
            Write-Host "Removing: $($Cert.Subject)" -ForegroundColor White
            Remove-Item -Path "$CertStore\$($Cert.Thumbprint)" -Force
            Write-Host "  Certificate removed successfully!" -ForegroundColor Green
            $RemovedCount++
        } catch {
            Write-Host "  Failed to remove certificate: $($_.Exception.Message)" -ForegroundColor Red
            $ErrorCount++
        }
    }
    
    Write-Host ""
    Write-Host "==================================================================" -ForegroundColor Cyan
    Write-Host "Removal Summary" -ForegroundColor Cyan
    Write-Host "==================================================================" -ForegroundColor Cyan
    Write-Host "Certificates removed: $RemovedCount" -ForegroundColor Green
    Write-Host "Certificates failed: $ErrorCount" -ForegroundColor Red
    Write-Host "Certificate store: $StoreDescription" -ForegroundColor White
    
    if ($RemovedCount -gt 0) {
        Write-Host ""
        Write-Host "CA certificates have been removed from Windows certificate store." -ForegroundColor Green
        Write-Host "SSL connections will now show security warnings again." -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "CA certificate removal completed!" -ForegroundColor Green
    Write-Host "==================================================================" -ForegroundColor Cyan
    exit 0
}

if ($AvailableCerts.Count -eq 0) {
    Write-Host ""
    Write-Host "No CA certificates found!" -ForegroundColor Red
    Write-Host "This script should be run after services have been installed with SSL enabled." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To generate SSL certificates:" -ForegroundColor Cyan
    Write-Host "  cd neo4j && .\management\manage-ssl.ps1 generate && .\management\manage-ssl.ps1 enable" -ForegroundColor Gray
    Write-Host "  cd milvus && .\management\manage-ssl.ps1 generate && .\management\manage-ssl.ps1 enable" -ForegroundColor Gray
    Write-Host "  cd mqtt && .\management\manage-ssl.ps1 generate && .\management\manage-ssl.ps1 enable" -ForegroundColor Gray
    exit 1
}

Write-Host ""
Write-Host "Services with SSL certificates:" -ForegroundColor White
foreach ($Service in $ServicesSummary.Keys) {
    Write-Host "  $Service`: $($ServicesSummary[$Service]) certificate(s)" -ForegroundColor Green
}

Write-Host ""
Write-Host "Installing CA certificates to: $StoreDescription" -ForegroundColor White
Write-Host "Certificate Store: $CertStore" -ForegroundColor Gray

$InstalledCount = 0
$SkippedCount = 0
$ErrorCount = 0

foreach ($CertInfo in $AvailableCerts) {
    try {
        Write-Host ""
        Write-Host "Processing: $($CertInfo.Name)" -ForegroundColor White
        
        # Load the certificate
        $Certificate = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
        $Certificate.Import($CertInfo.Path)
        
        # Check if certificate already exists in store
        $ExistingCert = Get-ChildItem -Path $CertStore | Where-Object { $_.Thumbprint -eq $Certificate.Thumbprint }
        
        if ($ExistingCert -and -not $Force) {
            Write-Host "  Certificate already installed (Thumbprint: $($Certificate.Thumbprint))" -ForegroundColor Yellow
            Write-Host "  Subject: $($Certificate.Subject)" -ForegroundColor Gray
            $SkippedCount++
        } else {
            if ($ExistingCert -and $Force) {
                Write-Host "  Removing existing certificate..." -ForegroundColor Yellow
                Remove-Item -Path "$CertStore\$($Certificate.Thumbprint)" -Force
            }
            
            # Install the certificate
            if ($IsAdmin) {
                $Store = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root", "LocalMachine")
            } else {
                $Store = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root", "CurrentUser")
            }
            
            $Store.Open("ReadWrite")
            $Store.Add($Certificate)
            $Store.Close()
            
            Write-Host "  Certificate installed successfully!" -ForegroundColor Green
            Write-Host "  Thumbprint: $($Certificate.Thumbprint)" -ForegroundColor Gray
            Write-Host "  Subject: $($Certificate.Subject)" -ForegroundColor Gray
            Write-Host "  Valid Until: $($Certificate.NotAfter)" -ForegroundColor Gray
            $InstalledCount++
        }
        
        $Certificate.Dispose()
        
    } catch {
        Write-Host "  Failed to install certificate: $($_.Exception.Message)" -ForegroundColor Red
        $ErrorCount++
    }
}

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "Installation Summary" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "Certificates installed: $InstalledCount" -ForegroundColor Green
Write-Host "Certificates skipped: $SkippedCount" -ForegroundColor Yellow
Write-Host "Certificates failed: $ErrorCount" -ForegroundColor Red
Write-Host "Certificate store: $StoreDescription" -ForegroundColor White

if ($InstalledCount -gt 0) {
    Write-Host ""
    Write-Host "Benefits:" -ForegroundColor Cyan
    Write-Host "- Browser SSL warnings eliminated for HTTPS connections" -ForegroundColor Green
    Write-Host "- Applications can connect without certificate validation errors" -ForegroundColor Green
    Write-Host "- Secure connections work seamlessly across all services" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "Test SSL connections:" -ForegroundColor Cyan
    if ($ServicesSummary.ContainsKey("Neo4j")) {
        Write-Host "- Neo4j Browser: https://localhost:7473" -ForegroundColor White
        Write-Host "- Neo4j Bolt+TLS: bolt+s://localhost:7687" -ForegroundColor White
    }
    if ($ServicesSummary.ContainsKey("Milvus")) {
        Write-Host "- Milvus gRPC: localhost:19530 (TLS)" -ForegroundColor White
        Write-Host "- MinIO Console: https://localhost:9001" -ForegroundColor White
    }
    if ($ServicesSummary.ContainsKey("MQTT")) {
        Write-Host "- MQTT SSL: localhost:8883" -ForegroundColor White
    }
    if ($ServicesSummary.ContainsKey("TimescaleDB")) {
        Write-Host "- TimescaleDB PostgreSQL: postgresql://user:pass@localhost:5432/db?sslmode=require" -ForegroundColor White
        Write-Host "- pgAdmin Web UI: https://localhost:5051" -ForegroundColor White
    }
}

if ($SkippedCount -gt 0) {
    Write-Host ""
    Write-Host "To reinstall existing certificates, use: -Force parameter" -ForegroundColor Gray
}

if ($ErrorCount -gt 0) {
    Write-Host ""
    Write-Host "Some certificates failed to install. Try running as Administrator." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Certificate Management:" -ForegroundColor Cyan
Write-Host "======================" -ForegroundColor Gray
Write-Host "To remove installed certificates:" -ForegroundColor White
Write-Host "  .\install-ca-certificates.ps1 -Remove" -ForegroundColor Green
Write-Host ""
Write-Host "Manual removal via Certificate Manager:" -ForegroundColor White
if ($IsAdmin) {
    Write-Host "1. Open Certificate Manager: certlm.msc" -ForegroundColor Gray
} else {
    Write-Host "1. Open Certificate Manager: certmgr.msc" -ForegroundColor Gray
}
Write-Host "2. Navigate to: Trusted Root Certification Authorities > Certificates" -ForegroundColor Gray
Write-Host "3. Find certificates with Subject containing: Neo4j-CA, Milvus-CA, or MQTT-CA" -ForegroundColor Gray
Write-Host "4. Right-click > Delete" -ForegroundColor Gray

Write-Host ""
Write-Host "CA certificate installation completed!" -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Cyan
