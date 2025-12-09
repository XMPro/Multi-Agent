# Planning Domain Definition Language (PDDL): Formal Planning in MAGS

## Overview

Planning Domain Definition Language (PDDL) is the standardized language for describing automated planning problems in artificial intelligence. Developed in 1998 by Drew McDermott and colleagues, PDDL has become the universal standard for AI planning research and applications, enabling formal specification of planning domains, problems, and solutions.

In XMPro MAGS, PDDL provides the formal foundation for goal-directed reasoning, action sequencing, and constraint-aware planning. Unlike LLM-generated action lists or simple scripts, PDDL enables provably correct plans with formal semantics, constraint satisfaction, and optimization guarantees—grounded in 50+ years of automated planning research.

### Why PDDL Matters for MAGS

**The Challenge**: Industrial operations require complex action sequences that must respect numerous constraints, optimize multiple objectives, and adapt to changing conditions. Manual planning is slow and error-prone; simple scripts are inflexible; LLM suggestions lack formal guarantees.

**The Solution**: PDDL provides standardized, formal language for expressing planning problems with provable correctness, constraint satisfaction, and optimization capabilities.

**The Result**: MAGS agents that generate optimal plans automatically, respect all constraints, provide formal validation, and explain their reasoning—capabilities that distinguish true planning intelligence from simple action generation.

### Key Business Drivers

1. **Formal Correctness**: Plans provably achieve goals while satisfying all constraints
2. **Standardization**: Universal language enables tool interoperability and knowledge sharing
3. **Expressiveness**: Capable of representing complex real-world industrial scenarios
4. **Optimization**: Generates optimal plans balancing multiple objectives
5. **Explainability**: Human-readable plans with clear action sequences and rationale

---

## Theoretical Foundations

### STRIPS: The Foundation (Fikes & Nilsson, 1971)

**Richard Fikes & Nils Nilsson** - "STRIPS: A New Approach to the Application of Theorem Proving to Problem Solving"

**Core Insight**: Planning can be formalized as state-space search with explicit preconditions and effects. Actions transform states, and planning finds sequences that reach goal states.

**Key Concepts**:
- **State**: Set of propositions describing world
- **Action**: Operation with preconditions and effects
- **Preconditions**: What must be true to execute action
- **Effects**: How action changes state (add/delete lists)
- **Plan**: Sequence of actions transforming initial state to goal state

**PDDL Connection**: PDDL is the modern, standardized evolution of STRIPS, adding expressiveness while maintaining the core state-action-goal model.

**Example**:
```
STRIPS-Style Maintenance Planning:
  
  Initial State:
    (equipment-operating pump-p101)
    (spare-parts-available bearing-b45)
    (technician-available john)
    (production-running line-3)
  
  Goal State:
    (equipment-maintained pump-p101)
    (production-running line-3)
  
  Actions:
    stop-equipment(pump-p101)
      Preconditions: (equipment-operating pump-p101)
      Effects: 
        Add: (equipment-stopped pump-p101)
        Delete: (equipment-operating pump-p101), (production-running line-3)
    
    replace-bearing(pump-p101, bearing-b45, john)
      Preconditions: (equipment-stopped pump-p101), 
                     (spare-parts-available bearing-b45),
                     (technician-available john)
      Effects:
        Add: (bearing-replaced pump-p101)
        Delete: (spare-parts-available bearing-b45)
    
    start-equipment(pump-p101)
      Preconditions: (bearing-replaced pump-p101)
      Effects:
        Add: (equipment-operating pump-p101), 
             (equipment-maintained pump-p101),
             (production-running line-3)
        Delete: (equipment-stopped pump-p101)
  
  Plan: [stop-equipment, replace-bearing, start-equipment]
  
  STRIPS principle: Formal, verifiable planning
```

---

### PDDL Standardization (McDermott et al., 1998)

**Drew McDermott et al.** - "PDDL—The Planning Domain Definition Language"

