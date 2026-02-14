# MAGS: The ORPA Cycle vs The Planning Cycle

## The One-Sentence Version

The **ORPA cycle** is the agent's overall way of thinking (Observe → Reflect → Plan → Act). The **planning cycle** is the timer that periodically checks whether the agent needs a new plan — it's just one part of ORPA.

---

## The Analogy: Breathing vs Deciding to Run

**The ORPA cycle is like breathing** — it's the continuous, fundamental rhythm of the agent's existence:
- **Observe**: Inhale — take in information from the environment
- **Reflect**: Process — your brain interprets what you sensed
- **Plan**: Decide — determine what to do next
- **Act**: Exhale — do something in the world

This cycle runs continuously. It IS the agent.

**The planning cycle is like deciding whether to run** — it's a specific, periodic check:
- Every few minutes, you ask: "Should I change what I'm doing?"
- Most of the time, the answer is "No, keep going"
- Occasionally, the answer is "Yes, I need a new plan"
- When you do need a new plan, you go through the full planning process

You breathe continuously. You only decide to run occasionally. Breathing doesn't stop while you're deciding whether to run.

---

## The Two Concepts in Detail

### The ORPA Cycle: The Agent's Way of Being

ORPA (Observe-Reflect-Plan-Act) is the **cognitive architecture** of a MAGS agent. It describes the four fundamental activities that every agent performs:

```
    ┌──────────┐
    │ OBSERVE  │ ← Perceive the environment (data streams, messages, events)
    └────┬─────┘
         │
         ▼
    ┌──────────┐
    │ REFLECT  │ ← Synthesise observations into insights (when significance threshold met)
    └────┬─────┘
         │
         ▼
    ┌──────────┐
    │   PLAN   │ ← Create or adapt plans (when adaptation detector triggers)
    └────┬─────┘
         │
         ▼
    ┌──────────┐
    │   ACT    │ ← Execute plan actions using tools
    └────┬─────┘
         │
         └──────→ Results become new observations → cycle continues
```

**Key properties of the ORPA cycle:**
- It's **continuous** — the agent is always in some phase of ORPA
- It's **not strictly sequential** — observations can happen while a plan is executing
- Different phases run at **different frequencies** — observation is fast, reflection is triggered, planning is periodic, action is ongoing
- It's the **conceptual framework**, not a literal loop in code

### The Planning Cycle: The Timer That Checks for Replanning

The planning cycle is a **specific, timer-driven mechanism** that periodically asks: "Does this agent need a new plan?"

```
Timer fires (every N minutes)
    │
    ▼
Is the agent already in a planning cycle?
    ├── Yes → Skip (don't interrupt current planning)
    │
    └── No → Run the Plan Adaptation Detector
              │
              ├── No adaptation needed → Do nothing (current plan is fine)
              │
              └── Adaptation needed → Start full planning process
                    │
                    ├── Retrieve context (observations, reflections, objectives, constraints)
                    ├── Generate plan via LLM
                    ├── Validate against constraints
                    └── Store and begin execution
```

**Key properties of the planning cycle:**
- It's **timer-driven** — fires at a configurable interval (e.g., every 15 minutes)
- It's **gated** — won't start if the agent is already planning or in consensus
- It's **conditional** — most ticks result in "no planning needed"
- It's **one part of ORPA** — specifically the "Plan" phase
- It has a **lock** — prevents concurrent planning cycles

---

## How They Relate

The ORPA cycle is the **whole picture**. The planning cycle is **one mechanism within it**.

```
ORPA CYCLE (continuous)
│
├── OBSERVE (continuous)
│   ├── Data streams deliver readings → queued
│   ├── Agent processes accumulated data → creates observations
│   └── Observations stored as memories
│
├── REFLECT (triggered)
│   ├── Accumulated observation significance exceeds threshold
│   ├── Agent synthesises observations into reflections
│   └── Reflections stored as memories
│
├── PLAN (periodic) ◄──── THIS IS THE PLANNING CYCLE
│   ├── Timer fires every N minutes
│   ├── Adaptation detector checks if replanning needed
│   ├── If yes: full planning process (LLM, constraints, etc.)
│   └── If no: skip (current plan continues)
│
└── ACT (ongoing)
    ├── Execute tasks from current plan
    ├── Invoke tools for each action
    └── Results become new observations → feeds back to OBSERVE
```

