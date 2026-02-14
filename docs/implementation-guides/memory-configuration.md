# Recommended Practice: Memory Configuration

*Back to [Implementation Guides](README.md) → Section 7.2-7.3*

---

## The Principle

Memory configuration determines **how much the agent remembers, what it considers important, and when it synthesises insights**. Get it right and the agent learns from experience. Get it wrong and it either drowns in noise or forgets critical context.

---

## Key Configuration Parameters

### 1. Reflection Significance Threshold

Controls when accumulated observations trigger a reflection (higher-order synthesis).

| Threshold | Effect | Use When |
|-----------|--------|----------|
| **0.4-0.5** | Reflects frequently — many reflections, some low quality | Fast-changing environments where every pattern matters |
| **0.6-0.7** | Balanced — reflects when there's meaningful accumulated significance | Most operational use cases (recommended starting point) |
| **0.8-0.9** | Reflects rarely — only on highly significant accumulated observations | Stable environments where only major events warrant reflection |

**Tuning guidance**:
- If the agent produces too many shallow reflections → increase threshold
- If the agent misses important patterns → decrease threshold
- Start at **0.6-0.7** and adjust based on reflection quality

### 2. Memory Retention Period

How far back the agent can recall. This must match the decision cycle and the process dynamics.

| Decision Frequency | Minimum Memory Retention | Why |
|-------------------|------------------------|-----|
| Every 15 minutes | 2-4 hours | Need to see trends across multiple cycles |
| Every hour | 8-24 hours | Need to see daily patterns |
| Every day | 7-30 days | Need to see weekly/monthly patterns |
| Per event | Depends on event frequency | Need enough history to recognise patterns |

**Rule of thumb**: Memory retention should be at least **10× the decision cycle interval**. If the agent decides every 15 minutes, it needs at least 150 minutes (2.5 hours) of memory to see meaningful trends.

### 3. Memory Type Weights

Different memory types have different significance weights when retrieved:

| Memory Type | Default Weight | Rationale |
|-------------|---------------|-----------|
| **Reflection** | 0.8-1.0 | Synthesised insights are the most valuable — they represent learning |
| **Observation** | 0.5-0.7 | Raw perceptions are important but less processed |
| **Conversation Summary** | 0.4-0.6 | Conversation context is useful but typically less actionable |
| **Synthetic** | 0.6-0.8 | Pre-loaded expert knowledge — valuable but not from direct experience |

**Tuning guidance**:
- If the agent over-relies on past reflections and ignores new observations → decrease reflection weight
- If the agent doesn't learn from experience (keeps making the same mistakes) → increase reflection weight

### 4. Similarity Thresholds

Controls how relevant a memory must be to be retrieved for the current context.

| Threshold Type | Default | Effect |
|---------------|---------|--------|
| **Observation similarity** | 0.75 | Higher threshold — only retrieve highly relevant observations |
| **Conversation similarity** | 0.65 | Lower threshold — broader context retrieval for conversations |

**Tuning guidance**:
- If the agent retrieves too many irrelevant memories → increase thresholds
- If the agent misses relevant context → decrease thresholds
- Observation threshold should be higher than conversation threshold (observations need precision; conversations need breadth)

---

## Memory Configuration by Agent Role

| Role | Retention | Reflection Threshold | Key Memory Focus |
|------|-----------|---------------------|-----------------|
| **Monitor** | Short (1-4 hours rolling) | 0.7 (high — only reflect on significant patterns) | Recent readings, change history, alarm history |
| **Analyst** | Medium (4-24 hours) | 0.6 (balanced) | Assessment history, trend patterns, prediction accuracy |
| **Decision-Maker** | Long (days to weeks) | 0.6 (balanced) | Decision history, outcome tracking, strategy effectiveness |
| **Guardian** | Long (days to weeks) | 0.5 (lower — reflect on any safety-relevant pattern) | Veto history, constraint proximity trends, near-miss patterns |
| **Executor** | Short (hours) | 0.8 (high — only reflect on execution anomalies) | Execution records, controller response patterns |

---

## The Memory Retrieval Pipeline

When an agent needs context for a decision, memories are retrieved through this pipeline:

```
1. Generate query vector from current context
2. Search vector database for similar memories
3. Filter by memory type and similarity threshold
4. Score each memory:
   Score = (similarity × sim_weight) +
           (importance × imp_weight × temporal_decay) +
           (surprise × surprise_weight × temporal_decay) +
           (type_weight)
5. Rank by combined score
6. Return top N memories (configured per agent)
7. Enrich with full content from TimeSeries database
```

**Key insight**: Memory retrieval is **semantic** (by meaning), not **chronological** (by time). A highly relevant memory from 2 hours ago may rank higher than an irrelevant memory from 5 minutes ago. Temporal decay reduces the score of older memories, but relevance can overcome recency.

---

## Common Configuration Mistakes

| Mistake | Symptom | Fix |
|---------|---------|-----|
| Retention too short | Agent "forgets" important context between cycles | Increase retention to 10× decision interval |
| Retention too long | Agent retrieves outdated, irrelevant memories | Decrease retention or increase temporal decay |
| Threshold too low | Too many shallow reflections cluttering memory | Increase reflection significance threshold |
| Threshold too high | Agent never reflects — doesn't learn from patterns | Decrease reflection significance threshold |
| Equal type weights | Agent treats raw observations same as synthesised insights | Weight reflections higher than observations |
| Same config for all agents | Monitor drowns in reflections; Guardian misses patterns | Configure per role (see table above) |

---

## Checklist

- [ ] Reflection significance threshold set (start at 0.6-0.7)
- [ ] Memory retention period matches decision cycle (≥ 10× interval)
- [ ] Memory type weights configured (reflections > observations > conversations)
- [ ] Similarity thresholds set (observations higher than conversations)
- [ ] Configuration varies by agent role (not one-size-fits-all)
- [ ] Tested with representative scenarios — agent recalls relevant context
- [ ] No excessive reflection generation (check reflection frequency)
- [ ] No missed patterns (check if important events lead to reflections)
