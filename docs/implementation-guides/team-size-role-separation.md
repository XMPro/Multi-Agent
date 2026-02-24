# Implementation Guide: Team Size and Role Separation

*Back to [Implementation Guides](README.md) → Section 2.3*

---

## The Principle

Each agent should have a **distinct, focused role**. Don't combine roles that need independent judgment. Don't split roles that share the same reasoning.

The agent count **emerges from use case characteristics** — it is not predetermined. This guide provides the structured process for determining the right number and type of agents consistently and safely.

---

## Step 1: Score Your Use Case (7 Dimensions, 100 Points)

### Complexity Classification

| Score | Classification | Typical Team Size |
|-------|---------------|-------------------|
| 0-25 | 🟢 Low | 2-3 agents |
| 26-45 | 🟡 Moderate | 3-4 agents |
| 46-65 | 🟠 High | 4-6 agents |
| 66-85 | 🔴 Very High | 6-8 agents |
| 86-100 | 🔴 Extreme | 8+ agents |

### The Seven Scoring Dimensions

| Dimension | What It Measures | Max Points |
|-----------|-----------------|------------|
| 1. Decision Authority & Consequences | How much autonomy? How bad if wrong? | 15 |
| 2. Process Complexity & Data Volume | How many variables? How complex? | 15 |
| 3. Decision Timing & Coordination | How fast? How many disciplines? | 15 |
| 4. Knowledge Synthesis & Expertise | How much domain knowledge? | 15 |
| 5. Quality, Safety & Compliance | Independent validation needed? | 15 |
| 6. Artifact Management & Documentation | How much documentation? | 15 |
| 7. Environmental & Operational Context | Continuous? Distributed? | 10 |

#### Dimension 1: Decision Authority & Consequences

**Autonomy level** (0-12 pts):
- Advisory only (0) → Soft actions (3) → Bounded autonomy (6) → Wide autonomy (9) → Full autonomy (12)

> **Calibration**: If setpoint bands ≥ 10% of operating range AND a Guardian veto AND rate-of-change limits → **Wide Autonomy (9 pts)**. If human approval required for every move → **Bounded Autonomy (6 pts)**.
>
> **Band width formula**: (High limit − Low limit) ÷ High limit × 100%. If ≥ 10% → Wide Autonomy.

**Consequence severity** (0-3 pts):
- Negligible (0) → Low (1) → Moderate (2) → High (3)

> **Safety calibration**: Any process with flammable/toxic materials under pressure defaults to **High (3 pts)** unless SIS/SIF protection is confirmed AND the agent cannot defeat those protections.

#### Dimension 5: Quality, Safety & Compliance

**Independent validation** (0-8 pts):
- None (0) → Embedded (2) → Separate (5) → **Independent (8)** — MUST have no conflict of interest

**Regulatory burden** (0-7 pts):
- None (0) → Basic/internal governance (2) → Significant/PSM/OSHA/GMP (4) → Stringent/aerospace/pharma/nuclear (7)

> **Industrial calibration**: PSM (Process Safety Management), OSHA 1910.119, or equivalent → **Significant (4 pts)**. Internal governance only → **Basic (2 pts)**.

---

## Step 2: Apply Mandatory Separations FIRST

⚠️ **These separations are non-negotiable. No combination rule can override them.**

Apply these before any other role decisions:

1. **Guardian/Validator MUST be independent** from any role with an economic or optimisation objective. The Guardian's value comes entirely from having no incentive to relax constraints for profit.

2. **Executor MUST NOT have decision-making authority.** It only implements what the Guardian approves. The entity proposing actions must not also execute them.

3. **Monitor MUST NOT have write access** to any control system. State collection and action execution must be separate.

If any proposed combination would violate these separations, the combination is **forbidden regardless of other rules**.

---

## Step 3: Determine Required Functional Roles

### Always Required

**Monitor/Observer** — Every team needs at least one agent that watches the environment. Without observation, nothing else works.

Consider multiple monitors if:
- 20+ variables AND geographically distributed
- Different timeframes (real-time + historical)
- Multiple specialized domains

### Conditional Roles

