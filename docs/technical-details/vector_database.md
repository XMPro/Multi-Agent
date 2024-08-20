# Vector Database

## Memory Structure

Our vector database is used to store and retrieve agent memories efficiently. Here's the structure of our memory entries:

| Field Name            | Data Type    | Purpose                                                                    |
|-----------------------|--------------|----------------------------------------------------------------------------|
| actionable_insights   | VARCHAR      | Contains specific actions or recommendations                               |
| agent_id              | VARCHAR      | Identifies the agent who created the memory                                |
| context               | VARCHAR      | Stores relevant contextual information                                     |
| contributing_memories | VARCHAR      | Stores IDs of memories that contributed to this memory                     |
| graph_Id              | VARCHAR      | The link back to the graph                                                 |
| id                    | VARCHAR      | Unique identifier for each memory entry                                    |
| importance            | FLOAT        | Stores the calculated importance score of the memory                       |
| key_points            | VARCHAR      | Stores main points or insights from the memory                             |
| outcomes              | VARCHAR      | Records the results of executed plans or actions                           |
| priority              | INT          | Represents the priority level of a plan or action                          |
| status                | VARCHAR      | Indicates the current status of a plan or action                           |
| summary               | VARCHAR      | Contains a brief summary of the memory content                             |
| timestamp             | INT64        | Records when the memory was created                                        |
| type                  | VARCHAR      | Specifies the type of memory (e.g., Observation, Reflection, Plan, Action) |
| vector                | FLOAT_VECTOR | Stores the embedding of the combined text fields    

## Benefits and Reasoning

1. **Comprehensive Memory Representation**
   - Captures various types of cognitive processes (observations, reflections, plans, actions)
   - Allows for a more complete representation of an agent's mental state and activities

2. **Efficient Retrieval**
   - Enables both semantic (vector) and structured (metadata) searches
   - Provides flexibility in querying memories based on content similarity or specific attributes

3. **Temporal Analysis**
   - Facilitates time-based queries and analysis
   - Enables studying the evolution of an agent's knowledge and decision-making over time

4. **Importance-Based Filtering**
   - Allows prioritization of more significant memories
   - Helps manage information overload and focus on critical information

5. **Contextual Understanding**
   - Provides rich contextual information for each memory
   - Enhances the agent's ability to understand and utilize memories effectively

6. **Traceability**
   - Allows tracking the origins and influences of memories
   - Enables understanding the development of ideas and decision-making processes

7. **Action Orientation**
   - Incorporates plans, actions, and their outcomes
   - Supports learning from experiences and improving future decision-making

8. **Flexible Memory Types**
   - Accommodates different types of memories
   - Allows the system to handle various cognitive processes and adapt to different domains