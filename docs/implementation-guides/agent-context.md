# Recommended Practice: Providing Context to Agents

*Back to [Implementation Guides](README.md) → Section 3.6*

---

## The Principle

An agent can only reason correctly about data it understands. Providing context means giving each agent the right knowledge — in the right place — so it can interpret what it receives, apply the correct rules, and avoid drawing false conclusions from numbers it doesn't understand.

Context has two distinct forms that must be handled differently:

| Context Type | What It Is | Where It Goes | Why |
|-------------|-----------|---------------|-----|
| **Grammar rules** | Conventions that apply to every piece of data the agent ever sees (e.g. tag naming conventions, unit rules, comparison prohibitions) | **System prompt** | Must be active at all times — cannot be retrieved on demand |
| **Reference knowledge** | Domain knowledge the agent looks up when it needs it (e.g. operating procedures, alarm setpoints, process descriptions) | **RAG collection** | Retrieved on demand — appropriate for contextual, situational knowledge |

Confusing these two categories is the most common cause of agent reasoning errors.

---

## What RAG Does — and Doesn't Do

### What RAG does

RAG (Retrieval-Augmented Generation) allows an agent to query a knowledge base and retrieve relevant document chunks at reasoning time. It is the right tool for:

- Looking up operating procedures for a specific situation
- Retrieving alarm setpoints and response guidance
- Finding process descriptions and equipment specifications
- Accessing safety analysis for a specific hazard scenario

### What RAG doesn't do

RAG does **not** proactively inject knowledge into the agent's reasoning. The agent must query for it. This means:

1. **The agent only retrieves what it knows to look for.** If the agent doesn't know it doesn't know something, it won't query for it. An agent that receives `FC3101_MV = 46.69` and `FC3101_SV = 15.5` has no reason to query "what does _MV mean" — it will just compare the numbers.

2. **RAG retrieval is semantic, not exhaustive.** The agent gets the chunks most similar to its query, not a complete reading of the document. A tag naming convention buried in Section 1.1 of a Tag Reference document may not be retrieved if the agent's query is about flow control performance.

3. **RAG is not reliable for rules that must always apply.** If a rule must be applied to every piece of data the agent receives — without exception — it cannot depend on the agent remembering to query for it each time.

### The failure mode

> The agent received `FC3101_MV = 46.69` and `FC3101_SV = 15.5`. The Tag Reference document (which explains that `_MV` is a valve position in % and `_SV` is a setpoint in t/hr) was available in the RAG collection. But the agent had no reason to query for tag suffix definitions — it saw two numbers and compared them. It concluded there was a "large discrepancy" and flagged a control fault. The controllers were working perfectly.

The Tag Reference was available. The agent didn't use it. RAG cannot fix a problem the agent doesn't know it has.

---

## The Three Layers of Agent Context

### Layer 1: System Prompt — Always-On Rules

The system prompt is read by the agent at the start of every reasoning cycle. It is the right place for:

- **Data interpretation rules**: Tag naming conventions, unit rules, which tag types must never be compared numerically, how to assess controller performance
- **Role identity and expertise**: Who the agent is and what domain knowledge it has
- **Behavioural boundaries**: What the agent must always do, must never do, and how it relates to other agents

**Example — Data Interpretation Rules in a system prompt:**

> "Tags ending in `_MV` are controller outputs to valves, expressed as a percentage (0–100%). They are NOT in engineering units and must never be compared numerically to setpoint tags (`_SV`) or direct measurement tags. To assess whether a controller is tracking its setpoint, compare the direct measurement tag (e.g. `FI3101`) to the setpoint tag (e.g. `FC3101_SV`). If these values are closely matched, the controller is performing correctly — regardless of the `_MV` value."

This rule is active every time the agent reasons about any tag. It does not depend on the agent querying for it.

### Layer 2: RAG Collection — On-Demand Reference Knowledge

The RAG collection is the right place for knowledge the agent looks up when it needs it:

- Operating procedures for specific situations
- Alarm setpoints and response guidance
- Process descriptions and equipment context
- Safety analysis for specific hazard scenarios
- Historical performance benchmarks

**RAG collection design by agent role:**

| Agent Role | Essential Documents |
|------------|-------------------|
| **Monitor** | Tag Reference, Alarm Summary |
| **Analyst (process)** | Tag Reference, Process Description, Control Philosophy |
| **Analyst (economic)** | Process Description |
| **Decision-Maker** | Control Philosophy, Operating Procedures |
| **Guardian** | Safety Analysis, Control Philosophy, Alarm Summary, Tag Reference |
| **Executor** | Control Philosophy, Operating Procedures, Tag Reference |

