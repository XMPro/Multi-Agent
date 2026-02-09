// Create or merge AI Providers Library node
MERGE (lib:Library {name: 'AI Providers Library', type: 'AIProvider'})
ON CREATE SET 
  lib.created_at = datetime(),
  lib.updated_at = datetime()
ON MATCH SET
  lib.updated_at = datetime()

// Create AI Provider nodes and link them to the library
WITH lib
UNWIND [
  {name: 'Anthropic', embedding: true, inferencing: false},
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

MERGE (lib)-[:CONTAINS]->(p)

RETURN lib.name AS library, 
       collect(p.name) AS providers,
       count(p) AS total_providers