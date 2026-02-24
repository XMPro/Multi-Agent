# Getting Started with XMPro MAGS

Welcome to XMPro Multi-Agent Generative Systems (MAGS)! This guide will help you understand what MAGS is, whether it's right for your use case, and how to get started.

## What is MAGS?

XMPro MAGS is an **intelligence platform** for industrial operations, not just an LLM wrapper. It combines:

- **~90% Business Process Intelligence**: Research-based capabilities for decision-making, planning, memory, and optimization
- **~10% LLM Utility Layer**: Natural language processing for communication and explanation

Think of MAGS as a team of specialized virtual workers that can observe operations, learn from experience, make decisions, and coordinate actions—continuously improving over time.

---

## Quick Start Paths

### Path 1: Business Stakeholder (15 minutes)

**Goal**: Understand what MAGS does and whether it fits your needs

1. [Why MAGS is Different](../architecture/two-layer-framework.md) (5 min)
   - Understand the intelligence platform framework
   - See how MAGS differs from LLM wrappers

2. [Evaluation Guide](evaluation-guide.md) (10 min)
   - Assess if MAGS fits your use case
   - GO/NO-GO decision framework

**Next**: If GO, proceed to Path 2

---

### Path 2: Technical Evaluator (45 minutes)

**Goal**: Understand how MAGS works and what it can do

1. [Understanding MAGS](understanding-mags.md) (15 min)
   - Core concepts in plain language
   - How agents think and work

2. [Agent Types](../concepts/agent_types.md) (10 min)
   - Content and Cognitive agents
   - When to use each type

3. [Use Cases](../use-cases/README.md) (10 min)
   - Predictive Maintenance
   - Process Optimization
   - Quality Management

4. [ORPA Cycle](../concepts/orpa-cycle.md) (10 min)
   - How agents observe, reflect, plan, and act
   - The cognitive cycle

**Next**: If interested, proceed to Path 3

---

### Path 3: Implementation Team (2-3 hours)

**Goal**: Deep technical understanding for implementation

1. [15 Business Process Capabilities](../architecture/business-process-intelligence.md) (30 min)
   - Cognitive Intelligence
   - Decision Orchestration
   - Performance Optimization
   - Integration & Execution

2. [Research Foundations](../research-foundations/README.md) (30 min)
   - Decision Theory
   - Cognitive Science
   - Multi-Agent Systems
   - Automated Planning

3. [Design Patterns](../design-patterns/README.md) (30 min)
   - Agent team patterns
   - Decision patterns
   - Communication patterns

4. [Best Practices](../best-practices/README.md) (30 min)
   - Agent design principles
   - Team composition
   - Objective function design

**Next**: Review [Installation Guide](../installation.md)

---

## By Role

### Business Decision Maker
**Focus**: Value and fit
- [Evaluation Guide](evaluation-guide.md) - Is MAGS right for you?
- [Use Cases](../use-cases/README.md) - Real-world applications
- [Two-Layer Framework](../architecture/two-layer-framework.md) - Why MAGS is different

### Solution Architect
**Focus**: Architecture and integration
- [System Architecture](../architecture/README.md) - Complete architecture
- [Integration & Execution](../integration-execution/README.md) - External interfaces
- [Data Architecture](../architecture/data-architecture.md) - Data management

### AI/ML Engineer
**Focus**: Capabilities and implementation
- [Research Foundations](../research-foundations/README.md) - Theoretical grounding
- [Cognitive Intelligence](../cognitive-intelligence/README.md) - Memory and learning
- [Performance Optimization](../performance-optimization/README.md) - Goals and optimization

### Operations Manager
**Focus**: Practical application
- [Use Cases](../use-cases/README.md) - Application scenarios
- [Agent Types](../concepts/agent_types.md) - What agents can do
- [Best Practices](../best-practices/README.md) - Implementation guidance

---

## Common Questions

### Is MAGS right for my use case?
Use the [Evaluation Prompt](evaluation-prompt.md) for an interactive LLM-based assessment, or the [Evaluation Guide](evaluation-guide.md) for a detailed written assessment. MAGS excels at operational/tactical decisions with 15+ minute cycles, measurable outcomes, and available data.

### How is MAGS different from other AI frameworks?
MAGS is ~90% business process intelligence (research-based decision-making, planning, memory) and only ~10% LLM utility. See [Two-Layer Framework](../architecture/two-layer-framework.md).

### What can MAGS agents do?
Agents can observe operations, learn patterns, make decisions, plan actions, and coordinate with other agents. See [Agent Types](../concepts/agent_types.md) and [ORPA Cycle](../concepts/orpa-cycle.md).

### How do I get started?
1. Complete the [Evaluation Guide](evaluation-guide.md)
2. If GO, read [Understanding MAGS](understanding-mags.md)
3. Review relevant [Use Cases](../use-cases/README.md)
4. Follow the [Installation Guide](../installation.md)

---

## Next Steps

After completing your chosen path:

**If Evaluating**:
- Try [Evaluation Prompt](evaluation-prompt.md) (interactive, recommended)
- Or complete [Evaluation Guide](evaluation-guide.md) (written)
- Review [Use Cases](../use-cases/README.md)
- Contact XMPro for consultation

**If Implementing**:
- Study [Design Patterns](../design-patterns/README.md)
- Review [Best Practices](../best-practices/README.md)
- Follow [Installation Guide](../installation.md)

**If Learning**:
- Explore [Research Foundations](../research-foundations/README.md)
- Read [Cognitive Intelligence](../cognitive-intelligence/README.md)
- Study [Decision Orchestration](../decision-orchestration/README.md)

---

## Documentation Structure

```
docs/
├── getting-started/          ← You are here
│   ├── README.md            (This file)
│   ├── evaluation-guide.md  (GO/NO-GO assessment)
│   ├── understanding-mags.md (Core concepts)
│   └── first-steps.md       (Role-based guidance)
│
├── architecture/            (System design)
├── concepts/                (Core ideas)
├── research-foundations/    (Academic grounding)
├── use-cases/              (Applications)
├── design-patterns/        (Proven approaches)
└── best-practices/         (Implementation guidance)
```

---

## Support

**Questions?** 
- Check the [FAQ](../faq/README.md)
- Review the [Glossary](../Glossary.md)
- Contact: support@xmpro.com

**Ready to Start?**
- [Evaluation Guide](evaluation-guide.md) - Assess fit
- [Understanding MAGS](understanding-mags.md) - Learn concepts
- [Installation Guide](../installation.md) - Deploy system

---

**Document Version**: 1.0  
**Last Updated**: December 6, 2025  
**Status**: ✅ Complete