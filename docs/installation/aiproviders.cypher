// =============================================================================
// Agent RAG Database Initialization Script
// This script creates all required nodes and relationships for the Agent RAG system
// Run this script once to initialize your Neo4j database
// =============================================================================

// =============================================================================
// STEP 1: Create Library Nodes
// =============================================================================

// Create or merge AI Providers Library node
MERGE (libAI:Library {name: 'AI Providers Library', type: 'AIProvider'})
ON CREATE SET 
  libAI.created_at = datetime(),
  libAI.updated_at = datetime()
ON MATCH SET
  libAI.updated_at = datetime()

// Create or merge Agent RAG Library node
MERGE (libRAG:Library {name: 'Agent RAG Library', type: 'RAG'})
ON CREATE SET 
  libRAG.created_at = datetime(),
  libRAG.updated_at = datetime()
ON MATCH SET
  libRAG.updated_at = datetime()

// Create or merge Document Collections Library node
MERGE (libDocs:Library {name: 'RAG Document Collections Library', type: 'DocumentCollection'})
ON CREATE SET 
  libDocs.created_at = datetime(),
  libDocs.updated_at = datetime()
ON MATCH SET
  libDocs.updated_at = datetime()

WITH libAI, libRAG, libDocs

// =============================================================================
// STEP 2: Create AI Providers and Link to Library
// =============================================================================

UNWIND [
  {name: 'Anthropic', embedding: false, inferencing: true},
  {name: 'AWSBedrock', embedding: true, inferencing: true},
  {name: 'AzureOpenAI', embedding: true, inferencing: true},
  {name: 'Google', embedding: true, inferencing: true},
  {name: 'Lemonade', embedding: false, inferencing: true},
  {name: 'Ollama', embedding: true, inferencing: true},
  {name: 'OpenAI', embedding: true, inferencing: true}
] AS provider

MERGE (p:AIProvider {name: provider.name})
ON CREATE SET 
  p.embedding = provider.embedding,
  p.inferencing = provider.inferencing,
  p.created_at = datetime(),
  p.updated_at = datetime()
ON MATCH SET
  p.embedding = provider.embedding,
  p.inferencing = provider.inferencing,
  p.updated_at = datetime()

MERGE (libAI)-[:CONTAINS]->(p)

WITH libRAG, collect(p) AS providers

// =============================================================================
// STEP 3: Create Embedding Models and Link to Providers
// =============================================================================

// OpenAI Embedding Models
MATCH (pOpenAI:AIProvider {name: 'OpenAI'})
WITH libRAG, pOpenAI
UNWIND [
  {
    name: 'text-embedding-ada-002',
    cost: '$0.0001/1K tokens',
    maxTokens: 8191,
    dimensions: 1536,
    description: 'Most capable embedding model for most use cases.',
    status: 'available',
    usage: 0
  },
  {
    name: 'text-embedding-3-small',
    cost: '$0.00002/1K tokens',
    maxTokens: 8191,
    dimensions: 1536,
    description: 'Smaller, faster, and cheaper embedding model',
    status: 'available',
    usage: 0
  },
  {
    name: 'text-embedding-3-large',
    cost: '$0.00013/1K tokens',
    maxTokens: 8192,
    dimensions: 3072,
    description: 'Larger, more capable embedding model',
    status: 'available',
    usage: 0
  }
] AS model

MERGE (m:EmbeddingModel {name: model.name})
ON CREATE SET 
  m.cost = model.cost,
  m.maxTokens = model.maxTokens,
  m.dimensions = model.dimensions,
  m.description = model.description,
  m.status = model.status,
  m.usage = model.usage,
  m.created_at = datetime(),
  m.updated_at = datetime()
ON MATCH SET
  m.cost = model.cost,
  m.maxTokens = model.maxTokens,
  m.dimensions = model.dimensions,
  m.description = model.description,
  m.status = model.status,
  m.updated_at = datetime()

MERGE (m)-[:USES]->(pOpenAI)

WITH libRAG

// Ollama Embedding Models
MATCH (pOllama:AIProvider {name: 'Ollama'})
WITH libRAG, pOllama
UNWIND [
  {
    name: 'nomic-embed-text:latest',
    cost: '$0.00/1K tokens',
    maxTokens: 2048,
    dimensions: 768,
    description: 'Basic Ollama embedding model',
    status: 'available',
    usage: 0
  },
  {
    name: 'mxbai-embed-large:latest',
    cost: '$0.00/1K tokens',
    maxTokens: 512,
    dimensions: 1024,
    description: 'High performance Ollama embedding model',
    status: 'available',
    usage: 0
  }
] AS model

MERGE (m:EmbeddingModel {name: model.name})
ON CREATE SET 
  m.cost = model.cost,
  m.maxTokens = model.maxTokens,
  m.dimensions = model.dimensions,
  m.description = model.description,
  m.status = model.status,
  m.usage = model.usage,
  m.created_at = datetime(),
  m.updated_at = datetime()
ON MATCH SET
  m.cost = model.cost,
  m.maxTokens = model.maxTokens,
  m.dimensions = model.dimensions,
  m.description = model.description,
  m.status = model.status,
  m.updated_at = datetime()

MERGE (m)-[:USES]->(pOllama)

WITH libRAG

// =============================================================================
// STEP 4: Create Chunking Strategies and Link to Agent RAG Library
// =============================================================================

UNWIND [
  {
    strategy: 'Semantic',
    overlap: 70,
    chunkSize: 1500,
    description: 'Splits text based on semantic boundaries using NLP techniques',
    smartSplitting: true,
    initialBytesPerTokenEstimate: 3,
    preserveStructure: true,
    quality: 0.0
  },
  {
    strategy: 'Fixed Size',
    overlap: 25,
    chunkSize: 256,
    description: 'Splits text into fixed-size chunks with configurable overlap',
    smartSplitting: false,
    initialBytesPerTokenEstimate: 3,
    preserveStructure: false,
    quality: 0.0
  },
  {
    strategy: 'Paragraph-based',
    overlap: 0,
    chunkSize: 384,
    description: 'Splits text at paragraph boundaries',
    smartSplitting: false,
    initialBytesPerTokenEstimate: 3,
    preserveStructure: true,
    quality: 0.0
  },
  {
    strategy: 'Sentence-based',
    overlap: 10,
    chunkSize: 128,
    description: 'Splits text at sentence boundaries',
    smartSplitting: true,
    initialBytesPerTokenEstimate: 3,
    preserveStructure: false,
    quality: 0.0
  }
] AS strat

MERGE (s:ChunkingStrategy {strategy: strat.strategy})
ON CREATE SET 
  s.overlap = strat.overlap,
  s.chunkSize = strat.chunkSize,
  s.description = strat.description,
  s.smartSplitting = strat.smartSplitting,
  s.initialBytesPerTokenEstimate = strat.initialBytesPerTokenEstimate,
  s.preserveStructure = strat.preserveStructure,
  s.quality = strat.quality,
  s.created_at = datetime(),
  s.updated_at = datetime()
ON MATCH SET
  s.overlap = strat.overlap,
  s.chunkSize = strat.chunkSize,
  s.description = strat.description,
  s.smartSplitting = strat.smartSplitting,
  s.initialBytesPerTokenEstimate = strat.initialBytesPerTokenEstimate,
  s.preserveStructure = strat.preserveStructure,
  s.quality = strat.quality,
  s.updated_at = datetime()

MERGE (libRAG)-[:CONTAINS]->(s)
