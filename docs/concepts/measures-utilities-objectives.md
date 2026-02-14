# MAGS: Measures, Utility Functions, and Objective Functions

## The One-Sentence Version

A **measure** is a number from the real world. A **utility function** turns that number into a value judgment. An **objective function** combines multiple value judgments into one decision score.

---

## The Analogy: A Restaurant Review

Imagine you're rating a restaurant:

1. **Measures** — The raw facts:
   - Wait time: 25 minutes
   - Food temperature: 72°C
   - Bill total: $85
   - Noise level: 78 dB

2. **Utility Functions** — How you feel about each fact:
   - 25-minute wait → 0.60 satisfaction (acceptable but not great)
   - 72°C food → 0.90 satisfaction (nice and hot)
   - $85 bill → 0.45 satisfaction (a bit expensive)
   - 78 dB noise → 0.30 satisfaction (too loud)

3. **Objective Function** — Your overall rating:
   - Overall = 0.3 × food_temp + 0.3 × price + 0.2 × wait + 0.2 × noise
   - Overall = 0.3(0.90) + 0.3(0.45) + 0.2(0.60) + 0.2(0.30) = **0.585**

Notice: the raw numbers (25 min, 72°C, $85, 78 dB) are in completely different units and scales. You can't average them directly. The utility functions normalise everything to a 0-1 scale, and the objective function weights and combines them.

---

## The Three Layers in Detail

### Layer 1: Measures

A measure is a **raw value from the real world** with a unit.

| What It Is | What It Isn't |
|-----------|--------------|
| A sensor reading | A judgment about whether the reading is good or bad |
| A calculated value | A decision about what to do |
| A number with a unit | A normalised score |

**Examples:**
- Column pressure: 16.9 barg
- Steam flow: 3.46 t/h
- Product impurity: 1.65 mol%
- Profit per hour: 250 AUD/h

Measures come from data sources — DCS tags, analysers, calculated values, price feeds. They are **objective facts** about the current state of the world.

**Key properties of a measure:**
- ID and name
- Unit of measurement
- Data source (where it comes from)
- Update frequency (how often it changes)
- Whether it's safety-critical

### Layer 2: Utility Functions

A utility function **transforms a raw measure into a normalised value between 0 and 1** that represents how desirable that value is.

| What It Is | What It Isn't |
|-----------|--------------|
| A value judgment (how good is this?) | A raw measurement |
| A normalised score (0 = terrible, 1 = ideal) | A decision about what to do |
| A curve that maps raw values to desirability | A constraint (hard limit) |

**The four types of curves:**

```
LINEAR              LOGARITHMIC         EXPONENTIAL         INVERSE EXPONENTIAL
1.0 ─────/          1.0 ──────╮         1.0          ╭──    1.0 ──╮
         /                    │                      /              │
0.5 ───/            0.5      │          0.5        /       0.5     │
       /                      │                    /                │
0.0 /               0.0      └──        0.0 ──────         0.0     └──
   min    max          min    max          min    max          min    max

Each unit of       First improvements   Excellence is       Approaching limits
improvement has    matter most;         disproportionately  becomes increasingly
equal value        diminishing returns  valuable            painful
```

**Example — Inverse Exponential for impurity:**
- 0.0 mol% → 1.0 utility (perfect — no impurity)
- 1.0 mol% → 0.90 utility (excellent — large margin)
- 1.5 mol% → 0.75 utility (good — comfortable)
- 1.8 mol% → 0.50 utility (acceptable — margin narrowing)
- 1.95 mol% → 0.25 utility (poor — very close to limit)
- 2.5 mol% → 0.0 utility (violation)

The **steepness** parameter controls how aggressively the curve drops near the limit. A steepness of 3.5 gives a moderate curve; 5.0 gives an aggressive one that penalises approaching the limit much more harshly.

