# Recommended Practice: Constraint Configuration

*Back to [Implementation Guides](README.md) → Section 5.2-5.4*

---

## The Principle

Constraints are the **non-negotiable rules** that agents must respect. Every constraint must be specific, measurable, linked to a data source, and have a defined response when violated.

---

## The Constraint Model

Every constraint in MAGS has these properties:

| Property | What It Defines | Example |
|----------|----------------|---------|
| **ID** | Unique identifier | CONST-001-TOP-IMPURITY |
| **Name** | Human-readable name | "Top C4+ Impurity Limit" |
| **Description** | What it enforces and why | "Must not exceed 2.0 mol% to maintain product quality" |
| **Measure ID** | Which measure it constrains | MEAS-001-TOP-IMPURITY |
| **Rule** | Computable expression | "MEAS-001 <= 2.0" |
| **Modality** | Deontic classification | Obligatory / Prohibited / Permitted |
| **Violation Action** | What happens on violation | Block / Warn / Log |
| **Priority** | How critical | Critical / High / Medium / Low |
| **Active** | Currently enforced? | Yes / No |

---

## Assigning Priority

### Decision Guide

```
Could violation cause physical harm or regulatory breach?
├── Yes → CRITICAL
└── No → Could violation cause equipment damage or product quality failure?
    ├── Yes → HIGH
    └── No → Could violation cause economic loss or performance degradation?
        ├── Yes → MEDIUM
        └── No → LOW (preference/guideline)
```

### Priority Definitions

| Priority | Override Authority | Examples |
|----------|-------------------|---------|
| **Critical** | Cannot be overridden by any agent | Safety limits, SIF setpoints, regulatory limits, equipment design limits |
| **High** | Requires human escalation | Product quality specs, operational ranges, rate-of-change limits |
| **Medium** | Can be relaxed with documented justification | Performance targets, efficiency thresholds |
| **Low** | Can be relaxed freely | Preferences, guidelines, soft targets |

---

## Choosing Violation Actions

### Decision Guide

```
Would violation cause immediate harm?
├── Yes → BLOCK (reject the plan)
└── No → Does violation require human judgment?
    ├── Yes → WARN (proceed but escalate)
    └── No → LOG (record for audit)
```

### When to Use Each

| Action | Behaviour | Use When |
|--------|-----------|----------|
| **Block** | Plan is rejected. Agent must revise before proceeding. | Safety limits, equipment boundaries, regulatory requirements |
| **Warn** | Plan proceeds but violation is flagged and escalated to humans. | Cumulative limits requiring supervisor approval, near-boundary operations |
| **Log** | Violation is recorded in audit trail. No impact on plan execution. | Soft targets, performance guidelines, informational thresholds |

---

## Deontic Modality

### The Three Modalities

| Modality | Meaning | Rule Pattern | Example |
|----------|---------|-------------|---------|
| **Obligatory** | This condition MUST be maintained | "measure <= limit" or "measure >= minimum" | "Impurity must stay below 2.0 mol%" |
| **Prohibited** | This condition MUST NOT occur | "measure != forbidden_state" | "Flooding must not occur (dP must not exceed 0.5 bar)" |
| **Permitted** | This condition MAY occur within bounds | "minimum <= measure <= maximum" | "Pressure may vary between 15.5-18.0 barg" |

### Choosing Modality

Most constraints are **Obligatory** (a condition that must be maintained). Use **Prohibited** when framing the constraint as "this must not happen" is clearer than "this must be maintained." Use **Permitted** for operating ranges where both ends are bounded.

---

## Constraint Categories

### Safety Constraints
- Priority: **Critical**
- Violation Action: **Block**
- Modality: **Obligatory** or **Prohibited**
- Examples: Impurity limits, pressure limits, level limits, SIF approach margins

### Equipment Constraints
- Priority: **Critical** or **High**
- Violation Action: **Block**
- Modality: **Obligatory**
- Examples: Operating ranges, design temperature limits, flow capacity limits

### Operational Constraints
- Priority: **High**
- Violation Action: **Block** or **Warn**
- Modality: **Obligatory**
- Examples: Setpoint bands, rate-of-change limits, move spacing

### Timing Constraints
- Priority: **High**
- Violation Action: **Block**
- Modality: **Obligatory**
- Examples: Minimum decision cycle, move spacing, consensus timeout

### Performance Constraints
- Priority: **Medium**
- Violation Action: **Warn** or **Log**
- Modality: **Obligatory**
- Examples: Efficiency targets, response time targets

---

## Constraint-Measure Linkage

**Every constraint must link to a measurable quantity.** If you can't measure it, you can't constrain it.

### Verification Checklist

For each constraint, verify:

| Check | Question |
|-------|---------|
| **Measure exists** | Is there a measure (MEAS-###) for this quantity? |
| **Data source reliable** | Does the measure's data source update frequently enough? |
| **Latency acceptable** | Can the constraint be evaluated before the violation occurs? |
| **Rule parseable** | Is the rule expression in the format "measure_id OPERATOR value"? |
| **Value realistic** | Is the constraint value achievable under normal operations? |

### Supported Rule Operators

| Operator | Meaning | Example |
|----------|---------|---------|
| `<=` | Less than or equal | `MEAS-001 <= 2.0` |
| `>=` | Greater than or equal | `MEAS-006 >= 15.5` |
| `<` | Less than | `MEAS-005 < 0.5` |
| `>` | Greater than | `MEAS-010 > 30` |
| `==` | Equals | `incident_count == 0` |
| `!=` | Not equals | `controller_mode != manual` |

---

## Checklist

- [ ] Every safety-critical measure has at least one Critical/Block constraint
- [ ] Every constraint links to a valid measure with a reliable data source
- [ ] Rule expressions are parseable (measure_id OPERATOR value)
- [ ] Priority assigned based on consequence severity
- [ ] Violation action matches the urgency of the constraint
- [ ] Timing constraints defined for decision cycles and move spacing
- [ ] No constraint set at a value that's unachievable under normal operations
- [ ] Constraints reviewed against the utility functions — no conflicts between the hard limit and the utility target
