# MAGS: Agent Profiles vs Agent Instances

## The One-Sentence Version

A **profile** is a job description. An **instance** is a person hired for that job.

---

## The Analogy That Makes It Click

### Think of a Hospital

A hospital has a **job description** for "Emergency Room Nurse." This description defines:
- Required qualifications (skills, certifications)
- Responsibilities (triage patients, administer medication, monitor vitals)
- Behavioural rules (always check patient ID, never administer drugs without doctor's order)
- Reporting structure (reports to ER charge nurse)

This is the **profile**. There is ONE profile for "ER Nurse."

But the hospital doesn't have one ER nurse. It has **twelve** — working different shifts, in different bays, with different patients. Each nurse:
- Has the same qualifications and follows the same rules (from the profile)
- But has their own current patients, their own shift schedule, their own memories of what happened today
- Nurse Sarah is treating a cardiac patient in Bay 3; Nurse James is treating a fracture in Bay 7
- They share the same job description but have completely different current states

Each nurse is an **instance** of the ER Nurse profile.

**If the hospital created a separate job description for every single nurse, that would be absurd.** You'd have "ER Nurse - Sarah," "ER Nurse - James," "ER Nurse - Maria" — twelve nearly identical documents that all say the same thing. When the hospital updates the triage protocol, they'd have to update twelve job descriptions instead of one.

---

## In MAGS Terms

### Profile (The Template)

A profile defines **what kind of agent this is**:

- **System Prompt** — The agent's identity, expertise, and personality
- **Skills** — What the agent knows how to do
- **Behavioural Rules** — Obligations, prohibitions, permissions, conditional duties
- **Technical Specs** — Which LLM model, token limits, planning cycle interval
- **RAG Collections** — Which knowledge bases the agent can access

A profile is created **once** and can be reused across many instances.

### Instance (The Running Agent)

An instance is **a specific, running agent** with its own:

- **Current state** — What is this agent doing right now?
- **Memories** — What has this agent observed and learned?
- **Active plans** — What is this agent working on?
- **Team membership** — Which team is this agent part of?
- **Conversations** — What has this agent discussed with users or other agents?
- **Cumulative metrics** — How has this agent performed?

An instance is created **per deployment** — each running agent is a separate instance.

---

## Why One-to-One Mapping Is Wrong

### The Anti-Pattern: One Profile Per Instance

```
❌ WRONG: One profile per instance

Profile: "Process Monitor - Depropaniser Unit 31"     → Instance: MON-001-DEPRO
Profile: "Process Monitor - Debutaniser Unit 32"       → Instance: MON-001-DEBUT
Profile: "Process Monitor - Deethaniser Unit 30"       → Instance: MON-001-DEETH
```

This creates three nearly identical profiles that differ only in which unit they monitor. When you want to update the monitoring logic (e.g., add a new behavioural rule about analyser deadtime), you have to update three profiles.

### The Correct Pattern: One Profile, Multiple Instances

```
✅ RIGHT: One profile, multiple instances

Profile: "Process Monitor"
    ├── Instance: MON-001-DEPRO  (Team: Depropaniser, monitors Unit 31 tags)
    ├── Instance: MON-001-DEBUT  (Team: Debutaniser, monitors Unit 32 tags)
    └── Instance: MON-001-DEETH  (Team: Deethaniser, monitors Unit 30 tags)
```

One profile defines what a Process Monitor does. Three instances deploy that profile to three different units. Each instance:
- Follows the same rules (from the shared profile)
- Monitors different data (configured per instance via team and tool assignments)
- Has its own memories (what it has observed on its unit)
- Belongs to a different team (with different team objectives)

---

## What Goes Where

| Aspect | Profile | Instance |
|--------|---------|----------|
| "What kind of agent is this?" | ✅ | |
| System prompt (identity, expertise) | ✅ | |
| Behavioural rules | ✅ | |
| Skills and capabilities | ✅ | |
| LLM model and token limits | ✅ | |
| RAG collection assignments | ✅ | |
| Planning cycle interval | ✅ | |
| "Which specific agent is this?" | | ✅ |
| Team membership | | ✅ |
| Current state and status | | ✅ |
| Memories and observations | | ✅ |
| Active plans and tasks | | ✅ |
| Conversation history | | ✅ |
| Tool configurations (data streams) | | ✅ |
| Performance metrics | | ✅ |
| User prompt (for Assistant type) | | ✅ |

---

## Real-World Scaling Examples

### Example 1: Multi-Site Deployment

A mining company has 5 processing plants, each with a flotation circuit. They want MAGS to optimise each circuit.

**Profiles** (created once, shared across all sites):
- Process Monitor — observes flotation data
- Metallurgical Analyst — interprets grade and recovery
- Economic Analyst — evaluates concentrate value vs reagent cost
- Optimisation Decision-Maker — proposes setpoint changes
- Quality Guardian — validates against constraints

**Instances** (5 per profile = 25 total):
- Each plant gets 5 agent instances, one per profile
- Each instance belongs to a site-specific team
- Each instance monitors site-specific data streams
- Each instance has its own memories of that site's behaviour

**If they used one-to-one mapping**, they'd have 25 profiles — 5 nearly identical copies of each role. Updating the monitoring logic means changing 5 Process Monitor profiles instead of 1.

### Example 2: Shift-Based Operation

A refinery runs 24/7 with 4 shift crews. They want each shift to have its own advisory agent that remembers shift-specific context.

**Profile** (one):
- Shift Advisor — provides operational guidance, answers questions, tracks shift handover notes

**Instances** (four):
- Shift-A Advisor — has memories of Shift A's patterns, preferences, and recurring issues
- Shift-B Advisor — has memories of Shift B's patterns
- Shift-C Advisor — has memories of Shift C's patterns
- Shift-D Advisor — has memories of Shift D's patterns

All four follow the same rules and have the same expertise (profile), but each has accumulated different memories from working with different shift crews (instance state).

### Example 3: Multi-Tenant SaaS

A software company offers MAGS-based advisory agents to multiple customers.

**Profile** (one per agent role):
- Equipment Health Advisor — answers questions about equipment condition

**Instances** (one per customer):
- Customer A's Equipment Health Advisor — has RAG access to Customer A's maintenance records
- Customer B's Equipment Health Advisor — has RAG access to Customer B's maintenance records

Same profile, different data access, different memories, different teams.

---

## The Litmus Test

Ask yourself: **"If I change a behavioural rule, how many things do I need to update?"**

- If the answer is **one** (the profile) → You're doing it right
- If the answer is **many** (one per instance) → You've fallen into the one-to-one trap

Ask yourself: **"Do these two agents differ in WHO THEY ARE, or just WHERE THEY WORK?"**

- If they differ in **who they are** (different skills, different rules, different expertise) → They need different profiles
- If they differ in **where they work** (different team, different data, different site) → They need the same profile with different instances

---

## When You DO Need Different Profiles

Different profiles are appropriate when agents have **fundamentally different roles**:

```
Profile: "Process Monitor"        — Observes data, detects changes
Profile: "Separation Analyst"     — Interprets separation performance
Profile: "Economic Analyst"       — Evaluates financial trade-offs
Profile: "Decision-Maker"         — Synthesises inputs, proposes actions
Profile: "Guardian"               — Validates safety constraints
Profile: "Control Executor"       — Writes setpoints to DCS
```

These are genuinely different jobs with different skills, rules, and responsibilities. They need different profiles.

But if you deploy this team to three different columns, you don't create 18 profiles. You create 6 profiles and 18 instances (3 instances per profile, one per column).

---

## Summary

| Concept | Profile | Instance |
|---------|---------|----------|
| **Analogy** | Job description | Employee |
| **Created** | Once per role | Once per deployment |
| **Contains** | Skills, rules, identity | State, memories, team |
| **Shared** | Across many instances | Unique to one agent |
| **Updated** | When the role changes | Continuously (as agent operates) |
| **Count** | Few (one per distinct role) | Many (one per running agent) |
