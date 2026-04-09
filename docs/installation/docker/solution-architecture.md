# XMPro MAGS - Solution Architecture (On-Premise)

This document describes the complete on-premise deployment architecture from a solution architect's perspective: what components exist, how they interact, and the role each plays in the XMPro Multi-Agent Generative System.

## End-to-End Architecture

The on-premise deployment consists of three layers: the **XMPro Application Platform** (IIS/Windows Server), the **MAGS Cognitive Engine** (which runs inside Data Streams on Stream Hosts, with its UI in XMPro AI), and the **Infrastructure Services** (Docker containers). Together they form an industrial-grade multi-agent system.

```mermaid
graph TB
    subgraph USERS["Users & External Systems"]
        ENG["Engineers /<br/>Operators"]
        SCADA["SCADA / Historians /<br/>OPC UA / DDS"]
        ERP["ERP / MES /<br/>Enterprise Systems"]
    end

    subgraph XMPRO["XMPro Application Platform <i>(IIS / Windows Server)</i>"]
        SM["Subscription Manager<br/><i>Identity, Licensing, Access Control</i><br/>:5201"]
        AD["App Designer<br/><i>Real-Time Dashboards & Apps</i><br/>:5202"]
        DS["Data Stream Designer<br/><i>Data Pipeline Orchestration</i><br/>:5203"]
        XAI["XMPro AI<br/><i>Agent Management, Conversations,<br/>MAGS UI</i>"]
        SH["Stream Host(s)<br/><i>Data Stream Execution Engine</i><br/>Windows Service / Docker"]
        SQL["SQL Server 2022<br/><i>SM, AD, DS Databases</i><br/>:1433"]
    end

    subgraph MAGS["MAGS Cognitive Engine <i>(runs in Data Streams on Stream Hosts)</i>"]
        ORPA["ORPA Cycle<br/><i>Observe - Reflect - Plan - Act</i>"]
        MEM["Memory Systems<br/><i>Short-term, Long-term,<br/>Episodic, Semantic</i>"]
        PLAN["Planning Engine<br/><i>PDDL-based Planning<br/>& Adaptation</i>"]
        GOV["Governance Framework<br/><i>Deontic Rules, Constraints,<br/>Bounded Autonomy</i>"]
        OBJ["Objective Functions<br/><i>KPI Optimization<br/>per Agent & Team</i>"]
    end

    subgraph DOCKER["Infrastructure Services <i>(Docker Host)</i>"]

        subgraph DATA["Data Tier"]
            NEO4J["Neo4j<br/><i>Graph Database</i><br/>Knowledge &<br/>Relationships"]
            TSDB["TimescaleDB<br/><i>Time-Series Database</i><br/>Sensor Data &<br/>Metrics"]
            MILVUS["Milvus<br/><i>Vector Database</i><br/>Embeddings &<br/>Similarity"]
        end

        subgraph MSG["Messaging Tier"]
            MQTT["Eclipse Mosquitto<br/><i>MQTT Broker</i><br/>Agent-to-Agent<br/>Communication"]
        end

        subgraph AI["AI Inference Tier"]
            OLLAMA["Ollama<br/><i>Local LLM Runtime</i><br/>Inference &<br/>Embeddings"]
        end

        subgraph OBS["Observability Tier"]
            OTEL["OTEL LGTM Stack<br/><i>Grafana + Loki + Tempo<br/>+ Mimir + Prometheus</i>"]
        end
    end

    ENG -->|"Browser"| AD
    ENG -->|"Browser"| DS
    ENG -->|"Browser"| XAI
    SCADA -->|"OPC UA / MQTT / DDS"| SH
    ERP -->|"REST / SQL"| SH

    SM --- AD & DS & XAI
    DS --> SH
    XAI -->|"Agent config,<br/>conversations,<br/>monitoring"| MAGS
    SH -->|"Executes MAGS<br/>as Data Streams"| MAGS

    ORPA --> MEM & PLAN & GOV & OBJ

    MAGS -->|"Bolt :7687<br/>Structural memory"| NEO4J
    MAGS -->|"gRPC :19530<br/>Semantic memory"| MILVUS
    MAGS -->|"SQL :5432<br/>Episodic memory"| TSDB
    MAGS -->|"MQTT :1883<br/>Agent messaging"| MQTT
    MAGS -->|"HTTP :11434<br/>LLM reasoning"| OLLAMA
    MAGS -->|"OTLP :4317<br/>Telemetry"| OTEL

    OTEL -.->|"scrapes metrics"| NEO4J & TSDB & MILVUS & MQTT

    classDef xmpro fill:#e8eaf6,stroke:#283593,color:#1a237e
    classDef mags fill:#fff8e1,stroke:#f57f17,color:#e65100
    classDef dataTier fill:#e3f2fd,stroke:#1565c0,color:#0d47a1
    classDef msgTier fill:#fce4ec,stroke:#c62828,color:#b71c1c
    classDef aiTier fill:#f3e5f5,stroke:#6a1b9a,color:#4a148c
    classDef obsTier fill:#fff3e0,stroke:#e65100,color:#bf360c
    classDef external fill:#e8f5e9,stroke:#2e7d32,color:#1b5e20

    class SM,AD,DS,XAI,SH,SQL xmpro
    class ORPA,MEM,PLAN,GOV,OBJ mags
    class NEO4J,TSDB,MILVUS dataTier
    class MQTT msgTier
    class OLLAMA aiTier
    class OTEL obsTier
    class ENG,SCADA,ERP external
```

