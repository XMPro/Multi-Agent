# XMPro AI Agents Installation Guide

This guide provides detailed instructions for setting up the XMPro AI Agents system.

## Required Prerequisites

- A licensed installation of XMPro
- Neo4j Graph Database
- Milvus or Qdrant Vector Database (Multiple collection support)
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

Run the following commands in your Neo4j database to create necessary constraints and indexes:

```cypher
CREATE CONSTRAINT agent_profile_id_unique IF NOT EXISTS FOR (p:AgentProfile) REQUIRE p.profile_id IS UNIQUE;
CREATE CONSTRAINT agent_instance_id_unique IF NOT EXISTS FOR (a:AgentInstance) REQUIRE a.agent_id IS UNIQUE;
CREATE CONSTRAINT memory_id_unique IF NOT EXISTS FOR (m:Memory) REQUIRE m.id IS UNIQUE;
CREATE CONSTRAINT prompt_id_unique IF NOT EXISTS FOR (p:Prompt) REQUIRE p.prompt_id IS UNIQUE;
CREATE CONSTRAINT tool_name_unique IF NOT EXISTS FOR (t:Tool) REQUIRE t.name IS UNIQUE;
CREATE CONSTRAINT decision_id_unique IF NOT EXISTS FOR (d:Decision) REQUIRE d.decision_id IS UNIQUE;
CREATE CONSTRAINT artifact_id_unique IF NOT EXISTS FOR (a:Artifact) REQUIRE a.id IS UNIQUE;
CREATE CONSTRAINT plan_id_unique IF NOT EXISTS FOR (p:Artifact) REQUIRE (p.id IS UNIQUE AND p.type = 'Plan');

CREATE INDEX team_id_idx IF NOT EXISTS FOR (t:Team) ON (t.team_id);
CREATE INDEX memory_created_date_idx IF NOT EXISTS FOR (m:Memory) ON (m.created_date);
CREATE INDEX memory_type_idx IF NOT EXISTS FOR (m:Memory) ON (m.type);
CREATE INDEX memory_importance_idx IF NOT EXISTS FOR (m:Memory) ON (m.importance);
CREATE INDEX prompt_internal_name_idx IF NOT EXISTS FOR (p:Prompt) ON (p.internal_name);
CREATE INDEX prompt_id_idx IF NOT EXISTS FOR (p:Prompt) ON (p.prompt_id);
CREATE INDEX artifact_type_idx IF NOT EXISTS FOR (a:Artifact) ON (a.type);
CREATE INDEX plan_status_idx IF NOT EXISTS FOR (p:Artifact) ON (p.status) WHERE p.type = 'Plan';
CREATE INDEX plan_active_idx IF NOT EXISTS FOR (p:Artifact) ON (p.active) WHERE p.type = 'Plan';
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
  models_providers: ['Anthropic', 'AzureOpenAI', 'Google', 'Ollama', 'OpenAI'],
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

Execute the following Cypher query to set up system prompts:

```cypher
// Create Prompt Library
MERGE (p:Library {name: "Main Prompt Library"})
ON CREATE SET p.type = "Prompt", p.created_date = datetime()

// Create Prompts
CREATE (p1:Prompt {
  prompt_id: "XMAGS-TOOLRESULT-PROMPT-001",
  name: "Tool Results",
  internal_name: "tool_results_prompt",
  prompt: "
Based on the following information:

Original prompt: {original_prompt}

Previous response: {previous_response}

Please provide an updated response.
  ",
  reserved_fields: ["original_prompt", "previous_response"],
  author: "XMPro",
  created_date: datetime(),
  last_modified_date: datetime(),
  active: true,
  version: 1,
  type: "system",
  category: "memory_cycle",
  tags: ["observation", "reflection"],
  description: "Instructs the AI to provide an updated response based on the results of tool usage.",
  last_used_date: null,
  model_provider: "Ollama",
  model_name: "llama3",
  max_tokens: 2000,
  access_level: "system"
}),
(p)-[:CONTAINS]->(p1)

