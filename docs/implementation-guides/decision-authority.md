# Recommended Practice: Decision Authority Levels

*Back to [Implementation Guides](README.md) → Section 2.4*

---

## The Principle

Every action an agent can take must have a clearly defined authority level. Ambiguity about who can decide what leads to either agents overstepping their bounds or agents failing to act when they should.

---

## The Four Authority Levels

### Level 1: Independent

The agent decides and acts **without approval from anyone**.

**When to use:**
- Routine operations within well-defined bounds
- Actions where the risk of a wrong decision is low and recoverable
- High-frequency decisions where waiting for approval would be impractical

**Examples:**
- Adjusting a setpoint within agreed operating bands
- Switching between pre-approved operating strategies
- Collecting and distributing data

**Configuration guidance:**
- Define the bounds explicitly (e.g., "FC3103 SP between 10-18.5 t/h")
- Include rate-of-change limits (e.g., "maximum 2°C per move")
- Ensure constraints are in place to catch errors

### Level 2: Consensus

The agent proposes, but **team agreement is required** before acting.

**When to use:**
- Decisions near safety or quality limits
- Actions that affect multiple agents' domains
- Situations where independent judgment from multiple perspectives is needed

**Examples:**
- Setpoint changes where predicted impurities would be between 1.8-2.0 mol% (close to limit)
- Simultaneous changes to multiple controllers
- Actions at the edge of rate-of-change limits

**Configuration guidance:**
- Define which agents must participate in consensus
- Set voting rules (majority, unanimity, specific agent must agree)
- Set timeout with fallback action (what happens if consensus isn't reached?)

### Level 3: Human Approval

The agent proposes, but **a human must approve** before the agent acts.

**When to use:**
- Actions outside agreed operating bands
- Cumulative changes exceeding thresholds
- Situations where the agent's authority is insufficient
- Response to abnormal conditions

**Examples:**
- Temperature setpoint changes exceeding 3°C cumulative per shift
- Any proposed setpoint outside agreed bands
- Changes during active alarm conditions
- Overriding a Guardian veto

**Configuration guidance:**
- Define the approval authority (Shift Supervisor, Process Engineer, etc.)
- Set a timeout with default action (conservative hold if no response)
- Provide the human with the agent's reasoning and data

### Level 4: Escalation

The agent **immediately alerts humans** — this is not a request for approval but a notification that something requires urgent attention.

**When to use:**
- Safety-critical situations
- Equipment failures or anomalies
- Conditions the agent cannot handle
- Constraint violations or imminent violations

**Examples:**
- Any impurity reading above 1.9 mol% and rising
- Analyser failure or stale data
- Equipment alarms triggered
- Any constraint violation detected or predicted

**Configuration guidance:**
- Escalation must be immediate — no waiting for the next planning cycle
- Use conditional duties in agent profiles (IF condition THEN escalate)
- Multiple notification channels (dashboard alert, SMS, email)
- The agent should also take conservative protective action if possible

---

## How to Assign Authority Levels

### Decision Tree

```
Is this action within well-defined, safe operating bounds?
├── Yes → Is the risk of error low and recoverable?
│   ├── Yes → INDEPENDENT
│   └── No → CONSENSUS (get team agreement)
└── No → Is this an emergency or safety situation?
    ├── Yes → ESCALATION (immediate human alert)
    └── No → HUMAN APPROVAL (propose and wait)
```

### Authority Matrix Template

For each action the team can take, fill in this matrix:

| Action | Normal Conditions | Near Limits | Abnormal Conditions | Emergency |
|--------|------------------|-------------|--------------------|-----------| 
| Adjust reflux SP | Independent | Consensus | Human Approval | Escalation |
| Adjust temperature SP | Independent | Consensus | Human Approval | Escalation |
| Switch operating strategy | Independent | Consensus | Human Approval | Escalation |
| Override Guardian veto | N/A | N/A | Human Approval | N/A |
| Report alarm | Independent | Independent | Escalation | Escalation |

---

## Common Patterns by Use Case Type

### Advisory Use Case (Agent recommends, human decides)
```
All actions → Human Approval or Escalation
No Independent or Consensus actions
```

### Supervised Autonomous (Agent acts within bounds, human oversees)
```
Within bounds → Independent
Near limits → Consensus
Outside bounds → Human Approval
Safety events → Escalation
```

### Fully Autonomous (Agent acts freely within safety envelope)
```
Within envelope → Independent
Near envelope edge → Consensus
Outside envelope → Human Approval
Safety events → Escalation
```

---

## Checklist

- [ ] Every agent action has a defined authority level
- [ ] Authority levels are documented in the team configuration
- [ ] Independent actions have explicit bounds and constraints
- [ ] Consensus actions define participating agents and voting rules
- [ ] Human approval actions define the approval authority and timeout
- [ ] Escalation actions define notification channels and protective actions
- [ ] No action is left without a defined authority level
