# Memory Cycle

## Overview

The Memory Cycle is a core component of the XMPro MAGS system, managing the cognitive processes of agents through observation, reflection, and planning integration. This document details the complete memory cycle process, its components, and their interactions.

## Architecture

```mermaid
graph TB
    Agent[Agent Instance]
    MC[Memory Cycle]
    ObsM[Observation Memory]
    RefM[Reflection Memory]
    Plan[Planning System]
    
    EmbeddingModel[Embedding Model]
    RAGProcessor[RAG Processor]
    
    VectorDBAbstract[AbstractVector Base Class]
    
    MQTT[Message Broker/MQTT]
    Neo4j[(Neo4j Graph Database)]
    LLM[Language Model]
    
    MQTT -->|Receives Input| Agent
    Agent -->|Triggers| MC
    
    MC -->|Creates| ObsM
    ObsM -->|Triggers| RefM
    RefM -->|Influences| Plan
    
    MC -->|1 Sends Content| EmbeddingModel
    EmbeddingModel -->|2 Creates Embeddings| RAGProcessor
    RAGProcessor -->|3 Queries Vector DB| VectorDBAbstract
    RAGProcessor -->|4 Returns Context| MC
    
    ObsM -->|Stores| Neo4j
    ObsM -->|Vectorizes & Stores| VectorDBAbstract
    RefM -->|Stores| Neo4j
    RefM -->|Vectorizes & Stores| VectorDBAbstract
    Plan -->|Stores| Neo4j
    
    MC -->|Generates Responses| LLM
    LLM -->|Enhanced with RAG Context| MC
    
    MC -->|Sends Responses| MQTT
    
    VectorDBAbstract -.->|Implements| Milvus[Milvus Vector DB]
    VectorDBAbstract -.->|Implements| Qdrant[Qdrant Vector DB]
    VectorDBAbstract -.->|Implements| MongoDB[MongoDB Atlas Vector DB]
    
    Milvus --- MilvusCollections[Milvus Collections]
    Qdrant --- QdrantCollections[Qdrant Collections]
    MongoDB --- MongoCollections[MongoDB Collections]
    
    subgraph Vector DB Collections
        MilvusCollections -->|Contains| MilvusAgent[Agent Memories]
        MilvusCollections -->|Contains| MilvusGeneral[General Knowledge]
        QdrantCollections -->|Contains| QdrantAgent[Agent Memories]
        QdrantCollections -->|Contains| QdrantGeneral[General Knowledge]
        MongoCollections -->|Contains| MongoAgent[Agent Memories]
        MongoCollections -->|Contains| MongoGeneral[General Knowledge]
    end
    
    classDef mainComponent fill:#f9f,stroke:#333,stroke-width:2px
    classDef database fill:#69b,stroke:#333,stroke-width:2px
    classDef ragComponent fill:#bfb,stroke:#333,stroke-width:2px
    classDef external fill:#ddd,stroke:#333,stroke-width:2px
    classDef vectorDB fill:#ff9,stroke:#333,stroke-width:2px
    classDef collection fill:#9cf,stroke:#333,stroke-width:2px
    
    class Agent,MC,ObsM,RefM,Plan mainComponent
    class Neo4j database
    class EmbeddingModel,RAGProcessor ragComponent
    class MQTT,LLM external
    class VectorDBAbstract,Milvus,Qdrant,MongoDB vectorDB
    class MilvusCollections,QdrantCollections,MongoCollections,MilvusAgent,MilvusGeneral,QdrantAgent,QdrantGeneral,MongoAgent,MongoGeneral collection
```

## Components

### 1. Initialization & Setup

The Memory Cycle initializes with several key components:
- Database Manager (Neo4j and Vector DBs)
- Language Model integration
- Message Broker (MQTT/DDS)
- OpenTelemetry for tracing/metrics
- Tool Library for agent capabilities
- Prompt Manager for LLM interactions

### 2. Core Input Processing

When input is received through MQTT, it is:
1. Validated and routed based on type:
   - Chat messages
   - Observations
   - Datastream messages

### 3. Memory Creation Process

#### 3.1 Observation Creation

