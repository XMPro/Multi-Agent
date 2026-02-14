# MAGS: Constraints vs Utility Functions

## The One-Sentence Version

A **utility function** says "I prefer this." A **constraint** says "I forbid that."

---

## The Analogy: Buying a House

When you're house-hunting, you have two types of criteria:

**Constraints** (non-negotiable):
- Must have at least 3 bedrooms (you have 3 kids — this is not flexible)
- Must be within 30 minutes of the school (non-negotiable for the family)
- Must be under $800,000 (that's what the bank approved)

**Preferences** (utility functions):
- Prefer a bigger garden (but a small one is acceptable)
- Prefer a newer kitchen (but you can renovate)
- Prefer a quiet street (but a busy one isn't a dealbreaker)

If a house violates a constraint (2 bedrooms, 45 minutes from school, $900,000), **you don't even consider it** — it's eliminated before you start comparing. If a house has a small garden, you still consider it — you just rate it lower.

In MAGS:
- **Constraints** eliminate options before optimisation begins
- **Utility functions** rank the remaining options by desirability

---

## The Key Differences

| Aspect | Constraint | Utility Function |
|--------|-----------|-----------------|
| **Purpose** | Eliminate unacceptable options | Rank acceptable options |
| **Response to violation** | Plan is rejected (Block), flagged (Warn), or logged (Log) | Low score — undesirable but not forbidden |
| **Scale** | Binary: satisfied or violated | Continuous: 0.0 to 1.0 |
| **When evaluated** | Before optimisation (filter) | During optimisation (score) |
| **Can be overridden?** | Critical: never. High: only with human approval | Always — it's a preference, not a rule |
| **Example** | "Impurity MUST NOT exceed 2.0 mol%" | "Lower impurity is preferred (steepness 3.5)" |

---

## How They Work Together

```
All possible operating points
        │
        ▼
┌─────────────────────────┐
│   CONSTRAINT FILTER      │
│                          │
│   Impurity ≤ 2.0? ──── Yes ──┐
│   Pressure ≥ 15.5? ─── Yes ──┤
│   Move size ≤ 2°C? ─── Yes ──┤──→ Passes all constraints
│   Level in 30-70%? ─── Yes ──┘
│                          │
│   Any "No"? ─────────── REJECTED (plan cannot proceed)
└─────────────────────────┘
        │
        ▼ (only options that passed ALL constraints)
┌─────────────────────────┐
│   UTILITY SCORING        │
│                          │
│   Impurity utility: 0.75 │
│   Profit utility:   0.82 │
│   Steam utility:    0.68 │
│                          │
│   Objective = weighted   │
│   combination = 0.77     │
└─────────────────────────┘
        │
        ▼
   Best option selected (highest objective score among constraint-satisfying options)
```

Constraints act as a **gate**. Utility functions act as a **ranking**. You must pass the gate before you can be ranked.

---

## The Confusing Middle Ground

### Why Steep Utility Functions Look Like Constraints

A utility function with high steepness (e.g., 5.0) drops very sharply near a limit:

```
Steepness 3.5 (standard):          Steepness 5.0 (Guardian):
1.0 ──╮                            1.0 ──╮
       ╲                                   ╲
0.5    ╲                           0.5     │
        ╲                                  │
0.0     ╲──                        0.0     └──
   0   1.0  2.0  2.5                 0   1.0  2.0  2.5
```

At steepness 5.0, the utility drops to near-zero well before the actual limit. This **looks** like a constraint — the agent strongly avoids that region. But it's fundamentally different:

- A **constraint** at 2.0 mol% means: "If the plan would result in 2.1 mol%, reject the plan entirely"
- A **utility** with steepness 5.0 means: "2.1 mol% has very low utility (0.05), so the agent will strongly prefer alternatives — but if no better option exists, it could still choose it"

### When to Use Which

| Situation | Use Constraint | Use Utility Function |
|-----------|---------------|---------------------|
| Safety limit that must never be exceeded | ✅ | Also ✅ (for gradient) |
| Equipment operating range | ✅ | Also ✅ (for preference within range) |
| Economic preference (lower cost is better) | ❌ | ✅ |
| Regulatory requirement | ✅ | ❌ (not a preference) |
| Timing rule (minimum spacing between moves) | ✅ | ❌ |
| Quality target (closer to target is better) | ❌ | ✅ |

**Best practice**: For safety-critical measures, use **BOTH**:
- A constraint to enforce the hard limit (Block if violated)
- A utility function to guide the agent away from the limit (gradient toward safety)

This gives you a hard floor (constraint) plus a soft preference to stay well above the floor (utility).

---

## Constraint Properties That Utility Functions Don't Have

Constraints in MAGS have properties that make them fundamentally different from utility functions:

### Deontic Modality
- **Obligatory**: This condition MUST be maintained (e.g., "impurity must stay below 2.0")
- **Prohibited**: This condition MUST NOT occur (e.g., "flooding must not happen")
- **Permitted**: This condition MAY occur within bounds (e.g., "pressure may vary between 15.5-18.0")

Utility functions don't have modality — they just express preference.

### Violation Action
- **Block**: Plan is rejected — the agent must revise
- **Warn**: Plan proceeds but violation is escalated for human review
- **Log**: Violation is recorded but doesn't prevent action

Utility functions never block anything — they just score low.

### Priority
- **Critical**: Cannot be overridden by any agent (safety, regulatory)
- **High**: Requires human escalation to override
- **Medium**: Can be temporarily relaxed with justification
- **Low**: Can be relaxed freely

Utility functions don't have priority levels — they're all preferences.

---

## Common Mistakes

### Mistake 1: Using Only Constraints (No Utilities)

❌ "Just set hard limits for everything"

Without utility functions, the agent has no way to distinguish between "barely acceptable" and "excellent." All constraint-satisfying options look equally good. The agent can't optimise — it can only filter.

### Mistake 2: Using Only Utilities (No Constraints)

❌ "The steep utility function will keep the agent away from the limit"

Without constraints, there's no hard floor. If the optimisation finds a scenario where violating the limit gives a higher overall objective score (because other utilities compensate), the agent might choose it. Constraints provide the non-negotiable safety net.

### Mistake 3: Setting Constraint Limits at the Utility Target

❌ "Constraint: impurity ≤ 1.5 mol% AND Utility target: 1.5 mol%"

This leaves no room for the utility function to work. The constraint should be at the **hard limit** (e.g., 2.0 mol%), and the utility function should guide the agent toward the **preferred operating point** (e.g., target 0.0, with steepness creating a gradient). The space between the utility target and the constraint limit is where optimisation happens.

---

## Summary

```
                    Utility Function              Constraint
                    ────────────────              ──────────
Nature:             Preference (soft)             Rule (hard)
Scale:              0.0 ──── 1.0                  Pass / Fail
Effect:             Guides optimisation            Gates optimisation
Violation:          Low score (undesirable)        Plan rejected (forbidden)
Override:           Always possible                Requires escalation or approval
Best for:           Economic trade-offs            Safety limits, regulatory rules
                    Quality targets                Equipment boundaries
                    Operational preferences        Timing constraints
```
