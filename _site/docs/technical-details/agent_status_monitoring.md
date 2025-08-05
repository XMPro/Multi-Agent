# Agent Status Monitoring and Error Handling System

## Concept

The Agent Status Monitoring and Error Handling System is designed to provide real-time insights into the operational status of agents within the Multi-Agent System (MAGS). It combines periodic status updates with comprehensive error handling to ensure robust operation and facilitate easy monitoring and debugging.

## Key Components

1. **Status Updates**: Regular broadcasts of agent operational metrics.
2. **Error Handling**: Centralized error capture and reporting.
4. **Activity Counters**: Tracking of key operations (memories processed, plans generated, conversations handled).
5. **Tool Usage Metrics**: Tracking the usage frequency of different tools.

## Sample Message Broker Payloads

### Startup

```json
{
  "agent_id": "FERM-DATA-AGENT-001",
  "event": "memory_cycle_started",
  "service_name": "XMPRO-MAGS-Memory-Cycle",
  "team_id": "AUSTIN-PROD-FERM-TEAM-001",
  "timestamp": "2024-11-06T19:27:22.5448234Z"
}
```

### Shutdown

```json
{
  "agent_id": "FERM-DATA-AGENT-001",
  "event": "memory_cycle_shutdown",
  "service_name": "XMPRO-MAGS-Memory-Cycle",
  "team_id": "AUSTIN-PROD-FERM-TEAM-001",
  "timestamp": "2024-11-06T19:34:05.5395374Z"
}
```

### Status

```json
{
  "agent_id": "VAXSC-COLD-AGENT-001",
  "timestamp": "2024-10-15T14:38:58.2396175Z",
  "state": "Running",
  "memories_processed": 0,
  "plans_generated": 0,
  "error_message": null,
  "last_reset_time": "2024-10-14T22:11:00.4514458Z",
  "conversations_handled": 0,
  "tool_usage": "{}"
}
```

### Error

```json
{
  "agent_id": "FERM-DATA-AGENT-001",
  "exception_type": "",
  "message": "",
  "stack_trace": "",
  "timestamp": "2024-11-06T19:34:05.5395374Z"
}
```

## Implementation Details

### Status Updates

The `MemoryCycle` class implements a timer-based status update mechanism:

The `StatusUpdateIntervalMs` and `CounterResetIntervalMs` are configured and read from `System Options` in the graph database.  Adjust them with caution. 

```C#
private Timer _statusUpdateTimer;
private const int StatusUpdateIntervalMs = 60000; // 1 minute
private const int CounterResetIntervalMs = 24 * 60 * 60 * 1000; // 24 hours

public void Start(string agentId)
{
    // ...
    _statusUpdateTimer = new Timer(SendStatusUpdate, null, 0, StatusUpdateIntervalMs);
    // ...
}
```

The `SendStatusUpdate` method collects and publishes the status:

```C#
private async void SendStatusUpdate(object state)
{
    var status = new AgentStatus
    {
        AgentId = _agentId,
        Timestamp = DateTime.UtcNow,
		//...
    };

    await _messageBroker.PublishStatusUpdateAsync(_agentId, agentInstance.TeamId, status);
}
```
### Error Handling

The `GlobalExceptionHandler` class provides centralized error management:

```C#
public class GlobalExceptionHandler
{
    private readonly ConcurrentDictionary<string, string> _lastErrors = new ConcurrentDictionary<string, string>();

    public async Task HandleExceptionAsync(Exception ex, string agentId, string teamId)
    {
        var errorMessage = $"{ex.GetType().Name}: {ex.Message}";
        _lastErrors[agentId] = errorMessage;
        await _messageBroker.PublishErrorMessageAsync(agentId, teamId, errorMessage, ex);
    }

    public string GetLastError(string agentId)
    {
        _lastErrors.TryGetValue(agentId, out var errorMessage);
        return errorMessage;
    }
}
```

### Activity Counters

Thread-safe counters track key operations:

```C#
public void IncrementMemoriesProcessed()
{
    Interlocked.Increment(ref _memoriesProcessed);
}

public void IncrementPlansGenerated()
{
    Interlocked.Increment(ref _plansGenerated);
}

public void IncrementConversationsHandled()
{
    Interlocked.Increment(ref _conversationsHandled);
}
```
### Tool Usage Tracking

```C#
public void IncrementToolUsage(string toolName)
{
    lock (_toolUsage)
    {
        if (!_toolUsage.ContainsKey(toolName))
        {
            _toolUsage[toolName] = 0;
        }
        _toolUsage[toolName]++;
    }
}
```
## System Architecture Diagram

```mermaid
graph TD
    A[Agent] --> B[MemoryCycle]
    B --> C[Status Update Timer]
    B --> D[Counter Reset Timer]
    B --> E[GlobalExceptionHandler]
    C --> F[SendStatusUpdate]
    D --> G[ResetCounters]
    E --> H[HandleExceptionAsync]
    F --> I[MessageBroker]
    H --> I
    I --> J[Status Topic]
    I --> K[Error Topic]
```

## Data Flow Diagram

```mermaid
sequenceDiagram
    participant A as Agent
    participant M as MemoryCycle
    participant G as GlobalExceptionHandler
    participant B as MessageBroker
    participant T as Status Topic
    participant E as Error Topic

    A->>M: Perform Operation
    alt Success
        M->>M: Increment Counters
    else Error
        M->>G: HandleExceptionAsync
        G->>B: PublishErrorMessageAsync
        B->>E: Publish Error
    end
    loop Every Minute
        M->>M: SendStatusUpdate
        M->>G: GetLastError
        M->>B: PublishStatusUpdateAsync
        B->>T: Publish Status
    end
```

## Reasoning and Benefits

1. **Real-time Monitoring**: Regular status updates provide insights into agent performance and health.
2. **Centralized Error Handling**: The `GlobalExceptionHandler` ensures consistent error management across the system.
3. **Operation Insights**: Counters for memories processed and plans generated offer visibility into agent activity levels.
4. **Scalability**: The system is designed to work with multiple agents, each maintaining its own status and error information.
5. **Fault Tolerance**: Error handling and reporting continue even if status updates fail, ensuring no loss of critical information.
6. **Conversation Insights**: Tracking the number of conversations handled provides visibility into the agent's interaction load.
7. **Tool Utilization**: Monitoring tool usage helps identify which tools are most frequently used, informing potential optimizations or resource allocations.

## Conclusion

This system provides a robust framework for monitoring and maintaining the health of agents in the MAGS. By combining regular status updates with centralized error handling, it offers a comprehensive view of system operations, facilitating quick identification and resolution of issues. The use of message brokers for communication ensures scalability and flexibility, allowing for easy integration with various monitoring and alerting systems.
