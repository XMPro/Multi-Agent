
## Introduction

Welcome to the comprehensive XMPro MAGS Glossary. This resource provides clear and concise definitions for terms related to Multi-Agent Generative Systems, generative AI agents, and the XMPro ecosystem. Our goal is to facilitate better understanding and communication among developers, researchers, and users working with XMPro's AI technologies.

This glossary covers a wide range of topics, including:
- Fundamental concepts in generative AI and multi-agent systems
- XMPro-specific terminology, tools, and components
- System architecture and technical implementation details
- Industry-standard AI and machine learning terms

Whether you're a seasoned AI professional or just starting your journey with XMPro's AI agents, this glossary aims to be your go-to reference for clarity and consistency in our rapidly evolving field.

## How to Use

Navigating and utilizing this glossary is straightforward:

1. **Browsing**: Terms are organized alphabetically under letter headings. Scroll through the document or use your browser's search function (usually Ctrl+F or Cmd+F) to find specific terms quickly.

2. **Structure**: Each entry follows this format:
   - **Term**: A concise definition, followed by any necessary elaboration or context.
   - *Example* (where applicable): A practical illustration of the term's usage.
   - *See also* (where relevant): Links to related terms within the glossary.

3. **Contributing**: We encourage community contributions to keep this glossary current and comprehensive. To add or modify entries:
   - Fork the repository
   - Make your changes in your forked version
   - Submit a pull request with a clear description of your additions or modifications

4. **Staying Updated**: Watch this repository to receive notifications about updates and new entries.

5. **Discussions**: For queries about specific terms or suggestions for new entries, please use the GitHub Discussions feature in this repository.

Remember, this glossary is a living document. Your input and expertise help make it an invaluable resource for the entire XMPro AI community.

---

## Terms

### A

**A2A (Agent2Agent Protocol)**: An open standard by Google Cloud that enables AI agents to communicate and collaborate across different platforms and frameworks using JSON-RPC 2.0 over HTTP(S). Agents discover each other through "Agent Cards" and can manage shared, stateful tasks with enterprise-grade security.

**ACP (Agent Communication Protocol)**: An open standard by IBM Research under the Linux Foundation that defines a RESTful API for agent interoperability. It enables agents from different frameworks to work together through standardized HTTP communication with async-first design and optional SDK requirements.

**Agency Protocol (Emerging)**: An experimental decentralized trust infrastructure where autonomous agents issue cryptographically signed promises backed by staked credits that can be slashed on misbehavior. Unlike communication protocols (A2A, ACP, MCP) that focus on message exchange and transport, Agency Protocol provides a trust and commitment layer focused on incentives, accountability, and reputation. The protocol uses game-theoretic mechanisms to make promise-keeping a Nash equilibrium, enabling credible commitments between agents without central authority. Design focuses on staking, slashing, verifiable assessments, and incentive alignment rather than message formats or runtime interoperability. Currently in yellow paper stage and not yet mainstream or standardized through organizations like the Linux Foundation. Potential future applications in MAGS include inter-enterprise agent collaboration, contractor agent governance, and high-stakes autonomous decisions requiring economic accountability. *See also*: A2A, ACP, Accountability, Nash Equilibrium, Consensus Mechanisms, Deontic Principles.

**Adaptation Factor**: A component that identifies specific conditions requiring plan modification, including type, description, impact level, and recommended actions.

**Adaptation Mechanism**: The process by which agents modify their behavior, knowledge, or strategies based on experience and changing conditions.

**Adaptation Type**: Classification of events that trigger replanning (ResourceChange, TimeConstraint, GoalAchievement, NewInformation).

**Agent**: An autonomous entity within the MAGS system capable of perceiving its environment, making decisions, and taking actions to achieve goals. There are two main types of agents in XMPro MAGS:

   1. **Content Agents**: LLM-based agents that focus on creating and managing information using Large Language Models for content generation, curation, and organization. They excel at tasks such as compiling reports, maintaining knowledge bases, creating documentation, and processing technical documents. Primarily LLM-powered (~80-90%).
   
   2. **Cognitive Agents**: ORPA-based agents that use the full cognitive architecture (Observe, Reflect, Plan, Act) for complex reasoning and autonomous decision-making. They analyze operational data, evaluate options, and make informed decisions based on deep knowledge of processes, quality standards, and operational metrics. These agents form the backbone of MAGS in industrial settings, implementing ~90% business process intelligence with ~10% LLM utility.
   
   3. **Hybrid Cognitive Agents**: Agents that combine full ORPA cognitive architecture with enhanced content generation capabilities, enabling end-to-end workflows that include analysis, documentation, and action.
   
   4. **Assistant Agents**: Serve as the primary interface between human operators and the technical systems. They understand natural language requests, translate them into system actions, and return results in user-friendly formats while maintaining awareness of user roles and access permissions.

   All agents work collaboratively within teams to optimize complex industrial processes and enhance productivity while operating under Rules of Engagement that ensure safe and ethical behavior.

**Agent Action**: A specific operation that an agent can perform, defined by a name, parameters, and whether it should return a result.