```plaintext
When a new observation is triggered:
1. Content is processed through RAG:
   - Query is embedded using the Embedding Model
   - Similar memories are retrieved from Vector DB
   - RAG context is retrieved from both general and agent-specific collections
2. LLM processes observation with context to generate:
   - Summary
   - Key Points
   - Context information
3. Importance score is calculated:
   - Uses LLM to evaluate importance (0-1 scale)
   - Considers agent goals and current context
4. Memory is stored:
   - Vector representation in chosen Vector DB
   - Relationship data in Neo4j
   - Additional metadata and metrics
```

```mermaid
sequenceDiagram
    participant Input
    participant MC as Memory Cycle
    participant EM as Embedding Model
    participant VDB as Vector DB
    participant LLM
    participant Neo4j
    
    Input->>MC: New Observation
    
    rect rgb(200, 255, 200)
        Note over MC,VDB: RAG Processing
        MC->>EM: Generate Embedding
        EM->>VDB: Query Similar Memories
        VDB-->>MC: Return Similar Memories
        MC->>VDB: Query RAG Collections
        VDB-->>MC: Return Context
    end
    
    rect rgb(255, 230, 200)
        Note over MC,LLM: Content Generation
        MC->>LLM: Process with Context
        LLM-->>MC: Return Generated Content
        Note right of LLM: - Summary<br/>- Key Points<br/>- Context Info
    end
    
    rect rgb(200, 230, 255)
        Note over MC,Neo4j: Importance & Storage
        MC->>LLM: Calculate Importance
        LLM-->>MC: Return Score (0-1)
        par Store in Vector DB
            MC->>VDB: Store Vector Representation
        and Store in Graph DB
            MC->>Neo4j: Store Relationships & Metadata
        end
    end
```

#### 3.2 Reflection Creation

```plaintext
Reflections are triggered when:
1. Accumulated observation importance exceeds threshold
2. Significant time has passed
3. Critical new information is received

Process:
1. Recent memories are collected and ranked:
   - Time-based decay applied to importance scores
   - Vector similarity considered
   - Contextual relevance evaluated
2. RAG enhancement applied:
   - Similar past reflections retrieved
   - Relevant context aggregated
3. LLM generates reflection with:
   - Key insights
   - Action items
   - Updated understanding
4. Storage similar to observations but with:
   - Links to contributing memories
   - Additional metadata for reflection chain
```

```mermaid
sequenceDiagram
    participant T as Trigger System
    participant MC as Memory Cycle
    participant VDB as Vector Database
    participant Neo4j
    participant EM as Embedding Model
    participant LLM
    
    Note over T: Triggered by:<br/>1. Importance Threshold
    
    T->>MC: Initiate Reflection
    
    rect rgb(200, 230, 255)
        Note over MC,Neo4j: Memory Collection Phase
        MC->>Neo4j: Fetch Recent Memories
        Neo4j-->>MC: Return Memory Records
        MC->>MC: Apply Time Decay
        MC->>EM: Generate Memory Embeddings
        EM->>VDB: Query Similar Memories
        VDB-->>MC: Return Similar Memories
    end
    
    rect rgb(200, 255, 200)
        Note over MC,VDB: RAG Enhancement
        MC->>VDB: Query Past Reflections
        VDB-->>MC: Return Similar Reflections
        MC->>VDB: Query Knowledge Base
        VDB-->>MC: Return Relevant Context
        MC->>MC: Aggregate RAG Context
    end
    
    rect rgb(255, 230, 200)
        Note over MC,LLM: Content Generation
        MC->>LLM: Generate Reflection
        Note right of LLM: Process with:<br/>- Key Insights<br/>- Action Items<br/>- Understanding Updates
        LLM-->>MC: Return Generated Content
    end
    
    rect rgb(230, 200, 255)
        Note over MC,Neo4j: Storage
        par Store in Vector DB
            MC->>EM: Generate Embedding
            EM->>VDB: Store Vector
        and Store in Graph DB
            MC->>Neo4j: Store Reflection
            MC->>Neo4j: Create Memory Links
        end
    end
```

### 4. Planning Integration

The memory cycle integrates with planning through:

```plaintext
1. Plan Detection:
   - Monitors reflection outcomes
   - Evaluates goal alignment
   - Checks for necessary plan updates

2. Plan Adaptation:
   - New reflections can trigger plan reviews
   - Environment changes can force replanning
   - Goal adjustments can initiate new plans

3. Plan Execution:
   - Tasks are distributed to appropriate agents
   - Progress is monitored and stored
   - Outcomes feed back into memory cycle
```