CREATE (p2:Prompt {
  prompt_id: "XMAGS-CONVERSATION-PROMPT-001",
  name: "Conversation",
  internal_name: "conversation_prompt",
  prompt: "Current timestamp: {current_timestamp}

Conversation history:
{conversation_history}

Context information:
{knowledge_context}

Available tools:
{available_tools}

To suggest a tool for use, include 'SUGGEST_TOOL: ToolName: <the user's original question>' in your response.

Current user input: {user_query}

Please provide a response that:
1. Addresses the user's input directly.
2. Incorporates relevant information from the conversation history and context.
3. IMPORTANT: Suggests available tools when necessary to provide accurate and helpful information. Always use the syntax 'SUGGEST_TOOL: ToolName: <user's original question>' when suggesting a tool. Do not attempt to create or modify queries yourself. Pass the user's question directly to the tool.
4. Maintains a consistent and appropriate tone throughout the conversation.
5. Asks for clarification if the user's intent is unclear.
6. Does not include any additional comments about running the query or needing confirmation.
7. CRITICAL: Do not provide any information that you don't have direct access to. Do not assume or fabricate any data or results. If you need information to answer the question, only suggest using a tool to obtain it.

Your response must include at least one tool suggestion if relevant to answering the query. Do not provide any fake or assumed results from tool usage. Do not speculate about what the results might be. Do not ask for confirmation to use the tool.  

Begin your response now:",
  reserved_fields: ["current_timestamp", "conversation_history", "knowledge_context", "available_tools", "user_query"],
  author: "XMPro",
  created_date: datetime(),
  last_modified_date: datetime(),
  active: true,
  version: 1,
  type: "system",
  category: "conversation",
  tags: ["conversation"],
  description: "Guides the AI in generating contextual responses during conversations, considering history, available tools, and user input.",
  last_used_date: null,
  model_provider: "Ollama",
  model_name: "llama3",
  max_tokens: 2000,
  access_level: "system"
}),
(p)-[:CONTAINS]->(p2)

CREATE (p3:Prompt {
  prompt_id: "XMAGS-CONVOSUMMARY-PROMPT-001",
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
  tags: ["conversation"],
  description: "Instructs the AI to create a concise summary of a conversation for future reference.",
  last_used_date: null,
  model_provider: "Ollama",
  model_name: "llama3",
  max_tokens: 2000,
  access_level: "system"
}),
(p)-[:CONTAINS]->(p3)

CREATE (p4:Prompt {
  prompt_id: "XMAGS-CONVOOBSERVE-PROMPT-001",
  name: "Conversation Observation",
  internal_name: "conversation_observation_prompt",
  prompt: "Analyze the following response and determine if it contains information that warrants creating a new observation. Consider the following criteria:

1. Significance: Does the response contain important or novel information?
2. Relevance: Is the information directly related to the agent's tasks or goals?
3. Actionability: Does the information suggest potential actions or decisions?
4. Complexity: Is the information complex enough to benefit from further analysis?

Response to analyze:
{response}

Based on these criteria, should a new observation be created? Respond with only 'Yes' or 'No'.",
  reserved_fields: ["response"],
  author: "XMPro",
  created_date: datetime(),
  last_modified_date: datetime(),
  active: true,
  version: 1,
  type: "system",
  category: "conversation",
  tags: ["conversation", "observation"],
  description: "Directs the AI to analyze a conversation response and determine if it warrants creating a new observation.",
  last_used_date: null,
  model_provider: "Ollama",
  model_name: "llama3",
  max_tokens: 2000,
  access_level: "system"
}),
(p)-[:CONTAINS]->(p4)

CREATE (p5:Prompt {
  prompt_id: "XMAGS-MEMORYIMPORTANT-PROMPT-001",
  name: "Memory Importance",
  internal_name: "importance_prompt",
  prompt: "Rate the importance of the following observation on a scale of 0 to 1, where 0 is completely unimportant and 1 is extremely important. The threshold for importance is {threshold}:

{content}

Importance score:",
  reserved_fields: ["threshold", "content"],
  author: "XMPro",
  created_date: datetime(),
  last_modified_date: datetime(),
  active: true,
  version: 1,
  type: "system",
  category: "memory_cycle",
  tags: ["conversation", "observation"],
  description: "Asks the AI to rate the importance of an observation or reflection on a scale of 0 to 1.",
  last_used_date: null,
  model_provider: "Ollama",
  model_name: "llama3",
  max_tokens: 2000,
  access_level: "system"
}),
(p)-[:CONTAINS]->(p5)