## XMPro Application Platform

The XMPro platform provides the operational front-end, data pipeline orchestration, and identity management. It is deployed on **Windows Server 2022** using **IIS** with a **SQL Server 2022** backend.

### Platform Components

```mermaid
graph LR
    subgraph IIS["IIS Web Server <i>(Windows Server 2022)</i>"]
        SM["Subscription Manager<br/><b>:5201</b><br/>Identity & Licensing"]
        AD["App Designer<br/><b>:5202</b><br/>Dashboards & Apps"]
        DS["Data Stream Designer<br/><b>:5203</b><br/>Pipeline Design"]
        XAI["XMPro AI<br/><i>MAGS UI & Agent<br/>Management</i>"]
    end

    subgraph EXEC["Execution"]
        SH1["Stream Host<br/><i>Windows Service</i>"]
        SH2["Stream Host<br/><i>Docker Container</i>"]
        SHN["Stream Host<br/><i>Edge Device</i>"]
    end

    subgraph DB["SQL Server 2022"]
        DB_SM["SM Database<br/><i>Identity, licensing</i>"]
        DB_AD["AD Database<br/><i>Apps, pages</i>"]
        DB_DS["DS Database<br/><i>Streams, agents</i>"]
    end

    SM -->|"Auth tokens"| AD & DS & XAI
    DS -->|"Stream configs"| SH1 & SH2 & SHN
    XAI -->|"MAGS agent config"| DS
    SM --- DB_SM
    AD --- DB_AD
    DS --- DB_DS

    classDef iis fill:#e8eaf6,stroke:#283593
    classDef exec fill:#e0f2f1,stroke:#00695c
    classDef db fill:#fce4ec,stroke:#c62828

    class SM,AD,DS,XAI iis
    class SH1,SH2,SHN exec
    class DB_SM,DB_AD,DB_DS db
```

| Component | Port | Role | Depends On |
|-----------|------|------|------------|
| **Subscription Manager** | 5201 | Central identity, licensing, and access control hub. Must be installed first. | SQL Server |
| **App Designer** | 5202 | Visual drag-and-drop builder for real-time operational dashboards and applications. No coding required. | SM |
| **Data Stream Designer** | 5203 | Visual designer for streaming data pipelines. Connects industrial data sources to agents and applications. | SM |
| **Stream Host** | - | Execution engine that runs Data Streams -- including MAGS cognitive agents. Deployed as Windows Service, Docker container, or console app. Can run at the edge. | DS |
| **XMPro AI** | - | MAGS front-end: agent team configuration, agent conversations, monitoring, and management. The UI layer for interacting with cognitive agents. | SM |
| **SQL Server 2022** | 1433 | Stores platform metadata: identity, app definitions, stream configurations. Each component gets its own database. | - |

**Prerequisites:** Windows Server 2022, IIS 10+, .NET 8 Hosting Bundle, ASP.NET 4.8, SQL Server 2022 (mixed-mode auth), JWT signing certificate (.pfx, 4096-bit RSA), SSL certificates for HTTPS.

### Stream Host & Collections

