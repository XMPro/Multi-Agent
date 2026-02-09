# TimescaleDB Fix and Grafana LGTM Integration Plan

## Overview

This plan addresses two objectives:
1. Fix TimescaleDB deployment to match the working pattern of MQTT, Milvus, and Neo4j
2. Add Grafana LGTM (Loki, Grafana, Tempo, Mimir) as an optional observability service

## Part 1: TimescaleDB Fixes

### Priority 1: Core Functionality (Required for Basic Operation)

#### 1.1 Create Missing init Directory and SQL File

**File to Create:** `docs/installation/docker/src/timescaledb/init/01-init-timescaledb.sql`

**Content:** (Already defined in install.ps1 lines 411-437)
```sql
-- =================================================================
-- TimescaleDB Initialization Script
-- =================================================================

-- Create TimescaleDB extension
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- Enable additional useful extensions
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Create a sample schema for time-series data
CREATE SCHEMA IF NOT EXISTS timeseries;

-- Set default privileges
GRANT USAGE ON SCHEMA timeseries TO PUBLIC;
GRANT CREATE ON SCHEMA timeseries TO postgres;

-- Log successful initialization
DO $$
BEGIN
    RAISE NOTICE 'TimescaleDB initialized successfully';
    RAISE NOTICE 'Version: %', (SELECT extversion FROM pg_extension WHERE extname = 'timescaledb');
END
$$;
```

**Why:** Docker expects this file at mount point `./init:/docker-entrypoint-initdb.d:ro` to initialize TimescaleDB extension on first startup.

#### 1.2 Test Basic Deployment Without SSL

**Actions:**
- Run install.ps1 without SSL flag
- Verify containers start: timescaledb, pgadmin, backup
- Test PostgreSQL connection on port 5432
- Test pgAdmin access on port 5050
- Verify backup container cron is working

**Validation:**
```powershell
# Check containers
docker-compose ps

# Test PostgreSQL connection
docker exec timescaledb psql -U postgres -d timescaledb -c "SELECT extversion FROM pg_extension WHERE extname = 'timescaledb';"

# Check backup logs
docker-compose logs backup
```

### Priority 2: SSL Support (Required for Production)

#### 2.1 Add pgAdmin Nginx Reverse Proxy Container

**File to Modify:** `docs/installation/docker/src/timescaledb/docker-compose.yml`

**Add New Service After pgadmin Service:**
```yaml
  pgadmin-nginx:
    image: nginx:alpine
    container_name: timescaledb-pgadmin-nginx
    restart: unless-stopped
    ports:
      - "${PGADMIN_PORT:-5050}:80"
      - "${PGADMIN_HTTPS_PORT:-5051}:443"
    volumes:
      - ./pgadmin/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./certs:/etc/nginx/ssl:ro
    depends_on:
      - pgadmin
    networks:
      - timescaledb_network
    healthcheck:
      test: ["CMD", "wget", "-O", "-", "http://localhost:80/misc/ping"]
      interval: 30s
      timeout: 10s
      retries: 3
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

**Why:** Provides SSL termination for pgAdmin, matching the pattern used by Milvus attu-nginx service.

#### 2.2 Modify pgAdmin Service Configuration

**File to Modify:** `docs/installation/docker/src/timescaledb/docker-compose.yml`

**Changes to pgadmin service:**
```yaml
  pgadmin:
    image: dpage/pgadmin4:latest
    container_name: timescaledb-pgadmin
    restart: unless-stopped
    environment:
      PGADMIN_DEFAULT_EMAIL: ${PGADMIN_EMAIL:-admin@example.com}
      PGADMIN_DEFAULT_PASSWORD: ${PGADMIN_PASSWORD:?pgAdmin password must be set}
      PGADMIN_CONFIG_SERVER_MODE: 'False'
      PGADMIN_CONFIG_MASTER_PASSWORD_REQUIRED: 'False'
      # Remove PGADMIN_ENABLE_TLS - nginx handles SSL
    volumes:
      - ./timescaledb-data/pgadmin:/var/lib/pgadmin
      - ./pgadmin/servers.json:/pgadmin4/servers.json:ro
      - ./certs/server.crt:/certs/server.cert:ro
      - ./certs/server.key:/certs/server.key:ro
      - ./pgadmin-entrypoint.sh:/pgadmin-entrypoint.sh:ro
    # Remove direct port exposure - nginx handles it
    entrypoint: ["/bin/sh", "/pgadmin-entrypoint.sh"]
    depends_on:
      - timescaledb
    networks:
      - timescaledb_network
    healthcheck:
      test: ["CMD", "wget", "-O", "-", "http://localhost:80/misc/ping"]
      interval: 30s
      timeout: 10s
      retries: 3
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

