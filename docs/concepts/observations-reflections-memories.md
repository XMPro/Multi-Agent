# MAGS: Observations, Reflections, and Memories

## The One-Sentence Version

An **observation** is what the agent sees. A **reflection** is what the agent thinks about what it has seen. A **memory** is where both are stored.

---

## The Analogy: A Detective's Notebook

A detective investigating a case works in three layers:

1. **Observations** — Raw facts recorded at the scene:
   - "The window was broken from the outside"
   - "Muddy footprints lead from the garden to the kitchen"
   - "The alarm system was disabled at 2:47 AM"

2. **Reflections** — Insights synthesised from multiple observations:
   - "The intruder entered through the garden, broke the kitchen window, and had already disabled the alarm — this was planned, not opportunistic"
   - "The mud pattern matches the garden soil, confirming the entry path"

3. **The Notebook** — Where everything is stored:
   - Both observations and reflections go in the same notebook
   - Each entry is dated, tagged with importance, and cross-referenced
   - The detective can flip back through the notebook to find relevant past entries

In MAGS, the notebook is the **memory system**. Observations and reflections are both types of memories, stored in the same database, but with different characteristics and different roles in the agent's reasoning.

---

## The Three Concepts in Detail

### Observations: What the Agent Sees

An observation is a **direct perception of the environment** — data that arrives from sensors, data streams, other agents, or user input.

| What It Is | What It Isn't |
|-----------|--------------|
| A factual record of incoming data | An interpretation or conclusion |
| Created when new information arrives | Created on a schedule |
| Raw perception with minimal processing | A synthesised insight |

**How observations are created:**
1. Data arrives via a data stream (e.g., OPC-UA sensor reading)
2. The agent's observation prompt processes the raw data through the LLM
3. The LLM extracts structured information: summary, key points, actionable insights
4. The result is stored as an observation memory

**What's stored with each observation:**
- The processed content (summary, key points)
- Importance score — how significant is this to the agent's goals?
- Surprise score — how unexpected or novel is this?
- Confidence score — how reliable is this information?
- Source information — where did this data come from?
- Timestamp — when was this observed?
- Vector embedding — for semantic similarity search

**Observations are the foundation.** Without observations, the agent has nothing to reason about. They are the raw material that feeds everything else.

### Reflections: What the Agent Thinks

A reflection is a **higher-order insight** synthesised from multiple observations and past reflections. It's the agent's way of learning — connecting dots, identifying patterns, and drawing conclusions.

| What It Is | What It Isn't |
|-----------|--------------|
| A synthesised insight from multiple observations | A single data point |
| Created when accumulated significance exceeds a threshold | Created for every observation |
| The agent's interpretation and reasoning | A raw fact |

**How reflections are triggered:**
1. Each observation contributes to an accumulated significance score
2. When the accumulated significance exceeds a configurable threshold, a reflection is triggered
3. The agent retrieves recent observations, past reflections, and relevant knowledge
4. The LLM synthesises these into new insights
5. The result is stored as a reflection memory

**What's stored with each reflection:**
- The synthesised content (insights, patterns, conclusions)
- Contributing memories — which observations and reflections fed into this
- Importance and surprise scores (typically higher than individual observations)
- Confidence score (stricter standards than observations — reflections must be well-supported)
- Vector embedding — for semantic similarity search

**Reflections are where learning happens.** An agent that only observes is like a camera — it records everything but understands nothing. Reflections are where the agent develops understanding.

### Memories: Where Everything Is Stored

Memory is the **storage and retrieval system** for both observations and reflections. It's not a separate concept — it's the container.

| What It Is | What It Isn't |
|-----------|--------------|
| The database where observations and reflections live | A third type of content |
| A retrieval system with semantic search | A simple log or queue |
| Scored and ranked for relevance | Stored in chronological order only |

**Memory types in MAGS:**
- **Observation memories** — stored from the Observe phase
- **Reflection memories** — stored from the Reflect phase
- **Conversation memories** — summaries of agent conversations (a special case)
- **Synthetic memories** — pre-loaded expert knowledge (not created by the agent)

**How memories are retrieved:**
When an agent needs context for a decision, it queries the memory system:
1. A query vector is generated from the current context
2. The vector database returns semantically similar memories
3. Memories are scored using multiple factors:
   - Vector similarity (how relevant is this memory to the current situation?)
   - Importance (how significant was this memory when created?)
   - Surprise (how novel was this memory?)
   - Temporal decay (how recent is this memory? Recent memories score higher)
   - Memory type weight (reflections typically weighted higher than observations)
