# OpenTelemetry Tracing Guide

## Table of Contents
1. [Overview](#overview)
2. [Naming Convention](#naming-convention)
   - [Activity Names](#activity-names)
   - [Tags](#tags)
3. [Implementation](#implementation)
4. [Usage](#usage)
5. [Best Practices](#best-practices)
6. [Examples](#examples)

## Overview

This document outlines the OpenTelemetry tracing conventions and best practices for the XMPro MAGS (Multi-Agent System) project. It provides guidelines for consistent naming, tagging, and implementation of tracing across all components of the system.

## Naming Convention

### Activity Names

Activity names follow this structure:

```
MAGS-[ComponentType]-[Operation]
```

- `MAGS`: Prefix indicating that this activity is part of the XMPro MAGS system.
- `[ComponentType]`: Type of component initiating the activity.
    - _EMBEDDING (options for Azure Open AI, Ollama, Open AI)
    - _STRATEGY (the various planning strategies)
    - AGENT_INSTANCE
    - DATABASE_MANAGER
    - LANGUAGE_MODELS
    - MEMORY_CYCLE
    - MILVUS_VECTOR_DATABASE
    - MQTT
    - NEO4j_CONNECTION_POOL
    - PROMPT_MANAGER
- `[Operation]`: Specific operation being performed.

Both ComponentType and Operation are in UPPERCASE in the activity name.

### Tags

Standard tags:

- `mags.component_type`: Type of component (snake_case)
- `mags.operation`: Operation being performed (snake_case)
- `mags.agent_id`: Identifier of the agent involved (when applicable, original format)

Tag naming and value conventions:

1. **Tag Names**: Always use snake_case (lowercase with underscores).
2. **Tag Values**:
   - For `mags.component_type` and `mags.operation`: Use snake_case.
   - For `mags.agent_id`: Preserve the original format of the agent ID.

## Implementation

The tracing functionality is implemented in the `OpenTelemetrySetup` class:

```C#
public class OpenTelemetrySetup : IDisposable
{
    // ... other members ...

    public Activity? StartActivity(string componentType, string operation, string? agentId = null)
    {
        string activityName = $"MAGS-{componentType.ToUpperInvariant()}-{operation.ToUpperInvariant()}";

        var activity = ActivitySource.StartActivity(activityName);
        
        if (activity != null)
        {
            activity.SetTag("mags.component_type", componentType.ToLowerInvariant().Replace(" ", "_"));
            activity.SetTag("mags.operation", operation.ToLowerInvariant().Replace(" ", "_"));
            if (agentId != null)
            {
                activity.SetTag("mags.agent_id", agentId); // Keep original format
            }
        }

        Logger.LogDebug("Started activity: {ActivityName}, AgentId: {AgentId}", activityName, agentId);
        return activity;
    }

    // ... other methods ...
}
```

## Usage

To create a new activity:

```C#
using var activity = _otelSetup.StartActivity("plan and solve strategy", "generate plan", Agent.AgentId);
```

This results in:
- Activity name: `MAGS-PLAN_AND_SOLVE_STRATEGY-GENERATE_PLAN`
- Tags:
  - `mags.component_type`: `plan_and_solve_strategy`
  - `mags.operation`: `generate_plan`
  - `mags.agent_id`: `WTR-QUAL-AGENT-001` (assuming this is the format of Agent.AgentId)

## Current Implementation

### General Practices

1. **Public API Method Tracing**: We systematically trace all public API methods across our components, providing clear entry points for analysis.

2. **Selective Private Method Tracing**: We've identified and implemented tracing for key private methods, focusing on:
   - Computationally expensive operations
   - I/O operations (database queries, file operations, network calls)
   - Methods with complex business logic
   - Frequently called methods and potential bottlenecks

3. **Call Stack Consideration**: Our tracing implementation takes into account the depth of our call stack, with traces at various levels of abstraction to provide a comprehensive view of system behavior.

4. **Performance Balancing**: We've struck a balance between granularity and performance, implementing coarse-grained tracing across the system with finer-grained tracing in critical areas.

### MAGS-Specific Practices

1. **Agent Operations**: We trace all main operations of our agents, including planning cycles and decision-making processes, providing insights into agent behavior and performance.

2. **Inter-component Communication**: Our tracing covers methods involved in communication between different components, allowing us to monitor and optimize system interactions.

3. **Resource-intensive Operations**: We've implemented tracing for methods involving heavy computation or significant resource usage, helping us identify and address performance bottlenecks.

4. **Error-prone Areas**: We've added comprehensive tracing to methods known to be error-prone or critical for system stability, enhancing our ability to quickly identify and resolve issues.

5. **Configuration and Initialization**: Our tracing includes important configuration and initialization methods, providing visibility into system startup and configuration processes.

## Examples

### Tracing in a Strategy Class

```C#
public class PlanAndSolveStrategy
{
    private readonly OpenTelemetrySetup _otelSetup;
    private readonly string _agentId;

    public PlanAndSolveStrategy(OpenTelemetrySetup otelSetup, string agentId)
    {
        _otelSetup = otelSetup;
        _agentId = agentId;
    }

    // Public method - always trace
    public async Task<Plan> GeneratePlanAsync(PlanningContext context)
    {
        using var activity = _otelSetup.StartActivity("plan_and_solve_strategy", "generate_plan", _agentId);
        // Method implementation
    }

    // Private method - trace selectively based on complexity and importance
    private async Task<List<Action>> GenerateActionsAsync(PlanningContext context)
    {
        using var activity = _otelSetup.StartActivity("plan_and_solve_strategy", "generate_actions", _agentId);
        // Method implementation
    }

    // Private helper method - might not need tracing unless it becomes a bottleneck
    private bool ValidatePlanningContext(PlanningContext context)
    {
        // No tracing here unless it becomes necessary
        // Method implementation
    }
}
```

## Conclusion

Our current implementation of OpenTelemetry tracing in the XMPro MAGS project provides us with valuable insights into system behavior and performance. By following best practices and implementing targeted tracing across our components, we've created a robust foundation for monitoring and analyzing our multi-agent system. As we continue to evolve our practices, we remain committed to maintaining an effective and efficient tracing system that supports the ongoing development and optimization of this project.