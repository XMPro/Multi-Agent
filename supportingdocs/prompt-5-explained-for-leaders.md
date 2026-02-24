# Why Does the MAGS Configuration Wizard Ask These Questions?
## Explaining Prompt 5 (Agent Inventory) to Senior Technical Leaders

---

## The Core Question: How Many AI Agents Do You Need?

When you deploy a MAGS team, you're assembling a group of AI agents that work together — like hiring a team of specialists. The fundamental question is: **how many specialists do you need, and what roles should they play?**

Too few agents and you have one person trying to do everything — the analysis is shallow, the decisions are rushed, and there's no independent check on safety. Too many agents and you've created unnecessary complexity, cost, and coordination overhead.

Prompt 5 is the structured process for answering this question correctly, every time, for any use case.

---

## Why Not Just Decide Intuitively?

We ran the same use case description through four leading AI systems (Claude, ChatGPT, Gemini, and Grok) without a structured process. They produced teams of 4, 5, 5, and 6 agents respectively — a 50% variance in team size for the same problem.

This matters because:
- **Too few agents** means combining roles that should be independent (e.g., the person proposing a change also approving it — a conflict of interest)
- **Too many agents** means unnecessary cost and complexity
- **Inconsistent results** mean you can't trust the process or compare designs across projects

The structured scoring process in Prompt 5 reduces this variance to near-zero. After the improvements, three of four AI systems produced identical 6-agent teams. The fourth produced 5 agents using a legitimate design choice that the prompt explicitly permits.

---

## The Seven Dimensions: What Are We Actually Measuring?

The prompt scores your use case across seven dimensions. Here's what each one is really asking:

### 1. Decision Authority & Consequences
**The question**: How much can the AI team do on its own, and how bad is it if they get it wrong?

**Why it matters**: A team that can only make recommendations needs fewer agents than one that can autonomously adjust physical equipment. And a team operating in a safety-critical environment (flammable materials, pressurised systems, medical devices) needs more independent checks than one managing a spreadsheet.

**The insight**: We found that AI systems were inconsistently scoring "how much authority" the team has. We added a simple formula: if the operating range is more than 10% wide AND there's an independent safety check AND there are rate-of-change limits, that's "wide autonomy." This eliminated the ambiguity.

### 2. Process Complexity & Data Volume
**The question**: How much data does the team need to watch, and how complicated are the relationships between variables?

**Why it matters**: A team monitoring 5 simple sensors needs one monitor agent. A team monitoring 50 variables with complex, nonlinear interactions between them needs more analytical capacity.

### 3. Decision Timing & Coordination
**The question**: How fast do decisions need to happen, and how many different specialties need to work together?

**Why it matters**: A team making decisions every 15 minutes across four disciplines (engineering, economics, quality, safety) needs more coordination than a team making daily decisions in a single domain.

### 4. Knowledge Synthesis & Expertise
**The question**: How deep does the domain knowledge need to be, and how much diagnosis is required?

**Why it matters**: A team that needs to understand distillation thermodynamics AND market economics AND safety engineering needs more specialised agents than a team applying simple rules.

### 5. Quality, Safety & Compliance
**The question**: Does the safety validation need to be completely independent from the decision-making?

**Why it matters**: This is the most important dimension for safety-critical applications. If the same agent that proposes a profitable action also validates whether it's safe, there's a conflict of interest — economic incentives can unconsciously bias the safety check. The Guardian agent must be structurally independent.

### 6. Artifact Management & Documentation
**The question**: How much documentation and reporting is required, and for how many different audiences?

**Why it matters**: A team that needs to produce regulatory submissions, engineering reports, operator notifications, and management summaries needs more documentation capability than one that just logs decisions.

### 7. Environmental & Operational Context
**The question**: Is this a continuous operation or event-driven? One site or many?

**Why it matters**: A continuous 24/7 operation needs different agent design than a batch process or a geographically distributed system.

---

## The Three Rules That Prevent Bad Designs

Beyond the scoring, Prompt 5 enforces three non-negotiable rules that no amount of scoring can override:

### Rule 1: The Guardian Must Be Independent
The agent that validates safety constraints must have **no economic objective**. It cannot be the same agent that proposes profit-maximising actions. This is the AI equivalent of separating the person who designs a bridge from the person who certifies it's safe.