Stream Hosts are the bridge between the XMPro platform and the physical/digital world. They execute Data Streams -- including MAGS cognitive agents -- that ingest data from SCADA, historians, IoT devices, and enterprise systems.

```mermaid
graph TB
    subgraph "Collection: Plant Floor"
        subgraph SH1["Stream Host 1 <i>(Windows Service)</i>"]
            DS1["Data Stream:<br/>Sensor Ingestion"]
            MAGS1["Data Stream:<br/>MAGS Predictive<br/>Maintenance Team"]
        end
        subgraph SH2["Stream Host 2 <i>(Windows Service)</i>"]
            DS2["Data Stream:<br/>Historian Sync"]
            MAGS2["Data Stream:<br/>MAGS Quality<br/>Control Team"]
        end
    end

    subgraph "Collection: Edge Devices"
        subgraph SH3["Stream Host 3 <i>(Docker on Edge)</i>"]
            DS3["Data Stream:<br/>Edge Pre-processing"]
        end
    end

    subgraph "Data Sources"
        OPC["OPC UA Server"]
        HIST["OSIsoft PI / Historian"]
        PLC["PLC / SCADA"]
    end

    subgraph "MAGS UI"
        XAI["XMPro AI<br/><i>Agent conversations,<br/>team config, monitoring</i>"]
    end

    OPC & HIST & PLC --> SH1 & SH2 & SH3

    MAGS1 & MAGS2 -->|"Agent messaging"| MQTT["MQTT Broker"]
    SH3 -->|"MQTT cross-collection"| MQTT
    MAGS1 & MAGS2 -->|"Memory read/write"| INFRA["Neo4j / Milvus /<br/>TimescaleDB"]
    MAGS1 & MAGS2 -->|"LLM calls"| OLLAMA["Ollama"]
    XAI -.->|"Manages"| MAGS1 & MAGS2

    classDef sh fill:#e0f2f1,stroke:#00695c
    classDef mags fill:#fff8e1,stroke:#f57f17
    classDef src fill:#f5f5f5,stroke:#616161
    classDef ui fill:#e8eaf6,stroke:#283593

    class DS1,DS2,DS3 sh
    class MAGS1,MAGS2 mags
    class OPC,HIST,PLC src
    class XAI ui
```

- **Collections** group Stream Hosts that run the same Data Streams (logical grouping by location or function)
- **MAGS agent teams run as Data Streams** alongside regular data ingestion streams on the same Stream Hosts
- Cross-collection communication uses **MQTT Remote Receivers/Publishers**
- Stream Hosts connect back to Data Stream Designer via HTTPS for configuration
- **XMPro AI** provides the UI for managing MAGS agents, viewing conversations, and monitoring decisions

---

## MAGS Cognitive Engine

MAGS is the AI decision-making layer. It deploys structured teams of cognitive agents that follow the **Observe-Reflect-Plan-Act (ORPA)** cycle. MAGS is ~90% business process intelligence and ~10% LLM utility.

**Runtime:** MAGS agents execute as **Data Streams on Stream Hosts**. The Data Stream Designer defines the agent pipeline (data ingestion, cognitive processing, action output), and Stream Hosts run it continuously. This means MAGS inherits all Stream Host capabilities: distributed execution, edge deployment, collection-based scaling, and cross-collection MQTT bridging.

**UI:** The **XMPro AI** product is the management and interaction layer for MAGS -- agent team configuration, real-time agent conversations, decision monitoring, and governance controls.

### How MAGS Uses Each Infrastructure Service

