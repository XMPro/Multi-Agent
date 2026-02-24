# Prompt 5: Agent Inventory
*Determine optimal team size and agent composition using multi-dimensional scoring.*

**Version**: 1.2 | **Phase**: Design — Step 5 of 10 | **Prerequisites**: Prompt 4 (Team Overview)

> Use this prompt to score your use case across 7 dimensions and determine the right number and type of agents. The agent count emerges from use case characteristics — it is not predetermined. Updated with hardened combination rules and domain-specific calibrations.

---

```prompt
## MAGS Agent Inventory

**Purpose**: Determine optimal team size and composition using multi-dimensional scoring across diverse use case types.

**Prerequisites**: ✅ Completed Prompt 4 team overview.

---

## Overview

This prompt determines the RIGHT number of agents (not constrained to arbitrary limits) by:
1. Scoring your use case across 7 dimensions (100 points total)
2. Identifying required functional roles based on characteristics
3. Building the team using role-based composition
4. Applying strict separation rules and efficiency adjustments

**The agent count emerges from use case characteristics**, not predetermined limits.

---

## STEP 1: Use Case Classification

### What is the primary purpose of this agent team?

Select ONE primary category:

- [ ] **Process Optimization** - Real-time control and optimization of continuous/batch processes
- [ ] **Predictive Maintenance** - Early detection and prevention of equipment failures
- [ ] **Decision Support/Advisory** - Analysis and recommendations for human decision-makers
- [ ] **Quality Management** - Ensuring consistency and specification compliance
- [ ] **Investigation/Diagnosis** - Root cause analysis and problem identification
- [ ] **Coordination/Workflow** - Managing complex multi-step or multi-party processes
- [ ] **Hybrid** - Combination of above (specify: _______________)

**Primary Category**: __________

**Secondary Characteristics** (check all that apply):
- [ ] Autonomous execution (agents take direct actions)
- [ ] Human-in-loop (agents recommend, humans approve)
- [ ] Multi-disciplinary coordination required
- [ ] Safety-critical consequences
- [ ] Real-time response requirements
- [ ] Regulatory compliance obligations

---

## STEP 2: Multi-Dimensional Scoring

### DIMENSION 1: Decision Authority & Consequences (0-15 points)

**Q1: What level of autonomous authority does the team have?**

- [ ] **Advisory Only** (0 pts) - Recommendations only, no direct actions
- [ ] **Soft Actions** (3 pts) - Can adjust parameters with no safety implications
- [ ] **Bounded Autonomy** (6 pts) - Can take actions within narrow bands; human approves every move or bands are very tight (< 10% of operating range)
- [ ] **Wide Autonomy** (9 pts) - Can reach any operating point within wide bands (≥ 10% of operating range) over multiple cycles; rate-of-change limits constrain speed but not ultimate authority; Guardian veto provides independent safety check
- [ ] **Full Autonomy** (12 pts) - Can take major actions with no Guardian, no rate limits, and no human approval path (rare in industrial settings)

> **Process Control Calibration**: If the system has setpoint bands ≥ 10% of operating range AND a Guardian veto AND rate-of-change limits → select **Wide Autonomy (9 pts)**. If human approval is required for every move → select **Bounded Autonomy (6 pts)**.
>
> **How to calculate band width**: (High limit − Low limit) ÷ (High limit) × 100%. If the result is ≥ 10%, select Wide Autonomy. Examples: a flow controller with range 10–18.5 units = 46% → Wide Autonomy; a temperature controller with range 75–87°C = 14% → Wide Autonomy; a valve position limited to ±5% around a fixed setpoint = Bounded Autonomy. If band widths are not stated in the case materials, ask the user to confirm them before scoring Q1.

**Q2: What are the consequences of agent errors?**

- [ ] **Negligible** (0 pts) - Minor inconvenience, <$1k impact
- [ ] **Low** (1 pt) - Moderate rework, $1k-$50k impact, no equipment damage
- [ ] **Moderate** (2 pts) - $50k-$500k impact, minor equipment wear, manageable alarms; SIS/SIF protection confirmed AND agent cannot defeat those protections
- [ ] **High** (3 pts) - $500k+ impact, potential for loss of containment, SIF trips, or safety threshold breaches

> **Process Safety Calibration**: Any process involving flammable or toxic materials under pressure defaults to **High (3 pts)** unless SIS/SIF protection is confirmed AND the agent cannot defeat those protections.

**DIMENSION 1 TOTAL**: _____ / 15

---

### DIMENSION 2: Process Complexity & Data Volume (0-15 points)

**Q3: How many data sources/variables must be monitored?**

- [ ] **Few** (0 pts) - 1-5 variables/sources
- [ ] **Moderate** (2 pts) - 6-20 variables/sources
- [ ] **Many** (4 pts) - 21-50 variables/sources
- [ ] **Extensive** (6 pts) - 50+ variables/sources

**Q4: How complex are the relationships between variables?**

- [ ] **Simple** (0 pts) - Direct cause-effect, linear relationships
- [ ] **Moderate** (2 pts) - Some interdependencies, mostly understood
- [ ] **Complex** (4 pts) - Significant interdependencies, some unknown
- [ ] **Very Complex** (6 pts) - Highly nonlinear, emergent behaviors

**Q5: How many control degrees of freedom (actions agents can take)?**

- [ ] **None** (0 pts) - Advisory only, no actions
- [ ] **1-2** (1 pt) - Very limited action space
- [ ] **3-5** (2 pts) - Moderate action space
- [ ] **6+** (3 pts) - Large action space

**DIMENSION 2 TOTAL**: _____ / 15

---

### DIMENSION 3: Decision Timing & Coordination (0-15 points)

**Q6: What is the required decision cycle time?**

- [ ] **Days-Weeks** (0 pts) - Strategic decisions, slow processes
- [ ] **Hours-Day** (2 pts) - Tactical decisions, batch processes
- [ ] **15min-Hours** (4 pts) - Operational decisions, slow continuous
- [ ] **1-15min** (6 pts) - Real-time decisions, fast continuous
- [ ] **<1min** (8 pts) - Rapid response requirements

**Q7: How many disciplines/specialties must coordinate?**

- [ ] **Single** (0 pts) - One domain (e.g., just process control)
- [ ] **Dual** (2 pts) - Two domains (e.g., process + economics)
- [ ] **Multiple** (4 pts) - 3-4 domains
- [ ] **Many** (7 pts) - 5+ disciplines requiring coordination

**DIMENSION 3 TOTAL**: _____ / 15

---

### DIMENSION 4: Knowledge Synthesis & Expertise (0-15 points)

**Q8: How much domain expertise must agents synthesize?**

- [ ] **Minimal** (0 pts) - Simple rules or calculations
- [ ] **Moderate** (3 pts) - Standard procedures and heuristics
- [ ] **Substantial** (6 pts) - Deep domain knowledge, complex trade-offs
- [ ] **Expert** (9 pts) - Multiple expert domains, novel situations

**Q9: How much investigation/diagnosis is required?**

- [ ] **None** (0 pts) - Clear inputs → clear outputs
- [ ] **Minimal** (2 pts) - Occasional diagnosis when issues arise; primary function is optimisation or control, not troubleshooting
- [ ] **Moderate** (4 pts) - Regular root cause analysis required; diagnosis supports every decision cycle
- [ ] **Extensive** (6 pts) - Complex diagnostic reasoning is primary function

**DIMENSION 4 TOTAL**: _____ / 15

---

### DIMENSION 5: Quality, Safety & Compliance (0-15 points)

**Q10: Is independent safety/quality validation required?**

- [ ] **No** (0 pts) - No special validation needed
- [ ] **Embedded** (2 pts) - Validation can be part of decision process
- [ ] **Separate** (5 pts) - Should be separate but can share objectives
- [ ] **Independent** (8 pts) - MUST be independent with no conflict of interest; the validator must have no economic incentive to relax constraints

**Q11: What is the regulatory/compliance burden?**

- [ ] **None** (0 pts) - No regulatory requirements
- [ ] **Basic** (2 pts) - General industrial standards; internal governance only, no external regulatory framework
- [ ] **Significant** (4 pts) - Industry-specific regulations (PSM/OSHA 1910.119, GMP, ISO functional safety); external regulatory framework applies
- [ ] **Stringent** (7 pts) - Highly regulated (aerospace, pharma, nuclear); regulatory submissions required

> **Industrial Calibration**: PSM (Process Safety Management), OSHA 1910.119, or equivalent → **Significant (4 pts)**. Internal governance only → **Basic (2 pts)**.

**DIMENSION 5 TOTAL**: _____ / 15

---

### DIMENSION 6: Artifact Management & Documentation (0-15 points)

**Q12: How much structured documentation/artifact management is required?**

- [ ] **Minimal** (0 pts) - Basic logging only
- [ ] **Moderate** (3 pts) - Standard audit trail and reporting
- [ ] **Substantial** (6 pts) - Comprehensive documentation with traceability
- [ ] **Extensive** (9 pts) - Complex document management, regulatory submissions

**Q13: How many stakeholder types require different information?**

- [ ] **Single** (0 pts) - One audience
- [ ] **Dual** (2 pts) - Two audiences (e.g., operations + engineering)
- [ ] **Multiple** (4 pts) - 3-4 stakeholder types with distinct information needs
- [ ] **Many** (6 pts) - 5+ stakeholder types

**DIMENSION 6 TOTAL**: _____ / 15

---

### DIMENSION 7: Environmental & Operational Context (0-10 points)

**Q14: What is the operational cadence?**

- [ ] **Continuous Steady-State** (0 pts) - Continuous, minimal variation
- [ ] **Continuous with Disturbances** (2 pts) - Continuous but frequent upsets
- [ ] **Batch/Cyclic** (4 pts) - Discrete batches or cycles
- [ ] **Event-Driven** (6 pts) - Triggered by specific events/conditions

**Q15: How distributed is the system geographically/logically?**

- [ ] **Single Location** (0 pts) - One unit, one location
- [ ] **Co-located Units** (1 pt) - Multiple units, same site
- [ ] **Distributed** (2 pts) - Multiple sites or complex distributed system
- [ ] **Highly Distributed** (4 pts) - Many sites, supply chain, multi-organization

**DIMENSION 7 TOTAL**: _____ / 10

---

## STEP 3: Calculate Total Score

| Dimension | Your Score | Maximum |
|-----------|-----------|---------|
| 1. Decision Authority & Consequences | _____ | 15 |
| 2. Process Complexity & Data Volume | _____ | 15 |
| 3. Decision Timing & Coordination | _____ | 15 |
| 4. Knowledge Synthesis & Expertise | _____ | 15 |
| 5. Quality, Safety & Compliance | _____ | 15 |
| 6. Artifact Management & Documentation | _____ | 15 |
| 7. Environmental & Operational Context | _____ | 10 |
| **TOTAL SCORE** | **_____** | **100** |

### Complexity Classification

- **0-25**: 🟢 **LOW** - Simple, single-discipline, advisory
- **26-45**: 🟡 **MODERATE** - Some coordination, moderate expertise
- **46-65**: 🟠 **HIGH** - Multi-discipline, significant expertise, safety considerations
- **66-85**: 🔴 **VERY HIGH** - Highly coordinated, safety-critical, regulatory
- **86-100**: 🔴 **EXTREME** - Maximum coordination, safety-critical, distributed

**Your Classification**: __________

---

## STEP 4: Determine Required Functional Roles

### ⚠️ MANDATORY SEPARATIONS — Apply Before Any Other Rules

These separations are non-negotiable. No combination rule can override them:

1. **Guardian/Validator MUST be independent** from any role with an economic or optimisation objective. The Guardian's value comes entirely from having no incentive to relax constraints for profit.
2. **Executor MUST NOT have decision-making authority**. It only implements what the Guardian approves. The entity proposing actions must not also execute them.
3. **Monitor MUST NOT have write access** to any control system. State collection and action execution must be separate.

If any proposed combination would violate these separations, the combination is **forbidden regardless of other rules**.

---

### ✅ ALWAYS REQUIRED

**Monitor/Observer** - Every team needs this
- Continuous data collection, state assessment, trigger detection
- Consider multiple monitors if:
  - Q3 ≥ 4 pts (20+ variables) AND geographically distributed
  - Different timeframes (real-time + historical)
  - Multiple specialized domains

**How many monitors needed?** _____

---

### CONDITIONAL ROLES

**Analyzer/Interpreter** - Required if ANY apply:
- [ ] Q9 (investigation) ≥ 4 pts
- [ ] Q4 (complexity) ≥ 4 pts
- [ ] Q8 (expertise) ≥ 6 pts
- [ ] Use case = Investigation/Diagnosis, Predictive Maintenance, or Quality Management

**If required, apply the AND Test to determine how many:**

> **The AND Test**: Write the system prompt for the proposed combined agent. If it requires the word "AND" to connect two fundamentally different disciplines (e.g., "Analyse fluid dynamics AND calculate market price spreads"), you MUST split them into separate agents. A well-designed agent has a system prompt describing a single, coherent expertise.

> **The Single Expert Test**: Ask "Would a single human expert be expected to have both of these skills?" A process engineer and an economist are different people. If the answer is no, split them.

> **The Data Domain Rule**: You MUST split Analyzer roles if they evaluate fundamentally different data schemas (e.g., thermodynamic physics vs. financial market pricing). Different domain knowledge, different data sources, different reasoning = different agents.

**How many analyzers needed?** _____

---

**Decision-Maker/Optimizer** - Required if ANY apply:
- [ ] Q1 (autonomy) ≥ 6 pts
- [ ] Q7 (disciplines) ≥ 4 pts
- [ ] Q8 (expertise) ≥ 6 pts
- [ ] Use case = Process Optimization or autonomous decision-making

If required, split into multiple if:
- [ ] Strategic vs tactical decisions separate
- [ ] Multiple competing objectives requiring separate decision-makers
- [ ] Regulatory separation of economic vs operational decisions

**How many decision-makers needed?** _____

---

**Executor/Controller** - Required if ANY apply:
- [ ] Q1 (autonomy) ≥ 3 pts
- [ ] Q5 (control DOF) ≥ 1 pt
- [ ] "Autonomous execution" checked in use case classification

If required, split into multiple if:
- [ ] Different action types (control vs communication)
- [ ] Critical timing/sequencing needs
- [ ] Distributed execution across systems

**How many executors needed?** _____

---

### SPECIALIZED ROLES (Add as Needed)

**Guardian/Validator** - Required if ANY apply:
- [ ] Q10 (validation) = 8 pts (independent required)
- [ ] Q2 = 3 pts AND Q1 ≥ 9 pts (high consequences + wide autonomy)
- [ ] "Safety-critical" checked in classification

**Guardian needed?** Yes / No

---

**Coordinator/Orchestrator** - Required if ANY apply:
- [ ] Q7 (disciplines) ≥ 7 pts
- [ ] Q13 (stakeholders) ≥ 4 pts
- [ ] Use case = Coordination/Workflow
- [ ] Complex multi-step processes

**Coordinator needed?** Yes / No

---

**Artifact Manager/Documenter** - Required if ANY apply:
- [ ] Q12 (documentation) ≥ 6 pts
- [ ] Q11 (regulatory) ≥ 4 pts
- [ ] Use case requires extensive traceability
- [ ] Multiple stakeholder artifacts

**Artifact Manager needed?** Yes / No

---

**Historian/Knowledge Manager** - Required if ANY apply:
- [ ] "Golden Batch" or reference state comparison
- [ ] Historical pattern analysis is core function
- [ ] Learning from past cases essential
- [ ] Q9 = 6 pts (extensive diagnostic reasoning)

**Historian needed?** Yes / No

---

## STEP 5: Calculate Final Agent Count

### Preliminary Count

Sum your role counts from Step 4:

| Role | Count |
|------|-------|
| Monitor/Observer | _____ |
| Analyzer/Interpreter | _____ |
| Decision-Maker/Optimizer | _____ |
| Executor/Controller | _____ |
| Guardian/Validator | _____ |
| Coordinator/Orchestrator | _____ |
| Artifact Manager/Documenter | _____ |
| Historian/Knowledge Manager | _____ |
| **PRELIMINARY TOTAL** | **_____** |

---

### Adjustment Rules

**Rule 1: Minimum Viable Team**
- If total = 1: Must have ≥ 2 agents (Monitor + one other)
- If total = 2 AND Q1 ≥ 6 pts: Add Executor (minimum 3 for autonomous teams)

**Rule 2: Strict Combination & Separation Logic**

First, confirm the Mandatory Separations from Step 4 are maintained. Then apply:

**MUST NEVER combine** (forbidden regardless of other rules):
- Guardian/Validator with any role that has an economic or optimisation objective
- Decision-Maker with Executor
- Any combination that gives a single agent both write access to control systems AND decision authority

**MUST split** (these roles require separate agents):
- Analyzer roles that fail the AND Test (different disciplines in one system prompt)
- Analyzer roles that fail the Data Domain Rule (different data schemas)
- Any role where the Single Expert Test says "no single human would have both skills"

**MAY combine** (only when ALL conditions are met):
- Monitor + one Analyzer type, IF: single location, same data source, and the analysis is a direct interpretation of the monitored data (not a separate domain)
- Analyzer + Decision-Maker, IF: single discipline (Q7 ≤ 2 pts) AND the analysis directly determines the decision with no competing inputs from other analyzers

**Roles to combine (if any)**: _____________

**Rule 3: Safety-Critical Minimum**
If Q10 = 8 pts OR (Q2 = 3 AND Q1 ≥ 9), MINIMUM 4 agents:
- Must include: Monitor + Analyzer + Decision-Maker + Guardian

**Rule 4: Advisory-Only Simplification**
If Q1 = 0 pts (advisory only):
- No Executor needed
- Consider combining Decision-Maker into Analyzer
- Typical: 2-3 agents

---

### **FINAL AGENT COUNT**: _____

**Rationale for adjustments**:

_______________________________________________________________

---

## STEP 6: Define Agent Roster

Complete this profile for EACH agent:

### Agent 1: [Name]

- **Profile ID**: [TEAM-ID]-[ROLE]-001
- **Role Category**: [Monitor/Analyzer/Decision-Maker/Executor/Guardian/Coordinator/Artifact Manager/Historian]
- **Primary Function**: [One sentence — should NOT require "AND" to describe]
- **Key Responsibilities**:
  - [Responsibility 1]
  - [Responsibility 2]
  - [Responsibility 3]
- **Decision Cycle**: [Timing]
- **Dependencies**: [Receives from / Sends to which agents]

*(Repeat for each agent)*

---

## STEP 7: Interaction Patterns

### Independent Operations
[Which agents work autonomously without requiring coordination?]

### Sequential Processing (typical workflow)
[Describe the typical decision flow: Agent A → Agent B → Agent C]

### Collaborative Decisions
[What situations require multi-agent coordination or consensus?]

---

## Validation Checklist

✅ **Coverage**: All functional needs addressed?
- [ ] Monitoring/observation
- [ ] Analysis/interpretation (if needed)
- [ ] Decision-making (if needed)
- [ ] Execution (if needed)
- [ ] Safety/quality validation (if required)
- [ ] Coordination (if required)
- [ ] Documentation (if required)

✅ **Separation**: Required separations maintained?
- [ ] Guardian has NO shared objective with any economic/optimization role (if Q10 = 8)
- [ ] Executor has NO decision-making authority
- [ ] Monitor has NO write access to control systems
- [ ] Each agent's primary function passes the AND Test (no "AND" connecting different disciplines)
- [ ] Clear audit trail showing analysis/decision/execution separation (if Q11 ≥ 4)

✅ **Efficiency**: Avoiding unnecessary complexity?
- [ ] No overlapping responsibilities
- [ ] Each agent has clear, focused role
- [ ] Team size proportional to complexity
- [ ] Any combinations applied only where MAY COMBINE conditions are ALL met

✅ **Integration**: Team can work together?
- [ ] Decision flow is clear
- [ ] No circular dependencies
- [ ] Communication paths well-defined

---

```

