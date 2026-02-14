# MAGS: How Agents Handle Incoming Data and Alerts During Processing

## Overview

MAGS agents operate on an **Observe-Reflect-Plan-Act (ORPA)** cycle. Each agent runs its own cycle independently, on a configurable timer. A natural question arises: what happens when new data or alerts arrive while an agent is already in the middle of processing?

This document explains the data flow architecture, queuing behaviour, and how MAGS ensures no information is lost — even when agents are busy.

---

## 1. Data Flow Architecture

### Three Layers of Data Handling

MAGS handles incoming data through three distinct layers:

```
Layer 1: MESSAGE QUEUE (Transport)
    Raw data arrives via MQTT/OPC-UA → buffered in concurrent queues
    ↓
Layer 2: OBSERVATION MEMORIES (Persistence)
    Agent processes queued data → creates observation memories in database
    ↓
Layer 3: PLANNING DECISIONS (Action)
    Agent retrieves recent observations → reasons about them → decides and acts
```

Each layer has its own buffering mechanism, ensuring data flows through the system without loss even when downstream components are busy.

---

## 2. Layer 1: Message Queuing

When data arrives from external systems (sensors, data streams, other agents), it is placed into a **concurrent message queue**. This queue:

- **Never blocks the sender** — data is enqueued immediately regardless of agent state
- **Never drops messages** — the queue grows to accommodate all incoming data
- **Is thread-safe** — multiple data sources can write simultaneously
- **Persists until read** — messages stay in the queue until an agent explicitly dequeues them

When an agent reads from the queue, it receives **all accumulated messages** since the last read. If 6 readings arrived during a 60-second processing window, the agent gets all 6 at once on its next read cycle.

---

## 3. Layer 2: Observation Memories

When an agent (typically a Monitor agent) processes incoming data, it creates **observation memories**. These are:

- **Persisted to the database** using the saga pattern (TimeSeries → Vector → Graph)
- **Scored for significance** — importance, surprise, and confidence are calculated
- **Embedded as vectors** — enabling semantic similarity search
- **Available to all agents** — any agent can retrieve recent observations via memory queries

Observations accumulate in the database. They do not disappear if an agent is busy processing something else. When any agent's next cycle runs, it can retrieve all recent observations as context for its reasoning.

---

## 4. Layer 3: Planning Cycle Lock

Each agent has a **planning cycle lock** that prevents concurrent planning:

- When an agent enters a planning cycle, it sets an `IsInPlanningCycle` flag
- If the timer fires again while the flag is set, the new cycle is **skipped** (not queued)
- When the current cycle completes, the flag is cleared
- The next timer tick starts a fresh cycle that sees all accumulated data

This means:

| Situation | What Happens |
|-----------|-------------|
| New data arrives while agent is idle | Agent processes it on the next timer tick |
| New data arrives while agent is processing | Data queues; agent sees it on the NEXT cycle after current one completes |
| Multiple alerts arrive during one cycle | All alerts queue; next cycle sees the full accumulated picture |
| Agent is in consensus negotiation | Planning cycles are suspended until consensus completes |

---

## 5. How Alerts Are Handled

### Same-Type Alerts (e.g., repeated feed composition changes)

If the same type of alert fires multiple times while an agent is processing:

1. Each alert's data is **queued** at the message layer
2. When the agent's current cycle completes, the next cycle reads **all queued data**
3. The agent sees the **latest state plus the trend** — it doesn't process each alert individually
4. It makes **one decision** based on the current accumulated picture

This is the **"latest state wins"** pattern — the agent always decides on the most current information, not on stale data from when the alert first fired.

### Different-Type Alerts (e.g., feed change + pressure alarm)

If a different type of alert fires while an agent is processing:

1. **If it targets the same agent**: The alert data queues. The next cycle processes both the original context and the new alert together, making a decision that accounts for both.

2. **If it targets a different agent**: MAGS agents run **independently**. A Monitor agent can detect and report a pressure alarm while the Decision-Maker is still processing a feed change. Each agent has its own cycle and its own planning lock.

3. **If it's a critical alarm**: Agent profiles can define **conditional duties** for critical situations (e.g., "IF critical alarm THEN immediately notify all agents and escalate to human"). These escalation paths operate through the messaging system, not through the planning cycle, so they are not blocked by the planning lock.

### Alert Priority and Significance

When the planning adaptation detector evaluates whether to trigger a new planning cycle, it considers:

