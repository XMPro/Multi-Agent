# MAGS Implementation Guides

> Tactical guidance for configuring, deploying, and managing Multi-Agent Generative Systems.

---

## How to Use This Guide

This guide provides **tactical, hands-on implementation guidance** with specific parameter values, decision trees, and configuration checklists. Each section links to detailed implementation guides.

**Looking for strategic guidance?** See [Best Practices](../best-practices/README.md) for high-level principles and design philosophy.

**Need conceptual understanding?** See [Concepts](../concepts/README.md) for foundational explanations.

### Read by Role

- **Team Designers** (Cowork wizard users): Sections 1-6
- **Developers** (building on the MAGS framework): Sections 4-9
- **Operators** (managing deployed MAGS teams): Sections 7-10
- **Everyone**: Section 1 (Architecture Overview) and Section 10 (Common Anti-Patterns)

---

## 1. Architecture Overview

*Understand the fundamental building blocks before configuring anything.*

### 1.1 The ORPA Cycle — How Agents Think
Every MAGS agent operates on an Observe-Reflect-Plan-Act cycle. Understanding this cycle is essential before configuring any agent behaviour.
→ **[Full explanation: ORPA Cycle vs Planning Cycle](../concepts/orpa-vs-planning-cycle.md)**

### 1.2 Agent Types — Choosing the Right Type for the Job
MAGS has distinct agent types (Decision, Standard, Assistant) with different capabilities. Choose the right type before writing a single prompt.
→ **[Full explanation: Assistant Agent Type](../concepts/assistant-agent-type.md)**

### 1.3 Profiles vs Instances — The Template and the Deployment
The most common architectural mistake is creating one profile per instance. Understand the distinction before designing your team.
→ **[Full explanation: Profiles vs Instances](../concepts/profiles-vs-instances.md)**

---

## 2. Team Design

*How to structure a team of agents that work together effectively.*

### 2.1 Team Objectives vs Agent Objectives
**Practice**: Give each agent its own objective aligned with its role, not a copy of the team objective. The tension between agent objectives creates checks and balances.
→ **[Full explanation: Team vs Agent Objectives](../concepts/team-vs-agent-objectives.md)**

### 2.2 When to Use Consensus vs Communication
**Practice**: Use communication (lightweight messaging) for routine information sharing. Reserve consensus (formal negotiation with voting) for decisions that require binding multi-agent agreement.
→ **[Full explanation: Consensus vs Communication](../concepts/consensus-vs-communication.md)**

