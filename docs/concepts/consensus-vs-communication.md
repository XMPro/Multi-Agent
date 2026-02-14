# MAGS: Consensus vs Communication

## The One-Sentence Version

**Communication** is agents talking to each other. **Consensus** is agents formally agreeing on something.

---

## The Analogy: A Meeting vs an Email

**Communication** is like sending an email:
- "Hey, I noticed the feed composition changed — thought you should know"
- One agent sends information to another
- The recipient reads it, thinks about it, and may or may not act on it
- No formal agreement is required
- Quick, lightweight, happens all the time

**Consensus** is like a formal meeting with a vote:
- "I propose we change the temperature setpoint to 82°C. All in favour?"
- Multiple agents participate in a structured negotiation
- There are proposals, counter-proposals, and voting
- The outcome is binding — everyone must follow the agreed decision
- Heavyweight, structured, happens only when needed

You wouldn't call a formal meeting every time you want to share a piece of information. And you wouldn't send an email when you need everyone to formally agree on a critical decision.

---

## The Two Concepts in Detail

### Communication: Sharing Information

Communication is the **exchange of information between agents** — one agent tells another something.

| What It Is | What It Isn't |
|-----------|--------------|
| Sending information from one agent to another | A formal agreement process |
| Lightweight and frequent | Heavyweight and structured |
| One-way or conversational | Multi-party negotiation |
| Informational — no binding outcome | Binding — outcome must be followed |

**How communication works in MAGS:**

1. An agent decides it has information worth sharing (via a Communication Decision)
2. The agent publishes a message to the recipient's topic via the message broker (MQTT)
3. The recipient receives the message and processes it as an observation
4. The recipient may or may not change its behaviour based on the information

**Types of communication:**
- **State updates**: "Here's the current process state" (Monitor → Analysts)
- **Assessments**: "Here's my analysis of the situation" (Analyst → Decision-Maker)
- **Proposals**: "I propose this setpoint change" (Decision-Maker → Guardian)
- **Approvals/Rejections**: "Approved" or "Vetoed with reasons" (Guardian → Executor)
- **Alerts**: "Critical alarm detected" (Monitor → All agents)

**Communication is asynchronous** — the sender publishes and moves on. The recipient processes the message on its own cycle. There's no waiting for acknowledgment.

### Consensus: Formal Agreement

Consensus is a **structured multi-agent negotiation process** that produces a binding outcome.

| What It Is | What It Isn't |
|-----------|--------------|
| A formal negotiation with proposals and voting | A casual information exchange |
| Multi-party (2+ agents participate) | One-to-one messaging |
| Produces a binding outcome | Informational only |
| Has a defined process with phases | Ad-hoc conversation |
| Suspends individual planning during negotiation | Runs alongside normal operations |

**How consensus works in MAGS:**

1. **Initiation**: An agent identifies a decision that requires team agreement
2. **Draft Plan Phase**: The initiating agent proposes a draft plan
3. **Voting Phase**: Participating agents review the proposal and vote (approve, reject with reasons, abstain)
4. **Resolution**: If sufficient agreement is reached, the proposal becomes binding. If not, the proposal may be revised and re-voted.
5. **Completion**: The consensus outcome is recorded and all agents resume normal operations

**Key properties of consensus:**
- **Planning is suspended** for participating agents during consensus — you can't plan individually while negotiating as a team
- **Timeout protection** — if consensus takes too long, it times out and falls back to a default action
- **Binding outcome** — once consensus is reached, all agents must follow the agreed decision
- **Cooldown period** — after consensus completes, there's a cooldown before another consensus can start on the same topic

---

## When to Use Which

| Situation | Use Communication | Use Consensus |
|-----------|------------------|---------------|
| Sharing data or observations | ✅ | ❌ |
| Reporting analysis results | ✅ | ❌ |
| Proposing a routine setpoint change | ✅ (proposal → approval chain) | ❌ |
| Near-limit operation (predicted impurities 1.8-2.0 mol%) | ❌ | ✅ (Decision-Maker + Guardian must formally agree) |
| Simultaneous changes to multiple controllers | ❌ | ✅ (team must agree on sequencing) |
| Resolving conflicting recommendations | ❌ | ✅ (formal resolution needed) |
| Escalating an alarm | ✅ (immediate notification) | ❌ |

**Rule of thumb**: If the outcome needs to be **binding and agreed upon by multiple agents**, use consensus. If you're just **sharing information or making a routine decision**, use communication.

---

## How They Interact

In practice, communication and consensus work together:

```
Normal Operation (Communication):
Monitor ──message──→ Analysts ──message──→ Decision-Maker ──message──→ Guardian ──message──→ Executor

Near-Limit Operation (Consensus triggered):
Decision-Maker: "I want to propose a change that would put impurity at 1.85 mol%"
    │
    ▼
Consensus Process Initiated
    │
    ├── Decision-Maker proposes: "Set TC3106 to 82°C"
    ├── Guardian reviews: "Predicted impurity 1.85 mol% — within limits but tight"
    ├── Guardian votes: "Approve with condition — monitor closely for 2 cycles"
    ├── Decision-Maker accepts condition
    │
    ▼
Consensus Reached → Binding outcome
    │
    ▼
Normal Communication Resumes
Guardian ──message──→ Executor: "Approved: TC3106 to 82°C with close monitoring"
```

---

## Common Mistakes

### Mistake 1: Using Consensus for Everything

❌ "Every decision should go through consensus"

Consensus is heavyweight — it suspends planning, involves voting, and takes time. Routine decisions (Monitor sharing data, Analyst providing assessment) should use simple communication. Reserve consensus for decisions that genuinely require multi-agent agreement.

### Mistake 2: Using Communication for Critical Decisions

❌ "The Decision-Maker just sends a message to the Guardian for near-limit operations"

When operating near safety limits, a simple message isn't enough. The Guardian might be busy processing something else and not see the message immediately. Consensus ensures both agents actively participate in the decision and formally agree before proceeding.

### Mistake 3: Thinking Consensus Means Unanimous Agreement

❌ "All agents must agree for consensus to pass"

Consensus doesn't require unanimity. The consensus configuration defines the voting rules — it might require a simple majority, a supermajority, or specific agents to agree (e.g., the Guardian must approve). The rules are configurable per team.

### Mistake 4: Forgetting That Consensus Suspends Planning

❌ "Agents can plan and participate in consensus at the same time"

When an agent enters a consensus process, its individual planning cycle is suspended. This prevents conflicts between individual plans and team-level decisions. Planning resumes after consensus completes.

---

## Summary Table

| Aspect | Communication | Consensus |
|--------|--------------|-----------|
| **What** | Information exchange | Formal agreement process |
| **Participants** | Usually 2 agents | 2+ agents |
| **Binding?** | No — informational | Yes — outcome must be followed |
| **Planning impact** | None — runs alongside | Suspends individual planning |
| **Frequency** | Continuous (every cycle) | Rare (only when needed) |
| **Duration** | Milliseconds (async message) | Seconds to minutes (negotiation) |
| **Timeout** | No (fire and forget) | Yes (falls back to default) |
| **Analogy** | Sending an email | Calling a formal meeting |
