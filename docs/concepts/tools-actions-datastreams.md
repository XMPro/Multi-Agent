# MAGS: Tools, Actions, and Data Streams

## The One-Sentence Version

A **tool** is how the agent gets information **in**. An **action** is a step in a plan and the only way anything goes **out**. A **data stream** is information flowing to the agent from the outside world, without being asked for.

**Tools bring data in. Actions send everything out.** If you remember one thing from this page, that is it.

---

## The Analogy: A Chef in a Kitchen

**Tools** are how the chef finds things out:
- A thermometer (what temperature is the meat?)
- A scale (how much flour is left?)
- Phoning the supplier to **ask** whether cream is in stock

**Actions** are the steps in the recipe, the things that change something:
- "Dice the onions"
- "Set the oven to 180°C"
- "Place an order for 20kg of flour"

**Data streams** are information arriving unasked:
- The timer beeping (the oven is done)
- A delivery arriving (ingredients from the supplier)
- A customer order coming in (new demand)

Three things to notice, and the middle one is where people go wrong:

- The chef doesn't "use" the timer beeping. It happens TO the chef.
- **A thermometer tells you the temperature. It does not change it.** Turning the oven up is an action, and there is no "oven tool" underneath it. Reaching for the supplier's phone number is a tool; placing the order is an action.
- "Dice the onions" is a step in the recipe, not a piece of equipment.

**Tools tell the chef what is going on. Actions change what is going on.**

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

| Tool Type | How data arrives | Example |
|-----------|------------------|---------|
| **Streaming** (receive) | **Pushed.** The agent listens; data arrives on a schedule or a trigger | Listen to sensor readings |
| **Request** (send/receive) | **Pulled.** The agent asks a question and gets data back | Query a database, retrieve the last 4 hours of history |
| **Built-in internal** (compute) | Neither. Invoked in-process, result returned immediately | NCalc mathematical expression evaluation |

> ⚠️ **Every tool brings data IN. A tool never writes to an external system.**
>
> **"Send/receive" means send a *request*, receive a *response*.** It does not mean the agent sends
> data out. A request tool is a read: the send is the question, the receive is the answer. That name
> is the most common source of confusion on this page, and misreading it is how a write path ends up
> filed as a tool.
>
> **Anything that changes the state of an external system is an action**, never a tool: writing a
> setpoint, setting a flag, triggering a sequence. If it leaves a mark outside the agent, it is an
> action.
>
> This matters beyond naming. **A write filed as a tool sits outside the constraints that gate
> writes.** It is not mislabelled, it is unguarded.

> **Built-in internal tools** are hardcoded into the MAGS agent framework and require no database entry, external API, or agent profile configuration. The [NCalc Tool](../integration-execution/ncalc-tool.md) is the primary example: it accepts a natural language query, translates it to a deterministic mathematical expression, evaluates it, and returns both the expression and the result. This guarantees accurate arithmetic without relying on the LLM to perform calculations.

**Tool properties:**
- Name and description
- Mode (streaming or request)
- Addresses (where to listen, or where to send the request)
- Expected data structure
- Timeout and window settings

**Key insight**: A tool is like a function in programming — it has inputs, outputs, and a defined behaviour. The agent calls it when needed.

### Actions: What the Agent DOES in a Plan

An action is a **specific step in a plan**. It is the only thing that changes the state of an external system, and it is dispatched to an XMPro Data Stream, which performs the change.

| What It Is | What It Isn't |
|-----------|--------------|
| A step in a plan with a specific goal | A tool (which only brings data in) |
| Created as part of planning | Defined in advance like a tool |
| Has a trigger, a purpose, and constraints | Just a capability |
| **The only way anything leaves the agent** | A way of reading data |

**The relationship:**
```
Plan: "Respond to feed composition change"
  │
  ├── Reads process state
  │   └── Via tool: DCS_Tag_Stream (streaming mode, data arrives)
  │
  ├── Reads process knowledge
  │   └── Via tool: RAG_Query (request mode, agent asks and gets an answer)
  │
  ├── Action 1: "Propose setpoint change to the Guardian"
  │   └── Goes OUT as an action
  │
  └── Action 2: "Write approved setpoint TC3106 to 81°C"
      └── Goes OUT as an action, dispatched to a Data Stream that writes to the controller
```

Note the asymmetry: **reading is done through tools, and every outgoing step is an action.** There is no write tool sitting under Action 2.

**Action properties:**
- Which agent performs it
- What triggers it
- How often it occurs
- What constraints apply
- Whether it needs human approval

**Key insight**: Actions are the "what" and "why." Tools are the "how" for **getting information in**. An action that writes does not reach for a write tool, because none exists: it is dispatched to a Data Stream, and that Data Stream performs the write.

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

                    IN, always through a tool

Sensors ──────→ Data Stream ──→ Tool (streaming) ──→ Observation
                                                         │
Historian ────────────────────→ Tool (request)  ──→ Observation
                                                         │
Knowledge Base ───────────────→ Tool (request)  ──→ Observation
                                                         │
                    OUT, always as an action              │
                                                         │
DCS ←───────────── Data Stream ←──────────────────── Action: "Write SP"
                                                         │
Other Agents ←──────────────────────────────────── Action: "Send proposal"
```

**Data flows IN through tools** (streaming pushes, request pulls). The agent reads.
**Everything flows OUT as an action**, dispatched to a Data Stream that performs it.
**Tools are the inbound half only.** There is no outbound tool.

---

## Common Mistakes

### Mistake 1: Filing a Write as a Tool

❌ "Tool: Adjust Reflux Setpoint"
❌ "Tool: DCS_SP_Write"

**Both are wrong, and the second is the more dangerous** because it looks like a properly generic capability. **There is no write tool.** Tools bring data in; anything going out is an action.

✅ "Action: Write TC3106 to 81°C", dispatched to a Data Stream that performs the write. The action specifies WHICH controller, WHAT value, and WHY, and it carries the constraints that gate it.

**Why this one matters more than the others.** The constraints that govern what an agent may change look at actions. A write filed as a tool is not merely in the wrong table: it sits outside the gates, so an operating-mode or authority check never sees it.

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
| **What** | A capability for getting data in | A plan step that changes something | A flow of information |
| **Direction** | **Inward only.** Pushed (streaming) or pulled (request) | **Outward.** The only way anything leaves the agent | Inward (data arrives) |
| **Created** | Once (configuration) | Per plan (dynamic) | Once (configuration) |
| **Reusable** | Yes — many observations use it | No — specific to one plan step | Yes — feeds many observations |
| **Example** | DCS_Tag_Read, RAG_Query | "Write TC3106 to 81°C" | OPC-UA sensor readings |
| **Analogy** | Thermometer, or asking the supplier a question | "Turn the oven to 180°C" | Delivery truck arriving |

> **The one line to remember:** tools bring data **in**, actions send everything **out**. "Send/receive" on a request tool means send a *question*, receive an *answer*.