### 2.3 Team Size and Role Separation
**Practice**: Each agent should have a distinct, focused role. Don't combine roles that need independent judgment (e.g., never combine the economic optimiser and the safety validator). Don't split roles that share the same reasoning (e.g., don't create separate agents for reading temperature vs reading pressure).
→ **[Full guide: Team Size and Role Separation](team-size-role-separation.md)**

### 2.4 Decision Authority Levels
**Practice**: Define clear authority levels — what agents can do independently, what requires team consensus, what needs human approval, and what triggers immediate escalation. Document these in the team configuration.
→ **[Full guide: Decision Authority Levels](decision-authority.md)**

---

## 3. Agent Profile Design

*How to write effective agent profiles that produce reliable behaviour.*

### 3.1 System Prompts — Identity and Expertise
**Practice**: The system prompt defines WHO the agent is. Keep it focused on identity, expertise, and behavioural boundaries. Don't put operational instructions in the system prompt — those belong in behavioural rules.
→ **[Full guide: System Prompts](system-prompts.md)**

### 3.2 Behavioural Rules — The Deontic Framework
**Practice**: Use all four rule types systematically:
- **Obligations** (MUST DO): Non-negotiable actions the agent must always perform
- **Prohibitions** (MUST NOT DO): Actions the agent must never take
- **Permissions** (MAY DO): Optional actions the agent can choose to take
- **Conditional Duties** (IF...THEN): Context-dependent rules that activate under specific conditions
→ **[Full guide: Behavioural Rules](behavioural-rules.md)**

### 3.3 Profile Reuse — One Profile, Many Instances
**Practice**: Design profiles as reusable templates. If two agents differ only in WHERE they operate (different site, different unit, different shift), they should share a profile with different instances.
→ **[Full explanation: Profiles vs Instances](../concepts/profiles-vs-instances.md)**

### 3.4 Model Selection by Role
**Practice**: Match LLM capability to role complexity:
- **High-complexity roles** (Decision-Maker, Guardian): Use the most capable model (e.g., Opus/GPT-4)
- **Medium-complexity roles** (Analysts): Use a balanced model (e.g., Sonnet/GPT-4o)
- **Low-complexity roles** (Monitor, Executor): Use a fast, efficient model (e.g., Haiku/GPT-4o-mini)
→ **[Full guide: Model Selection](model-selection.md)**

### 3.5 Planning Cycle Interval
**Practice**: Set the planning cycle interval based on the process dynamics, not the LLM speed. If the process takes 15 minutes to respond to a change, a 15-minute planning cycle is appropriate. Shorter intervals waste LLM calls; longer intervals miss changes.
→ **[Full guide: Planning Cycle Interval](planning-cycle-interval.md)**

---

## 4. Measures, Utilities, and Objectives

*How to build the value chain from raw data to decision scores.*

### 4.1 The Three-Layer Chain
**Practice**: Always maintain the three distinct layers: Measure (raw value) → Utility Function (normalised value judgment) → Objective Function (combined decision score). Don't skip layers.
→ **[Full explanation: Measures, Utilities, and Objectives](../concepts/measures-utilities-objectives.md)**

### 4.2 Choosing Utility Function Types
**Practice**: Match the curve type to the value pattern:
- **Linear**: Each unit of improvement has equal value (e.g., profit per hour)
- **Logarithmic**: Diminishing returns (e.g., production throughput)
- **Exponential**: Excellence is disproportionately valuable (e.g., product quality)
- **Inverse Exponential**: Approaching limits is increasingly painful (e.g., safety measures)
→ **[Full guide: Utility Function Types](utility-function-types.md)**

### 4.3 Steepness Tuning
**Practice**: Start with moderate steepness (3.0-3.5) and adjust based on observed agent behaviour. If agents aren't cautious enough near limits, increase steepness. If agents are too conservative, decrease it. Use higher steepness for safety-critical agents (e.g., Guardian at 5.0 vs others at 3.5).
→ **[Full guide: Steepness Tuning](steepness-tuning.md)**

### 4.4 Avoiding Double-Counting
**Practice**: If a composite measure (like profit/hr) already includes a component (like steam cost), don't include the component separately in the objective function. Each real-world factor should influence the objective once.

---

## 5. Constraints

*How to define hard limits that agents must never violate.*

### 5.1 Constraints vs Utility Functions — Know the Difference
**Practice**: Use constraints for hard limits (safety, regulatory, equipment). Use utility functions for preferences (economic, quality targets). For safety-critical measures, use BOTH — a constraint as the hard floor and a utility function as the gradient toward safety.
→ **[Full explanation: Constraints vs Utility Functions](../concepts/constraints-vs-utilities.md)**

### 5.2 Constraint Priority Levels
**Practice**: Assign priorities deliberately:
- **Critical**: Safety and regulatory — never overridable
- **High**: Quality and operational — requires human escalation to override
- **Medium**: Performance targets — can be temporarily relaxed with justification
- **Low**: Preferences — can be relaxed freely
→ **[Full guide: Constraint Configuration](constraint-configuration.md)** (covers 5.2, 5.3, and 5.4)

### 5.3 Violation Actions
**Practice**: Match the violation action to the severity:
- **Block**: For constraints where violation would cause harm (safety, equipment limits)
- **Warn**: For constraints where human judgment is needed (cumulative limits, near-boundary operations)
- **Log**: For soft constraints where awareness is sufficient (performance targets)

### 5.4 Constraint-Measure Linkage
**Practice**: Every constraint must link to a specific measure. If you can't measure it, you can't constrain it. Ensure the measure's data source is reliable and timely enough to support the constraint.

---

## 6. Data and Tools

*How to connect agents to the real world.*

### 6.1 Tools vs Actions vs Data Streams
**Practice**: Design tools as generic, reusable capabilities (e.g., "read DCS tag"). Define actions as specific plan steps that use tools (e.g., "read tray 20 temperature"). Configure data streams as continuous information flows (e.g., "OPC-UA sensor readings every 10 seconds").
→ **[Full explanation: Tools, Actions, and Data Streams](../concepts/tools-actions-datastreams.md)**

### 6.2 Data Inventory First
**Practice**: Before designing agents, inventory what data is actually available. Agents can only work with data that exists. Use the MAGS Configuration Wizard's Data Inventory step to establish the data landscape before designing the system around it.
→ **[Full guide: Data Inventory First](data-inventory.md)**

### 6.3 Monitor as Data Gateway
**Practice**: In most teams, designate one agent (typically the Monitor) as the primary data gateway. Other agents receive data through the Monitor's state snapshots rather than reading directly from external systems. This creates a single, consistent data view and prevents multiple agents from independently loading external interfaces.
→ **[Full guide: Data Architecture Patterns](data-architecture.md)** (covers 6.3 and 6.4)

### 6.4 Independent Access for Safety-Critical Roles
**Practice**: Safety-critical agents (Guardian, Executor) should retain independent data access for validation and pre-action checks. Don't route their data through the same gateway as the optimisation agents — independence is essential for safety.

---

## 7. Memory and Learning

*How agents accumulate knowledge and use it for better decisions.*

### 7.1 Observations, Reflections, and Memories
**Practice**: Understand the three-tier memory system. Observations are raw perceptions. Reflections are synthesised insights. Both are stored as memories and retrieved by semantic similarity, not just chronological order.
→ **[Full explanation: Observations, Reflections, and Memories](../concepts/observations-reflections-memories.md)**

### 7.2 Significance Thresholds
**Practice**: Tune the reflection significance threshold based on the domain. Too low = too many reflections (noise). Too high = missed insights. Start at 0.6-0.7 and adjust based on the quality of reflections produced.
→ **[Full guide: Memory Configuration](memory-configuration.md)** (covers 7.2 and 7.3)

### 7.3 Memory Retention
**Practice**: Configure memory retention based on the decision cycle. If decisions are made every 15 minutes, the agent needs at least 2-3 hours of memory to see trends. If decisions are daily, it needs weeks of memory.

---

## 8. Planning and Execution

*How agents decide what to do and carry it out.*

### 8.1 Planning, Execution, and Adaptation
**Practice**: Understand the three distinct phases. Planning creates the roadmap. Execution follows it. Adaptation detects when it needs to change. Don't replan every cycle — only when adaptation says it's necessary.
→ **[Full explanation: Planning, Execution, and Adaptation](../concepts/planning-execution-adaptation.md)**

### 8.2 Constraint Validation Before Execution
**Practice**: Every plan should be validated against constraints before execution begins. Plans that would violate constraints are rejected, and the agent must revise. This is the safety net that prevents harmful actions.
→ **[Full guide: Execution and Timing](execution-timing.md)** (covers 8.2 and 8.3)

### 8.3 Move Spacing and Timing
**Practice**: Set move spacing based on process response time, not agent processing time. If the process takes 15 minutes to respond to a setpoint change, the agent should wait at least 15 minutes before evaluating the result — regardless of how fast the LLM can think.

---

## 9. Concurrent Operations

*How agents handle real-time data flow and parallel processing.*

### 9.1 Data Queuing and the "Latest State Wins" Pattern
**Practice**: MAGS agents don't process every event individually. Data accumulates in queues, and each agent cycle reads the full accumulated picture. Design agent logic to assess the current state and trends, not to react to individual data points.
→ **[Full explanation: Concurrent Data and Alert Handling](../concepts/concurrent-data-handling.md)**

### 9.2 Planning Lock and Cycle Skipping
**Practice**: If an agent is already in a planning cycle, new triggers are skipped (not queued). The next cycle will see all accumulated data. Don't design agent logic that depends on processing every trigger — design it to handle the latest state.

### 9.3 Critical Alert Escalation
**Practice**: For critical alerts that can't wait for the next planning cycle, use conditional duties with immediate messaging (escalation to humans, alerts to other agents). Don't rely on the planning cycle for time-critical responses.

---

## 10. Common Anti-Patterns

*Mistakes that are easy to make and hard to debug.*

| # | Anti-Pattern | Why It's Wrong | What to Do Instead |
|---|-------------|---------------|-------------------|
| 1 | **One profile per instance** | Creates maintenance burden; changes must be replicated across copies | One profile, many instances |
| 2 | **Same objective for all agents** | Eliminates checks and balances; no independent safety validation | Role-specific objectives with productive tension |
| 3 | **Skipping the utility layer** | Raw values in different units can't be meaningfully combined | Always normalise through utility functions |
| 4 | **Constraints only, no utilities** | Agent can't distinguish "barely acceptable" from "excellent" | Use both: constraints as gates, utilities as rankings |
| 5 | **Utilities only, no constraints** | No hard floor; agent might violate limits if overall score is high enough | Use both: constraints for hard limits, utilities for preferences |
| 6 | **Replanning every cycle** | Wastes LLM calls; creates plan churn | Only replan when adaptation detector says conditions changed |
| 7 | **Processing every event individually** | Overwhelms the agent; ignores the "latest state wins" pattern | Batch-process accumulated data; decide on current state |
| 8 | **Consensus for routine decisions** | Heavyweight process suspends planning; slows everything down | Use communication for routine; consensus only for binding agreements |
| 9 | **No data inventory before design** | Agents designed around data that doesn't exist | Inventory available data first (use the Configuration Wizard's Data Inventory step) |
| 10 | **Double-counting in objectives** | Distorts the decision score; over-weights certain factors | Each real-world factor appears once in the objective |

