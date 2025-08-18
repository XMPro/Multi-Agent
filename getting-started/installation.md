---
layout: default
title: "Installation"
description: "Step-by-step guide to install and configure MAGS for your environment"
category: "getting-started"
---

# Installation Guide

This guide will walk you through the process of installing Multi-Agent Generative Systems (MAGS) in your environment.

## Prerequisites

Before installing MAGS, ensure your system meets the following requirements:

- **Operating System**: Windows 10/11, macOS 10.15+, or Linux (Ubuntu 20.04+ recommended)
- **Memory**: Minimum 16GB RAM (32GB recommended)
- **Storage**: 50GB available disk space
- **CPU**: 4+ cores (8+ recommended)
- **GPU**: Optional but recommended for larger deployments
- **Docker**: Docker Desktop 4.0+ or Docker Engine 20.10+
- **Database**: PostgreSQL 13+ or MongoDB 5.0+
- **Vector Database**: Pinecone, Weaviate, or Milvus
- **Node.js**: v16+ (for web interface)

## Installation Options

MAGS can be installed using one of the following methods:

### Option 1: Docker Compose (Recommended)

1. Clone the repository:
   ```bash
   git clone https://github.com/xmpro/multi-agent.git
   cd multi-agent
   ```

2. Configure environment variables:
   ```bash
   cp .env.example .env
   # Edit .env file with your configuration
   ```

3. Start the services:
   ```bash
   docker-compose up -d
   ```

4. Verify installation:
   ```bash
   curl http://localhost:8080/health
   ```

### Option 2: Kubernetes

1. Clone the repository:
   ```bash
   git clone https://github.com/xmpro/multi-agent.git
   cd multi-agent/kubernetes
   ```

2. Configure Kubernetes manifests:
   ```bash
   # Edit configuration files in kubernetes/config
   ```

3. Deploy to Kubernetes:
   ```bash
   kubectl apply -f kubernetes/
   ```

4. Verify deployment:
   ```bash
   kubectl get pods -n mags
   ```

### Option 3: Manual Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/xmpro/multi-agent.git
   cd multi-agent
   ```

2. Install dependencies:
   ```bash
   # Backend
   cd backend
   pip install -r requirements.txt
   
   # Frontend
   cd ../frontend
   npm install
   ```

3. Configure the system:
   ```bash
   cp config.example.json config.json
   # Edit config.json with your settings
   ```

4. Start the services:
   ```bash
   # Backend
   cd backend
   python app.py
   
   # Frontend (in a new terminal)
   cd frontend
   npm start
   ```

## Post-Installation Steps

After installing MAGS, complete the following steps:

1. **Create admin account**:
   ```bash
   curl -X POST http://localhost:8080/api/admin/setup \
     -H "Content-Type: application/json" \
     -d '{"username":"admin","password":"your-secure-password"}'
   ```

2. **Configure database connections**:
   - Log in to the admin dashboard at `http://localhost:8080/admin`
   - Navigate to "Settings" > "Database Connections"
   - Configure your PostgreSQL and vector database connections

3. **Set up API keys**:
   - Navigate to "Settings" > "API Keys"
   - Add your LLM provider API keys (OpenAI, Anthropic, etc.)

4. **Initialize the system**:
   - Navigate to "System" > "Initialization"
   - Click "Initialize System" to set up required database schemas

## Troubleshooting

If you encounter issues during installation:

- **Check logs**:
  ```bash
  docker-compose logs -f
  ```

- **Verify network connectivity**:
  ```bash
  curl http://localhost:8080/health
  ```

- **Check database connection**:
  ```bash
  docker-compose exec postgres psql -U postgres -c "SELECT 1"
  ```

- **Restart services**:
  ```bash
  docker-compose restart
  ```

## Next Steps

Once MAGS is installed and running:

1. [Configure your environment]({{ '/getting-started/configuration' | relative_url }})
2. [Create your first agent]({{ '/getting-started/first-steps' | relative_url }})
3. [Explore advanced features]({{ '/getting-started/advanced-usage' | relative_url }})
