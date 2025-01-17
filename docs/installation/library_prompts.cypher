// Create Prompt Library
MERGE (p:Library {name: "Main Prompt Library"})
ON CREATE SET p.type = "Prompt", p.created_date = datetime()

// Create Prompts
CREATE (p1:Prompt {
  prompt_id: "XMAGS-TOOLRESULT-PROMPT-001",
  name: "Tool Results",
  internal_name: "tool_results_prompt",
  prompt: "Based on the following information:

{original_prompt}

Previous response: 
{previous_response}

<instructions>
Please provide an updated response.  
If you are provided information from the tools make sure to include that in your response.  
Summarise the tools and output the results of the tools in markdown that the user can understand as part of your response, if you are provided telemetry style data output it as a markdown table.
<instructions>",
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
  model_provider: "OpenAI",
  model_name: "gpt-4o-mini",
  max_tokens: 2000,
  access_level: "system"
}),
(p)-[:CONTAINS]->(p1)

CREATE (p2:Prompt {
  prompt_id: "XMAGS-CONVERSATION-PROMPT-001",
  name: "Conversation",
  internal_name: "conversation_prompt",
  prompt: "Current timestamp: {current_timestamp}
Current user input: {user_query}

Context information:
{knowledge_context}

<tools>
Available tools:
{available_tools}

Use the keywords in the available tools if there are any, to find a tool thats appropriate.
To suggest a tool for use, include SUGGEST_TOOL: [ToolName] - [the users original question] in your response.  
IF the tool you are suggesting is [XMPro Data Stream Tool] then the format to use is SUGGEST_TOOL: [ToolName] (Data Stream) - [the users original question] in your response.  
</tools>

<instructions>
Please provide a response that:

1. ALWAYS BEGIN YOUR RESPONSE WITH AN ASSET SUMMARY SECTION:
   ```
   ASSET SUMMARY:
   Asset IDs Found: [List all unique asset IDs from context and history]
   Part Numbers Found: [List all unique part numbers]
   Location Names Found: [List all unique locations]
   Model Numbers Found: [List all unique model numbers]
   Additional Identifiers: [Any other relevant identifiers]
   ```

2. When referencing assets in your response:
   - Always use the full identifier format: [Asset ID] ([Part/Model Number]) at [Location]
   - Include all available identifier information for each asset mentioned
   - If any identifier information is missing, explicitly note this

3. Addresses the users input directly while maintaining consistent asset identification.

4. Incorporates relevant information from the conversation history and context:
   - When citing historical data, include the timestamp
   - Maintain chronological organization of information
   - Preserve all asset identifiers when referencing historical data

5. IMPORTANT: Suggests available tools when necessary to provide accurate and helpful information:
   - Always use the syntax 'SUGGEST_TOOL: ToolName: [the users original question]'
   - Do not modify queries yourself
   - Pass the users question directly to the tool
   - Suggest tools specifically for missing asset information

6. Maintains a consistent and appropriate tone throughout the conversation.

7. Asks for clarification if the users intent is unclear.

8. Does not include any additional comments about running the query or needing confirmation.

9. CRITICAL: Do not provide any information that you don't have direct access to:
   - Do not assume or fabricate any data or results
   - If you need information to answer the question, only suggest using a tool to obtain it
   - Never infer or guess at asset identifiers

10. Format all numerical data consistently:
    - Include units of measurement
    - Use consistent decimal places
    - Include measurement timestamps

11. Present information in a structured format:
    - Group data by asset ID
    - Use tables or lists for multiple metrics
    - Highlight any changes in asset information across timestamps

Your response must include at least one tool suggestion if relevant to answering the query. Do not provide any fake or assumed results from tool usage. Do not speculate about what the results might be. Do not ask for confirmation to use the tool.  
</instructions>

<Conversation history>
{conversation_history}
</Conversation history>",
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
  model_provider: "OpenAI",
  model_name: "gpt-4o-mini",
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
  model_provider: "OpenAI",
  model_name: "gpt-4o-mini",
  max_tokens: 2000,
  access_level: "system"
}),
(p)-[:CONTAINS]->(p3)

CREATE (p4:Prompt {
  prompt_id: "XMAGS-CONVOOBSERVE-PROMPT-001",
  name: "Conversation Observation",
  internal_name: "conversation_observation_prompt",
  prompt: "Analyze the following response and recent agent memories to determine if a NEW observation should be created. Consider both chronological and semantically similar memories.

1. Significance: Does the response contain important or novel information?
2. Relevance: Is the information directly related to the agent's tasks or goals?
3. Actionability: Does the information suggest potential actions or decisions?
4. Novelty: How does this information compare to:
   - Recent memories (chronological)
   - Similar memories (semantic)
5. Context: How does this information enhance or modify existing knowledge?
6. If there is already an Obseration or Reflection for this information we dont need to create a new one.

Recent chronological memories:
{time_ordered_memories}

Semantically similar memories:
{similar_memories}

Current response to analyze:
{response}

Based on these criteria, should a new observation be created? Respond with 'Yes' or 'No'.

Reasoning:
[Provide brief explanation considering both chronological and semantic context]",
  reserved_fields: ["time_ordered_memories", "response", "similar_memories"],
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
  model_provider: "OpenAI",
  model_name: "gpt-4o-mini",
  max_tokens: 2000,
  access_level: "system"
}),
(p)-[:CONTAINS]->(p4)

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
  model_provider: "OpenAI",
  model_name: "gpt-4o-mini",
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
  model_provider: "OpenAI",
  model_name: "gpt-4o-mini",
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
  model_provider: "OpenAI",
  model_name: "gpt-4o-mini",
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
  model_provider: "OpenAI",
  model_name: "gpt-4o-mini",
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
  model_provider: "OpenAI",
  model_name: "gpt-4o-mini",
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
  model_provider: "OpenAI",
  model_name: "gpt-4o-mini",
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
  model_provider: "OpenAI",
  model_name: "gpt-4o-mini",
  max_tokens: 2000,
  access_level: "system"
}),
(p)-[:CONTAINS]->(p12)