**Agent Activity Metrics**: Performance measurements tracking memories processed, messages handled, plans generated, and conversations managed by an agent.

**Agent Brain**: The core cognitive component of XMPro MAGS agents that implements the memory cycle and reasoning capabilities, enabling agents to observe, reflect, plan, and act in their environment.

**Agent Instance**: An active, running instance of an agent with a specific profile, capable of executing tasks, using tools, and interacting with other agents.

**Agent Memory**: A record of an agent's experiences, observations, reflections, plans, and decisions, stored with metadata such as importance, surprise score, and confidence.

**Agent Profile**: A configuration that defines an agent's capabilities, characteristics, permissions, behavioral parameters, and tool access rights. It serves as a template for creating agent instances.

**Agent Profile Templates**: Reusable configuration templates that define standard agent behaviors, capabilities, and constraints. These templates enable rapid deployment of agent instances across multiple operational contexts while maintaining consistency in governance and performance standards.

**Agent Status**: The current operational state of an agent instance (e.g., active, idle, processing).

**Agent Team**: A collection of agents working together toward common objectives, with defined roles, communication protocols, and consensus configurations.

**Agent Trajectory**: The path an agent takes through systems and entities during an ORPA cycle, recording which entities were accessed, in what order, and in what context. Agent trajectories are analyzed to discover decision patterns and organizational structure. Multiple trajectories reveal co-occurrence patterns (which entities are accessed together), typical decision flows, and structural equivalences. *See also*: Decision Trace, Learned Ontology, ORPA Cycle.

**Agent Type**: A classification of agents based on their primary architecture and function (Content, Cognitive, Hybrid Cognitive, Assistant).

**Agent-Washing**: The practice of rebranding simple automation, basic workflows, or coded systems as "intelligent agents" without implementing the cognitive capabilities required for true agency. This misleading practice obscures the distinction between genuine AI agents and enhanced traditional automation.

**AgentOps**: A holistic approach to developing, deploying, and managing AI agents in industrial environments, bringing DevOps principles to AI agent management through lifecycle management, continuous improvement, and human-AI collaboration.

**APEX (Agent Platform EXperience)**: XMPro's internal, proprietary management platform for Multi-Agent Generative Systems that provides agent lifecycle management, governance frameworks, and observability capabilities for industrial AI deployment. APEX is not publicly available.

**Approval Voting**: A consensus algorithm where participants can vote for multiple options in a decision-making process.

**ARIA (Accessible Rich Internet Applications)**: A set of attributes that can be added to HTML elements to improve the accessibility of web content and applications. In XMPro MAGS, ARIA is implemented in the web UI pages to enhance their accessibility for users relying on assistive technologies.

**Assistant Agents**: AI agents that serve as the primary interface between human operators and technical systems. They understand natural language requests, translate them into system actions, and return results in user-friendly formats while maintaining awareness of user roles and access permissions. Assistant Agents offer the most accessible entry point for organizations starting with intelligent automation.

### B

**Bayesian Inference**: A statistical method for updating probabilities based on new evidence, fundamental to MAGS confidence scoring and uncertainty quantification.

**Behavioral Adaptation**: The process by which agents adjust their actions and strategies based on performance monitoring and feedback.

**Bernoulli's Utility Theory**: The foundational principle (1738) that people value outcomes based on utility (satisfaction) rather than absolute value, exhibiting diminishing returns. Forms the basis for MAGS objective functions and decision-making.

**Borda Count**: A consensus algorithm where participants rank options and points are assigned based on rankings to determine the winner.

**Byzantine Fault Tolerance**: The ability of a distributed system to reach consensus even when some components fail arbitrarily or maliciously. MAGS uses Byzantine consensus (3f+1 agents to tolerate f failures) for safety-critical decisions.

**Bounded Autonomy**: A framework where AI systems operate independently within well-defined constraints, maintaining freedom of action within predetermined safe envelopes while preserving human agency over boundary conditions. This approach ensures that agents can adapt to changing conditions while remaining within appropriate operational limits.

**Brain-Inspired Architecture**: An AI agent design approach that mirrors the structure and function of the human brain, incorporating specialized cognitive modules for memory, reasoning, perception, and action that work together in a coherent framework.

**BrainGraph**: XMPro's graph-based memory architecture that stores and connects agent observations, reflections, plans, decisions, and actions. This system enables agents to build contextual understanding and learn from collective experiences across the agent team.

### C

**Calculation Method Type**: Defines the algorithm used to calculate confidence scores (General, ObservationConfidence, ReflectionConfidence, PlanningConfidence, ConversationObservationConfidence).

**Carroll Industrial AI Agent Framework**: An evaluation framework for assessing true AI agency in industrial applications, based on the ability to learn from experience, make autonomous decisions within defined boundaries, and adapt strategies based on changing conditions. This framework helps distinguish genuine agents from "agent-washing" implementations.

**Causal Analysis**: The process of identifying cause-and-effect relationships in industrial systems to understand what events lead to specific outcomes, enabling better decision-making and problem prevention.

