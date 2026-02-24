# MAGS FAQ — Business and Positioning

*Questions that arise before and during adoption decisions: what MAGS is, how it compares, whether it is trustworthy, and what to expect from an implementation.*

*For design and capability questions, see [architecture.md](./architecture.md). For setup and configuration, see [technical.md](./technical.md).*

---

## Contents

- [What Is It — Positioning and Comparison](#what-is-it--positioning-and-comparison)
- [Trust, Safety, and Risk](#trust-safety-and-risk)
- [Implementation and Maintenance](#implementation-and-maintenance)

---

## What Is It — Positioning and Comparison

### What does MAGS actually do?

MAGS is the decision-making layer that sits between operational data and the actions that data should trigger. It turns observations into decisions, and decisions into actions.

Three components underpin it: Data Streams connect to any data source, App Designer surfaces operational dashboards, and MAGS provides AI agent teams that reason, decide, and act continuously.

**See also:** [Why MAGS](../concepts/whymags.md) · [System Components](../architecture/system-components.md) · [Two-Layer Framework](../architecture/two-layer-framework.md)

---

### How is a MAGS team different from a single AI assistant or copilot?

A copilot is one AI trying to assist with everything. MAGS is a structured team where each agent has a specific role, specific rules, and specific objectives.

The critical structural difference: the agent that proposes an action is never the same agent that validates it. This separation of duties — equivalent to financial controls requiring two authorisations — is not achievable in a single-AI architecture. A single model with conflicting objectives cannot provide an independent safety check on its own recommendations.

**See also:** [Team vs Agent Objectives](../concepts/team-vs-agent-objectives.md) · [Why MAGS](../concepts/whymags.md) · [Agent Team Patterns](../design-patterns/agent-team-patterns.md)

---

### How is MAGS different from rule-based automation or Advanced Process Control (APC)?

Rule-based automation and APC optimise a single loop or unit using fixed rules or a mathematical model. MAGS can reason across multiple objectives simultaneously — process performance, economics, safety compliance — and explain its reasoning in natural language.

APC cannot tell you *why* it made a recommendation in business terms. MAGS can.

**See also:** [Decision Making](../concepts/decision-making.md) · [Process Optimisation](../use-cases/process-optimization.md) · [When NOT to Use MAGS](../decision-guides/when-not-to-use-mags.md)

---

### How is MAGS different from Model Predictive Control (MPC)?

MPC is a control algorithm that uses a process model to predict future behaviour and optimise outputs over a rolling time horizon. It is fast, mathematically rigorous, and well-proven. MAGS differs in four ways:

1. **Scope**: MPC optimises control performance for one unit. MAGS reasons across process performance, economics, safety, and market conditions simultaneously.
2. **Explainability**: MPC produces an optimal output trajectory from a mathematical optimisation — it cannot explain the recommendation in business terms. MAGS produces a decision with documented reasoning.
3. **Model dependency**: MPC requires a calibrated, maintained process model. If the model drifts, performance degrades silently. MAGS agents reason from domain knowledge and are explicit about uncertainty when predictions don't match observations.
4. **Economic integration**: MPC optimises process performance. MAGS optimises business outcomes subject to process and safety constraints. These are different objectives.

**The honest positioning**: MPC and MAGS are complementary, not competitive. MPC handles the fast control layer (seconds to minutes). MAGS handles the slower economic and strategic optimisation layer (minutes to hours). MAGS can function as the supervisor that determines the targets a lower-level controller then tracks.

**See also:** [Decision Making](../concepts/decision-making.md) · [Planning Approaches](../concepts/planning-approaches.md) · [Process Optimisation](../use-cases/process-optimization.md)

---

### How is MAGS different from a digital twin?

A digital twin models the process. MAGS uses the digital twin as a data source and adds the decision-making layer on top. The digital twin becomes one of the inputs the Monitor agent uses to assess current state — MAGS does not replace the twin.

**See also:** [Tools, Actions and Data Streams](../concepts/tools-actions-datastreams.md) · [Data Architecture](../architecture/data-architecture.md)

---

### What is MAGS not?

MAGS is not a historian, SCADA, chatbot, digital twin, or reporting tool. It is the decision-making layer that sits above those systems and uses them as data sources.

**See also:** [When NOT to Use MAGS](../decision-guides/when-not-to-use-mags.md) · [FRAMEWORK-RELATIONSHIPS](../FRAMEWORK-RELATIONSHIPS.md)

---

## Trust, Safety, and Risk

### Is MAGS replacing operators?

No — and the answer is worth being direct about, because the question usually comes from genuine concern.

In advisory operation, the agent presents a recommendation with its reasoning; the operator decides whether to act. Nothing changes in the control room except that the operator has better information, faster.

In autonomous operation, the agent acts only within bands that the operator and engineering team have set and approved. If anything falls outside those rules, the agent escalates immediately.

What agents handle: the repetitive, continuous calculation work that operators rarely have time for — watching one unit continuously, evaluating whether a marginal saving is worth pursuing, checking whether a market signal justifies tightening specifications. Operators are freed to focus on what genuinely requires human judgement: abnormal situations, equipment issues, decisions requiring experience and context.

A useful analogy: a very attentive junior engineer who never sleeps, always does the calculation correctly, and escalates to the senior operator when something is outside their authority. The senior operator remains in charge.

**See also:** [Human-in-the-Loop](../responsible-ai/human-in-the-loop.md) · [Incremental Adoption](../adoption-guidance/incremental-adoption.md) · [Decision Authority](../implementation-guides/decision-authority.md)

---

### What if the AI makes a mistake?

The answer has three layers.

**Prevention**: A Guardian-type agent independently validates every proposed action before execution. This agent has no economic objective — its sole purpose is constraint compliance. It cannot be overridden by economic or operational agents; only a human operator can override a Guardian veto.

**Containment**: Every action is within pre-approved operating bands. Even if the agent's reasoning is wrong, the worst outcome is an output moved within the range your engineers signed off. Safety instrumented systems provide the final backstop — agents cannot defeat safety interlocks.

**Accountability**: The full audit trail shows every decision, every data point considered, and every reasoning step. This is more accountability than most manual processes, where operator reasoning is rarely documented.

The engineering analogy: "What if a junior engineer makes a mistake?" You prevent that not by removing the junior engineer, but by having a senior engineer review their work before it is implemented. The Guardian is that senior engineer.

**See also:** [Human-in-the-Loop](../responsible-ai/human-in-the-loop.md) · [Deontic Principles](../concepts/deontic-principles.md) · [Explainability](../responsible-ai/explainability.md) · [Audit Trail](../responsible-ai/regulatory-compliance-audit-trail.md) · [Constraints vs Utilities](../concepts/constraints-vs-utilities.md)

---

### We've tried AI before and it didn't work.

This is the right question to engage with seriously. Most industrial AI failures fall into one of three categories:

**Model drift**: The model was trained on historical data that did not represent real operating conditions. When conditions changed, the model gave wrong answers. MAGS addresses this by reasoning from domain knowledge — engineering principles, economic logic — rather than pattern-matching on historical data. The agent's reasoning is transparent; you can see when it is making assumptions that do not match current reality.

**Trust failure**: The system could not explain its decisions, so operators overrode it constantly. MAGS explains every decision in plain language. Operators can agree or disagree with the reasoning — they are not accepting a black-box output.

**Scope creep**: The project tried to optimise everything at once. It became too complex to validate, too slow to deploy, and too hard to maintain. The recommended approach is to start with a specific, bounded problem — one unit, defined objectives, validated constraints — and prove value before expanding scope.

**See also:** [Risk Mitigation Strategies](../adoption-guidance/risk-mitigation-strategies.md) · [When NOT to Use MAGS](../decision-guides/when-not-to-use-mags.md) · [Incremental Adoption](../adoption-guidance/incremental-adoption.md) · [Agent Training](../concepts/agent_training.md)

---

### What happens in abnormal situations?

Monitoring agents continuously watch for abnormal conditions — not just when evaluating proposals, but as a continuous background task. If an approaching constraint violation is detected, the agent alerts before any proposal is even formed.

If an alarm activates, autonomous actions are immediately suspended and escalated to the operator. Agents do not attempt to handle alarms — that is the operator's role. The agent's purpose is to prevent the conditions that lead to alarms, not to respond to them once they occur.

If data quality is compromised — stale reading, suspect instrument, failed analyser — the agent flags it and falls back to conservative operation rather than making decisions on uncertain data. The agent is explicit about its uncertainty and the reason it is holding.

The design principle: fail safe. When in doubt, escalate to a human. Agents are designed to be more conservative when uncertain, not less.

**See also:** [Decision Making](../concepts/decision-making.md) · [Confidence Scoring](../cognitive-intelligence/confidence-scoring.md) · [Human-in-the-Loop](../responsible-ai/human-in-the-loop.md)

---

### What are the cybersecurity implications of giving AI agents write access?

Agents write to existing systems through existing integration layers — they do not bypass control systems or communicate directly with field devices. All communication goes through standard protocols (OPC-UA, REST, MQTT) using the same security as existing historian and monitoring connections.

Write access is scoped to specific, pre-authorised outputs only. Every write is logged with timestamp, value, and approval reference. Agents cannot modify configuration, tuning, or modes — outputs only, within defined bounds.

From a network architecture perspective, MAGS sits in the same zone as historian and data platforms. It does not require direct access to the control network.

For organisations with strict OT security requirements: agents can be configured in advisory-only mode where they never write to operational systems. This eliminates write-access concerns entirely while retaining monitoring and advisory value.

**See also:** [Prompt Injection Protection](../technical-details/prompt-injection-protection.md) · [Responsible AI Policies](../responsible-ai/policies.md) · [Regulatory Compliance and Audit Trail](../responsible-ai/regulatory-compliance-audit-trail.md)

---

### How does MAGS handle data quality issues?

The Monitor-type agent applies multiple quality checks on every cycle:

- **Staleness detection**: If a sensor or analyser has not updated within its expected cycle time, it is flagged.
- **Range checks**: Values outside physically plausible ranges are flagged as suspect.
- **Rate-of-change checks**: Values changing faster than physically possible are flagged as instrument artefacts.
- **Cross-validation**: Where multiple measurements should be consistent, inconsistencies are flagged.

When data quality is compromised, the agent falls back to conservative operation — holding current outputs and alerting the operator — rather than making decisions on uncertain data. The agent is explicit about its uncertainty and the reason it is holding.

**See also:** [Concurrent Data Handling](../concepts/concurrent-data-handling.md) · [Confidence Scoring](../cognitive-intelligence/confidence-scoring.md) · [Observations, Reflections and Memories](../concepts/observations-reflections-memories.md)

---

## Implementation and Maintenance

### How long before we see value?

The technical deployment is fast. The change management — building operator trust, getting engineering sign-off on operating bands, getting IT/OT security approval — is typically the pacing factor.

Typical progression for advisory operation:

| Phase | Timing | What happens |
|---|---|---|
| Familiarisation | Weeks 1–2 | Agent is live. Operators observe recommendations and build familiarity without acting on them. |
| Early adoption | Weeks 2–4 | Operators act on recommendations they agree with. First measurable value appears. |
| Routine use | Month 2–3 | Operators trust the agent for routine situations. Value accumulates continuously. |
| Economic layer | Month 3–6 | Continuous financial calculation quantifies the case for each recommendation. Savings visible in reports. |
| Autonomous (if approved) | Month 6–12 | Agent acts on every opportunity within approved bands. Value compounds — not just when operators have time to evaluate. |

Plan for 3–6 months to full value. The technical deployment may be faster; the adoption journey sets the pace.

**See also:** [Incremental Adoption](../adoption-guidance/incremental-adoption.md) · [Risk Mitigation Strategies](../adoption-guidance/risk-mitigation-strategies.md) · [Deployment Considerations](../best-practices/deployment-considerations.md)

---

### What is the maintenance burden?

This is a fair concern — many AI systems become maintenance problems when the process changes.

The key difference from ML-based systems: **there is no model to retrain.** Agent knowledge comes from two sources: the RAG knowledge base (engineering documents, operating procedures) and the LLM's reasoning capability. When the process changes, you update the documents and the agent's rules — not a statistical model.

Typical maintenance events:

| Event | Action |
|---|---|
| New operating range | Update the agent's operating bands and constraint values |
| New product specification | Update utility function targets and constraint limits |
| Process equipment change | Update the relevant agent's system prompt and rules |
| New operating procedure | Add to the knowledge base; the agent incorporates it on the next cycle |

None of these require retraining a model or rebuilding the system. Every agent's rules, objectives, and data requirements are explicit and human-readable — you can see exactly what each agent is doing and why.

**See also:** [Agent Design Principles](../best-practices/agent-design-principles.md) · [System Prompts](../implementation-guides/system-prompts.md) · [Memory Configuration](../implementation-guides/memory-configuration.md) · [Deployment Considerations](../best-practices/deployment-considerations.md)

---

### Can it work with existing systems?

MAGS connects to any system via OPC-UA, REST APIs, databases, or file feeds. It sits above existing infrastructure and uses it as data sources — it does not replace what is already there.

Existing AI systems, historians, digital twins, process simulators, and business systems all become data sources or tools that agents can call. Integration is handled once in the Data Stream layer and then made available to all agents that need it.

**See also:** [DataStream Integration](../integration-execution/datastream-integration.md) · [Tool Orchestration](../integration-execution/tool-orchestration.md) · [Data Architecture](../architecture/data-architecture.md)

---

### We already have a data platform / AI system / digital twin. Does MAGS replace it?

No. MAGS sits above those systems and uses them as data sources and tools. Your existing AI becomes one of the tools agents can call. The decision-making layer MAGS provides is what those systems typically lack — not the data or the models themselves.

**See also:** [DataStream Integration](../integration-execution/datastream-integration.md) · [FRAMEWORK-RELATIONSHIPS](../FRAMEWORK-RELATIONSHIPS.md)

---

*Add questions here as they arise in customer conversations. See [README.md](./README.md) for the full FAQ index.*
