# =================================================================
# Ollama Service Management Script for Windows
# Description: Manage Ollama Docker service operations
# Version: 1.0.0
# =================================================================

param(
    [ValidateSet("start", "stop", "restart", "status", "logs", "models", "pull", "remove-model", "update", "stats")]
    [string]$Action = "",
    
    [string]$ModelName = "",
    [int]$Lines = 100,
    [switch]$Follow = $false,
    [switch]$Force = $false
)

# Ensure we're in the ollama directory (not management subdirectory)
$CurrentLocation = Get-Location
if ($CurrentLocation.Path.EndsWith("management")) {
    Set-Location ..
}

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "Ollama Service Management" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

# Show help if no action provided
if (-not $Action) {
    Write-Host "Usage: .\manage-ollama.ps1 <action> [options]" -ForegroundColor White
    Write-Host ""
    Write-Host "Actions:" -ForegroundColor Cyan
    Write-Host "  start          Start Ollama service" -ForegroundColor White
    Write-Host "  stop           Stop Ollama service" -ForegroundColor White
    Write-Host "  restart        Restart Ollama service" -ForegroundColor White
    Write-Host "  status         Show comprehensive service status" -ForegroundColor White
    Write-Host "  logs           Display service logs" -ForegroundColor White
    Write-Host "  models         List downloaded models" -ForegroundColor White
    Write-Host "  pull           Pull a specific model" -ForegroundColor White
    Write-Host "  remove-model   Remove a downloaded model" -ForegroundColor White
    Write-Host "  update         Update Ollama Docker image" -ForegroundColor White
    Write-Host "  stats          Display resource usage statistics" -ForegroundColor White
    Write-Host ""
    Write-Host "Parameters:" -ForegroundColor Cyan
    Write-Host "  -ModelName     Model name for pull/remove-model actions" -ForegroundColor White
    Write-Host "  -Lines         Number of log lines to display (default: 100)" -ForegroundColor White
    Write-Host "  -Follow        Follow log output (tail -f)" -ForegroundColor White
    Write-Host "  -Force         Skip confirmation prompts" -ForegroundColor White
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Cyan
    Write-Host "  .\manage-ollama.ps1 status" -ForegroundColor Gray
    Write-Host "  .\manage-ollama.ps1 logs -Lines 50 -Follow" -ForegroundColor Gray
    Write-Host "  .\manage-ollama.ps1 pull -ModelName 'llama3.2:3b'" -ForegroundColor Gray
    Write-Host "  .\manage-ollama.ps1 remove-model -ModelName 'llama3.1:70b'" -ForegroundColor Gray
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

# Start service
function Start-OllamaService {
    Write-Host "Starting Ollama service..." -ForegroundColor White
    docker-compose up -d 2>&1 | Out-Null
    Start-Sleep -Seconds 3
    
    $Containers = docker-compose ps --format json 2>$null | ConvertFrom-Json
    $OllamaContainer = $Containers | Where-Object { $_.Service -eq "ollama" }
    
    if ($OllamaContainer -and $OllamaContainer.State -eq "running") {
        Write-Host "✓ Ollama service started successfully" -ForegroundColor Green
    } else {
        Write-Host "✗ Failed to start Ollama service" -ForegroundColor Red
        Write-Host "Check logs: .\manage-ollama.ps1 logs" -ForegroundColor Yellow
    }
}

# Stop service
function Stop-OllamaService {
    Write-Host "Stopping Ollama service..." -ForegroundColor White
    docker-compose stop 2>&1 | Out-Null
    Write-Host "✓ Ollama service stopped" -ForegroundColor Green
}

# Restart service
function Restart-OllamaService {
    Write-Host "Restarting Ollama service..." -ForegroundColor White
    docker-compose restart 2>&1 | Out-Null
    Start-Sleep -Seconds 3
    Write-Host "✓ Ollama service restarted" -ForegroundColor Green
}

# Show status
function Show-Status {
    Write-Host "Ollama Service Status" -ForegroundColor Cyan
    Write-Host "=====================" -ForegroundColor Cyan
    Write-Host ""
    
    # Docker Containers
    Write-Host "Docker Containers:" -ForegroundColor Cyan
    try {
        $Containers = docker-compose ps --format json 2>$null | ConvertFrom-Json
        foreach ($Container in $Containers) {
            $status = if ($Container.State -eq "running") { "✓ Running" } else { "✗ Stopped" }
            $color = if ($Container.State -eq "running") { "Green" } else { "Red" }
            Write-Host "  $($Container.Service): $status" -ForegroundColor $color
        }
    } catch {
        Write-Host "  Could not retrieve container status" -ForegroundColor Gray
    }
    
    Write-Host ""
    
    # API Endpoints
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
    
    # Test HTTP endpoint
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:$HttpPort/api/version" -TimeoutSec 2 -UseBasicParsing -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200) {
            Write-Host "  HTTP:  http://localhost:$HttpPort (✓ Responding)" -ForegroundColor Green
        }
    } catch {
        Write-Host "  HTTP:  http://localhost:$HttpPort (✗ Not Responding)" -ForegroundColor Red
    }
    
    # Test HTTPS endpoint if SSL is enabled
    $Containers = docker-compose ps --format json 2>$null | ConvertFrom-Json
    $NginxContainer = $Containers | Where-Object { $_.Service -eq "nginx-ssl" }
    if ($NginxContainer -and $NginxContainer.State -eq "running") {
        try {
            $response = Invoke-WebRequest -Uri "https://localhost:$HttpsPort/api/version" -TimeoutSec 2 -UseBasicParsing -SkipCertificateCheck -ErrorAction SilentlyContinue
            if ($response.StatusCode -eq 200) {
                Write-Host "  HTTPS: https://localhost:$HttpsPort (✓ Responding)" -ForegroundColor Green
            }
        } catch {
            Write-Host "  HTTPS: https://localhost:$HttpsPort (✗ Not Responding)" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    
    # Configuration
    Write-Host "Configuration:" -ForegroundColor Cyan
    if (Test-Path ".env") {
        $envContent = Get-Content ".env"
        
        $gpuDriver = ($envContent | Where-Object { $_ -match "OLLAMA_GPU_DRIVER=" }) -replace "OLLAMA_GPU_DRIVER=", ""
        Write-Host "  GPU Support: $gpuDriver" -ForegroundColor White
        
        $numParallel = ($envContent | Where-Object { $_ -match "OLLAMA_NUM_PARALLEL=" }) -replace "OLLAMA_NUM_PARALLEL=", ""
        if ($numParallel) {
            Write-Host "  Max Parallel Requests: $numParallel" -ForegroundColor White
        }
        
        $maxLoaded = ($envContent | Where-Object { $_ -match "OLLAMA_MAX_LOADED_MODELS=" }) -replace "OLLAMA_MAX_LOADED_MODELS=", ""
        if ($maxLoaded) {
            Write-Host "  Max Loaded Models: $maxLoaded" -ForegroundColor White
        }
        
        $keepAlive = ($envContent | Where-Object { $_ -match "OLLAMA_KEEP_ALIVE=" }) -replace "OLLAMA_KEEP_ALIVE=", ""
        if ($keepAlive) {
            Write-Host "  Keep Alive: $keepAlive" -ForegroundColor White
        }
    }
    
    Write-Host ""
    
    # Downloaded Models
    Write-Host "Downloaded Models:" -ForegroundColor Cyan
    try {
        $ModelList = docker exec ollama ollama list 2>$null
        if ($ModelList) {
            $Models = $ModelList -split "`n" | Select-Object -Skip 1
            $ModelCount = ($Models | Where-Object { $_.Trim() -ne "" }).Count
            Write-Host "  Total: $ModelCount model(s)" -ForegroundColor White
            Write-Host ""
            Write-Host $ModelList -ForegroundColor Gray
        } else {
            Write-Host "  No models downloaded" -ForegroundColor Gray
        }
    } catch {
        Write-Host "  Could not retrieve model list" -ForegroundColor Gray
    }
    
    Write-Host ""
    
    # Test Commands
    Write-Host "Test Commands:" -ForegroundColor Cyan
    Write-Host "  curl http://localhost:$HttpPort/api/version" -ForegroundColor Gray
    Write-Host "  curl http://localhost:$HttpPort/api/tags" -ForegroundColor Gray
    Write-Host ""
}

# Show logs
function Show-Logs {
    Write-Host "Ollama Service Logs (last $Lines lines)" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    if ($Follow) {
        Write-Host "Following logs (Ctrl+C to exit)..." -ForegroundColor Gray
        Write-Host ""
        docker-compose logs ollama --tail $Lines --follow
    } else {
        docker-compose logs ollama --tail $Lines
    }
}

# List models
function Show-Models {
    Write-Host "Downloaded Models" -ForegroundColor Cyan
    Write-Host "=================" -ForegroundColor Cyan
    Write-Host ""
    
    try {
        $ModelList = docker exec ollama ollama list 2>$null
        if ($ModelList) {
            Write-Host $ModelList -ForegroundColor White
            Write-Host ""
            Write-Host "Commands:" -ForegroundColor Cyan
            Write-Host "  Pull model:   .\manage-ollama.ps1 pull -ModelName <name>" -ForegroundColor Gray
            Write-Host "  Remove model: .\manage-ollama.ps1 remove-model -ModelName <name>" -ForegroundColor Gray
            Write-Host "  Test model:   docker exec ollama ollama run <name> `"test prompt`"" -ForegroundColor Gray
        } else {
            Write-Host "No models downloaded yet" -ForegroundColor Gray
            Write-Host ""
            Write-Host "Download models using: .\management\pull-models.ps1" -ForegroundColor Cyan
        }
    } catch {
        Write-Host "✗ Could not retrieve model list" -ForegroundColor Red
        Write-Host "Ensure Ollama service is running" -ForegroundColor Yellow
    }
    
    Write-Host ""
}

# Pull model
function Pull-Model {
    param([string]$ModelName)
    
    if (-not $ModelName) {
        Write-Host "✗ Model name is required" -ForegroundColor Red
        Write-Host "Usage: .\manage-ollama.ps1 pull -ModelName 'llama3.2:3b'" -ForegroundColor Yellow
        return
    }
    
    Write-Host "Pulling model: $ModelName" -ForegroundColor Cyan
    Write-Host "This may take several minutes..." -ForegroundColor Gray
    Write-Host ""
    
    try {
        docker exec ollama ollama pull $ModelName
        Write-Host ""
        Write-Host "✓ Model pulled successfully: $ModelName" -ForegroundColor Green
    } catch {
        Write-Host ""
        Write-Host "✗ Failed to pull model: $ModelName" -ForegroundColor Red
    }
}

# Remove model
function Remove-Model {
    param([string]$ModelName)
    
    if (-not $ModelName) {
        Write-Host "✗ Model name is required" -ForegroundColor Red
        Write-Host "Usage: .\manage-ollama.ps1 remove-model -ModelName 'llama3.1:70b'" -ForegroundColor Yellow
        return
    }
    
    # Check if model exists
    try {
        $ModelList = docker exec ollama ollama list 2>$null
        if (-not ($ModelList -match $ModelName)) {
            Write-Host "✗ Model not found: $ModelName" -ForegroundColor Red
            return
        }
    } catch {
        Write-Host "✗ Could not check model list" -ForegroundColor Red
        return
    }
    
    if (-not $Force) {
        $Confirm = Read-Host "Remove model '$ModelName'? (y/n)"
        if ($Confirm -ne "Y" -and $Confirm -ne "y") {
            Write-Host "Model removal cancelled" -ForegroundColor Yellow
            return
        }
    }
    
    Write-Host "Removing model: $ModelName" -ForegroundColor White
    
    try {
        docker exec ollama ollama rm $ModelName 2>&1 | Out-Null
        Write-Host "✓ Model removed successfully: $ModelName" -ForegroundColor Green
    } catch {
        Write-Host "✗ Failed to remove model: $ModelName" -ForegroundColor Red
    }
}

# Update Ollama
function Update-Ollama {
    Write-Host "Updating Ollama Docker image..." -ForegroundColor White
    Write-Host ""
    
    Write-Host "Pulling latest Ollama image..." -ForegroundColor Gray
    docker-compose pull ollama
    
    Write-Host ""
    Write-Host "Recreating container with new image..." -ForegroundColor Gray
    docker-compose up -d ollama
    
    Start-Sleep -Seconds 3
    
    Write-Host ""
    Write-Host "✓ Ollama updated successfully" -ForegroundColor Green
    Write-Host ""
    
    # Display version
    try {
        $Version = docker exec ollama ollama --version 2>$null
        Write-Host "Current version: $Version" -ForegroundColor White
    } catch {
        Write-Host "Could not retrieve version" -ForegroundColor Gray
    }
}

# Show stats
function Show-Stats {
    Write-Host "Ollama Resource Usage" -ForegroundColor Cyan
    Write-Host "=====================" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "Container Statistics:" -ForegroundColor Cyan
    docker stats ollama --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"
    
    Write-Host ""
    
    # Show GPU stats if available
    try {
        $NvidiaSmi = nvidia-smi --query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader 2>$null
        if ($LASTEXITCODE -eq 0 -and $NvidiaSmi) {
            Write-Host "GPU Statistics:" -ForegroundColor Cyan
            Write-Host $NvidiaSmi -ForegroundColor White
        }
    } catch {
        # No GPU or nvidia-smi not available
    }
    
    Write-Host ""
}

# Main script logic
if (-not (Test-Docker)) {
    exit 1
}

switch ($Action) {
    "start" {
        Start-OllamaService
    }
    
    "stop" {
        Stop-OllamaService
    }
    
    "restart" {
        Restart-OllamaService
    }
    
    "status" {
        Show-Status
    }
    
    "logs" {
        Show-Logs
    }
    
    "models" {
        Show-Models
    }
    
    "pull" {
        Pull-Model -ModelName $ModelName
    }
    
    "remove-model" {
        Remove-Model -ModelName $ModelName
    }
    
    "update" {
        Update-Ollama
    }
    
    "stats" {
        Show-Stats
    }
    
    default {
        Write-Host "Unknown action: $Action" -ForegroundColor Red
        exit 1
    }
}

Write-Host "==================================================================" -ForegroundColor Cyan
