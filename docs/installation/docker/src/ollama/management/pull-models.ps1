# =================================================================
# Ollama Model Download Script for Windows
# Description: Interactive wizard to download Ollama models
# Version: 1.0.0
# =================================================================

param(
    [switch]$Minimal = $false,
    [switch]$Standard = $false,
    [switch]$Performance = $false,
    [switch]$HighEnd = $false,
    [switch]$Custom = $false,
    [switch]$EmbeddingOnly = $false
)

# Ensure we're in the ollama directory (not management subdirectory)
$CurrentLocation = Get-Location
if ($CurrentLocation.Path.EndsWith("management")) {
    Set-Location ..
}

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "Ollama Model Download Wizard" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

# Check if Docker is running
Write-Host "Checking Docker availability..." -ForegroundColor White
try {
    docker version | Out-Null
} catch {
    Write-Host "✗ Docker is not running!" -ForegroundColor Red
    Write-Host "Please start Docker Desktop and try again." -ForegroundColor Yellow
    exit 1
}

# Check if Ollama container is running
Write-Host "Checking Ollama service..." -ForegroundColor White
$OllamaRunning = $false
try {
    $Containers = docker-compose ps --format json 2>$null | ConvertFrom-Json
    $OllamaContainer = $Containers | Where-Object { $_.Service -eq "ollama" }
    
    if ($OllamaContainer -and $OllamaContainer.State -eq "running") {
        $OllamaRunning = $true
        Write-Host "✓ Ollama service is running" -ForegroundColor Green
    }
} catch {
    # Container not found
}

if (-not $OllamaRunning) {
    Write-Host "✗ Ollama service is not running" -ForegroundColor Red
    $StartChoice = Read-Host "Start Ollama service now? (y/n)"
    if ($StartChoice -eq "Y" -or $StartChoice -eq "y") {
        Write-Host "Starting Ollama service..." -ForegroundColor White
        docker-compose up -d
        Start-Sleep -Seconds 5
        Write-Host "✓ Ollama service started" -ForegroundColor Green
    } else {
        Write-Host "Cannot download models without Ollama running" -ForegroundColor Yellow
        exit 1
    }
}

Write-Host ""

# Display current models
Write-Host "Current Downloaded Models:" -ForegroundColor Cyan
try {
    $CurrentModels = docker exec ollama ollama list 2>$null
    if ($CurrentModels) {
        Write-Host $CurrentModels -ForegroundColor Gray
    } else {
        Write-Host "  No models downloaded yet" -ForegroundColor Gray
    }
} catch {
    Write-Host "  Could not retrieve model list" -ForegroundColor Gray
}

Write-Host ""

# Check available disk space
Write-Host "Checking available disk space..." -ForegroundColor White
try {
    $VolumeInfo = docker volume inspect ollama-data 2>$null | ConvertFrom-Json
    if ($VolumeInfo) {
        $MountPoint = $VolumeInfo.Mountpoint
        # Get drive from mountpoint
        $Drive = $MountPoint.Substring(0, 2)
        $DiskInfo = Get-PSDrive $Drive.Substring(0, 1)
        $FreeSpaceGB = [math]::Round($DiskInfo.Free / 1GB, 2)
        Write-Host "Available space: $FreeSpaceGB GB" -ForegroundColor White
        
        if ($FreeSpaceGB -lt 10) {
            Write-Host "⚠ Warning: Low disk space! Some models may not fit." -ForegroundColor Yellow
        }
    }
} catch {
    Write-Host "Could not determine available space" -ForegroundColor Gray
}

Write-Host ""

# Model definitions
$EmbeddingModels = @{
    "nomic-embed-text:latest" = @{
        Name = "nomic-embed-text:latest"
        Size = "274 MB"
        Dimensions = "768"
        Description = "Fast, efficient embeddings (Recommended)"
        Recommended = $true
    }
    "mxbai-embed-large:latest" = @{
        Name = "mxbai-embed-large:latest"
        Size = "669 MB"
        Dimensions = "1024"
        Description = "Higher quality embeddings"
        Recommended = $false
    }
}

