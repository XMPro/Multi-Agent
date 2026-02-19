#!/bin/bash
# =================================================================
# Ollama Service Management Script for Linux
# Description: Manage Ollama Docker service operations
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
ACTION=""
MODEL_NAME=""
LINES=100
FOLLOW=false
FORCE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        start|stop|restart|status|logs|models|pull|remove-model|update|stats)
            ACTION="$1"
            shift
            ;;
        --model-name)
            MODEL_NAME="$2"
            shift 2
            ;;
        --lines)
            LINES="$2"
            shift 2
            ;;
        --follow)
            FOLLOW=true
            shift
            ;;
        --force)
            FORCE=true
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
echo -e "${CYAN}Ollama Service Management${NC}"
echo -e "${CYAN}==================================================================${NC}"
echo ""

# Show help if no action provided
if [ -z "$ACTION" ]; then
    echo -e "${GRAY}Usage: ./manage-ollama.sh <action> [options]${NC}"
    echo ""
    echo -e "${CYAN}Actions:${NC}"
    echo -e "${GRAY}  start          Start Ollama service${NC}"
    echo -e "${GRAY}  stop           Stop Ollama service${NC}"
    echo -e "${GRAY}  restart        Restart Ollama service${NC}"
    echo -e "${GRAY}  status         Show comprehensive service status${NC}"
    echo -e "${GRAY}  logs           Display service logs${NC}"
    echo -e "${GRAY}  models         List downloaded models${NC}"
    echo -e "${GRAY}  pull           Pull a specific model${NC}"
    echo -e "${GRAY}  remove-model   Remove a downloaded model${NC}"
    echo -e "${GRAY}  update         Update Ollama Docker image${NC}"
    echo -e "${GRAY}  stats          Display resource usage statistics${NC}"
    echo ""
    echo -e "${CYAN}Parameters:${NC}"
    echo -e "${GRAY}  --model-name   Model name for pull/remove-model actions${NC}"
    echo -e "${GRAY}  --lines        Number of log lines to display (default: 100)${NC}"
    echo -e "${GRAY}  --follow       Follow log output (tail -f)${NC}"
    echo -e "${GRAY}  --force        Skip confirmation prompts${NC}"
    echo ""
    echo -e "${CYAN}Examples:${NC}"
    echo -e "${GRAY}  ./manage-ollama.sh status${NC}"
    echo -e "${GRAY}  ./manage-ollama.sh logs --lines 50 --follow${NC}"
    echo -e "${GRAY}  ./manage-ollama.sh pull --model-name llama3.2:3b${NC}"
    echo -e "${GRAY}  ./manage-ollama.sh remove-model --model-name llama3.1:70b${NC}"
    echo ""
    echo -e "${CYAN}==================================================================${NC}"
    exit 0
fi

# Check if Docker is available
check_docker() {
    if ! docker version &> /dev/null; then
        echo -e "${RED}✗ Docker is not available!${NC}"
        echo -e "${YELLOW}Please ensure Docker is running.${NC}"
        return 1
    fi
    return 0
}

# Start service
start_service() {
    echo -e "${GRAY}Starting Ollama service...${NC}"
    docker-compose up -d 2>&1 > /dev/null
    sleep 3
    
    if docker-compose ps 2>/dev/null | grep -q "ollama.*running"; then
        echo -e "${GREEN}✓ Ollama service started successfully${NC}"
    else
        echo -e "${RED}✗ Failed to start Ollama service${NC}"
        echo -e "${YELLOW}Check logs: ./manage-ollama.sh logs${NC}"
    fi
}

# Stop service
stop_service() {
    echo -e "${GRAY}Stopping Ollama service...${NC}"
    docker-compose stop 2>&1 > /dev/null
    echo -e "${GREEN}✓ Ollama service stopped${NC}"
}

# Restart service
restart_service() {
    echo -e "${GRAY}Restarting Ollama service...${NC}"
    docker-compose restart 2>&1 > /dev/null
    sleep 3
    echo -e "${GREEN}✓ Ollama service restarted${NC}"
}