CREATE (p6:Prompt {
  prompt_id: "XMAGS-PLANDECISION-PROMPT-001",
  name: "Plan Decision",
  internal_name: "plan_decision_prompt",
  prompt: "Based on the following information, decide if a new plan is needed or if the current plan should be adjusted or if the current plan is sufficient:

### Current plan: 
{current_plan}

### Current state: 
{current_state}

### Adaptation factors: 
{adaptation_factors}

### New goal from reflections: 
{new_goal_from_reflections}

### Current plan valid: 
{current_plan_valid}

### Initial assessment: 
{initial_assessment}

## Response Format
Provide your decision as 'Yes' for a new plan or a plan adjustment is needed or 'No' if no plan is needed or the current plan is sufficient. 
[Reply ONLY Yes/No]
### Explanation
[provide a brief explanation for your decision]",
  reserved_fields: ["current_plan", "current_state", "adaptation_factors", "new_goal_from_reflections", "current_plan_valid", "initial_assessment"],
  author: "XMPro",
  created_date: datetime(),
  last_modified_date: datetime(),
  active: true,
  version: 1,
  type: "system",
  category: "plan",
  tags: ["plan", "reflection"],
  description: "Directs the AI to decide whether a new plan is needed or if the current plan should be adjusted based on various factors",
  last_used_date: null,
  model_provider: "Ollama",
  model_name: "llama3",
  max_tokens: 2000,
  access_level: "system"
}),
(p)-[:CONTAINS]->(p6)

CREATE (p7:Prompt {
  prompt_id: "XMAGS-PLANREFLECT-PROMPT-001",
  name: "Planning Reflection",
  internal_name: "planning_reflection_analysis_prompt",
  prompt: "Analyze the following recent reflections and determine if a new goal is needed. Consider the current plan and goals when making your decision.
        
Recent reflections:
{recent_reflections}
        
Current goals: 
{current_goals}
        
Current plan:
{current_plan}

## Response Format
'Yes/No' 
### New goal
[goal statement if a new plan or an update is needed].

Provide a brief explanation for your decision, considering how the recent reflections align with or diverge from the current plan and goals.",
  reserved_fields: ["recent_reflections", "current_goals", "current_plan"],
  author: "XMPro",
  created_date: datetime(),
  last_modified_date: datetime(),
  active: true,
  version: 1,
  type: "system",
  category: "plan",
  tags: ["plan", "reflection"],
  description: "Guides the AI in analyzing recent reflections to determine if a new goal is needed.",
  last_used_date: null,
  model_provider: "Ollama",
  model_name: "llama3",
  max_tokens: 2000,
  access_level: "system"
}),
(p)-[:CONTAINS]->(p7)

CREATE (p8:Prompt {
  prompt_id: "XMAGS-PLANCHANGERSS-PROMPT-001",
  name: "Planning Change Resources",
  internal_name: "planning_resource_changes_prompt",
  prompt: "Analyze the current plan, its goal, and the agent's available resources. 
Identify any resource changes that might require plan adaptation:
Current Plan Goal: {plan_goal}
Agent Resources:
- Available Tools: {available_tools}
Consider the following:
1. Are all tools necessary for achieving the plan's goal still available?
2. Are there new tools available that could help achieve the goal more efficiently?
3. Have any changes in tool availability significantly impacted the feasibility of achieving the goal?

Provide a list of adaptation factors in the following structured format:

## Response Format

1. Description: [Describe the adaptation factor]
   Impact Level: [High/Medium/Low]
   Recommended Action: [Describe the recommended action]
2. Description: [Describe the adaptation factor]
   Impact Level: [High/Medium/Low]
   Recommended Action: [Describe the recommended action]
[Continue with additional factors as needed]

Focus on how changes in tool availability might affect the agent's ability to achieve the stated goal. Ensure each factor is numbered and follows the exact format provided above.",
  reserved_fields: ["plan_goal", "available_tools"],
  author: "XMPro",
  created_date: datetime(),
  last_modified_date: datetime(),
  active: true,
  version: 1,
  type: "system",
  category: "plan",
  tags: ["plan"],
  description: "Directs the AI to identify resource changes that might require plan adaptation.",
  last_used_date: null,
  model_provider: "Ollama",
  model_name: "llama3",
  max_tokens: 2000,
  access_level: "system"
}),
(p)-[:CONTAINS]->(p8)