```mermaid
graph TB
    subgraph MAGS["MAGS Agent (ORPA Cycle)"]
        O["Observe<br/><i>Receive data, detect events</i>"]
        R["Reflect<br/><i>Assess significance,<br/>generate insights</i>"]
        P["Plan<br/><i>PDDL planning,<br/>task decomposition</i>"]
        A["Act<br/><i>Execute tools,<br/>publish decisions</i>"]
        O --> R --> P --> A
        A -.->|"Loop"| O
    end

    subgraph "Polyglot Persistence"
        NEO4J["Neo4j<br/><b>Structural Memory</b><br/><i>Who, What, Where</i><br/>Agent relationships, team structure,<br/>knowledge graphs, constraints"]
        MILVUS["Milvus<br/><b>Semantic Memory</b><br/><i>Meaning, Context</i><br/>Observation embeddings,<br/>similar experience retrieval"]
        TSDB["TimescaleDB<br/><b>Episodic Memory</b><br/><i>When, Trends</i><br/>Time-stamped decisions,<br/>KPI history, sensor data"]
    end

    MQTT["MQTT Broker<br/><b>Agent Communication</b><br/><i>Team coordination</i><br/>Pub/sub messaging between agents,<br/>cross-collection data flow"]

    OLLAMA["Ollama<br/><b>LLM Utility</b><br/><i>~10% of agent intelligence</i><br/>Natural language reasoning,<br/>text generation, embeddings"]

    OTEL["OTEL LGTM<br/><b>Observability</b><br/>Decision traces, confidence scores,<br/>agent health metrics"]

    O -->|"Subscribe to events"| MQTT
    O -->|"Query recent history"| TSDB
    R -->|"Retrieve similar memories"| MILVUS
    R -->|"Query relationships"| NEO4J
    R -->|"Generate reflections"| OLLAMA
    P -->|"Check constraints"| NEO4J
    P -->|"Analyse trends"| TSDB
    P -->|"Reason & plan"| OLLAMA
    A -->|"Publish decisions"| MQTT
    A -->|"Store experience"| NEO4J & MILVUS & TSDB
    A -->|"Emit telemetry"| OTEL

    classDef mags fill:#fff8e1,stroke:#f57f17
    classDef data fill:#e3f2fd,stroke:#1565c0
    classDef msg fill:#fce4ec,stroke:#c62828
    classDef ai fill:#f3e5f5,stroke:#6a1b9a
    classDef obs fill:#fff3e0,stroke:#e65100

    class O,R,P,A mags
    class NEO4J,MILVUS,TSDB data
    class MQTT msg
    class OLLAMA ai
    class OTEL obs
```

| ORPA Phase | Infrastructure Used | What Happens |
|------------|-------------------|--------------|
| **Observe** | MQTT, TimescaleDB | Agent subscribes to MQTT topics for real-time events; queries TimescaleDB for recent sensor/KPI history |
| **Reflect** | Milvus, Neo4j, Ollama | Retrieves semantically similar past observations from Milvus; queries Neo4j for entity relationships; uses LLM to assess significance and generate insights |
| **Plan** | Neo4j, TimescaleDB, Ollama | Checks deontic constraints in Neo4j; analyses trends in TimescaleDB; uses LLM + PDDL for task planning |
| **Act** | MQTT, Neo4j, Milvus, TimescaleDB, OTEL | Publishes decisions via MQTT; stores experience across all three databases; emits decision traces to OTEL |

### Agent Team Architecture

MAGS agents operate in structured teams with separation of duties:

```mermaid
graph TB
    subgraph TEAM["Agent Team <i>(e.g. Predictive Maintenance)</i>"]
        MON["Monitoring Agent<br/><i>Observes equipment data</i>"]
        ANA["Analytics Agent<br/><i>Predicts failures</i>"]
        ECON["Economic Agent<br/><i>Optimises cost/benefit</i>"]
        SAFE["Safety Agent<br/><i>Validates constraints</i>"]
        EXEC_A["Execution Agent<br/><i>Creates work orders</i>"]
    end

    subgraph COMMS["Communication"]
        MQTT_T["MQTT Topics<br/><i>team/{team-id}/...</i>"]
    end

    subgraph SHARED["Shared Memory"]
        NEO["Neo4j<br/><i>Team knowledge graph</i>"]
        MIL["Milvus<br/><i>Shared embeddings</i>"]
        TS["TimescaleDB<br/><i>Shared history</i>"]
    end

    MON -->|"Publishes alerts"| MQTT_T
    MQTT_T -->|"Subscribes"| ANA & ECON & SAFE
    ANA -->|"Publishes predictions"| MQTT_T
    ECON -->|"Publishes recommendations"| MQTT_T
    SAFE -->|"Validates / vetoes"| MQTT_T
    MQTT_T --> EXEC_A

    MON & ANA & ECON & SAFE & EXEC_A --> NEO & MIL & TS

    classDef agent fill:#fff8e1,stroke:#f57f17
    classDef comms fill:#fce4ec,stroke:#c62828
    classDef mem fill:#e3f2fd,stroke:#1565c0

    class MON,ANA,ECON,SAFE,EXEC_A agent
    class MQTT_T comms
    class NEO,MIL,TS mem
```

