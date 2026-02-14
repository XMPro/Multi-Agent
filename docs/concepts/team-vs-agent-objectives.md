# MAGS: Team Objectives vs Agent Objectives

## The One-Sentence Version

The **team objective** is the shared goal. **Agent objectives** are individual motivations that create productive tension — agents don't all optimise for the same thing, and that's by design.

---

## The Analogy: A Football Team

A football team has one **team objective**: win the match.

But each player has a different **individual objective** aligned with their role:

| Player | Individual Objective | How It Serves the Team |
|--------|---------------------|----------------------|
| Striker | Maximise goals scored | Goals win matches |
| Goalkeeper | Minimise goals conceded | Not losing is half of winning |
| Midfielder | Maximise possession and passing accuracy | Control enables both attack and defence |
| Defender | Minimise opponent chances | Protects the goalkeeper |

The striker and goalkeeper have **opposing tendencies** — the striker wants to push forward (risk), the goalkeeper wants everyone to stay back (safety). This tension is **healthy** — it creates a balanced team. If everyone optimised for the same thing (e.g., all attack), the team would be dysfunctional.

**The coach doesn't tell every player to "win the match."** That's too vague. Instead, each player has a specific objective that contributes to the team goal in their own way.

---

## How It Works in MAGS

### Team Objective: The Shared Goal

The team objective defines **what the team as a whole is trying to achieve**. It's typically a dual objective:

**Business Objective** (Controlling):
- Drives autonomous decisions during normal operations
- Example: "Maximise profit per hour"

**Technical Objective** (Monitoring):
- Tracked continuously with alert thresholds
- Triggers mode switching if performance degrades
- Example: "Maintain column health and constraint compliance"

### Agent Objectives: Individual Motivations

Each agent has its own objective function that reflects **its specific role** in the team:

| Agent Role | Agent Objective | Alignment to Team |
|-----------|----------------|-------------------|
| **Process Monitor** | Data completeness and change detection (KPI-based) | Enables both objectives — without data, nothing works |
| **Separation Analyst** | Separation quality (weighted sum of impurity utilities) | Informs the business objective — provides engineering context |
| **Economic Analyst** | Profit per hour (mirrors business objective) | Directly mirrors the team business objective |
| **Decision-Maker** | Profit per hour (inherits team business objective) | Executes the team business objective |
| **Guardian** | Constraint compliance (MinMax of safety utilities) | Executes the team technical objective |
| **Executor** | Execution reliability (KPI-based) | Enables the business objective — without execution, decisions have no effect |

### The Deliberate Tension

Notice that the **Decision-Maker** and the **Guardian** have fundamentally different objectives:

```
Decision-Maker                    Guardian
──────────────                    ────────
Objective: Maximise profit        Objective: Maximise constraint margin
Tendency: Push closer to limits   Tendency: Stay far from limits
           (more profit)                     (more safety)

         ←── TENSION ──→

Resolved by:
- Guardian has veto authority
- Mode switching mechanism
- Hard constraint enforcement
```

This tension is **the whole point**. If the Decision-Maker and Guardian had the same objective, there would be no independent safety check. The Guardian would agree with every profit-maximising proposal, even ones that push dangerously close to limits.

By giving the Guardian a different objective (constraint compliance, not profit), you create a structural check: the Guardian resists proposals that sacrifice safety for profit, and the Decision-Maker must find solutions that satisfy both.

---

## Why Not Give Everyone the Team Objective?

### The Problem with Shared Objectives

If every agent optimised for "maximise profit per hour":

- The **Monitor** would only report data relevant to profit, potentially ignoring safety signals
- The **Separation Analyst** would frame every assessment in terms of profit impact, losing engineering nuance
- The **Guardian** would approve risky proposals because they increase profit
- There would be **no independent safety check** — everyone is incentivised to push limits

### The Power of Diverse Objectives

With role-specific objectives:

- The **Monitor** reports ALL data comprehensively (its objective is completeness, not profit)
- The **Separation Analyst** focuses on separation quality (its objective is engineering performance)
- The **Guardian** focuses on constraint compliance (its objective is safety, independent of profit)
- The **Decision-Maker** synthesises all inputs and optimises for profit — but subject to the Guardian's independent validation

This creates a system of **checks and balances**, similar to how a company has a CFO (profit), a safety officer (compliance), and a CEO (balance both).

---

## The Dual Objective and Mode Switching

The team's dual objective creates a **mode switching** mechanism:

### Normal Mode: Business-Controlled

```
Business Objective (Controlling) ──→ Drives all decisions
Technical Objective (Monitoring) ──→ Tracked in background
```

The team optimises for profit. The technical objective is monitored but doesn't drive decisions. If technical performance is good (all constraints comfortable), the team focuses on economics.

### Emergency Mode: Technical-Controlled

```
Business Objective (Monitoring) ──→ Tracked but doesn't drive decisions
Technical Objective (Controlling) ──→ Drives all decisions
```

If the technical objective drops below a critical threshold (e.g., a constraint is approaching violation), the team switches to technical mode. Now all decisions prioritise restoring safety margins. Profit is monitored but doesn't drive decisions.

**Mode switching triggers:**
- Technical objective drops below critical threshold
- Safety alarm activates
- Guardian vetoes two consecutive proposals
- Analyser failure (no reliable data)

**Mode switching back:**
- Technical objective recovers above normal threshold for sustained period
- No active alarms
- All analysers confirmed operational
- Guardian confirms adequate margins

---

## Common Mistakes

### Mistake 1: Same Objective for All Agents

❌ "Every agent should optimise for the team objective"

This eliminates the checks and balances. The Guardian must have a different objective from the Decision-Maker to provide independent validation.

### Mistake 2: Agent Objectives That Conflict with the Team

❌ "The Monitor's objective is to minimise its own LLM costs"

Agent objectives should be **aligned with** the team objective, even if they're not identical. A Monitor that minimises costs might skip data collection, undermining the entire team.

### Mistake 3: No Tension Between Agents

❌ "All agents should agree on every decision"

Productive tension is a feature, not a bug. If the Decision-Maker and Guardian always agree, one of them is redundant. The value of the Guardian comes from its willingness to veto proposals that the Decision-Maker favours.

### Mistake 4: Forgetting the Monitoring Objective

❌ "We only need one objective — profit"

Without a monitoring objective, there's no early warning system. The technical objective provides continuous health monitoring and triggers mode switching before constraints are violated.

---

## Summary

| Aspect | Team Objective | Agent Objective |
|--------|---------------|----------------|
| **Scope** | The whole team | One specific agent |
| **Purpose** | Define what the team achieves | Define what motivates this agent |
| **Count** | 1-2 per team (business + technical) | 1 per agent |
| **Identical across agents?** | N/A | **No** — deliberately different per role |
| **Creates tension?** | Between business and technical | Between agents (by design) |
| **Example** | "Maximise profit while maintaining safety" | Guardian: "Maximise constraint margin" |