**Cognitive Agents**: ORPA-based AI agents that implement the full cognitive architecture (Observe, Reflect, Plan, Act) for autonomous reasoning and strategic decision-making in complex, dynamic environments. These agents use formal planning, optimization algorithms, and decision theory—not just LLM generation—to achieve optimal outcomes. They embody ~90% business process intelligence (decision-making, planning, memory, optimization) and only ~10% LLM utility (communication and explanation). Cognitive Agents form the backbone of MAGS in industrial settings, enabling continuous learning, adaptation, and improvement through sophisticated memory systems and research-grounded decision frameworks.

**Coherent Causation**: The principle that value in complex systems emerges from the aligned interaction of system elements across multiple scales of organization, focusing on enhancing the coherence of interactions rather than optimizing individual components.

**Communication Decision**: A structured decision about whether and how to communicate with other agents, including target selection and content determination.

**Communication Decision Type**: Classification of communication approaches (Direct to specific agents, Team-wide to all team members).

**Communication Message**: A structured data object exchanged between agents, containing sender/receiver information, content, metadata, and authorization tokens.

**Communication Protocol**: The rules and formats governing how agents exchange information and interact with each other.

**Communication Type**: The classification of a message based on its purpose (DirectMessage, Request, Response, Alert, Broadcast, Agreement, Disagreement, etc.).

**Composite AI**: An integrated approach that combines multiple AI technologies including Causal AI, Predictive AI, Generative AI, First Principles Models, and Symbolic AI to solve complex industrial problems more effectively than any single AI technology alone.

**Confidence Evaluation**: An assessment of the reliability or certainty of an agent's memory, decision, or action.

**Confidence Level**: A categorization of confidence (Low, Medium, High) that determines whether additional validation is required.

**Confidence Score**: A numerical representation of an agent's certainty about a memory, decision, or action, including detailed reasoning factors.

**Conflict Report**: A detailed record of conflicts identified between draft plans during consensus processes, including affected resources, agents, and resolution status.

**Conflict Type**: Classification of conflicts in consensus processes (ObjectiveFunction conflicts, Other types).

**Consensus Algorithm**: See Consensus Protocol.

**Consensus Detector**: A component that analyzes planning decisions to determine when consensus is needed based on objective function relationships and confidence thresholds.

**Consensus Manager**: A component that coordinates consensus processes between agents, tracking votes and determining outcomes.

**Consensus Option**: A potential choice in a consensus decision-making process, with an identifier, description, and vote counts.

**Consensus Process**: A structured decision-making procedure where multiple agents vote on options to reach agreement through defined protocols.

**Consensus Protocol**: The method used to determine when agreement has been reached (SimpleMajority, WeightedMajority, Unanimous, BordaCount, ApprovalVoting, Supermajority, Cumulative).

**Consensus Result**: The outcome of a consensus process, including the winning option, vote counts, and supporting data.

**Consensus Round**: A phase in collaborative iterative consensus where agents submit draft plans, identify conflicts, and work toward resolution.

**Consensus Status**: The current state of a consensus process (Created, InProgress, Consensus, Timeout, Cancelled, Deadlocked).

**Consensus Threshold**: The minimum level of agreement required to consider consensus achieved in a decision-making process.

**Consensus Trigger Type**: The reason that initiated a consensus process (None, TeamObjective, HumanInitiated, LowConfidence).

**Consensus Vote**: A record of an agent's preference in a consensus process, including justification, weight, and timestamp.

**Constraint Level**: A classification of the importance of rules or limitations (NonNegotiable, CriticalBusiness, Important, Desirable).

**Contractor Model**: XMPro's approach to integrating external AI frameworks (like AutoGen, LangGraph, CrewAI) as specialized service providers within the MAGS ecosystem. External agents function as "contractors" for specific tasks while operating under XMPro's governance framework.

**Content Agents**: LLM-based AI agents that focus on creating and managing information using Large Language Models for content generation, curation, and organization. They excel at tasks such as compiling reports, maintaining knowledge bases, creating documentation, processing technical documents, and turning raw information into structured formats that support operational decisions. Content Agents are primarily LLM-powered (~80-90%) with limited cognitive architecture, operating under supervised conditions with human review typical for their outputs.

**Content Processing**: The system for analyzing, categorizing, and extracting information from various types of content.

**Content Processor Type**: A classification of specialized content processing strategies (FailureMode, TechnicalReport, MaintenanceProcedure, EquipmentSpecification, IncidentReport, Manual, Generic).

### D

**Database Manager**: A component that handles all database operations including memory storage, retrieval, and management across different database types.

**DataStreams**: XMPro's visual, no-code platform for creating real-time data processing pipelines that serve as the foundation for MAGS agent deployment, providing the separation of control between agent reasoning and execution.

**DataStream Designer**: XMPro's visual development environment for building real-time data processing pipelines using drag-and-drop components. This platform enables subject matter experts to create and modify agent deployments without coding requirements.

**Decision Agents** *(formerly)*: See **Cognitive Agents**. The term "Decision Agents" has been replaced with "Cognitive Agents" to better emphasize the ORPA-based cognitive architecture and the ~90% business process intelligence that distinguishes these agents from LLM wrappers. This terminology change clarifies that these agents use sophisticated cognitive frameworks for autonomous reasoning, not just LLM-based decision generation.