---

## Supporting Information

### Examples

#### Example 1: Depropaniser (Process Optimization - Safety Critical)

**Step 1**: Process Optimization, Autonomous ✓, Safety-critical ✓, Real-time ✓

**Step 2 Scores**:
- D1: 12/15 (Wide Autonomy 9 pts — bands ≥10%, Guardian veto, rate limits; High consequences 3 pts — flammable hydrocarbons under pressure)
- D2: 9/15 (many variables, complex, 1-2 DOF)
- D3: 8/15 (15min-hr cycles, 3-4 disciplines)
- D4: 10/15 (substantial expertise, moderate diagnosis)
- D5: 12/15 (independent validation, Significant regulatory — PSM/SIF compliance)
- D6: 5/15 (moderate docs, dual stakeholders)
- D7: 2/10 (continuous with disturbances, single location)

**Total**: 58/100 (🟠 HIGH COMPLEXITY)

**AND Test applied to Analyzers**:
- "Analyse separation thermodynamics AND calculate market price economics" → FAILS AND Test → MUST split
- Result: 2 Analyzers (Separation Analyst + Economic Analyst)

**Mandatory Separations check**:
- Guardian independent from Economic Analyst ✓
- Executor separate from Decision-Maker ✓
- Monitor has no write access ✓

**Step 4 Roles**:
- Monitor: 1
- Analyzer: 2 (process/separation + economic — AND Test requires split)
- Decision-Maker: 1
- Executor: 1
- Guardian: 1 (Q10 = 8, independent required)