**Core Insight**: Standardized language for planning problems enables tool interoperability, benchmarking, and knowledge sharing. PDDL became the universal standard for AI planning.

**Key Components**:

**Domain Definition**:
- Types: Object categories
- Predicates: State properties
- Functions: Numeric values
- Actions: Available operations
- Reusable across problems

**Problem Definition**:
- Objects: Specific instances
- Initial state: Starting conditions
- Goal: Desired conditions
- Problem-specific

**Why This Matters**:
- Universal standard
- Tool interoperability
- Formal semantics
- Expressive power
- Research foundation

**MAGS Application**:
- Formal plan representation
- Standardized planning language
- Tool integration
- Plan validation
- Knowledge reuse

---

### PDDL Evolution

**PDDL 1.2 (1998)**: Original version
- Basic STRIPS-style planning
- Predicate logic
- Simple actions
- Foundation established

**PDDL 2.1 (2002)**: Temporal and numeric
- Durative actions (time-extended)
- Numeric fluents (quantities)
- Continuous change
- Resource reasoning

**PDDL 2.2 (2004)**: Derived predicates
- Derived predicates (computed)
- Timed initial literals
- Enhanced expressiveness

**PDDL 3.0 (2004)**: Preferences and constraints
- Trajectory constraints
- Preferences (soft constraints)
- Plan quality metrics
- Optimization support

**PDDL+ (2015)**: Hybrid planning
- Mixed discrete-continuous
- Processes and events
- Physical systems
- Advanced modeling

---

## PDDL Core Components

### Domain Definition

**Purpose**: Define general rules and actions for a planning domain

**Structure**:
```pddl
(define (domain domain-name)
  (:requirements :strips :typing :fluents)
  (:types type1 type2 - parent-type)
  (:predicates 
    (predicate1 ?param - type)
    (predicate2 ?p1 - type1 ?p2 - type2))
  (:functions
    (function1 ?param - type) - number)
  (:action action-name
    :parameters (?p1 - type1 ?p2 - type2)
    :precondition (and ...)
    :effect (and ...))
)
```

**Components**:

**Requirements**: Specify PDDL features used
- `:strips` - Basic STRIPS planning
- `:typing` - Typed objects
- `:fluents` - Numeric functions
- `:durative-actions` - Time-extended actions
- `:negative-preconditions` - Negation in preconditions

**Types**: Object categories
- Hierarchical type system
- Inheritance supported
- Type checking

**Predicates**: Boolean state properties
- Define what can be true/false
- Parameterized by objects
- State representation

**Functions**: Numeric values
- Quantities and measurements
- Resource levels
- Costs and durations

**Actions**: Available operations
- Parameters (what objects involved)
- Preconditions (when applicable)
- Effects (what changes)

---

### Problem Definition

**Purpose**: Specify a particular planning instance

**Structure**:
```pddl
(define (problem problem-name)
  (:domain domain-name)
  (:objects
    obj1 obj2 - type1
    obj3 - type2)
  (:init
    (predicate1 obj1)
    (= (function1 obj1) 10))
  (:goal
    (and (predicate2 obj1 obj2)
         (> (function1 obj1) 5)))
)
```

**Components**:

**Domain**: Reference to domain definition

**Objects**: Specific instances
- Concrete objects for this problem
- Typed according to domain

**Initial State**: Starting conditions
- Predicates that are true
- Function values
- Complete state specification

**Goal**: Desired conditions
- Predicates that should be true
- Function constraints
- Partial state specification

---

## PDDL in MAGS: Industrial Applications

### Application 1: Predictive Maintenance Planning

**Domain**: Equipment maintenance operations

