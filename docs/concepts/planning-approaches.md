# Planning Approaches: PDDL and Beyond

## Overview

Planning in MAGS uses established automated planning research, particularly PDDL (Planning Domain Definition Language), to generate optimal action sequences. Unlike LLM-based planning that generates text descriptions of plans, MAGS uses formal planning languages with mathematical guarantees.

### The Core Principle

**Plans Are Formal Specifications, Not Text**

Traditional frameworks: LLM generates plan as text
MAGS: PDDL planner generates formal plan, LLM explains it

---

## Theoretical Foundations

### STRIPS (Fikes & Nilsson, 1971)
- State-space planning
- Preconditions and effects
- Goal-directed reasoning

### PDDL (McDermott et al., 1998)
- Standardized planning language
- Domain and problem definitions
- Numeric fluents for quantitative planning

### HTN Planning (Erol, Hendler, Nau, 1994)
- Hierarchical task decomposition
- Method selection
- Constraint satisfaction

### Partial-Order Planning (Sacerdoti, 1975)
- Flexible task ordering
- Least-commitment strategy
- Parallel execution

---

## Planning Components

### Domain Definition
- Types (equipment, actions, resources)
- Predicates (states, conditions)
- Actions (preconditions, effects)

### Problem Definition
- Objects (specific instances)
- Initial state
- Goal state

### Plan Solution
- Action sequence
- Resource allocation
- Timing constraints

---

## Planning Strategies

### Forward Planning
- Start from current state
- Apply actions
- Reach goal state

### Backward Planning
- Start from goal
- Work backward
- Find initial state

### Hierarchical Planning
- Decompose complex goals
- Plan at multiple levels
- Coordinate subtasks

---

## Related Documentation

- [Plan Optimization](../performance-optimization/plan-optimization.md)
- [Plan Adaptation](../cognitive-intelligence/plan-adaptation.md)
- [PDDL Details](pddl.md)
- [ORPA Cycle](orpa-cycle.md)

---

## References

- Fikes, R. E., & Nilsson, N. J. (1971). "STRIPS"
- McDermott, D., et al. (1998). "PDDL"
- Erol, K., Hendler, J., & Nau, D. S. (1994). "HTN planning"
- Sacerdoti, E. D. (1975). "NOAH planner"

---

**Document Version**: 1.0  
**Last Updated**: December 5, 2024  
**Status**: ✅ Complete