#!/bin/bash
# =================================================================
# Ollama Model Download Script for Linux
# Description: Interactive wizard to download Ollama models
# Version: 1.0.0
# =================================================================

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

# Default parameters
MINIMAL=false
STANDARD=false
PERFORMANCE=false
HIGH_END=false
CUSTOM=false
EMBEDDING_ONLY=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --minimal)
            MINIMAL=true
            shift
            ;;
        --standard)
            STANDARD=true
            shift
            ;;
        --performance)
            PERFORMANCE=true
            shift
            ;;
        --high-end)
            HIGH_END=true
            shift
            ;;
        --custom)
            CUSTOM=true
            shift
            ;;
        --embedding-only)
            EMBEDDING_ONLY=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Ensure we're in the ollama directory (not management subdirectory)
if [[ $(basename "$PWD") == "management" ]]; then
    cd ..
fi

echo -e "${CYAN}==================================================================${NC}"
echo -e "${CYAN}Ollama Model Download Wizard${NC}"
echo -e "${CYAN}==================================================================${NC}"
echo ""

# Check if Docker is running
echo -e "${GRAY}Checking Docker availability...${NC}"
if ! docker version &> /dev/null; then
    echo -e "${RED}✗ Docker is not running!${NC}"
    echo -e "${YELLOW}Please start Docker and try again.${NC}"
    exit 1
fi

# Check if Ollama container is running
echo -e "${GRAY}Checking Ollama service...${NC}"
OLLAMA_RUNNING=false

if docker-compose ps 2>/dev/null | grep -q "ollama.*running"; then
    OLLAMA_RUNNING=true
    echo -e "${GREEN}✓ Ollama service is running${NC}"
fi

if [ "$OLLAMA_RUNNING" = false ]; then
    echo -e "${RED}✗ Ollama service is not running${NC}"
    read -p "Start Ollama service now? (y/n): " start_choice
    if [[ "$start_choice" =~ ^[Yy]$ ]]; then
        echo -e "${GRAY}Starting Ollama service...${NC}"
        docker-compose up -d
        sleep 5
        echo -e "${GREEN}✓ Ollama service started${NC}"
    else
        echo -e "${YELLOW}Cannot download models without Ollama running${NC}"
        exit 1
    fi
fi

echo ""

# Display current models
echo -e "${CYAN}Current Downloaded Models:${NC}"
CURRENT_MODELS=$(docker exec ollama ollama list 2>/dev/null)
if [ -n "$CURRENT_MODELS" ]; then
    echo -e "${GRAY}$CURRENT_MODELS${NC}"
else
    echo -e "${GRAY}  No models downloaded yet${NC}"
fi

echo ""

# Check available disk space
echo -e "${GRAY}Checking available disk space...${NC}"
FREE_SPACE=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')
echo -e "${GRAY}Available space: ${FREE_SPACE} GB${NC}"

if [ "$FREE_SPACE" -lt 10 ]; then
    echo -e "${YELLOW}⚠ Warning: Low disk space! Some models may not fit.${NC}"
fi

echo ""

# Model selection
SELECTED_MODELS=()

if [ "$MINIMAL" = true ] || [ "$STANDARD" = true ] || [ "$PERFORMANCE" = true ] || [ "$HIGH_END" = true ]; then
    # Profile-based selection
    if [ "$MINIMAL" = true ]; then
        SELECTED_MODELS+=("nomic-embed-text:latest")
        SELECTED_MODELS+=("llama3.2:3b")
    fi
    if [ "$STANDARD" = true ]; then
        SELECTED_MODELS+=("nomic-embed-text:latest")
        SELECTED_MODELS+=("llama3.1:8b")
        SELECTED_MODELS+=("mistral:7b")
    fi
    if [ "$PERFORMANCE" = true ]; then
        SELECTED_MODELS+=("nomic-embed-text:latest")
        SELECTED_MODELS+=("llama3.1:8b")
        SELECTED_MODELS+=("mistral:7b")
        SELECTED_MODELS+=("qwen2.5:7b")
        SELECTED_MODELS+=("deepseek-r1:8b")
    fi
    if [ "$HIGH_END" = true ]; then
        SELECTED_MODELS+=("nomic-embed-text:latest")
        SELECTED_MODELS+=("mxbai-embed-large:latest")
        SELECTED_MODELS+=("llama3.1:70b")
        SELECTED_MODELS+=("qwen2.5:72b")
    fi
elif [ "$EMBEDDING_ONLY" = true ]; then
    SELECTED_MODELS+=("nomic-embed-text:latest")
