# MAGS: Tools, Actions, and Data Streams

## The One-Sentence Version

A **tool** is a capability the agent has. An **action** is a step in a plan that uses a tool. A **data stream** is information flowing to the agent from the outside world.

---

## The Analogy: A Chef in a Kitchen

**Tools** are the equipment in the kitchen:
- A knife (can cut things)
- An oven (can heat things)
- A thermometer (can measure temperature)
- A phone (can call suppliers)

**Actions** are the steps in a recipe:
- "Dice the onions" (uses the knife tool)
- "Preheat oven to 180°C" (uses the oven tool)
- "Check internal temperature" (uses the thermometer tool)
- "Order more flour" (uses the phone tool)

**Data streams** are information arriving at the kitchen:
- The timer beeping (the oven is done)
- A delivery arriving (ingredients from the supplier)
- A customer order coming in (new demand)

The chef doesn't "use" the timer beeping — it happens TO the chef. The chef USES the knife to dice onions. And "dice the onions" is a step in the recipe, not the knife itself.

---

## The Three Concepts in Detail

### Tools: What the Agent CAN Do

A tool is a **reusable capability** that an agent can invoke. It's the mechanism, not the purpose.

| What It Is | What It Isn't |
|-----------|--------------|
| A capability (read data, write setpoint, query knowledge) | A step in a plan |
| Reusable across many different actions | Single-use |
| Defined once, used many times | Created per plan |

**Types of tools in MAGS:**

| Tool Type | Direction | Example |
|-----------|-----------|---------|
| **Streaming** (receive) | Data flows TO the agent | Listen to sensor readings |
| **Request** (send/receive) | Agent sends request, gets response | Query a database, write a setpoint |

**Tool properties:**
- Name and description
- Mode (streaming or request)
- Addresses (where to send/receive)
- Expected data structure
- Timeout and window settings

**Key insight**: A tool is like a function in programming — it has inputs, outputs, and a defined behaviour. The agent calls it when needed.

### Actions: What the Agent DOES in a Plan

An action is a **specific step in a plan** that may use one or more tools to accomplish its purpose.

| What It Is | What It Isn't |
|-----------|--------------|
| A step in a plan with a specific goal | A tool (the mechanism) |
| Created as part of planning | Defined in advance like a tool |
| Has a trigger, a purpose, and constraints | Just a capability |

**The relationship:**
```
Plan: "Respond to feed composition change"
  │
  ├── Action 1: "Read current process state"
  │   └── Uses tool: DCS_Tag_Stream (streaming mode)
  │
  ├── Action 2: "Analyse separation performance"
  │   └── Uses tool: RAG_Query (to retrieve process knowledge)
  │
  ├── Action 3: "Propose setpoint change"
  │   └── Uses tool: Agent_Message_Send (to send proposal to Guardian)
  │
  └── Action 4: "Write approved setpoint"
      └── Uses tool: DCS_SP_Write (to write to controller)
```

**Action properties:**
- Which agent performs it
- What triggers it
- How often it occurs
- What constraints apply
- Whether it needs human approval

**Key insight**: Actions are the "what" and "why." Tools are the "how." The same tool (DCS_SP_Write) might be used in many different actions (write reflux setpoint, write temperature setpoint, revert to safe setpoint).

### Data Streams: What Flows TO the Agent

A data stream is **continuous information arriving from external systems** — the agent doesn't request it, it just arrives.

| What It Is | What It Isn't |
|-----------|--------------|
| Information pushed to the agent | Something the agent actively requests |
| Continuous or event-driven | A one-time query |
| From external systems (sensors, DCS, models) | From other agents (that's communication) |

**Examples:**
- OPC-UA sensor readings arriving every 10 seconds
- GC analyser results arriving every 5 minutes
- Alarm events arriving when triggered
- Price updates arriving when entered

**Data streams vs tools:**
A data stream often uses a tool in streaming mode to receive data. But the data stream is the *flow of information*, while the tool is the *mechanism for receiving it*.

```
Data Stream: "DCS process measurements flowing at 10-second intervals"
    │
    └── Received via Tool: DCS_Tag_Stream (configured in streaming mode)
            │
            └── Agent processes the data in its observation cycle
```

---

## How They Interact

```
EXTERNAL WORLD                    AGENT                         PLAN
──────────────                    ─────                         ────

Sensors ──────→ Data Stream ──→ Tool (streaming) ──→ Observation
                                                         │
DCS ←─────────────────────────── Tool (request) ←── Action: "Write SP"
                                                         │
Knowledge Base ←─────────────── Tool (request) ←── Action: "Query RAG"
                                                         │
Other Agents ←───────────────── Tool (send) ←────── Action: "Send proposal"
```

**Data flows IN** via data streams (passive — the agent receives).
**Actions flow OUT** via tools (active — the agent does something).
**Tools are the bridge** between the agent and the external world in both directions.

---

## Common Mistakes

### Mistake 1: Defining Actions as Tools

❌ "Tool: Adjust Reflux Setpoint"

"Adjust Reflux Setpoint" is an action (a step in a plan), not a tool. The tool is "DCS_SP_Write" — a generic capability to write a setpoint to any controller. The action specifies WHICH controller, WHAT value, and WHY.

### Mistake 2: Confusing Data Streams with Tool Requests

❌ "The agent requests sensor data every 10 seconds"

If data arrives on a schedule from the DCS, that's a data stream (streaming mode). The agent doesn't request it — it listens. A tool request is when the agent actively asks for something specific (e.g., "give me the last 4 hours of temperature history").

### Mistake 3: One Tool Per Action

❌ "We need a tool for reading temperature, a tool for reading pressure, a tool for reading level..."

Tools should be **generic capabilities**. One "DCS_Tag_Read" tool can read any DCS tag. The action specifies which tag to read. Don't create a separate tool for every data point.

### Mistake 4: Forgetting That Data Streams Are Passive

❌ "The Monitor agent's action is to collect data"

Data collection via streaming is passive — the data arrives whether the agent is ready or not (it queues). The Monitor's action is to PROCESS the accumulated data, detect changes, and raise flags. The data stream handles the collection.

---

## Summary Table

| Aspect | Tool | Action | Data Stream |
|--------|------|--------|-------------|
| **What** | A capability | A plan step | A flow of information |
| **Direction** | Both (send and receive) | Outward (agent does something) | Inward (data arrives) |
| **Created** | Once (configuration) | Per plan (dynamic) | Once (configuration) |
| **Reusable** | Yes — used by many actions | No — specific to one plan step | Yes — feeds many observations |
| **Example** | DCS_SP_Write | "Write TC3106 to 81°C" | OPC-UA sensor readings |
| **Analogy** | Kitchen knife | "Dice the onions" | Delivery truck arriving |
