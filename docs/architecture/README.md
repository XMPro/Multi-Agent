# XMPro AI Agents Architecture Documentation

Welcome to the architecture documentation for the XMPro AI Agents project. This folder contains various diagrams and explanations that illustrate the structure, components, and interactions within our system.

## Table of Contents

1. [Overview](#overview)
2. [Diagram Types](#diagram-types)
3. [Naming Convention Hierarchy](#naming-convention-hierarchy)
4. [Key Components](#key-components)
5. [Agent Architecture](#agent-architecture)
6. [Memory Cycle Instantiation](#memory-cycle-instantiation)
7. [Interaction Flows](#interaction-flows)
8. [Deployment Architecture](#deployment-architecture)

## Overview

The XMPro AI Agents system is designed to manage and coordinate multiple AI agents in industrial settings. The architecture is built to support scalability, flexibility, and efficient communication between various components.

## Diagram Types

This folder contains several types of diagrams, each serving a specific purpose in explaining our system architecture:

1. **Component Diagrams**: Show the high-level structure of the system and how different components interact.
2. **Sequence Diagrams**: Illustrate the flow of operations and interactions between system components over time.
3. **Class Diagrams**: Depict the structure of key classes in our object-oriented design.
4. **Deployment Diagrams**: Visualize how the system is deployed across hardware and software environments.

## Naming Convention Hierarchy

The following diagram illustrates the hierarchy of our naming convention, from Agent Instances up to Sites:

```mermaid
graph TD
    A[WTR-QUAL-AGENT-001] -->|INSTANCE_OF| B[WTR-QUAL-PROFILE-001]
    C[MAINT-ENG-AGENT-001] -->|INSTANCE_OF| D[MAINT-ENG-PROFILE-001]
    E[OPS-MGT-AGENT-001] -->|INSTANCE_OF| F[OPS-MGT-PROFILE-001]
    B -->|ASSOCIATED_WITH| G[DALLAS-PROD-OPS-TEAM-001]
    D -->|ASSOCIATED_WITH| G
    F -->|ASSOCIATED_WITH| G
    G -->|ASSIGNED_TO| H[DALLAS-PLANT-PROD-FAC-001]
```

## Key Components

- Agent Profiles
- Agent Instances
- Memory Cycle
- MQTT Manager
- Database Manager (Neo4j and Vector Database)
- Language Model
- Prompt Manager
- Planning Strategies

## Agent Architecture

For a detailed explanation of our agent architecture, including the structure of AgentProfile and AgentInstance, please refer to the [Agent Architecture Documentation](agent_architecture.md).

## Memory Cycle Instantiation

The Memory Cycle Instantiation process is a crucial part of our system. Here are the key diagrams illustrating this process:

### Overall Process Flow

```mermaid
graph TD
    A[Start] --> B[Configuration Setup]
    B --> C[MemoryCycle Creation]
    C --> D[Service Collection Init]
    D --> E[Core Components Init]
    E --> F[Service Registration]
    F --> G[MemoryCycle Instantiation]
    G --> H[Agent Startup]
    H --> I[MQTT Startup]
    I --> J[Memory Cycle Execution]
    J --> K[Error Handling & Cleanup]
    K --> L[End]
```

### Core Components Interaction

```mermaid
graph TD
    MC[MemoryCycle] --> |Uses| LM[Language Model]
    MC --> |Uses| DBM[Database Manager]
    MC --> |Communicates via| MQTT[MQTT Manager]
    DBM --> |Interfaces with| Neo4j[Neo4j Database]
    DBM --> |Interfaces with| VDB[Vector Database]
    MC --> |Uses| EM[Embedding Model]
    MC --> |Guided by| PM[Prompt Manager]
    MC --> |Plans with| PS[Planning Strategies]
```

### MQTT Startup Process

```mermaid
sequenceDiagram
    participant A as Agent
    participant MM as MQTT Manager
    participant B as MQTT Broker
    A->>MM: Start MQTT
    MM->>B: Attempt MQTT 5 Connection
    alt MQTT 5 Successful
        B->>MM: MQTT 5 Connected
    else MQTT 5 Failed
        MM->>B: Attempt MQTT 3.1.1 Connection
        B->>MM: MQTT 3.1.1 Connected
    end
    MM->>B: Subscribe to Topics
    MM->>B: Publish Startup Message
    MM->>A: MQTT Ready
```

For more detailed information on the Memory Cycle Instantiation process, please refer to the [Memory Cycle Instantiation Documentation](../technical-details/memory_cycle_instantiation.md).

## Interaction Flows

[Overview of main interaction flows within the system, to be expanded]

## Deployment Architecture

[Description of how the system is deployed, to be expanded]

For more detailed information on specific aspects of the architecture, please refer to the individual diagram files in this folder.