**Final**: **6 AGENTS**
1. Process Monitor Agent
2. Separation Performance Analyst Agent
3. Economic Analyst Agent
4. Optimisation Decision-Maker Agent
5. Quality & Safety Guardian Agent
6. Control Executor Agent

---

### Example 2: Control Loop Advisor (Investigation Support)

**Step 1**: Investigation/Diagnosis, Human-in-loop ✓, Decision Support ✓

**Step 2 Scores**:
- D1: 1/15 (advisory only, low consequences)
- D2: 10/15 (50+ loops, complex, no actions)
- D3: 4/15 (hours-day, dual disciplines)
- D4: 9/15 (moderate expertise, extensive diagnosis)
- D5: 0/15 (no special validation, no regulatory)
- D6: 5/15 (moderate reporting, dual stakeholders)
- D7: 2/10 (continuous with disturbances, single location)

**Total**: 31/100 (🟡 MODERATE COMPLEXITY)

**AND Test**: "Monitor loop data AND diagnose performance issues" — same domain (process control), same data schema → MAY combine Monitor + Analyzer

**Final**: **2-3 AGENTS**
1. Data Monitor Agent (collects from 50+ loops)
2. Investigation Manager Agent (PCA analysis + prioritization + reporting)
*(Optional 3rd: Split Analyzer + Coordinator if reporting complex)*

