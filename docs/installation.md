# XMPro AI Agents Installation Guide

This guide provides detailed instructions for setting up the XMPro AI Agents system.

## Required Prerequisites

- Neo4j Graph Database
- Milvus Vector Database (Multiple collection support)
- MQTT Broker
- A Large Language Model Provider - for embedding (minimum 1, maximum 1)
    - Azure Open AI
    - Ollama
    - Open AI
- A Large Language Model Provider - for inference (minimum 1, all 3)
    - Azure Open AI
    - Ollama
    - Open AI
- XMPro Stream Host

## Optional
- Open Telemetry (If required)
    - OTLP
    - Azure Monitor

## Setup Steps

### 1. Neo4j Configuration

Run the following commands in your Neo4j database to create necessary constraints and indexes:

```cypher
CREATE CONSTRAINT agent_profile_id_unique IF NOT EXISTS FOR (p:AgentProfile) REQUIRE p.profile_id IS UNIQUE;
CREATE CONSTRAINT agent_instance_id_unique IF NOT EXISTS FOR (a:AgentInstance) REQUIRE a.agent_id IS UNIQUE;
CREATE CONSTRAINT memory_id_unique IF NOT EXISTS FOR (m:Memory) REQUIRE m.id IS UNIQUE;
CREATE CONSTRAINT decision_id_unique IF NOT EXISTS FOR (p:Decision) REQUIRE p.id IS UNIQUE;
CREATE CONSTRAINT prompt_id_unique IF NOT EXISTS FOR (p:Prompt) REQUIRE p.prompt_id IS UNIQUE;

CREATE INDEX team_id_idx IF NOT EXISTS FOR (t:Team) ON (t.team_id);

CREATE INDEX memory_created_at_idx IF NOT EXISTS FOR (m:Memory) ON (m.created_at);
CREATE INDEX memory_type_idx IF NOT EXISTS FOR (m:Memory) ON (m.type);
CREATE INDEX memory_importance_idx IF NOT EXISTS FOR (m:Memory) ON (m.importance);

CREATE INDEX prompt_internal_name_idx IF NOT EXISTS FOR (p:Prompt) ON (p.internal_name);
CREATE INDEX prompt_id_idx IF NOT EXISTS FOR (p:Prompt) ON (p.prompt_id);
```

### 2. System Options Installation

Execute the following Cypher query to set up system options:

Edit the `models_providers` to ensure it matches your environment on what you are enabling as options.

For example if you are only allowing *Ollama* then it should read as `models_providers: ['Ollama'],`.

```cypher
CREATE (so:SystemOptions {
  id: 'SYSTEM-OPTIONS',
  reserved_fields_observation: ['user_query', 'knowledge_context'],
  reserved_fields_reflection: ['skills', 'experience', 'deontic_rules', 'organizational_rules', 'knowledge_context', 'recent_observations', 'past_reflections'],
  models_providers: ['Ollama', 'OpenAI', 'AzureOpenAI'],
  prompt_access_levels: '[
  {"value": "admin", "description": "For system administrators with full access to all prompts"},
  {"value": "user", "description": "For regular users of the system"},
  {"value": "restricted", "description": "For sensitive prompts that require special permission to access"},
  {"value": "system", "description": "For core system prompts essential for the MAGs memory cycle implementation"}
]',
  prompt_types: '[
  {"value": "system", "description": "For core system functionality"},
  {"value": "user", "description": "For prompts created or customized by users"},
  {"value": "template", "description": "For base prompts that can be customized or extended for specific use cases"},
  {"value": "analysis", "description": "For prompts designed to analyze or interpret data or text"},
  {"value": "generation", "description": "For prompts focused on generating new content or ideas"},
  {"value": "classification", "description": "For prompts that categorize or label input"},
  {"value": "extraction", "description": "For prompts designed to extract specific information from text"},
  {"value": "dialogue", "description": "For prompts used in conversational or interactive contexts"},
  {"value": "task-specific", "description": "For prompts designed for particular tasks within the application"},
  {"value": "utility", "description": "For helper prompts that support other processes but aren\'t main functionalities"}
]',
  rag_schema: '{
    "schemas": {
      "default": {
        "id": "string",
        "title": "string",
        "content": "string",
        "summary": "string",
        "author": "string",
        "source": "string",
        "url": "string",
        "publication_date": "datetime",
        "last_updated": "datetime",
        "language": "string",
        "category": "string",
        "tags": "list<string>",
        "version": "string",
        "vector": "list<float>",
        "related_documents": "list<string>"
      }
    },
    "citation_structure": {
      "format": "[{id}] {author}. \"{title}.\" {source}, {publication_date}. {url}. (Accessed: {last_updated})",
      "fields": ["id", "author", "title", "source", "publication_date", "url", "last_updated"]
    }
  }',
  created_date: datetime(),
  last_modified_date: datetime()
})
RETURN so
```