# Show status
show_status() {
    echo -e "${CYAN}Ollama Service Status${NC}"
    echo -e "${CYAN}=====================${NC}"
    echo ""
    
    # Docker Containers
    echo -e "${CYAN}Docker Containers:${NC}"
    if docker-compose ps 2>/dev/null | tail -n +2 | grep -q .; then
        docker-compose ps 2>/dev/null | tail -n +2 | while read line; do
            if echo "$line" | grep -q "running"; then
                echo -e "${GREEN}  ✓ $line${NC}"
            else
                echo -e "${RED}  ✗ $line${NC}"
            fi
        done
    else
        echo -e "${GRAY}  No containers found${NC}"
    fi
    
    echo ""
    
    # API Endpoints
    echo -e "${CYAN}API Endpoints:${NC}"
    HTTP_PORT="11434"
    HTTPS_PORT="11443"
    
    if [ -f ".env" ]; then
        HTTP_PORT=$(grep "OLLAMA_PORT=" .env | cut -d'=' -f2)
        HTTPS_PORT=$(grep "OLLAMA_HTTPS_PORT=" .env | cut -d'=' -f2)
    fi
    
    # Test HTTP endpoint
    if curl -sf "http://localhost:$HTTP_PORT/api/version" > /dev/null 2>&1; then
        echo -e "${GREEN}  HTTP:  http://localhost:$HTTP_PORT (✓ Responding)${NC}"
    else
        echo -e "${RED}  HTTP:  http://localhost:$HTTP_PORT (✗ Not Responding)${NC}"
    fi
    
    # Test HTTPS endpoint if SSL is enabled
    if docker-compose ps 2>/dev/null | grep -q "nginx-ssl.*running"; then
        if curl -sfk "https://localhost:$HTTPS_PORT/api/version" > /dev/null 2>&1; then
            echo -e "${GREEN}  HTTPS: https://localhost:$HTTPS_PORT (✓ Responding)${NC}"
        else
            echo -e "${RED}  HTTPS: https://localhost:$HTTPS_PORT (✗ Not Responding)${NC}"
        fi
    fi
    
    echo ""
    
    # Configuration
    echo -e "${CYAN}Configuration:${NC}"
    if [ -f ".env" ]; then
        GPU_DRIVER=$(grep "OLLAMA_GPU_DRIVER=" .env | cut -d'=' -f2)
        echo -e "${GRAY}  GPU Support: $GPU_DRIVER${NC}"
        
        NUM_PARALLEL=$(grep "OLLAMA_NUM_PARALLEL=" .env | cut -d'=' -f2)
        if [ -n "$NUM_PARALLEL" ]; then
            echo -e "${GRAY}  Max Parallel Requests: $NUM_PARALLEL${NC}"
        fi
        
        MAX_LOADED=$(grep "OLLAMA_MAX_LOADED_MODELS=" .env | cut -d'=' -f2)
        if [ -n "$MAX_LOADED" ]; then
            echo -e "${GRAY}  Max Loaded Models: $MAX_LOADED${NC}"
        fi
        
        KEEP_ALIVE=$(grep "OLLAMA_KEEP_ALIVE=" .env | cut -d'=' -f2)
        if [ -n "$KEEP_ALIVE" ]; then
            echo -e "${GRAY}  Keep Alive: $KEEP_ALIVE${NC}"
        fi
    fi
    
    echo ""
    
    # Downloaded Models
    echo -e "${CYAN}Downloaded Models:${NC}"
    MODEL_LIST=$(docker exec ollama ollama list 2>/dev/null)
    if [ -n "$MODEL_LIST" ]; then
        MODEL_COUNT=$(echo "$MODEL_LIST" | tail -n +2 | grep -c .)
        echo -e "${GRAY}  Total: $MODEL_COUNT model(s)${NC}"
        echo ""
        echo -e "${GRAY}$MODEL_LIST${NC}"
    else
        echo -e "${GRAY}  No models downloaded${NC}"
    fi
    
    echo ""
    
    # Test Commands
    echo -e "${CYAN}Test Commands:${NC}"
    echo -e "${GRAY}  curl http://localhost:$HTTP_PORT/api/version${NC}"
    echo -e "${GRAY}  curl http://localhost:$HTTP_PORT/api/tags${NC}"
    echo ""
}

# Show logs
show_logs() {
    echo -e "${CYAN}Ollama Service Logs (last $LINES lines)${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    
    if [ "$FOLLOW" = true ]; then
        echo -e "${GRAY}Following logs (Ctrl+C to exit)...${NC}"
        echo ""
        docker-compose logs ollama --tail $LINES --follow
    else
        docker-compose logs ollama --tail $LINES
    fi
}