**PDDL Domain (Conceptual)**:
```pddl
(define (domain maintenance)
  (:requirements :strips :typing :fluents :durative-actions)
  
  (:types 
    equipment component technician tool - object
    maintenance-type - object)
  
  (:predicates
    (equipment-operational ?e - equipment)
    (equipment-stopped ?e - equipment)
    (component-failed ?c - component)
    (component-of ?c - component ?e - equipment)
    (technician-available ?t - technician)
    (has-skill ?t - technician ?skill)
    (tool-available ?tool - tool)
    (maintenance-complete ?e - equipment))
  
  (:functions
    (equipment-health ?e - equipment) - number
    (maintenance-duration ?e - equipment ?m - maintenance-type) - number
    (downtime-cost) - number)
  
  (:durative-action perform-maintenance
    :parameters (?e - equipment ?t - technician ?m - maintenance-type)
    :duration (= ?duration (maintenance-duration ?e ?m))
    :condition (and
      (at start (equipment-stopped ?e))
      (at start (technician-available ?t))
      (at start (has-skill ?t bearing-replacement))
      (over all (not (equipment-operational ?e))))
    :effect (and
      (at start (not (technician-available ?t)))
      (at end (technician-available ?t))
      (at end (maintenance-complete ?e))
      (at end (increase (equipment-health ?e) 50))))
)
```

**Problem Instance**:
```pddl
(define (problem pump-maintenance)
  (:domain maintenance)
  
  (:objects
    pump-p101 - equipment
    bearing-b45 - component
    john - technician
    wrench - tool
    preventive - maintenance-type)
  
  (:init
    (equipment-operational pump-p101)
    (component-of bearing-b45 pump-p101)
    (technician-available john)
    (has-skill john bearing-replacement)
    (tool-available wrench)
    (= (equipment-health pump-p101) 65)
    (= (maintenance-duration pump-p101 preventive) 4))
  
  (:goal
    (and (maintenance-complete pump-p101)
         (> (equipment-health pump-p101) 90)))
)
```

**Generated Plan**:
```
1. stop-equipment(pump-p101)
2. perform-maintenance(pump-p101, john, preventive) [duration: 4 hours]
3. test-equipment(pump-p101)
4. start-equipment(pump-p101)

Total duration: 4.5 hours
Downtime cost: $18,000
Equipment health: 65 → 115 (capped at 100)
Goal achieved: ✓
```

---

### Application 2: Process Optimization Planning

**Domain**: Production process optimization

**PDDL Domain (Conceptual)**:
```pddl
(define (domain process-optimization)
  (:requirements :strips :typing :fluents)
  
  (:types
    process-line parameter - object
    adjustment-type - object)
  
  (:predicates
    (line-running ?l - process-line)
    (parameter-optimal ?p - parameter)
    (adjustment-applied ?a - adjustment-type ?p - parameter))
  
  (:functions
    (throughput ?l - process-line) - number
    (quality ?l - process-line) - number
    (energy-consumption ?l - process-line) - number
    (parameter-value ?p - parameter) - number
    (target-throughput) - number
    (target-quality) - number)
  
  (:action adjust-temperature
    :parameters (?l - process-line ?p - parameter)
    :precondition (and
      (line-running ?l)
      (not (parameter-optimal ?p)))
    :effect (and
      (parameter-optimal ?p)
      (increase (throughput ?l) 5)
      (decrease (quality ?l) 1)
      (increase (energy-consumption ?l) 3)))
  
  (:action adjust-flow-rate
    :parameters (?l - process-line ?p - parameter)
    :precondition (and
      (line-running ?l)
      (not (parameter-optimal ?p)))
    :effect (and
      (parameter-optimal ?p)
      (increase (throughput ?l) 3)
      (increase (quality ?l) 2)
      (increase (energy-consumption ?l) 2)))
)
```

**Problem Instance**:
```pddl
(define (problem optimize-line-3)
  (:domain process-optimization)
  
  (:objects
    line-3 - process-line
    temperature flow-rate - parameter
    temp-adjust flow-adjust - adjustment-type)
  
  (:init
    (line-running line-3)
    (= (throughput line-3) 85)
    (= (quality line-3) 96)
    (= (energy-consumption line-3) 100)
    (= (target-throughput) 95)
    (= (target-quality) 95))
  
  (:goal
    (and (>= (throughput line-3) (target-throughput))
         (>= (quality line-3) (target-quality))))
)
```

