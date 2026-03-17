// Create Tool Library
CREATE (tl:Library {name: "Tool Library", type: "Tool", created_date: datetime()})

CREATE (duckduckgo:Tool {
    id: 'DUCKD-WSRCH-TOOL-001',
    name: 'DuckDuckGoWebSearchTool',
    active: true,
    author: "XMPro",
    description: 'A privacy-focused web search tool that leverages DuckDuckGos search engine to retrieve relevant online information. The tool supports configurable result limits (default: 5) and content filtering through safe search (default: enabled). It handles web queries with built-in rate limiting (60 requests/minute) and timeout protection (5s connect, 10s read). For optimal results, use specific search queries and consider including time-relevant terms for current information. The tool returns structured results including titles, URLs, and snippets while maintaining user privacy. Advanced features include region-specific searching (using wt-wt format) and time-based filtering (day/week/month/year). Best used with focused, well-formed queries and appropriate safe search settings based on context. Handles errors gracefully and provides clear feedback on rate limits or connectivity issues.',
    class_name: 'DuckDuckGoWebSearchTool',
    created_date: datetime(),
    last_modified_date: datetime(),
    options: '{"maxResults": 5, "safeSearch": true}'
})
CREATE (tl)-[:CONTAINS]->(duckduckgo)

CREATE (ncalc:Tool {
    id: 'NCALC-EXPR-TOOL-001',
    name: 'NCalcTool',
    active: true,
    author: "XMPro",
    description: 'An internal mathematical and logical expression evaluation tool that accepts natural language queries and evaluates them at runtime. The tool uses an internal LLM call to translate the user query into a valid NCalc expression, then evaluates it using the NCalc engine. Supports arithmetic operators (+, -, *, /, %), comparisons (=, !=, <, >, <=, >=), logical operators (and, or, not), and a comprehensive set of mathematical functions including Abs, Ceiling, Floor, Max, Min, Pow, Round, Sign, Sqrt, Truncate, trigonometric functions (Sin, Cos, Tan, Asin, Acos, Atan), conditionals (if), and constants (Pi, e). Returns both the generated expression and its computed result. The internal LLM prompt can be overridden via the Prompt Manager using the identifier ncalc_expression_prompt. This is an internal tool hardcoded into the agent system; no external configuration is required.',
    class_name: 'NCalcTool',
    created_date: datetime(),
    last_modified_date: datetime(),
    options: '{}'
})
CREATE (tl)-[:CONTAINS]->(ncalc)

// Create metrics for all tools
WITH tl
MATCH (t:Tool)
CREATE (t)-[:HAS_METRICS]->(m:Entry {
    type: 'Metric',
    context: 'Tool',
    category: 'Aggregate',
    entry_id: randomUUID(),
    created_date: datetime(),
    last_modified_date: datetime(),
    average_response_time: 0,
    input_assistant_tokens: 0,
    input_other_tokens: 0,
    input_overhead_tokens: 0,
    input_system_tokens: 0,
    input_token_usage: 0,
    input_user_tokens: 0,
    total_token_usage: 0,
    failed_calls: 0,
    successful_calls: 0,
    total_calls: 0,
    total_data_processed: 0,
    total_response_time: 0,
    output_reasoning_tokens: 0,
})
