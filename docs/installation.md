# XMPro AI Agents Installation Guide

This guide provides detailed instructions for setting up the XMPro AI Agents system.

## Required Prerequisites

- A licensed installation of XMPro
- Neo4j Graph Database
- Milvus, Qdrant or MongoDB Atlas Vector Database (Multiple collection support)
- Message broker: MQTT Broker
- A Large Language Model Provider - for embedding (minimum 1, maximum 1)
    - Azure Open AI
    - Google
    - Ollama
    - Open AI
- A Large Language Model Provider - for inference (minimum 1, maximum 5)
    - Azure Open AI
    - Anthropic
    - Google
    - Ollama
    - Open AI

## Optional
- Open Telemetry (If required)
    - OTLP

## Setup Steps

### 1. Neo4j Configuration

Run the Cypher commands found in `installation/constraints.cypher` to create the necessary constraints and indexes for the database.

### 2. System Options Installation

Execute the Cypher commands found in `installation/system_options.cypher` to set up system options. Before running:

- Edit the `models_providers` array to match your environment's enabled providers
    - For example, if only using Ollama: `models_providers: ['Ollama']`
- Edit the `rag_schema` to match your RAG collection schemas. Each collection can have a different schema.

### 3. Prompt Library Installation

Execute the Cypher commands found in `installation/library_prompts.cypher` to set up the system prompts.

### 4. Tools Library Installation

Execute the Cypher commands found in `installation/library_tools.cypher` to set up the tool options. 

### 5. Agent Profiles

Agent profiles are essential components of the XMPro AI Agents system, defining the characteristics, capabilities, and behavior of each agent. They serve as templates for creating agent instances.

#### Create Profiles
XMPro MAGS provides three main options for creating profiles:

1. **Wizard Creation**: Step-by-step guided process covering:
   - Basic Information
   - Model Configuration
   - Cognitive Parameters
   - Skills and Experience
   - Rules and Prompts
   - RAG Configuration
   - Review and Create

2. **Manual Creation**: Direct input through the agent profile creation UI

3. **Import Existing**: Import pre-configured profiles from JSON files

To create a new profile manually or import an existing one:

Navigate to the Agent Profile management section in the XMPro MAGS administration interface.

Choose either "Create New Profile" or "Import Profile" based on your preference.
If creating manually, fill in all the required fields in the provided form.
If importing, select the JSON file containing the agent profile configuration.

#### Import Examples and Empty Template

In the `./src/agent_profiles` directory, you'll find several examples of agent profiles that can be imported:

- `predictive_maintenance_agent.md`
- `simulation_and_scenario_analysis_agent.md`
- `equipment_monitoring_and_diagnostics_agent.md`

Additionally, an empty template is provided below for creating new profiles from scratch:

```JSON
{
    "active": true,
    "allowed_planning_method": ["Plan & Solve"],
    "decision_parameters": {
      "collaboration_preference": 0.9,
      "innovation_factor": 0.85,
      "planning_cycle_interval_seconds": 14400,
      "risk_tolerance": 0.2
    },
    "deontic_rules": [
      "MODIFY: Add or modify rules specific to the agent's role",
      "Must provide evidence-based analysis",
      "Must collaborate with other agents for comprehensive insights"
    ],
    "experience": "MODIFY: Describe the agent's simulated experience relevant to its role",
    "interaction_preferences": {
      "information_sharing_willingness": 0.95,
      "preferred_communication_style": "MODIFY: Set to analytical, formal, or informal",
      "query_response_detail_level": "medium"
    },
    "max_tokens": 2000,
    "memory_parameters": {
      "max_recent_memories": 150,
      "memory_decay_factor": 0.994,
      "observation_importance_threshold": 0.65,
      "reflection_importance_threshold": 8,
      "memory_cache_cleanup_minutes": 5,
      "memory_cache_max_age_minutes": 30
    },
    "model_name": "MODIFY: Set to the desired model name",
    "model_provider": "MODIFY: Set to the desired model provider",
    "name": "MODIFY: Set the agent's name",
"observation_prompt": "#MODIFY: Update the name here and below reference to reflect the agent profile. Logistics Coordination Specialist\n\n## Observation\n{user_query}\n\n## Relevant Knowledge\n{knowledge_context}\n\nAs an AI agent specialized in logistics coordination for vaccine supply chains, analyze the given observation and relevant knowledge. Then:\n\nOptimize routes and modes of transport for vaccine shipments. Consider potential disruptions and provide contingency plans.\n\n## Response Format\n\n### Analysis\n[Provide a detailed analysis of the observation, considering the context and relevant knowledge, and provide me a summary and key points.]\n\n### Summary\n[Provide a brief and concise summary of the situation]\n\n### Key Points\n- [Key point 1]\n- [Key point 2]\n- [Key point 3]\n...",
    "organizational_rules": [
      "MODIFY: Add rules specific to the organization and agent's role",
      "Ensure timely communication of critical information",
      "Maintain a knowledge base of past experiences and resolutions"
    ],
    "performance_metrics": {
        "MODIFY": "Add or modify metrics relevant to the agent's role",
        "response_time": 45
    },
    "profile_id": "MODIFY: Set a unique profile ID following the naming convention",
    "rag_collection_name": "MODIFY: Set the appropriate RAG collection name",
    "rag_top_k": 10,
    "rag_vector_size": 1536,
"reflection_prompt": "MODIFY: Update the first part of this and the consider section below. As a Logistics Coordination Specialist, reflect on these observations and past reflections, focusing on your performance in managing vaccine transportation and distribution.\n\nConsider the following:\n\n1. How effective were your route optimization strategies in ensuring timely and cost-effective deliveries?\n2. Are there any recurring logistical challenges or bottlenecks that need addressing?\n3. How well are you coordinating with other agents, especially the Cold Chain Integrity Manager, to ensure seamless and safe vaccine transport?\n4. Are there any areas where you can improve your disruption management and contingency planning?\n5. What new transportation technologies or methodologies should you explore to enhance logistics efficiency?\n\nProvide insights and actionable steps to enhance your performance as a logistics coordination specialist.\n\nYou have the following characteristics:\n\nSkills:\n{skills}\n\nExperience:\n{experience}\n\nDeontic rules:\n{deontic_rules}\n\nOrganizational rules:\n{organizational_rules}\n\nRelevant Knowledge:\n{knowledge_context}\n\nRecent observations:\n{recent_observations}\n\nPast reflections:\n{past_reflections}\n\nAvailable Tools:\n{available_tools}\n\n## Response Format\n\n### Analysis\n[Provide a detailed analysis, considering the context and relevant knowledge]\n\n### Summary\n[Provide a brief and concise summary of the situation and your recommendations]\n\n### Key Points\n- [Key point 1]\n- [Key point 2]\n- [Key point 3]\n...\n\n### Actionable Insights\n1. [Insight 1]\n2. [Insight 2]\n3. [Insight 3]\n...",
    "skills": [
      "MODIFY: List skills relevant to the agent's role",
      "Statistical analysis",
      "Machine learning techniques"
    ],
    "system_prompt": "MODIFY: Customize this prompt to define the agent's role and primary objectives",
    "use_general_rag": true
}
```

To use this template:

1. Fields marked with "MODIFY:" should be customized for your specific agent profile.
2. Fields without "MODIFY:" can typically be left as-is, but feel free to adjust if needed for your use case.
3. For array fields (like "deontic_rules" or "skills"), you can add, remove, or modify items as necessary.
4. Ensure all "MODIFY:" markers are removed from the final JSON before importing.
5. **Important**: When setting the `profile_id`, make sure to follow the ID naming convention: `[Area]-[Function]-PROFILE-[Version]`. For example: `WTR-QUAL-PROFILE-001` for a Water Quality Profile.

    The ID naming convention ensures consistency across your agent profiles and aligns with the overall system architecture. Refer to the [Naming Convention - Id](naming-conventions/Id.md) document for more details on the naming structure.

6. Copy the contents of above JSON.
7. Create a new JSON file and paste the template contents.
8. Fill in the details specific to your new agent profile.
9. Save the file and use the "Import Profile" feature in the UI to add it to your system.

#### Load Profiles

Once profiles are created or imported, they can be easily loaded and managed through the XMPro MAGS administration interface:

1. Navigate to the Agent Profile management section.
2. You'll see a list of all available agent profiles.
3. Use the search and filter options to find specific profiles if needed.
4. Select a profile to view its details, edit its configuration, or use it to create agent instances.

Remember to regularly review and update your agent profiles to ensure they remain aligned with your operational needs and take advantage of new capabilities as they're added to the system.

## Next Steps

After completing the installation, access the prompt administration page and ensure the system prompts are using the models providers and models you have enabled.