**Generated Plan**:
```
1. adjust-flow-rate(line-3, flow-rate)
   Result: Throughput 85→88, Quality 96→98, Energy 100→102

2. adjust-temperature(line-3, temperature)
   Result: Throughput 88→93, Quality 98→97, Energy 102→105

3. adjust-flow-rate(line-3, flow-rate) [second adjustment]
   Result: Throughput 93→96, Quality 97→99, Energy 105→107

Goal achieved: Throughput 96 ≥ 95 ✓, Quality 99 ≥ 95 ✓
Energy increase: 7% (acceptable)
```

---

### Application 3: Quality Management Planning

**Domain**: Quality deviation response

**PDDL Domain (Conceptual)**:
```pddl
(define (domain quality-management)
  (:requirements :strips :typing :fluents)
  
  (:types
    production-line measurement action-type - object)
  
  (:predicates
    (deviation-detected ?l - production-line ?m - measurement)
    (root-cause-identified ?l - production-line)
    (corrective-action-applied ?a - action-type)
    (quality-restored ?l - production-line))
  
  (:functions
    (quality-level ?l - production-line) - number
    (target-quality) - number
    (action-duration ?a - action-type) - number)
  
  (:action investigate-deviation
    :parameters (?l - production-line ?m - measurement)
    :precondition (deviation-detected ?l ?m)
    :effect (root-cause-identified ?l))
  
  (:action apply-correction
    :parameters (?l - production-line ?a - action-type)
    :precondition (root-cause-identified ?l)
    :effect (and
      (corrective-action-applied ?a)
      (increase (quality-level ?l) 5)))
  
  (:action verify-quality
    :parameters (?l - production-line)
    :precondition (corrective-action-applied ?a)
    :effect (when (>= (quality-level ?l) (target-quality))
                  (quality-restored ?l)))
)
```

---

## MAGS Extensions to PDDL

### Extension 1: Real-Time Adaptive Actions

**Concept**: Actions that adapt based on real-time data

**MAGS Extension**:
```pddl
(:xmpro-mags-adaptive-action monitor-equipment
  :parameters (?e - equipment)
  :precondition (equipment-operational ?e)
  :effect (and
    (forall (?c - component)
      (when (and (component-of ?c ?e)
                 (> (sensor-reading ?c) (threshold ?c)))
        (decrease (equipment-health ?e) 1))))
  :xmpro-mags-real-time-condition (< (equipment-health ?e) 80))
```

**Benefits**:
- Real-time data integration
- Dynamic condition evaluation
- Adaptive behavior
- Continuous monitoring

---

### Extension 2: Multi-Agent Coordination

**Concept**: Actions requiring coordination among multiple agents

**MAGS Extension**:
```pddl
(:xmpro-mags-coordinated-action consensus-decision
  :parameters (?decision - decision-type)
  :agents (?a1 ?a2 ?a3 - agent)
  :precondition (and
    (agent-available ?a1)
    (agent-available ?a2)
    (agent-available ?a3))
  :consensus-threshold 0.75
  :effect (when (consensus-achieved ?decision)
                (decision-approved ?decision)))
```

**Benefits**:
- Multi-agent coordination
- Consensus requirements
- Distributed decision-making
- Team collaboration

---

### Extension 3: Probabilistic Outcomes

**Concept**: Actions with uncertain outcomes

**MAGS Extension**:
```pddl
(:xmpro-mags-probabilistic-action repair-component
  :parameters (?c - component)
  :precondition (component-failed ?c)
  :probabilistic-effects
    (0.85 (component-operational ?c))
    (0.15 (component-needs-replacement ?c)))
```

**Benefits**:
- Uncertainty modeling
- Risk assessment
- Contingency planning
- Robust plans