**Why:** Removes direct port exposure and SSL configuration from pgAdmin, delegating to nginx container.

#### 2.3 Update nginx.conf Template in install.ps1

**File to Modify:** `docs/installation/docker/src/timescaledb/management/install.ps1`

**No changes needed** - The nginx.conf generation (lines 288-366) is already correct and matches the pattern.

#### 2.4 Test SSL Deployment

**Actions:**
- Run install.ps1 with -EnableSSL flag
- Verify SSL certificates generated in certs directory
- Test HTTPS access to pgAdmin on port 5051
- Verify HTTP redirect from port 5050 to 5051
- Test PostgreSQL SSL connection with sslmode=require

**Validation:**
```powershell
# Check SSL certificates
ls certs/

# Test HTTPS access
curl -k https://localhost:5051

# Test PostgreSQL SSL
psql "postgresql://postgres:password@localhost:5432/timescaledb?sslmode=require"
```

### Priority 3: Completeness (Required for Cross-Platform Support)

#### 3.1 Create Linux Installation Script

**File to Create:** `docs/installation/docker/src/timescaledb/management/install.sh`

**Actions:**
- Port install.ps1 logic to bash
- Follow pattern from mqtt/management/install.sh and neo4j/management/install.sh
- Ensure feature parity with PowerShell version
- Test on Linux/macOS

**Key Sections:**
- Docker availability check
- Directory structure creation
- SSL certificate generation using alpine/openssl
- Configuration file generation
- Interactive prompts for passwords and SSL options
- Container startup and health checks

#### 3.2 Create Linux SSL Management Script

**File to Create:** `docs/installation/docker/src/timescaledb/management/manage-ssl.sh`

**Actions:**
- Port manage-ssl.ps1 logic to bash
- Follow pattern from mqtt/management/manage-ssl.sh and neo4j/management/manage-ssl.sh
- Support enable/disable/regenerate operations
- Test certificate installation and rotation

#### 3.3 Add TimescaleDB to Stack Installer

**Files to Modify:**
- `docs/installation/docker/windows/management/docker-stack-installer.ps1`
- `docs/installation/docker/linux/management/docker-stack-installer.sh`

**Changes:**
- Add TimescaleDB to service selection menu
- Add TimescaleDB installation logic
- Update service count and completion messages

#### 3.4 Add TimescaleDB to Offline Package

**Files to Modify:**
- `docs/installation/docker/windows/prepare-stack.ps1`
- `docs/installation/docker/linux/prepare-stack.sh`

**Changes:**
- Add TimescaleDB images to download list:
  - `timescale/timescaledb:latest-pg16`
  - `dpage/pgadmin4:latest`
  - `postgres:16-alpine` (for backup container)
  - `nginx:alpine` (for pgadmin-nginx)
- Add fallback versions for each image
- Include TimescaleDB directory in service zip
- Update offline instructions

---

## Part 2: Grafana LGTM Integration

### Overview

Add Grafana LGTM (Loki, Grafana, Tempo, Mimir) as an optional observability service for OpenTelemetry data collection, metrics, logs, and traces.

### 2.1 Create Grafana LGTM Directory Structure

**Directory to Create:** `docs/installation/docker/src/grafana-lgtm/`

