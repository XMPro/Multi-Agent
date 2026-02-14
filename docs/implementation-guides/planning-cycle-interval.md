# Recommended Practice: Planning Cycle Interval

*Back to [Implementation Guides](README.md) → Section 3.5*

---

## The Principle

Set the planning cycle interval based on **process dynamics**, not LLM speed. The interval should match how quickly the environment changes and how long it takes for actions to have effect.

---

## How to Choose the Interval

### The Formula

```
Planning Cycle Interval ≈ Process Response Time × 0.5 to 1.0
```

If the process takes 15 minutes to respond to a setpoint change, the planning cycle should be 8-15 minutes. This ensures the agent evaluates the result of its last action before deciding the next one.

### By Domain

| Domain | Typical Process Response | Recommended Interval | Rationale |
|--------|------------------------|---------------------|-----------|
| Chemical process control | 15-45 min | 10-30 min | Column dynamics, analyser lag |
| Equipment monitoring | Hours to days | 30-60 min | Degradation is slow |
| Energy management | 15-60 min | 15-30 min | Load changes, price updates |
| Supply chain | Hours to days | 1-4 hours | Logistics timescales |
| Incident investigation | Hours | 30-60 min | Information gathering pace |
| Financial trading | Minutes | 5-15 min | Market volatility |

### By Agent Role

Not all agents in a team need the same interval:

| Role | Interval Relative to Team | Why |
|------|--------------------------|-----|
| Monitor | 0.1-0.5× (faster) | Needs to detect changes quickly |
| Analyst | 1× (same as team) | Analyses on the decision cycle |
| Decision-Maker | 1× (same as team) | Decides on the decision cycle |
| Guardian | 0.3-0.5× (faster) | Background constraint monitoring |
| Executor | Triggered (no fixed interval) | Acts when approved, not on a timer |

---

## The Goldilocks Zone

### Too Short (< 0.5× process response time)

**Symptoms**:
- Agent replans before seeing the effect of its last action
- Excessive LLM calls with no new information
- Plan churn — constantly creating new plans that supersede the previous one
- High cost with no improvement in outcomes

### Just Right (0.5-1.0× process response time)

**Symptoms**:
- Agent evaluates results of previous actions before deciding next steps
- Plans are stable — only change when conditions genuinely change
- Reasonable LLM cost
- Good responsiveness to real changes

### Too Long (> 2× process response time)

**Symptoms**:
- Agent misses changes that happened between cycles
- Slow response to disturbances
- Multiple process changes accumulate before the agent reacts
- Operators lose confidence in the agent's responsiveness

---

## Special Considerations

### Analyser Deadtime

If your process has analysers with significant deadtime (e.g., GC analysers with 5-minute cycle + 5-minute deadtime), the planning cycle must account for this:

```
Effective Response Time = Process Response Time + Analyser Deadtime
Planning Cycle ≈ Effective Response Time × 0.5 to 1.0
```

### Multiple Response Times

If the agent monitors variables with different response times (e.g., temperature responds in 15 min, analyser in 25 min), use the **longest relevant response time** for the planning cycle. The agent can use faster-responding variables as early indicators within the cycle.

### Dual Spacing (Normal vs Urgent)

For some applications, two intervals are appropriate:
- **Normal**: Based on full process response time (e.g., 20 min)
- **Urgent**: Based on early indicator response time (e.g., 10 min) — used when approaching limits

---

## Checklist

- [ ] Process response time identified for all key variables
- [ ] Analyser deadtimes accounted for
- [ ] Planning cycle set to 0.5-1.0× effective response time
- [ ] Monitor agent has a shorter interval than the team cycle
- [ ] Guardian has a shorter interval for background monitoring
- [ ] Executor is triggered (not timer-based)
- [ ] Interval tested — agent sees results before replanning
