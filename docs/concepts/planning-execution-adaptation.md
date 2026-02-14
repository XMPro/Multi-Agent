# MAGS: Planning, Plan Execution, and Plan Adaptation

## The One-Sentence Version

**Planning** creates the roadmap. **Execution** follows the roadmap. **Adaptation** decides when the roadmap needs to change.

---

## The Analogy: A Road Trip

You're driving from Sydney to Melbourne.

**Planning** (before you leave):
- Choose the route (M31 Hume Highway)
- Identify stops (fuel at Goulburn, lunch at Albury)
- Estimate timing (9 hours total)
- Set the goal (arrive by 6 PM)

**Execution** (while driving):
- Follow the planned route
- Stop for fuel at Goulburn as planned
- Track progress against the schedule

**Adaptation** (when things change):
- Road closure ahead → need a new route (replan)
- Running 30 minutes ahead of schedule → skip the Albury stop (adjust plan)
- Car making strange noise → pull over and investigate (pause plan, new priority)
- Everything going smoothly → keep following the plan (no adaptation needed)

The key insight: **you don't replan every 5 minutes**. You only replan when something has changed enough to make the current plan invalid or suboptimal. Most of the time, you're just executing.

---

## The Three Phases in Detail

### Planning: Creating the Roadmap

Planning is the process of **deciding what to do** — creating a structured plan with goals, tasks, and actions.

| What It Is | What It Isn't |
|-----------|--------------|
| Creating a sequence of tasks to achieve a goal | Executing those tasks |
| Deciding WHAT to do and in WHAT ORDER | Doing it |
| Triggered by new information or changed conditions | Running continuously |

**How planning works in MAGS:**

1. The planning adaptation detector determines that a new plan is needed (see Adaptation below)
2. The agent retrieves relevant context: recent observations, reflections, current objectives, constraints, available actions
3. The planning strategy (e.g., Plan-and-Solve) generates a PDDL-style plan through the LLM
4. The plan is validated against constraints — any plan that would violate a constraint is rejected
5. The validated plan is stored and ready for execution

**A plan contains:**
- **Goal**: What the plan aims to achieve
- **Tasks**: Ordered steps to reach the goal
- **Actions**: Specific operations within each task (linked to tools)
- **Measure Impacts**: Predicted effects on measures (used for constraint validation)

**Planning is expensive** — it involves LLM calls, constraint validation, and context retrieval. That's why MAGS doesn't plan on every cycle — it only plans when adaptation detection says it's necessary.

### Execution: Following the Roadmap

Execution is the process of **carrying out the plan** — performing the tasks and actions in order.

| What It Is | What It Isn't |
|-----------|--------------|
| Performing planned tasks using tools | Deciding what to do |
| Following the sequence defined in the plan | Creating new tasks on the fly |
| Reporting results back | Evaluating whether the plan is still valid |

**How execution works in MAGS:**

1. The agent picks up the next task from the current plan
2. For each action in the task, the agent invokes the appropriate tool
3. The tool result is recorded (success or failure)
4. The agent moves to the next task
5. Results are stored as observations, which feed back into the ORPA cycle

**Execution is straightforward** — the hard thinking happened during planning. Execution is about reliably carrying out what was decided.

### Adaptation: Knowing When to Change the Roadmap

Adaptation is the process of **detecting when the current plan is no longer valid** and deciding whether to replan.

| What It Is | What It Isn't |
|-----------|--------------|
| Evaluating whether the current plan still makes sense | Creating a new plan (that's planning) |
| Detecting changed conditions that invalidate the plan | Executing the plan |
| A continuous background check | A one-time decision |

**How adaptation works in MAGS:**

The Plan Adaptation Detector evaluates multiple factors on each cycle:

1. **Recent memory significance** — Have important new observations arrived that the current plan doesn't account for?
2. **Current plan validity** — Is the plan still progressing? Have any tasks failed?
3. **Environmental changes** — Have conditions changed enough to make the plan's assumptions wrong?
4. **Goal achievement** — Has the goal already been achieved? Or has it become impossible?
5. **Constraint status** — Would continuing the current plan violate any constraints?

**Adaptation outcomes:**
- **No adaptation needed** — Current plan is still valid. Continue executing.
- **Minor adjustment** — Modify the current plan (skip a task, change a parameter).
- **Full replan** — Current plan is invalid. Trigger a new planning cycle.

---

## How They Interact

```
        ┌──────────────────────────────────────────┐
        │                                          │
        ▼                                          │
   ADAPTATION                                      │
   "Is the current plan still valid?"              │
        │                                          │
        ├── Yes → Continue EXECUTION               │
        │                                          │
        └── No → Trigger PLANNING                  │
                    │                              │
                    ▼                              │
               PLANNING                            │
               "Create a new plan"                 │
                    │                              │
                    ▼                              │
               EXECUTION                           │
               "Carry out the plan"                │
                    │                              │
                    ▼                              │
               Results become observations ────────┘
               (feed back into adaptation check)
```

**The cycle:**
1. Adaptation checks if the plan is still valid
2. If not, planning creates a new plan
3. Execution carries out the plan
4. Results create new observations
5. New observations feed back into the next adaptation check

---

## Timing: When Each Phase Runs

| Phase | When It Runs | How Long It Takes | How Often |
|-------|-------------|-------------------|-----------|
| **Adaptation** | Every planning cycle tick (timer-based) | Milliseconds (lightweight checks) | Every few minutes |
| **Planning** | Only when adaptation says "replan needed" | Seconds to minutes (LLM calls) | Only when needed |
| **Execution** | Continuously while a plan exists | Varies by action (tool calls) | Ongoing |

**Key insight**: Adaptation runs frequently but is cheap. Planning runs rarely but is expensive. Execution runs continuously. This is efficient — you don't waste LLM calls on planning when the current plan is still working.

---

## Common Mistakes

### Mistake 1: Replanning Every Cycle

❌ "The agent should create a new plan every 15 minutes"

Planning is expensive (LLM calls, constraint validation). If the current plan is still valid, there's no reason to replan. The adaptation detector exists specifically to avoid unnecessary replanning.

### Mistake 2: No Adaptation (Static Plans)

❌ "Once the agent has a plan, it follows it until completion"

In dynamic environments, conditions change. A plan created 30 minutes ago may be based on assumptions that are no longer true. Without adaptation, the agent blindly follows an outdated plan.

### Mistake 3: Confusing Adaptation with Execution

❌ "The agent adapts by executing a different action"

Adaptation is about EVALUATING the plan, not executing it. If adaptation determines the plan needs to change, it triggers PLANNING (which creates a new plan). Execution then follows the new plan.

### Mistake 4: Planning Without Context

❌ "The agent plans based on its objective function alone"

Good planning requires context: recent observations, past reflections, current constraints, available actions, and team state. An agent that plans without context creates plans that don't account for the current situation.

---

## Summary Table

| Aspect | Planning | Execution | Adaptation |
|--------|---------|-----------|------------|
| **Question** | "What should I do?" | "Do it" | "Is my plan still right?" |
| **Trigger** | Adaptation says "replan" | Plan exists with pending tasks | Timer tick (periodic check) |
| **Cost** | High (LLM calls) | Medium (tool calls) | Low (lightweight checks) |
| **Frequency** | Only when needed | Continuous | Every cycle |
| **Output** | A new plan | Task results | "Keep going" or "replan" |
| **Analogy** | Planning the road trip | Driving the route | Checking for road closures |