---

### Example 3: VnV Aerospace (Coordination/Workflow)

**Step 1**: Coordination/Workflow, Multi-disciplinary ✓, Regulatory ✓

**Step 2 Scores**:
- D1: 5/15 (soft actions, moderate consequences)
- D2: 9/15 (many sources, complex, few actions)
- D3: 7/15 (days-weeks, 5+ disciplines)
- D4: 15/15 (expert multi-domain, extensive diagnosis)
- D5: 12/15 (separate validation, stringent aerospace)
- D6: 15/15 (extensive docs, many stakeholders)
- D7: 5/10 (event-driven, co-located units)

**Total**: 68/100 (🔴 VERY HIGH COMPLEXITY)

**AND Test applied**: Requirements analysis AND test results analysis → different data schemas, different expertise → MUST split

**Final**: **6-8 AGENTS**
1. Test Data Monitor Agent
2. Requirements Analyst Agent
3. Test Results Analyst Agent
4. Qualification Strategist Agent
5. Compliance Validator Agent (Guardian)
6. Program Coordinator Agent
7. Documentation Manager Agent
*(8th optional: Split Test Coordinator + Program Coordinator)*

---

### Example 4: Brewery Golden Batch (Quality Management)

**Step 1**: Quality Management, Human-in-loop ✓, Batch ✓