```mermaid
sequenceDiagram
    participant Timer as Planning Timer
    participant RefD as Reflection System
    participant Env as Environmental Changes
    participant Goals as Goal Monitor
    participant MC as Memory Cycle
    participant PlanA as PlanAdaptationDetector
    participant Plan as PlanningSystem
    participant LLM
    participant Neo4j
    participant VDB as Vector DB
    participant Agent as Other Agents
    participant MB as Message Broker

    rect rgb(200, 255, 200)
        Note over Timer,Plan: Plan Detection Phase - Multiple Triggers
        
        alt Time-based Check
            Timer->>MC: IsTimeForPlanning()
            MC->>PlanA: ShouldTriggerPlanningAsync
        end
        
        alt Reflection Trigger
            RefD->>MC: New Reflection Created
            MC->>PlanA: ShouldTriggerPlanningAsync
        end

        alt Environmental Change
            Env->>MC: New Information Received
            MC->>PlanA: ShouldTriggerPlanningAsync
        end

        alt Goal Not Met
            Goals->>MC: Goal Status Update
            MC->>PlanA: ShouldTriggerPlanningAsync
        end

        alt Resource Changes
            Agent->>MC: Resource Status Update
            MC->>PlanA: ShouldTriggerPlanningAsync
        end

        PlanA->>Neo4j: Get Current Plan
        Neo4j-->>PlanA: Return Plan Details
        PlanA->>VDB: Query Similar Memories
        VDB-->>PlanA: Return Relevant Context
        PlanA->>LLM: Evaluate Planning Need
        LLM-->>PlanA: Return Decision & Reasoning
        PlanA-->>MC: Return Planning Decision
    end

    alt Plan Update Needed
        rect rgb(255, 230, 200)
            Note over MC,MB: Plan Adaptation Phase
            MC->>Plan: TriggerPlanningProcessAsync
            Plan->>Plan: SelectPlanningMethod
            Plan->>LLM: Generate/Adjust Plan
            LLM-->>Plan: Return PDDL Plan
            Plan->>Neo4j: Store Plan & Tasks
            Plan->>MB: PublishNewPlan or PublishUpdatedPlan
            MB-->>Agent: Notify Plan Changes
        end

        rect rgb(200, 230, 255)
            Note over Plan,MB: Task Distribution Phase
            MB->>Agent: PublishTasksToAgents
            MB->>Agent: PublishActionsToAgents
            Agent-->>MB: Report Task Status
            MB->>Neo4j: Update Task Status
            Agent->>MC: Feed Outcomes to Memory
        end
    else No Update Needed
        PlanA->>MC: Return NoUpdateNeeded Decision
    end

    Note over MC,Agent: Continuous Monitoring & Feedback Loop
```

### 5. RAG Implementation

```plaintext
For each memory operation:
1. Content Processing:
   - Text is cleaned and formatted
   - Relevant sections are extracted
   - Context is structured

2. Vector Operations:
   - Content is embedded via Embedding Model
   - Vector DB collections are queried:
     * Agent-specific memories
     * General knowledge base
   - Results are ranked by relevance

3. Context Integration:
   - Top K results are retrieved
   - Context is formatted for LLM
   - Token limits are managed
```

### 6. Storage & Persistence

```plaintext
Dual Storage Strategy:
1. Neo4j Graph Database:
   - Relationship data
   - Temporal connections
   - Metadata and metrics
   - Planning linkages

2. Vector Database:
   - Semantic embeddings
   - Fast similarity search
   - Collections separated by:
     * Agent-specific memories
     * General knowledge
     * Different memory types
```

### 7. Metrics & Monitoring

```plaintext
The cycle tracks:
1. Memory Statistics:
   - Memories processed
   - Importance distributions
   - Response times
   - Token usage

2. RAG Metrics:
   - Query times
   - Relevance scores
   - Cache hit rates
   - Vector DB performance

3. System Health:
   - Resource usage
   - Error rates
   - Processing latencies
   - Queue depths
```

The Memory Cycle operates continuously, with each component feeding into others to maintain the agent's cognitive processes and decision-making capabilities. The system is designed to be both reactive to new inputs and proactive in generating insights and maintaining knowledge coherence.