| Role | When to Add | Trigger |
|------|------------|---------|
| **Analyzer/Interpreter** | Complex data needs interpretation | Complexity score ≥ 4, Investigation ≥ 4, or Expertise ≥ 6 |
| **Decision-Maker/Optimizer** | Autonomous decisions needed | Autonomy ≥ 6, Multiple disciplines, or Optimization use case |
| **Executor/Controller** | Agent writes to control systems | Autonomy ≥ 3, Control DOF ≥ 1, Autonomous execution |
| **Guardian/Validator** | Independent safety validation | Validation = 8 pts, OR High consequences + Wide autonomy |
| **Coordinator/Orchestrator** | Complex multi-step workflows | Many disciplines (≥ 7 pts), Many stakeholders (≥ 4) |
| **Artifact Manager** | Heavy documentation requirements | Documentation burden ≥ 6, Regulatory ≥ 4 |
| **Historian/Knowledge Manager** | Pattern matching against history | Golden batch comparison, Extensive diagnostics |

---

## Step 4: Apply the Split/Combine Tests

### The AND Test (Primary Test for Analyzers)

Write the system prompt for the proposed combined agent. If it requires the word **"AND"** to connect two fundamentally different disciplines, you **MUST split** them into separate agents.

| System Prompt | Result |
|--------------|--------|
| "Analyse separation thermodynamics AND calculate market price economics" | ❌ FAILS — split into 2 agents |
| "Analyse batch performance AND compare to golden batch" | ✅ PASSES — same domain, same data |
| "Monitor loop data AND diagnose performance issues" | ✅ PASSES — same domain (process control) |

### The Single Expert Test

Ask: **"Would a single human expert be expected to have both of these skills?"**

- A process engineer and an economist are different people → split
- A process engineer who also monitors the same process → combine

### The Data Domain Rule

You **MUST split** Analyzer roles if they evaluate fundamentally different data schemas:
- Thermodynamic physics vs. financial market pricing → split
- Different domain knowledge + different data sources + different reasoning = different agents

### Decision Tree: Split or Combine?

```
Do the two functions use fundamentally different expertise?
├── No → COMBINE into one agent
└── Yes → Do they need to provide independent assessments?
    ├── No → COMBINE (one agent with broader skills)
    └── Yes → SPLIT into separate agents
```

---

## Step 5: Apply Combination Rules

### MUST NEVER Combine (Forbidden Regardless of Other Rules)

| Role A | Role B | Why They Must Be Separate |
|--------|--------|--------------------------|
| Guardian/Validator | Any role with economic/optimisation objective | Guardian must have no incentive to relax constraints |
| Decision-Maker | Executor | Proposing and executing actions must be separate |
| Monitor/Observer | Executor/Controller | Observation and action must be separate |
| Any economic role | Any safety role | Economic incentives must not influence safety judgments |

### MUST Split

- Analyzer roles that **fail the AND Test** (different disciplines in one system prompt)
- Analyzer roles that **fail the Data Domain Rule** (different data schemas)
- Any role where the **Single Expert Test** says "no single human would have both skills"

### MAY Combine (Only When ALL Conditions Are Met)

- **Monitor + one Analyzer type**, IF: single location, same data source, AND the analysis is a direct interpretation of the monitored data (not a separate domain)
- **Analyzer + Decision-Maker**, IF: single discipline (≤ 2 disciplines) AND the analysis directly determines the decision with no competing inputs from other analyzers

---

## Step 6: Apply Adjustment Rules

### Rule 1: Minimum Viable Team
- If total = 1: Must have ≥ 2 agents (Monitor + one other)
- If total = 2 AND autonomy ≥ 6 pts: Add Executor (minimum 3 for autonomous teams)

### Rule 2: Safety-Critical Minimum
If independent validation = 8 pts OR (High consequences + Wide autonomy), **MINIMUM 4 agents**:
```
Monitor → Analyzer → Decision-Maker → Guardian
```
The Guardian must be independent from the decision-making chain. This is non-negotiable.

### Rule 3: Advisory-Only Simplification
If advisory only (autonomy = 0 pts):
- No Executor needed
- Consider combining Decision-Maker into Analyzer
- Typical: 2-3 agents

