# Recommended Practice: Data Inventory First

*Back to [Implementation Guides](README.md) → Section 6.2*

---

## The Principle

Before designing agents, **inventory what data is actually available**. Agents can only work with data that exists. Designing a system around data you don't have leads to costly rework at implementation time.

---

## Why Data-First Matters

### The Common Failure Mode

```
1. Design agents with ideal data access (design steps)     ← Assumes unlimited data
2. Define measures and utility functions                    ← Based on assumed data
3. Define constraints linked to measures                    ← Based on assumed data
4. Reach Data & Tools step                                 ← First time data is examined
5. Discover that 30% of assumed data doesn't exist          ← REWORK
6. Redesign agents, measures, constraints                   ← Expensive backtracking
```

### The Data-First Approach

```
1. Inventory available data (Data Inventory step)           ← Know what you have
2. Design agents around available data (design steps)       ← Realistic from the start
3. Define measures linked to actual data sources             ← Verified
4. Define constraints linked to verified measures            ← Grounded
5. Data & Tools step confirms and reconciles                ← Minimal gaps
```

---

## What to Inventory

### 1. Real-Time Data Sources

For each system that provides live data:

| Question | Why It Matters |
|----------|---------------|
| What tags/signals are available? | Defines what agents can observe |
| What are the update rates? | Determines minimum planning cycle interval |
| What protocol? (OPC-UA, MQTT, API) | Determines tool configuration |
| What authentication? | Determines integration complexity |
| Read-only or read-write? | Determines if agents can act, not just observe |

### 2. Analyser and Calculated Data

| Question | Why It Matters |
|----------|---------------|
| What analysers exist? | Quality measures depend on analyser availability |
| What is the update cycle? | Affects how quickly agents can confirm effects |
| Is there deadtime/lag? | Agents must account for measurement delay |
| What virtual/calculated tags exist? | May provide derived measures without new sensors |

### 3. Contextual Data (Documents, Knowledge Bases)

| Question | Why It Matters |
|----------|---------------|
| What engineering documents exist? | Defines RAG collection content |
| What format? (PDF, database, structured) | Determines RAG ingestion approach |
| How current? | Stale documents lead to stale agent knowledge |
| How large? | Affects RAG chunking and retrieval strategy |

### 4. Historical Data

| Question | Why It Matters |
|----------|---------------|
| How much history is available? | Determines trend analysis capability |
| At what resolution? | Affects the granularity of historical queries |
| Where is it stored? | Determines historical query tool configuration |

---

## The Data Gap Analysis

After inventorying available data, compare it against what the agent design needs:

| Desired Data | Needed By | Available? | Gap | Resolution |
|-------------|-----------|-----------|-----|------------|
| Feed C3 composition | Monitor, Analyst | Yes (virtual GC) | None | — |
| Product impurity | Monitor, Guardian | Yes (GC analyser, 5-min cycle) | Deadtime not accounted for | Add deadtime awareness to profiles |
| Propane price | Economic Analyst | Partial (manual input) | Not automated | Accept manual; add staleness detection |
| Equipment vibration | Monitor | No | No vibration sensors | Remove from design or add sensors |

### Resolution Options for Gaps

| Resolution | When to Use |
|-----------|------------|
| **Add the data source** | If feasible and cost-effective |
| **Calculate from existing data** | If the desired value can be derived |
| **Use a proxy measure** | If a related measure provides similar information |
| **Remove the requirement** | If the agent can function without it |
| **Accept the limitation** | If the gap is minor and the agent can work around it |

---

## When to Do the Inventory

### Ideal: Early in the Configuration Wizard (Data Inventory Step)

Complete the data inventory early in the MAGS Configuration Wizard, before defining the business problem. This ensures the entire design is grounded in reality.

### Acceptable: During the Data & Tools Step

If the data inventory wasn't done upfront, the Data & Tools Requirements step of the Configuration Wizard includes a Data Gap Analysis section. This catches gaps before configuration generation but may require backtracking to earlier design steps.

### Too Late: During Implementation

Discovering data gaps during implementation is the most expensive time to find them. Every gap requires design changes that ripple through profiles, measures, constraints, and tools.

---

## Checklist

- [ ] All real-time data sources inventoried (tags, rates, protocols)
- [ ] All analysers inventoried (cycle times, deadtimes, quality)
- [ ] All calculated/virtual tags identified
- [ ] All contextual documents listed (for RAG collections)
- [ ] Historical data availability confirmed
- [ ] Write access identified (which systems can agents write to?)
- [ ] Data gaps identified and resolution planned
- [ ] Simulation vs production data source noted (affects timing)