---

## Document Index

### Concept Clarifications (in ../concepts/)
| Document | Key Question It Answers |
|----------|----------------------|
| [ORPA vs Planning Cycle](../concepts/orpa-vs-planning-cycle.md) | What's the difference between the agent's thinking cycle and the planning timer? |
| [Assistant Agent Type](../concepts/assistant-agent-type.md) | How do Assistant agents differ from Decision agents? |
| [Profiles vs Instances](../concepts/profiles-vs-instances.md) | Why shouldn't I create one profile per agent? |
| [Measures, Utilities & Objectives](../concepts/measures-utilities-objectives.md) | What's the difference between a measure, a utility, and an objective? |
| [Observations, Reflections & Memories](../concepts/observations-reflections-memories.md) | How does the agent's memory system work? |
| [Constraints vs Utilities](../concepts/constraints-vs-utilities.md) | When do I use a constraint vs a utility function? |
| [Tools, Actions & DataStreams](../concepts/tools-actions-datastreams.md) | What's the difference between a tool, an action, and a data stream? |
| [Team vs Agent Objectives](../concepts/team-vs-agent-objectives.md) | Why don't all agents share the same objective? |
| [Planning, Execution & Adaptation](../concepts/planning-execution-adaptation.md) | How does the agent decide when to replan? |
| [Consensus vs Communication](../concepts/consensus-vs-communication.md) | When should agents formally agree vs just share information? |
| [Concurrent Data Handling](../concepts/concurrent-data-handling.md) | What happens to data that arrives while agents are busy? |