$InferenceModels = @{
    "llama3.2:1b" = @{
        Name = "llama3.2:1b"
        Size = "1.3 GB"
        Params = "1B"
        Description = "Very fast, basic tasks"
        Profile = "Minimal"
    }
    "llama3.2:3b" = @{
        Name = "llama3.2:3b"
        Size = "2.0 GB"
        Params = "3B"
        Description = "Fast, good quality (Recommended)"
        Profile = "Minimal"
    }
    "llama3.1:8b" = @{
        Name = "llama3.1:8b"
        Size = "4.7 GB"
        Params = "8B"
        Description = "Balanced performance"
        Profile = "Standard"
    }
    "mistral:7b" = @{
        Name = "mistral:7b"
        Size = "4.1 GB"
        Params = "7B"
        Description = "Excellent reasoning"
        Profile = "Standard"
    }
    "qwen2.5:7b" = @{
        Name = "qwen2.5:7b"
        Size = "4.7 GB"
        Params = "7B"
        Description = "Multilingual support"
        Profile = "Performance"
    }
    "deepseek-r1:8b" = @{
        Name = "deepseek-r1:8b"
        Size = "4.9 GB"
        Params = "8B"
        Description = "Advanced reasoning"
        Profile = "Performance"
    }
    "llama3.1:70b" = @{
        Name = "llama3.1:70b"
        Size = "40 GB"
        Params = "70B"
        Description = "Highest quality"
        Profile = "HighEnd"
    }
    "qwen2.5:72b" = @{
        Name = "qwen2.5:72b"
        Size = "41 GB"
        Params = "72B"
        Description = "Best multilingual"
        Profile = "HighEnd"
    }
}

# Model selection
$SelectedModels = @()

if ($Minimal -or $Standard -or $Performance -or $HighEnd) {
    # Profile-based selection
    if ($Minimal) {
        $SelectedModels += "nomic-embed-text:latest"
        $SelectedModels += "llama3.2:3b"
    }
    if ($Standard) {
        $SelectedModels += "nomic-embed-text:latest"
        $SelectedModels += "llama3.1:8b"
        $SelectedModels += "mistral:7b"
    }
    if ($Performance) {
        $SelectedModels += "nomic-embed-text:latest"
        $SelectedModels += "llama3.1:8b"
        $SelectedModels += "mistral:7b"
        $SelectedModels += "qwen2.5:7b"
        $SelectedModels += "deepseek-r1:8b"
    }
    if ($HighEnd) {
        $SelectedModels += "nomic-embed-text:latest"
        $SelectedModels += "mxbai-embed-large:latest"
        $SelectedModels += "llama3.1:70b"
        $SelectedModels += "qwen2.5:72b"
    }
} elseif ($EmbeddingOnly) {
    $SelectedModels += "nomic-embed-text:latest"
} else {
    # Interactive selection
    Write-Host "Model Selection Menu" -ForegroundColor Cyan
    Write-Host "====================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Required Embedding Models (Choose at least one):" -ForegroundColor Yellow
    Write-Host "  [1] nomic-embed-text:latest (768 dim, ~274MB) ✓ Recommended" -ForegroundColor White
    Write-Host "  [2] mxbai-embed-large:latest (1024 dim, ~669MB)" -ForegroundColor White
    Write-Host ""
    Write-Host "Inference Model Profiles:" -ForegroundColor Yellow
    Write-Host "  [3] Minimal Profile (llama3.2:3b) - ~2GB total" -ForegroundColor White
    Write-Host "  [4] Standard Profile (llama3.1:8b + mistral:7b) - ~9GB total" -ForegroundColor White
    Write-Host "  [5] Performance Profile (4 models) - ~18GB total" -ForegroundColor White
    Write-Host "  [6] High-End Profile (70B+ models) - ~80GB+ total" -ForegroundColor White
    Write-Host "  [7] Custom Selection (choose individual models)" -ForegroundColor White
    Write-Host ""
    
    $Selection = Read-Host "Enter selection (comma-separated for multiple, e.g., 1,4)"
    
    $Choices = $Selection -split ',' | ForEach-Object { $_.Trim() }
    
    foreach ($Choice in $Choices) {
        switch ($Choice) {
            "1" { $SelectedModels += "nomic-embed-text:latest" }
            "2" { $SelectedModels += "mxbai-embed-large:latest" }
            "3" { 
                $SelectedModels += "nomic-embed-text:latest"
                $SelectedModels += "llama3.2:3b"
            }
            "4" {
                $SelectedModels += "nomic-embed-text:latest"
                $SelectedModels += "llama3.1:8b"
                $SelectedModels += "mistral:7b"
            }
            "5" {
                $SelectedModels += "nomic-embed-text:latest"
                $SelectedModels += "llama3.1:8b"
                $SelectedModels += "mistral:7b"
                $SelectedModels += "qwen2.5:7b"
                $SelectedModels += "deepseek-r1:8b"
            }
            "6" {
                $SelectedModels += "nomic-embed-text:latest"
                $SelectedModels += "mxbai-embed-large:latest"
                $SelectedModels += "llama3.1:70b"
                $SelectedModels += "qwen2.5:72b"
            }
            "7" {
                # Custom selection
                Write-Host ""
                Write-Host "Available Inference Models:" -ForegroundColor Cyan
                Write-Host "  [1] llama3.2:1b (~1.3GB) - Very fast, basic tasks" -ForegroundColor White
                Write-Host "  [2] llama3.2:3b (~2.0GB) - Fast, good quality" -ForegroundColor White
                Write-Host "  [3] llama3.1:8b (~4.7GB) - Balanced" -ForegroundColor White
                Write-Host "  [4] mistral:7b (~4.1GB) - Excellent reasoning" -ForegroundColor White
                Write-Host "  [5] qwen2.5:7b (~4.7GB) - Multilingual" -ForegroundColor White
                Write-Host "  [6] deepseek-r1:8b (~4.9GB) - Advanced reasoning" -ForegroundColor White
                Write-Host "  [7] llama3.1:70b (~40GB) - Highest quality" -ForegroundColor White
                Write-Host "  [8] qwen2.5:72b (~41GB) - Best multilingual" -ForegroundColor White
                Write-Host ""
                
                $CustomSelection = Read-Host "Enter selections (comma-separated)"
                $CustomChoices = $CustomSelection -split ',' | ForEach-Object { $_.Trim() }
                
                foreach ($CustomChoice in $CustomChoices) {
                    switch ($CustomChoice) {
                        "1" { $SelectedModels += "llama3.2:1b" }
                        "2" { $SelectedModels += "llama3.2:3b" }
                        "3" { $SelectedModels += "llama3.1:8b" }
                        "4" { $SelectedModels += "mistral:7b" }
                        "5" { $SelectedModels += "qwen2.5:7b" }
                        "6" { $SelectedModels += "deepseek-r1:8b" }
                        "7" { $SelectedModels += "llama3.1:70b" }
                        "8" { $SelectedModels += "qwen2.5:72b" }
                    }
                }
            }
        }
    }
}

