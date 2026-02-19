OPTIONAL MATCH (n:SystemOptions)
REMOVE n.agent_communication
REMOVE n.consensus_config
REMOVE n.memory_retrieval
REMOVE n.confidence_scoring
REMOVE n.timing_config
REMOVE n.importance_scoring
REMOVE n.surprise_scoring

MERGE (so:SystemOptions {id: 'SYSTEM-OPTIONS'})
ON CREATE SET
  so.author = 'XMPro',
  so.reserved_fields_observation = ['name', 'user_query', 'knowledge_context'],
  so.reserved_fields_reflection = ['name', 'team_context', 'objectives_context', 'knowledge_context', 'recent_observations', 'past_reflections', 'available_tools', 'synthetic_memories'],
  so.reserved_fields_user_prompt = ['current_timestamp', 'user_query', 'knowledge_context', 'available_tools', 'history'],
  so.reserved_fields_task_prompt = ['goal', 'plan_details', 'team_capabilities', 'objective_function'],
  so.prompt_access_levels = '[{"value": "admin", "description": "For system administrators with full access to all prompts"},
  {"value": "user", "description": "For regular users of the system"},
  {"value": "restricted", "description": "For sensitive prompts that require special permission to access"},
  {"value": "system", "description": "For core system prompts essential for the MAGs memory cycle implementation"}]',
  so.allowed_planning = ['Plan & Solve'],
  so.allowed_consensus = ['SimpleMajority'],
  so.content_processor_type  = ['Failure Mode', 'Technical Report', 'Maintenance Procedure', 'Equipment Specification', 'Incident Report', 'Manual', 'Generic'],
  so.prompt_types = '[{"value": "system", "description": "For core system functionality"},
  {"value": "user", "description": "For prompts created or customized by users"},
  {"value": "template", "description": "For base prompts that can be customized or extended for specific use cases"},
  {"value": "analysis", "description": "For prompts designed to analyze or interpret data or text"},
  {"value": "generation", "description": "For prompts focused on generating new content or ideas"},
  {"value": "classification", "description": "For prompts that categorize or label input"},
  {"value": "extraction", "description": "For prompts designed to extract specific information from text"},
  {"value": "dialogue", "description": "For prompts used in conversational or interactive contexts"},
  {"value": "task-specific", "description": "For prompts designed for particular tasks within the application"},
  {"value": "utility", "description": "For helper prompts that support other processes but aren\'t main functionalities"}]',
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
  so.config_timing = '{
    "status_update_interval_ms": 60000,
    "counter_reset_interval_ms":  86400000
  }',
  so.config_importance_scoring = '{
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
  so.config_surprise_scoring = '{
    "novelty_threshold": 0.7,
    "pattern_deviation_weight": 0.6,
    "context_unexpectedness_weight": 0.4,
    "historical_window_size": 100,
    "temporal_decay": {
        "half_life_hours": 24
    }
  }',
  so.config_confidence_scoring = '{
    "thresholds": {
      "low_confidence": 0.4,
      "medium_confidence": 0.6,
      "high_confidence": 0.8,
      "critical_threshold": 0.7,
      "min_objective_alignment_factor": 0.8,
      "max_objective_alignment_factor": 1.2
    },
    "factor_weights": {
      "evidence_weight": 0.3,
      "consistency_weight": 0.25,
      "reasoning_weight": 0.2,
      "uncertainty_weight": 0.15,
      "stability_weight": 0.1,
      "observation_decision_weight": 0.2,
      "objective_alignment_weight": 0.3,
      "team_objective_weight": 0.7
    },
    "memory_weights": {
      "observation_weight": 0.8,
      "reflection_weight": 1.2,
      "plan_weight": 0.7,
      "decision_weight": 1.0,
      "action_weight": 0.9,
      "default_weight": 0.6
    }
  }',
  so.config_memory_retrieval = '{
    "weights": {
        "similarity_weight": 0.4,
        "importance_weight": 0.3,
        "surprise_weight": 0.2,
        "recency_weight": 0.1
    },
    "type_weights": {
        "observation_weight": 0.6,
        "reflection_weight": 1.2,
        "plan_weight": 0.5,
        "decision_weight": 0.9,
        "action_weight": 1.0,
        "synthetic_weight": 1.1,
        "default_weight": 0.5
    },
    "min_similarity_threshold": 0.3,
    "conversation_context": {
      "enable_adaptive_querying": true,
      "topic_shift_similarity_threshold": 0.85,
      "refresh_interval_turns": 5,
      "cache_max_age_minutes": 10,
      "enable_topic_shift_detection": true
    }
  }',
  so.config_agent_communication = '{
    "trust_factor": 0.8
  }',
  so.config_consensus = '{
    "confidence_threshold": 0.5,
    "cooldown_minutes": 30,
    "default_protocol": "SimpleMajority",
    "enabled": true,
    "enable_formal_voting": false,
    "objective_function_conflict_threshold": 0.2,
    "max_ci_rounds": 3,
    "timeout_minutes": 60
  }',
  so.config_saga_retry = '{
    "max_retries": 3,
    "initial_delay_ms": 100,
    "max_delay_ms": 30000,
    "backoff_multiplier": 2.0,
    "use_jitter": true
  }',
  so.config_agent_repair = '{
    "enabled": true,
    "repair_cycle_interval_minutes": 5,
    "max_repair_attempts": 3,
    "repair_batch_size": 50,
    "repair_timeout_seconds": 30,
    "circuit_breaker_failure_threshold": 5,
    "circuit_breaker_timeout_minutes": 5,
    "health_assessment_interval_minutes": 10
  }',
  so.created_date = datetime(),
  so.last_modified_date = datetime()