**Step 2 Scores**:
- D1: 8/15 (bounded autonomy, moderate consequences)
- D2: 6/15 (6-20 variables, moderate complexity, 3-5 actions)
- D3: 4/15 (hours-day, dual disciplines)
- D4: 8/15 (substantial brewing expertise, minimal diagnosis)
- D5: 4/15 (embedded validation, basic food safety)
- D6: 5/15 (moderate batch records, dual stakeholders)
- D7: 4/10 (batch/cyclic, single location)

**Total**: 39/100 (🟡 MODERATE COMPLEXITY)

**AND Test**: "Analyse batch performance AND compare to golden batch" — same domain (batch quality), same data schema → MAY combine Analyzer + Historian

**Final**: **4 AGENTS**
1. Fermentation Monitor Agent
2. Quality Analyst Agent (includes golden batch comparison — passes AND Test: single domain)
3. Process Optimizer Agent
4. Controller Agent

---

## General Guidelines

**2-3 Agents**: Advisory, Low Complexity
- Examples: Control Loop Advisor, Predictive Maintenance Advisory
- Characteristics: Human-in-loop, slow response, single-dual disciplines
- Typical: Monitor + Analyzer (+optional Coordinator)

**3-4 Agents**: Moderate Autonomous or Batch Quality
- Examples: Brewery Golden Batch, Simple Process Control
- Characteristics: Some autonomy, moderate complexity, dual disciplines
- Typical: Monitor + Analyzer + Optimizer + Controller

