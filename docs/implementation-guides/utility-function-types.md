# Recommended Practice: Choosing Utility Function Types

*Back to [Implementation Guides](README.md) → Section 4.2*

---

## The Principle

The utility function type determines **how the agent values changes** in a measure. Choose the type that matches the real-world value pattern — not every measure has the same shape of preference.

---

## The Four Types — When to Use Each

### Linear: Equal Value Per Unit

```
Utility
1.0 ─────────/
             /
0.5 ───────/
           /
0.0 ─────/
    min      max
```

**Use when**: Each unit of improvement has the same value as the last. There are no diminishing returns and no accelerating benefits.

**Decision rule**: "Is the 10th unit of improvement worth the same as the 1st?"
- If yes → Linear

**Common applications**:
| Measure | Why Linear |
|---------|-----------|
| Profit per hour | Each additional dollar has equal value |
| Price spread | Each AUD/t of spread has proportional economic impact |
| Feed composition (as context) | Proportional change in separation difficulty |
| Ambient conditions | Proportional effect on process |

### Logarithmic: Diminishing Returns

```
Utility
1.0 ──────────╮
              │
0.5          │
            │
0.0        └──
    min      max
```

**Use when**: Initial improvements matter a lot, but additional improvements matter progressively less. The first unit is very valuable; the 10th unit barely moves the needle.

**Decision rule**: "Does the value of improvement decrease as you get more of it?"
- If yes → Logarithmic

**Common applications**:
| Measure | Why Logarithmic |
|---------|----------------|
| Production throughput | First units critical; excess capacity less valuable |
| Reflux ratio | Initial reflux essential; excess reflux wastes energy |
| Data collection rate | 90% coverage is critical; 99% vs 99.5% barely matters |
| Storage/buffer capacity | Having some is essential; having lots is nice but not critical |

### Exponential: Accelerating Value

```
Utility
1.0          ╭──
            /
0.5        /
          /
0.0 ──────
    min      max
```

**Use when**: Excellence is disproportionately valuable. Being good is fine, but being excellent is worth much more than the incremental improvement suggests.

**Decision rule**: "Is the difference between 90% and 95% worth more than the difference between 50% and 55%?"
- If yes → Exponential

**Common applications**:
| Measure | Why Exponential |
|---------|----------------|
| Equipment reliability (OEE) | 99% uptime is worth far more than 95% |
| Product purity (when selling premium) | Premium grade commands disproportionate price |
| Safety performance | Near-zero incidents is exponentially more valuable |
| Precision/accuracy | High precision enables capabilities that moderate precision cannot |

### Inverse Exponential: Accelerating Pain

```
Utility
1.0 ──╮
       │
0.5    │
        │
0.0     └──
    min      max
```

**Use when**: Approaching a limit becomes increasingly painful. Small deviations from ideal are tolerable, but getting close to the limit is disproportionately bad.

**Decision rule**: "Does the pain of getting worse accelerate as you approach the limit?"
- If yes → Inverse Exponential

**Common applications**:
| Measure | Why Inverse Exponential |
|---------|----------------------|
| Product impurity (approaching spec limit) | 1.5 mol% is fine; 1.9 mol% is concerning; 2.0 mol% is critical |
| Equipment temperature (approaching design limit) | Normal range is comfortable; near-limit is dangerous |
| Column differential pressure (flooding risk) | Normal dP is fine; high dP risks flooding |
| Cost overruns | Small overruns are manageable; large overruns are catastrophic |
| Level (approaching trip setpoints) | Mid-range is fine; extremes trigger safety systems |

---

## Decision Tree

```
Does each unit of improvement have equal value?
├── Yes → LINEAR
└── No → Does value increase or decrease with more improvement?
    ├── Decreases (diminishing returns) → LOGARITHMIC
    └── Increases → Is it about approaching a limit (pain) or achieving excellence (reward)?
        ├── Approaching a limit (pain accelerates) → INVERSE EXPONENTIAL
        └── Achieving excellence (reward accelerates) → EXPONENTIAL
```

---

## Distribution Patterns by Use Case

| Use Case Type | Typical Distribution |
|--------------|---------------------|
| Process optimisation | 60% Inverse Exponential, 20% Linear, 15% Logarithmic, 5% Exponential |
| Equipment monitoring | 50% Inverse Exponential, 30% Exponential, 15% Linear, 5% Logarithmic |
| Financial/economic | 50% Linear, 30% Inverse Exponential, 15% Logarithmic, 5% Exponential |
| Quality management | 40% Exponential, 35% Inverse Exponential, 15% Linear, 10% Logarithmic |

---

## Checklist

- [ ] Each measure has a utility function type assigned
- [ ] Type selection matches the real-world value pattern (not assumed)
- [ ] Safety-critical measures use Inverse Exponential (accelerating pain near limits)
- [ ] Economic measures use Linear (proportional value) unless there are clear diminishing returns
- [ ] No measure is left without a utility function
- [ ] The distribution of types makes sense for the use case domain