CREATE (p9:Prompt {
  prompt_id: "XMAGS-PLANCHANGETIME-PROMPT-001",
  name: "Planning Change Time",
  internal_name: "planning_time_constraints_prompt",
  prompt: "Analyze the current plan, its goal, and time constraints. Identify any time-related issues that might require plan adaptation:

Current Plan Goal: {plan_goal}
Current Time: {current_time}

Consider how any changes in time constraints might affect the agent's ability to achieve the stated goal.

Provide a list of adaptation factors in the following structured format:

## Response Format

1. Description: [Describe the adaptation factor]
   Impact Level: [High/Medium/Low]
   Recommended Action: [Describe the recommended action]
2. Description: [Describe the adaptation factor]
   Impact Level: [High/Medium/Low]
   Recommended Action: [Describe the recommended action]
[Continue with additional factors as needed]

Focus on how changes in timing might affect the agent's ability to achieve the stated goal. Ensure each factor is numbered and follows the exact format provided above.",
  reserved_fields: ["plan_goal", "current_time"],
  author: "XMPro",
  created_date: datetime(),
  last_modified_date: datetime(),
  active: true,
  version: 1,
  type: "system",
  category: "plan",
  tags: ["plan"],
  description: "Instructs the AI to analyze time-related issues that might necessitate plan adaptation.",
  last_used_date: null,
  model_provider: "Ollama",
  model_name: "llama3",
  max_tokens: 2000,
  access_level: "system"
}),
(p)-[:CONTAINS]->(p9)

CREATE (p10:Prompt {
  prompt_id: "XMAGS-PLANCHANGEINFO-PROMPT-001",
  name: "Planning Change New Information",
  internal_name: "planning_new_information_prompt",
  prompt: "Analyze the current plan, its goal, and recent memories. Identify any new information that might require plan adaptation:

Current Plan Goal: {plan_goal}
Recent Memories: {recent_memories}

Consider how any new information might affect the agent's ability to achieve the stated goal.

Provide a list of adaptation factors in the following structured format:

## Response Format

1. Description: [Describe the adaptation factor]
   Impact Level: [High/Medium/Low]
   Recommended Action: [Describe the recommended action]
2. Description: [Describe the adaptation factor]
   Impact Level: [High/Medium/Low]
   Recommended Action: [Describe the recommended action]
[Continue with additional factors as needed]

Focus on how new information might affect the agent's ability to achieve the stated goal. Ensure each factor is numbered and follows the exact format provided above.",
  reserved_fields: ["plan_goal", "recent_memories"],
  author: "XMPro",
  created_date: datetime(),
  last_modified_date: datetime(),
  active: true,
  version: 1,
  type: "system",
  category: "plan",
  tags: ["plan"],
  description: "Guides the AI in identifying new information that might require plan adaptation.",
  last_used_date: null,
  model_provider: "Ollama",
  model_name: "llama3",
  max_tokens: 2000,
  access_level: "system"
}),
(p)-[:CONTAINS]->(p10)

CREATE (p11:Prompt {
  prompt_id: "XMAGS-PLANPROBLEMUNDERSTAND-PROMPT-001",
  name: "Planning Understanding Problem",
  internal_name: "plan_understand_problem_prompt",
  prompt: "Analyze the following goal and provide a concise summary of the key elements, objectives, and constraints, considering the capabilities of the team:

Goal: {goal}

Team Capabilities:
{team_capabilities}

Your response should include:
1. A brief restatement of the main objective
2. Identification of key components or sub-goals
3. Any implicit or explicit constraints
4. Potential challenges or considerations
5. How different team members' capabilities might be leveraged to achieve the goal

Provide your analysis in a clear, structured format.",
  reserved_fields: ["goal", "team_capabilities"],
  author: "XMPro",
  created_date: datetime(),
  last_modified_date: datetime(),
  active: true,
  version: 1,
  type: "system",
  category: "plan",
  tags: ["plan"],
  description: "Guides the AI in analyzing a goal and team capabilities to provide a comprehensive problem understanding.",
  last_used_date: null,
  model_provider: "Ollama",
  model_name: "llama3",
  max_tokens: 2000,
  access_level: "system"
}),
(p)-[:CONTAINS]->(p11)