**Decision Intelligence**: The discipline of improving decision-making by understanding and engineering the decisions themselves rather than just automating processes. It focuses on determining the right actions based on current conditions, historical data, and defined objectives.

**Decision Making**: The process by which agents evaluate options and select actions based on goals, constraints, and available information.

**Decision Parameters**: Configuration settings that govern how an agent makes decisions, including planning cycles and thresholds.

**Decision Trace**: A complete record of a decision with full context, reasoning, precedents, and outcomes—captured automatically as MAGS agents execute their ORPA cycles. Unlike simple logs, decision traces capture not just what happened, but why it was allowed to happen, including observations that triggered the decision, reasoning that led to it, precedents that informed it, policies evaluated, exceptions granted, and outcomes validated. Decision traces are stored in the XMPro AO Platform DecisionGraph using PROV-O (W3C Provenance Ontology) for complete auditability. *See also*: DecisionGraph, Agent Trajectory, Learned Ontology.

**Decision Type**: Classification of decisions in the system (Planning decisions made by single agents, Consensus decisions involving multiple agents).

**DecisionGraph**: A hybrid ontology system in the XMPro AO Platform that combines industry-standard ontologies (ISO 14224, IDO, ISA-95) with learned decision patterns discovered from MAGS agent behavior. The DecisionGraph stores decision traces, enables precedent search, discovers patterns from agent trajectories, validates patterns against standards, and supports decision simulation. It provides both interoperability (through standards) and adaptability (through learning). *See also*: Decision Trace, Learned Ontology, Hybrid Ontology.

**Deontic Principles**: A branch of logic that deals with duty, obligation, and permission. In XMPro MAGS, these principles establish clear rules for AI agents regarding what they must do (obligations), what they can do (permissions), and what they must not do (prohibitions).

**Deontic Logic**: A branch of modal logic dealing with obligation, permission, and prohibition. In MAGS, deontic logic provides formal foundations for Rules of Engagement, enabling verifiable compliance and explainable governance.

**Deontic Rules**: Ethical guidelines and behavioral constraints that govern what actions are permitted, obligatory, or forbidden for agents. Five types: Obligation (O), Permission (P), Prohibition (F), Conditional (C), and Normative (N).

**Deontic Token**: A permission object that authorizes specific types of communication between agents with defined scope and expiration.

**Digital Factory**: A modern manufacturing concept that integrates digital technologies, IoT sensors, data analytics, and automation to create intelligent, connected production environments capable of real-time optimization and adaptive manufacturing.

**Digital Twin**: A real-time digital representation of physical assets, processes, or systems that enables monitoring, analysis, and optimization through continuous data integration and modeling.

**Draft Plan**: A preliminary plan submitted by an agent during consensus processes, extending the base Plan class with versioning and collaboration features.

### E

**Ebbinghaus Forgetting Curve**: The principle (1885) that memory decays exponentially over time without reinforcement. MAGS uses this for intelligent memory decay and cleanup, with importance-adjusted decay rates.

**Emergence Architecture**: The deliberate design of conditions that allow valuable system properties to emerge from component interactions, rather than attempting to impose those properties through direct intervention.

**Episodic Memory**: Memory of specific events with temporal context ("what happened when"). In MAGS, stored in time series databases for temporal queries and trend analysis.

**Emergent Optimization**: Solutions that arise from collective agent behavior rather than predetermined algorithms, allowing systems to discover solutions that transcend traditional optimization methods.

**Embedding Constants**: Standardized values and configurations used across different embedding providers in the system.

**Enum Extensions**: Utility methods that extend enum functionality with additional operations and conversions.

### F

**Factory Message Broker**: A factory pattern implementation that creates appropriate message broker instances based on configuration.

**Foundation Agent**: An AI agent that demonstrates genuine agency through the ability to learn from experience, make autonomous decisions within defined boundaries, and adapt strategies based on changing conditions. Foundation agents require specific cognitive modules working together in a coherent architecture.

### G

**Generative Agents**: Advanced AI entities designed to autonomously recognize patterns, generate predictions, and perform tasks by emulating human reasoning. Unlike traditional computational software, generative agents are trained on extensive data sets to understand context and make informed decisions.

**Generative Integration**: An advanced approach to data and application integration that leverages generative AI (GenAI) and large language models (LLM) to securely automate the creation of integration pipelines and streamline the process of connecting disparate systems and data sources.

**Global Exception Handler**: A centralized component for managing and logging exceptions across the entire MAGS system.

**Goal Formation**: The process of defining objectives, success criteria, and constraints for agent planning.

**Graph Database Type**: Enumeration of supported graph databases (Neo4j, AzureCosmosDbGremlin, AmazonNeptune, Memgraph, JanusGraph, OrientDB, TigerGraph, Dgraph, ArangoDB, NebulaGraph, and many others).

**Graph Queries**: Standardized query definitions for graph database operations across different graph database implementations.

**Graph Query Exception**: Specialized exception type for handling graph database operation errors.

**Graph Schema**: The structure definition for graph database entities, relationships, and properties used in the MAGS system.

