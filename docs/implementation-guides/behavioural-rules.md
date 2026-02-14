# Recommended Practice: Behavioural Rules (Deontic Framework)

*Back to [Implementation Guides](README.md) → Section 3.2*

---

## The Principle

Behavioural rules define **what the agent MUST do, MUST NOT do, MAY do, and MUST DO IF a condition is met**. They are the operational guardrails that shape agent behaviour beyond what the system prompt establishes.

---

## The Four Rule Types

### 1. Obligations (MUST DO)

Non-negotiable actions the agent must always perform. These are the agent's core duties.

**How many**: 5-10 per agent

**Writing pattern**: Start with an action verb. Be specific and measurable.

| Good ✅ | Bad ❌ |
|---------|--------|
| "Read all configured data sources at every cycle — never skip a source" | "Monitor data" |
| "Timestamp every reading with the data source and value" | "Keep track of things" |
| "Document the reasoning for every proposal" | "Be transparent" |
| "Submit every proposal to the Guardian before execution" | "Get approval when needed" |

**Tips**:
- Each obligation should be independently verifiable — could an auditor check if it was followed?
- Obligations should be unconditional — they apply in ALL situations
- If an obligation only applies sometimes, it's a Conditional Duty, not an Obligation

### 2. Prohibitions (MUST NOT DO)

Actions the agent must never take. These are the hard boundaries.

**How many**: 5-8 per agent

**Writing pattern**: Start with "MUST NOT". Be explicit about what's forbidden.

| Good ✅ | Bad ❌ |
|---------|--------|
| "MUST NOT propose setpoint changes outside the agreed bands" | "Don't go too far" |
| "MUST NOT filter or suppress data — report all readings" | "Be honest" |
| "MUST NOT write to any controller other than FC3103 and TC3106" | "Only write to approved controllers" |
| "MUST NOT override the Guardian's veto" | "Respect safety" |

**Tips**:
- Prohibitions should be absolute — no exceptions
- If there are exceptions, use a Conditional Duty instead
- Prohibitions prevent the LLM from rationalising its way into dangerous territory

### 3. Permissions (MAY DO)

Optional actions the agent is allowed but not required to take. These give the agent flexibility.

**How many**: 4-6 per agent

**Writing pattern**: Start with "MAY". Describe the optional capability.

| Good ✅ | Bad ❌ |
|---------|--------|
| "MAY adjust reading frequency based on process stability" | "Can change things" |
| "MAY maintain rolling averages and trend indicators" | "Track trends if useful" |
| "MAY suggest a modified version of a vetoed proposal" | "Try again if rejected" |
| "MAY compare current performance to historical data" | "Use history" |

**Tips**:
- Permissions clarify what's allowed without being required
- They prevent the agent from being overly rigid
- Without permissions, agents may avoid beneficial actions because they weren't explicitly told to do them

### 4. Conditional Duties (IF...THEN)

Context-dependent rules that activate under specific conditions.

**How many**: 5-6 per agent

**Writing pattern**: "IF [specific, measurable condition] THEN [specific action]"

| Good ✅ | Bad ❌ |
|---------|--------|
| "IF any analyser reading is stale for more than two update intervals THEN flag analyser fault and escalate to human" | "If data looks bad, do something" |
| "IF predicted impurities will exceed 1.8 mol% within two cycles THEN mark assessment as URGENT" | "If things are getting worse, be more careful" |
| "IF the Guardian vetoes a proposal THEN revise and resubmit or accept the veto" | "Handle rejections" |
| "IF cumulative TC3106 change approaches 3°C THEN request human Shift Supervisor approval" | "Get approval for big changes" |

**Tips**:
- The IF condition must be specific and measurable — not vague
- The THEN action must be concrete — not "consider" or "think about"
- Conditional duties handle the edge cases that obligations and prohibitions can't cover
- They're the most powerful rule type for shaping nuanced agent behaviour

---

## How Rules Interact

```
OBLIGATIONS set the baseline: "You MUST always do these things"
     │
PROHIBITIONS set the boundaries: "You MUST NEVER do these things"
     │
PERMISSIONS add flexibility: "You MAY also do these things"
     │
CONDITIONAL DUTIES handle edge cases: "IF this happens, THEN do this"
```

Together, they create a **behavioural envelope** — the agent operates within the space defined by obligations (floor), prohibitions (walls), permissions (optional doors), and conditional duties (situation-specific responses).

---

## Rules by Agent Role

### Monitor/Observer
- **Obligations**: Data collection completeness, timestamping, change detection, alarm forwarding
- **Prohibitions**: No interpretation, no recommendations, no data filtering
- **Permissions**: Adjust reading frequency, maintain rolling averages, flag suspect data
- **Conditional**: Stale data handling, alarm escalation, instrument fault detection

### Analyzer/Interpreter
- **Obligations**: Quantified assessments, trajectory predictions, margin calculations
- **Prohibitions**: No setpoint proposals, no economic judgments (if separation analyst), no data suppression
- **Permissions**: Historical comparison, sensitivity analysis, additional data requests
- **Conditional**: Urgent flagging near limits, data quality caveats, equipment issue escalation

### Decision-Maker/Optimizer
- **Obligations**: Consider all inputs, document reasoning, respect rate-of-change limits, submit to Guardian
- **Prohibitions**: No direct execution, no Guardian override, no action on suspect data
- **Permissions**: Hold decisions, request updated assessments, propose phased sequences
- **Conditional**: Conflict resolution (safety > economics), cumulative limit escalation, uncertainty handling

### Guardian/Validator
- **Obligations**: Validate every proposal, check all constraints independently, provide specific veto reasons
- **Prohibitions**: No economic consideration, no weakening of limits, no deference to urgency
- **Permissions**: Suggest modified proposals, request additional data, proactive alerting
- **Conditional**: Near-limit heightened scrutiny, SIF approach veto, data quality veto

### Executor/Controller
- **Obligations**: Only execute Guardian-approved changes, verify controller mode, confirm readback
- **Prohibitions**: No unapproved execution, no value modification, no wrong-mode writes
- **Permissions**: Brief execution delay for transient disturbances, anomaly reporting
- **Conditional**: Mode conflict handling, communication failure handling, PV non-response handling

---

## Checklist

- [ ] 5-10 Obligations per agent (unconditional duties)
- [ ] 5-8 Prohibitions per agent (absolute boundaries)
- [ ] 4-6 Permissions per agent (optional flexibility)
- [ ] 5-6 Conditional Duties per agent (edge case handling)
- [ ] All rules are specific and measurable (not vague)
- [ ] Obligations are independently verifiable
- [ ] Prohibitions are absolute (no exceptions)
- [ ] Conditional duties have specific, measurable IF conditions
- [ ] No contradictions between rule types
- [ ] Safety-critical rules are in Obligations or Prohibitions (not just Permissions)