# Remove duplicates
$SelectedModels = $SelectedModels | Select-Object -Unique

if ($SelectedModels.Count -eq 0) {
    Write-Host "No models selected. Exiting." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Selected Models:" -ForegroundColor Cyan
foreach ($Model in $SelectedModels) {
    if ($EmbeddingModels.ContainsKey($Model)) {
        $Info = $EmbeddingModels[$Model]
        Write-Host "  • $($Info.Name) - $($Info.Size) - $($Info.Description)" -ForegroundColor White
    } elseif ($InferenceModels.ContainsKey($Model)) {
        $Info = $InferenceModels[$Model]
        Write-Host "  • $($Info.Name) - $($Info.Size) - $($Info.Description)" -ForegroundColor White
    } else {
        Write-Host "  • $Model" -ForegroundColor White
    }
}

Write-Host ""
$Confirm = Read-Host "Download these models? (y/n)"
if ($Confirm -ne "Y" -and $Confirm -ne "y") {
    Write-Host "Download cancelled" -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "Downloading Models" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

$SuccessCount = 0
$FailedModels = @()

foreach ($Model in $SelectedModels) {
    Write-Host "Downloading: $Model" -ForegroundColor Cyan
    Write-Host "This may take several minutes depending on model size..." -ForegroundColor Gray
    
    try {
        $Output = docker exec ollama ollama pull $Model 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Successfully downloaded: $Model" -ForegroundColor Green
            $SuccessCount++
        } else {
            Write-Host "✗ Failed to download: $Model" -ForegroundColor Red
            $FailedModels += $Model
        }
    } catch {
        Write-Host "✗ Error downloading $Model : $($_.Exception.Message)" -ForegroundColor Red
        $FailedModels += $Model
    }
    
    Write-Host ""
}

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "Download Summary" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Successfully downloaded: $SuccessCount model(s)" -ForegroundColor Green

if ($FailedModels.Count -gt 0) {
    Write-Host "Failed downloads: $($FailedModels.Count) model(s)" -ForegroundColor Red
    foreach ($Failed in $FailedModels) {
        Write-Host "  • $Failed" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Current Models:" -ForegroundColor Cyan
try {
    $FinalModels = docker exec ollama ollama list 2>$null
    Write-Host $FinalModels -ForegroundColor Gray
} catch {
    Write-Host "Could not retrieve model list" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Test Commands:" -ForegroundColor Cyan
Write-Host "  Test embedding model:" -ForegroundColor White
Write-Host "    docker exec ollama ollama run nomic-embed-text `"test`"" -ForegroundColor Gray
Write-Host ""
Write-Host "  Test inference model:" -ForegroundColor White
Write-Host "    docker exec ollama ollama run llama3.2:3b `"Hello, how are you?`"" -ForegroundColor Gray
Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