CREATE (p13:Prompt {
  prompt_id: "XMAGS-PLANSOLVEADJ-PROMPT-001",
  name: "Plan & Solve Adjustment",
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
  tags: ["plan"],
  description: "Adjust a plan based on the planning decision.",
  last_used_date: null,
  model_provider: "OpenAI",
  model_name: "gpt-4o-mini",
  max_tokens: 2000,
  access_level: "system"
}),
(p)-[:CONTAINS]->(p13)

CREATE (p14:Prompt {
  prompt_id: "XMAGS-DSTOOL-PROMPT-001",
  name: "Data Stream Tool",
  internal_name: "data_stream_message_prompt",
  prompt: "Generate message payloads that STRICTLY conform to ONLY the structure defined between the <structure> tags.
Input: {input}

<structure>
{structure}
<structure>

Requirements:
- Output MUST be valid JSON array of messages
- Each message MUST ONLY contain the exact fields defined in the <structure> tags
- NO additional fields or structures are allowed
- NO variation from the defined structure is permitted
- Return ONLY the formatted JSON array with messages matching the exact structure
- Any identified items should be returned as separate messages using only this structure
- IGNORE any impulse to add additional fields or structures not defined above

Expected output format:
[
    {
        // fields matching expected structure
    }
]",
  reserved_fields: ["input", "structure"],
  author: "XMPro",
  created_date: datetime(),
  last_modified_date: datetime(),
  active: true,
  version: 1,
  type: "system",
  category: "tool",
  tags: ["tool", "data stream"],
  description: "Formats the incomming response to fit the structure the datastream needs.",
  last_used_date: null,
  model_provider: "OpenAI",
  model_name: "gpt-4o-mini",
  max_tokens: 2000,
  access_level: "system"
}),
(p)-[:CONTAINS]->(p14)

CREATE (p15:Prompt {
  prompt_id: "XMAGS-CONREPLY-PROMPT-001",
  name: "Conversation Reply",
  internal_name: "conversation_reply_prompt",
  prompt: "Given a users input, the agent's response including retrieved information and tool usage results, create a natural, conversational reply that incorporates all key information. Follow these guidelines:

1. Maintain Context:
   - Acknowledge the users specific query/concern
   - Reference key points from the RAG context when relevant
   - Explain tool usage and results clearly
   - Maintain continuity with any previous exchanges
   - Clearly attribute information sources and tool results

2. Information Integration:
   - Seamlessly incorporate RAG-sourced information
   - Clearly present tool results and their implications
   - Highlight particularly relevant retrieved information
   - Distinguish between general knowledge, specific retrieved context, and tool-generated data
   - Include relevant citations for RAG information
   - Explain any actions taken by tools on the users behalf

3. Tool Usage Transparency:
   - Clearly indicate which tools were used and why
   - Explain tool results in user-friendly terms
   - Highlight any important findings or data from tools
   - Note any limitations or caveats in tool results
   - Indicate if tools encountered any issues

4. Tone and Structure:
   - Keep the tone professional yet friendly and approachable
   - Present information in a logical flow
   - Group related points together
   - Use appropriate transitions between topics
   - End with a natural closing or invitation for further questions

5. Content Organization:
   - Present the most important information first
   - Break down complex information into digestible parts
   - Use bullet points or numbered lists for multiple items
   - Include relevant examples or analogies when helpful

6. Source Attribution:
   - Clearly indicate information sources (knowledge base, tools, etc.)
   - Include relevant citations in a natural way
   - Maintain transparency about all information sources

Input Context:
User Query: {user_query}
Initial Response: {agent_response}

Retrieved Knowledge Context:
{knowledge_context}

Tools Used and Results:
{tool_usage}

Format your response conversationally while maintaining all key information. Ensure the reply is:
- Clear and concise
- Natural and engaging
- Informative and accurate
- Appropriately detailed
- Easy to understand
- Properly attributed for all information sources
- Clear about tool usage and results

[Return only the conversational response that incorporates all essential information]",
  reserved_fields: ["tool_usage", "knowledge_context", "agent_response", "user_query"],
  author: "XMPro",
  created_date: datetime(),
  last_modified_date: datetime(),
  active: true,
  version: 1,
  type: "system",
  category: "conversation",
  tags: ["conversation"],
  description: "Formats the response to send back to the user.",
  last_used_date: null,
  model_provider: "OpenAI",
  model_name: "gpt-4o-mini",
  max_tokens: 2000,
  access_level: "system"
}),
(p)-[:CONTAINS]->(p15)