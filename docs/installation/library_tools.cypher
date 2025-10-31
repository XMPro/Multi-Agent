// Create Tool Library
CREATE (tl:Library {name: "Tool Library", type: "Tool", created_date: datetime()})

CREATE (duckduckgo:Tool {
    id: 'DUCKD-WSRCH-TOOL-001',
    name: 'DuckDuckGoWebSearchTool',
    active: true,
    description: 'A privacy-focused web search tool that leverages DuckDuckGos search engine to retrieve relevant online information. The tool supports configurable result limits (default: 5) and content filtering through safe search (default: enabled). It handles web queries with built-in rate limiting (60 requests/minute) and timeout protection (5s connect, 10s read). For optimal results, use specific search queries and consider including time-relevant terms for current information. The tool returns structured results including titles, URLs, and snippets while maintaining user privacy. Advanced features include region-specific searching (using wt-wt format) and time-based filtering (day/week/month/year). Best used with focused, well-formed queries and appropriate safe search settings based on context. Handles errors gracefully and provides clear feedback on rate limits or connectivity issues.',
    class_name: 'DuckDuckGoWebSearchTool',
    created_date: datetime(),
    last_modified_date: datetime(),
    options: '{"maxResults": 5, "safeSearch": true}'
})
CREATE (tl)-[:CONTAINS]->(duckduckgo)

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
    total_response_time: 0
})