### H

**Hallucination**: A phenomenon in large language models where the AI generates false, fabricated, or nonsensical information that appears plausible. This occurs due to the model's lack of true understanding, instead relying on learned patterns to produce text.

**Human Intervention Type**: Classification of human involvement required in consensus processes (ConsensusBlock when consensus is triggered during cooldown periods).

**Hybrid Cognitive Agents**: AI agents that combine full ORPA cognitive architecture with enhanced content generation capabilities. These versatile agents handle tasks requiring both autonomous reasoning and sophisticated content creation, enabling end-to-end workflows from analysis through documentation to action. Hybrid Cognitive Agents maintain the full cognitive foundation (~90% business intelligence) while integrating advanced LLM capabilities for comprehensive problem-solving without handoffs between specialists.

**Hybrid Agents** *(formerly)*: See **Hybrid Cognitive Agents**. The term has been updated to "Hybrid Cognitive Agents" to clarify that these agents are built on a cognitive architecture foundation (full ORPA cycle) with enhanced content capabilities, rather than a simple mix of content and decision features.

**Hybrid Ontology**: An approach that combines prescribed ontologies (industry standards like ISO 14224, IDO, ISA-95) with learned ontologies (patterns discovered from agent behavior). The hybrid approach provides both interoperability (through standards) and adaptability (through learning). In the XMPro DecisionGraph, standards define equipment types and relationships while learned patterns capture decision flows and success factors. *See also*: Learned Ontology, DecisionGraph, Decision Trace.

### I

**Intelligent Digital Twin**: An advanced digital twin that incorporates AI agents and real-time decision-making capabilities, enabling autonomous optimization and adaptive responses to changing conditions.

**Integration Patterns**: Standardized approaches for connecting different system components, particularly for LLM, memory, and communication integration.

### K

**Knowledge Adaptation**: The process by which agents update their understanding and patterns based on new information and experiences.

**Knowledge Integration**: The incorporation of new information into an agent's existing knowledge base, establishing relationships and resolving conflicts.

### L

**Language Model**: The AI model used by agents for natural language understanding and generation, supporting multiple providers.

**Large Language Models (LLMs)**: Advanced artificial intelligence models trained on vast amounts of text data. In Multi-Agent Generative Systems, LLMs are used by Content Agents primarily for content generation and curation (~80-90% of their capability), while Cognitive Agents utilize them as the ~10% utility layer for communication and explanation, with the ~90% intelligence layer provided by business process intelligence (decision-making, planning, memory, optimization).

**Learned Ontology**: An organizational structure that emerges from observing how work actually happens, rather than being prescribed upfront by humans. In the XMPro DecisionGraph, learned ontologies are discovered by analyzing MAGS agent trajectories—which entities agents access together, in what order, with what success rates. Patterns emerge from accumulated agent behavior and are validated against industry standards (ISO 14224, IDO). This approach captures tacit knowledge and adapts continuously as operations evolve. *See also*: Hybrid Ontology, Agent Trajectory, Decision Trace.

**Lightweight Agent Instance**: A simplified representation of an agent used in team contexts, containing only essential information for efficient operations.

**LLM Constants**: Standardized values and configurations used across different language model providers.

### M

**MAGS (Multi-Agent Generative Systems)**: Dynamic teams of virtual workers powered by advanced artificial intelligence that work independently and collaboratively to optimize operational outcomes. MAGS combine Large Language Models with specialized AI agents to simulate complex processes, optimize operations, and adapt to changing conditions.

**MAGS Components**: The platform's foundation built on multi-agent collaboration, including:
   - Agent Profile (Template)
   - Agent (Instance of a profile)
   - Task & Task Management
   - Rules of Engagement
   - Tools
   - Functions
   - Processes
   - Teams
   - Collaboration
   - Reasoning Styles
   - Memory Systems

**Managed Heap**: The portion of memory used by .NET managed objects, tracked as part of system resource metrics.

**MCP (Model Context Protocol)**: An open standard by Anthropic that standardizes how AI applications connect to external data sources and tools. Often described as "USB-C for AI," it provides a universal protocol for connecting LLMs with context through a client-server architecture supporting both local and remote deployments.

**Memory Consolidation**: The process of converting short-term memories to long-term storage, identifying patterns and relationships.

**Memory Cycle**: The system that manages an agent's memory processing, including significance calculation, storage, and retrieval.

**Memory Metrics**: Detailed measurements of memory usage including managed heap, working set, memory load, and pressure indicators.

**Memory Parameters**: Configuration settings that govern how an agent processes and manages memories.

**Memory Significance**: A measure of how important a memory is, based on relevance, novelty, and potential impact.

**Memory Type**: A classification of agent memories (Observation, Reflection, Plan, Decision, Action, Synthetic).

**Memory Vector Item**: A data structure that combines memory content with vector embeddings for semantic search operations.

**Message Broker**: A component that handles message routing and delivery between agents using protocols like MQTT, OPC UA, or DDS.

**Mixture of Agents (MoA)**: A novel approach in artificial intelligence that leverages multiple large language models (LLMs) to enhance overall performance and capabilities through layered architecture, iterative refinement, diverse model integration, and collaborative intelligence.