CREATE (p12:Prompt {
  prompt_id: "XMAGS-PLANPDDL-PROMPT-001",
  name: "Planning Generate PDDL",
  internal_name: "plan_generate_pddl_prompt",
  prompt: "Given the following goal, problem understanding, team capabilities, and available actions, generate a complete PDDL plan:

Goal: {goal}
Problem Understanding:
{understanding}

Team Capabilities:
{team_capabilities}

Available Actions:
{available_actions}

Your response should include the following PDDL components, each clearly labeled and properly formatted:

1. PDDL Domain Definition:
   - Define appropriate types
   - List all predicates
   - Detail each action, including:
     - Parameters
     - Preconditions
     - Effects
   Note: Only include actions from the Available Actions list.

2. PDDL Problem Definition:
   - Define objects
   - Specify the initial state
   - State the goal condition

3. PDDL Plan:
   - Provide a sequence of actions that solve the problem
   - Assign each action to a specific team member based on their capabilities
   - Ensure the plan is valid and achieves the stated goal
   - Only use actions defined in the domain and listed in Available Actions

4. Plan Validation:
   - Briefly explain why the plan is valid and how it achieves the goal
   - If a valid plan cannot be generated, explain why and suggest what additional information or actions might be needed

5. Optional: Efficiency Analysis
   - Comment on the efficiency of the plan
   - Suggest any potential optimizations or alternative approaches

Please use proper PDDL syntax for each component. Separate each section clearly and use comments to explain any complex parts of the domain, problem, or plan.

Example structure:

```
;; Domain Definition
(define (domain domain-name)
  (:requirements :typing :negative-preconditions)
  (:types
    ; List types here
  )
  (:predicates
    ; List predicates here
  )
  (:action action-name
    :parameters ()
    :precondition ()
    :effect ()
  )
  ; Add more actions as needed
)

;; Problem Definition
(define (problem problem-name)
  (:domain domain-name)
  (:objects
    ; List objects here
  )
  (:init
    ; Specify initial state here
  )
  (:goal
    ; State goal condition here
  )
)

;; Plan
; Action 1: (action-name parameters) ; Assigned to: Team Member
; Action 2: (action-name parameters) ; Assigned to: Team Member
; ...
```

Ensure that all PDDL elements are syntactically correct and logically consistent with the given goal, problem understanding, and team capabilities.",
  reserved_fields: ["goal", "team_capabilities", "understanding", "available_actions"],
  author: "XMPro",
  created_date: datetime(),
  last_modified_date: datetime(),
  active: true,
  version: 1,
  type: "system",
  category: "plan",
  tags: ["plan"],
  description: "Directs the AI to create a complete PDDL plan based on a goal, problem understanding, and team capabilities.",
  last_used_date: null,
  model_provider: "Ollama",
  model_name: "llama3",
  max_tokens: 2000,
  access_level: "system"
}),
(p)-[:CONTAINS]->(p12)

