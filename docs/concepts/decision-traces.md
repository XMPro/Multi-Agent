# Decision Traces

**Category**: Core Concepts  
**Related**: ORPA Cycle, Memory Systems, AO Platform Integration

---

## Overview

**Decision traces** are complete records of decisions with full context, reasoning, precedents, and outcomes—captured automatically as MAGS agents execute their ORPA cycles.

**Key Distinction:**
- **Memory**: What the agent observed, reflected on, planned
- **Decision Trace**: Why the decision was allowed to happen, with complete provenance

**Purpose:** Turn operational precedent into queryable organizational knowledge.

---

## What is a Decision Trace?

A decision trace captures:

**WHO:**
- Which agent made the decision
- Who approved it (if human-in-the-loop)
- Who was involved

**WHAT:**
- What the goal was
- What decision was made
- What equipment/process it applied to

**WHEN:**
- When the decision was made
- When it was executed
- When the outcome was validated

**WHY:**
- What observations triggered it
- What reasoning led to it
- What precedents informed it
- What policy was evaluated
- What exceptions were granted

**HOW:**
- What pattern was followed
- What confidence level
- What method was used

**OUTCOME:**
- What resulted
- Whether it succeeded or failed
- What was learned

---

## Decision Traces vs. Memory

### Memory (MAGS Internal)

**Purpose:** Agent's working knowledge
- Observations: What the agent perceived
- Reflections: What the agent thought about
- Plans: What the agent intended to do
- Actions: What the agent did

**Storage:** Neo4j (graph), Qdrant/Milvus (vector), TimescaleDB (timeseries)

**Scope:** Agent-specific, supports agent reasoning

### Decision Traces (DecisionGraph)

**Purpose:** Organizational knowledge
- Complete decision provenance (PROV-O)
- Precedent relationships
- Learned patterns
- Outcome validation

**Storage:** AO Platform triple-store (RDF/OWL)

**Scope:** Organization-wide, supports precedent search and pattern discovery

### Relationship

```
MAGS Agent Memory → Feeds → Decision Traces → Stored in → AO Platform DecisionGraph
```

**Example:**
1. Agent observes vibration (Memory: Observation)
2. Agent reflects on pattern (Memory: Reflection)
3. Agent plans maintenance (Memory: Plan)
4. Agent makes decision (Decision Trace: Complete provenance)
5. Decision stored in DecisionGraph with standards (ISO 14224) and precedents
6. Future agents query DecisionGraph for precedents

---

## How ORPA Cycle Creates Decision Traces

### Observe Phase

**Agent Action:**
- Accesses vibration sensor data
- Creates observation memory

**Decision Trace Capture:**
- Records which entities accessed
- Links observation to decision
- Captures trigger context

### Reflect Phase

**Agent Action:**
- Analyzes vibration pattern
- Retrieves historical data
- Creates reflection memory

**Decision Trace Capture:**
- Records which entities accessed (bearing history, similar failures)
- Captures agent insight
- Links reflection to decision

### Plan Phase

**Agent Action:**
- Searches for precedents
- Evaluates maintenance policy
- Creates maintenance plan

**Decision Trace Capture:**
- Records precedents reviewed
- Captures policy evaluation
- Records exception handling (if any)
- Links plan to decision

### Act Phase

**Agent Action:**
- Executes or recommends action
- Updates equipment status

**Decision Trace Capture:**
- Records complete decision with PROV-O provenance
- Captures approval chain (if human-in-the-loop)
- Links to generated plan
- Stores in AO Platform DecisionGraph

### Outcome Phase (Later)

**System Action:**
- Observes outcome
- Validates decision success/failure

**Decision Trace Update:**
- Updates decision with outcome
- Links to outcome evidence
- Triggers pattern discovery

---

## DecisionGraph: Where Decision Traces Live

The **DecisionGraph** is part of the XMPro AO Platform—a hybrid ontology system that stores and analyzes decision traces.

**Components:**

**1. Standards Layer**
- ISO 14224 (equipment ontology)
- IDO (industrial operations)
- ISA-95 (manufacturing)

**2. Decision Traces**
- Complete PROV-O provenance
- Precedent relationships
- Outcome tracking

**3. Learned Patterns**
- Patterns discovered from agent trajectories
- Validated against standards
- Continuous improvement

**4. Query Interface**
- Precedent search
- Pattern discovery
- Decision simulation
- Audit trails

**Integration:**
- MAGS agents create decision traces
- AO Platform stores and analyzes them
- Agents query DecisionGraph for precedents
- Patterns improve agent decisions

---

## Benefits for MAGS Agents