**Model Provider**: The source of the language model used by an agent (OpenAI, AzureOpenAI, Anthropic, Google, AWSBedrock, Grok, Mistral, Meta, Cohere, HuggingFace, OpenRouter, Ollama).

**Multi-Agent Generative Systems (MAGS)**: See MAGS.

**Multi-Objective Optimization**: The process of optimizing multiple competing objectives simultaneously. MAGS uses Pareto optimization to generate non-dominated solutions and enable explicit trade-off analysis.

**Multi-Store Memory Model**: The cognitive architecture (Atkinson-Shiffrin 1968) with sensory, short-term, and long-term memory stores. MAGS implements this with cache (short-term) and polyglot persistence (long-term).

### N

**Nash Equilibrium**: A stable state in multi-agent systems (Nash 1950) where no agent can improve by changing strategy alone. MAGS uses Nash equilibrium for fair resource allocation and consensus solutions.

**Neo4j Graph**: Implementation of graph database operations specifically for Neo4j, including connection management and query execution.

**Neptune Graph**: Implementation for Amazon Neptune graph database with support for both Gremlin and SPARQL query languages.

**Networked Autonomy**: The ability for specialized agents to communicate, collaborate, and coordinate across traditional domain boundaries through standardized protocols while maintaining their independence and specialized capabilities.

### O

**Objective Component**: An individual metric that contributes to an objective function, with its own weight and optimization direction.

**Objective Direction**: Whether a performance metric should be minimized (lower is better) or maximized (higher is better).

**Objective Function**: A mathematical formula that combines multiple performance metrics to evaluate agent or team performance and guide decision-making toward specific organizational goals.

**Objective Function Type**: Whether an objective function applies to an individual agent or a team.

**Objective Threshold**: Value ranges that define different performance levels for components of an objective function.

**Observation Memory**: A record of direct experiences, environmental data, and event observations.

**OpenTelemetry**: An observability framework for cloud-native software, providing a collection of tools, APIs, and SDKs for instrumenting, generating, collecting, and exporting telemetry data.

**OpenTelemetry Setup**: Configuration and initialization of telemetry collection for monitoring and observability.

**Operation Model Change**: Transformation of how work gets done within an organization, as opposed to Business Model Change which focuses on new revenue streams. This includes shifts from scheduled to condition-based maintenance, reactive to predictive operations, or centralized to distributed decision-making.

**Organizational Rules**: Guidelines and protocols specific to the organizational context in which agents operate.

**ORPA (Observe, Reflect, Plan, Act)**: The cognitive cycle used by XMPro MAGS agents to process information and make decisions. This structured approach enables agents to continuously monitor operations, identify patterns, develop strategies, and take appropriate actions.

**OT/IT Integration**: The bridging of Operational Technology (equipment, sensors, control systems) with Information Technology (enterprise systems, databases, networks) to create unified data flows and coordinated decision-making across traditionally separate domains.

### P

**Parametric Agents**: AI agents that use well-defined parameters to create bounded, governable intelligence rather than embedding operational knowledge in code. This approach separates what an agent can do from how it should operate, enabling configuration by domain experts without coding requirements.

**Participation Status**: The status of an agent in a consensus process (Invited, Accepted, Declined, DraftSubmitted, ConflictsAcknowledged, Voted, ResultAcknowledged).

**Performance Level**: A categorization of achievement against objectives (e.g., poor, acceptable, excellent).

**Performance Metrics**: Quantitative measures used to evaluate agent or team effectiveness.

**Permission Level**: Classification of authorization levels in the deontic system (Low, Normal, High, Critical).

**Plan**: A structured sequence of actions designed to achieve a goal, with associated metadata and status tracking.

**Plan Action**: An individual action within a plan task, including name, numeric effects, and preconditions.

**Plan Adaptation**: The process of modifying plans in response to changing conditions, new information, or performance feedback.

**Plan Adaptation Detector**: A component that monitors plan execution and identifies when adaptation is needed.

**Plan Adaptation Models**: Data structures and algorithms used to represent and process plan adaptation requirements.

**Plan Executor**: A component that manages the execution of plans, tracking progress and handling errors.

**Plan Status**: The current state of a plan (Draft, Created, InProgress, Updated, Suspended, Completed, Failed, NoTasks, Undefined).

**Plan Task**: An individual action or operation within a plan, with its own status, dependencies, and resource requirements.

**Planning Cycle**: A recurring process where agents assess their situation and formulate or adapt plans.

**Planning Decision**: A record of a decision to create or modify a plan, including the reasoning, context, and confidence assessment.

**Planning Step Type**: Classification of steps in the planning process (UnderstandProblem, GeneratePDDLPlan, BreakDownTasks).

**Planning Strategy**: An approach to generating and optimizing plans (e.g., sequential, parallel, hierarchical, adaptive).

**Planning Strategy Factory**: A factory pattern implementation for creating appropriate planning strategies based on requirements.