---

## Design Patterns for PDDL Planning

### Pattern 1: Hierarchical Task Decomposition

**Concept**: Break complex tasks into manageable subtasks

**Approach**:
1. Define high-level abstract tasks
2. Create decomposition methods
3. Specify primitive actions
4. Plan at appropriate abstraction level

**Example**:
```
High-Level Task: "Optimize plant performance"
  
Decomposition:
  Level 1: Optimize plant
    → Optimize Line 1
    → Optimize Line 2
    → Optimize Line 3
  
  Level 2: Optimize Line 1
    → Optimize throughput
    → Optimize quality
    → Optimize energy
  
  Level 3: Optimize throughput
    → Adjust feed rate
    → Tune temperature
    → Optimize cooling
  
HTN principle: Manageable complexity through hierarchy
```

---

### Pattern 2: Constraint-Aware Planning

**Concept**: Generate plans that satisfy all constraints

**Approach**:
1. Identify all constraints (resource, temporal, state)
2. Encode constraints in PDDL
3. Use constraint-aware planner
4. Validate plan feasibility

**Example**:
```pddl
(:constraints
  ;; Resource constraints
  (forall (?t - technician)
    (at most 1 (maintenance-in-progress ?t)))
  
  ;; Temporal constraints
  (always (< (total-downtime) 8))
  
  ;; State constraints
  (always (>= (safety-level) 95)))
```

---

### Pattern 3: Multi-Objective Optimization

**Concept**: Balance multiple competing objectives

**Approach**:
1. Define multiple objective functions
2. Specify weights or priorities
3. Generate Pareto-optimal plans
4. Select based on trade-offs

**Example**:
```pddl
(:metric minimize
  (+ (* 0.4 (total-cost))
     (* 0.3 (total-downtime))
     (* 0.3 (- 100 (quality-level)))))
```

---

### Pattern 4: Contingency Planning

**Concept**: Plan for multiple scenarios

**Approach**:
1. Identify potential failures
2. Generate contingency branches
3. Specify trigger conditions
4. Enable adaptive execution

**Example**:
```
Primary Plan: Scheduled maintenance
  If (equipment-fails-before-schedule)
    → Contingency: Emergency maintenance
  If (parts-unavailable)
    → Contingency: Temporary repair + reschedule
```

---

## PDDL vs. Alternative Approaches

### PDDL-Based Planning (MAGS Approach)

**Characteristics**:
- Formal specification
- Provable correctness
- Constraint satisfaction
- Optimization support
- Tool interoperability

**Advantages**:
- Guaranteed correctness
- Formal validation
- Consistent quality
- Explainable plans
- 50+ years of research

**Use Cases**:
- Complex industrial planning
- Safety-critical operations
- Regulatory compliance
- Multi-constraint optimization

---

### LLM-Based Planning

**Characteristics**:
- Text generation
- No formal semantics
- Probabilistic output
- Inconsistent quality

**Limitations**:
- No correctness guarantee
- May violate constraints
- Inconsistent across problems
- Cannot prove optimality
- No formal validation

**Use Cases**:
- Simple suggestions
- Brainstorming
- Natural language interaction
- Non-critical planning

---

### Script-Based Planning

**Characteristics**:
- Hardcoded sequences
- Fixed logic
- Fast execution
- Limited flexibility

**Limitations**:
- Inflexible
- Difficult to modify
- No optimization
- Poor adaptability
- Domain-specific

**Use Cases**:
- Simple, repetitive tasks
- Well-defined procedures
- No variation needed
- Performance-critical

---

## Measuring Success

### Planning Quality Metrics

```
Plan Correctness:
  Target: 100% of plans achieve goals
  Measurement: Goal achievement rate
  Validation: Formal verification

Constraint Satisfaction:
  Target: 100% of constraints satisfied
  Measurement: Constraint violation rate
  Validation: Constraint checking

Plan Optimality:
  Target: >90% of plans Pareto-optimal
  Measurement: Optimality gap
  Validation: Comparison to optimal
```

