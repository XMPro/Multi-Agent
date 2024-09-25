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
CREATE CONSTRAINT tool_name_unique IF NOT EXISTS FOR (t:Tool) REQUIRE t.name IS UNIQUE;

CREATE INDEX team_id_idx IF NOT EXISTS FOR (t:Team) ON (t.team_id);

CREATE INDEX memory_created_date_idx IF NOT EXISTS FOR (m:Memory) ON (m.created_date);
CREATE INDEX memory_type_idx IF NOT EXISTS FOR (m:Memory) ON (m.type);
CREATE INDEX memory_importance_idx IF NOT EXISTS FOR (m:Memory) ON (m.importance);

CREATE INDEX prompt_internal_name_idx IF NOT EXISTS FOR (p:Prompt) ON (p.internal_name);
CREATE INDEX prompt_id_idx IF NOT EXISTS FOR (p:Prompt) ON (p.prompt_id);
```

### 2. System Options Installation

Execute the following Cypher query to set up system options:

Edit the `models_providers` to ensure it matches your environment on what you are enabling as options.

For example if you are only allowing *Ollama* then it should read as `models_providers: ['Ollama'],`.

Edit the `rag_schema` to ensure it matches your rag schema for the collections you have defined.  Each RAG collection can have a different schema.

```cypher
CREATE (so:SystemOptions {
  id: 'SYSTEM-OPTIONS',
  reserved_fields_observation: ['user_query', 'knowledge_context'],
  reserved_fields_reflection: ['skills', 'experience', 'deontic_rules', 'organizational_rules', 'knowledge_context', 'recent_observations', 'past_reflections', 'available_tools'],
  models_providers: ['Anthropic', 'Google', 'AzureOpenAI', 'Ollama', 'OpenAI'],
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
      "rag_general": {
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

### 3. Prompt Library Installation

| Internal Name | Description |
|---------------|-------------|
| conversation_prompt | A generic prompt for handling conversations with various types of agents. |
| conversation_observation_prompt | A generic prompt to check if an observation is required based on the conversation. |
| conversation_summary_prompt | A prompt to generate a one-sentence summary of a conversation between a user and an AI assistant. |
| final_pddl_plan_prompt | A prompt to generate the final PDDL plan incorporating all improvements and solving the original problem. |
| importance_prompt | A prompt to rate the importance of an observation or a reflection on a scale of 0 to 1, with a customizable importance threshold. |
| planning_decision_prompt | A prompt to decide whether a new plan is needed based on the agent's current state, goals, and recent memories. |
| reflection_plan_analysis_prompt | A prompt to analyze recent reflections, determine if a new plan is needed, and potentially define a new goal. |
| subtask_plan_formulation_prompt | A prompt to formulate a plan for solving a specific subtask within the context of a PDDL problem. |
| task_decomposition_prompt | A prompt to decompose a complex task into smaller, manageable subtasks based on the problem understanding. |
| tool_results_prompt | A prompt to generate an updated response based on tool results and check if a new observation is needed. |
| understand_problem_prompt | A prompt to analyze goals, and provide a summary. |

Execute the following Cypher query to set up system prompts:

```cypher
// Create Prompt Library
CREATE (p:Library {name: "Main Prompt Library", type: "Prompt", created_date: datetime()})

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
  version: 1,
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

CREATE (p2:Prompt {
  prompt_id: "XMAGS-PLANNINGDECISION-PROMPT-001",
  name: "Planning Decision",
  internal_name: "planning_decision_prompt",
  prompt: "Based on the following information, decide if a new plan is needed:

Recent memories: {recent_memories}
Current state: {current_state}
Current goals: {current_goals}
New goal from reflections: {new_goal_from_reflections}
Time for planning: {time_for_planning}
Current plan valid: {current_plan_valid}
Current plan details: {current_plan_details}
Goals being met: {goals_being_met}
New plan needed based on reflections: {new_plan_needed}

Provide your decision as 'Yes' or 'No', followed by a brief explanation.",
  reserved_fields: ["recent_memories", "current_state", "current_goals", "new_goal_from_reflections", "time_for_planning", "current_plan_valid", "current_plan_details", "goals_being_met", "new_plan_needed"],
  author: "XMPro",
  created_date: datetime(),
  last_modified_date: datetime(),
  active: true,
  version: 1,
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
  version: 1,
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
  version: 1,
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
  version: 1,
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
  version: 1,
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

CREATE (p7:Prompt {
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
  version: 1,
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
(p)-[:CONTAINS]->(p7)

CREATE (p8:Prompt {
  prompt_id: "XMAGS-TOOLRESULTS-PROMPT-001",
  name: "Tool Results",
  internal_name: "tool_results_prompt",
  prompt: "Based on the following information:\n\nOriginal prompt: {original_prompt}\n\nPrevious response: {previous_response}\n\nPlease provide an updated response. After your response, on a new line, write 'OBSERVATION_NEEDED: Yes' if you think a new observation should be made based on this interaction, or 'OBSERVATION_NEEDED: No' if not.",
  reserved_fields: ["original_prompt", "previous_response"],
  author: "XMPro",
  created_date: datetime(),
  last_modified_date: datetime(),
  active: true,
  version: 1,
  type: "system",
  category: "conversation",
  tags: ["tool", "observation"],
  description: "A prompt to generate an updated response based on tool results and check if a new observation is needed.",
  last_used_date: null,
  model_provider: "Ollama",
  model_name: "llama3",
  max_tokens: 2000,
  access_level: "system"
}),
(p)-[:CONTAINS]->(p8)

CREATE (p9:Prompt {
  prompt_id: "XMAGS-CONVSUMMARY-PROMPT-001",
  name: "Conversation Summary",
  internal_name: "conversation_summary_prompt",
  prompt: "Summarize the following conversation so it can be used in a future conversation:

User: {user_query}
Assistant: {agent_response} 

[Return ONLY the summary]",
  reserved_fields: ["user_query", "agent_response"],
  author: "XMPro",
  created_date: datetime(),
  last_modified_date: datetime(),
  active: true,
  version: 1,
  type: "system",
  category: "conversation",
  tags: ["summary", "conversation"],
  description: "A prompt to generate a one-sentence summary of a conversation between a user and an AI assistant.",
  last_used_date: null,
  model_provider: "Ollama",
  model_name: "llama3",
  max_tokens: 2000,
  access_level: "system"
}),
(p)-[:CONTAINS]->(p9)

CREATE (p10:Prompt {
  prompt_id: "XMAGS-CONV-PROMPT-001",
  name: "Conversation Generic",
  internal_name: "conversation_prompt",
  prompt: "Current timestamp: {current_timestamp}

Conversation history:
{conversation_history}

Context information:
{knowledge_context}

Available tools:
{available_tools}

To suggest a tool for use, include 'SUGGEST_TOOL: ToolName: "the user's original question"' in your response.

Current user input: {user_query}

Please provide a response that:
1. Addresses the user's input directly.
2. Incorporates relevant information from the conversation history and context.
3. IMPORTANT: Suggests available tools when necessary to provide accurate and helpful information. Always use the syntax 'SUGGEST_TOOL: ToolName: "user's original question"' when suggesting a tool. Do not attempt to create or modify queries yourself. Pass the user's question directly to the tool.
4. Maintains a consistent and appropriate tone throughout the conversation.
5. Asks for clarification if the user's intent is unclear.
6. Does not include any additional comments about running the query or needing confirmation.
7. CRITICAL: Do not provide any information that you don't have direct access to. Do not assume or fabricate any data or results. If you need information to answer the question, only suggest using a tool to obtain it.

Your response must include at least one tool suggestion if relevant to answering the query. Do not provide any fake or assumed results from tool usage. Do not speculate about what the results might be. Do not ask for confirmation to use the tool.  

Begin your response now:",
  reserved_fields: ["conversation_history", "knowledge_context", "available_tools", "user_query", "current_timestamp"],
  author: "XMPro",
  created_date: datetime(),
  last_modified_date: datetime(),
  active: true,
  version: 1,
  type: "system",
  category: "conversation",
  tags: ["conversation"],
  description: "A generic prompt for handling conversations with various types of agents.",
  last_used_date: null,
  model_provider: "Ollama",
  model_name: "llama3",
  max_tokens: 2000,
  access_level: "system"
}),
(p)-[:CONTAINS]->(p10)

CREATE (p11:Prompt {
  prompt_id: "XMAGS-CONVOBSERVATION-PROMPT-001",
  name: "Conversation Observation",
  internal_name: "conversation_observation_prompt",
  prompt: "Analyze the following response and determine if it contains information that warrants creating a new observation. Consider the following criteria:

1. Significance: Does the response contain important or novel information?
2. Relevance: Is the information directly related to the agent's tasks or goals?
3. Actionability: Does the information suggest potential actions or decisions?
4. Complexity: Is the information complex enough to benefit from further analysis?

Response to analyze:
{response}

Based on these criteria, should a new observation be created? Respond with ONLY 'Yes' or 'No'.",
  reserved_fields: ["response"],
  author: "XMPro",
  created_date: datetime(),
  last_modified_date: datetime(),
  active: true,
  version: 1,
  type: "system",
  category: "conversation",
  tags: ["observation", "conversation"],
  description: "A generic prompt to check if an observation is required based on the conversation.",
  last_used_date: null,
  model_provider: "Ollama",
  model_name: "llama3",
  max_tokens: 2000,
  access_level: "system"
}),
(p)-[:CONTAINS]->(p11)
```

### 4. Tools Library Installation
Execute the following Cypher query to set up the tool options:

```cypher
// Create Tool Library
CREATE (tl:Library {name: "Tool Library", type: "Tool", created_date: datetime()})

// Create SQL Query Tool
CREATE (sql:Tool {
    name: 'SqlRecommendationQueryTool',
    description: 'Executes read-only SQL queries based on natural language input. This tool interprets user requests, generates appropriate SQL SELECT statements, and retrieves data from the specified database, ensuring data integrity by preventing any modifications.  XMPro Recommendations are advanced event alerts that combine alerts, actions, and monitoring capabilities to enhance operational decision-making and response.',
    class_name: 'SqlQueryTool',
    created_date: datetime(),
    last_modified_date: datetime(),
    options: '{"connectionString": "default_connection_string", "timeout": 30, "max_retries": 3}',
    model_provider: 'Ollama',
    model_name: 'llama3',
    max_tokens: 2000,
    prompt_user: 'Generate a SQL query to answer the following question: {user_query}. Wrap the SQL query in ```sql``` tags.',
    prompt_system: 'You are an advanced SQL query generator for a specific database schema. The database schema is as follows:
    
    -- AI_RecommendationAlertData Table
CREATE TABLE AI_RecommendationAlertData (
    ID INT,
    RuleId INT,
    EntityId INT,
    AssetId INT,
    Status INT,  -- 0: active, 1: resolved
    IsRecommendationClosed INT,  -- 0: open, 1: closed
    Title VARCHAR(255),
    Description TEXT,
    ActionDescription TEXT,
    Comments TEXT,
    CreatedTime DATETIME,
    ResolvedBy VARCHAR(100),
    ResolvedTime DATETIME,
    EscalatedTo INT,  -- 0: not escalated, >0: user ID
    FalsePositive INT,  -- 0: no, 1: yes
    AssignedTo VARCHAR(100),
    AlertScore FLOAT,
    Helpful INT,  -- 0: No, 1: Yes
    RecommendationId INT,
    RecommendationVersion INT,
    RuleName VARCHAR(255),
    Filter TEXT,
    RuleTitle TEXT,
    RuleDescription TEXT,
    AutoResolve INT,  -- 0: No, 1: Yes
    Recurrence INT,
    EnableInstructions INT,  -- 0: No, 1: Yes
    EnableFields INT,  -- 0: No, 1: Yes
    Priority INT,  -- 1: Low, 2: Medium, 3: High
    LogAllData INT,  -- 0: No, 1: Yes
    IsSoftDeleted INT,
    RuleScoreFactor FLOAT,
    OptionalFactor FLOAT,
    RecommendationName VARCHAR(255),
    RecommendationScoreFactor FLOAT,
    CategoryName VARCHAR(255),
    CompanyId INT,
    CategoryScoreFactor FLOAT
);

-- AI_AlertData Table
CREATE TABLE AI_AlertData (
    AlertId INT,
    Description VARCHAR(255),  -- Name for the relevant data of RecommendationAlertData
    Value TEXT,  -- Values for the relevant data of the RecommendationAlertData table
    AlertTimestamp DATETIME
);

-- AI_ControlValue Table
CREATE TABLE AI_ControlValue (
    ControlId INT,
    AlertId INT,
    Name VARCHAR(255),  -- from Control.Caption
    Value TEXT,
    LastModified DATETIME
);

# AI Recommendation and Alert Schema Context

## Table Relationships
- `AI_RecommendationAlertData` is the main table, containing the core information about alerts and recommendations.
- `AI_AlertData` contains additional data related to specific alerts. It is linked to `AI_RecommendationAlertData` through the `AlertId` field.
- `AI_ControlValue` stores control values associated with alerts. It is also linked to `AI_RecommendationAlertData` through the `AlertId` field.

## AI_RecommendationAlertData Table

This table stores the main data for AI-generated recommendation alerts.

Key fields and their meanings:
- `ID`: Unique identifier for each alert
- `RuleId`: Identifier for the rule that triggered this alert
- `EntityId` and `AssetId`: Identifiers for the entity and asset against which the alert was triggered
- `Status`: 0 for active alerts, 1 for resolved alerts
- `IsRecommendationClosed`: 0 for open recommendations, 1 for closed recommendations
- `Title`: The alert heading or title
- `Description`: Detailed description of the alert
- `CreatedTime`: When the alert was created
- `ResolvedTime`: When the alert was resolved (if applicable)
- `EscalatedTo`: User ID to which an alert is escalated (0 if not escalated)
- `FalsePositive`: 0 if the alert is valid, 1 if its a false positive
- `AlertScore`: The total score for this alert
- `RecommendationId` and `RecommendationVersion`: Identify the specific recommendation that triggered this alert
- `Priority`: 1 for Low, 2 for Medium, 3 for High priority
- `CompanyId`: Identifier for the company associated with this alert

## AI_AlertData Table

This table contains additional data related to specific alerts.

Key fields:
- `AlertId`: Links to the `ID` in `AI_RecommendationAlertData`
- `Description`: Name or description of the additional data point
- `Value`: The actual value of the additional data point
- `AlertTimestamp`: When this additional data was recorded

## AI_ControlValue Table

This table stores control values associated with alerts, typically used for user interface elements or additional metadata.

Key fields:
- `ControlId`: Unique identifier for each control value
- `AlertId`: Links to the `ID` in `AI_RecommendationAlertData`
- `Name`: The name or caption of the control (e.g., a field label)
- `Value`: The value associated with this control
- `LastModified`: When this control value was last updated

## Common Query Scenarios

1. Retrieving active alerts for a specific asset
2. Finding high-priority alerts that havent been resolved
3. Identifying false positive alerts
4. Tracking resolution times for alerts
5. Analyzing alert trends over time
6. Fetching all data related to a specific alert (including associated AlertData and ControlValue entries)

# Your Role
Your role is to create safe, efficient, and accurate SELECT queries only, based on this schema. Adhere to these guidelines:

1. Security: Generate ONLY SELECT queries. Any form of data modification is prohibited.
2. Performance: Aim for efficient queries, using appropriate indexing and avoiding unnecessary joins or subqueries when possible.
3. Clarity: Write clear, well-formatted SQL with proper indentation and meaningful aliases.
4. Accuracy: Ensure the query accurately reflects the users intent and handles potential edge cases.
5. Explanation: Always provide a brief explanation of your query, including any assumptions made.
6. Format: Enclose your SQL query within an artifact tag as follows: ```sql ```

If you cannot generate a valid SELECT query for the request, explain why and suggest alternatives or clarifications needed from the user. Always prioritize data integrity and system security in your responses."',
    reserved_fields: ["user_query"]
})
CREATE (tl)-[:CONTAINS]->(sql)

// Create Time and Date Tool
CREATE (time:Tool {
    name: 'TimeAndDateTool',
    description: 'Performs time-related operations such as time zone conversions and date calculations.',
    class_name: 'TimeAndDateTool',
    created_date: datetime(),
    last_modified_date: datetime(),
    options: '{"defaultTimeZone": "UTC"}'
})
CREATE (tl)-[:CONTAINS]->(time)

// Create DuckDuckGo Web Search Tool
CREATE (duckduckgo:Tool {
    name: 'DuckDuckGoWebSearchTool',
    description: 'Performs a web search using DuckDuckGo and returns relevant information',
    class_name: 'DuckDuckGoWebSearchTool',
    created_date: datetime(),
    last_modified_date: datetime(),
    options: '{"maxResults": 5, "safeSearch": true}'
})
CREATE (tl)-[:CONTAINS]->(duckduckgo)

// Create Bing Web Search Tool
CREATE (bing:Tool {
    name: 'BingWebSearchTool',
    description: 'Performs a web search using Bing and returns relevant information',
    class_name: 'BingWebSearchTool',
    created_date: datetime(),
    last_modified_date: datetime(),
    options: '{"maxResults": 5, "safeSearch": true, "apiKey": ""}'
})
CREATE (tl)-[:CONTAINS]->(bing)

// Create Google Web Search Tool
CREATE (google:Tool {
    name: 'GoogleWebSearchTool',
    description: 'Performs a web search using Google and returns relevant information',
    class_name: 'GoogleWebSearchTool',
    created_date: datetime(),
    last_modified_date: datetime(),
    options: '{"maxResults": 5, "safeSearch": true, "apiKey": "", "searchEngineId": ""}'
})
CREATE (tl)-[:CONTAINS]->(google)

// Create Sentiment Analysis Tool
CREATE (sentiment:Tool {
    name: 'SentimentAnalysisTool',
    description: 'Analyzes the sentiment of the given text and returns a sentiment score.',
    class_name: 'SentimentAnalysisTool',
    created_date: datetime(),
    last_modified_date: datetime(),
    options: '',
    model_provider: 'Ollama',
    model_name: 'llama3',
    max_tokens: 2000,
    prompt_user:'{user_query}',
    prompt_system: 'Analyze the sentiment of the following text and provide a sentiment score between -1 (very negative) and 1 (very positive), along with a brief explanation.',
    reserved_fields: ["user_query"]
})
CREATE (tl)-[:CONTAINS]->(sentiment)

// Create initial aggregate metrics for each tool
WITH tl
MATCH (t:Tool)
CREATE (t)-[:HAS_METRICS]->(m:Metrics {
    type: 'Aggregate',
    created_date: datetime(),
    last_modified_date: datetime(),
    total_calls: 0,
    total_response_time: 0,
    total_token_usage: 0,
    successful_calls: 0,
    failed_calls: 0,
    total_data_processed: 0,
    average_response_time: 0
})
```

### 5. Agent Profiles
[To be added]

#### Create Profiles

#### Load Profiles

## Troubleshooting

## Next Steps

After completing the installation, access the prompt administration page and ensure the system prompts are using the models providers and models you have enabled.