# Recommended Practice: Team Size and Role Separation

*Back to [Implementation Guides](README.md) → Section 2.3*

---

## The Principle

Each agent should have a **distinct, focused role**. Don't combine roles that need independent judgment. Don't split roles that share the same reasoning.

---

## How Many Agents Do You Need?

### The Scoring Method

MAGS uses a multi-dimensional scoring system to determine team size. The score (0-100) maps to a complexity classification:

| Score | Classification | Typical Team Size |
|-------|---------------|-------------------|
| 0-25 | 🟢 Low | 2-3 agents |
| 26-45 | 🟡 Moderate | 3-4 agents |
| 46-65 | 🟠 High | 4-6 agents |
| 66-100 | 🔴 Very High | 6-8 agents |

### The Seven Scoring Dimensions

| Dimension | What It Measures | Max Points |
|-----------|-----------------|------------|
| Decision Authority & Consequences | How much autonomy? How bad if wrong? | 15 |
| Process Complexity & Data Volume | How many variables? How complex? | 15 |
| Decision Timing & Coordination | How fast? How many disciplines? | 15 |
| Knowledge Synthesis & Expertise | How much domain knowledge? | 15 |
| Quality, Safety & Compliance | Independent validation needed? | 15 |
| Artifact Management & Documentation | How much documentation? | 15 |
| Environmental & Operational Context | Continuous? Distributed? | 10 |

---

## The Functional Roles

### Always Required

**Monitor/Observer** — Every team needs at least one agent that watches the environment. Without observation, nothing else works.

### Conditional Roles (Add When Needed)

| Role | When to Add | Trigger |
|------|------------|---------|
| **Analyzer/Interpreter** | Complex data needs interpretation | Complexity score ≥ 4, Investigation ≥ 4, or Expertise ≥ 6 |
| **Decision-Maker/Optimizer** | Autonomous decisions needed | Autonomy ≥ 6, Multiple disciplines, or Optimization use case |
| **Executor/Controller** | Agent writes to control systems | Autonomy ≥ 3, Control DOF ≥ 1, Autonomous execution |
| **Guardian/Validator** | Independent safety validation | Safety-critical, Independent validation required |
| **Coordinator/Orchestrator** | Complex multi-step workflows | Many disciplines (≥ 7), Many stakeholders (≥ 4) |
| **Artifact Manager** | Heavy documentation requirements | Documentation burden ≥ 6, Regulatory ≥ 4 |
| **Historian/Knowledge Manager** | Pattern matching against history | Golden batch comparison, Extensive diagnostics |

---

## When to Split a Role into Multiple Agents

Split an Analyzer into two agents when:
- ✅ They analyse **fundamentally different domains** (e.g., engineering vs economics)
- ✅ They use **different data sources** and **different reasoning**
- ✅ They need to provide **independent assessments** to a decision-maker

Do NOT split when:
- ❌ They analyse the same data from different angles (that's one analyst's job)
- ❌ The only difference is the specific variable (temperature analyst vs pressure analyst — that's one monitor)
- ❌ Splitting would create agents that can't function without each other's output

### Decision Tree: Split or Combine?

```
Do the two functions use fundamentally different expertise?
├── No → COMBINE into one agent
└── Yes → Do they need to provide independent assessments?
    ├── No → COMBINE (one agent with broader skills)
    └── Yes → SPLIT into separate agents
```

---

## When to Combine Roles

Combine roles when:
- ✅ The team score is low (< 45) and you have more agents than the complexity warrants
- ✅ Two roles always work in lockstep (one can't function without the other)
- ✅ The combined role is still focused enough for one LLM to handle well

Do NOT combine when:
- ❌ The roles need **independent judgment** (never combine optimizer + safety validator)
- ❌ Combining would create an agent with conflicting objectives
- ❌ The combined role would exceed the LLM's context window or reasoning capacity

### Roles That Must NEVER Be Combined

| Role A | Role B | Why They Must Be Separate |
|--------|--------|--------------------------|
| Decision-Maker/Optimizer | Guardian/Validator | The Guardian must independently validate without economic bias |
| Monitor/Observer | Executor/Controller | Separation of observation from action prevents feedback loops |
| Any economic role | Any safety role | Economic incentives must not influence safety judgments |

---

## The Safety-Critical Minimum

For any use case with safety-critical consequences, the minimum team is **4 agents**:

```
Monitor → Analyzer → Decision-Maker → Guardian
```

The Guardian must be independent from the decision-making chain. This is non-negotiable for safety-critical applications.

---

## Examples by Domain

### Simple Advisory (Score ~25, 2-3 agents)
```
Monitor + Advisor
```
The Monitor observes; the Advisor analyses and recommends to humans.

### Process Optimization (Score ~55, 5-6 agents)
```
Monitor → Separation Analyst ──┐
                                ├→ Decision-Maker → Guardian → Executor
         Economic Analyst ─────┘
```
Two analysts provide independent assessments; Decision-Maker synthesises; Guardian validates; Executor acts.

### Complex Investigation (Score ~70, 6-8 agents)
```
Monitor → Domain Analyst ──┐
          Data Analyst ─────┤
          Historical ───────┼→ Coordinator → Decision-Maker → Guardian
          Compliance ───────┘
```
Multiple specialists feed into a coordinator who orchestrates the investigation.

---

## Checklist

- [ ] Scored the use case across all 7 dimensions
- [ ] Team size matches the complexity classification
- [ ] Every agent has a distinct, focused role
- [ ] No roles combined that need independent judgment
- [ ] No roles split that share the same reasoning
- [ ] Safety-critical minimum met (if applicable)
- [ ] Guardian is independent from economic optimization (if applicable)