else
    # Interactive selection
    echo -e "${CYAN}Model Selection Menu${NC}"
    echo -e "${CYAN}====================${NC}"
    echo ""
    echo -e "${YELLOW}Required Embedding Models (Choose at least one):${NC}"
    echo -e "${GRAY}  [1] nomic-embed-text:latest (768 dim, ~274MB) ✓ Recommended${NC}"
    echo -e "${GRAY}  [2] mxbai-embed-large:latest (1024 dim, ~669MB)${NC}"
    echo ""
    echo -e "${YELLOW}Inference Model Profiles:${NC}"
    echo -e "${GRAY}  [3] Minimal Profile (llama3.2:3b) - ~2GB total${NC}"
    echo -e "${GRAY}  [4] Standard Profile (llama3.1:8b + mistral:7b) - ~9GB total${NC}"
    echo -e "${GRAY}  [5] Performance Profile (4 models) - ~18GB total${NC}"
    echo -e "${GRAY}  [6] High-End Profile (70B+ models) - ~80GB+ total${NC}"
    echo -e "${GRAY}  [7] Custom Selection (choose individual models)${NC}"
    echo ""
    
    read -p "Enter selection (comma-separated for multiple, e.g., 1,4): " selection
    
    IFS=',' read -ra CHOICES <<< "$selection"
    
    for choice in "${CHOICES[@]}"; do
        choice=$(echo "$choice" | xargs) # Trim whitespace
        case $choice in
            1)
                SELECTED_MODELS+=("nomic-embed-text:latest")
                ;;
            2)
                SELECTED_MODELS+=("mxbai-embed-large:latest")
                ;;
            3)
                SELECTED_MODELS+=("nomic-embed-text:latest")
                SELECTED_MODELS+=("llama3.2:3b")
                ;;
            4)
                SELECTED_MODELS+=("nomic-embed-text:latest")
                SELECTED_MODELS+=("llama3.1:8b")
                SELECTED_MODELS+=("mistral:7b")
                ;;
            5)
                SELECTED_MODELS+=("nomic-embed-text:latest")
                SELECTED_MODELS+=("llama3.1:8b")
                SELECTED_MODELS+=("mistral:7b")
                SELECTED_MODELS+=("qwen2.5:7b")
                SELECTED_MODELS+=("deepseek-r1:8b")
                ;;
            6)
                SELECTED_MODELS+=("nomic-embed-text:latest")
                SELECTED_MODELS+=("mxbai-embed-large:latest")
                SELECTED_MODELS+=("llama3.1:70b")
                SELECTED_MODELS+=("qwen2.5:72b")
                ;;
            7)
                # Custom selection
                echo ""
                echo -e "${CYAN}Available Inference Models:${NC}"
                echo -e "${GRAY}  [1] llama3.2:1b (~1.3GB) - Very fast, basic tasks${NC}"
                echo -e "${GRAY}  [2] llama3.2:3b (~2.0GB) - Fast, good quality${NC}"
                echo -e "${GRAY}  [3] llama3.1:8b (~4.7GB) - Balanced${NC}"
                echo -e "${GRAY}  [4] mistral:7b (~4.1GB) - Excellent reasoning${NC}"
                echo -e "${GRAY}  [5] qwen2.5:7b (~4.7GB) - Multilingual${NC}"
                echo -e "${GRAY}  [6] deepseek-r1:8b (~4.9GB) - Advanced reasoning${NC}"
                echo -e "${GRAY}  [7] llama3.1:70b (~40GB) - Highest quality${NC}"
                echo -e "${GRAY}  [8] qwen2.5:72b (~41GB) - Best multilingual${NC}"
                echo ""
                
                read -p "Enter selections (comma-separated): " custom_selection
                
                IFS=',' read -ra CUSTOM_CHOICES <<< "$custom_selection"
                
                for custom_choice in "${CUSTOM_CHOICES[@]}"; do
                    custom_choice=$(echo "$custom_choice" | xargs)
                    case $custom_choice in
                        1) SELECTED_MODELS+=("llama3.2:1b") ;;
                        2) SELECTED_MODELS+=("llama3.2:3b") ;;
                        3) SELECTED_MODELS+=("llama3.1:8b") ;;
                        4) SELECTED_MODELS+=("mistral:7b") ;;
                        5) SELECTED_MODELS+=("qwen2.5:7b") ;;
                        6) SELECTED_MODELS+=("deepseek-r1:8b") ;;
                        7) SELECTED_MODELS+=("llama3.1:70b") ;;
                        8) SELECTED_MODELS+=("qwen2.5:72b") ;;
                    esac
                done
                ;;
        esac
    done
