# MAGS FAQ — Architecture and Design

*Questions about team design, agent roles, capability boundaries, and the conceptual decisions behind how MAGS works. These come up when designing a solution or evaluating whether MAGS is the right tool for a problem.*

*For adoption and positioning questions, see [business.md](./business.md). For setup and configuration, see [technical.md](./technical.md).*

---

## Contents

- [Team Design](#team-design)
- [Agent Capabilities and Limitations](#agent-capabilities-and-limitations)
- [Core Concepts](#core-concepts)
  - [What is the ORPA cycle?](#what-is-the-orpa-cycle)
  - [What does the anatomy of a cognitive agent look like?](#what-does-the-anatomy-of-a-cognitive-agent-look-like)
  - [How does agent memory work?](#how-does-agent-memory-work-where-does-the-intelligence-reside)
  - [How do agents reach consensus?](#how-do-agents-reach-consensus-on-decisions-that-span-multiple-domains)

---

## Team Design

### Why do agents need a team? Why not one powerful AI?

The key insight is **separation of duties**. The agent that proposes an action must never be the same agent that validates it — this is the same principle as requiring two authorisations for financial transactions, or separating design from inspection in safety-critical engineering.

A Guardian agent's entire value comes from having no incentive to relax constraints for economic gain. A single AI with conflicting objectives cannot provide this structural guarantee. One model trying to balance safety and profitability simultaneously will always face pressure to trade the one for the other.

**See also:** [Team vs Agent Objectives](../concepts/team-vs-agent-objectives.md) · [Why MAGS](../concepts/whymags.md) · [Agent Team Patterns](../design-patterns/agent-team-patterns.md) · [Deontic Principles](../concepts/deontic-principles.md)

---

### Why don't all agents share the same objective?

Productive tension between agent objectives is a feature, not a bug. An economic agent optimising for value and a guardian agent optimising for constraint compliance create the same checks and balances expected in any well-governed engineering or financial process.

If every agent optimised for the same objective, there would be no independent safety validation — only mutual reinforcement of the same bias. The tension between roles is what makes the team trustworthy.

**See also:** [Team vs Agent Objectives](../concepts/team-vs-agent-objectives.md) · [Consensus Mechanisms](../concepts/consensus-mechanisms.md) · [Deontic Principles](../concepts/deontic-principles.md)

---

### What is the difference between a Profile and an Instance?

A **profile** is a job description. An **instance** is a person hired for that job.

One profile can have many instances — for example, one "Process Monitor" profile deployed across ten different units, each monitoring different equipment but following the same role, rules, and objectives. Creating a separate profile per instance is the most common architectural mistake: maintenance overhead then scales with the number of units rather than the number of distinct roles.

**See also:** [Profiles vs Instances](../concepts/profiles-vs-instances.md)

---

### How do agent team patterns vary by use case?

Different operational problems call for different team compositions. A monitoring-only team looks very different from a team with autonomous execution authority. Common structural patterns — hierarchical, collaborative, specialist — each carry different trade-offs in speed, accountability, and complexity.

**See also:** [Agent Team Patterns](../design-patterns/agent-team-patterns.md) · [Team Composition](../best-practices/team-composition.md) · [Team Size and Role Separation](../implementation-guides/team-size-role-separation.md)

---

## Agent Capabilities and Limitations

### Should agents be used for event detection?

For pure event detection — threshold breaches, rate-of-change alerts — Data Streams with rules or lightweight models are faster, cheaper, and more reliable than agents. **Agents are the wrong tool for detection.**

The right architecture: Data Streams detect events; agents interpret and respond. Do not use agents for "is this value above threshold?" Use them for "what does this pattern mean and what should we do about it?"

**See also:** [Tools, Actions and Data Streams](../concepts/tools-actions-datastreams.md) · [DataStream Integration](../integration-execution/datastream-integration.md)

---

### Can an agent build its own predictive model from historical data?

No — not in the current MAGS architecture. Agents cannot train ML models or create statistical models from raw data. They can reason about data using domain knowledge from their knowledge base, and they can call pre-built models as tools.

If trained predictions are needed, build the model in Data Streams or an external ML platform and expose it as a tool the agent can call. The agent then interprets the model's output — it does not produce the model itself.

**See also:** [Agent Training](../concepts/agent_training.md) · [Tool Orchestration](../integration-execution/tool-orchestration.md) · [When NOT to Use MAGS](../decision-guides/when-not-to-use-mags.md)

---

### Can an agent observe process variables and learn to optimise on its own?

Partially, with important limitations. Agents accumulate observations and synthesised insights (reflections) over time and use these to make progressively better decisions. But this is episodic memory and structured reasoning — not parametric machine learning.

Agents work best when:
- The objective is explicit (a defined value formula or goal)
- The action space is bounded (adjust these outputs within these limits)
- The constraints are defined (these conditions must never be violated)

Agents cannot perform unsupervised reinforcement learning or build mathematical process models from operational data.

**See also:** [Observations, Reflections and Memories](../concepts/observations-reflections-memories.md) · [Memory Systems](../concepts/memory-systems.md) · [Objective Functions](../concepts/objective-functions.md) · [When NOT to Use MAGS](../decision-guides/when-not-to-use-mags.md)

---

### What happens to data that arrives while an agent is processing?

Data queues in a concurrent message buffer — nothing is lost. When the agent's current cycle completes, the next cycle reads all accumulated data and makes a decision based on the latest state. This is the "latest state wins" pattern: agents assess the current accumulated picture rather than processing every event individually.

**See also:** [Concurrent Data Handling](../concepts/concurrent-data-handling.md)

---

## Core Concepts

### What is the ORPA cycle?

**Observe-Reflect-Plan-Act.** Each agent runs its own continuous ORPA cycle independently and in parallel with every other agent on the team. This maps directly to John Boyd's OODA loop, the decision-making model developed to explain why fighter pilots win — not by being stronger, but by cycling through observe-orient-decide-act faster than their adversary.

- **Observe**: The agent monitors its data streams for changes. A process engineer agent watches separation efficiency and tray temperatures. An economic analyst watches product prices and energy costs. Each agent has its own instruments and its own domain.
- **Reflect**: The agent builds context by comparing the current state to historical patterns and assessing significance. This is where memory becomes intelligence rather than data storage. Reflect makes the Orient phase from OODA explicit — good decisions require judgment built from experience, not just fast reactions.
- **Plan**: The agent determines whether to act, what to communicate to other agents, and how to respond. Plans are shaped by the agent's own objective function and constrained by its rules of engagement.
- **Act**: The agent communicates significant findings, proposes actions, or executes approved changes within its authority level.

The critical point: agents don't wait in a queue for each other. They communicate when their significance threshold is crossed — similar to how operators in a control room speak up when they see something that matters, not because it is their turn in a sequence. The team's intelligence emerges from these parallel, overlapping cycles, not from a prescribed workflow.

**See also:** [ORPA Cycle](../concepts/orpa-cycle.md) · [ORPA vs Planning Cycle](../concepts/orpa-vs-planning-cycle.md) · [Planning, Execution and Adaptation](../concepts/planning-execution-adaptation.md)

---

### What does the anatomy of a cognitive agent look like?

A cognitive agent has four independent components that make its ORPA cycle meaningful.

**Its own observation domain.** The specific data streams and operational variables it monitors continuously. A process engineer agent watches separation efficiency, tray temperatures, and reflux ratios. An economic analyst watches product prices, energy costs, and margin calculations. Neither waits to be told what to look at. Each has its own instruments and its own domain.

**Its own clock.** Agents don't observe on a shared schedule. Each agent's reflection cycle is driven by the significance of what it is seeing. A quiet period means less frequent reflection. A significant change triggers immediate attention. The process doesn't care about your polling interval, and neither should your agents.

**Its own objective function.** A mathematical expression of what "good" looks like from this agent's perspective. A safety guardian maximises distance from every safety limit. An economic analyst maximises profit per hour. These objectives are fundamentally different, and that tension between them is a feature — it creates the checks and balances that make autonomous operation trustworthy.

**Its own memory.** Each agent accumulates experience: what it observed, what it inferred, what happened as a result. This is the agent's own experience, built over time, informing its reflection. An agent that saw a similar disturbance six months ago recognises the pattern faster the second time. Memory is what makes reflection intelligent rather than reactive.

These four components run independently per agent, not as a shared pipeline. The team's intelligence is the sum of these parallel, overlapping ORPA cycles — not a sequence of handoffs.

**See also:** [Agent Architecture](../architecture/agent_architecture.md) · [ORPA Cycle](../concepts/orpa-cycle.md) · [Objective Functions](../concepts/objective-functions.md) · [Memory Systems](../concepts/memory-systems.md)

---

### How does agent memory work? Where does the intelligence reside?

The memory architecture mirrors how the human brain stores and retrieves information. MAGS implements three distinct memory systems, each optimised for different cognitive functions.

**Semantic memory (Graph Database).** Stores relationships and structure: which equipment connects to which process, which failure modes affect which production lines, what operating procedures apply to which conditions. This is the agent's understanding of how things relate to each other.

**Episodic memory (Time-Series Database).** Records time-stamped experiences: what happened, when, under what conditions. This is the agent's history of what it has observed and the outcomes that followed.

**Associative memory (Vector Database).** Enables rapid pattern recognition through semantic similarity search. When a new situation arises, the vector database finds the closest matching previous experiences in 50-100 milliseconds. This is the agent's intuition — "this situation feels like that previous situation."

This three-tier architecture mirrors Dual-Process Theory from cognitive psychology. System 1 (fast, intuitive) operates through vector similarity search for rapid pattern matching. System 2 (slow, analytical) operates through graph traversal and time-series analysis for deliberate reasoning. This is how human experts work: fast intuition backed by careful analysis when stakes are high.

Short-term memory keeps recent observations accessible for immediate context, similar to human working memory. The cache automatically removes information after 30 minutes of inactivity to prevent overload. Long-term memory stores five types of information: observations, reflections, plans, decisions, and actions. Over time, memories that prove useful stay prominent while irrelevant information naturally decays.

The intelligence of the agent resides in this combination of memory, objective functions, and the ORPA reasoning cycle. The large language model provides the reasoning capability, but the agent's intelligence comes from the operational context stored in its memory, the business objectives encoded in its utility functions, and the constraints defined by its rules of engagement. Without that context, an LLM is generating plausible text. With it, the agent is making operational decisions grounded in physical reality.

**See also:** [Memory Systems](../concepts/memory-systems.md) · [How MAGS Uses Memory](../concepts/howmagsusememory.md) · [Memory Configuration](../implementation-guides/memory-configuration.md) · [Memory Management](../cognitive-intelligence/memory-management.md) · [Vector Database](../technical-details/vector_database.md)

---

### How do agents reach consensus on decisions that span multiple domains?

Agents reach consensus through the **team objective function** — a weighted mathematical expression that balances competing priorities like throughput, equipment health, quality, and energy efficiency. Each agent contributes to this objective from its domain. Expert agents provide the observations that inform each component. The orchestrator synthesises these contributions and proposes actions that move the team objective in the right direction. The guardian validates independently.

No agent waits for another to finish. They communicate when they have something significant to say. When a proposed action affects multiple domains — for example, reducing throughput to protect equipment — the team objective function provides the common framework for evaluating whether the trade-off creates net value. The orchestrator weighs the utility of avoided equipment failure against the utility of marginal production gain given current conditions, and the guardian confirms the proposal stays within safety constraints.

This is structurally different from voting or majority-rules consensus. The objective function encodes the organisation's priorities mathematically. Agents don't negotiate — they optimise toward a shared definition of "good" while respecting constraints that cannot be traded away.

**See also:** [Consensus Mechanisms](../concepts/consensus-mechanisms.md) · [Consensus vs Communication](../concepts/consensus-vs-communication.md) · [Team vs Agent Objectives](../concepts/team-vs-agent-objectives.md) · [Objective Functions](../concepts/objective-functions.md)

---

### What is the difference between an Observation and a Reflection?

An **observation** is what the agent perceives at a moment in time — a data reading, an event, a state change.

A **reflection** is what the agent concludes from multiple observations over time — the synthesised insight that can improve future decisions. Reflections represent accumulated learning and are what allow agents to become progressively better at their role as they gain operational experience.

**See also:** [Observations, Reflections and Memories](../concepts/observations-reflections-memories.md) · [Memory Systems](../concepts/memory-systems.md) · [Memory Management](../cognitive-intelligence/memory-management.md)

---

### What is the difference between a Constraint and a Utility Function?

A **utility function** says "I prefer this" — it guides optimisation toward better outcomes by creating a gradient that steers decisions toward higher-value states.

A **constraint** says "I forbid that" — it gates optimisation and rejects any plan that violates it, regardless of how attractive the plan is on other dimensions.

For safety-critical measures, use both: a constraint as the hard floor that can never be crossed, and a utility function as the gradient that steers decisions away from the floor before it is ever reached. The utility function keeps the agent from getting close to the limit; the constraint ensures it can never be violated.

**See also:** [Constraints vs Utilities](../concepts/constraints-vs-utilities.md) · [Objective Functions](../concepts/objective-functions.md) · [Measures, Utilities and Objectives](../concepts/measures-utilities-objectives.md) · [Constraint Configuration](../implementation-guides/constraint-configuration.md)

---

### Why do different AI models (or runs) sometimes produce different agent team designs for the same problem?

Variance in team design outputs typically comes from subjective interpretation of combination rules and ambiguous scoring criteria. Common causes:

- The "AND test" was not applied: if a system prompt requires "AND" to connect two structurally different disciplines, those should be separate agents rather than combined.
- Guardian independence was not enforced: the agent validating safety should have no economic objective and should be structurally separate from agents that propose actions.
- Role granularity was inconsistent: some roles were combined at a high level while others were split finely.

Consistent team designs require explicit rules: band-width calculation formulas, domain-specific calibrations, mandatory separation rules for safety-critical roles.

**See also:** [Team Size and Role Separation](../implementation-guides/team-size-role-separation.md) · [Agent Design Principles](../best-practices/agent-design-principles.md) · [Team Composition](../best-practices/team-composition.md)

---

*Add questions here as they arise in design sessions and architecture reviews. See [README.md](./README.md) for the full FAQ index.*
