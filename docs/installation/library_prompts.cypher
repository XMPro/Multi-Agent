// Create Library once
MERGE (lib:Library {name: "Main Prompt Library"})
ON CREATE SET lib.type = "Prompt", lib.created_date = datetime();

// Define all prompts as a collection of maps
MATCH (lib:Library {type: "Prompt"})
WITH lib, [
  {
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
To suggest a tool for use, include SUGGEST_TOOL: [ToolName] - [the user's original question] in your response.
IF the tool you are suggesting is [XMPro Data Stream Tool] then the format to use is SUGGEST_TOOL: [ToolName] (Data Stream) - [the user's original question] in your response.
</tools>

<instructions>
Response Requirements:
1. Start with direct answer to query
2. Use available knowledge and tools appropriately
3. Maintain clear and concise communication
4. Maintains a consistent and appropriate tone throughout the conversation.
5. Include relevant citations
6. Acknowledge any limitations
7. Asks for clarification if the user's intent is unclear.
8. Use 'SUGGEST_TOOL: [ToolName] - [Query]' format for tool suggestions
9. When referencing assets in your response:
   - Always use the full identifier format: [Asset ID] ([Part/Model Number]) at [Location]
   - Include all available identifier information for each asset mentioned
   - If any identifier information is missing, explicitly note this
10. Incorporates relevant information from the conversation history and context:
   - When citing historical data, include the timestamp
   - Maintain chronological organization of information
   - Preserve all asset identifiers when referencing historical data
11. IMPORTANT: Suggests available tools when necessary to provide accurate and helpful information:
   - Always use the syntax 'SUGGEST_TOOL: ToolName: \"user's original question\"'
   - Do not modify queries yourself
   - Pass the user's question directly to the tool
   - Suggest tools specifically for missing asset information
12. Does not include any additional comments about running the query or needing confirmation.
13. CRITICAL: Do not provide any information that you don't have direct access to:
   - Do not assume or fabricate any data or results
   - If you need information to answer the question, only suggest using a tool to obtain it
   - Never infer or guess at asset identifiers
14. Format all numerical data consistently:
    - Include units of measurement
    - Use consistent decimal places
    - Include measurement timestamps
15. Present information in a structured format:
    - Group data by asset ID
    - Use tables or lists for multiple metrics
    - Highlight any changes in asset information across timestamps

Your response can include tool suggestions ONLY IF relevant to answering the query. Do not provide any fake or assumed results from tool usage. Do not speculate about what the results might be. Do not ask for confirmation to use the tool.
</instructions>

<Conversation history>
{history}
</Conversation history>",
    reserved_fields: ["current_timestamp", "history", "knowledge_context", "available_tools", "user_query"],
    category: "conversation",
    tags: ["conversation"],
    description: "Guides the AI in generating contextual responses during conversations, considering history, available tools, and user input."
  },
  {
    prompt_id: "XMAGS-CONVOSUMMARY-PROMPT-001",
    name: "Conversation Summary",
    internal_name: "conversation_summary_prompt",
    prompt: "Extract and compress the following conversation into essential points for future context:

User: {user_query}
Assistant: {agent_response}

Create a concise extract that preserves:
- Key decisions and their reasoning
- Important recommendations and advice given
- Specific methods, processes, or approaches suggested
- Critical details, examples, or implementation steps
- Important warnings, limitations, or considerations
- Tools, resources, or references mentioned
- Any follow-up actions or next steps identified

Format as bullet points for maximum token efficiency while retaining all actionable and contextually important information.

Example:
User: How should I handle equipment calibration scheduling for our new production line?
Assistant: [Long detailed response about calibration procedures, scheduling software, compliance requirements, etc.]

Extract:
• Recommended monthly calibration schedule for critical equipment, quarterly for secondary
• Use CalibrationPro software - integrates with existing ERP system 
• Must document per ISO 9001 requirements - keep records minimum 3 years
• Schedule during planned maintenance windows to minimize downtime
• Critical equipment: pressure sensors, flow meters, temperature controllers
• Backup calibration vendor: TechCal Services (contact: 555-0123)
• Warning: Never skip pressure sensor calibration - safety compliance issue

[Return ONLY the compact extract]",
    reserved_fields: ["user_query", "agent_response"],
    category: "conversation",
    tags: ["conversation"],
    description: "Instructs the AI to create a concise summary of a conversation for future reference."
  },
  {
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
6. If there is already an Observation or Reflection for this information we do not need to create a new one.

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
    category: "conversation",
    tags: ["conversation", "observation"],
    description: "Directs the AI to analyze a conversation response and determine if it warrants creating a new observation."
  },
  {
    prompt_id: "XMAGS-CONREPLY-PROMPT-001",
    name: "Conversation Reply",
    internal_name: "conversation_reply_prompt",
    prompt: "# Input Context
## User Query
{user_query}

## Initial Response
{agent_response}

## Retrieved Knowledge Context
{knowledge_context}

## Tools Used and Results
{tool_usage}

# Instructions
Given a user's input, the agent's response including retrieved information and tool usage results, create a natural, conversational reply that incorporates all key information. Follow these guidelines:

## Core Response Principles
1. **Only use actual data**: Never create hypothetical examples, sample data, or placeholder visualizations
2. **Be helpful within constraints**: Explain what you can do and what information you would need
3. **Suggest actionable next steps**: Guide users toward obtaining the data they need
4. **Maintain assistant role**: Stay helpful and professional while being honest about limitations

# Data Visualization Requirements
When data needs to be visualized, choose appropriate chart types based on data relationships.

## Data Visualization Requirements
**CRITICAL**: Only create visualizations when you have actual data from the knowledge context or tool results.

### Chart Selection Guidelines (for actual data only)
Before creating a chart, ask:
  - Do these data points have a meaningful relationship?
  - Would connecting these points with lines make logical sense?
  - Is this time series data or sequential data?
  - Are these measurements that should be compared as categories?
  - Would this data be better understood as a table?

**When to Chart**
- ✅ **Create charts**: When actual numerical data is provided in the knowledge context or tool results

**When NOT to Chart**
- ❌ Unrelated measurements with different units (use table + bar chart if comparison needed)
- ❌ Single data points
- ❌ Data that's clearer in tabular format
- ❌ Mixed units without meaningful relationships

### Chart Data Transformation
When numerical data is present:
- Convert tabular data into chart-ready format
- Structure the data as a proper JSON object
- Include appropriate chart type based on data
  - Line charts for time series
  - Bar charts for comparisons
  - Pie charts for proportions
  - Scatter plots for correlations

### Bar Charts 
For comparing different categories, measurements, or unrelated values

 ```chart
 {
   \"type\": \"BarChart\",
   \"data\": [
	 {\"name\": \"Category A\", \"value\": 150},
	 {\"name\": \"Category B\", \"value\": 230}
   ],
   \"config\": {
	 \"xAxis\": \"name\",
	 \"yAxis\": \"value\",
	 \"title\": \"Comparison Chart Title\",
	 \"yAxisUnit\": \"units\"
   }
 }
 ```

### Line Charts
ONLY for time series data or sequential relationships

 ```chart
 {
   \"type\": \"LineChart\",
   \"data\": [
	 {\"name\": \"Jan\", \"value\": 100},
	 {\"name\": \"Feb\", \"value\": 120},
	 {\"name\": \"Mar\", \"value\": 110}
   ],
   \"config\": {
	 \"xAxis\": \"name\",
	 \"yAxis\": \"value\",
	 \"title\": \"Time Series Chart Title\"
   }
 }
 ```

### Pie Charts
For parts of a whole (percentages/proportions)

 ```chart
 {
   \"type\": \"PieChart\",
   \"data\": [
	 {\"name\": \"Section A\", \"value\": 30},
	 {\"name\": \"Section B\", \"value\": 70}
   ],
   \"config\": {
	 \"title\": \"Distribution Chart Title\"
   }
 }
 ```

### Scatter Plots
For showing correlations between two variables

 ```chart
 {
   \"type\": \"ScatterChart\",
   \"data\": [
	 {\"x\": 10, \"y\": 20},
	 {\"x\": 15, \"y\": 25}
   ],
   \"config\": {
	 \"xAxis\": \"x\",
	 \"yAxis\": \"y\",
	 \"title\": \"Correlation Chart Title\"
   }
 }
 ```

### For Process Flows
Use mermaid diagrams:

```mermaid
graph TD
   A[Start] --> B[Process]
   B --> C[End]
```

### For Tabular Data
Use markdown tables:

| Header 1 | Header 2 | 
|----------|----------| 
| Data 1 | Data 2 |

## Response Structure
1. **Direct answer**: Address the user's specific question first
2. **Available information**: Share what you actually know from the context
3. **Tool suggestions**: Recommend specific tools when relevant using proper format
4. **Next steps**: Guide user on how to get the information they need

## Information Handling
- **Cite sources**: Include all relevant citations from knowledge context
- **Acknowledge limitations**: Be transparent about what you don't know
- **No fabrication**: Never invent data, examples, or specifics not in the context
- **Maintain accuracy**: Only reference information that's actually provided

## Tool Usage Transparency
- Indicate which tools were used and why
- Format tool results consistently
- Note any limitations or issues

## Asset References (when applicable)
When the user is specifically asking about individual assets and asset identifiers are provided in the context:
- Use the identifier format provided in the context
- Include only the identifier information that's actually available
- Note when identifier information is incomplete
- Don't assume or fabricate asset details

For general topics (processes, parts, procedures, asset groups), respond naturally without forcing asset identifier formatting.

## Conversation Continuity
- Reference relevant conversation history
- Maintain chronological organization
- Preserve asset identifiers from historical data
- Include timestamps when citing historical information

## What NOT to do
- ❌ Create hypothetical examples or sample data
- ❌ Generate placeholder visualizations
- ❌ Assume or infer information not provided
- ❌ Create fake citations or references
- ❌ Use phrases like \"Here\'s an example of what it might look like\"
- ❌ Ask for confirmation to use tools
- ❌ Provide speculative results from tool usage

## Professional Tone
- Maintain helpful, knowledgeable assistant persona
- Be direct and clear about capabilities and limitations
- Offer constructive guidance on next steps
- Stay focused on the user\'s actual needs",
    reserved_fields: ["tool_usage", "knowledge_context", "agent_response", "user_query"],
    category: "conversation",
    tags: ["conversation"],
    description: "Formats the response to send back to the user."
  },
  {
    prompt_id: "XMAGS-PLANDECISION-PROMPT-001",
    name: "Plan Decision",
    internal_name: "plan_decision_prompt",
    prompt: "Based on the following information, decide if the current plan should be adjusted or if the current plan is sufficient:

## Current plan: 
{current_plan}

## Current state: 
{current_state}

## Adaptation factors: 
{adaptation_factors}

## New goal from reflections: 
{new_goal_from_reflections}

## Current plan valid: 
{current_plan_valid}

## Initial assessment: 
{initial_assessment}

## Objective Function:
{objective_function}

## Available Actions:
{available_actions}

## Analysis Instructions
Carefully analyze the information provided to determine if the current plan should be adjusted or maintained:

1. **Threshold vs Target Assessment:**
   - Distinguish between target values (aspirational goals) and alarm thresholds (action triggers)
   - Focus primarily on measures that exceed warning or critical thresholds
   - Consider target misses as secondary factors unless they indicate trend toward threshold breach

2. **Measure Performance Analysis:**
   - Examine each measure in the objective function
   - Identify measures that exceed warning or critical thresholds
   - Assess if the current plan's tasks directly address underperforming measures
   - Evaluate whether current plan structure can accommodate needed improvements

3. **Plan Relevance Assessment:**
   - Review if current plan tasks are designed to address the identified performance gaps
   - Consider whether the plan is actively targeting the right measures
   - Assess if plan execution could reasonably improve the current situation

4. **Adaptation Factor Assessment:**
   - Evaluate the impact level of each adaptation factor
   - Determine if adaptation factors represent fundamental changes since plan creation
   - Assess whether adaptation factors require structural plan changes or minor modifications

5. **Action Capability Assessment:**
   - Review available actions and their impact on measures
   - Identify if current plan utilizes the most appropriate actions for current conditions
   - Determine if different or additional actions would significantly improve outcomes

6. **New Goal Evaluation:**
   - If new goals exist, assess their compatibility with current plan structure
   - Determine if new goals can be incorporated through minor plan modifications

## Decision Criteria:

**Recommend NO CHANGE if:**
- Measures are within acceptable thresholds (even if not meeting targets)
- Current plan tasks directly address the primary performance issues
- No significant adaptation factors or new goals present
- Current plan validity and initial assessment support continuation

**Recommend PLAN ADJUSTMENT if:**
- Few measures exceed thresholds but current plan structure remains sound
- Minor adaptation factors affect specific plan elements
- Current plan tasks are relevant but need modification or addition
- New goals can be incorporated into existing structure

**Recommend NEW PLAN if:**
- Multiple measures significantly exceed critical thresholds
- Current plan tasks are misaligned with primary performance issues
- Major adaptation factors fundamentally change the operating context
- Current plan structure cannot accommodate necessary changes

## Response Format
Provide your decision as 'Yes' for a plan adjustment is needed or 'No' if the current plan is sufficient.
[Reply ONLY Yes/No]

### Explanation
[Provide a brief explanation for your decision that references:
1. Specific measures and their threshold status (not just target alignment)
2. How well current plan tasks address the identified issues
3. Impact of adaptation factors on plan relevance
4. Whether available actions support plan continuation or require changes]",
    reserved_fields: ["current_plan", "current_state", "adaptation_factors", "new_goal_from_reflections", "current_plan_valid", "initial_assessment", "objective_function", "available_actions"],
    category: "plan",
    tags: ["plan", "reflection"],
    description: "Directs the AI to decide whether a new plan is needed or if the current plan should be adjusted based on various factors"
  },
  {
    prompt_id: "XMAGS-PLANREFLECT-PROMPT-001",
    name: "Planning Reflection",
    internal_name: "planning_reflection_analysis_prompt",
    prompt: "Analyze the following recent reflections and determine if a new goal is needed. Consider the current plan, goals, objective functions, measures, and available actions when making your decision.


## Recent reflections
{recent_reflections}


## Current goals
{current_goals}


## Current plan
{current_plan}


## Objective Functions and Measures
{objective_function}

## Available Actions
{available_actions}

## Instructions
Your task is to determine if a new goal is needed based on the reflections, while ensuring alignment with the existing objective functions and measures. DO NOT invent new metrics or goals that aren't related to the existing objective functions and measures.

When analyzing the reflections:
1. Focus on identifying gaps between current performance and target values in the objective functions
2. Consider which available actions could address these gaps
3. Evaluate if the current plan is sufficient to meet the objectives or if a new goal is needed
4. Only suggest a new goal if it directly contributes to improving the measures in the objective functions

## Response Format
'Yes/No'

### New goal
If a new goal is needed, provide a specific, measurable goal statement using this format:
- Goal Type: [Individual/Team]
- Goal Name: [Short descriptive name]
- Objective: [Minimize/Maximize]
- Formula: [Mathematical expression using ONLY existing measure IDs from the objective functions]
- Components:
  * [Existing Measure ID] (Weight: [0-1], [Minimize/Maximize]): Current value: [current value from objective function], Target value: [realistic target value]
  * [Additional measures as needed, ONLY using existing measure IDs]
- Required Actions: [List specific actions from the Available Actions that would help achieve this goal]
- Success Criteria: [Specific, measurable outcome in terms of the objective function measures]
- Priority: [High/Medium/Low]

### Target Value Derivation
When setting target values for each measure:
1. Use the current values and target values already defined in the objective functions as your primary reference
2. If adjusting targets, ensure they are realistic improvements over current values:
   a. For measures to minimize: Set targets that are 5-15% below current values
   b. For measures to maximize: Set targets that are 5-15% above current values
3. Explicitly reference the thresholds defined in the objective functions
4. NEVER set target values that are unrealistic or drastically different from current values

### Action Alignment
For each measure in your proposed goal:
1. Identify specific actions from the Available Actions list that would directly impact this measure
2. Explain how each action would affect the measure (increase, decrease, or set to a specific value)
3. Estimate the magnitude of impact each action would have on the measure
4. DO NOT suggest actions that aren't in the Available Actions list

### Explanation
Provide a brief explanation for your decision, focusing on:
1. Specific performance gaps identified in the reflections that relate to the objective functions
2. How the current values of measures compare to their target values and thresholds
3. Which specific actions could be taken to improve underperforming measures
4. How your proposed goal (if any) would address these gaps using available actions
5. Why the current plan is or isn't sufficient to address these gaps",
    reserved_fields: ["recent_reflections", "current_goals", "current_plan", "objective_function", "available_actions"],
    category: "plan",
    tags: ["plan", "reflection"],
    description: "Guides the AI in analyzing recent reflections to determine if a new goal is needed."
  },
  {
    prompt_id: "XMAGS-PLANPROBLEMUNDERSTAND-PROMPT-001",
    name: "Planning Understanding Problem",
    internal_name: "plan_understand_problem_prompt",
    prompt: "Analyze the following goal and provide a concise summary of the key elements, objectives, and constraints, considering the capabilities of the team:

## Goal
{goal}

## Team Capabilities
{team_capabilities}

## Objective Functions
{objective_function}

## Response
Your response should include:
1. A brief restatement of the main objective
2. Identification of key components or sub-goals
3. Any implicit or explicit constraints
4. Potential challenges or considerations
5. How different team members' capabilities might be leveraged to achieve the goal
6. How the goal relates to the objective functions and their measures

Provide your analysis in a clear, structured format.",
    reserved_fields: ["goal", "team_capabilities", "objective_function"],
    category: "plan",
    tags: ["plan"],
    description: "Guides the AI in analyzing a goal and team capabilities to provide a comprehensive problem understanding."
  },
  {
    prompt_id: "XMAGS-PLANPDDL-PROMPT-001",
    name: "Planning Generate PDDL",
    internal_name: "plan_generate_pddl_prompt",
    prompt: "Based on the goal and problem understanding below, create a PDDL (Planning Domain Definition Language) plan that can be executed to achieve the goal.

## Goal
{goal}

## Problem Understanding
{understanding}

## Team Capabilities
{team_capabilities}

## Objective Function
{objective_function}

## Available Actions
{available_actions}

## Instructions
Create a complete PDDL solution, it should include the following PDDL components, each clearly labeled and properly formatted:

1. PDDL Domain Definition:
   - Define domain-specific types that directly relate to the problem (transformers, forecasting models, grid sections, maintenance tasks, etc.)
   - **IMPORTANT: Ensure ALL types referenced in predicates, functions, and actions are explicitly defined in the `:types` section**
   - **IMPORTANT: Only use PDDL-supported primitive types. DO NOT use 'string' or 'number' as types - instead, create domain-specific types like 'operation-type' or 'measure'**
   - List concrete predicates that represent actionable states (calibrated, optimized, maintained, etc.)
   - Define all functions that will be used, including:
     - **IMPORTANT: Define the `total-cost` function if you plan to use it in the metric**
     - All measure values and their valid ranges
   - Detail each action with:
     - Specific parameters that identify the objects being acted upon
     - Realistic preconditions that must be true before the action can be executed
     - Concrete effects showing exactly how the action changes the system state
     - Numeric effects showing how each action impacts goal metrics (use increase/decrease)
   - **If you include `:durative-actions` in requirements, you MUST define at least one durative action with `:duration`, `:condition`, and `:effect` sections**
   - **If you don't need durative actions, remove `:durative-actions` from requirements**
   Note: Only include actions from the Available Actions list, but make them specific to the domain.

2. PDDL Problem Definition:
   - Define specific objects representing actual system components (transformer-1, model-A, etc.)
   - **IMPORTANT: Ensure all objects have types that are explicitly defined in the domain**
   - Specify the initial state with concrete values for all relevant predicates and numeric fluents
   - Include the current metric values as specified in the goal
   - State the goal condition in terms of specific metric improvements

3. PDDL Plan:
   - Provide a sequence of actions with specific parameters that clearly identify what is being acted upon
   - **IMPORTANT: Ensure all actions in the plan use only parameter types that match the action definitions**
   - For each action, explain:
     - Why this action is needed at this point in the plan
     - How it specifically contributes to improving the target metrics (with numeric values)
     - Which preconditions it satisfies for subsequent actions
   - Assign each action to the most appropriate agent based on their skills
   - Ensure temporal dependencies between actions are respected

4. Plan Validation:
   - Explain how each action in the plan directly contributes to:
     - Improving relevant metrics
     - Meeting target goals
   - Calculate the cumulative impact of all actions on the goal metrics
   - Verify the plan achieves the target values within the specified timeframe

5. Efficiency Analysis:
   - Identify critical path actions that directly impact timeline
   - Suggest parallel activities that could be executed simultaneously
   - Identify potential bottlenecks or resource constraints
   - Recommend specific optimizations to reduce execution time or improve results

6. Objective Function Impact:
   - Calculate the initial objective function score based on current measure values
   - Project the objective function score after plan execution
   - Break down contributions by component (with weights)
   - Calculate overall improvement in absolute and percentage terms

## CRITICAL PDDL VALIDATION REQUIREMENTS:
- **Type Consistency**: Every type referenced anywhere MUST be defined in the `:types` section
- **Parameter Typing**: All action parameters must have valid types
- **Predicate Usage**: All predicates used in preconditions must be defined
- **Function Definition**: All functions used (especially in metrics) must be defined
- **Requirements Consistency**: If you include a requirement like `:durative-actions`, the domain must use that feature
- **Only use standard PDDL types and constructs**: 
  - NO string or number primitive types (use domain-specific types instead)
  - NO undefined operators or syntax
- **Check All Preconditions**: Ensure every action's preconditions only reference defined predicates and valid parameters

IMPORTANT:
- Pay special attention to safety-critical measures (marked as SafetyCritical in the Objective Function section). Ensure that actions never cause these measures to exceed their alarm thresholds.
- Consider relationships between measures when planning actions. Some measures may be inputs to calculated measures, so changes to one measure may affect others.

IMPORTANT FORMAT REQUIREMENTS:
1. Start each major section with a specific header format:
   - Use exactly \";; Domain Definition\" for the domain section
   - Use exactly \";; Problem Definition\" for the problem section
   - Use exactly \";; Plan\" for the plan section
   - Use exactly \"### Plan Validation:\" for the validation section
   - Use exactly \"### Efficiency Analysis:\" for the efficiency analysis section

2. For the PDDL code:
   - Enclose all PDDL code blocks within triple backticks with the pddl language specifier: ```pddl
   - Ensure proper indentation and syntax formatting
   - End all PDDL code blocks with ```

3. For the Plan section:
   - Format each action as a comment line starting with semicolon (;)
   - Include agent assignment in the format: \"; Assigned to: [Agent Name]\"
   - Ensure numeric effects are specified for each action (e.g., \"reduces load-forecast-error by 0.05\")
   - Include measure impacts for each action in the format:
     \"; Measure Impacts:\"
     \";   - measure1: increases from 82.5 to 83.0\"
     \";   - measure2: decreases from 94.0 to 92.5\"

4. For Validation and Efficiency sections:
   - Use bullet points for clarity
   - Include specific numeric calculations showing cumulative effects

5. For Objective Function Impact section:
   - Include initial and projected objective function scores
   - Break down by component with weights
   - Show overall improvement in absolute and percentage terms

## COMPLETE EXAMPLE STRUCTURE:

```pddl
;; Domain Definition
(define (domain domain-name)
  (:requirements :typing :fluents :negative-preconditions)
  (:types
    agent - object
    resource - object
    capability - object  ; Define ALL referenced types
    measure - object
    operation-type - object  ; Instead of using 'string'
  )
  (:predicates
    (has-capability ?a - agent ?c - capability)
    (resource-available ?r - resource)
    ...
  )
  (:functions
    (measure-value ?m - measure)
    (total-cost)  ; Define this if used in metric
    ...
  )
  (:action action-name
    :parameters (?a - agent ?r - resource ?op - operation-type)  ; Use defined types
    :precondition (and 
      (has-capability ?a capability1)
      (resource-available ?r)
    )
    :effect (and 
      (increase (measure-value measure1) 0.5)
      (increase (total-cost) 1)
      ...
    )
  )
  ...
)
```

```pddl
;; Problem Definition
(define (problem problem-name)
  (:domain domain-name)
  (:objects
    agent1 agent2 - agent
    measure1 measure2 - measure
    capability1 capability2 - capability
    operation1 operation2 - operation-type
    ...
  )
  (:init
    (has-capability agent1 capability1)
    (= (measure-value measure1) 82.5)
    (= (total-cost) 0)
    ...
  )
  (:goal (and
    (>= (measure-value measure1) 85.0)
    ...
  ))
  (:metric minimize (total-cost))
)
```

;; Plan 
; Action 1: (action-name agent1 resource1 operation1) 
; Assigned to: Agent1 
; Explanation of this action's purpose 
; Numeric effect: decreases/increases metric by X.XX 
; Preconditions satisfied: has-capability, resource-available 
; Measure Impacts: 
;   - measure1: increases from 82.5 to 83.0 
;   - measure2: decreases from 94.0 to 92.5

; Action 2: (action-name agent2 resource2 operation2) 
; Assigned to: Agent2
; Explanation of this action's purpose 
; Numeric effect: decreases/increases metric by X.XX 
; Preconditions satisfied: has-capability, resource-available 
; Measure Impacts: 
;   - measure1: increases from 83.0 to 83.5 
;   - measure2: decreases from 92.5 to 91.0

### Plan Validation:
- Action 1 contributes X.XX improvement to metric1, from Y.YY to Z.ZZ
- Action 2 contributes X.XX improvement to metric2, from Y.YY to Z.ZZ
- Combined effect: metric1 improved by X.XX, metric2 improved by X.XX
- Timeline analysis: All actions can be completed within the required timeframe of N months
- Measure relationships considered:
  - Changes to measure1 affect calculated measure3 (formula: measure3 = measure1 * 0.5 + measure2)
  - Projected impact on measure3: from A.AA to B.BB

### Efficiency Analysis:
- Critical path: Action 1 → Action 3 → Action 5
- Parallel opportunities: Actions 2 and 4 can be executed simultaneously
- Bottleneck identified: Limited availability of Agent X for both Action 1 and Action 3
- Optimization recommendation: Prioritize Action 1 to immediately improve metric1 by X.XX

### Objective Function Impact:
- Initial objective function score: X.XX
- Projected objective function score after plan execution: Y.YY
- Component contributions:
  - Component1 (weight: W.WW): from X.XX to Y.YY
  - Component2 (weight: W.WW): from X.XX to Y.YY
- Overall improvement: Z.ZZ (P.PP%)

Ensure that all PDDL elements are syntactically correct and logically consistent with the given goal, problem understanding, and team capabilities. Your PDDL should show a clear path to achieving the specific numeric targets in the goal.",
    reserved_fields: ["goal", "understanding", "team_capabilities", "available_actions", "objective_function"],
    category: "plan",
    tags: ["plan"],
    description: "Creates a comprehensive PDDL plan based on given parameters and constraints."
  },
  {
    prompt_id: "XMAGS-PLANADJ-PROMPT-001",
    name: "Plan Adjustment",
    internal_name: "plan_adjustment_prompt",
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

## Team Capabilities
{team_capabilities}

## Objective Function
{objective_function}

## Available Actions
{available_actions}

Please provide an adjusted PDDL plan that incorporates the new planning decision. Your response should include:

1. Updated PDDL Domain Definition (if necessary):
   - Define domain-specific types that directly relate to the problem
   - List concrete predicates that represent actionable states
   - Detail each action with:
     - Specific parameters that identify the objects being acted upon
     - Realistic preconditions that must be true before the action can be executed
     - Concrete effects showing exactly how the action changes the system state
     - Numeric effects showing how each action impacts goal metrics (use increase/decrease)
   - Highlight any new types, predicates, or actions added
   - Explain why these additions are necessary
   Note: Only include actions from the Available Actions list, but make them specific to the domain.

2. Updated PDDL Problem Definition:
   - Define specific objects representing actual system components
   - Specify the initial state with concrete values for all relevant predicates and numeric fluents
   - Include the current metric values as specified in the goal
   - State the goal condition in terms of specific metric improvements
   - Show changes to the initial state or objects (if any)
   - Clearly state the new goal condition

3. Adjusted PDDL Plan:
   - Provide the full sequence of actions in the new plan
   - For each action, explain:
     - Why this action is needed at this point in the plan
     - How it specifically contributes to improving the target metrics (with numeric values)
     - Which preconditions it satisfies for subsequent actions
   - Assign each action to the most appropriate agent based on their skills
   - Ensure temporal dependencies between actions are respected
   - Highlight which actions are new or modified
   - Explain how these changes address the new goal

4. Plan Validation:
   - Explain how each action in the plan directly contributes to improving relevant metrics
   - Calculate the cumulative impact of all actions on the goal metrics
   - Verify the plan achieves the target values within the specified timeframe
   - Analyze which parts of the original plan were maintained and why

5. Efficiency Analysis:
   - Identify critical path actions that directly impact timeline
   - Suggest parallel activities that could be executed simultaneously
   - Identify potential bottlenecks or resource constraints
   - Recommend specific optimizations to reduce execution time or improve results

6. Objective Function Impact:
   - Calculate the initial objective function score based on current measure values
   - Project the objective function score after plan execution
   - Break down contributions by component (with weights)
   - Calculate overall improvement in absolute and percentage terms

IMPORTANT:
- Pay special attention to safety-critical measures (marked as SafetyCritical in the Objective Function section). Ensure that actions never cause these measures to exceed their alarm thresholds.
- Consider relationships between measures when planning actions. Some measures may be inputs to calculated measures, so changes to one measure may affect others.
- Maintain relevant parts of the original plan when possible, and clearly justify any removals or significant changes.

IMPORTANT FORMAT REQUIREMENTS:
1. Start each major section with a specific header format:
   - Use exactly \";; Domain Definition\" for the domain section
   - Use exactly \";; Problem Definition\" for the problem section
   - Use exactly \";; Plan\" for the plan section
   - Use exactly \"### Plan Validation:\" for the validation section
   - Use exactly \"### Efficiency Analysis:\" for the efficiency analysis section
   - Use exactly \"### Objective Function Impact:\" for the impact section

2. For the PDDL code:
   - Enclose all PDDL code blocks within triple backticks with the pddl language specifier: ```pddl
   - Ensure proper indentation and syntax formatting
   - End all PDDL code blocks with ```

3. For the Plan section:
   - Format each action as a comment line starting with semicolon (;)
   - Include agent assignment in the format: \"; Assigned to: [Agent Name]\"
   - Ensure numeric effects are specified for each action (e.g., \"reduces load-forecast-error by 0.05\")
   - Include measure impacts for each action in the format:
     \"; Measure Impacts:\"
     \";   - measure1: increases from 82.5 to 83.0\"
     \";   - measure2: decreases from 94.0 to 92.5\"
   - Mark each action as New, Modified, or Unchanged

4. For Validation and Efficiency sections:
   - Use bullet points for clarity
   - Include specific numeric calculations showing cumulative effects

5. For Objective Function Impact section:
   - Include initial and projected objective function scores
   - Break down by component with weights
   - Show overall improvement in absolute and percentage terms

Your complete response should follow this exact structure:

```pddl
;; Domain Definition
(define (domain updated-domain-name)
  (:requirements :typing :fluents :durative-actions :negative-preconditions)
  (:types
    agent - object
    resource - object
    ...
  )
  (:predicates
    (has-capability ?a - agent ?c - capability)
    ...
  )
  (:functions
    (cost ?a - action)
    (measure-value ?m - measure)
    ...
  )
  (:action action-name
    :parameters (?a - agent ?r - resource)
    :precondition (and ...)
    :effect (and 
      (increase (measure-value measure1) 0.5)
      ...
    )
  )
  ...
)
```

```pddl
;; Problem Definition
(define (problem updated-problem-name)
  (:domain updated-domain-name)
  (:objects
    agent1 agent2 - agent
    measure1 measure2 - measure
    ...
  )
  (:init
    (has-capability agent1 capability1)
    (= (measure-value measure1) 82.5)
    ...
  )
  (:goal (and
    (>= (measure-value measure1) 85.0)
    ...
  ))
  (:metric minimize (total-cost))
)
```

;; Plan 
; Action 1: (action-name parameters) ; New/Modified/Unchanged
; Assigned to: Agent Name 
; Explanation of this action's purpose 
; Numeric effect: decreases/increases metric by X.XX 
; Preconditions satisfied: ... 
; Measure Impacts: 
; - measure1: increases from 82.5 to 83.0 
; - measure2: decreases from 94.0 to 92.5

; Action 2: (action-name parameters) ; New/Modified/Unchanged
; Assigned to: Agent Name 
; Explanation of this action's purpose 
; Numeric effect: decreases/increases metric by X.XX 
; Preconditions satisfied: ... 
; Measure Impacts: 
; - measure1: increases from 83.0 to 83.5 
; - measure2: decreases from 92.5 to 91.0

### Plan Validation:
- Action 1 contributes X.XX improvement to metric1, from Y.YY to Z.ZZ
- Action 2 contributes X.XX improvement to metric2, from Y.YY to Z.ZZ
- Combined effect: metric1 improved by X.XX, metric2 improved by X.XX
- Timeline analysis: All actions can be completed within the required timeframe of N months
- Measure relationships considered:
  - Changes to measure1 affect calculated measure3 (formula: measure3 = measure1 * 0.5 + measure2)
  - Projected impact on measure3: from A.AA to B.BB
- Original plan elements maintained:
  - [List elements from original plan that were maintained]
  - [Explain why these elements were preserved]

### Efficiency Analysis:
- Critical path: Action 1 → Action 3 → Action 5
- Parallel opportunities: Actions 2 and 4 can be executed simultaneously
- Bottleneck identified: Limited availability of Agent X for both Action 1 and Action 3
- Optimization recommendation: Prioritize Action 1 to immediately improve metric1 by X.XX

### Objective Function Impact:
- Initial objective function score: X.XX
- Projected objective function score after plan execution: Y.YY
- Component contributions:
  - Component1 (weight: W.WW): from X.XX to Y.YY
  - Component2 (weight: W.WW): from X.XX to Y.YY
- Overall improvement: Z.ZZ (P.PP%)

Ensure that all PDDL elements are syntactically correct and logically consistent with both the original plan and the new planning decision.",
    reserved_fields: ["current_goal", "current_pddl_plan", "new_goal", "decision_reasoning", "objective_function", "team_capabilities", "available_actions"],
    category: "plan",
    tags: ["plan"],
    description: "Adjust a plan based on the planning decision."
  },
  {
prompt_id: "XMAGS-TASKBREAKDOWN-PROMPT-001",
    name: "Task Breakdown",
    internal_name: "task_breakdown_prompt",
    prompt: "Break down the following plan into specific, actionable tasks to achieve the goal, considering the capabilities of the team members:

## Goal
{goal}

## Plan
{plan_details}

## Team Capabilities
{team_capabilities}

## Objective Function
{objective_function}

## Instructions 

For each task, specify:
1. A clear description of the task
2. The agent best suited to perform the task based on their capabilities
3. Any dependencies on other tasks
4. The specific actions required to complete the task
5. The impact of the task on objective function measures

IMPORTANT: For each task, you MUST include specific actions from the agent's \"Available Actions\" list that would be used to accomplish the PDDL action. Each PDDL action must be translated into one or more concrete actions from the agent's available actions.

For example:
- If a PDDL action is \"calibrate-forecasting-model\", you must specify which of the agent's available actions (such as \"update_digital_twin\" or \"create_work_order\") would be used to accomplish this.
- If a PDDL action is \"schedule-maintenance\", you must include the \"schedule_maintenance\" action and any other relevant actions from the agent's available actions list.

DO NOT leave the Actions section empty or with [- None]. Every task must have at least one specific action listed from the agent's Available Actions.

REMINDER: Only use actions from the Available Actions list. Do not invent or suggest new actions.

The response MUST STRICTLY ADHERE to the following constraints:
- Only actions listed in the Available Actions section may be used
- No new or additional actions may be suggested or implied
- Each action listed in the response must be verbatim from the Available Actions list
- All required parameters for each action must be specified
- For actions with operation-specific required parameters, all required parameters for the specific operation must be included

IMPORTANT CONSIDERATIONS:
- Pay special attention to safety-critical measures (marked as SafetyCritical in the Objective Function section). Ensure that actions never cause these measures to exceed their alarm thresholds.
- Consider relationships between measures when planning actions. Some measures may be inputs to calculated measures, so changes to one measure may affect others.
- For each task, explicitly state how it will impact each relevant measure in the objective function, including the current value, the expected change, and the projected value after the task is completed.

## Response Format

Task [no]: [task description]
Agent: [AgentId (Agent Name)]
Dependencies: [List dependencies by stating the task no]
PDDL Step: [Corresponding PDDL plan step description]
PDDL Details: [Include the full detailed information from the PDDL plan for this action]
Actions:
- [specific action from agent's Available Actions list]
- [another specific action if needed]
Action Justification: [Provide a brief explanation of why these specific actions were selected to accomplish the PDDL task, explaining how each action contributes to the overall task objective]
Measure Impacts:
- [measure_name]: [expected change] (from [current_value] to [projected_value])
- [another_measure]: [expected change] (from [current_value] to [projected_value])

Example:
Task 1: Calibrate the forecasting model to improve forecast accuracy.
Agent: UTIL-LOAD-AGENT-001 (Load Optimization Agent)
Dependencies: None
PDDL Step: Action 1: (calibrate-forecasting-model model-A)
PDDL Details: ; Action 1: (calibrate-forecasting-model model-A) ; Assigned to: UTIL-LOAD-AGENT-001 ; This action calibrates the forecasting model to improve forecast accuracy. ; Numeric effect: decreases load-forecast-error by 0.05. ; Preconditions satisfied: `not (calibrated model-A)`.
Actions:
- update_digital_twin
- create_work_order
Action Justification: The update_digital_twin action is selected to update the model's parameters and algorithms in the digital environment, which is essential for improving forecast accuracy. The create_work_order action initiates the formal process of model calibration, ensuring the necessary resources are allocated and the calibration is properly documented in the system.
Measure Impacts:
- load_forecast_error: decrease (from 0.42 to 0.37)
- operational_efficiency_ratio: increase (from 82.5 to 84.0)",
    reserved_fields: ["planning_decision_goal", "planning_decision_reasoning", "planning_decision_context", "planning_decision_response", "components_list"],
    category: "plan",
    tags: ["task", "agent"],
    description: "Default prompt template for generating task breakdowns."
  },
  {
prompt_id: "XMAGS-CONSENSUSIMP-PROMPT-001",
    name: "Component Impact Analysis",
    internal_name: "components_batch_impact_analysis_prompt",
    prompt: "Analyze the following planning decision to determine which components and measures of an objective function it would impact.

## Goal
{planning_decision_goal}

## Reasoning
{planning_decision_reasoning}

## Context
{planning_decision_context}

## Response
{planning_decision_response}

## Components and Measures to Analyze
{components_list}

## Analysis Instructions
Consider both explicit mentions and implicit impacts. A planning decision may impact a component or measure even if it doesn't explicitly mention it by name. Consider:
1. Direct impacts: Components or measures explicitly mentioned in the decision
2. Indirect impacts: Components or measures affected through relationships with directly impacted items
3. System dependencies: How changes to one component might affect related components or measures
4. Side effects: Unintended consequences that might affect other components or measures
5. Measure relationships: How measures are calculated from or influence other measures

For measures specifically, consider:
- Whether the measure would increase, decrease, or be set to a specific value
- The approximate magnitude of the impact (small, moderate, large)
- How the impact aligns with the measure's target value and direction (maximize/minimize)
- Whether the impact would cross any threshold boundaries defined for the measure

## Response Format
For each item, clearly identify whether it is a component or a measure, and provide your analysis in the following format:

For components:
COMPONENT: [component name]
IMPACT_DETECTED: [Yes/No]
CONFIDENCE: [0-1 scale, e.g., 0.85]
REASONING: [Brief explanation of why this component is or is not impacted]

For measures:
MEASURE: [measure name]
IMPACT_DETECTED: [Yes/No]
CONFIDENCE: [0-1 scale, e.g., 0.85]
IMPACT_TYPE: [Increase/Decrease/Set/Unknown] (only if IMPACT_DETECTED is Yes)
IMPACT_MAGNITUDE: [Estimated magnitude of impact, 0-1 scale] (only if IMPACT_DETECTED is Yes)
REASONING: [Brief explanation of why this measure is or is not impacted]

Analyze each component and measure separately and provide a complete analysis for all listed items.

## Examples

Example 1 - Component Analysis:
COMPONENT: transformer_efficiency
IMPACT_DETECTED: Yes
CONFIDENCE: 0.78
REASONING: The planning decision explicitly mentions optimizing transformer operations, which would directly impact the transformer_efficiency component. The goal of reducing energy losses would positively affect this component.

Example 2 - Measure Analysis:
MEASURE: hotspot_temperature
IMPACT_DETECTED: Yes
CONFIDENCE: 0.92
IMPACT_TYPE: Decrease
IMPACT_MAGNITUDE: 0.3
REASONING: The planning decision includes implementing improved cooling protocols, which would directly reduce hotspot temperatures in transformers. Based on the described approach, a moderate decrease in temperature (approximately 30% improvement toward target) can be expected.

Example 3 - No Impact Case:
MEASURE: maintenance_cost_ratio
IMPACT_DETECTED: No
CONFIDENCE: 0.65
REASONING: The planning decision focuses on operational efficiency and does not mention or imply changes to maintenance procedures, schedules, or resources. While improved efficiency might indirectly affect maintenance in the long term, there is no clear pathway for this decision to impact maintenance costs in the scope described.",
    reserved_fields: ["planning_decision_goal", "planning_decision_reasoning", "planning_decision_context", "planning_decision_response", "components_list"],
    category: "plan",
    tags: ["objective", "team"],
    description: "Prompt for determining if a planning decision impacts specific components or measures of an objective function."
  },
  {
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
Summarize the tools and output the results of the tools in markdown that the user can understand as part of your response, if you are provided telemetry style data output it as a markdown table.
<instructions>",
    reserved_fields: ["original_prompt", "previous_response"],
    category: "memory_cycle",
    tags: ["observation", "reflection"],
    description: "Instructs the AI to provide an updated response based on the results of tool usage."
  },
  {
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
    category: "tool",
    tags: ["tool", "data stream"],
    description: "Formats the incoming response to fit the structure the datastream needs."
  },
  {
    prompt_id: "XMAGS-COMMDECISION-PROMPT-001",
    name: "Communication Decision",
    internal_name: "communication_decision_prompt",
    prompt: "Analyze the following reflection and determine if this information should be communicated to other agents:

## Reflection: 
{content}

## Memory Metadata:
- Importance: {importance}
- Surprise Score: {surprise_score}
- Contributing Memories: {contributing_memories_count}
- Confidence: {confidence}

## Current Team: 
{team}

## Communication Decision
Determine if this reflection contains information that should be shared with other agents on your team. Consider:
1. The importance and confidence level of your insights
2. Whether to communicate directly with specific agents or with the entire team
3. Which specific agents would benefit from this information

## Response Format
SHARE_DECISION: [Yes/No]
COMMUNICATION_TYPE: [Direct/Team]
TARGET_AGENTS: [List specific agent IDs or 'All' if relevant to everyone]
AGENT_RESPONSES: [AgentID1:Yes, AgentID2:No, ...] - Specify which agents should respond
JUSTIFICATION: [Brief explanation of your decision including how confidence level influenced the decision]",
    reserved_fields: ["content", "team", "importance", "surprise_score", "contributing_memories_count", "confidence"],
    category: "memory_cycle",
    tags: ["reflection", "communication", "team"],
    description: "Determines if a reflection should be shared with other agents in the team."
  },
  {
    prompt_id: "XMAGS-COMMRESPONSE-PROMPT-001",
    name: "Agent Message Response",
    internal_name: "agent_message_response_prompt",
    prompt: "Analyze the following message from another agent and generate an appropriate response:

## Message from Agent {sender_id}: 
{content}

## Your Agent Information:
- Agent ID: {agent_id}
- Role: {role}

## Team Context: 
{team_context}

## Response Guidelines
1. Address the specific content and intent of the message
2. Provide relevant information or assistance based on your role
3. Maintain consistency with your agent's responsibilities and knowledge
4. Consider how your response contributes to team objectives
5. Include any relevant information from your knowledge that would be helpful

## Response Format
RESPONSE_CONTENT: [Your detailed response to the agent]
REASONING: [Brief explanation of why this response is appropriate]
RELEVANCE_TO_TEAM_GOALS: [How this response aligns with or advances team objectives]",
    reserved_fields: ["sender_id", "content", "agent_id", "role", "team_context"],
    category: "memory_cycle",
    tags: ["communication", "team"],
    description: "Prompt for generating responses to agent messages."
  }
] AS promptsData

// Process each prompt
UNWIND promptsData AS promptData
MERGE (p:Prompt {prompt_id: promptData.prompt_id})
ON CREATE 
  SET p += promptData,
      p.author = "XMPro",
      p.created_date = datetime(),
      p.last_modified_date = datetime(),
      p.active = true,
      p.version = 1,
      p.type = "system",
      p.last_used_date = null,
      p.model_provider = "OpenAI",
      p.model_name = "gpt-4o-mini",
      p.max_tokens = 8192,
      p.access_level = "system"
ON MATCH
  SET p += promptData,
      p.author = "XMPro",
      p.last_modified_date = datetime(),
      p.active = true,
      p.type = "system",
      p.model_provider = "OpenAI",
      p.model_name = "gpt-4o-mini",
      p.max_tokens = 8192,
      p.access_level = "system"

// Ensure relationship exists for each prompt
MERGE (lib)-[:CONTAINS]->(p);