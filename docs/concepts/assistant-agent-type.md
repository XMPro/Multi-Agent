# MAGS: Assistant Agent Type

## Overview

MAGS supports multiple agent types, each with different behaviours in the ORPA (Observe-Reflect-Plan-Act) cycle. The **Assistant** type is designed for conversational, user-facing agents that respond to human queries — as opposed to **Decision** and **Standard** types that autonomously observe, plan, and act on their environment.

---

## Agent Types Comparison

| Capability | Decision / Standard | Assistant |
|-----------|-------------------|-----------|
| Autonomous observation (ORPA cycle) | ✅ Full ORPA cycle | ❌ No autonomous observation |
| Planning and plan execution | ✅ Creates and executes plans | ❌ No planning |
| Vector store initialization | ✅ Full vector store setup | ❌ Skipped (lighter footprint) |
| Conversation handling | ✅ Uses shared conversation prompt | ✅ Uses its own custom prompt |
| Memory and recall | ✅ Full memory system | ✅ Memory available but simplified |
| Significance scoring | Standard weighting | Prioritises frequency and responsiveness |

---

## How Assistant Agents Handle Conversations

### The Two-Prompt Architecture

Every MAGS agent has two prompts that shape its LLM interactions:

1. **System Prompt** — Defines the agent's identity, expertise, behavioural rules, and boundaries. This is set in the agent's profile and is always sent as the `system` role message to the LLM. All agent types use this the same way.

2. **Conversation Prompt** — The template used to structure the `user` role message sent to the LLM during a conversation. This is where Assistant agents differ from other types.

### How the Conversation Prompt Is Selected

When a conversation message arrives, MAGS selects the conversation prompt template based on the agent type:

**For Assistant agents:**
- MAGS uses the agent's **User Prompt** — a custom prompt template stored on the agent instance itself
- This allows each Assistant agent to have its own unique conversation style, instructions, and response format
- The model provider and model name come from the agent's profile

**For Decision and Standard agents:**
- MAGS first checks the **Prompt Library** for a shared prompt called `conversation_prompt`
- If found, it uses the library prompt (which can also specify its own model provider and model name)
- If not found, it falls back to a built-in default conversation prompt
- This means all Decision/Standard agents on a team share the same conversation prompt template

### Why This Matters

The Assistant type's custom prompt mechanism allows you to create specialised conversational agents without modifying the shared prompt library. For example:

- A **Process Expert Assistant** could have a User Prompt that instructs it to always reference operating procedures and safety guidelines when answering questions
- A **Data Analysis Assistant** could have a User Prompt that instructs it to format responses with tables and calculations
- A **Training Assistant** could have a User Prompt that uses a Socratic teaching style

Each of these would have different User Prompts but could share the same System Prompt (defining their domain expertise) or have different System Prompts as well.

---

## How to Configure an Assistant Agent

### Setting the Agent Type

The agent type is set on the agent instance node in the graph database. Set the `type` field to `Assistant`.

### Setting the System Prompt

The System Prompt is defined in the agent's **profile** (not the instance). It defines who the agent is — its role, expertise, and behavioural rules. This is the same mechanism used by all agent types.

### Setting the User Prompt (Conversation Template)

The User Prompt is set on the agent **instance** node in the graph database, in the `user_prompt` field. This is the custom conversation prompt template that replaces the shared prompt library template.

The User Prompt template can include placeholders that MAGS replaces at runtime:
- `{user_query}` — The user's input message
- `{knowledge_context}` — Context retrieved from RAG (knowledge base)
- `{current_timestamp}` — Current UTC timestamp for time awareness

### What Happens During a Conversation

When a user sends a message to an Assistant agent:

1. MAGS retrieves relevant context from the agent's knowledge base (RAG)
2. MAGS retrieves relevant memories (conversation summaries and observations)
3. MAGS selects the conversation prompt template — for Assistant agents, this is the custom User Prompt
4. MAGS fills in the template placeholders with the user's message, RAG context, memory context, and timestamp
5. MAGS sends the filled prompt to the LLM with the System Prompt as the system message
6. The LLM response is returned to the user

---

## What Assistant Agents Don't Do

Because Assistant agents are designed for conversation rather than autonomous operation, several MAGS subsystems are simplified or disabled:

- **No autonomous observation cycle** — Assistant agents don't independently observe their environment on a timer. They respond when spoken to.
- **No planning or plan execution** — Assistant agents don't create PDDL plans or execute plan actions. They provide information and recommendations through conversation.
- **No vector store initialization** — The full vector store setup is skipped for Assistant agents, reducing startup time and resource usage.
- **Simplified significance scoring** — When Assistant agents do create observations (from conversation content), the significance calculation prioritises frequency and responsiveness over other factors.

---

## When to Use Each Agent Type

| Use Case | Recommended Type | Why |
|----------|-----------------|-----|
| Autonomous process monitoring and control | Decision | Needs full ORPA cycle, planning, and action execution |
| Data analysis with tool use | Standard | Needs observation and planning but may not need full decision authority |
| User-facing Q&A or advisory | **Assistant** | Conversational, responds to queries, custom prompt per agent |
| Specialised content processing | **Assistant** | Custom prompt defines processing instructions |

---

## Example: Assistant vs Decision Agent for the Same Domain

Consider a process engineering domain:

**Decision Agent** (e.g., "Optimisation Decision-Maker"):
- System Prompt: Defines its role as the decision-maker for a depropaniser column
- Conversation Prompt: Shared from prompt library (same as other Decision agents)
- Behaviour: Autonomously observes process data, reflects on trends, creates plans, executes setpoint changes
- Conversations: Can answer questions about its decisions, but conversation is secondary to its autonomous role

**Assistant Agent** (e.g., "Process Engineering Advisor"):
- System Prompt: Defines its expertise in distillation and fractionation
- User Prompt: Custom template that instructs it to always reference operating procedures, provide calculations, and cite safety guidelines
- Behaviour: Waits for user questions, retrieves relevant knowledge, provides detailed engineering advice
- Conversations: This IS its primary role — it exists to help humans make better decisions

Both agents can have the same domain knowledge (via RAG collections) and the same System Prompt defining their expertise. The difference is in how they operate: the Decision agent acts autonomously, while the Assistant agent responds to human queries with a customised conversational style.
