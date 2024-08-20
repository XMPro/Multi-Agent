# Graph Database

## Id Structure

The Id structure in our graph database follows the naming convention outlined in the `/naming-conventions/Id.md` file. Here's a brief overview:

Structure: `[Site]-[Area]-[Function]-[Type]-[Instance]`

Example: `DALLAS-PROD-OPS-TEAM-001`

Components:
- [Site]: Derived from ISA-95's Enterprise-Site hierarchy
- [Area]: Aligns with ISA-95's Area concept
- [Function]: Influenced by PERA's functional levels and Industry 4.0 concepts
- [Type]: Added to accommodate various entities, including AI agents
- [Instance]: Common in many industrial naming conventions for unique identification

## Graph Database Nodes

Our graph database consists of several types of nodes, each representing different entities in the XMPro AI Agents system. Here's an overview of the main node types and their properties:

### 1. AgentInstance

| Property    | Type     | Description                                    |
|-------------|----------|------------------------------------------------|
| agent_id    | String   | Unique identifier for the agent instance       |
| created_at  | DateTime | Timestamp of when the instance was created     |
| plan_prompt | String   | The prompt used for planning                   |
| profile_id  | String   | ID of the associated agent profile             |
| user_prompt | String   | The initial prompt given to the agent instance |

### 2. AgentProfile

| Property                | Type             | Description                                           |
|-------------------------|------------------|-------------------------------------------------------|
| active                  | Boolean          | Indicates if the profile is currently active          |
| decision_parameters     | String (JSON)    | Parameters for decision making                        |
| deontic_rules           | Array of Strings | Rules governing the agent's behavior                  |
| experience              | String           | Description of the agent's simulated experience       |
| interaction_preferences | String (JSON)    | Preferences for interaction                           |
| max_tokens              | Integer          | Maximum number of tokens for responses                |
| memory_parameters       | String (JSON)    | Parameters for memory management                      |
| model_name              | String           | Name of the specific AI model                         |
| model_type              | String           | Type of AI model used                                 |
| name                    | String           | Name of the agent profile                             |
| observation_prompt      | String           | Prompt template for observations                      |
| organizational_rules    | Array of Strings | Rules specific to the organization                    |
| performance_metrics     | String (JSON)    | Metrics for measuring performance                     |
| profile_id              | String           | Unique identifier for the agent profile               |
| rag_collection_name     | String           | Name of the RAG collection used                       |
| rag_top_k               | Integer          | Number of top results to retrieve from RAG            |
| rag_vector_size         | Integer          | Size of the vector for RAG                            |
| reflection_prompt       | String           | Prompt template for reflections                       |
| skills                  | Array of Strings | List of skills the agent possesses                    |
| system_prompt           | String           | The system prompt for the agent                       |
| use_general_rag         | Boolean          | Whether to use general RAG or not                     |

### 3. Memory

| Property   | Type     | Description                                |
|------------|----------|--------------------------------------------|
| created_at | DateTime | Timestamp of when the memory was created   |
| id         | String   | Unique identifier for the memory           |
| importance | Float    | Importance score of the memory (indexed)   |
| type       | String   | Type of memory (indexed)                   |

### 4. Prompt

| Property           | Type             | Description                                           |
|--------------------|------------------|-------------------------------------------------------|
| access_level       | String           | Access level required to use or modify the prompt     |
| active             | Boolean          | Whether the prompt is currently active                |
| author             | String           | Author of the prompt                                  |
| category           | String           | Category of the prompt                                |
| created_date       | DateTime         | Date and time when the prompt was created             |
| description        | String           | Description of the prompt's purpose                   |
| internal_name      | String           | Internal name used for backend operations (indexed)   |
| last_modified_date | DateTime         | Date and time of the last modification                |
| last_used_date     | DateTime         | Date when the prompt was last used                    |
| model_name         | String           | Specific AI model the prompt is optimized for         |
| model_type         | String           | Type of AI model the prompt is designed for           |
| name               | String           | Name of the prompt                                    |
| process            | String           | Process associated with the prompt (indexed)          |
| prompt             | String           | The actual prompt text                                |
| prompt_id          | String           | Unique identifier for the prompt                      |
| reserved_fields    | Array of Strings | Fields reserved for specific use in the prompt        |
| tags               | Array of Strings | Tags associated with the prompt                       |
| version            | Integer          | Version number of the prompt (indexed)                |

### 5. Team

| Property | Type   | Description                    |
|----------|--------|--------------------------------|
| name     | String | Name of the team               |
| team_id  | String | Unique identifier for the team |

This graph structure allows for efficient querying and analysis of the relationships between different entities in the XMPro AI Agents system.