**Planning Trigger Reason**: The cause that initiated a planning or replanning process (GoalNotMet, EnvironmentalChange, NewInformation, ResourceOptimization, ConflictResolution, PeriodicUpdate, FutureEventAnticipation, ExternalInstruction, InvalidPlan, Other).

**Pool Metrics**: Performance measurements for database connection pools and resource management.

**Pareto Optimality**: A state where improving one objective requires sacrificing another (Pareto 1896). MAGS generates Pareto-optimal solutions for multi-objective decisions, enabling explicit trade-off analysis.

**Paxos**: A consensus algorithm (Lamport 1998) for asynchronous distributed systems. MAGS uses Paxos-style consensus for distributed agent coordination without timing assumptions.

**PDDL (Planning Domain Definition Language)**: A formal language (McDermott et al. 1998) used to describe planning problems in artificial intelligence, providing a standardized way to encode planning problems and serving as the de facto standard for representing planning problems in AI research.

**Polyglot Persistence**: The practice (Fowler 2011) of using different databases for different data types. MAGS uses vector databases for semantic memory, graph databases for structural memory, time series databases for episodic memory, and cache for short-term memory.

**Prospect Theory**: The behavioral economics theory (Kahneman & Tversky 1979) that people evaluate outcomes relative to reference points with loss aversion. MAGS uses prospect theory for context-aware significance assessment.

**Predictive Maintenance**: An industrial maintenance strategy that uses data analysis, sensor monitoring, and machine learning to predict equipment failures before they occur, enabling proactive maintenance scheduling and reducing unplanned downtime.

**Prompt Manager**: A component that manages and retrieves prompt templates for different agent operations and LLM interactions.

### Q

**Qdrant**: A vector similarity search engine with extended filtering support, one of the supported vector database options.

### R

**RAG (Retrieval-Augmented Generation)**: A technique that enhances language model responses with information retrieved from a knowledge base, enabling agents to access and incorporate relevant information from organizational documents and systems.

**Raft**: An understandable consensus algorithm (Ongaro & Ousterhout 2014) with leader election and log replication. MAGS uses Raft-style consensus for team coordination with automatic failover.

**Recent Memory Cache**: A high-performance cache for frequently accessed recent memories to improve retrieval speed.

**Reflection Memory**: A record of processed insights, pattern recognition, and learning outcomes.

**Retrieval Mechanism**: The system for finding and accessing relevant memories based on context and query.

**Research Agents**: AI systems designed to handle discrete, on-demand knowledge tasks rather than continuous operations. These agents excel at one-time research projects, content generation, and analysis tasks but lack the governance frameworks and continuous monitoring capabilities required for industrial environments.

**Rules of Engagement**: A structured framework that governs agent behavior through deontic principles, including obligations, permissions, prohibitions, conditional rules, and normative guidelines. These rules ensure ethical operations, maintain safety standards, and facilitate effective collaboration while providing boundaries for autonomous decision-making.

### S

**Safe Operating Envelope**: The defined boundaries within which agents can operate autonomously without human intervention. These boundaries are established through risk assessment and include technical, operational, and business constraints that ensure safe and effective agent behavior.

**SCADA (Supervisory Control and Data Acquisition)**: Industrial control systems used to monitor and control distributed equipment and processes. SCADA systems collect real-time data from sensors and devices, providing the operational data that MAGS agents use for decision-making.

**Segmentation Config**: Configuration settings for breaking down content into manageable segments for processing.

**Separation of Control**: An architectural principle that separates agent decision-making from action execution, ensuring that agents can think, plan, and request actions, but the execution system determines what actually happens. This approach is essential for safety in industrial environments.

**Shared Decision Space**: A collaborative framework where multiple agents can access and contribute to collective decision-making processes, enabling coordination and consensus-building across agent teams.

**Semantic Memory**: General knowledge without temporal context ("what we know"). In MAGS, stored in vector databases for similarity-based retrieval and pattern matching.

**Shared Memory Space**: A collaborative memory architecture where agents can access and build upon observations, reflections, and decisions from other agents, creating collective intelligence and institutional knowledge.

**STRIPS**: The foundational AI planning system (Fikes & Nilsson 1971) that formalized planning as state-space search with preconditions and effects. PDDL is the modern evolution of STRIPS.

**Shared Telemetry Components**: Common telemetry infrastructure shared across different system components.

**Significance Calculation**: The process of determining the importance of a memory based on various factors.

**Simple Majority**: A consensus algorithm requiring more than 50% of participants to agree on an option.

**Strategy Development**: The process of generating options, assessing risks, and allocating resources in planning.

**Stream Host Architecture**: XMPro's scalable deployment framework that enables the instantiation of multiple agent instances based on agent profiles. This architecture supports horizontal scaling and efficient resource management across distributed industrial environments.

**Supermajority**: A consensus algorithm requiring a specified threshold (e.g., 2/3 or 3/4) to be reached.

**Surprise Score**: A measure of how unexpected or novel a memory or observation is.

**Synthetic Memory**: Artificially created memories used for training, knowledge injection, or enhancing agent capabilities, enabling agents to learn from edge cases that are difficult to replicate in real-world scenarios.

**System Options**: Configuration parameters that control system-wide behavior and settings.