### Planning Performance Metrics

```
Planning Time:
  Target: <5 seconds for routine problems
  Target: <60 seconds for complex problems
  Measurement: Time to generate plan

Plan Quality:
  Target: >85% stakeholder satisfaction
  Measurement: Plan acceptance rate
  Tracking: Feedback and outcomes

Adaptability:
  Target: >90% of plans executable despite changes
  Measurement: Plan robustness
  Tracking: Execution success rate
```

---

## Related Documentation

### Core Concepts
- [Decision Making](decision-making.md) - Using plans for decisions
- [Planning Approaches](planning-approaches.md) - Planning methods
- [ORPA Cycle](orpa-cycle.md) - Planning in cognitive cycle

### Research Foundations
- [Automated Planning](../research-foundations/automated-planning.md) - 50+ years of planning research
- [Decision Theory](../research-foundations/decision-theory.md) - Goal selection

### Performance Optimization
- [Plan Optimization](../performance-optimization/plan-optimization.md) - Plan generation and optimization
- [Goal Optimization](../performance-optimization/goal-optimization.md) - Objective functions

### Integration & Execution
- [Tool Orchestration](../integration-execution/tool-orchestration.md) - Plan execution

### Use Cases
- [Predictive Maintenance](../use-cases/predictive-maintenance.md) - Maintenance planning
- [Process Optimization](../use-cases/process-optimization.md) - Process planning
- [Quality Management](../use-cases/quality-management.md) - Corrective action planning

---

## References

### Foundational Works

**STRIPS and Classical Planning**:
- Fikes, R. E., & Nilsson, N. J. (1971). "STRIPS: A New Approach to the Application of Theorem Proving to Problem Solving". Artificial Intelligence, 2(3-4), 189-208
- Newell, A., & Simon, H. A. (1972). "Human Problem Solving". Prentice-Hall

**PDDL**:
- McDermott, D., et al. (1998). "PDDL—The Planning Domain Definition Language". Technical Report CVC TR-98-003, Yale Center for Computational Vision and Control
- Fox, M., & Long, D. (2003). "PDDL2.1: An Extension to PDDL for Expressing Temporal Planning Domains". Journal of Artificial Intelligence Research, 20, 61-124
- Gerevini, A., & Long, D. (2005). "Plan Constraints and Preferences in PDDL3". Technical Report, Department of Electronics for Automation, University of Brescia

**Hierarchical Planning**:
- Erol, K., Hendler, J., & Nau, D. S. (1994). "HTN Planning: Complexity and Expressivity". In Proceedings of AAAI-94, 1123-1128
- Nau, D., et al. (2003). "SHOP2: An HTN Planning System". Journal of Artificial Intelligence Research, 20, 379-404

### Modern Applications

**Planning and Scheduling**:
- Ghallab, M., Nau, D., & Traverso, P. (2004). "Automated Planning: Theory and Practice". Morgan Kaufmann
- Russell, S., & Norvig, P. (2020). "Artificial Intelligence: A Modern Approach" (4th ed.). Pearson (Chapters 10-11)

**Industrial Applications**:
- Leitão, P., & Karnouskos, S. (Eds.). (2015). "Industrial Agents: Emerging Applications of Software Agents in Industry". Elsevier
- Monostori, L., et al. (2006). "Agent-based systems for manufacturing". CIRP Annals, 55(2), 697-720

**Planning Tools**:
- Helmert, M. (2006). "The Fast Downward Planning System". Journal of Artificial Intelligence Research, 26, 191-246
- Richter, S., & Westphal, M. (2010). "The LAMA Planner: Guiding Cost-Based Anytime Planning with Landmarks". Journal of Artificial Intelligence Research, 39, 127-177

---

**Document Version**: 2.0  
**Last Updated**: December 6, 2025  
**Status**: ✅ Enhanced to Comprehensive Quality Standard