**Key properties of a utility function:**
- Which measure it transforms
- Curve type (Linear, Logarithmic, Exponential, Inverse Exponential)
- Target value (ideal)
- Min and max range
- Steepness (for exponential types)

### Layer 3: Objective Functions

An objective function **combines multiple utility values into a single score** that drives agent decisions.

| What It Is | What It Isn't |
|-----------|--------------|
| A weighted combination of utilities | A single utility function |
| The agent's decision-making compass | A constraint or hard limit |
| A score that says "how well are we doing overall?" | A measure of any single variable |

**Aggregation methods:**
- **Weighted Sum**: Score = w₁×U₁ + w₂×U₂ + w₃×U₃ (most common)
- **Weighted Product**: Score = U₁^w₁ × U₂^w₂ × U₃^w₃ (penalises any zero heavily)
- **MinMax**: Score = MIN(U₁, U₂, U₃) (only as good as the worst component)
- **Nash Product**: Balanced fairness across all components

**Example — MinMax for safety monitoring:**
```
Technical Health = MIN(
    Impurity_Top_Utility,      // 0.75
    Impurity_Bottom_Utility,   // 0.82
    Column_dP_Utility,         // 0.90
    Pressure_Utility,          // 0.95
    Drum_Level_Utility,        // 0.88
    Sump_Level_Utility         // 0.91
)
= 0.75  (limited by top impurity)
```

With MinMax, the overall score equals the worst-performing component. This ensures no single problem is masked by good performance elsewhere.

---

## The Complete Chain

```
Real World          Layer 1              Layer 2              Layer 3
──────────          ───────              ───────              ───────

Sensor: 85°C   →   Measure: 85°C    →   Utility: 0.70    ─┐
Sensor: 0.4 bar →  Measure: 0.4 bar →   Utility: 0.55    ─┤→  Objective: 0.55
Sensor: 50%     →  Measure: 50%     →   Utility: 1.00    ─┤   (MinMax = worst)
Price: 700 AUD  →  Measure: 700 AUD →   Utility: 0.85    ─┘
```

---

## Common Mistakes

### Mistake 1: Skipping the Utility Layer

❌ "Just use the raw pressure value in the objective function"

This doesn't work because raw values have different units and scales. Pressure in barg, temperature in °C, and impurity in mol% can't be meaningfully combined without normalisation.

### Mistake 2: Putting Constraints in Utility Functions

❌ "Set the utility to 0 if impurity exceeds 2.0 mol%"

Utility functions express **preferences**, not **hard limits**. A utility of 0 means "very undesirable" but doesn't prevent the agent from choosing that option. Use the constraint system for hard limits that must never be violated.

### Mistake 3: Double-Counting in Objectives

❌ "Include both Profit/hr AND Steam Cost in the objective"

If profit/hr already includes steam cost (Profit = Revenue - Steam Cost), adding steam cost separately double-counts its influence. Each real-world factor should appear once in the objective, either directly or embedded in a composite measure.

### Mistake 4: One Utility Per Agent

❌ "The Monitor agent has its own utility function for pressure"

Utility functions are shared across agents — they define how the TEAM values a measure. Different agents may use different subsets of utilities, and some agents may use the same utility with different steepness (e.g., the Guardian uses steeper impurity curves), but the utility function itself is a team-level concept.

---

## Summary Table

| Aspect | Measure | Utility Function | Objective Function |
|--------|---------|-----------------|-------------------|
| **What** | Raw value | Normalised value judgment | Combined decision score |
| **Scale** | Physical units (°C, bar, mol%) | 0 to 1 | 0 to 1 |
| **Answers** | "What is the value?" | "How good is this value?" | "How well are we doing overall?" |
| **Count** | 10-20 per team (typical) | One per measure | 1-2 per team + one per agent |
| **Changes** | Every few seconds/minutes | Only when preferences change | Only when team strategy changes |
| **Configured by** | Data engineers | Domain experts | Team designers |