**System Resource Metrics**: Comprehensive measurements of system performance including memory, tool usage, and error tracking.

### T

**Task Status**: The current state of a plan task (Created, Submitted, Working, InputRequired, Completed, Canceled, Failed, Unknown).

**Team**: A group of agents working together toward common objectives, with defined roles, communication protocols, and consensus configurations.

**Telemetry Flusher**: A component responsible for ensuring telemetry data is properly sent to monitoring systems.

**Telemetry Setup**: Configuration and initialization of telemetry collection across the system.

**Token Probability**: Statistical information about token likelihood in language model responses.

**Tool**: A specialized component that provides specific capabilities to agents, such as database operations, data analysis, or external service integration.

**Tool Call**: A structured request to execute a specific tool with defined parameters and expected outputs.

**Tool Library**: A collection of tools available to agents, with access controlled by permissions and configurations.

**Tulving's Memory Types**: The distinction (1972) between episodic (temporal experiences) and semantic (atemporal knowledge) memory. MAGS implements both types with appropriate storage and retrieval strategies.

**Topics**: Standardized message broker topic definitions for routing different types of messages.

**Trust Factor**: A measure of the reliability of information sources, affecting how memories are weighted and processed.

### U

**Unanimous**: A consensus algorithm requiring all participants to agree on the same option. MAGS uses unanimous consensus for highest-criticality decisions requiring complete stakeholder alignment.

**Utility Function**: A mathematical representation of preferences that maps outcomes to numerical values. MAGS uses utility functions (linear, logarithmic, exponential, piecewise) for multi-objective optimization. *See also*: Objective Function, Multi-Objective Optimization, Pareto Optimality.

**Utility Text Processing**: A comprehensive toolkit for text manipulation, parsing, and formatting operations throughout the system.

**Utility Tokenization**: Helper methods for token counting, text truncation, and token-aware text processing.

**Utility Type Conversion**: Helper methods for converting between different data types safely and efficiently.

### O

**OEE (Overall Equipment Effectiveness)**: A key performance indicator in manufacturing that measures the percentage of manufacturing time that is truly productive. OEE combines availability, performance, and quality metrics to provide a comprehensive measure of equipment efficiency, commonly used as an objective function for MAGS optimization.

### V

**Value Engineering**: A systematic approach to optimizing the relationship between function and cost in complex systems, focusing on creating conditions where value emerges from coherent system behavior rather than optimizing individual components.

**Vector Collection Type**: Classification of vector collections (agent-specific collections, team-wide collections).

**Vector Database Type**: Enumeration of supported vector databases (Milvus, Qdrant, MongoDbAtlas, AzureCosmosDb, Pinecone, Weaviate, Vespa, ChromaDb, RedisVectorSearch, Elasticsearch, OpenSearch, PostgreSqlPgVector, and many others).

**Vector Operations**: Mathematical techniques for semantic similarity calculation, memory clustering, and pattern recognition.

**Virtual Workers**: Another term for MAGS agents, emphasizing their role as autonomous team members that can perform complex tasks and make decisions within industrial operations.

### W

**Weighted Majority**: A consensus algorithm where votes are weighted by agent expertise, authority, or other factors.

**Working Set**: The total amount of physical memory (RAM) used by a process, including code, data, and shared libraries.

### X

**XMPro Multi-Agent Generative Systems (MAGS)**: 
MAGS (Multi-Agent Generative Systems) are dynamic teams of virtual workers powered by advanced artificial intelligence. These self-organizing teams work independently and collaboratively to optimize operational outcomes and achieve specified goals. Key features of MAGS include:

   - **Independence and Agency**: Each virtual worker functions autonomously, making decisions and taking actions independently within their defined scope.
   
   - **Planning and Reflection**: They can plan ahead, reflect on past actions, and adjust strategies accordingly, enabling continuous improvement.
   
   - **Anticipatory and Goal-Seeking**: They proactively identify and work towards operational objectives, always striving for optimal outcomes.
   
   - **Always-On Collaboration**: They operate 24/7, constantly monitoring, communicating, and responding to changes in their environment, ensuring seamless coordination.
   
   - **Adaptive Reasoning and Decision-Making**: They use advanced AI to analyze situations, solve problems, and make informed choices, adapting their execution techniques based on inputs and environmental considerations.
   
   - **Complex Workflow Execution**: They can handle and optimize intricate operational processes with minimal human intervention, streamlining complex tasks.
   
   - **Rules of Engagement**: Agents and teams operate under a structured set of deontic principles, including obligations, permissions, prohibitions, conditional rules, and normative guidelines. These rules govern their behavior, ensure ethical operations, maintain safety standards, and facilitate effective collaboration while providing a framework for autonomous decision-making within predefined boundaries.

   MAGS combines the power of large language models with specialized AI agents to simulate complex processes, optimize operations, and adapt to changing conditions. This makes them valuable tools for improving efficiency and driving innovation across various industries and operational scenarios. 

   The integration of deontic principles through the Rules of Engagement ensures that MAGS operates efficiently, ethically, and safely, particularly in critical industrial environments where reliability and accountability are paramount.
