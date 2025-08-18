---
layout: default
title: "First Steps"
description: "Create your first agent and understand the basics of agent interaction"
category: "getting-started"
---

# First Steps with MAGS

After installing and configuring MAGS, it's time to create your first agent and understand how agents interact. This guide will walk you through the basic steps to get started with MAGS.

## Creating Your First Agent

### Using the Web Interface

1. **Access the dashboard**:
   - Open your browser and navigate to `http://localhost:8080`
   - Log in with your administrator credentials

2. **Create a new agent**:
   - Click on "Agents" in the main navigation
   - Click the "Create Agent" button
   - Fill in the basic information:
     - Name: "MyFirstAgent"
     - Description: "A simple test agent"
     - Type: "Assistant"

3. **Configure agent capabilities**:
   - Select the LLM model (e.g., GPT-4, Claude)
   - Set the temperature (0.7 is a good starting point)
   - Configure memory settings (default is usually fine)

4. **Define agent profile**:
   - Add a system message that defines the agent's role and capabilities
   - Example: "You are a helpful assistant that specializes in answering questions about MAGS."

5. **Save the agent**:
   - Click "Create Agent" to finalize

### Using the API

You can also create an agent programmatically:

```bash
curl -X POST http://localhost:8080/api/agents \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -d '{
    "name": "MyFirstAgent",
    "description": "A simple test agent",
    "type": "assistant",
    "model": "gpt-4",
    "temperature": 0.7,
    "systemMessage": "You are a helpful assistant that specializes in answering questions about MAGS.",
    "memorySettings": {
      "shortTermCapacity": 10,
      "retrievalCount": 5
    }
  }'
```

## Interacting with Your Agent

### Direct Interaction

1. **Open the agent chat**:
   - From the Agents list, click on "MyFirstAgent"
   - Click on the "Chat" tab

2. **Send a message**:
   - Type a message in the input field
   - Example: "What are the key components of MAGS?"
   - Press Enter or click Send

3. **View the response**:
   - The agent will process your message and respond
   - You can continue the conversation with follow-up questions

### API Interaction

You can also interact with your agent via API:

```bash
curl -X POST http://localhost:8080/api/agents/MyFirstAgent/chat \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -d '{
    "message": "What are the key components of MAGS?"
  }'
```

## Creating a Multi-Agent Team

Now let's create a simple team with two agents:

1. **Create a second agent**:
   - Follow the steps above to create another agent
   - Name: "ResearchAgent"
   - Description: "An agent that researches information"
   - System Message: "You are a research specialist that finds and summarizes information."

2. **Create a team**:
   - Click on "Teams" in the main navigation
   - Click "Create Team"
   - Fill in the team information:
     - Name: "MyFirstTeam"
     - Description: "A simple test team"

3. **Add agents to the team**:
   - Select "MyFirstAgent" and "ResearchAgent" from the list
   - Assign roles:
     - MyFirstAgent: "Coordinator"
     - ResearchAgent: "Researcher"

4. **Configure team workflow**:
   - Define how agents should collaborate
   - Set up communication protocols
   - Define task delegation rules

5. **Save the team**:
   - Click "Create Team" to finalize

## Testing Agent Collaboration

Now let's test how the agents collaborate:

1. **Start a team conversation**:
   - From the Teams list, click on "MyFirstTeam"
   - Click on the "Collaborate" tab

2. **Assign a task**:
   - Type a task that requires collaboration
   - Example: "Research the benefits of multi-agent systems and provide a summary"

3. **Observe the workflow**:
   - The coordinator agent (MyFirstAgent) will break down the task
   - The research agent will gather information
   - The coordinator will compile the final response

4. **Review the results**:
   - Examine how the agents worked together
   - Check the conversation history to see the collaboration process

## Understanding Agent Memory

Agents in MAGS have both short-term and long-term memory:

1. **View agent memory**:
   - From the agent details page, click on the "Memory" tab
   - You'll see recent interactions and stored knowledge

2. **Test memory persistence**:
   - Tell the agent some information: "The MAGS project started in 2023."
   - Later, ask: "When did the MAGS project start?"
   - The agent should recall the information

3. **Explore memory management**:
   - Check how memories are stored and retrieved
   - Observe how significance scores affect memory retention

## Next Steps

Now that you've created your first agent and team, you can:

1. **Customize agent behaviors**:
   - Modify system messages for more specialized roles
   - Adjust memory and reasoning parameters

2. **Integrate external tools**:
   - Connect agents to databases, APIs, or other systems
   - Enable agents to perform actions beyond conversation

3. **Develop complex workflows**:
   - Create multi-stage processes with multiple agents
   - Implement decision trees and conditional logic

4. **Explore advanced features**:
   - [Learn about advanced MAGS features]({{ '/getting-started/advanced-usage' | relative_url }})
   - [Understand agent architecture in depth]({{ '/docs/architecture' | relative_url }})