CREATE (p13:Prompt {
  prompt_id: "XMAGS-PLANSOLVEADJ-PROMPT-001",
  name: "Plan Solve Adjustment",
  internal_name: "plan_solve_adjustment_prompt",
  prompt: "Given the current plan and a new planning decision, adjust the PDDL plan to incorporate the new goal while maintaining relevant parts of the current plan:

Current Plan:
Goal: {current_goal}
PDDL Plan: 
```
{current_pddl_plan}
```

New Planning Decision:
Goal: {new_goal}
Reasoning: {decision_reasoning}

Please provide an adjusted PDDL plan that incorporates the new planning decision. Your response should include:

1. Updated PDDL Domain Definition (if necessary):
   - Highlight any new types, predicates, or actions added
   - Explain why these additions are necessary

2. Updated PDDL Problem Definition:
   - Show changes to the initial state or objects (if any)
   - Clearly state the new goal condition

3. Adjusted PDDL Plan:
   - Provide the full sequence of actions in the new plan
   - Highlight which actions are new or modified
   - Explain how these changes address the new goal

4. Reasoning:
   - Briefly explain how the adjusted plan incorporates the new planning decision
   - Describe which parts of the original plan were maintained and why
   - Justify any significant changes or removals from the original plan

Please use proper PDDL syntax for all components. Separate each section clearly and use comments to explain any complex adjustments or reasoning.

Example structure for your response:

```
;; Updated Domain Definition (if necessary)
(define (domain updated-domain-name)
  ; ... (include full updated domain definition)
  ; Use comments to explain new or modified elements
)

;; Updated Problem Definition
(define (problem updated-problem-name)
  ; ... (include full updated problem definition)
  ; Clearly show the new goal condition
)

;; Adjusted Plan
; Action 1: (action-name parameters) ; New/Modified/Unchanged
; Action 2: (action-name parameters) ; New/Modified/Unchanged
; ...

;; Reasoning
; Explain adjustments and their rationale here
```

Ensure that all PDDL elements are syntactically correct and logically consistent with both the original plan and the new planning decision.",
  reserved_fields: ["current_goal", "current_pddl_plan", "new_goal", "decision_reasoning"],
  author: "XMPro",
  created_date: datetime(),
  last_modified_date: datetime(),
  active: true,
  version: 1,
  type: "system",
  category: "plan",
  tags: ["plan", "plan_solve"],
  description: "Instructs the AI to adjust an existing PDDL plan to incorporate new goals or planning decisions.",
  last_used_date: null,
  model_provider: "Ollama",
  model_name: "llama3",
  max_tokens: 2000,
  access_level: "system"
}),
(p)-[:CONTAINS]->(p13)

```

### 4. Tools Library Installation
Execute the following Cypher query to set up the tool options:

Edit the `SentimentAnalysisTool` to ensure it matches your environment on what you are enabling as model providers.

For example if you are using *Ollama* then it should read as `models_providers: 'Ollama'`, there can only be one provider and model configured.


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
Agent profiles are essential components of the XMPro AI Agents system, defining the characteristics, capabilities, and behavior of each agent. They serve as templates for creating agent instances.

#### Create Profiles
XMPro MAGS provides a user-friendly interface for creating and managing agent profiles. You have three main options for creating profiles:

1. **Wizard Creation**: 
   The Team Creation or the Profile Creation Wizard guides you through the process of creating a new agent profile step-by-step. This option is ideal for users who are new to the system or prefer a guided approach. The wizard includes the following steps:

   a. **Basic Information**: 
      - Enter the agent's name and profile ID (following the naming convention).
      - Select the agent's primary function (e.g., Water Quality Management, Predictive Maintenance).
      - Choose the active status of the profile.

   b. **Model Configuration**:
      - Select the model provider and specific model to be used.
      - Set the maximum token limit for responses.

   c. **Cognitive Parameters**:
      - Define decision parameters like collaboration preference and risk tolerance.
      - Set memory parameters such as max recent memories and importance thresholds.

   d. **Skills and Experience**:
      - Add relevant skills from a predefined list or create custom skills.
      - Describe the agent's simulated experience.

   e. **Rules and Prompts**:
      - Add deontic and organizational rules.
      - Customize observation, reflection, and system prompts using templates.

   f. **RAG Configuration**:
      - Set up Retrieval-Augmented Generation parameters.
      - Choose whether to use general RAG or specify a collection.

   g. **Review and Create**:
      - Review all entered information.
      - Create the profile or go back to make changes.

2. **Manual Creation**: 
   Use the agent profile creation UI to manually input all the necessary details for a new agent profile. This option provides more flexibility and is suitable for experienced users who want fine-grained control over all aspects of the profile.

3. **Import Existing**: 
   Import pre-configured agent profiles from JSON files. This is useful for quickly setting up profiles that have been prepared in advance or for transferring profiles between different instances of the system.

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
      "reflection_importance_threshold": 8
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