**Structure:**
```
grafana-lgtm/
├── docker-compose.yml
├── grafana_lgtm_readme.md
├── .env.example
├── config/
│   └── otel-collector-config.yaml (if custom config needed)
├── data/
│   └── .gitkeep (for persistent data)
├── certs/
│   └── .gitkeep (for SSL certificates)
└── management/
    ├── install.ps1
    ├── install.sh
    ├── manage-ssl.ps1
    └── manage-ssl.sh
```

### 2.2 Create Docker Compose Configuration

**File to Create:** `docs/installation/docker/src/grafana-lgtm/docker-compose.yml`

**Content:**
```yaml
services:
  grafana-lgtm:
    image: grafana/otel-lgtm:latest
    container_name: grafana-lgtm
    restart: unless-stopped
    ports:
      # Grafana UI
      - "${GRAFANA_PORT:-3000}:3000"
      # OpenTelemetry OTLP gRPC
      - "${OTEL_GRPC_PORT:-4317}:4317"
      # OpenTelemetry OTLP HTTP
      - "${OTEL_HTTP_PORT:-4318}:4318"
    volumes:
      # Persist data across container restarts
      - ./data:/data
      # Custom OTel Collector config (optional)
      - ./config/otel-collector-config.yaml:/otel-lgtm/otelcol-config.yaml:ro
    environment:
      # Logging configuration
      - ENABLE_LOGS_GRAFANA=${ENABLE_LOGS_GRAFANA:-false}
      - ENABLE_LOGS_LOKI=${ENABLE_LOGS_LOKI:-false}
      - ENABLE_LOGS_PROMETHEUS=${ENABLE_LOGS_PROMETHEUS:-false}
      - ENABLE_LOGS_TEMPO=${ENABLE_LOGS_TEMPO:-false}
      - ENABLE_LOGS_PYROSCOPE=${ENABLE_LOGS_PYROSCOPE:-false}
      - ENABLE_LOGS_OTELCOL=${ENABLE_LOGS_OTELCOL:-false}
      - ENABLE_LOGS_ALL=${ENABLE_LOGS_ALL:-false}
      
      # Grafana Cloud integration (optional)
      - GC_PROMETHEUS_URL=${GC_PROMETHEUS_URL:-}
      - GC_PROMETHEUS_USERNAME=${GC_PROMETHEUS_USERNAME:-}
      - GC_PROMETHEUS_PASSWORD=${GC_PROMETHEUS_PASSWORD:-}
      - GC_LOKI_URL=${GC_LOKI_URL:-}
      - GC_LOKI_USERNAME=${GC_LOKI_USERNAME:-}
      - GC_LOKI_PASSWORD=${GC_LOKI_PASSWORD:-}
      - GC_TEMPO_URL=${GC_TEMPO_URL:-}
      - GC_TEMPO_USERNAME=${GC_TEMPO_USERNAME:-}
      - GC_TEMPO_PASSWORD=${GC_TEMPO_PASSWORD:-}
      
      # Timezone
      - TZ=${TZ:-UTC}
    healthcheck:
      test: ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:3000/api/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    networks:
      - grafana-lgtm-network
    logging:
      driver: "json-file"
      options:
        max-size: "100m"
        max-file: "3"

  # Optional: nginx reverse proxy for SSL termination
  grafana-nginx:
    image: nginx:alpine
    container_name: grafana-lgtm-nginx
    restart: unless-stopped
    ports:
      - "${GRAFANA_HTTP_PORT:-3080}:80"
      - "${GRAFANA_HTTPS_PORT:-3443}:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./certs:/etc/nginx/ssl:ro
    depends_on:
      - grafana-lgtm
    networks:
      - grafana-lgtm-network
    healthcheck:
      test: ["CMD", "wget", "-O", "-", "http://localhost:80/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    profiles:
      - ssl

networks:
  grafana-lgtm-network:
    driver: bridge
    name: grafana-lgtm-network
```

**Key Features:**
- Uses official grafana/otel-lgtm image
- Exposes standard OpenTelemetry ports (4317 gRPC, 4318 HTTP)
- Grafana UI on port 3000 (configurable)
- Persistent data volume at /data
- Optional nginx for SSL (using Docker Compose profiles)
- Grafana Cloud integration support
- Configurable logging for all components

