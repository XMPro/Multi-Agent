# Recommended Practice: Steepness Tuning

*Back to [Implementation Guides](README.md) → Section 4.3*

---

## The Principle

Steepness controls **how aggressively** the utility function responds near limits. Higher steepness means the agent feels more urgency as values approach boundaries. Tuning steepness is how you calibrate agent caution.

---

## What Steepness Does

For Inverse Exponential and Exponential utility functions, the steepness parameter (typically 2.0-5.0) controls the curve shape:

```
Low steepness (2.0):              High steepness (5.0):
Gradual, gentle curve              Sharp, aggressive curve

1.0 ──╲                           1.0 ──╲
       ╲                                  │
0.5     ╲                         0.5     │
          ╲                                │
0.0        ╲──                    0.0      └──
    ideal    limit                    ideal    limit

Agent is relaxed about              Agent is very concerned about
approaching the limit               approaching the limit
```

At steepness 2.0, the utility drops gradually — the agent treats approaching the limit as a moderate concern. At steepness 5.0, the utility drops sharply — the agent treats approaching the limit as an urgent problem.

---

## Steepness Ranges and Their Meaning

| Steepness | Behaviour | Use For |
|-----------|-----------|---------|
| **2.0-2.5** | Gentle — moderate concern near limits | Cost metrics, non-critical performance targets |
| **3.0-3.5** | Moderate — standard risk aversion | Most operational measures, quality targets |
| **4.0-4.5** | Aggressive — strong concern near limits | Safety-adjacent measures, equipment limits |
| **5.0+** | Very aggressive — near-panic near limits | Safety-critical measures, Guardian agent variations |

---

## Agent-Specific Steepness Variations

The same measure can have **different steepness for different agents**. This is a powerful design tool:

| Agent | Steepness | Why |
|-------|-----------|-----|
| Standard agents | 3.5 | Balanced concern — optimise while being aware of limits |
| Guardian agent | 5.0 | Heightened concern — feel urgency earlier, resist proposals that push toward limits |

**Example — Impurity at 1.8 mol% (limit is 2.0):**

| Agent | Steepness | Utility at 1.8 mol% | Agent's Feeling |
|-------|-----------|---------------------|----------------|
| Decision-Maker | 3.5 | ~0.50 | "Acceptable — margin is narrowing but we can still optimise" |
| Guardian | 5.0 | ~0.35 | "Concerning — we should not push any closer" |

This difference in perception creates the **structural tension** between the optimiser (who sees opportunity) and the validator (who sees risk). The Decision-Maker proposes; the Guardian resists. The team finds the right balance.

---

## How to Tune Steepness

### Starting Point

1. Start with **3.0-3.5** for all measures
2. Run the system and observe agent behaviour
3. Adjust based on what you see

### Tuning Up (Increase Steepness)

**Symptom**: Agent is too relaxed about approaching limits
- Proposes operating points very close to constraints
- Doesn't show urgency when values trend toward limits
- Guardian approves proposals that feel too aggressive

**Action**: Increase steepness by 0.5-1.0

### Tuning Down (Decrease Steepness)

**Symptom**: Agent is too conservative
- Refuses to operate anywhere near limits even when it's safe
- Leaves significant economic value on the table
- Guardian vetoes proposals that are well within safe bounds

**Action**: Decrease steepness by 0.5-1.0

### The Iteration Cycle

```
1. Set initial steepness (3.0-3.5)
2. Run the system against test scenarios
3. Observe: Is the agent too aggressive or too conservative?
4. Adjust steepness ±0.5
5. Repeat until behaviour matches expectations
```

---

## Steepness by Measure Category

| Category | Recommended Steepness | Rationale |
|----------|---------------------|-----------|
| Safety-critical (impurity, pressure, levels) | 3.5 standard / 5.0 Guardian | Safety measures need aggressive curves, especially for the Guardian |
| Equipment limits (dP, temperature ranges) | 4.0-4.5 | Equipment damage is expensive and dangerous |
| Cost metrics (steam, energy, reagents) | 2.5-3.0 | Cost overruns are painful but not dangerous |
| Quality targets (purity, grade) | 3.0-3.5 | Quality matters but has more tolerance than safety |
| Performance indicators (throughput, efficiency) | 2.0-3.0 | Performance is desirable but flexible |
| Context measures (feed composition, prices) | N/A (use Linear) | External inputs — no steepness needed |

---

## Checklist

- [ ] All Inverse Exponential and Exponential utilities have steepness assigned
- [ ] Safety-critical measures have steepness ≥ 3.5 (standard) and ≥ 5.0 (Guardian)
- [ ] Cost metrics have moderate steepness (2.5-3.0)
- [ ] Guardian agent has higher steepness than other agents for shared measures
- [ ] Steepness has been tested against representative scenarios
- [ ] Agent behaviour matches expectations (not too aggressive, not too conservative)