**Key design principles:**
- The agent that **proposes** an action is never the one that **approves** it
- Safety validation is structurally independent from economic optimisation
- Agents act only within engineer-approved **bounded autonomy** limits
- Every decision includes documented reasoning (explainability)
- Consensus mechanisms resolve conflicting recommendations

---

## Infrastructure Services (Docker)

### Component Breakdown

Each service stack is independently deployable on a single Docker host, connected through a shared observability network.

```mermaid
graph TB
    subgraph HOST["Docker Host"]

        subgraph OBS_NET["observability network <i>(shared by all services)</i>"]
            direction TB
        end

        subgraph NEO["Neo4j Stack"]
            NEO4J_DB["neo4j-graph<br/>neo4j:2025.08-community<br/><b>7474</b> HTTP | <b>7687</b> Bolt<br/><b>7473</b> HTTPS | <b>2004</b> Metrics"]
            NEO4J_WATCHER["neo4j-watcher<br/>python:3.11-slim<br/>Auto-executes .cypher scripts"]
            NEO4J_DB --- NEO4J_WATCHER
        end

        subgraph MQ["MQTT Stack"]
            MOSQUITTO["mosquitto<br/>eclipse-mosquitto:2.0.22<br/><b>1883</b> TCP | <b>8883</b> TLS<br/><b>9002</b> WebSocket | <b>9003</b> WSS"]
        end

        subgraph MIL["Milvus Stack"]
            direction TB
            ETCD["etcd<br/>v3.6.5<br/><i>Metadata store</i>"]
            MINIO["minio<br/>minio:latest<br/><b>9000</b> API | <b>9001</b> Console"]
            MILVUS_DB["milvus-standalone<br/>milvus:v2.6.3<br/><b>19530</b> gRPC | <b>9091</b> HTTP<br/><i>4 CPU / 8 GB RAM</i>"]
            ATTU["attu<br/>zilliz/attu:v2.6<br/><i>Web UI</i>"]
            ATTU_NGINX["nginx<br/><b>8001</b> HTTPS Attu<br/><b>19531</b> CORS proxy"]
            ETCD & MINIO --> MILVUS_DB --> ATTU --> ATTU_NGINX
        end

        subgraph TS["TimescaleDB Stack"]
            direction TB
            TSDB_PG["timescaledb<br/>timescale/timescaledb:pg16<br/><b>5432</b> PostgreSQL<br/><i>4 CPU / 8 GB RAM</i>"]
            PGADMIN["pgadmin4<br/><b>5050</b> HTTP | <b>5051</b> HTTPS"]
            POSTGREST["postgrest<br/><b>3000</b> HTTP | <b>3443</b> HTTPS<br/><i>Auto-generated REST API</i>"]
            BACKUP["backup scheduler<br/>postgres:16-alpine<br/><i>Daily 02:00 UTC</i>"]
            TSDB_PG --> PGADMIN & POSTGREST & BACKUP
        end

        subgraph OL["Ollama Stack"]
            OLLAMA_SVC["ollama<br/>ollama:latest<br/><b>11434</b> HTTP | <b>11443</b> HTTPS<br/><i>GPU: NVIDIA / AMD / CPU</i>"]
            OL_NGINX["nginx<br/><i>SSL termination</i>"]
            OLLAMA_SVC --> OL_NGINX
        end

        subgraph OTEL_S["OTEL LGTM Stack"]
            direction TB
            OTEL_LGTM["otel-lgtm<br/>grafana/otel-lgtm:latest<br/><b>3001</b> Grafana<br/><b>4317</b> OTLP gRPC | <b>4318</b> OTLP HTTP<br/><i>4 CPU / 4 GB RAM</i>"]
            PG_EXP["postgres-exporter<br/><i>:9187 metrics</i>"]
            MQ_EXP["mosquitto-exporter<br/><i>:9234 metrics</i>"]
            OTEL_NGINX["nginx<br/><b>3444</b> HTTPS Grafana"]
            OTEL_LGTM --- PG_EXP & MQ_EXP & OTEL_NGINX
        end
    end

    classDef neo fill:#e3f2fd,stroke:#1565c0
    classDef mq fill:#fce4ec,stroke:#c62828
    classDef mil fill:#e8eaf6,stroke:#283593
    classDef ts fill:#e0f2f1,stroke:#00695c
    classDef ol fill:#f3e5f5,stroke:#6a1b9a
    classDef otel fill:#fff3e0,stroke:#e65100

    class NEO4J_DB,NEO4J_WATCHER neo
    class MOSQUITTO mq
    class ETCD,MINIO,MILVUS_DB,ATTU,ATTU_NGINX mil
    class TSDB_PG,PGADMIN,POSTGREST,BACKUP ts
    class OLLAMA_SVC,OL_NGINX ol
    class OTEL_LGTM,PG_EXP,MQ_EXP,OTEL_NGINX otel
```