### 2.3 Create Installation Script (PowerShell)

**File to Create:** `docs/installation/docker/src/grafana-lgtm/management/install.ps1`

**Key Features:**
- Check Docker availability
- Create directory structure (data, config, certs)
- Interactive prompts for:
  - Enable SSL (yes/no)
  - Enable component logging (yes/no)
  - Grafana Cloud integration (optional)
  - Custom ports
- Generate .env file with configuration
- Generate nginx.conf if SSL enabled
- Generate SSL certificates using alpine/openssl
- Start containers with appropriate profile (with/without SSL)
- Display access information and credentials

**Default Credentials:**
- Grafana UI: admin/admin (user prompted to change on first login)

### 2.4 Create Installation Script (Bash)

**File to Create:** `docs/installation/docker/src/grafana-lgtm/management/install.sh`

**Features:** Same as PowerShell version, ported to bash

### 2.5 Create SSL Management Scripts

**Files to Create:**
- `docs/installation/docker/src/grafana-lgtm/management/manage-ssl.ps1`
- `docs/installation/docker/src/grafana-lgtm/management/manage-ssl.sh`

**Features:**
- Enable SSL (generate certificates, update nginx.conf, restart with ssl profile)
- Disable SSL (stop nginx, restart without ssl profile)
- Regenerate certificates
- Install CA-provided certificates

### 2.6 Create README Documentation

**File to Create:** `docs/installation/docker/src/grafana-lgtm/grafana_lgtm_readme.md`

**Sections:**
- Overview of Grafana LGTM
- Architecture diagram (Collector → Loki/Tempo/Mimir → Grafana)
- Quick start installation
- Configuration options
- OpenTelemetry integration guide
- Accessing Grafana UI
- Sending telemetry data (traces, metrics, logs)
- Grafana Cloud integration
- SSL/TLS configuration
- Data persistence and backup
- Troubleshooting
- Example application instrumentation

### 2.7 Create nginx Configuration Template

**File to Create:** `docs/installation/docker/src/grafana-lgtm/nginx.conf.template`

**Content:**
```nginx
events {
    worker_connections 1024;
}

http {
    upstream grafana {
        server grafana-lgtm:3000;
    }

    # Redirect HTTP to HTTPS
    server {
        listen 80;
        server_name {{DOMAIN}};
        return 301 https://$host$request_uri;
    }

    # HTTPS server
    server {
        listen 443 ssl;
        server_name {{DOMAIN}};

        ssl_certificate /etc/nginx/ssl/server.crt;
        ssl_certificate_key /etc/nginx/ssl/server.key;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers HIGH:!aNULL:!MD5;
        ssl_prefer_server_ciphers on;

        location / {
            proxy_pass http://grafana;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
        }
    }
}
```

### 2.8 Integration with Existing Services

#### 2.8.1 Add to Stack Installer

**Files to Modify:**
- `docs/installation/docker/windows/management/docker-stack-installer.ps1`
- `docs/installation/docker/linux/management/docker-stack-installer.sh`

**Changes:**
- Add "Grafana LGTM (Observability)" to service selection menu
- Add installation logic
- Display OpenTelemetry endpoint information after installation

#### 2.8.2 Add to Offline Package

**Files to Modify:**
- `docs/installation/docker/windows/prepare-stack.ps1`
- `docs/installation/docker/linux/prepare-stack.sh`

**Changes:**
- Add Grafana LGTM images to download list:
  - `grafana/otel-lgtm:latest`
  - `nginx:alpine` (if not already included)
- Add fallback versions
- Include grafana-lgtm directory in service zip

#### 2.8.3 Update Complete Deployment Flowchart

**File to Modify:** `docs/installation/docker/complete-deployment-flowchart.md`

**Changes:**
- Add Grafana LGTM to main deployment decision flow
- Add Grafana LGTM installation process flowchart
- Add to service architecture overview
- Update deployment summary

### 2.9 OpenTelemetry Integration Examples

**File to Create:** `docs/installation/docker/src/grafana-lgtm/examples/README.md`

