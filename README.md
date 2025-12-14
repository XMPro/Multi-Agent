# XMPro Multi-Agent Generative Systems (MAGS)

Multi-Agent Generative Systems (MAGS) is an industrial-grade framework for deploying collaborative AI agent teams in operational environments. MAGS agents coordinate through formal consensus mechanisms, maintain sophisticated memory systems, and make autonomous decisions based on research-grounded cognitive architectures.

## Overview

MAGS implements a **90/10 intelligence architecture**: 90% business process intelligence (decision-making, planning, memory, optimization) and 10% LLM utility (communication and explanation). This design prioritizes deterministic, explainable decision-making over pure generative AI approaches.

**Core Capabilities:**
- Multi-agent coordination with formal consensus mechanisms (Byzantine, Raft, weighted voting)
- ORPA cognitive cycle (Observe-Reflect-Plan-Act) for autonomous decision-making
- Sophisticated memory systems with significance scoring and synthetic memory generation
- Real-time integration with operational systems via XMPro Data Streams
- Complete audit trails and explainability for regulatory compliance

**Research Foundation:** Extends Stanford's "Generative Agents: Interactive Simulacra of Human Behavior" (Park et al., 2023) for industrial applications. [[2304.03442]](https://arxiv.org/abs/2304.03442)

## XMPro Agentic Operations Platform

MAGS is part of XMPro's comprehensive Agentic Operations platform, which provides four distinct AI agent capabilities:

![XMPro GenAI Agents](docs/decision-guides/images/xmprogenAIagents.png)

1. **XMPro DataStream GenAI Agents** - Rule-based workflows with LLM enhancement
2. **AI Assistant** - Chat interface with dynamic access to real-time operational data
3. **AI Advisor** - Situational awareness with proactive recommendations
4. **MAGS** - Multi-agent coordination for complex scenarios

**When to use MAGS:** Multi-stakeholder consensus, safety-critical operations, complex coordination, regulatory compliance. For simpler scenarios, consider XMPro's other agent capabilities first.

See [When NOT to Use MAGS](docs/decision-guides/when-not-to-use-mags.md) for detailed decision framework.

## Architecture

### ORPA Cognitive Cycle

![ORPA Memory Cycle](docs/concepts/images/XMProORPAMemoryCycle.png)

MAGS agents operate through a four-phase cognitive cycle:

1. **Observe** - Gather information from operational systems and environment
2. **Reflect** - Analyze observations, identify patterns, assess significance
3. **Plan** - Develop strategies using multi-objective optimization
4. **Act** - Execute plans with monitoring and feedback loops

### Agent Types

- **Content Agents** - Information retrieval, documentation, knowledge management
- **Decision Agents** - Autonomous reasoning, optimization, strategic planning
- **Hybrid Agents** - Combined capabilities for complex scenarios

### Multi-Agent Coordination

- Formal consensus mechanisms (Paxos, Raft, Byzantine fault tolerance)
- Team-based organization with defined roles and responsibilities
- Distributed memory systems with shared knowledge bases
- MQTT/DDS messaging infrastructure for reliable communication

## Key Features

- **Adaptive Decision Making** - Agents create and modify plans dynamically based on changing conditions
- **Prompt Injection Protection** - Architectural safeguards and controlled interfaces prevent prompt injection attacks
- **Self-Healing Systems** - MAPE control loops enable autonomous error detection and recovery
- **OpenTelemetry Integration** - Comprehensive observability and performance monitoring
- **Hybrid Database Architecture** - Graph (Neo4j), TimeSeries (TimescaleDB), and Vector (Qdrant/Milvus) databases
- **Tool Orchestration** - Extensible tool library with MCP (Model Context Protocol) support
- **Responsible AI Framework** - Human-in-the-loop patterns, explainability, compliance mapping

## Getting Started

### Prerequisites

- Licensed XMPro installation
- Neo4j Graph Database
- Vector Database (Milvus, Qdrant, or MongoDB Atlas)
- MQTT Broker
- LLM Provider (Azure OpenAI, AWS Bedrock, or compatible)

### Installation

1. Configure Neo4j graph database
2. Install system options
3. Load prompt library
4. Load tool library
5. Configure vector database and MQTT broker

See [Installation Guide](docs/installation.md) for detailed instructions.

### Quick Start

**For Evaluation:**
- [Evaluation Prompt](docs/getting-started/evaluation-prompt.md) - Interactive LLM assessment
- [Evaluation Guide](docs/getting-started/evaluation-guide.md) - Detailed written assessment
- [Understanding MAGS](docs/getting-started/understanding-mags.md) - Core concepts

**For Implementation:**
- [First Steps](docs/getting-started/first-steps.md) - Role-based learning paths
- [Agent Types](docs/concepts/agent_types.md) - Content, Decision, and Hybrid agents
- [ORPA Cycle](docs/concepts/orpa-cycle.md) - Cognitive architecture details
- [Design Patterns](docs/design-patterns/README.md) - Implementation patterns

## Documentation

