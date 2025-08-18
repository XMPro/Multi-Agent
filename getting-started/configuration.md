---
layout: default
title: "Configuration"
description: "Configure your MAGS installation for optimal performance"
category: "getting-started"
---

# Configuration Guide

After installing MAGS, you'll need to configure it to match your specific requirements. This guide covers the essential configuration steps to optimize your MAGS deployment.

## System Configuration

### Environment Variables

MAGS uses environment variables for core configuration. The main settings are:

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `MAGS_ENV` | Environment (development, staging, production) | development | Yes |
| `MAGS_PORT` | Port for the API server | 8080 | Yes |
| `MAGS_LOG_LEVEL` | Logging level (debug, info, warn, error) | info | Yes |
| `MAGS_SECRET_KEY` | Secret key for JWT tokens | - | Yes |
| `MAGS_DB_URI` | Database connection string | - | Yes |
| `MAGS_VECTOR_DB_URI` | Vector database connection string | - | Yes |
| `MAGS_REDIS_URI` | Redis connection string (for caching) | - | No |
| `MAGS_LLM_PROVIDER` | Default LLM provider | openai | Yes |
| `MAGS_LLM_API_KEY` | API key for the LLM provider | - | Yes |

### Configuration File

For more advanced settings, edit the `config.json` file:

```json
{
  "system": {
    "name": "MAGS Instance",
    "description": "Multi-Agent Generative System",
    "maxAgents": 100,
    "maxTeams": 20,
    "defaultTimeout": 30000
  },
  "security": {
    "tokenExpiration": 86400,
    "maxLoginAttempts": 5,
    "lockoutDuration": 900,
    "allowedOrigins": ["http://localhost:3000"]
  },
  "llm": {
    "providers": {
      "openai": {
        "models": ["gpt-4", "gpt-3.5-turbo"],
        "defaultModel": "gpt-3.5-turbo",
        "temperature": 0.7,
        "maxTokens": 4096
      },
      "anthropic": {
        "models": ["claude-2", "claude-instant"],
        "defaultModel": "claude-instant",
        "temperature": 0.7,
        "maxTokens": 4096
      }
    }
  },
  "memory": {
    "vectorDimensions": 1536,
    "similarityThreshold": 0.75,
    "maxMemoryAge": 2592000,
    "memoryRefreshInterval": 86400
  }
}
```

## Database Configuration

### PostgreSQL

If using PostgreSQL, configure the following:

1. Create a dedicated database:
   ```sql
   CREATE DATABASE mags;
   CREATE USER mags_user WITH ENCRYPTED PASSWORD 'your_password';
   GRANT ALL PRIVILEGES ON DATABASE mags TO mags_user;
   ```

2. Update your `.env` file:
   ```
   MAGS_DB_URI=postgresql://mags_user:your_password@localhost:5432/mags
   ```

### Vector Database

Configure your vector database (Pinecone, Weaviate, or Milvus):

#### Pinecone Example

1. Create an index in the Pinecone console with:
   - Dimensions: 1536 (for OpenAI embeddings)
   - Metric: Cosine

2. Update your `.env` file:
   ```
   MAGS_VECTOR_DB_URI=pinecone://api-key@index-name
   ```

#### Weaviate Example

1. Create a schema in Weaviate:
   ```json
   {
     "class": "MAGSMemory",
     "vectorizer": "none",
     "properties": [
       {
         "name": "content",
         "dataType": ["text"]
       },
       {
         "name": "agentId",
         "dataType": ["string"]
       },
       {
         "name": "timestamp",
         "dataType": ["number"]
       }
     ]
   }
   ```

2. Update your `.env` file:
   ```
   MAGS_VECTOR_DB_URI=weaviate://localhost:8080
   ```

## Agent Configuration

### Default Agent Settings

Configure default settings for new agents in `agent_defaults.json`:

```json
{
  "memory": {
    "shortTermCapacity": 10,
    "longTermStrategy": "significance-based",
    "retrievalCount": 5
  },
  "communication": {
    "protocol": "direct",
    "messageFormat": "json",
    "maxMessageSize": 4096
  },
  "reasoning": {
    "framework": "chain-of-thought",
    "confidenceThreshold": 0.7,
    "fallbackStrategy": "ask-human"
  }
}
```

### Agent Templates

MAGS includes several pre-configured agent templates in the `templates` directory. You can customize these or create new ones.

## Security Configuration

### Authentication

Configure authentication methods in `auth_config.json`:

```json
{
  "methods": ["local", "oauth", "ldap"],
  "oauth": {
    "providers": {
      "google": {
        "clientId": "your-client-id",
        "clientSecret": "your-client-secret",
        "callbackUrl": "http://localhost:8080/auth/google/callback"
      }
    }
  },
  "ldap": {
    "url": "ldap://ldap.example.com",
    "bindDN": "cn=admin,dc=example,dc=com",
    "bindCredentials": "admin-password",
    "searchBase": "dc=example,dc=com",
    "searchFilter": "(uid={{username}})"
  }
}
```

### API Rate Limiting

Configure rate limiting in `rate_limits.json`:

```json
{
  "default": {
    "windowMs": 60000,
    "max": 100,
    "message": "Too many requests, please try again later"
  },
  "auth": {
    "windowMs": 3600000,
    "max": 10,
    "message": "Too many login attempts, please try again later"
  }
}
```

## Performance Tuning

### Memory Optimization

Adjust memory settings based on your hardware:

```json
{
  "cache": {
    "enabled": true,
    "ttl": 3600,
    "maxSize": 1000
  },
  "embedding": {
    "batchSize": 10,
    "concurrency": 5
  },
  "retrieval": {
    "preloadCommonMemories": true,
    "cacheResults": true
  }
}
```

### Scaling Configuration

For larger deployments, configure scaling options:

```json
{
  "workers": {
    "min": 2,
    "max": 10,
    "targetCpuUtilization": 70
  },
  "queues": {
    "memory": {
      "concurrency": 5,
      "retryLimit": 3
    },
    "embedding": {
      "concurrency": 3,
      "retryLimit": 2
    }
  }
}
```

## Next Steps

After configuring your MAGS installation:

1. [Create your first agent]({{ '/getting-started/first-steps' | relative_url }})
2. [Explore advanced features]({{ '/getting-started/advanced-usage' | relative_url }})
3. [Learn about system monitoring]({{ '/operations/monitoring' | relative_url }})
