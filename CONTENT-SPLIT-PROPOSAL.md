# MAGS Documentation Content Split — Approval Request

**Date:** 25 March 2026
**Author:** Pieter van Schalkwyk
**Status:** Pending Approval

---

## Background

The MAGS knowledge base currently lives in a single public GitHub repository. As the platform matures and we expand our customer and partner base, we need to separate general educational content from proprietary implementation and configuration guidance. This document proposes a content split and revised navigation structure for both the public repository and a new private documentation site.

---

## Proposed Structure

### Repository 1 — Public GitHub (Existing Repo, Retained)

**Purpose:** Thought leadership, developer mindshare, prospect education, community engagement.

**Audience:** Anyone — prospects, researchers, analysts, developers evaluating MAGS.

**Principle:** Everything here should reinforce that XMPro has been doing this for a while and has deep domain expertise. No platform configuration details, no customer onboarding specifics.

#### Content Retained (No Change Required)

| Section | Location | Rationale |
|---|---|---|
| Getting Started | `docs/getting-started/` | Helps prospects understand MAGS quickly |
| Core Concepts | `docs/concepts/` | Educational, vendor-neutral MAGS theory |
| Architecture | `docs/architecture/` | Framework-level design, not platform internals |
| Design Patterns | `docs/design-patterns/` | Generic agent team patterns |
| Best Practices | `docs/best-practices/` | Strategic guidance, not configuration |
| Use Cases | `docs/use-cases/` | Industry scenarios (no customer data) |
| Case Studies | `case-studies/` | Anonymised implementation examples |
| Decision Guides | `docs/decision-guides/` | When/why to use MAGS |
| Responsible AI | `docs/responsible-ai/` | General governance and policy guidance |
| Research Foundations | `docs/research-foundations/` | Academic references and basis |
| Research Papers | `research/` | XMPro IP — published to demonstrate depth |
| Strategic Positioning | `docs/strategic-positioning/` | Azure CAF alignment — supports enterprise sales |
| FAQ | `docs/faq/` | General Q&A |
| Glossary | `docs/Glossary.md` | Terminology reference |
| Framework Relationships | `docs/FRAMEWORK-RELATIONSHIPS.md` | Competitive/ecosystem positioning |

#### Content Removed from Public Repo (Moving to Private Site)

| Section | Location | Reason for Moving |
|---|---|---|
| Implementation Guides | `docs/implementation-guides/` | Platform-specific config (system prompts, memory, constraints, model selection) |
| Installation Guides | `docs/installation/` | XMPro Docker setup and deployment scripts |
| Integration & Execution | `docs/integration-execution/` | DataStream integration, tool orchestration (XMPro-specific) |
| Naming Conventions | `docs/naming-conventions/` | XMPro platform ID and message broker conventions |
| Technical Details | `docs/technical-details/` | Platform internals — vector DB, telemetry, agent status |
| Cognitive Intelligence | `docs/cognitive-intelligence/` | Memory decay, confidence scoring, synthetic memory implementation |
| Decision Orchestration | `docs/decision-orchestration/` | Agent lifecycle governance and communication framework |
| Performance Optimization | `docs/performance-optimization/` | Platform tuning and monitoring guidance |
| Adoption Guidance | `docs/adoption-guidance/` | Customer onboarding and risk mitigation (post-sale content) |
| Agent Profiles | `src/agent_profiles/` | XMPro platform JSON configurations |
| Team Manifests | `src/team_manifests/` | Detailed implementation configurations |
| Accessibility | `docs/accessibility.md` | Not relevant to MAGS — to be deleted |

#### Revised Public Repo Navigation (Role-Based Paths)

The README role-based navigation will be updated to remove references to content that has moved. Proposed revised paths:

**Business Executive**
→ Use Cases · Case Studies · Decision Guides · Research Papers · Business FAQ

**Solution Architect**
→ Architecture · Design Patterns · Best Practices · Decision Guides · Strategic Positioning · Architecture FAQ

**Developer**
→ Getting Started · Core Concepts · Design Patterns · Best Practices · Technical FAQ
> *For implementation and configuration: see the Customer Documentation Portal*

**Operations Engineer**
→ Getting Started · Core Concepts · Responsible AI · Technical FAQ
> *For installation, deployment, and tuning: see the Customer Documentation Portal*

---

### Repository 2 — Private GitHub (New Repo)

**Purpose:** Implementation and configuration reference for customers and partners actively deploying MAGS.

**Audience:** Paying customers, implementation partners, XMPro professional services.

**Principle:** Detailed enough to configure and deploy without needing to call support. Proprietary platform specifics kept out of public view.

#### Proposed Structure

```
mags-customer-docs/
├── README.md                        # Welcome and access guide
├── getting-started/                 # Customer onboarding (from adoption-guidance/)
│   ├── onboarding-overview.md
│   ├── incremental-adoption.md
│   └── risk-mitigation-strategies.md
├── implementation-guides/           # Moved from public repo
│   ├── system-prompts.md
│   ├── agent-context.md
│   ├── behavioural-rules.md
│   ├── constraint-configuration.md
│   ├── memory-configuration.md
│   ├── model-selection.md
│   ├── team-size-role-separation.md
│   ├── data-inventory.md
│   └── ...
├── agent-profiles/                  # Moved from src/agent_profiles/
│   ├── README.md
│   ├── anomaly-detection/
│   ├── predictive-maintenance/
│   ├── pharmaceutical/
│   └── ...
├── team-manifests/                  # Moved from src/team_manifests/
│   ├── advanced-predictive-maintenance.md
│   ├── antibiotic-fermentation-optimization.md
│   ├── expert-oee-optimizer.md
│   └── pharmaceutical-cstr-process-intelligence.md
├── platform/                        # Platform internals
│   ├── installation/                # Moved from docs/installation/
│   ├── integration-execution/       # Moved from docs/integration-execution/
│   ├── naming-conventions/          # Moved from docs/naming-conventions/
│   ├── technical-details/           # Moved from docs/technical-details/
│   └── performance-optimization/    # Moved from docs/performance-optimization/
├── advanced/                        # Deep implementation topics
│   ├── cognitive-intelligence/      # Moved from docs/cognitive-intelligence/
│   └── decision-orchestration/      # Moved from docs/decision-orchestration/
└── release-notes/                   # Future: changelog and version history
```

#### Access Control
- Private GitHub repository
- Access granted per organisation (customer/partner)
- XMPro Professional Services team has write access
- Customers have read access
- Partners have read access (full or scoped by agreement)

---

## What Does Not Change

- The public repo URL and structure remain stable — no broken external links
- All public content stays in place; only the private sections are removed
- The public repo's git history is preserved (demonstrates longevity and depth)
- The MIT licence on public documentation is unchanged

---

## Actions Required for Approval

- [ ] Confirm content split is correct as described above
- [ ] Confirm private repo name (suggested: `xmpro/mags-customer-docs`)
- [ ] Confirm which GitHub organisation hosts the private repo
- [ ] Confirm access model (per-org, per-user, team-based)
- [ ] Approve deletion of `docs/accessibility.md`
- [ ] Approve revised public README navigation

---

## Implementation Plan (Post-Approval)

1. Create private GitHub repo with agreed name and access controls
2. Copy private content sections into new repo, preserving folder structure
3. Remove private sections from public repo
4. Update public README navigation to reflect what remains
5. Add a note in public README pointing to the Customer Documentation Portal for implementation guides
6. Verify no broken internal links remain in either repo

---

## Questions or Feedback

Please comment directly on this document or contact Pieter van Schalkwyk.
