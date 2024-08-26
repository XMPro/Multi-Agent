# Prompt Manager

## MAGS System Prompt Id Structure

Structure: `XMAGS-[Process]-PROMPT-[Version]`

Example: `XMAGS-OBS-PROMPT-001`

Components:
- XMAGS: Fixed identifier for the Multi-Agent System
- [Process]: The specific cognitive process (OBS, REF, PLAN, ACT)
- PROMPT: Fixed identifier for Prompt type
- [Version]: A numeric version identifier

### Process Codes:
- OBS: Observation
- REF: Reflection
- PLAN: Planning
- ACT: Action

### Examples

| Prompt Purpose     | Prompt ID             | Breakdown                                                                     |
|--------------------|------------------------|-------------------------------------------------------------------------------|
| Action Prompt      | XMAGS-ACT-PROMPT-001  | XMAGS: Multi-Agent System<br>ACT: Action<br>PROMPT: Type<br>001: Version      |
| Observation Prompt | XMAGS-OBS-PROMPT-001  | XMAGS: Multi-Agent System<br>OBS: Observation<br>PROMPT: Type<br>001: Version |
| Planning Prompt    | XMAGS-PLAN-PROMPT-001 | XMAGS: Multi-Agent System<br>PLAN: Planning<br>PROMPT: Type<br>001: Version   |
| Reflection Prompt  | XMAGS-REF-PROMPT-001  | XMAGS: Multi-Agent System<br>REF: Reflection<br>PROMPT: Type<br>001: Version  |

Note: As the system expands, new process codes can be added to accommodate additional cognitive processes or functionalities.

## Fields

| Field Name         | Type             | Description                                        | Expanded Rationale                                                                                                                                                                                                                                    |
|--------------------|------------------|----------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| access_level       | String           | Indicates who can use or modify this prompt        | Useful for implementing access control. In a multi-user or organization setting, this allows for restricting sensitive prompts to certain user groups or individuals, enhancing security and privacy.                                                 |
| active             | Boolean          | Indicates if the prompt is currently in use        | Allows for easy filtering of current vs. archived prompts. This is particularly useful in large systems where prompts may be deprecated but kept for historical reasons. It simplifies queries for active prompts.                                    |
| author             | String           | The creator of the prompt                          | Important for attribution and accountability. In a multi-user system, this allows tracking who created which prompts, which can be useful for quality control, performance evaluation, and giving credit where it's due.                              |
| category           | String           | The general category or type of the prompt         | Allows for easier organization and retrieval of prompts. This can be used to group similar prompts together, making it easier for users to find relevant prompts for their needs. It also allows for analysis of prompt performance by category.      |
| created_date       | DateTime         | Date and time the prompt was created               | Useful for tracking the prompt's lifecycle. This timestamp helps in auditing, allows for chronological sorting of prompts, and can be used to analyze prompt creation patterns over time.                                                             |
| description        | String           | A brief explanation of the prompt's purpose        | Provides context without having to read the full prompt. This helps users quickly understand what a prompt does without needing to interpret the prompt text itself. It's particularly useful in large prompt libraries.                              |
| internal_name      | String           | A code-friendly name for backend use               | This internal name is used code, queries, and other backend operations where a simplified, consistent naming format is beneficial.                                                                                                                    |
| last_modified_date | DateTime         | Date and time of the last modification             | Important for tracking changes and auditing. This helps identify which prompts have been recently updated, which is crucial for version control and ensuring users are working with the most up-to-date prompts.                                      |
| last_used_date     | DateTime         | Date the prompt was last utilized                  | Useful for identifying outdated or frequently used prompts. This can help in maintenance tasks, such as archiving old prompts or prioritizing the review of frequently used ones. It can also be used to analyze usage patterns over time.            |
| model_name         | String           | The specific AI model this prompt is optimized for | Provides more granular information about model compatibility. This allows for fine-tuned optimization of prompts for specific models, which can be crucial for achieving the best performance.                                                        |
| model_type         | String           | The type of AI model this prompt is designed for   | Ensures prompts are used with compatible model architectures. This is crucial for maintaining prompt effectiveness across different AI systems. It allows for easy filtering of prompts suitable for specific model types.                            |
| name               | String           | A unique, human-readable name for the prompt       | Provides a quick, identifiable reference for the prompt. This makes it easier for users to search for and recognize prompts without needing to read the full prompt text. It also serves as a natural key for ensuring uniqueness across all prompts. |
| prompt             | String           | The actual prompt text                             | Core content of the prompt. This is the main text that will be used to guide the AI's response. It's crucial for the functioning of the system and is what users will primarily interact with.                                                        |
| prompt_id          | String           | Unique identifier for the prompt                   | Essential for referencing specific prompts. This allows for efficient querying and relationship building in the graph database. It's particularly useful when linking prompts to other entities or when tracking prompt versions.                     |
| reserved_fields    | Object/String    | Any reserved fields                                | Useful for storing prompt-specific metadata that doesn't fit into other categories. This flexibility allows for future expansions without changing the node structure. It can store custom attributes that are specific to certain types of prompts.  |
| tags               | Array of Strings | Relevant tags or keywords                          | Enhances searchability and categorization. Tags provide a flexible way to associate prompts with multiple concepts, making them easier to find. They can also be used for filtering and analyzing trends in prompt creation and usage.                |
| version            | Integer          | Current version number of the prompt               | Helps in tracking the evolution of the prompt. This is crucial for version control, allowing users to understand how many iterations a prompt has gone through and potentially rollback to previous versions if needed.                               |

## Root Node
There is a root node called PromptLibrary to which all prompts are linked.  The reasons for this are:

1. Organization: It provides a clear organizational structure, making it easier to manage and understand the relationship between prompts.

2. Querying: While it adds one more hop in some queries, it makes it much easier to perform operations on all prompts (e.g., finding all prompts, updating properties across all prompts).

3. Consistency: Having a root node allows you to enforce consistent properties or relationships across all prompts more easily.

4. Scalability: As your prompt library grows, having a root node will make it easier to manage and maintain the structure.

5. Flexibility: You can still easily query individual prompts, and the added structure doesn't significantly impact performance for most use cases.


