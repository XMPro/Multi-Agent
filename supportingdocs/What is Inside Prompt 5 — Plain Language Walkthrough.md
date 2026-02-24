## What's Inside Prompt 5 — Plain Language Walkthrough

Prompt 5 has 7 steps. Here's what each step does and what the rules mean:

---

### Step 1: What Kind of Problem Is This?

You pick one primary category (process optimisation, predictive maintenance, advisory, quality management, investigation, coordination, or hybrid) and check which secondary characteristics apply (autonomous execution, safety-critical, real-time, multi-disciplinary).

**Why**: The category determines which specialist roles are needed. A process optimisation team needs different agents than an investigation team.

---

### Step 2: Score Your Use Case (100 points across 7 dimensions)

**Dimension 1 — How much authority and what are the stakes?** (0-15 pts)
- *Authority*: Can agents only recommend (0 pts), make small adjustments (3 pts), act within narrow limits (6 pts), act within wide limits (9 pts), or act freely (12 pts)?
- *Consequences*: If agents make a mistake, is the impact negligible (0), low (1), moderate (2), or high (3)?
- **Rule**: For industrial control systems — if the operating range is more than 10% wide AND there's an independent safety check AND there are rate-of-change limits, score as "wide authority" (9 pts). Calculate band width as: (high limit minus low limit) divided by high limit, times 100.

**Dimension 2 — How complex is the data and process?** (0-15 pts)
- *Data volume*: 1-5 variables (0), 6-20 (2), 21-50 (4), 50+ (6)
- *Relationship complexity*: Simple cause-and-effect (0), some interdependencies (2), significant nonlinear interactions (4), highly complex emergent behaviour (6)
- *Number of actions agents can take*: None (0), 1-2 (1), 3-5 (2), 6+ (3)

**Dimension 3 — How fast and how coordinated?** (0-15 pts)
- *Decision speed*: Days-weeks (0), hours-day (2), 15min-hours (4), 1-15min (6), under 1 minute (8)
- *Number of disciplines*: One (0), two (2), three to four (4), five or more (7)

**Dimension 4 — How deep is the expertise needed?** (0-15 pts)
- *Domain knowledge*: Simple rules (0), standard procedures (3), deep expertise with complex trade-offs (6), multiple expert domains (9)
- *Diagnosis required*: None (0), occasional (2), regular root cause analysis (4), complex diagnosis is the primary job (6)

**Dimension 5 — How critical is safety and compliance?** (0-15 pts)
- *Independent validation*: Not needed (0), can be embedded in decisions (2), should be separate (5), MUST be independent with no conflict of interest (8)
- *Regulatory burden*: None (0), general industrial standards (2), industry-specific regulations like PSM/OSHA (4), highly regulated like aerospace or pharma (7)
- **Rule**: PSM (Process Safety Management) or OSHA 1910.119 = score as "Significant" (4 pts). Internal governance only = "Basic" (2 pts).

**Dimension 6 — How much documentation?** (0-15 pts)
- *Documentation*: Basic logging (0), standard audit trail (3), comprehensive traceability (6), regulatory submissions (9)
- *Stakeholder types*: One audience (0), two (2), three to four (4), five or more (6)

**Dimension 7 — What's the operating environment?** (0-10 pts)
- *Operating mode*: Continuous steady-state (0), continuous with disturbances (2), batch/cyclic (4), event-driven (6)
- *Geographic spread*: Single location (0), multiple units same site (1), multiple sites (2), highly distributed (4)

**Total score interpretation**:
- 0-25: Low complexity → 2-3 agents
- 26-45: Moderate → 3-4 agents
- 46-65: High → 4-6 agents
- 66-85: Very high → 6-8 agents
- 86-100: Extreme → 8+ agents

---

### Step 3: Calculate Your Total Score

Add up all seven dimensions. This gives you the complexity classification.

---

### Step 4: Determine Which Roles Are Needed

**Before anything else — Three Non-Negotiable Separations:**

1. **The Safety Validator must be independent** from any role with an economic or optimisation objective. The validator must have no financial incentive to approve unsafe actions.
2. **The Executor must not make decisions** — it only implements what has been approved by others.
3. **The Monitor must not write to control systems** — data collection and action execution must be separate.

These three rules cannot be overridden by any other consideration.

**Always required:**
- **Monitor/Observer** — every team needs at least one agent watching the environment

**Add these if triggered by your scores:**
- **Analyser/Interpreter** — needed if your diagnosis score is 4+, complexity is 4+, or expertise is 6+
- **Decision-Maker/Optimizer** — needed if authority is 6+, disciplines are 4+, or expertise is 6+
- **Executor/Controller** — needed if authority is 3+, actions exist, or autonomous execution is checked
- **Guardian/Validator** — needed if independent validation is required (score 8) or safety-critical with wide authority

**Add these only for complex cases:**
- **Coordinator/Orchestrator** — only if 5+ disciplines or complex multi-step workflows
- **Artifact Manager** — only if extensive documentation (score 6+) or significant regulatory burden
- **Historian/Knowledge Manager** — only if historical pattern matching is the core function

**The AND Test for splitting Analysers:**
Write the job description for the combined role. If it requires "AND" to connect two different disciplines (e.g., "analyse engineering data AND calculate financial economics"), you must split them into two separate agents. A single agent should have one coherent expertise that a single human expert would possess.

**The Data Domain Rule:**
If two analysis functions use fundamentally different data sources (e.g., physical sensor readings vs. market price feeds), they must be separate agents.

---

### Step 5: Calculate Final Agent Count

Add up all the roles. Then apply four adjustment rules:

1. **Minimum viable team**: If you only have 1 agent, add another. If you have 2 agents with wide authority, add an Executor (minimum 3 for autonomous teams).

2. **Combination rules** (strict):
   - **NEVER combine**: Guardian with any economic role; Decision-Maker with Executor
   - **MUST split**: Any roles that fail the AND Test or Data Domain Rule
   - **MAY combine** (only if ALL conditions met): Monitor + one Analyser, if same location, same data source, same domain

3. **Safety-critical minimum**: If independent validation is required, you must have at least 4 agents: Monitor + Analyser + Decision-Maker + Guardian.

4. **Advisory-only simplification**: If agents only recommend (no autonomous actions), no Executor needed; consider combining Decision-Maker into Analyser.

---

### Step 6: Define Each Agent

For each agent, specify: name, role category, primary function (one sentence — must not require "AND" to describe), key responsibilities, decision cycle, and which agents it receives from and sends to.

---

### Step 7: Describe How They Work Together

Three patterns:
- **Independent operations**: Which agents run continuously without needing coordination?
- **Sequential processing**: What is the typical decision flow from agent to agent?
- **Collaborative decisions**: What situations require multiple agents to agree before acting?

---

### Final Validation Checklist

Before proceeding, confirm:
- All functional needs are covered (monitoring, analysis, decisions, execution, safety validation)
- The Guardian has no shared objective with any economic role
- The Executor has no decision-making authority
- The Monitor has no write access to control systems
- Each agent's primary function passes the AND Test
- Team size is proportional to the complexity score
- Decision flow is clear with no circular dependencies