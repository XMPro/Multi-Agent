# Recommended Practice: Execution and Timing

*Back to [Implementation Guides](README.md) → Section 8.2-8.3*

---

## The Principle

Set execution timing based on **process physics**, not agent convenience. The process doesn't care how fast the LLM can think — it responds at its own pace. Agents must wait for the process to respond before evaluating results.

---

## Constraint Validation Before Execution

### The Validation Flow

Every plan must pass constraint validation before any action is executed:

```
Plan Created
    │
    ▼
Constraint Validator checks ALL active constraints
    │
    ├── All constraints satisfied → Plan APPROVED for execution
    │
    └── Any constraint violated → Plan REJECTED
        │
        ├── Violation details logged (which constraint, by how much)
        ├── Rejected option recorded (for audit trail)
        └── Agent must revise the plan
```

### What Gets Validated

The validator checks the plan's **predicted measure impacts** against each constraint:

| Check | What It Verifies |
|-------|-----------------|
| Projected values within limits | "Would this plan push impurity above 2.0 mol%?" |
| Rate-of-change within limits | "Would this plan change temperature by more than 2°C?" |
| Timing constraints respected | "Has enough time passed since the last move?" |
| Equipment ranges respected | "Would this setpoint be within the controller's operating range?" |

### Best Practice: Validate Early, Validate Often

- Validate **before execution starts** — don't discover violations mid-execution
- Validate against **current measure values** — not stale data from when the plan was created
- If conditions change during execution, **re-validate** remaining plan steps

---

## Move Spacing

### What Is Move Spacing?

Move spacing is the **minimum time between successive control actions** on the same variable. It ensures the process has time to respond to one change before the next is applied.

### How to Determine Move Spacing

```
Move Spacing = Process Response Time + Measurement Confirmation Time
```

| Component | What It Is | Typical Range |
|-----------|-----------|---------------|
| **Process response time** | How long for the process variable to respond meaningfully | 5-45 minutes (depends on process) |
| **Measurement confirmation time** | How long for the measurement to confirm the response | 0-15 minutes (depends on analyser) |

### Example: Distillation Column

| Variable | Process Response | Measurement Lag | Total Move Spacing |
|----------|-----------------|----------------|-------------------|
| Tray temperature (after reboiler change) | 14-16 min | 0 min (direct measurement) | **15-20 min** |
| Product impurity (after reflux change) | 15-25 min | 5-10 min (GC analyser deadtime) | **20-35 min** |
| Column pressure (after condenser change) | 2-5 min | 0 min (direct measurement) | **5 min** |

### Dual Spacing Modes

For some applications, two spacing modes are appropriate:

| Mode | Spacing | When Used | What Agent Evaluates |
|------|---------|-----------|---------------------|
| **Normal** | Full response + confirmation time | Standard operation | Full process response confirmed by measurement |
| **Urgent** | Response time only (no confirmation wait) | Approaching limits | Direction and rate of change from fast-responding variables |

**Trigger for urgent mode**: When a constraint-related measure is trending toward its limit (e.g., impurity approaching 1.8 mol% with a 2.0 mol% constraint).

---

## Analyser Deadtime

### What It Is

Many process measurements have **deadtime** — a delay between when a real change occurs in the process and when the measurement reflects it.

### Common Sources of Deadtime

| Source | Typical Deadtime | Example |
|--------|-----------------|---------|
| GC analyser cycle | 3-5 minutes | Gas chromatograph completes one analysis cycle |
| GC analyser transport | 2-5 minutes | Sample travels from process to analyser |
| Lab analysis | 30-60 minutes | Sample taken, transported, analysed, result entered |
| Model calculation | 1-5 minutes | Soft sensor or virtual analyser computation time |
| Direct measurement | ~0 | Temperature, pressure, flow (essentially instantaneous) |

### How Deadtime Affects Agent Behaviour

```
t=0:   Agent writes new setpoint
t=15:  Process responds (tray temperature changes)     ← Agent can see this
t=20:  GC analyser starts reflecting the change         ← Agent can see this
t=25:  GC analyser fully reflects the change            ← Agent can confirm

If the agent evaluates at t=10: "Nothing happened" → WRONG (too early)
If the agent evaluates at t=15: "Temperature moved" → PARTIAL (no quality confirmation)
If the agent evaluates at t=25: "Quality confirmed" → CORRECT (full picture)
```

### Best Practice: Temperature-First Monitoring

Use fast-responding measurements (temperatures, pressures, flows) as **early indicators** of whether a control action is having its expected effect. Wait for slow-responding measurements (analysers) for **confirmation**.

| Phase | What to Monitor | When |
|-------|----------------|------|
| **Immediate** (0-5 min) | Flow changes, pressure response | Confirm the control action was accepted |
| **Early** (5-15 min) | Temperature trends, direction and rate | Confirm the process is responding in the expected direction |
| **Confirmation** (15-30 min) | Analyser readings, quality measurements | Confirm the final effect on product quality |

### Agent Profile Implications

- **Monitor**: Flag analyser readings as potentially stale if a setpoint change was executed within the deadtime window
- **Analyst**: Use temperature trends as leading indicators; note when GC has not yet confirmed
- **Decision-Maker**: In urgent mode, decide on temperature trends; in normal mode, wait for GC confirmation
- **Executor**: Monitor flow/temperature PV for immediate response; don't expect quality confirmation within the PV monitoring window

---

## Timing Configuration Summary

| Parameter | How to Set It | Typical Range |
|-----------|--------------|---------------|
| **Planning cycle interval** | 0.5-1.0× process response time | 5-30 minutes |
| **Move spacing (normal)** | Process response + measurement confirmation | 15-35 minutes |
| **Move spacing (urgent)** | Process response only (early indicators) | 10-20 minutes |
| **PV monitoring window** | Long enough to see initial response | 5-15 minutes |
| **Analyser deadtime awareness** | Total cycle + transport time | 5-15 minutes |
| **Constraint evaluation frequency** | Guardian background check interval | 0.3-0.5× planning cycle |
| **Escalation response** | Immediate — no waiting for planning cycle | < 1 minute |

---

## Checklist

- [ ] Move spacing set based on process response time (not agent processing time)
- [ ] Analyser deadtimes identified and documented for all quality measurements
- [ ] Temperature-first monitoring strategy defined (fast indicators before slow confirmation)
- [ ] Dual spacing modes defined if applicable (normal vs urgent)
- [ ] Urgent mode trigger conditions defined (approaching constraint limits)
- [ ] Constraint validation configured to run before plan execution
- [ ] PV monitoring window appropriate for the measurement type
- [ ] Agent profiles account for analyser deadtime in their reasoning
- [ ] Escalation paths bypass the planning cycle for time-critical situations