> ⚠️ The **Tag Reference** (or equivalent document listing all tags, units, and roles) is the most commonly omitted document. Without it, agents cannot look up what a tag represents even when they know to ask. Include it in every agent that reads process data.

### Layer 3: Behavioural Rules — Conditional Context

Behavioural rules (Obligations, Prohibitions, Permissions, Conditional Duties) provide context-sensitive instructions that activate under specific conditions. They are the right place for:

- Rules that apply only in certain situations (IF...THEN)
- Escalation triggers
- Data quality handling instructions
- Coordination rules with other agents

---

## The Critical Distinction: Tag Names vs Tag Naming Conventions

This distinction is the most common source of confusion when designing agent system prompts.

| | Tag Names | Tag Naming Conventions |
|--|-----------|----------------------|
| **What they are** | Specific identifiers: `FI3101`, `TC3106`, `FC3103_SV` | Grammar rules: "tags ending in `_MV` are valve positions in %" |
| **Scope** | Deployment-specific — change between plants, units, systems | Universal within the system — apply to every tag the agent sees |
| **Where they belong** | Tool configuration and data inventory — NOT in the system prompt | System prompt (Data Interpretation Rules section) |
| **Why** | Putting tag names in the system prompt makes the profile non-reusable and hard to maintain | Naming conventions must be active at all times — RAG cannot reliably surface them on demand |

**Wrong approach:**
> System prompt: "You monitor FI3101 (feed flow), FC3101_SV (feed setpoint), and FC3101_MV (feed valve position)."

This puts specific tag names in the system prompt. If the tag names change, the system prompt must be rewritten.

**Right approach:**
> System prompt: "You monitor feed flow, feed setpoint, and feed valve position. Tags ending in `_MV` are valve positions in % (0–100%) and must never be compared to setpoint or measurement tags."
>
> Tool configuration: `{ "tag": "FI3101", "description": "feed flow", "unit": "t/hr" }`

The system prompt carries the grammar rule. The tool configuration carries the specific tag names.

---

## Designing Context for a New Agent — Checklist

### System Prompt
- [ ] Data Interpretation Rules section included (for any agent that reads process data)
- [ ] Tag naming conventions documented (suffix/prefix patterns, unit rules)
- [ ] Explicit prohibition: which tag types must never be compared numerically
- [ ] Correct comparison method stated: how to assess controller performance
- [ ] Controller mode codes defined (if applicable)
- [ ] No specific tag names in the system prompt

### RAG Collection
- [ ] Tag Reference (or equivalent) included for any agent that reads process data
- [ ] Process Description included for all agents
- [ ] Role-appropriate documents included (see table above)
- [ ] Documents are current — stale documents lead to stale agent knowledge
- [ ] Documents are chunked appropriately for the RAG retrieval strategy

### Behavioural Rules
- [ ] Data quality handling rules included (what to do with stale, suspect, or missing data)
- [ ] Escalation triggers defined for data anomalies
- [ ] Conditional duties cover the most important "if data shows X, then do Y" scenarios

---

## Lessons Learned

The following patterns have been observed in production MAGS deployments and testing:

| Lesson | What Happened | What to Do Instead |
|--------|--------------|-------------------|
| **RAG cannot fix unknown unknowns** | Agent compared `_MV` (%) to `_SV` (t/hr) and flagged a false control fault. The Tag Reference was in RAG but the agent never queried it. | Put tag naming conventions in the system prompt, not just in RAG |
| **The Tag Reference is always missing** | In every agent team reviewed, the Tag Reference was absent from at least one agent's RAG collection that needed it | Treat the Tag Reference as mandatory for all data-reading agents |
| **Grammar rules belong in the system prompt** | Rules that apply to every data point (unit conventions, comparison prohibitions) were put in RAG documents. Agents retrieved them inconsistently. | System prompt for always-on rules; RAG for situational reference |
| **Tag names in system prompts create maintenance debt** | System prompts contained specific tag names. When the tag naming scheme changed, every system prompt had to be rewritten. | Tag names in tool config; naming conventions in system prompt |
| **Confidence doesn't indicate correctness** | An agent rated itself 7/10 confident in a conclusion that was wrong from the first comparison. High confidence in a wrong interpretation is worse than acknowledged uncertainty. | Data interpretation rules in the system prompt prevent the wrong interpretation from forming in the first place |

---

## Checklist Summary

- [ ] Grammar rules (naming conventions, unit rules) → **System prompt**
- [ ] Reference knowledge (procedures, alarms, process descriptions) → **RAG collection**
- [ ] Tag Reference included in RAG for every data-reading agent
- [ ] Tag names NOT in system prompt — in tool configuration
- [ ] Tag naming conventions IN system prompt — in Data Interpretation Rules section
- [ ] Behavioural rules cover data quality and anomaly handling
