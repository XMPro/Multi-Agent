// First drop redundant or obsolete constraints and indexes
DROP CONSTRAINT plan_id_unique IF EXISTS;
DROP CONSTRAINT conversation_id_unique IF EXISTS;
DROP INDEX plan_status_idx IF EXISTS;
DROP INDEX plan_active_idx IF EXISTS;
DROP INDEX conversation_id_idx IF EXISTS;

CREATE CONSTRAINT agent_profile_id_unique IF NOT EXISTS FOR (p:AgentProfile) REQUIRE p.profile_id IS UNIQUE;
CREATE CONSTRAINT agent_instance_id_unique IF NOT EXISTS FOR (a:AgentInstance) REQUIRE a.agent_id IS UNIQUE;
CREATE CONSTRAINT memory_id_unique IF NOT EXISTS FOR (m:Memory) REQUIRE m.id IS UNIQUE;
CREATE CONSTRAINT prompt_id_unique IF NOT EXISTS FOR (p:Prompt) REQUIRE p.prompt_id IS UNIQUE;
CREATE CONSTRAINT tool_name_unique IF NOT EXISTS FOR (t:Tool) REQUIRE t.name IS UNIQUE;
CREATE CONSTRAINT decision_id_unique IF NOT EXISTS FOR (d:Decision) REQUIRE d.decision_id IS UNIQUE;
CREATE CONSTRAINT artifact_id_unique IF NOT EXISTS FOR (a:Artifact) REQUIRE a.id IS UNIQUE;
CREATE CONSTRAINT objective_function_id_unique IF NOT EXISTS FOR (of:ObjectiveFunction) REQUIRE of.id IS UNIQUE;

CREATE INDEX team_id_idx IF NOT EXISTS FOR (t:Team) ON (t.team_id);
CREATE INDEX memory_created_date_idx IF NOT EXISTS FOR (m:Memory) ON (m.created_date);
CREATE INDEX memory_type_idx IF NOT EXISTS FOR (m:Memory) ON (m.type);
CREATE INDEX memory_importance_idx IF NOT EXISTS FOR (m:Memory) ON (m.importance);
CREATE INDEX prompt_internal_name_idx IF NOT EXISTS FOR (p:Prompt) ON (p.internal_name);
CREATE INDEX prompt_id_idx IF NOT EXISTS FOR (p:Prompt) ON (p.prompt_id);
CREATE INDEX artifact_type_idx IF NOT EXISTS FOR (a:Artifact) ON (a.type);
CREATE INDEX objective_function_type_idx IF NOT EXISTS FOR (of:ObjectiveFunction) ON (of.type);
CREATE INDEX objective_function_active_idx IF NOT EXISTS FOR (of:ObjectiveFunction) ON (of.active);
CREATE INDEX objective_function_created_date_idx IF NOT EXISTS FOR (of:ObjectiveFunction) ON (of.created_date);

// Constraints for Entry types
CREATE CONSTRAINT entry_id_unique IF NOT EXISTS FOR (e:Entry) REQUIRE e.id IS UNIQUE;
CREATE CONSTRAINT entry_entry_id_unique IF NOT EXISTS FOR (e:Entry) REQUIRE e.entry_id IS UNIQUE;

// Constraints for Measure types
CREATE CONSTRAINT measure_id_unique IF NOT EXISTS FOR (m:Measure) REQUIRE m.id IS UNIQUE;
CREATE CONSTRAINT measure_measure_id_unique IF NOT EXISTS FOR (m:Measure) REQUIRE m.measure_id IS UNIQUE;

// Constraints for Location
CREATE CONSTRAINT location_id_unique IF NOT EXISTS FOR (l:Location) REQUIRE l.id IS UNIQUE;
CREATE CONSTRAINT location_location_id_unique IF NOT EXISTS FOR (l:Location) REQUIRE l.location_id IS UNIQUE;

// Constraints for Library
CREATE CONSTRAINT library_name_unique IF NOT EXISTS FOR (l:Library) REQUIRE l.name IS UNIQUE;

// Compound indexes for type property approach
CREATE INDEX artifact_type_id_idx IF NOT EXISTS FOR (a:Artifact) ON (a.type, a.id);
CREATE INDEX entry_type_idx IF NOT EXISTS FOR (e:Entry) ON (e.type);
CREATE INDEX entry_type_id_idx IF NOT EXISTS FOR (e:Entry) ON (e.type, e.id);
CREATE INDEX decision_type_idx IF NOT EXISTS FOR (d:Decision) ON (d.type);
CREATE INDEX measure_type_idx IF NOT EXISTS FOR (m:Measure) ON (m.type);
CREATE INDEX measure_type_id_idx IF NOT EXISTS FOR (m:Measure) ON (m.type, m.id);

