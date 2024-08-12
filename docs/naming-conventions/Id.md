# Naming Convention - Id

## Summary

This document outlines the naming convention for identifiers used in the XMPro AI Agents system. The convention follows a hybrid approach primarily based on the ISA-95 standard, with influences from other industrial standards and adaptations for modern AI components.

## Structure

The proposed hybrid approach follows this structure:

`[Site]-[Area]-[Function]-[Type]-[Instance]`

Example: `PLANT1-PROD-QUAL-AGENT-001`

### Components

- **[Site]**: Derived from ISA-95's Enterprise-Site hierarchy
- **[Area]**: Aligns with ISA-95's Area concept
- **[Function]**: Influenced by PERA's functional levels and Industry 4.0 concepts
- **[Type]**: Added to accommodate various entities, including AI agents
  - FAC - Facility
  - TEAM - Team
  - PROFILE - Agent Profile
  - AGENT - Agent Instance
- **[Instance]**: Common in many industrial naming conventions for unique identification

## Basis and Influences

1. **Primary Basis: ISA-95 / IEC 62264 Standard**
   - Widely used in manufacturing and industrial control systems
   - Borrows concepts of hierarchical structure and Site/Area designations
   - More information: [ISA-95 Standard](https://www.isa.org/standards-and-publications/isa-standards/isa-standards-committees/isa95)

2. **Influences from Other Standards:**
   - Purdue Enterprise Reference Architecture (PERA): Functional hierarchy concepts
        - More information: [PERA](https://en.wikipedia.org/wiki/Purdue_Enterprise_Reference_Architecture)
   - Industry 4.0: Designed to include modern elements like AI agents

3. **Adaptations and Additions:**
   - [Function] and [Type] elements added for flexibility in representing various industrial processes and entities
   - [Instance] element added for unique identification

4. **Rationale for Adaptations:**
   - Simplifies some aspects of ISA-95 (e.g., omitting Enterprise level)
   - Adds flexibility to accommodate a wider range of entity types, including software and AI components

## Examples

### For Team:
Structure: [Site] - [Area] - [Function] - TEAM - [Version]
Example: DALLAS-PROD-OPS-TEAM-001

### For Agent Profiles:
Structure: [Area] - [Function] - PROFILE - [Version]
Example: WTR-QUAL-PROFILE-001

Note: Agent Profiles do not include the [Site] component in their identifier. This is because Agent Profiles belong to a team, which already contains the site information. The site context is inherited from the team to which the profile belongs.

### For Agent Instances:
Structure: [Area] - [Function] - AGENT - [Instance]
Example: WTR-QUAL-AGENT-001

Note: Agent Instances do not include the [Site] component in their identifier. This is because Agent Instances belong to an Agent Profile, which belongs to a Team, that already contains the site information. The site context is inherited from the team to which the instance belongs.

## Explanation of Structure Differences

1. **Teams**: Include all components ([Site]-[Area]-[Function]-TEAM-[Version]) as they represent the highest level of organization within a site.

2. **Agent Profiles**: Omit the [Site] component ([Area]-[Function]-PROFILE-[Version]) because they are associated with a specific team, which already includes the site information. This prevents redundancy and maintains a clear hierarchical structure.

3. **Agent Instances**: Similar to Agent Profiles, they omit the [Site] component ([Area]-[Function]-AGENT-[Instance]) as they are instantiated within the context of a team.

This structure ensures that each entity has a unique identifier while avoiding unnecessary repetition of information. The site context for both Agent Profiles and Agent Instances is implicitly provided by the team they belong to.

## Sample Id Table - Agent Instance

| Agent Name                    | ID                        | Site  | Area  | Function | Type  | Instance |
|-------------------------------|---------------------------|-------|-------|----------|-------|----------|
| Water Quality Agent           | WTR-QUAL-AGENT-001  | na | WTR   | QUAL     | AGENT | 001      |
| Maintenance Engineering Agent | MAINT-ENG-AGENT-001 | na | MAINT | ENG      | AGENT | 001      |
| Operations Management Agent   | OPS-MGT-AGENT-001   | na | OPS   | MGT      | AGENT | 001      |
| Energy Efficiency Agent       | ENGY-EFF-AGENT-001  | na | ENGY  | EFF      | AGENT | 001      |
| Safety and Compliance Agent   | SFTY-COMP-AGENT-001 | na | SFTY  | COMP     | AGENT | 001      |
| Data Analysis Agent           | DATA-ANLY-AGENT-001 | na | DATA  | ANLY     | AGENT | 001      |

## Legend

| Location/Area Code | Description       |     | Function/Type Code | Description |
|--------------------|-------------------|-----|---------------------|-------------|
| RESV1              | Reservoir Site 1  |     | QUAL                | Quality     |
| WTR                | Water Management  |     | ENG                 | Engineering |
| MAINT              | Maintenance       |     | MGT                 | Management  |
| OPS                | Operations        |     | EFF                 | Efficiency  |
| ENGY               | Energy Management |     | COMP                | Compliance  |
| SFTY               | Safety            |     | ANLY                | Analysis    |
| DATA               | Data Management   |     |                     |             |

Note: 
- RESV1 is used as a placeholder for the site. In a real-world scenario, this would be replaced with the actual site identifier.
- The Area and Function components are derived from the agent's primary role.
- AGENT is used to denote that these are Agent instances, distinguishing them from other types of equipment or systems.
- 001 is used as the instance number, allowing for multiple agent instances of the same type if needed.

# Naming Convention Examples

| Entity Type | Example ID | Breakdown | Explanation |
|-------------|------------|-----------|-------------|
| Location | DALLAS-PLANT-PROD-FAC-001 | DALLAS: Site<br>PLANT: Area<br>PROD: Function<br>FAC: Type<br>001: Instance | - DALLAS: Abbreviation for Dallas (Site)<br>- PLANT: Indicates it's a manufacturing plant (Area)<br>- PROD: Denotes production area (Function)<br>- FAC: Facility type (Type)<br>- 001: Instance number (assuming this is the first or only plant in Dallas) |
| Team | DALLAS-PROD-OPS-TEAM-001 | DALLAS: Site<br>PROD: Area<br>OPS: Function<br>TEAM: Type<br>001: Instance | - DALLAS: Abbreviation for Dallas (Site)<br>- PROD: Production (Area)<br>- OPS: Operations (Function)<br>- TEAM: Indicates this is a team identifier (Type)<br>- 001: Instance number (for the first or primary operations team) |
| Agent Profile | WTR-QUAL-PROFILE-001 | WTR: Area<br>QUAL: Function<br>PROFILE: Type<br>001: Version | - WTR: Water management (Area)<br>- QUAL: Quality (Function)<br>- PROFILE: Indicates this is an agent profile (Type)<br>- 001: Version number |
| Agent Instance | WTR-QUAL-AGENT-001 | WTR: Area<br>QUAL: Function<br>AGENT: Type<br>001: Instance | - WTR: Water management (Area)<br>- QUAL: Quality (Function)<br>- AGENT: Indicates this is an agent instance (Type)<br>- 001: Instance number |

Note: The Agent Profile and Agent Instance examples do not include the Site component (e.g., DALLAS) because they are associated with a team that already contains this information, avoiding redundancy.

Additional Agent Profile Examples:
- MAINT-ENG-PROFILE-001 (Maintenance Engineering)
- OPS-MGT-PROFILE-001 (Operations Management)
- ENGY-EFF-PROFILE-001 (Energy Efficiency)
- SFTY-COMP-PROFILE-001 (Safety and Compliance)
- DATA-ANLY-PROFILE-001 (Data Analysis)

These examples demonstrate how the naming convention is applied consistently across different types of entities in the system, providing clear and structured identifiers that convey information about the entity's location, function, and type.

## Conclusion

This naming convention provides a flexible and comprehensive framework for identifying various components in the XMPro AI Agents system. It balances the need for standardization with the flexibility required for modern industrial AI applications.