The planning cycle is the **heartbeat** of the Plan phase. But the other three phases (Observe, Reflect, Act) have their own rhythms:

| Phase | Rhythm | Trigger |
|-------|--------|---------|
| **Observe** | Continuous | Data arrives from streams |
| **Reflect** | Event-driven | Accumulated significance exceeds threshold |
| **Plan** | Timer-driven | Planning cycle interval (e.g., every 15 min) |
| **Act** | Ongoing | Plan has pending tasks |

---

## What Runs When

Here's a timeline showing how the phases interleave:

```
Time →
─────────────────────────────────────────────────────────────

OBSERVE:  ●──●──●──●──●──●──●──●──●──●──●──●──●──●──●──●──●
          (data arrives continuously, processed into observations)

REFLECT:  ─────────────●────────────────────●────────────────
          (triggered only when significance threshold exceeded)

PLAN:     ────────────────────●─────────────────────────●────
          (timer fires periodically; most ticks = "no replan needed")

ACT:      ──────────────────────■■■■■■■■■■──────■■■■■■■■■■──
          (executes plan tasks; pauses between plans)
```

**Observe** runs most frequently — it's always listening.
**Reflect** runs occasionally — only when there's enough new information.
**Plan** runs periodically — but usually decides "no change needed."
**Act** runs when there's a plan to execute.

---

## Common Mistakes

### Mistake 1: Thinking ORPA Is a Strict Loop

❌ "The agent observes, then reflects, then plans, then acts, then observes again — in that exact order"

ORPA is a conceptual framework, not a strict sequential loop. Observations happen continuously. Reflections are triggered by significance. Planning is timer-driven. Actions execute asynchronously. These phases overlap and interleave.

### Mistake 2: Equating the Planning Cycle with the ORPA Cycle

❌ "The planning cycle interval IS the ORPA cycle interval"

The planning cycle is just the timer for the Plan phase. The Observe phase runs much faster (every few seconds for data streams). The Reflect phase runs on its own trigger (significance threshold). Setting the planning cycle to 15 minutes doesn't mean the agent only thinks every 15 minutes — it observes and reflects continuously.

### Mistake 3: Thinking Planning Happens Every Cycle

❌ "Every 15 minutes, the agent creates a new plan"

The planning cycle fires every 15 minutes, but most of the time the adaptation detector says "no replanning needed." The agent only creates a new plan when conditions have changed enough to warrant it. In stable conditions, the agent might go hours without replanning.

### Mistake 4: Thinking Observation Stops During Planning

❌ "While the agent is planning, it can't observe new data"

Data continues to arrive and queue during planning. The agent's observation processing may be paused during an active planning cycle (to avoid conflicts), but the data is buffered and processed on the next observation cycle. Nothing is lost.

---

## Configuration: What You Can Tune

| Parameter | What It Controls | Typical Range |
|-----------|-----------------|---------------|
| **Planning cycle interval** | How often the Plan phase checks for replanning | 5-30 minutes |
| **Significance threshold** | How much observation significance triggers a Reflection | 0.5-0.8 |
| **Data stream polling** | How often Observe receives new data | 1-60 seconds |
| **Adaptation sensitivity** | How much change triggers replanning | Configurable per factor |

**Tuning guidance:**
- Shorter planning cycle = faster response to changes, but more LLM calls
- Higher significance threshold = fewer reflections, but each one is more meaningful
- Faster data polling = more current observations, but more processing load
- Higher adaptation sensitivity = more frequent replanning, but potentially unnecessary

---

## Summary Table

| Aspect | ORPA Cycle | Planning Cycle |
|--------|-----------|---------------|
| **What** | The agent's cognitive architecture | A timer that checks for replanning |
| **Scope** | All four phases (O, R, P, A) | Just the Plan phase |
| **Runs** | Continuously (phases interleave) | Periodically (timer-driven) |
| **Frequency** | Always active | Every N minutes (configurable) |
| **Outcome** | The agent's ongoing behaviour | "Replan" or "keep current plan" |
| **Analogy** | Breathing | Deciding whether to change direction |
| **Configurable?** | Each phase has its own settings | Planning cycle interval |
