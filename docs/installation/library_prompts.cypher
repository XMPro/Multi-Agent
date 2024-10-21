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
   - If a valid plan cannot be generated, explain why and suggest what additional information or actions might be needed",
  reserved_fields: ["goal", "understanding", "team_capabilities", "available_actions"],
  author: "XMPro",
  created_date: datetime(),
  last_modified_date: datetime(),
  active: true,
  version: 1,
  type: "system",
  category: "plan",
  tags: ["plan"],
  description: "Creates a comprehensive PDDL plan based on given parameters and constraints.",
  last_used_date: null,
  model_provider: "Ollama",
  model_name: "llama3",
  max_tokens: 2000,
  access_level: "system"
}),
(p)-[:CONTAINS]->(p12)