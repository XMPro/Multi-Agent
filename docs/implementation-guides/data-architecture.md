# Recommended Practice: Data Architecture Patterns

*Back to [Implementation Guides](README.md) → Section 6.3-6.4*

---

## The Principle

Design a clear data flow architecture where each agent knows exactly where its data comes from. Use a **Monitor as gateway** pattern for consistency, but maintain **independent access for safety-critical roles**.

---

## The Two Patterns

### Pattern 1: Monitor as Data Gateway

Most agents receive data through the Monitor agent's state snapshots rather than reading directly from external systems.

```
External Systems (DCS, OPC-UA, Analysers)
        │
        ▼
   Monitor Agent (primary data gateway)
        │
        ├──→ State Snapshot → Analyst A
        ├──→ State Snapshot → Analyst B
        └──→ State Snapshot → Decision-Maker
```

**Benefits**:
- Single, consistent data view across the team — all agents see the same snapshot
- Prevents multiple agents from independently loading external interfaces
- Monitor handles data quality checks, timestamping, and change detection
- Reduces external system load (one reader, not six)

**When to use**: For all agents that consume data for analysis and decision-making.

### Pattern 2: Independent Access for Safety-Critical Roles

Safety-critical agents (Guardian, Executor) retain their own direct access to external systems.

```
External Systems (DCS, OPC-UA, Analysers)
        │
        ├──→ Monitor Agent (gateway for team)
        │
        ├──→ Guardian Agent (independent validation reads)
        │
        └──→ Executor Agent (pre-write verification reads)
```

**Benefits**:
- Guardian can independently verify data without trusting the Monitor's snapshot
- Executor can confirm controller state immediately before writing
- No single point of failure for safety-critical operations

**When to use**: For agents that validate safety or execute control actions.

---

## Combined Architecture

The recommended architecture combines both patterns:

```
External Systems
    │
    ├─── Monitor (reads ALL data, distributes snapshots)
    │       │
    │       ├──→ Analyst A (receives via Monitor)
    │       ├──→ Analyst B (receives via Monitor)
    │       └──→ Decision-Maker (receives via Monitor)
    │
    ├─── Guardian (independent reads for validation)
    │
    └─── Executor (independent reads for pre-write checks)
```

### Data Access Matrix

| Agent | External Read | External Write | Via Monitor | Independent |
|-------|-------------|---------------|-------------|-------------|
| Monitor | ✅ All tags | ❌ | N/A (IS the gateway) | ✅ |
| Analyst(s) | ❌ | ❌ | ✅ | ❌ |
| Decision-Maker | ❌ | ❌ | ✅ | ❌ |
| Guardian | ✅ (validation) | ❌ | Also ✅ | ✅ |
| Executor | ✅ (pre-write) | ✅ (setpoints) | ❌ | ✅ |

---

## Streaming vs Request Mode

### Streaming Mode (Data Pushed to Agent)

Data arrives continuously without the agent requesting it.

**Use for**:
- Sensor readings at regular intervals
- Alarm events
- Price updates
- Any data that changes frequently and the agent needs to stay current

**Configuration**: Set `mode: "streaming"` with a `window_seconds` that matches the observation cycle.

### Request Mode (Agent Pulls Data)

Agent sends a request and waits for a response.

**Use for**:
- Historical data queries
- On-demand calculations
- Setpoint writes (send command, get confirmation)
- RAG knowledge base queries

**Configuration**: Set `mode: "request"` with a `timeout_seconds` appropriate for the expected response time.

### Decision Guide

```
Does the data change frequently and the agent needs to stay current?
├── Yes → STREAMING (data pushed to agent)
└── No → Does the agent need specific data at specific times?
    ├── Yes → REQUEST (agent pulls on demand)
    └── No → Consider if this data is needed at all
```

---

## Data Flow Design Checklist

- [ ] Monitor agent designated as primary data gateway
- [ ] All analyst and decision-maker agents receive data via Monitor snapshots
- [ ] Guardian has independent read access for validation
- [ ] Executor has independent read access for pre-write verification
- [ ] Executor is the ONLY agent with write access
- [ ] Streaming mode configured for continuous data (sensors, alarms)
- [ ] Request mode configured for on-demand data (history, RAG, writes)
- [ ] Data access matrix documented (who reads what, who writes what)
- [ ] No agent has more access than its role requires
