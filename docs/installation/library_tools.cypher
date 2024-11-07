// Create Tool Library
CREATE (tl:Library {name: "Tool Library", type: "Tool", created_date: datetime()})

// Create SQL Query Tool
CREATE (sql:Tool {
    name: 'SqlRecommendationQueryTool',
    active: true,
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
);"',
    reserved_fields: ["user_query"]
})
CREATE (tl)-[:CONTAINS]->(sql)

CREATE (duckduckgo:Tool {
    name: 'DuckDuckGoWebSearchTool',
    active: true,
    description: 'Performs a web search using DuckDuckGo and returns relevant information',
    class_name: 'DuckDuckGoWebSearchTool',
    created_date: datetime(),
    last_modified_date: datetime(),
    options: '{"maxResults": 5, "safeSearch": true}'
})
CREATE (tl)-[:CONTAINS]->(duckduckgo)

// Create metrics for all tools
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