### Core Documentation
- [**Getting Started**](docs/getting-started/README.md) - Onboarding and evaluation
- [**Architecture**](docs/architecture/README.md) - System design and components
- [**Concepts**](docs/concepts/README.md) - Core concepts and methodologies
- [**Use Cases**](docs/use-cases/README.md) - Real-world applications

### Implementation
- [**Design Patterns**](docs/design-patterns/README.md) - Proven patterns for agent teams, communication, decisions, memory, and planning
- [**Best Practices**](docs/best-practices/README.md) - Agent design, deployment, testing, and team composition
- [**Adoption Guidance**](docs/adoption-guidance/README.md) - Incremental adoption and risk mitigation
- [**Decision Guides**](docs/decision-guides/README.md) - When to use MAGS and migration strategies

### Technical Reference
- [**Cognitive Intelligence**](docs/cognitive-intelligence/README.md) - Memory, learning, and adaptation
- [**Decision Orchestration**](docs/decision-orchestration/README.md) - Coordination and consensus
- [**Performance Optimization**](docs/performance-optimization/README.md) - Goals and optimization
- [**Integration & Execution**](docs/integration-execution/README.md) - External interfaces and tool orchestration
- [**Responsible AI**](docs/responsible-ai/README.md) - Policies, explainability, compliance

### Additional Resources
- [**Research Foundations**](docs/research-foundations/README.md) - Academic foundations across 10 research domains
- [**Technical Details**](docs/technical-details/README.md) - Implementation details and guides
- [**FAQ**](docs/faq.md) - Frequently asked questions
- [**Glossary**](docs/Glossary.md) - Terminology reference

## Repository Structure

```
Multi-Agent/
├── docs/                           # Documentation
│   ├── getting-started/            # Onboarding and evaluation
│   ├── architecture/               # System design
│   ├── concepts/                   # Core concepts
│   ├── use-cases/                  # Real-world applications
│   ├── design-patterns/            # Implementation patterns
│   ├── best-practices/             # Production guidance
│   ├── cognitive-intelligence/     # Memory and learning
│   ├── decision-orchestration/     # Coordination and consensus
│   ├── performance-optimization/   # Goals and optimization
│   ├── integration-execution/      # External interfaces
│   ├── responsible-ai/             # Governance and compliance
│   ├── adoption-guidance/          # Adoption strategies
│   ├── decision-guides/            # Decision frameworks
│   ├── research-foundations/       # Academic foundations
│   ├── technical-details/          # Implementation details
│   └── ...
├── src/                            # Source code
│   ├── agent_profiles/             # Pre-built agent templates
│   │   ├── *.md                    # Agent profile documentation
│   │   └── json/                   # Agent profile configurations
│   └── README.md
├── research/                       # Research papers
└── case-studies/                   # Implementation case studies
```

## Use Cases

| Industry | Scenario | MAGS Capabilities |
|----------|----------|-------------------|
| Manufacturing | Production line optimization | Multi-agent coordination, resource allocation consensus |
| Healthcare | Treatment plan development | Multi-specialist input, safety-critical decisions, audit trails |
| Finance | Credit approval process | Risk assessment, regulatory compliance, explainability |
| Energy | Grid management | Real-time coordination, autonomous operation, fault tolerance |
| Supply Chain | Multi-vendor coordination | Conflicting objectives, complex optimization, consensus |

See [Use Cases](docs/use-cases/README.md) for detailed scenarios.

## Contributing

This repository contains documentation and reference implementations for XMPro MAGS. The core agent technology remains proprietary to XMPro.

## License

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

**Important:** This repository contains open-source components licensed under the MIT License. However, the core XMPro AI agent technology, including its proprietary algorithms and implementations, remains the exclusive intellectual property of XMPro. The open-source materials provided herein serve as a framework and reference implementation.

## Support

- **Email:** support@xmpro.com
- **Documentation:** [docs/](docs/)
- **FAQ:** [docs/faq.md](docs/faq.md)

## References

- [[2304.03442] Generative Agents: Interactive Simulacra of Human Behavior](https://arxiv.org/abs/2304.03442)
- [Part 1: From Railroads to AI - The Evolution of Game-Changing Utilities](https://xmpro.com/part-1-from-railroads-to-ai-the-evolution-of-game-changing-utilities/)
- [Part 2: The Future of Work - Harnessing Generative Agents in Manufacturing](https://xmpro.com/part2-the-future-of-work-harnessing-generative-agents-in-manufacturing/)
- [Part 3: AI at the Core - LLMs and Data Pipelines for Industrial MAGS](https://xmpro.com/part-3-ai-at-the-core-llms-and-data-pipelines-for-industrial-multi-agent-generative-systems/)
- [Part 4: Pioneering Progress - Real-World Applications of MAGS](https://xmpro.com/part-4-pioneering-progress-real-world-applications-of-multi-agent-generative-systems/)
- [Part 5: Rules of Engagement - Establishing Governance for MAGS](https://xmpro.com/part-5-rules-of-engagement-establishing-governance-for-multi-agent-generative-systems/)

---

**Newsletter:** [The Digital Engineer](https://www.linkedin.com/build-relation/newsletter-follow?entityUrn=7107692183964585984) - Pieter van Schalkwyk on Multi-Agent Systems, Industrial AI, and Digital Transformation
