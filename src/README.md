# Source Code Directory

This directory contains the core components of the XMPro AI Agents project, specifically focusing on team manifests and agent profiles for our Multi-Agent Generative System (MAGS).

## Structure

- `team_manifests/`: JSON files defining team structures and objectives
- `agent_profiles/`: JSON files specifying individual agent characteristics and capabilities

## Team Manifests

Team manifests define the overall structure, objectives, and operational parameters for a group of AI agents working together. They include information such as:

- Team identification and metadata
- Team objectives and performance metrics
- Communication protocols
- Decision-making processes
- Operational constraints
- Escalation policies

### Sample Teams:
- [Advanced Predictive Maintenance Team](team_manifests/advanced_predictive_maintenance_team)
- [Antibiotic Fermentation Optimization Team](team_manifests/antibiotic_fermentation_optimization_team.md)

## Agent Profiles

Agent profiles define the specific characteristics, capabilities, and roles of individual AI agents within a team. Key components of an agent profile include:

- Agent identification and basic information
- Specialized skills and experience
- Deontic and organizational rules
- Model specifications
- Memory and decision-making parameters
- Performance metrics

For more information on agent profiles, refer to the [Agent Architecture Documentation](../docs/architecture/agent_architecture.md).

All agent profiles can be found here [Agent Profiles](agent_profiles/README.md)

## Usage

To create new team manifests or agent profiles, use the existing examples as templates and modify them according to your specific requirements. Ensure that all JSON files are properly formatted and contain all necessary fields as defined in the documentation.