*Why this matters to leaders*: Without this rule, an AI system optimising for profit will unconsciously find ways to rationalise safety concerns away. The Guardian's entire value comes from having no incentive to relax constraints.

### Rule 2: The Executor Cannot Make Decisions
The agent that writes commands to physical systems (setpoints, controls, actuators) must only implement what has been approved. It cannot decide what to do — it only does what it's told.

*Why this matters to leaders*: This is the AI equivalent of separating the person who approves a purchase order from the person who processes the payment. It creates an auditable chain of custody.

### Rule 3: The Monitor Cannot Write to Systems
The agent that collects and distributes data cannot also send commands to control systems.

*Why this matters to leaders*: This prevents a single point of failure where a data collection error could accidentally trigger a control action.

---

## The "AND Test": When Do You Need Two Specialists Instead of One?

The most common design question is: "Can we combine the process analyst and the economic analyst into one agent to save cost?"

The answer depends on a simple test: **write the job description for the combined role**. If it requires the word "AND" to connect two fundamentally different disciplines — "analyse separation thermodynamics AND calculate market price economics" — you need two agents.

This isn't arbitrary. It reflects how human expertise works:
- A process engineer and an economist are different people with different training
- Combining them into one AI agent means the reasoning is shallower in both domains
- More importantly, it means the economic analysis can unconsciously influence the engineering analysis (and vice versa)

The test also applies to data: if the two roles use fundamentally different data sources (physical sensor readings vs. market price feeds), they should be separate agents.

---

## Why Did We Test This Across Four AI Systems?

We deliberately ran the same use case through Claude, ChatGPT, Gemini, and Grok to stress-test the prompt. The results were revealing:

**Before the improvements**: 4, 5, 5, 6 agents — a 50% variance
**After the improvements**: 5, 6, 6, 6 agents — near-consensus

The remaining difference (ChatGPT at 5 vs. others at 6) is actually a legitimate design choice: ChatGPT correctly identified that the rules permit combining the monitoring and process analysis roles when they share the same data source and domain. This is not wrong — it's a valid architectural decision that the prompt explicitly allows.

The key insight from this testing: **the variance was not in the final agent count — it was in the reasoning**. Before the improvements, different AI systems were making different assumptions about what "bounded autonomy" means, whether PSM regulations apply, and whether to combine roles. After the improvements, all four systems applied the same logic and reached the same conclusions.

---

## Questions Leaders Typically Ask

**"Why can't we just start with fewer agents and add more later?"**

You can, but the cost of adding agents later is higher than getting it right upfront. Each agent needs its own system prompt, behavioural rules, objective function, and integration with the team. More importantly, adding a Guardian agent after deployment means redesigning the decision flow — the existing agents were built without an independent check, and retrofitting one requires rethinking their objectives.

**"The scoring seems subjective — who decides what 'Complex' means?"**

The scoring rubric has been calibrated with specific examples and formulas to reduce subjectivity. For the most ambiguous questions (like autonomy level), we added explicit calculation methods. But some judgment is always required — that's why the prompt asks you to document your reasoning, not just your score. The reasoning is as important as the number.

**"What if we get the agent count wrong?"**

The prompt includes adjustment rules that catch common errors: minimum viable team sizes, safety-critical minimums, and combination opportunities. The validation checklist at the end catches the most common mistakes before you proceed to designing individual agents.

**"Why do we need a structured process at all? Can't an experienced engineer just decide?"**

An experienced engineer can make a good decision — but they can't make a *consistent* decision across projects, teams, and time. The structured process creates a documented, auditable rationale that can be reviewed, challenged, and improved. It also means that when a new team member joins, they can understand why the team was designed the way it was.

---

## The Bottom Line

Prompt 5 is a structured decision-making framework that answers the question "how many AI agents do you need?" in a way that is:

- **Consistent** — the same use case produces the same answer regardless of who runs it
- **Auditable** — every design decision is documented with reasoning
- **Safe** — non-negotiable separation rules prevent conflicts of interest
- **Generic** — works for any industry, any use case, any scale

The seven dimensions capture the factors that genuinely drive team complexity. The three mandatory separation rules capture the safety architecture principles that cannot be compromised. The combination tests capture the efficiency principles that prevent over-engineering.

Together, they produce a team design that is right-sized for the problem — not too small to be effective, not too large to be practical.