### 1. Precedent-Based Decision-Making

**Before Decision Traces:**
- Agent makes decision based on current context only
- No access to similar past decisions
- Reinvents solutions

**With Decision Traces:**
- Agent queries precedents before deciding
- Sees what worked in similar situations
- Learns from organizational experience

### 2. Continuous Learning

**Pattern Discovery:**
- System analyzes agent trajectories
- Discovers typical decision flows
- Identifies success patterns
- Validates against standards (ISO 14224)

**Agents Benefit:**
- Use learned patterns for better decisions
- Higher success rates over time
- Organizational knowledge compounds

### 3. Trust Through Transparency

**Explainability:**
- Every decision has complete provenance
- Operators can query "why was this allowed?"
- Complete audit trail for compliance

**Human Confidence:**
- Operators trust agents more
- Can validate reasoning
- Can override if needed

### 4. Multi-Agent Coordination

**Consensus Decisions:**
- Complete provenance of multi-agent decisions
- Each agent's contribution captured
- Conflict resolution documented

**Benefits:**
- Learn coordination patterns
- Improve consensus over time
- Transparent collaboration

---

## Example: Bearing Maintenance Decision

**MAGS Agent (Observe-Reflect-Plan-Act):**
1. Observes: Vibration at 6.8 mm/s
2. Reflects: "Rapid increase rate indicates failure"
3. Plans: "Recommend early maintenance"
4. Acts: Requests supervisor approval

**Decision Trace (Captured in DecisionGraph):**
```turtle
:Decision-123 a dt:DecisionTrace ;
    # WHO
    prov:wasAttributedTo :Agent-MAINT-001 ;
    dt:approvedBy :Supervisor-Jane ;
    
    # WHAT
    dt:goal "Prevent bearing failure" ;
    dt:appliesTo iso14224:RotatingEquipment ;
    
    # WHY
    prov:used :Observation-456 ;  # Vibration reading
    dt:precedents :Decision-089 ;  # Similar past decision
    dt:reasoning "Rapid increase rate" ;
    
    # HOW
    dt:followedPattern :BearingMaintenancePattern ;
    dt:confidence 0.85 ;
    
    # OUTCOME
    dt:outcome "Success" .
```

**Future Agent Benefits:**
- Queries DecisionGraph for similar situations
- Finds Decision-123 as precedent
- Sees it was successful
- Makes better-informed decision

---

## Integration with AO Platform

**MAGS Role:**
- Execute ORPA cycles
- Make decisions
- Create decision traces

**AO Platform Role:**
- Store decision traces (RDF triple-store)
- Provide standards (ISO 14224, IDO)
- Enable precedent search
- Discover patterns
- Support simulation

**Together:**
- MAGS provides agent intelligence
- DecisionGraph provides organizational intelligence
- Hybrid ontology (standards + learned)

---

## Strategic Importance

**Market Opportunity:**
Jaya Gupta (Foundation Capital) identifies "context graphs" as the next trillion-dollar platform opportunity—systems of record for decisions, not just data.

**MAGS Position:**
- MAGS agents create decision traces
- DecisionGraph stores and analyzes them
- Hybrid ontology (standards + learned)
- Unique competitive position

**Key Insight:**
> "The next $50B company will be built on learned ontologies. Structure that emerges from how work actually happens, not how you designed it to happen." - Jaya Gupta

MAGS agents discover this structure through their ORPA cycles. The DecisionGraph captures and makes it queryable.

---

## Related Concepts

- **[ORPA Cycle](orpa-cycle.md)** - How agents create decision traces
- **[Memory Systems](memory-systems.md)** - Relationship to agent memory
- **[Consensus Mechanisms](consensus-mechanisms.md)** - Multi-agent decision traces
- **[Decision-Making](decision-making.md)** - How agents make decisions

---

## Related Documentation

**AO Platform DecisionGraph:**
- [DecisionGraph Architecture](../../../xmpro-ao-platform/docs/design/24-DecisionGraph-Architecture.md)
- [Decision Traces Provenance](../../../xmpro-ao-platform/docs/design/25-Decision-Traces-Provenance.md)
- [Examples](../../../xmpro-ao-platform/examples/decision-traces/)

**ObsidianFiles (Team Documentation):**
- [Executive Summary](../../../ObsidianFiles/01-Executive-Summary.md)
- [Technical Architecture](../../../ObsidianFiles/02-Technical-Architecture.md)
- [FAQ](../../../ObsidianFiles/07-FAQ.md)

---

*Decision traces transform MAGS from an agent framework into a decision intelligence platform—capturing organizational knowledge that compounds over time.*