// Compound indexes for common queries
CREATE INDEX artifact_type_status_idx IF NOT EXISTS FOR (a:Artifact) ON (a.type, a.status);
CREATE INDEX artifact_type_active_idx IF NOT EXISTS FOR (a:Artifact) ON (a.type, a.active);
CREATE INDEX entry_type_timestamp_idx IF NOT EXISTS FOR (e:Entry) ON (e.type, e.timestamp);

// Additional indexes for timestamp and date properties
CREATE INDEX agent_instance_active_idx IF NOT EXISTS FOR (a:AgentInstance) ON (a.active);
CREATE INDEX entry_timestamp_idx IF NOT EXISTS FOR (e:Entry) ON (e.timestamp);
CREATE INDEX entry_created_date_idx IF NOT EXISTS FOR (e:Entry) ON (e.created_date);
CREATE INDEX artifact_created_date_idx IF NOT EXISTS FOR (a:Artifact) ON (a.created_date);
CREATE INDEX decision_timestamp_idx IF NOT EXISTS FOR (d:Decision) ON (d.timestamp);
CREATE INDEX measure_created_date_idx IF NOT EXISTS FOR (m:Measure) ON (m.created_date);

// Relationship property indexes (for common relationship property filters)
CREATE INDEX has_sbom_is_latest_idx IF NOT EXISTS FOR ()-[r:HAS_SBOM]-() ON (r.is_latest);
CREATE INDEX member_of_active_idx IF NOT EXISTS FOR ()-[r:MEMBER_OF]-() ON (r.active);
CREATE INDEX has_task_status_idx IF NOT EXISTS FOR ()-[r:HAS_TASK]-() ON (r.status);

// For the Memory creation timestamp filtering
CREATE INDEX memory_created_timestamp_idx IF NOT EXISTS FOR (m:Memory) ON (m.timestamp);
// Compound index for Memory queries by agent and type
CREATE INDEX memory_agent_type_idx IF NOT EXISTS FOR (m:Memory) ON (m.type, m.created_date);
// If you frequently query memories by importance + type
CREATE INDEX memory_importance_type_idx IF NOT EXISTS FOR (m:Memory) ON (m.importance, m.type);

// For Entry nodes
CREATE INDEX entry_type_timestamp_idx IF NOT EXISTS FOR (e:Entry) ON (e.type, e.timestamp);
CREATE INDEX entry_created_date_idx IF NOT EXISTS FOR (e:Entry) ON (e.created_date);

// For Decision nodes
CREATE INDEX decision_type_status_idx IF NOT EXISTS FOR (d:Decision) ON (d.type, d.status);
CREATE INDEX decision_created_date_idx IF NOT EXISTS FOR (d:Decision) ON (d.created_date);

// For Artifact nodes
CREATE INDEX artifact_agent_type_idx IF NOT EXISTS FOR (a:Artifact) ON (a.agent_id, a.type);
CREATE INDEX artifact_status_idx IF NOT EXISTS FOR (a:Artifact) ON (a.status);

// Essential for communication pattern queries
CREATE INDEX decision_trigger_reason_idx IF NOT EXISTS FOR (d:Decision) ON (d.trigger_reason);
// Compound index for communication queries that filter by type + date
CREATE INDEX decision_type_created_date_idx IF NOT EXISTS FOR (d:Decision) ON (d.type, d.created_date);
// For Memory queries that filter by agent relationships and date
CREATE INDEX memory_type_created_date_idx IF NOT EXISTS FOR (m:Memory) ON (m.type, m.created_date);
// For Artifact queries filtering by type + date (you have separate but not compound)
CREATE INDEX artifact_type_created_date_idx IF NOT EXISTS FOR (a:Artifact) ON (a.type, a.created_date);
// For target_agents filtering in communication queries
CREATE INDEX decision_target_agents_idx IF NOT EXISTS FOR (d:Decision) ON (d.target_agents);
// For communication_type filtering
CREATE INDEX decision_communication_type_idx IF NOT EXISTS FOR (d:Decision) ON (d.communication_type);