---

## Examples by Domain

### Simple Advisory (Score ~25, 2-3 agents)
```
Monitor + Advisor
```
The Monitor observes; the Advisor analyses and recommends to humans.

### Control Loop Investigation (Score ~31, 2-3 agents)
```
Data Monitor Agent → Investigation Manager Agent
```
AND Test: "Monitor loop data AND diagnose performance issues" — same domain, same data schema → MAY combine.

### Brewery Golden Batch (Score ~39, 4 agents)
```
Fermentation Monitor → Quality Analyst → Process Optimizer → Controller
```
AND Test: "Analyse batch performance AND compare to golden batch" — same domain → MAY combine Analyzer + Historian.

### Process Optimization — Safety Critical (Score ~58, 6 agents)
```
Monitor → Separation Analyst ──┐
                                ├→ Decision-Maker → Guardian → Executor
         Economic Analyst ─────┘
```
AND Test: "Analyse separation thermodynamics AND calculate market price economics" → FAILS → MUST split into 2 Analyzers.

### Complex Investigation (Score ~70, 6-8 agents)
```
Monitor → Domain Analyst ──┐
          Data Analyst ─────┤
          Historical ───────┼→ Coordinator → Decision-Maker → Guardian
          Compliance ───────┘
```
Multiple specialists feed into a coordinator who orchestrates the investigation.

### Highly Coordinated / Regulatory (Score ~68, 6-8 agents)
```
Monitor → Requirements Analyst ──┐
          Test Results Analyst ───┼→ Compliance Validator → Program Coordinator → Documentation Manager
          Qualification Strategist┘
```
AND Test: "Requirements analysis AND test results analysis" → different data schemas → MUST split.

---

## General Guidelines by Team Size

| Team Size | Complexity | Typical Use Cases | Typical Composition |
|-----------|-----------|-------------------|---------------------|
| 2-3 agents | Low (0-25) | Advisory, Decision Support | Monitor + Analyzer (+optional Coordinator) |
| 3-4 agents | Moderate (26-45) | Batch Quality, Simple Control | Monitor + Analyzer + Optimizer + Controller |
| 4-5 agents | High (46-65) | Safety-Critical Process Control | Monitor + Analyst + Optimizer + Guardian + Controller |
| 5-6 agents | High (46-65) | Multi-Objective, Multi-Disciplinary | Monitor + Multiple Analysts + Optimizer + Guardian + Controller |
| 6-8+ agents | Very High/Extreme (66-100) | Coordinated, Regulatory, Distributed | Monitor + Analysts + Strategist + Guardian + Coordinator + Artifact Manager + Executor |

---

## Validation Checklist

### Coverage
- [ ] All functional needs addressed (monitoring, analysis, decisions, execution, safety, coordination, documentation)
- [ ] Every agent has a clear, focused primary function

### Mandatory Separations
- [ ] Guardian has NO shared objective with any economic/optimization role (if independent validation required)
- [ ] Executor has NO decision-making authority
- [ ] Monitor has NO write access to control systems
- [ ] Each agent's primary function passes the AND Test (no "AND" connecting different disciplines)
- [ ] Clear audit trail showing analysis/decision/execution separation (if regulatory ≥ 4 pts)

### Efficiency
- [ ] No overlapping responsibilities
- [ ] Team size proportional to complexity score
- [ ] Any combinations applied only where MAY COMBINE conditions are ALL met
- [ ] Scored the use case across all 7 dimensions

### Integration
- [ ] Decision flow is clear (no circular dependencies)
- [ ] Communication paths well-defined
- [ ] Safety-critical minimum met (if applicable)

---

## Validation Note

This scoring methodology has been validated across multiple AI systems (Claude, ChatGPT, Gemini, Grok). Without a structured process, the same use case produced teams of 4, 5, 5, and 6 agents — a 50% variance. After applying the hardened scoring rules and combination tests, all four systems converged to consistent team designs.

**The implication**: Team composition decisions must be documented with explicit reasoning, not just a final count. The reasoning is as important as the number.