**4-5 Agents**: Safety-Critical Process Control
- Examples: Depropaniser (if analyzers combined), Reactor Control
- Characteristics: Full autonomy, safety-critical, multiple objectives
- Typical: Monitor + Analyst + Optimizer + Guardian + Controller

**5-6 Agents**: Complex Multi-Objective or Multi-Disciplinary
- Examples: Depropaniser (analyzers split), Multi-unit optimization
- Characteristics: Multiple objectives requiring separate analysis, several disciplines
- Typical: Monitor + Multiple Analysts + Optimizer + Guardian + Controller

**6-8+ Agents**: Highly Coordinated, Extensive Documentation
- Examples: VnV Aerospace, Supply Chain Coordination
- Characteristics: Many disciplines (5+), extensive documentation
- Typical: Monitor + Analysts + Strategist + Guardian + Coordinator + Artifact Manager + Executor

---

**Next**: [`prompt-06-agent-profile-definition.md`](./prompt-06-agent-profile-definition.md) (complete for EACH agent)

---

*Updated: 2026-02-22 — Added Mandatory Separations, AND Test, Single Expert Test, Data Domain Rule, domain-specific scoring calibrations for Q1/Q2/Q11, and hardened Rule 2 combination logic based on cross-LLM evaluation.*

---

**Next**: [`prompt-06-agent-profile-definition.md`](./prompt-06-agent-profile-definition.md) (complete for EACH agent)
