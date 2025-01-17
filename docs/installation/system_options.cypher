MERGE (so:SystemOptions {id: 'SYSTEM-OPTIONS'})
ON CREATE SET
  so.reserved_fields_observation = ['user_query', 'knowledge_context'],
  so.reserved_fields_reflection = ['skills', 'experience', 'deontic_rules', 'organizational_rules', 'knowledge_context', 'recent_observations', 'past_reflections', 'available_tools'],
  so.reserved_field_user_prompt = ['current_timestamp', 'user_query', 'knowledge_context', 'available_tools', 'conversation_history'],
  so.reserved_fields_task_prompt = ['goal', 'plan_details', 'team_capabilities', 'available_actions'],
  so.models_providers = ['Anthropic', 'AzureOpenAI', 'Google', 'Ollama', 'OpenAI'],
  so.prompt_access_levels = '[
  {"value": "admin", "description": "For system administrators with full access to all prompts"},
  {"value": "user", "description": "For regular users of the system"},
  {"value": "restricted", "description": "For sensitive prompts that require special permission to access"},
  {"value": "system", "description": "For core system prompts essential for the MAGs memory cycle implementation"}
]',
  so.prompt_types = '[
  {"value": "system", "description": "For core system functionality"},
  {"value": "user", "description": "For prompts created or customized by users"},
  {"value": "template", "description": "For base prompts that can be customized or extended for specific use cases"},
  {"value": "analysis", "description": "For prompts designed to analyze or interpret data or text"},
  {"value": "generation", "description": "For prompts focused on generating new content or ideas"},
  {"value": "classification", "description": "For prompts that categorize or label input"},
  {"value": "extraction", "description": "For prompts designed to extract specific information from text"},
  {"value": "dialogue", "description": "For prompts used in conversational or interactive contexts"},
  {"value": "task-specific", "description": "For prompts designed for particular tasks within the application"},
  {"value": "utility", "description": "For helper prompts that support other processes but aren\'t main functionalities"}
]',
  so.rag_schema = '{
    "schemas": {
      "rag_general_knowledge": {
        "id": "string",
        "title": "string",
        "content": "string",
        "summary": "string",
        "author": "string",
        "source": "string",
        "url": "string",
        "publication_date": "datetime",
        "last_updated": "datetime",
        "language": "string",
        "category": "string",
        "tags": "list",
        "version": "string",
        "vector": "list",
        "related_documents": "list"
      }
    },
    "citation_structure": {
      "format": "[{0}] {1}. {2}. {3}, {4}. Available at: {5}",
      "fields": [
        "id",
        "author",
        "title",
        "source",
        "publication_date",
        "url"
      ]
    }
  }',
  so.importance_scoring = '{
    "frequency": {
        "scale_factor": 2.0,
        "log_base": 2.0,
        "input_scale": 1.0,
        "offset": 0.1
    },
    "duration": {
        "threshold": 60.0,
        "log_scale": 1.0,
        "log_base": 2.0,
        "log_offset": 0.1,
        "linear_scale": 0.5,
        "linear_factor": 0.01
    },
    "agent_weights": {
        "assistant_frequency_weight": 0.7,
        "assistant_duration_weight": 0.3,
        "content_frequency_weight": 0.3,
        "content_duration_weight": 0.7
    }
}',
so.created_date = datetime()
ON MATCH SET
  so.reserved_fields_observation = ['user_query', 'knowledge_context'],
  so.reserved_fields_reflection = ['skills', 'experience', 'deontic_rules', 'organizational_rules', 'knowledge_context', 'recent_observations', 'past_reflections', 'available_tools'],
  so.reserved_field_user_prompt = ['current_timestamp', 'user_query', 'knowledge_context', 'available_tools', 'conversation_history'],
  so.reserved_fields_task_prompt = ['goal', 'plan_details', 'team_capabilities', 'available_actions'],
  so.models_providers = ['Anthropic', 'AzureOpenAI', 'Google', 'Ollama', 'OpenAI'],
  so.prompt_access_levels = '[
  {"value": "admin", "description": "For system administrators with full access to all prompts"},
  {"value": "user", "description": "For regular users of the system"},
  {"value": "restricted", "description": "For sensitive prompts that require special permission to access"},
  {"value": "system", "description": "For core system prompts essential for the MAGs memory cycle implementation"}
]',
  so.prompt_types = '[
  {"value": "system", "description": "For core system functionality"},
  {"value": "user", "description": "For prompts created or customized by users"},
  {"value": "template", "description": "For base prompts that can be customized or extended for specific use cases"},
  {"value": "analysis", "description": "For prompts designed to analyze or interpret data or text"},
  {"value": "generation", "description": "For prompts focused on generating new content or ideas"},
  {"value": "classification", "description": "For prompts that categorize or label input"},
  {"value": "extraction", "description": "For prompts designed to extract specific information from text"},
  {"value": "dialogue", "description": "For prompts used in conversational or interactive contexts"},
  {"value": "task-specific", "description": "For prompts designed for particular tasks within the application"},
  {"value": "utility", "description": "For helper prompts that support other processes but aren\'t main functionalities"}
]',
  so.rag_schema = '{
    "schemas": {
      "rag_general_knowledge": {
        "id": "string",
        "title": "string",
        "content": "string",
        "summary": "string",
        "author": "string",
        "source": "string",
        "url": "string",
        "publication_date": "datetime",
        "last_updated": "datetime",
        "language": "string",
        "category": "string",
        "tags": "list",
        "version": "string",
        "vector": "list",
        "related_documents": "list"
      }
    },
    "citation_structure": {
      "format": "[{0}] {1}. {2}. {3}, {4}. Available at: {5}",
      "fields": [
        "id",
        "author",
        "title",
        "source",
        "publication_date",
        "url"
      ]
    }
  }',
  so.importance_scoring = '{
      "frequency": {
          "scale_factor": 2.0,
          "log_base": 2.0,
          "input_scale": 1.0,
          "offset": 0.1
      },
      "duration": {
          "threshold": 60.0,
          "log_scale": 1.0,
          "log_base": 2.0,
          "log_offset": 0.1,
          "linear_scale": 0.5,
          "linear_factor": 0.01
      },
      "agent_weights": {
          "assistant_frequency_weight": 0.7,
          "assistant_duration_weight": 0.3,
          "content_frequency_weight": 0.3,
          "content_duration_weight": 0.7
      }
  }',
  so.last_modified_date = datetime()
RETURN so