### Network Topology

All services join the shared **observability** network for centralized metrics collection. Each service stack also has its own isolated bridge network for internal communication.

```mermaid
graph LR
    subgraph "observability<br/><i>external Docker network</i>"
        direction TB
        N1["Neo4j"]
        N2["MQTT"]
        N3["Milvus"]
        N4["TimescaleDB"]
        N5["Ollama"]
        N6["OTEL LGTM"]
    end

    subgraph "mqtt-network<br/><i>bridge</i>"
        M1["Mosquitto"]
    end

    subgraph "milvus-internal<br/><i>bridge</i>"
        V1["Etcd"]
        V2["MinIO"]
        V3["Milvus Standalone"]
        V4["Attu + Nginx"]
    end

    subgraph "timescaledb_network<br/><i>bridge</i>"
        T1["TimescaleDB"]
        T2["pgAdmin"]
        T3["PostgREST"]
        T4["Backup"]
    end

    subgraph "ollama-network<br/><i>bridge</i>"
        O1["Ollama"]
        O2["Nginx SSL"]
    end

    N2 -.- M1
    N3 -.- V3
    N4 -.- T1
    N5 -.- O1
```

**Key design decisions:**
- The **observability** network is external (created once, shared across all compose stacks)
- Service-specific networks provide **blast radius isolation** -- a misconfigured Milvus container cannot reach MQTT internals
- Prometheus exporters (postgres-exporter, mosquitto-exporter) sit on the observability network and bridge into service networks to scrape metrics

---

## Observability Data Flow

```mermaid
flowchart TB
    subgraph "Instrumented Applications"
        APP["MAGS Agents /<br/>XMPro Stream Hosts<br/><i>with OTEL SDK</i>"]
    end

    subgraph "Infrastructure Metrics"
        NEO_M["Neo4j :2004"]
        PG_EXP["postgres-exporter :9187<br/><i>scrapes TimescaleDB</i>"]
        MQ_EXP["mosquitto-exporter :9234<br/><i>scrapes MQTT</i>"]
        MIL_M["Milvus :9091"]
    end

    subgraph OTEL["OTEL LGTM Container"]
        COLLECTOR["OpenTelemetry<br/>Collector"]
        PROM["Prometheus"]
        LOKI["Loki<br/><i>Logs</i>"]
        TEMPO["Tempo<br/><i>Traces</i>"]
        MIMIR["Mimir<br/><i>Long-term metrics</i>"]
        GRAFANA["Grafana<br/><i>Dashboards</i>"]
    end

    APP -->|"OTLP gRPC :4317<br/>OTLP HTTP :4318"| COLLECTOR
    COLLECTOR --> LOKI & TEMPO & PROM

    NEO_M & PG_EXP & MQ_EXP & MIL_M -->|"Prometheus scrape<br/>every 30s"| PROM

    PROM --> MIMIR --> GRAFANA
    LOKI --> GRAFANA
    TEMPO --> GRAFANA

    OPS["Operations Team"] -->|"Browse :3001 / :3444"| GRAFANA

    classDef otel fill:#fff3e0,stroke:#e65100
    class COLLECTOR,PROM,LOKI,TEMPO,MIMIR,GRAFANA otel
```

---

## SSL/TLS Architecture

The platform supports two SSL patterns depending on whether the service has native TLS support:

```mermaid
flowchart LR
    subgraph "Native TLS"
        C1["Client"] -->|"Bolt+TLS :7687"| NEO["Neo4j"]
        C2["Client"] -->|"TLS :8883"| MQ["MQTT"]
        C3["Client"] -->|"gRPC TLS :19530"| MIL["Milvus"]
        C4["Client"] -->|"SSL :5432"| TS["TimescaleDB"]
    end

    subgraph "Nginx TLS Termination"
        C5["Client"] -->|"HTTPS"| NG["Nginx<br/>SSL Termination"]
        NG -->|"HTTP"| SVC["pgAdmin :80<br/>PostgREST :3000<br/>Ollama :11434<br/>Grafana :3000<br/>Attu :3000"]
    end

    classDef native fill:#c8e6c9,stroke:#2e7d32
    classDef proxy fill:#fff3e0,stroke:#e65100
    class NEO,MQ,MIL,TS native
    class NG proxy
```

| HTTPS Endpoint | Host Port | Backend |
|----------------|-----------|---------|
| pgAdmin | 5051 | pgAdmin :80 |
| PostgREST | 3443 | PostgREST :3000 |
| Ollama | 11443 | Ollama :11434 |
| Grafana | 3444 | Grafana :3000 |
| Attu (Milvus UI) | 8001 | Attu :3000 |

XMPro platform components (SM, AD, DS) use IIS-managed HTTPS with their own SSL certificates.

---

## Resource Footprint

### Docker Infrastructure Services

| Service | CPU Limit | RAM Limit | CPU Reserved | RAM Reserved | Persistent Storage |
|---------|-----------|-----------|--------------|--------------|-------------------|
| Neo4j | 6 | 8 GB | 3 | 6 GB | Graph data, logs, plugins |
| Milvus Standalone | 4 | 8 GB | 2 | 4 GB | Vector indexes |
| TimescaleDB | 4 | 8 GB | - | - | PostgreSQL data, backups |
| OTEL LGTM | 4 | 4 GB | 2 | 2 GB | Metrics, logs, traces |
| Ollama | 6 | 8 GB | - | - | LLM model files (10-50 GB) |
| Etcd | 1 | 2 GB | 0.5 | 1 GB | Milvus metadata |
| MinIO | 1 | 2 GB | 0.5 | 1 GB | Vector object storage |
| **Docker total** | **~26** | **~40 GB** | **~8** | **~14 GB** | |

### XMPro Platform (Windows Server)

| Component | CPU | RAM | Storage |
|-----------|-----|-----|---------|
| IIS (SM + AD + DS + AI) | 4+ | 8+ GB | Application binaries, config |
| SQL Server 2022 | 4+ | 16+ GB | Platform databases |
| Stream Host(s) | 2+ per host | 4+ GB per host | Connector libraries |
| **Platform total** | **~10+** | **~28+ GB** | |

**Combined minimum for full stack:** ~36 CPU cores, ~68 GB RAM (production sizing depends on agent count, data volume, and model size).

---

## Deployment Topology Options

### Option A: Single Server (Dev / PoC)

```mermaid
graph TB
    subgraph SERVER["Single Server"]
        IIS["IIS<br/>SM + AD + DS + AI"]
        SQL["SQL Server"]
        DOCKER["Docker Desktop<br/>All 6 service stacks"]
        SH["Stream Host<br/><i>Windows Service<br/>runs MAGS Data Streams</i>"]
    end

    classDef server fill:#e8eaf6,stroke:#283593
    class IIS,SQL,DOCKER,SH server
```

### Option B: Separated (Production)

```mermaid
graph TB
    subgraph APP_SVR["Application Server <i>(Windows Server)</i>"]
        IIS["IIS<br/>SM + AD + DS + AI"]
        SH["Stream Host(s)<br/><i>runs MAGS Data Streams</i>"]
    end

    subgraph DB_SVR["Database Server"]
        SQL["SQL Server 2022<br/><i>XMPro platform DBs</i>"]
    end

    subgraph DOCKER_SVR["Docker Host <i>(Linux recommended)</i>"]
        NEO["Neo4j"]
        MQTT["MQTT"]
        MIL["Milvus"]
        TS["TimescaleDB"]
        OL["Ollama"]
        OTEL["OTEL LGTM"]
    end

    subgraph GPU_SVR["GPU Server <i>(optional)</i>"]
        OL2["Ollama<br/><i>Dedicated GPU inference</i>"]
    end

    subgraph EDGE["Edge <i>(optional)</i>"]
        SH_E["Stream Host<br/><i>Docker on edge gateway</i>"]
    end

    IIS --> SQL
    SH --> IIS
    SH --> DOCKER_SVR
    SH_E -->|"MQTT"| MQTT

    classDef app fill:#e8eaf6,stroke:#283593
    classDef db fill:#fce4ec,stroke:#c62828
    classDef docker fill:#e3f2fd,stroke:#1565c0
    classDef gpu fill:#f3e5f5,stroke:#6a1b9a
    classDef edge fill:#e0f2f1,stroke:#00695c

    class IIS,SH app
    class SQL db
    class NEO,MQTT,MIL,TS,OL,OTEL docker
    class OL2 gpu
    class SH_E edge
```