- **Recent memory significance** — how important are the accumulated observations?
- **Current plan validity** — does the current plan still make sense given new data?
- **Environmental changes** — have conditions changed enough to warrant replanning?
- **Goal achievement status** — is the current plan still progressing toward its goals?

High-significance observations (like critical alarms) will trigger replanning on the next available cycle. Low-significance observations may not trigger replanning at all — the current plan continues.

---

## 6. The "Latest State Wins" Pattern

MAGS uses a fundamentally different pattern from traditional event-driven systems:

### Traditional Event Processing
```
Event 1 → Process → Complete
Event 2 → Process → Complete
Event 3 → Process → Complete
Event 4 → Process → Complete
```
Every event is processed individually, in order.

### MAGS Pattern
```
Reading 1 ─┐
Reading 2 ─┤
Reading 3 ─┼─→ Agent reads ALL → Reasons on LATEST STATE → One decision
Reading 4 ─┤
Reading 5 ─┤
Reading 6 ─┘
```
Data accumulates; the agent processes the full picture at once.

**Why this is the right pattern for operational decision-making:**

An experienced human operator doesn't react to every individual sensor reading. They look at the current state, assess the trend, consider the context, and make one informed decision. MAGS agents do the same thing — they accumulate observations, assess the situation holistically, and act on the latest understanding.

This pattern also naturally handles the "stale alert" problem. If a feed composition alert fires at t=0 and the agent doesn't process it until t=60, the agent doesn't act on the t=0 data — it acts on the t=60 data, which reflects the current reality. The alert served its purpose by triggering the agent to look, but the decision is based on what the agent sees now, not what triggered the look.

---

## 7. Inter-Agent Communication During Processing

When agents communicate (e.g., Monitor sends a state assessment to Analysts), the messages flow through the MQTT message broker:

- Messages are **published to topics** — they don't require the recipient to be listening at that exact moment
- Each agent **subscribes to relevant topics** and receives messages when it processes them
- Messages from other agents are treated as **observations** — they go through the same observe → memory → planning pipeline
- The planning lock on one agent does **not block** other agents from sending or receiving messages

This means the agent chain (Monitor → Analysts → Decision-Maker → Guardian → Executor) is **asynchronous by design**. Each agent processes at its own pace. If the Decision-Maker is slow, the Monitor doesn't stop collecting data — it continues observing and accumulating state.

---

## 8. Consensus and Planning Interaction

When a consensus process is active (multiple agents negotiating agreement):

- Individual planning cycles are **suspended** for participating agents
- The consensus manager handles the negotiation flow
- Once consensus completes, planning cycles resume
- Accumulated observations during the consensus period are available to the next planning cycle

This prevents conflicts between individual agent planning and team-level consensus processes.

---

## 9. Summary

| Question | Answer |
|----------|--------|
| **Is incoming data lost during processing?** | No — concurrent queues buffer all messages; nothing is dropped |
| **Do alerts go into a queue?** | Yes — at both the message layer (raw data) and the memory layer (observations) |
| **Are duplicate alerts suppressed?** | Not explicitly — but the planning lock prevents concurrent processing, and the next cycle sees all accumulated data as one picture |
| **What about different alert types?** | They queue independently; the next cycle processes all accumulated alerts together |
| **What about alerts for different agents?** | Agents run independently — one agent's busy state doesn't block another |
| **What about critical alarms?** | Conditional duties in agent profiles enable immediate escalation paths that bypass the planning cycle |
| **Does the agent act on stale data?** | No — the "latest state wins" pattern means decisions are always based on the most current accumulated state |

---

## 10. Design Implications for Agent Profiles

When designing agent profiles, keep these data flow characteristics in mind:

1. **Planning cycle interval** determines how quickly an agent responds to new data. Shorter intervals mean faster response but more LLM calls.

2. **Conditional duties** for critical situations should use immediate messaging (escalation to humans, alerts to other agents) rather than relying on the planning cycle, which may be locked.

3. **Monitor agents** should be designed to process accumulated data in batches, not individual readings. Their observation logic should assess trends and current state, not react to each data point.

4. **Decision-making agents** should expect that the data they receive may represent an accumulated period, not a single instant. Their reasoning should account for the possibility that conditions have evolved since the triggering event.

5. **Move spacing and timing constraints** should account for the planning cycle duration. If a planning cycle takes 60 seconds and the move spacing is 30 minutes, the effective spacing is 30 minutes of process time plus ~1 minute of agent processing time.