4. The top-ranked memories are included in the agent's reasoning context

---

## How They Work Together

```
Data arrives from environment
        │
        ▼
   OBSERVE PHASE
   Agent processes data → creates Observation Memory
        │
        ├─ Significance accumulates across observations
        │
        ▼
   REFLECT PHASE (triggered when significance threshold exceeded)
   Agent synthesises observations → creates Reflection Memory
        │
        ├─ Reflection may trigger planning
        │
        ▼
   PLAN PHASE
   Agent retrieves relevant memories (both observations AND reflections)
   Uses them as context for creating a plan
        │
        ▼
   ACT PHASE
   Agent executes the plan
   Results become new observations → cycle continues
```

### A Concrete Example

**Observation 1** (t=0 min): "Feed C3 composition dropped from 64.8 to 62.1 mol%"
- Importance: 0.7 (significant change)
- Surprise: 0.8 (unexpected shift)

**Observation 2** (t=5 min): "Tray 20 temperature rising from 80.0 to 80.8°C"
- Importance: 0.5 (moderate change)
- Surprise: 0.4 (expected response to feed change)

**Observation 3** (t=10 min): "Top C4+ impurity trending up from 1.65 to 1.72 mol%"
- Importance: 0.6 (quality moving toward limit)
- Surprise: 0.5 (consistent with feed change)

**Accumulated significance exceeds threshold → Reflection triggered**

**Reflection** (t=10 min): "The feed has shifted leaner by ~2.7 mol% C3. The column is responding as expected — tray temperatures rising and top impurity increasing. At the current rate, top impurity will approach 1.9 mol% within 30 minutes if reflux and steam are not adjusted. This is consistent with a well blending change upstream."
- Importance: 0.85 (actionable insight)
- Contributing memories: Observations 1, 2, 3
- Confidence: 0.80 (well-supported by multiple consistent observations)

**This reflection then feeds into the planning phase**, where the agent decides whether to adjust setpoints.

---

## Common Mistakes

### Mistake 1: Treating Every Data Point as an Observation

❌ "Create an observation for every sensor reading"

Observations should be **meaningful perceptions**, not raw data dumps. The observation prompt processes incoming data through the LLM to extract what matters. If a sensor reading hasn't changed significantly, it may not warrant a new observation.

### Mistake 2: Expecting Reflections on Every Observation

❌ "The agent should reflect after every observation"

Reflections are triggered by **accumulated significance**, not by individual observations. If three low-importance observations arrive, they may not trigger a reflection. One high-importance observation might trigger one immediately. The threshold is configurable.

### Mistake 3: Confusing Memory Retrieval with Chronological Recall

❌ "The agent remembers the last 10 things that happened"

Memory retrieval is **semantic**, not chronological. The agent retrieves memories that are most **relevant** to the current situation, weighted by similarity, importance, surprise, and recency. A highly relevant memory from 2 hours ago may rank higher than an irrelevant memory from 5 minutes ago.

### Mistake 4: Thinking Reflections Replace Observations

❌ "Once the agent reflects, it doesn't need the original observations"

Both observations and reflections persist in memory. When the agent retrieves context for a decision, it gets BOTH recent observations (raw facts) and past reflections (synthesised insights). The observations provide ground truth; the reflections provide interpretation.

---

## Summary Table

| Aspect | Observation | Reflection | Memory |
|--------|------------|------------|--------|
| **What** | Raw perception of data | Synthesised insight | Storage container |
| **Created by** | Observe phase (data arrival) | Reflect phase (significance threshold) | Both phases |
| **Frequency** | Per meaningful data event | When accumulated significance is high enough | Continuous |
| **Content** | Facts, readings, events | Patterns, conclusions, predictions | Both types |
| **Importance** | Typically 0.3-0.7 | Typically 0.6-0.9 | Scored per entry |
| **Confidence** | Based on source reliability | Stricter — must be well-supported | Scored per entry |
| **Retrieval** | By semantic similarity + recency | By semantic similarity + importance | Unified search across all types |
| **Analogy** | Detective's scene notes | Detective's case theory | Detective's notebook |
