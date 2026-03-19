# Research Papers

XMPro research and technical papers on Multi-Agent Generative Systems. These papers provide the theoretical foundations, design frameworks, and practical guidance that underpin the MAGS architecture documented in this repository.

---

## Papers

### Neuroscience-Inspired Cognitive Architecture for Multi-Agent Systems
**Date**: September 2025 · [PDF](2025.9.9_Neuroscience-Inspired%20Cognitive%20Architecture%20for%20Multi-Agent%20Systems.pdf)

Explores how principles from neuroscience and cognitive science inform the design of the MAGS cognitive architecture — including memory encoding, reflection, and the observe-reflect-plan-act (ORPA) cycle. Provides the theoretical grounding for how MAGS agents store, retrieve, and reason from experience over time.

**Related docs**: [ORPA Cycle](../docs/concepts/orpa-cycle.md) · [Memory Systems](../docs/concepts/memory-systems.md) · [Cognitive Intelligence](../docs/cognitive-intelligence/README.md) · [Research Foundations: Cognitive Science](../docs/research-foundations/cognitive-science.md)

---

### Utility Functions for Industrial Multi-Agent Systems
**Date**: November 2025 · [PDF](Utility_Function_Paper_Nov25.pdf)

Covers the design and application of utility and objective functions in industrial MAGS deployments. Addresses how agents balance competing objectives — economic, operational, safety — through mathematical utility functions, and how constraints interact with utility to produce safe, value-maximising behaviour.

**Related docs**: [Objective Functions](../docs/concepts/objective-functions.md) · [Measures, Utilities and Objectives](../docs/concepts/measures-utilities-objectives.md) · [Constraints vs Utilities](../docs/concepts/constraints-vs-utilities.md) · [Objective Function Design](../docs/best-practices/objective-function-design.md)

---

### Senior Manager's Guide to MAGS
**Date**: October 2025 · [PDF](2025.10.22_Senior%20Managers%20Guide%20to%20MAGS.pdf)

A non-technical overview of MAGS for senior leaders and decision-makers. Covers what MAGS is, where it fits in an operational technology stack, how it compares to alternatives, and how organisations should think about adoption, governance, and value realisation.

**Related docs**: [Business FAQ](../docs/faq/business.md) · [Use Cases](../docs/use-cases/README.md) · [Adoption Guidance](../docs/adoption-guidance/README.md) · [When NOT to Use MAGS](../docs/decision-guides/when-not-to-use-mags.md)

---

### IP Protection for Industrial Agentic Systems
**Date**: February 2026 · [PDF](2026.02.02_IP_Protection_for_Industrial_Agentic_Systems.pdf)

Examines intellectual property considerations specific to industrial agentic systems — including how operational knowledge embedded in agent configurations, utility functions, and memory systems constitutes protectable IP, and what governance frameworks organisations should put in place.

**Related docs**: [Responsible AI Policies](../docs/responsible-ai/policies.md) · [Deontic Principles](../docs/concepts/deontic-principles.md) · [Regulatory Compliance and Audit Trail](../docs/responsible-ai/regulatory-compliance-audit-trail.md)

---

### The 3-Layer Industrial World Model Stack
**Date**: March 2026 · [PDF](2026.03.19_Three_Layer_World_Model_for_Industrial_Operations.pdf)

Proposes a three-layer world model stack required for industrial autonomy. AI labs (AMI Labs, Meta V-JEPA 2, World Labs) are building the Physical Dynamics layer that predicts how materials and equipment behave under control actions — but industrial autonomy requires two additional layers: an Operational KPI Dynamics layer that translates physical state changes into production value metrics (throughput, grade, recovery, energy), and a Socio-Technical Dynamics layer that evaluates whether a proposed strategy is acceptable given safety constraints, alarm behaviour, maintenance risk, contractual obligations, and human workload. The paper formally specifies all three layers with clean API boundaries, defines the cognitive agent requirements for reasoning over the prediction stack using the observe–reflect–plan–act cycle, and introduces operator co-evolution as a mechanism for continuous constraint learning from operational feedback. Includes end-to-end demonstrations on a copper grinding-flotation circuit and an upstream oil and gas separation train, a progressive autonomy framework with formal gate criteria for each phase transition (shadow, advisory, bounded autonomous, collaborative autonomous), and alignment with LeCun's AMI architecture through a vendor-agnostic world model provider interface.

**Related docs**: [ORPA Cycle](../docs/concepts/orpa-cycle.md) · [Planning Approaches](../docs/concepts/planning-approaches.md) · [Objective Functions](../docs/concepts/objective-functions.md) · [Constraints vs Utilities](../docs/concepts/constraints-vs-utilities.md) · [Human-in-the-Loop](../docs/responsible-ai/human-in-the-loop.md) · [Deontic Principles](../docs/concepts/deontic-principles.md)

---

*For academic research foundations that inform the MAGS architecture, see [docs/research-foundations/](../docs/research-foundations/README.md).*