ON MATCH SET
  so.reserved_fields_observation = ['name', 'user_query', 'knowledge_context'],
  so.reserved_fields_reflection = ['name', 'team_context', 'objectives_context', 'knowledge_context', 'recent_observations', 'past_reflections', 'available_tools', 'synthetic_memories'],
  so.reserved_fields_user_prompt = ['current_timestamp', 'user_query', 'knowledge_context', 'available_tools', 'history'],
  so.reserved_fields_task_prompt = ['goal', 'plan_details', 'team_capabilities', 'objective_function'],
  so.prompt_access_levels = '[{"value": "admin", "description": "For system administrators with full access to all prompts"},
  {"value": "user", "description": "For regular users of the system"},
  {"value": "restricted", "description": "For sensitive prompts that require special permission to access"},
  {"value": "system", "description": "For core system prompts essential for the MAGs memory cycle implementation"}]',
  so.allowed_planning = ['Plan & Solve'],
  so.allowed_consensus = ['SimpleMajority'],
  so.content_processor_type  = ['Failure Mode', 'Technical Report', 'Maintenance Procedure', 'Equipment Specification', 'Incident Report', 'Manual', 'Generic'],
  so.prompt_types = '[{"value": "system", "description": "For core system functionality"},
  {"value": "user", "description": "For prompts created or customized by users"},
  {"value": "template", "description": "For base prompts that can be customized or extended for specific use cases"},
  {"value": "analysis", "description": "For prompts designed to analyze or interpret data or text"},
  {"value": "generation", "description": "For prompts focused on generating new content or ideas"},
  {"value": "classification", "description": "For prompts that categorize or label input"},
  {"value": "extraction", "description": "For prompts designed to extract specific information from text"},
  {"value": "dialogue", "description": "For prompts used in conversational or interactive contexts"},
  {"value": "task-specific", "description": "For prompts designed for particular tasks within the application"},
  {"value": "utility", "description": "For helper prompts that support other processes but aren\'t main functionalities"}]',
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
  so.config_timing = '{
    "status_update_interval_ms": 60000,
    "counter_reset_interval_ms":  86400000
  }',
  so.config_importance_scoring = '{
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
  so.config_surprise_scoring = '{
    "novelty_threshold": 0.7,
    "pattern_deviation_weight": 0.6,
    "context_unexpectedness_weight": 0.4,
    "historical_window_size": 100,
    "temporal_decay": {
        "half_life_hours": 24
    }
  }',
  so.config_confidence_scoring = '{
    "thresholds": {
      "low_confidence": 0.4,
      "medium_confidence": 0.6,
      "high_confidence": 0.8,
      "critical_threshold": 0.7,
      "min_objective_alignment_factor": 0.8,
      "max_objective_alignment_factor": 1.2
    },
    "factor_weights": {
      "evidence_weight": 0.3,
      "consistency_weight": 0.25,
      "reasoning_weight": 0.2,
      "uncertainty_weight": 0.15,
      "stability_weight": 0.1,
      "observation_decision_weight": 0.2,
      "objective_alignment_weight": 0.3,
      "team_objective_weight": 0.7
    },
    "memory_weights": {
      "observation_weight": 0.8,
      "reflection_weight": 1.2,
      "plan_weight": 0.7,
      "decision_weight": 1.0,
      "action_weight": 0.9,
      "default_weight": 0.6
    }
  }',
  so.config_memory_retrieval = '{
    "weights": {
        "similarity_weight": 0.4,
        "importance_weight": 0.3,
        "surprise_weight": 0.2,
        "recency_weight": 0.1
    },
    "type_weights": {
        "observation_weight": 0.6,
        "reflection_weight": 1.2,
        "plan_weight": 0.5,
        "decision_weight": 0.9,
        "action_weight": 1.0,
        "synthetic_weight": 1.1,
        "default_weight": 0.5
    },
    "min_similarity_threshold": 0.3,
    "conversation_context": {
      "enable_adaptive_querying": true,
      "topic_shift_similarity_threshold": 0.85,
      "refresh_interval_turns": 5,
      "cache_max_age_minutes": 10,
      "enable_topic_shift_detection": true
    }
  }',
  so.config_agent_communication = '{
    "trust_factor": 0.8
  }',
  so.config_consensus = '{
    "confidence_threshold": 0.5,
    "cooldown_minutes": 30,
    "default_protocol": "SimpleMajority",
    "enabled": true,
    "enable_formal_voting": false,
    "objective_function_conflict_threshold": 0.2,
    "max_ci_rounds": 3,
    "timeout_minutes": 60
  }',
  so.config_saga_retry = '{
    "max_retries": 3,
    "initial_delay_ms": 100,
    "max_delay_ms": 30000,
    "backoff_multiplier": 2.0,
    "use_jitter": true
  }',
  so.config_agent_repair = '{
    "enabled": true,
    "repair_cycle_interval_minutes": 5,
    "max_repair_attempts": 3,
    "repair_batch_size": 50,
    "repair_timeout_seconds": 30,
    "circuit_breaker_failure_threshold": 5,
    "circuit_breaker_timeout_minutes": 5,
    "health_assessment_interval_minutes": 10
  }',
  so.last_modified_date = datetime()
RETURN so