### 3. Prompt Library Load

| Internal Name | Description |
|---------------|-------------|
| conversation_prompt | A generic prompt for handling conversations with various types of agents. |
| conversation_summary_prompt | A prompt to generate a one-sentence summary of a conversation between a user and an AI assistant. |
| final_pddl_plan_prompt | A prompt to generate the final PDDL plan incorporating all improvements and solving the original problem. |
| importance_prompt | A prompt to rate the importance of an observation or a reflection on a scale of 0 to 1, with a customizable importance threshold. |
| plan_execution_simulation_prompt | A prompt to simulate the execution of a plan for a specific subtask and describe the outcomes and challenges. |
| planning_decision_prompt | A prompt to decide whether a new plan is needed based on the agent's current state, goals, and recent memories. |
| reflection_plan_analysis_prompt | A prompt to analyze recent reflections, determine if a new plan is needed, and potentially define a new goal. |
| subtask_plan_formulation_prompt | A prompt to formulate a plan for solving a specific subtask within the context of a PDDL problem. |
| task_decomposition_prompt | A prompt to decompose a complex task into smaller, manageable subtasks based on the problem understanding. |
| tool_results_prompt | A prompt to generate an updated response based on tool results and check if a new observation is needed. |
| understand_problem_prompt | A prompt to analyze goals, and provide a summary. |

Execute the following Cypher query to set up system prompts:

```cypher
// Create PromptLibrary
CREATE (p:PromptLibrary {name: "Main Prompt Library", created_date: datetime()})

//MemoryCycle - CalculateImportance
CREATE (p1:Prompt {
  prompt_id: "XMAGS-IMPORTANCE-PROMPT-001",
  name: "Importance",
  internal_name: "importance_prompt",
  prompt: "Rate the importance of the following observation on a scale of 0 to 1, where 0 is completely unimportant and 1 is extremely important. The threshold for importance is {threshold}:\n\n{content}\n\nImportance score:",
  reserved_fields: ["threshold", "content"],
  author: "XMPro",
  created_date: datetime(),
  last_modified_date: datetime(),
  active: true,
  version: 0o01,
  type: "system",
  category: "memory_cycle",
  tags: ["observation", "reflection"],
  description: "A prompt to rate the importance of an observation or a reflection on a scale of 0 to 1, with a customizable importance threshold.",
  last_used_date: null,
  model_provider: "Ollama",
  model_name: "llama3",
  max_tokens: 2000,
  access_level: "system"
}),
(p)-[:CONTAINS]->(p1)

//MemoryCycle - ShouldTriggerPlanningAsync
CREATE (p2:Prompt {
  prompt_id: "XMAGS-PLANNINGDECISION-PROMPT-001",
  name: "Planning Decision",
  internal_name: "planning_decision_prompt",
  prompt: "Based on the following information, decide if a new plan is needed:\n\nRecent memories: {recent_memories}\nCurrent state: {current_state}\nCurrent goals: {current_goals}\nNew goal from reflections: {new_goal_from_reflections}\nTime for planning: {time_for_planning}\nCurrent plan valid: {current_plan_valid}\nGoals being met: {goals_being_met}\nNew plan needed based on reflections: {new_plan_needed}\n\nProvide your decision as 'Yes' or 'No', followed by a brief explanation.",
  reserved_fields: ["recent_memories", "current_state", "current_goals", "new_goal_from_reflections", "time_for_planning", "current_plan_valid", "goals_being_met", "new_plan_needed"],
  author: "XMPro",
  created_date: datetime(),
  last_modified_date: datetime(),
  active: true,
  version: 0o01,
  type: "system",
  category: "memory_cycle",
  tags: ["decision-making", "planning"],
  description: "A prompt to decide whether a new plan is needed based on the agent's current state, goals, and recent memories.",
  last_used_date: null,
  model_provider: "Ollama",
  model_name: "llama3",
  max_tokens: 2000,
  access_level: "system"
}),
(p)-[:CONTAINS]->(p2)

//MemoryCycle - DetermineGoalFromReflectionsAsync
CREATE (p3:Prompt {
  prompt_id: "XMAGS-REFLECTIONPLANANALYSIS-PROMPT-001",
  name: "Reflection Plan Analysis",
  internal_name: "reflection_plan_analysis_prompt",
  prompt: "Analyze the following recent reflections and determine if a new plan is needed. If so, provide a concise goal statement.\n\nRecent reflections:\n{recent_reflections}\nCurrent goals: \n{current_goals}\n\nRespond with 'New plan needed: Yes/No' followed by 'New goal: [goal statement]' if a new plan is needed.",
  reserved_fields: ["recent_reflections", "current_goals"],
  author: "XMPro",
  created_date: datetime(),
  last_modified_date: datetime(),
  active: true,
  version: 0o01,
  type: "system",
  category: "memory_cycle",
  tags: ["goal-setting", "reflection-analysis", "planning"],
  description: "A prompt to analyze recent reflections, determine if a new plan is needed, and potentially define a new goal.",
  last_used_date: null,
  model_provider: "Ollama",
  model_name: "llama3",
  max_tokens: 2000,
  access_level: "system"
}),
(p)-[:CONTAINS]->(p3)

//PLanAndSolveStrategt - GetFallbackPrompt
CREATE (p4:Prompt {
  prompt_id: "XMAGS-UNDERSTANDPROBLEM-PROMPT-001",
  name: "Understanding Goal Analysis",
  internal_name: "understand_problem_prompt",
  prompt: "Analyze the following goal and provide a concise summary of the key elements, objectives, and constraints:\n\nGoal: {goal}",
  reserved_fields: ["goal"],
  author: "XMPro",
  created_date: datetime(),
  last_modified_date: datetime(),
  active: true,
  version: 0o01,
  type: "system",
  category: "plan_solve_strategy",
  tags: ["planning"],
  description: "A prompt to analyze goals, and provide a summary.",
  last_used_date: null,
  model_provider: "Ollama",
  model_name: "llama3",
  max_tokens: 2000,
  access_level: "system"
}),
(p)-[:CONTAINS]->(p4)

//AbstractPlanninStrategy - DecomposeTaskAsync
CREATE (p5:Prompt {
  prompt_id: "XMAGS-TASKDECOMP-PROMPT-001",
  name: "Task Decomposition",
  internal_name: "task_decomposition_prompt",
  prompt: "Based on this understanding of the problem:\n{understanding}\n\nDecompose the overall task into a list of smaller, manageable subtasks. Each subtask should be a step towards solving the overall problem.  I want a MAXIMUM of 5 subtasks do NOT exceed this. Choose the top 5 as the most important subtasks.  You do not have to create 5 if you can accomplish this in fewer subtasks, 5 is your MAXIMUM.\n\n## Response Format

### Subtasks
[Provide a numbered list of subtasks, you can provide sub bullets if required.]",
  reserved_fields: ["understanding"],
  author: "XMPro",
  created_date: datetime(),
  last_modified_date: datetime(),
  active: true,
  version: 0o01,
  type: "system",
  category: "plan_solve_strategy",
  tags: ["task-decomposition", "subtasks", "planning"],
  description: "A prompt to decompose a complex task into smaller, manageable subtasks based on the problem understanding.",
  last_used_date: null,
  model_provider: "Ollama",
  model_name: "llama3",
  max_tokens: 2000,
  access_level: "system"
}),
(p)-[:CONTAINS]->(p5)

//AbstractPlanningStrategy - FormulateSubtaskPlansAsync
CREATE (p6:Prompt {
  prompt_id: "XMAGS-SUBTASKPLAN-PROMPT-001",
  name: "Subtask Plan Formulation",
  internal_name: "subtask_plan_formulation_prompt",
  prompt: "Formulate a plan for solving this subtask within the context of the PDDL problem: '{subtask}'. Describe the approach and any key actions or decisions.",
  reserved_fields: ["subtask"],
  author: "XMPro",
  created_date: datetime(),
  last_modified_date: datetime(),
  active: true,
  version: 0o01,
  type: "system",
  category: "plan_solve_strategy",
  tags: ["subtask-planning", "plan-formulation", "planning"],
  description: "A prompt to formulate a plan for solving a specific subtask within the context of a PDDL problem.",
  last_used_date: null,
  model_provider: "Ollama",
  model_name: "llama3",
  max_tokens: 2000,
  access_level: "system"
}),
(p)-[:CONTAINS]->(p6)

//AbstractPlanningStrategy - ExecutePlanAsync
CREATE (p7:Prompt {
  prompt_id: "XMAGS-PLANEXECSIM-PROMPT-001",
  name: "Plan Execution Simulation",
  internal_name: "plan_execution_simulation_prompt",
  prompt: "Simulate the execution of this plan for the subtask '{subtask}':\n{plan}\n\nDescribe the outcome, any challenges encountered, and how they were addressed.",
  reserved_fields: ["subtask", "plan"],
  author: "XMPro",
  created_date: datetime(),
  last_modified_date: datetime(),
  active: true,
  version: 0o01,
  type: "system",
  category: "plan_solve_strategy",
  tags: ["plan-execution", "simulation", "planning"],
  description: "A prompt to simulate the execution of a plan for a specific subtask and describe the outcomes and challenges.",
  last_used_date: null,
  model_provider: "Ollama",
  model_name: "llama3",
  max_tokens: 2000,
  access_level: "system"
}),
(p)-[:CONTAINS]->(p7)

//PLanAndSolveStrategt - GetFallbackPrompt
CREATE (p8:Prompt {
  prompt_id: "XMAGS-FINALPDDLPLAN-PROMPT-001",
  name: "Final PDDL Plan",
  internal_name: "final_pddl_plan_prompt",
  prompt: "Given the following information:

Goal: {goal}

Problem Understanding: {understanding}

Subtasks: {sub_tasks}

Subtask Plans: {sub_task_Plans}

Generate a complete PDDL plan that solves the problem. Your response should include:

1. A PDDL domain definition with appropriate types, predicates, and actions.
2. A PDDL problem definition that matches the domain and represents the initial state and goal.
3. A sequence of PDDL actions that solve the problem, incorporating the plans for each subtask.

Ensure the plan is properly formatted and includes all necessary elements for a valid PDDL representation. The actions should be in the correct order to achieve the goal, taking into account the relationships between subtasks.",
  reserved_fields: ["goal", "understanding", "sub_tasks", "sub_task_Plans"],
  author: "XMPro",
  created_date: datetime(),
  last_modified_date: datetime(),
  active: true,
  version: 0o01,
  type: "system",
  category: "plan_solve_strategy",
  tags: ["PDDL", "plan-generation", "final-plan", "planning"],
  description: "A prompt to generate the final PDDL plan incorporating all improvements and solving the original problem.",
  last_used_date: null,
  model_provider: "Ollama",
  model_name: "llama3",
  max_tokens: 2000,
  access_level: "system"
}),
(p)-[:CONTAINS]->(p8)

// Create the tool results prompt
CREATE (p9:Prompt {
  prompt_id: "XMAGS-TOOL-RESULTS-PROMPT-001",
  name: "Tool Results",
  internal_name: "tool_results_prompt",
  prompt: "Based on the following information:\n\nOriginal prompt: {original_prompt}\n\nPrevious response: {previous_response}\n\nPlease provide an updated response. After your response, on a new line, write 'OBSERVATION_NEEDED: Yes' if you think a new observation should be made based on this interaction, or 'OBSERVATION_NEEDED: No' if not.",
  reserved_fields: ["original_prompt", "previous_response"],
  author: "XMPro",
  created_date: datetime(),
  last_modified_date: datetime(),
  active: true,
  version: 0o01,
  type: "system",
  category: "conversation",
  tags: ["tool_results", "observation_check"],
  description: "A prompt to generate an updated response based on tool results and check if a new observation is needed.",
  last_used_date: null,
  model_provider: "Ollama",
  model_name: "llama3",
  max_tokens: 2000,
  access_level: "system"
}),
(p)-[:CONTAINS]->(p9)

// Create the conversation summary prompt
CREATE (p10:Prompt {
  prompt_id: "XMAGS-CONVERSATION-SUMMARY-PROMPT-001",
  name: "Conversation Summary",
  internal_name: "conversation_summary_prompt",
  prompt: "Summarize the following conversation in one sentence:\nUser: {user_query}\nAssistant: {agent_response} [Return ONLY the summary]",
  reserved_fields: ["user_query", "agent_response"],
  author: "XMPro",
  created_date: datetime(),
  last_modified_date: datetime(),
  active: true,
  version: 0o01,
  type: "system",
  category: "conversation",
  tags: ["summary"],
  description: "A prompt to generate a one-sentence summary of a conversation between a user and an AI assistant.",
  last_used_date: null,
  model_provider: "Ollama",
  model_name: "llama3",
  max_tokens: 2000,
  access_level: "system"
}),
(p)-[:CONTAINS]->(p10)

// Create the conversation prompt
CREATE (p11:Prompt {
  prompt_id: "XMAGS-CONVERSATION-PROMPT-001",
  name: "Generic Conversation",
  internal_name: "conversation_prompt",
  prompt: "Conversation history:\n{conversation_history}\n\nContext information:\n{knowledge_context}\n\nAvailable tools:\n{available_tools}\n\nCurrent user input: {user_query}\n\nPlease provide a response that:\n1. Addresses the user's input directly.\n2. Incorporates relevant information from the conversation history and context.\n3. Uses available tools when necessary to provide accurate and helpful information.\n4. Maintains a consistent and appropriate tone throughout the conversation.\n5. Asks for clarification if the user's intent is unclear.\n\nYour response:",
  reserved_fields: ["conversation_history", "knowledge_context", "available_tools", "user_query"],
  author: "XMPro",
  created_date: datetime(),
  last_modified_date: datetime(),
  active: true,
  version: 0o01,
  type: "system",
  category: "conversation",
  tags: ["generic", "conversation"],
  description: "A generic prompt for handling conversations with various types of agents.",
  last_used_date: null,
  model_provider: "Ollama",
  model_name: "llama3",
  max_tokens: 2000,
  access_level: "system"
}),
(p)-[:CONTAINS]->(p11)
```

### 4. Agent Profiles
[To be addded]

#### Create Profiles

#### Load Profiles

## Troubleshooting

## Next Steps

After completing the installation, access the prompt administration page and ensure the system prompts are using the models providers and models you have enabled.