# List models
show_models() {
    echo -e "${CYAN}Downloaded Models${NC}"
    echo -e "${CYAN}=================${NC}"
    echo ""
    
    MODEL_LIST=$(docker exec ollama ollama list 2>/dev/null)
    if [ -n "$MODEL_LIST" ]; then
        echo -e "${GRAY}$MODEL_LIST${NC}"
        echo ""
        echo -e "${CYAN}Commands:${NC}"
        echo -e "${GRAY}  Pull model:   ./manage-ollama.sh pull --model-name <name>${NC}"
        echo -e "${GRAY}  Remove model: ./manage-ollama.sh remove-model --model-name <name>${NC}"
        echo -e "${GRAY}  Test model:   docker exec ollama ollama run <name> \"test prompt\"${NC}"
    else
        echo -e "${GRAY}No models downloaded yet${NC}"
        echo ""
        echo -e "${CYAN}Download models using: ./management/pull-models.sh${NC}"
    fi
    
    echo ""
}

# Pull model
pull_model() {
    if [ -z "$MODEL_NAME" ]; then
        echo -e "${RED}✗ Model name is required${NC}"
        echo -e "${YELLOW}Usage: ./manage-ollama.sh pull --model-name llama3.2:3b${NC}"
        return 1
    fi
    
    echo -e "${CYAN}Pulling model: $MODEL_NAME${NC}"
    echo -e "${GRAY}This may take several minutes...${NC}"
    echo ""
    
    if docker exec ollama ollama pull "$MODEL_NAME"; then
        echo ""
        echo -e "${GREEN}✓ Model pulled successfully: $MODEL_NAME${NC}"
    else
        echo ""
        echo -e "${RED}✗ Failed to pull model: $MODEL_NAME${NC}"
        return 1
    fi
}

# Remove model
remove_model() {
    if [ -z "$MODEL_NAME" ]; then
        echo -e "${RED}✗ Model name is required${NC}"
        echo -e "${YELLOW}Usage: ./manage-ollama.sh remove-model --model-name llama3.1:70b${NC}"
        return 1
    fi
    
    # Check if model exists
    MODEL_LIST=$(docker exec ollama ollama list 2>/dev/null)
    if ! echo "$MODEL_LIST" | grep -q "$MODEL_NAME"; then
        echo -e "${RED}✗ Model not found: $MODEL_NAME${NC}"
        return 1
    fi
    
    if [ "$FORCE" = false ]; then
        read -p "Remove model '$MODEL_NAME'? (y/n): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Model removal cancelled${NC}"
            return 0
        fi
    fi
    
    echo -e "${GRAY}Removing model: $MODEL_NAME${NC}"
    
    if docker exec ollama ollama rm "$MODEL_NAME" 2>&1 > /dev/null; then
        echo -e "${GREEN}✓ Model removed successfully: $MODEL_NAME${NC}"
    else
        echo -e "${RED}✗ Failed to remove model: $MODEL_NAME${NC}"
        return 1
    fi
}

# Update Ollama
update_ollama() {
    echo -e "${GRAY}Updating Ollama Docker image...${NC}"
    echo ""
    
    echo -e "${GRAY}Pulling latest Ollama image...${NC}"
    docker-compose pull ollama
    
    echo ""
    echo -e "${GRAY}Recreating container with new image...${NC}"
    docker-compose up -d ollama
    
    sleep 3
    
    echo ""
    echo -e "${GREEN}✓ Ollama updated successfully${NC}"
    echo ""
    
    # Display version
    VERSION=$(docker exec ollama ollama --version 2>/dev/null)
    if [ -n "$VERSION" ]; then
        echo -e "${GRAY}Current version: $VERSION${NC}"
    else
        echo -e "${GRAY}Could not retrieve version${NC}"
    fi
}

# Show stats
show_stats() {
    echo -e "${CYAN}Ollama Resource Usage${NC}"
    echo -e "${CYAN}=====================${NC}"
    echo ""
    
    echo -e "${CYAN}Container Statistics:${NC}"
    docker stats ollama --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"
    
    echo ""
    
    # Show GPU stats if available
    if command -v nvidia-smi &> /dev/null; then
        if nvidia-smi --query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader 2>/dev/null; then
            echo ""
            echo -e "${CYAN}GPU Statistics:${NC}"
            nvidia-smi --query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader
        fi
    fi
    
    echo ""
}

# Main script logic
if ! check_docker; then
    exit 1
fi

case $ACTION in
    start)
        start_service
        ;;
    
    stop)
        stop_service
        ;;
    
    restart)
        restart_service
        ;;
    
    status)
        show_status
        ;;
    
    logs)
        show_logs
        ;;
    
    models)
        show_models
        ;;
    
    pull)
        pull_model
        ;;
    
    remove-model)
        remove_model
        ;;
    
    update)
        update_ollama
        ;;
    
    stats)
        show_stats
        ;;
    
    *)
        echo -e "${RED}Unknown action: $ACTION${NC}"
        exit 1
        ;;
esac

echo -e "${CYAN}==================================================================${NC}"