### Implementation Guides (in this directory)
| Document | What It Covers |
|----------|---------------|
| [Team Size & Role Separation](team-size-role-separation.md) | Scoring method, functional roles, when to split/combine, safety-critical minimum |
| [Decision Authority](decision-authority.md) | Four authority levels, decision trees, authority matrix template |
| [System Prompts](system-prompts.md) | Prompt structure, what belongs where, good vs bad examples |
| [Behavioural Rules](behavioural-rules.md) | Four rule types, writing patterns, rules by agent role |
| [Model Selection](model-selection.md) | Three tiers, decision tree, cost-performance trade-offs, token limits |
| [Planning Cycle Interval](planning-cycle-interval.md) | Formula, by-domain guidance, Goldilocks zone, dual spacing |
| [Utility Function Types](utility-function-types.md) | Four types with decision tree, common applications, distribution patterns |
| [Steepness Tuning](steepness-tuning.md) | Steepness ranges, agent-specific variations, tuning methodology |
| [Constraint Configuration](constraint-configuration.md) | Priority assignment, violation actions, modality, measure linkage |
| [Data Inventory](data-inventory.md) | Why data-first, what to inventory, gap analysis, timing |
| [Data Architecture](data-architecture.md) | Monitor gateway pattern, independent safety access, streaming vs request |
| [Memory Configuration](memory-configuration.md) | Significance thresholds, retention periods, type weights, retrieval pipeline |
| [Execution Timing](execution-timing.md) | Constraint validation, move spacing, analyser deadtime, temperature-first monitoring |

---

## Related Documentation

- **[Best Practices](../best-practices/README.md)** - Strategic guidance and design principles
- **[Concepts](../concepts/README.md)** - Foundational understanding
- **[Design Patterns](../design-patterns/README.md)** - Proven implementation patterns
- **[Use Cases](../use-cases/README.md)** - Real-world applications

---

*This guide is a living document. As MAGS evolves and new patterns emerge, sections will be added and updated.*
