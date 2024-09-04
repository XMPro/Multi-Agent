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

### Example Agents

1. [Antibiotic Fermentation Maintenance and Calibration Specialist Agent](agent_profiles/antibiotic_production_fermentation_maintenance_calibration_specialist.md)
2. [Antibiotic Fermentation Microbiologist Agent](agent_profiles/antibiotic_production_fermentation_microbiologist.md)
3. [Antibiotic Fermentation Process Engineer Agent](agent_profiles/antibiotic_production_fermentation_process_engineer.md)
4. [Antibiotic Fermentation Process Optimization and Data Scientist Agent](agent_profiles/antibiotic_production_process_optimization_data_scientist.md)
5. [Antibiotic Fermentation Quality Assurance and Compliance Officer Agent](agent_profiles/antibiotic_production_quality_assurance_compliance_officer.md)

Each link above leads to a detailed profile for the respective agent.

## Usage

To create new team manifests or agent profiles, use the existing examples as templates and modify them according to your specific requirements. Ensure that all JSON files are properly formatted and contain all necessary fields as defined in the documentation.