fi

# Remove duplicates
SELECTED_MODELS=($(echo "${SELECTED_MODELS[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

if [ ${#SELECTED_MODELS[@]} -eq 0 ]; then
    echo -e "${YELLOW}No models selected. Exiting.${NC}"
    exit 0
fi

echo ""
echo -e "${CYAN}Selected Models:${NC}"
for model in "${SELECTED_MODELS[@]}"; do
    case $model in
        "nomic-embed-text:latest")
            echo -e "${GRAY}  • $model - 274 MB - Fast, efficient embeddings (Recommended)${NC}"
            ;;
        "mxbai-embed-large:latest")
            echo -e "${GRAY}  • $model - 669 MB - Higher quality embeddings${NC}"
            ;;
        "llama3.2:1b")
            echo -e "${GRAY}  • $model - 1.3 GB - Very fast, basic tasks${NC}"
            ;;
        "llama3.2:3b")
            echo -e "${GRAY}  • $model - 2.0 GB - Fast, good quality${NC}"
            ;;
        "llama3.1:8b")
            echo -e "${GRAY}  • $model - 4.7 GB - Balanced performance${NC}"
            ;;
        "mistral:7b")
            echo -e "${GRAY}  • $model - 4.1 GB - Excellent reasoning${NC}"
            ;;
        "qwen2.5:7b")
            echo -e "${GRAY}  • $model - 4.7 GB - Multilingual support${NC}"
            ;;
        "deepseek-r1:8b")
            echo -e "${GRAY}  • $model - 4.9 GB - Advanced reasoning${NC}"
            ;;
        "llama3.1:70b")
            echo -e "${GRAY}  • $model - 40 GB - Highest quality${NC}"
            ;;
        "qwen2.5:72b")
            echo -e "${GRAY}  • $model - 41 GB - Best multilingual${NC}"
            ;;
        *)
            echo -e "${GRAY}  • $model${NC}"
            ;;
    esac
done

echo ""
read -p "Download these models? (y/n): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Download cancelled${NC}"
    exit 0
fi

echo ""
echo -e "${CYAN}==================================================================${NC}"
echo -e "${CYAN}Downloading Models${NC}"
echo -e "${CYAN}==================================================================${NC}"
echo ""

SUCCESS_COUNT=0
FAILED_MODELS=()

for model in "${SELECTED_MODELS[@]}"; do
    echo -e "${CYAN}Downloading: $model${NC}"
    echo -e "${GRAY}This may take several minutes depending on model size...${NC}"
    
    if docker exec ollama ollama pull "$model" 2>&1; then
        echo -e "${GREEN}✓ Successfully downloaded: $model${NC}"
        ((SUCCESS_COUNT++))
    else
        echo -e "${RED}✗ Failed to download: $model${NC}"
        FAILED_MODELS+=("$model")
    fi
    
    echo ""
done

echo -e "${CYAN}==================================================================${NC}"
echo -e "${CYAN}Download Summary${NC}"
echo -e "${CYAN}==================================================================${NC}"
echo ""
echo -e "${GREEN}Successfully downloaded: $SUCCESS_COUNT model(s)${NC}"

if [ ${#FAILED_MODELS[@]} -gt 0 ]; then
    echo -e "${RED}Failed downloads: ${#FAILED_MODELS[@]} model(s)${NC}"
    for failed in "${FAILED_MODELS[@]}"; do
        echo -e "${RED}  • $failed${NC}"
    done
fi

echo ""
echo -e "${CYAN}Current Models:${NC}"
FINAL_MODELS=$(docker exec ollama ollama list 2>/dev/null)
if [ -n "$FINAL_MODELS" ]; then
    echo -e "${GRAY}$FINAL_MODELS${NC}"
else
    echo -e "${GRAY}Could not retrieve model list${NC}"
fi

echo ""
echo -e "${CYAN}Test Commands:${NC}"
echo -e "${GRAY}  Test embedding model:${NC}"
echo -e "${GRAY}    docker exec ollama ollama run nomic-embed-text \"test\"${NC}"
echo ""
echo -e "${GRAY}  Test inference model:${NC}"
echo -e "${GRAY}    docker exec ollama ollama run llama3.2:3b \"Hello, how are you?\"${NC}"
echo ""
echo -e "${CYAN}==================================================================${NC}"