**Content:**
- Example code snippets for instrumenting applications
- Environment variables for OTLP endpoints
- Language-specific examples (Python, Java, Go, .NET, Node.js)
- Testing with curl/grpcurl
- Viewing data in Grafana

**Example Environment Variables:**
```bash
export OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318
export OTEL_SERVICE_NAME=my-service
```

### 2.10 Testing and Validation

**Actions:**
- Test installation without SSL
- Test installation with SSL
- Send sample OpenTelemetry data (traces, metrics, logs)
- Verify data appears in Grafana
- Test Grafana Cloud integration (optional)
- Test data persistence across container restarts
- Test backup and restore procedures
- Validate on Windows and Linux

---

## Implementation Order

### Phase 1: TimescaleDB Core Fixes
1. Create init directory and SQL file
2. Test basic deployment without SSL
3. Add pgadmin-nginx service to docker-compose.yml
4. Modify pgadmin service configuration
5. Test SSL deployment

### Phase 2: TimescaleDB Cross-Platform Support
6. Create install.sh for Linux
7. Create manage-ssl.sh for Linux
8. Add to stack installer scripts
9. Add to offline package preparation
10. Test on Windows and Linux

### Phase 3: Grafana LGTM Foundation
11. Create directory structure
12. Create docker-compose.yml
13. Create install.ps1 (Windows)
14. Create install.sh (Linux)
15. Create README documentation

### Phase 4: Grafana LGTM SSL and Management
16. Create nginx.conf template
17. Create manage-ssl.ps1 and manage-ssl.sh
18. Test SSL deployment
19. Create OpenTelemetry integration examples

### Phase 5: Integration and Documentation
20. Add Grafana LGTM to stack installer
21. Add Grafana LGTM to offline package
22. Update complete deployment flowchart
23. Create integration testing suite
24. Final validation on Windows and Linux

---

## Success Criteria

### TimescaleDB
- [ ] TimescaleDB container starts successfully
- [ ] TimescaleDB extension is initialized
- [ ] pgAdmin accessible via HTTP (port 5050)
- [ ] pgAdmin accessible via HTTPS (port 5051) when SSL enabled
- [ ] PostgreSQL connections work with and without SSL
- [ ] Automated backups run successfully
- [ ] Installation works on Windows and Linux
- [ ] Included in stack installer and offline package

### Grafana LGTM
- [ ] Grafana LGTM container starts successfully
- [ ] Grafana UI accessible (default: port 3000)
- [ ] OpenTelemetry endpoints accepting data (ports 4317, 4318)
- [ ] Sample telemetry data visible in Grafana
- [ ] SSL termination works via nginx
- [ ] Data persists across container restarts
- [ ] Installation works on Windows and Linux
- [ ] Included in stack installer and offline package
- [ ] Integration examples work correctly

---

## Notes

### TimescaleDB
- The install.ps1 script is already well-written and follows the pattern of working services
- Main issue is missing init directory and nginx container for pgAdmin SSL
- Once fixed, TimescaleDB will be on par with other services

### Grafana LGTM
- Grafana LGTM is a single Docker image containing multiple components
- Simpler deployment than Milvus (which requires etcd, minio, standalone)
- OpenTelemetry is the standard for observability in modern applications
- Provides immediate value for monitoring the multi-agent system
- Can integrate with existing services (Neo4j, MQTT, Milvus, TimescaleDB) for comprehensive observability

### Security Considerations
- All services should use SSL in production
- Default passwords should be changed immediately
- Consider network isolation between services
- Implement proper firewall rules
- Regular security updates for all images

### Performance Considerations
- Grafana LGTM can be resource-intensive (contains Loki, Tempo, Mimir, Grafana)
- Consider resource limits in docker-compose.yml
- Monitor disk usage for /data directory (logs and traces can grow quickly)
- Implement data retention policies
- Consider separate deployment for production vs development

---

## Related Documentation

- [TimescaleDB Documentation](https://docs.timescale.com/)
- [Grafana LGTM Documentation](https://grafana.com/docs/opentelemetry/docker-lgtm/)
- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Nginx Documentation](https://nginx.org/en/docs/)