---

## Port Reference

### XMPro Platform

| Component | Port | Protocol | Description |
|-----------|------|----------|-------------|
| **Subscription Manager** | 5201 | HTTPS | Identity, licensing, access control |
| **App Designer** | 5202 | HTTPS | Dashboard and application UI |
| **Data Stream Designer** | 5203 | HTTPS | Data pipeline design UI |
| **XMPro AI** | - | HTTPS | MAGS agent management, conversations, monitoring |
| **SQL Server** | 1433 | TDS | Platform databases |

### Docker Infrastructure

| Service | Port | Protocol | Description |
|---------|------|----------|-------------|
| **Neo4j** | 7474 | HTTP | Browser UI |
| | 7473 | HTTPS | Browser UI (SSL) |
| | 7687 | Bolt/Bolt+TLS | Query protocol |
| **MQTT** | 1883 | TCP | Pub/sub messaging |
| | 8883 | TLS | Encrypted pub/sub |
| | 9002 | WebSocket | Browser clients |
| **Milvus** | 19530 | gRPC | Vector operations |
| | 9091 | HTTP | Health / management |
| | 9001 | HTTP | MinIO console |
| | 8001 | HTTPS | Attu web UI |
| **TimescaleDB** | 5432 | PostgreSQL | Database |
| | 5050/5051 | HTTP/HTTPS | pgAdmin |
| | 3000/3443 | HTTP/HTTPS | PostgREST API |
| **Ollama** | 11434 | HTTP | LLM API |
| | 11443 | HTTPS | LLM API (SSL) |
| **OTEL LGTM** | 3001/3444 | HTTP/HTTPS | Grafana dashboards |
| | 4317 | gRPC | OTLP receiver |
| | 4318 | HTTP | OTLP receiver |

---

## Deployment Modes (Docker Infrastructure)

```mermaid
flowchart TD
    START["Deploy Infrastructure Stack"] --> MODE{Environment?}

    MODE -->|"Internet available"| ONLINE["Online Deployment<br/>docker-stack-installer pulls images"]
    MODE -->|"Air-gapped"| OFFLINE["Offline Deployment<br/>prepare-stack.ps1 creates package"]

    ONLINE --> SELECT
    OFFLINE -->|"Transfer package<br/>~2.2 GB total"| LOAD["docker load -i images.tar"]
    LOAD --> SELECT

    SELECT["Select Services"] --> S1["Neo4j"]
    SELECT --> S2["MQTT"]
    SELECT --> S3["Milvus"]
    SELECT --> S4["TimescaleDB"]
    SELECT --> S5["Ollama"]
    SELECT --> S6["OTEL LGTM<br/><i>installed last</i>"]

    S1 & S2 & S3 & S4 & S5 & S6 --> NET["Create observability network"]
    NET --> UP["docker-compose up -d<br/>per service"]
    UP --> CERTS["Install CA certificates"]
    CERTS --> XMPRO["Install XMPro Platform<br/><i>SM → AD → DS → AI → Stream Host</i>"]
    XMPRO --> READY["Platform Ready"]

    classDef start fill:#e1f5fe,stroke:#0277bd
    classDef ready fill:#c8e6c9,stroke:#2e7d32
    classDef xmpro fill:#e8eaf6,stroke:#283593
    class START start
    class READY ready
    class XMPRO xmpro
```

**Cross-platform:** Docker infrastructure uses identical Compose configurations with platform-specific installer scripts (PowerShell for Windows, Bash for Linux). The XMPro platform components require Windows Server with IIS.
