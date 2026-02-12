// ============================================================================
// PART 1: DROP EXISTING CONSTRAINTS AND INDEXES (GROUPED BY ENTITY TYPE)
// ============================================================================

// -------------------- AgentInstance --------------------
DROP CONSTRAINT agent_instance_id_unique IF EXISTS;
DROP INDEX agent_instance_active_idx IF EXISTS;

// -------------------- AgentProfile --------------------
DROP CONSTRAINT agent_profile_id_unique IF EXISTS;
DROP CONSTRAINT agent_profile_name_unique IF EXISTS;
DROP INDEX agent_profile_active IF EXISTS;
DROP INDEX agent_profile_active_author IF EXISTS;
DROP INDEX agent_profile_active_category IF EXISTS;
DROP INDEX agent_profile_active_name IF EXISTS;
DROP INDEX agent_profile_author IF EXISTS;
DROP INDEX agent_profile_category IF EXISTS;
DROP INDEX agent_profile_id IF EXISTS;
DROP INDEX agent_profile_name IF EXISTS;
DROP INDEX agent_profile_tags IF EXISTS;

// -------------------- Artifact --------------------
DROP CONSTRAINT artifact_id_unique IF EXISTS;
DROP INDEX artifact_agent_type_idx IF EXISTS;
DROP INDEX artifact_created_date_idx IF EXISTS;
DROP INDEX artifact_status_idx IF EXISTS;
DROP INDEX artifact_type IF EXISTS;
DROP INDEX artifact_type_active_idx IF EXISTS;
DROP INDEX artifact_type_created_date_idx IF EXISTS;
DROP INDEX artifact_type_id_idx IF EXISTS;
DROP INDEX artifact_type_status_idx IF EXISTS;

// -------------------- Conversation --------------------
DROP CONSTRAINT conversation_id_unique IF EXISTS;
DROP INDEX conversation_id_idx IF EXISTS;

// -------------------- Decision --------------------
DROP CONSTRAINT decision_id_unique IF EXISTS;
DROP INDEX decision_communication_type_idx IF EXISTS;
DROP INDEX decision_created_date_idx IF EXISTS;
DROP INDEX decision_target_agents_idx IF EXISTS;
DROP INDEX decision_timestamp_idx IF EXISTS;
DROP INDEX decision_trigger_reason_idx IF EXISTS;
DROP INDEX decision_type_created_date_idx IF EXISTS;
DROP INDEX decision_type_idx IF EXISTS;
DROP INDEX decision_type_status_idx IF EXISTS;

// -------------------- Entry --------------------
DROP CONSTRAINT entry_id_unique IF EXISTS;
DROP CONSTRAINT entry_entry_id_unique IF EXISTS;
DROP INDEX entry_author_type IF EXISTS;
DROP INDEX entry_category IF EXISTS;
DROP INDEX entry_created_date_idx IF EXISTS;
DROP INDEX entry_site IF EXISTS;
DROP INDEX entry_timestamp IF EXISTS;
DROP INDEX entry_type_id_idx IF EXISTS;
DROP INDEX entry_type IF EXISTS;
DROP INDEX entry_type_timestamp IF EXISTS;
DROP INDEX entry_type_wizard IF EXISTS;
DROP INDEX entry_wizard_author_session IF EXISTS;
DROP INDEX entry_wizard_author_status IF EXISTS;

// -------------------- Library --------------------
DROP CONSTRAINT library_name_unique IF EXISTS;
DROP CONSTRAINT library_type_unique IF EXISTS;
DROP INDEX library_type IF EXISTS;

// -------------------- Location --------------------
DROP CONSTRAINT location_id_unique IF EXISTS;
DROP CONSTRAINT location_location_id_unique IF EXISTS;
DROP INDEX location_name IF EXISTS;
DROP INDEX location_site IF EXISTS;

// -------------------- Measure --------------------
DROP CONSTRAINT measure_id_unique IF EXISTS;
DROP CONSTRAINT measure_measure_id_unique IF EXISTS;
DROP CONSTRAINT measure_name_unique IF EXISTS;
DROP INDEX measure_type_id_idx IF EXISTS;
DROP INDEX measure_created_date_idx IF EXISTS;
DROP INDEX measure_author IF EXISTS;
DROP INDEX measure_domain_index IF EXISTS;
DROP INDEX measure_domain_name IF EXISTS;
DROP INDEX measure_id IF EXISTS;
DROP INDEX measure_measure_id_idx IF EXISTS;
DROP INDEX measure_name_idx IF EXISTS;
DROP INDEX measure_type_domain IF EXISTS;
DROP INDEX measure_type_idx IF EXISTS;

// -------------------- Memory --------------------
DROP CONSTRAINT memory_id_unique IF EXISTS;
DROP INDEX memory_type_created_date_idx IF EXISTS;
DROP INDEX memory_created_date_idx IF EXISTS;
DROP INDEX memory_created_timestamp_idx IF EXISTS;
DROP INDEX memory_importance_idx IF EXISTS;
DROP INDEX memory_importance_type_idx IF EXISTS;
DROP INDEX memory_type_idx IF EXISTS;

// -------------------- ObjectiveFunction --------------------
DROP CONSTRAINT objective_function_id_unique IF EXISTS;
DROP INDEX objective_function_active_idx IF EXISTS;
DROP INDEX objective_function_created_date_idx IF EXISTS;
DROP INDEX objective_function_type_idx IF EXISTS;

// -------------------- Plan --------------------
DROP CONSTRAINT plan_id_unique IF EXISTS;
DROP INDEX plan_active_idx IF EXISTS;
DROP INDEX plan_status_idx IF EXISTS;

// -------------------- Prompt --------------------
DROP CONSTRAINT prompt_name_unique IF EXISTS;
DROP CONSTRAINT prompt_id_version_unique IF EXISTS;
DROP CONSTRAINT prompt_id_unique IF EXISTS;
DROP INDEX prompt_access_author IF EXISTS;
DROP INDEX prompt_access_level IF EXISTS;
DROP INDEX prompt_active IF EXISTS;
DROP INDEX prompt_author IF EXISTS;
DROP INDEX prompt_category IF EXISTS;
DROP INDEX prompt_id_active IF EXISTS;
DROP INDEX prompt_id_idx IF EXISTS;
DROP INDEX prompt_id_version IF EXISTS;
DROP INDEX prompt_internal_name_idx IF EXISTS;
DROP INDEX prompt_lookup_composite IF EXISTS;
DROP INDEX prompt_name IF EXISTS;

// -------------------- Team --------------------
DROP CONSTRAINT team_name_unique IF EXISTS;
DROP CONSTRAINT team_id_unique IF EXISTS;
DROP INDEX team_active IF EXISTS;
DROP INDEX team_active_category IF EXISTS;
DROP INDEX team_author IF EXISTS;
DROP INDEX team_category IF EXISTS;
DROP INDEX team_id_idx IF EXISTS;
DROP INDEX team_name IF EXISTS;
DROP INDEX team_team_id_name_index IF EXISTS;

// -------------------- Tool --------------------
DROP CONSTRAINT tool_name_unique IF EXISTS;
DROP CONSTRAINT tool_id_unique IF EXISTS;
DROP INDEX tool_active_name IF EXISTS;
DROP INDEX tool_class_active IF EXISTS;
DROP INDEX tool_class_name IF EXISTS;
DROP INDEX tool_id IF EXISTS;
DROP INDEX tool_active_class_name IF EXISTS;

// -------------------- Action --------------------
DROP CONSTRAINT action_name_unique IF EXISTS;
DROP CONSTRAINT action_id_unique IF EXISTS;
DROP INDEX action_id IF EXISTS;
DROP INDEX action_name IF EXISTS;
DROP INDEX action_id_name_index IF EXISTS;
DROP INDEX action_active_category_name IF EXISTS;

// -------------------- Wizard --------------------
DROP CONSTRAINT wizard_id_unique IF EXISTS;
DROP CONSTRAINT wizard_name_unique IF EXISTS;
DROP INDEX wizard_active IF EXISTS;
DROP INDEX wizard_author IF EXISTS;

// -------------------- System Options --------------------
DROP CONSTRAINT system_options_id_unique IF EXISTS;

// -------------------- Relationships --------------------
DROP INDEX allows_action IF EXISTS;
DROP INDEX allows_tool IF EXISTS;
DROP INDEX has_sbom_is_latest_idx IF EXISTS;
DROP INDEX has_task_status_idx IF EXISTS;
DROP INDEX member_of_active_idx IF EXISTS;

// ============================================================================
// PART 2: RE-ADD CONSTRAINTS AND INDEXES (GROUPED BY ENTITY TYPE)
// ============================================================================

// -------------------- AgentInstance --------------------
CREATE CONSTRAINT agent_instance_id_unique IF NOT EXISTS FOR (a:AgentInstance) REQUIRE a.agent_id IS UNIQUE;
CREATE INDEX agent_instance_active_idx IF NOT EXISTS FOR (a:AgentInstance) ON (a.active);

// -------------------- AgentProfile --------------------
CREATE CONSTRAINT agent_profile_id_unique IF NOT EXISTS FOR (p:AgentProfile) REQUIRE p.profile_id IS UNIQUE;
CREATE CONSTRAINT agent_profile_name_unique IF NOT EXISTS FOR (p:AgentProfile) REQUIRE p.name IS UNIQUE;
CREATE INDEX agent_profile_active IF NOT EXISTS FOR (p:AgentProfile) ON (p.active);
CREATE INDEX agent_profile_active_author IF NOT EXISTS FOR (p:AgentProfile) ON (p.active, p.author);
CREATE INDEX agent_profile_active_category IF NOT EXISTS FOR (p:AgentProfile) ON (p.active, p.category);
CREATE INDEX agent_profile_active_name IF NOT EXISTS FOR (p:AgentProfile) ON (p.active, p.name);
CREATE INDEX agent_profile_author IF NOT EXISTS FOR (p:AgentProfile) ON (p.author);
CREATE INDEX agent_profile_category IF NOT EXISTS FOR (p:AgentProfile) ON (p.category);
CREATE INDEX agent_profile_id IF NOT EXISTS FOR (p:AgentProfile) ON (p.profile_id);
CREATE INDEX agent_profile_name IF NOT EXISTS FOR (p:AgentProfile) ON (p.name);
CREATE INDEX agent_profile_tags IF NOT EXISTS FOR (p:AgentProfile) ON (p.tags);

// -------------------- Artifact --------------------
CREATE CONSTRAINT artifact_id_unique IF NOT EXISTS FOR (a:Artifact) REQUIRE a.id IS UNIQUE;
CREATE INDEX artifact_agent_type_idx IF NOT EXISTS FOR (a:Artifact) ON (a.agent_id, a.type);
CREATE INDEX artifact_created_date_idx IF NOT EXISTS FOR (a:Artifact) ON (a.created_date);
CREATE INDEX artifact_status_idx IF NOT EXISTS FOR (a:Artifact) ON (a.status);
CREATE INDEX artifact_type IF NOT EXISTS FOR (a:Artifact) ON (a.type);
CREATE INDEX artifact_type_active_idx IF NOT EXISTS FOR (a:Artifact) ON (a.type, a.active);
CREATE INDEX artifact_type_created_date_idx IF NOT EXISTS FOR (a:Artifact) ON (a.type, a.created_date);
CREATE INDEX artifact_type_id_idx IF NOT EXISTS FOR (a:Artifact) ON (a.type, a.id);
CREATE INDEX artifact_type_status_idx IF NOT EXISTS FOR (a:Artifact) ON (a.type, a.status);

// -------------------- Conversation --------------------
CREATE CONSTRAINT conversation_id_unique IF NOT EXISTS FOR (c:Conversation) REQUIRE c.conversation_id IS UNIQUE;
CREATE INDEX conversation_id_idx IF NOT EXISTS FOR (c:Conversation) ON (c.conversation_id);

// -------------------- Decision --------------------
CREATE CONSTRAINT decision_id_unique IF NOT EXISTS FOR (d:Decision) REQUIRE d.decision_id IS UNIQUE;
CREATE INDEX decision_communication_type_idx IF NOT EXISTS FOR (d:Decision) ON (d.communication_type);
CREATE INDEX decision_created_date_idx IF NOT EXISTS FOR (d:Decision) ON (d.created_date);
CREATE INDEX decision_target_agents_idx IF NOT EXISTS FOR (d:Decision) ON (d.target_agents);
CREATE INDEX decision_timestamp_idx IF NOT EXISTS FOR (d:Decision) ON (d.timestamp);
CREATE INDEX decision_trigger_reason_idx IF NOT EXISTS FOR (d:Decision) ON (d.trigger_reason);
CREATE INDEX decision_type_created_date_idx IF NOT EXISTS FOR (d:Decision) ON (d.type, d.created_date);
CREATE INDEX decision_type_idx IF NOT EXISTS FOR (d:Decision) ON (d.type);
CREATE INDEX decision_type_status_idx IF NOT EXISTS FOR (d:Decision) ON (d.type, d.status);

// -------------------- Entry --------------------
CREATE CONSTRAINT entry_id_unique IF NOT EXISTS FOR (e:Entry) REQUIRE e.id IS UNIQUE;
CREATE CONSTRAINT entry_entry_id_unique IF NOT EXISTS FOR (e:Entry) REQUIRE e.entry_id IS UNIQUE;
CREATE INDEX entry_author_type IF NOT EXISTS FOR (e:Entry) ON (e.author, e.type);
CREATE INDEX entry_category IF NOT EXISTS FOR (e:Entry) ON (e.category);
CREATE INDEX entry_created_date_idx IF NOT EXISTS FOR (e:Entry) ON (e.created_date);
CREATE INDEX entry_site IF NOT EXISTS FOR (e:Entry) ON (e.site);
CREATE INDEX entry_timestamp IF NOT EXISTS FOR (e:Entry) ON (e.timestamp);
CREATE INDEX entry_type_id_idx IF NOT EXISTS FOR (e:Entry) ON (e.type, e.id);
CREATE INDEX entry_type IF NOT EXISTS FOR (e:Entry) ON (e.type);
CREATE INDEX entry_type_timestamp IF NOT EXISTS FOR (e:Entry) ON (e.type, e.timestamp);
CREATE INDEX entry_type_wizard IF NOT EXISTS FOR (e:Entry) ON (e.type, e.wizard_id);
CREATE INDEX entry_wizard_author_session IF NOT EXISTS FOR (e:Entry) ON (e.wizard_id, e.author, e.session_name);
CREATE INDEX entry_wizard_author_status IF NOT EXISTS FOR (e:Entry) ON (e.wizard_id, e.author, e.status);

// -------------------- Library --------------------
CREATE CONSTRAINT library_name_unique IF NOT EXISTS FOR (l:Library) REQUIRE l.name IS UNIQUE;
CREATE CONSTRAINT library_type_unique IF NOT EXISTS FOR (l:Library) REQUIRE l.type IS UNIQUE;
CREATE INDEX library_type IF NOT EXISTS FOR (l:Library) ON (l.type);

// -------------------- Location --------------------
CREATE CONSTRAINT location_id_unique IF NOT EXISTS FOR (l:Location) REQUIRE l.id IS UNIQUE;
CREATE CONSTRAINT location_location_id_unique IF NOT EXISTS FOR (l:Location) REQUIRE l.location_id IS UNIQUE;
CREATE INDEX location_name IF NOT EXISTS FOR (l:Location) ON (l.name);
CREATE INDEX location_site IF NOT EXISTS FOR (l:Location) ON (l.site);

// -------------------- Measure --------------------
CREATE CONSTRAINT measure_id_unique IF NOT EXISTS FOR (m:Measure) REQUIRE m.id IS UNIQUE;
CREATE CONSTRAINT measure_measure_id_unique IF NOT EXISTS FOR (m:Measure) REQUIRE m.measure_id IS UNIQUE;
CREATE CONSTRAINT measure_name_unique IF NOT EXISTS FOR (m:Measure) REQUIRE m.name IS UNIQUE;
CREATE INDEX measure_type_id_idx IF NOT EXISTS FOR (m:Measure) ON (m.type, m.id);
CREATE INDEX measure_created_date_idx IF NOT EXISTS FOR (m:Measure) ON (m.created_date);
CREATE INDEX measure_author IF NOT EXISTS FOR (m:Measure) ON (m.author);
CREATE INDEX measure_domain_index IF NOT EXISTS FOR (m:Measure) ON (m.domain);
CREATE INDEX measure_domain_name IF NOT EXISTS FOR (m:Measure) ON (m.domain, m.name);
CREATE INDEX measure_id IF NOT EXISTS FOR (m:Measure) ON (m.id);
CREATE INDEX measure_measure_id_idx IF NOT EXISTS FOR (m:Measure) ON (m.measure_id);
CREATE INDEX measure_name_idx IF NOT EXISTS FOR (m:Measure) ON (m.name);
CREATE INDEX measure_type_domain IF NOT EXISTS FOR (m:Measure) ON (m.type, m.domain);
CREATE INDEX measure_type_idx IF NOT EXISTS FOR (m:Measure) ON (m.type);

// -------------------- Memory --------------------
CREATE CONSTRAINT memory_id_unique IF NOT EXISTS FOR (m:Memory) REQUIRE m.id IS UNIQUE;
CREATE INDEX memory_type_created_date_idx IF NOT EXISTS FOR (m:Memory) ON (m.type, m.created_date);
CREATE INDEX memory_created_date_idx IF NOT EXISTS FOR (m:Memory) ON (m.created_date);
CREATE INDEX memory_created_timestamp_idx IF NOT EXISTS FOR (m:Memory) ON (m.timestamp);
CREATE INDEX memory_importance_idx IF NOT EXISTS FOR (m:Memory) ON (m.importance);
CREATE INDEX memory_importance_type_idx IF NOT EXISTS FOR (m:Memory) ON (m.importance, m.type);
CREATE INDEX memory_type_idx IF NOT EXISTS FOR (m:Memory) ON (m.type);

// -------------------- ObjectiveFunction --------------------
CREATE CONSTRAINT objective_function_id_unique IF NOT EXISTS FOR (of:ObjectiveFunction) REQUIRE of.id IS UNIQUE;
CREATE INDEX objective_function_active_idx IF NOT EXISTS FOR (of:ObjectiveFunction) ON (of.active);
CREATE INDEX objective_function_created_date_idx IF NOT EXISTS FOR (of:ObjectiveFunction) ON (of.created_date);
CREATE INDEX objective_function_type_idx IF NOT EXISTS FOR (of:ObjectiveFunction) ON (of.type);

// -------------------- Plan --------------------
CREATE CONSTRAINT plan_id_unique IF NOT EXISTS FOR (p:Plan) REQUIRE p.plan_id IS UNIQUE;
CREATE INDEX plan_active_idx IF NOT EXISTS FOR (p:Plan) ON (p.active);
CREATE INDEX plan_status_idx IF NOT EXISTS FOR (p:Plan) ON (p.status);

// -------------------- Prompt --------------------
CREATE CONSTRAINT prompt_name_unique IF NOT EXISTS FOR (p:Prompt) REQUIRE p.name IS UNIQUE;
CREATE CONSTRAINT prompt_id_version_unique IF NOT EXISTS FOR (p:Prompt) REQUIRE (p.id, p.version) IS UNIQUE;
CREATE CONSTRAINT prompt_id_unique IF NOT EXISTS FOR (p:Prompt) REQUIRE p.prompt_id IS UNIQUE;
CREATE INDEX prompt_access_author IF NOT EXISTS FOR (p:Prompt) ON (p.access_level, p.author);
CREATE INDEX prompt_access_level IF NOT EXISTS FOR (p:Prompt) ON (p.access_level);
CREATE INDEX prompt_active IF NOT EXISTS FOR (p:Prompt) ON (p.active);
CREATE INDEX prompt_author IF NOT EXISTS FOR (p:Prompt) ON (p.author);
CREATE INDEX prompt_category IF NOT EXISTS FOR (p:Prompt) ON (p.category);
CREATE INDEX prompt_id_active IF NOT EXISTS FOR (p:Prompt) ON (p.prompt_id, p.active);
CREATE INDEX prompt_id_idx IF NOT EXISTS FOR (p:Prompt) ON (p.prompt_id);
CREATE INDEX prompt_id_version IF NOT EXISTS FOR (p:Prompt) ON (p.prompt_id, p.version);
CREATE INDEX prompt_internal_name_idx IF NOT EXISTS FOR (p:Prompt) ON (p.internal_name);
CREATE INDEX prompt_lookup_composite IF NOT EXISTS FOR (p:Prompt) ON (p.internal_name, p.active);
CREATE INDEX prompt_name IF NOT EXISTS FOR (p:Prompt) ON (p.name);

// -------------------- Team --------------------
CREATE CONSTRAINT team_name_unique IF NOT EXISTS FOR (t:Team) REQUIRE t.team_name IS UNIQUE;
CREATE CONSTRAINT team_id_unique IF NOT EXISTS FOR (t:Team) REQUIRE t.team_id IS UNIQUE;
CREATE INDEX team_active IF NOT EXISTS FOR (t:Team) ON (t.active);
CREATE INDEX team_active_category IF NOT EXISTS FOR (t:Team) ON (t.active, t.category);
CREATE INDEX team_author IF NOT EXISTS FOR (t:Team) ON (t.author);
CREATE INDEX team_category IF NOT EXISTS FOR (t:Team) ON (t.category);
CREATE INDEX team_id_idx IF NOT EXISTS FOR (t:Team) ON (t.team_id);
CREATE INDEX team_name IF NOT EXISTS FOR (t:Team) ON (t.team_name);
CREATE INDEX team_team_id_name_index IF NOT EXISTS FOR (t:Team) ON (t.team_id, t.team_name);

// -------------------- Tool --------------------
CREATE CONSTRAINT tool_id_unique IF NOT EXISTS FOR (t:Tool) REQUIRE t.id IS UNIQUE;
CREATE INDEX tool_active_name IF NOT EXISTS FOR (t:Tool) ON (t.active, t.name);
CREATE INDEX tool_class_active IF NOT EXISTS FOR (t:Tool) ON (t.class_name, t.active);
CREATE INDEX tool_class_name IF NOT EXISTS FOR (t:Tool) ON (t.class_name);
CREATE INDEX tool_id IF NOT EXISTS FOR (t:Tool) ON (t.id);
CREATE INDEX tool_active_class_name IF NOT EXISTS FOR (t:Tool) ON (t.active, t.class_name, t.name);

// -------------------- Action --------------------
CREATE CONSTRAINT action_id_unique IF NOT EXISTS FOR (a:Action) REQUIRE a.id IS UNIQUE;
CREATE INDEX action_id IF NOT EXISTS FOR (a:Action) ON (a.id);
CREATE INDEX action_name IF NOT EXISTS FOR (a:Action) ON (a.name);
CREATE INDEX action_id_name_index IF NOT EXISTS FOR (a:Action) ON (a.id, a.name);
CREATE INDEX action_active_category_name IF NOT EXISTS FOR (a:Action) ON (a.active, a.category, a.name);

// -------------------- Wizard --------------------
CREATE CONSTRAINT wizard_id_unique IF NOT EXISTS FOR (w:Wizard) REQUIRE w.wizard_id IS UNIQUE;
CREATE CONSTRAINT wizard_name_unique IF NOT EXISTS FOR (w:Wizard) REQUIRE w.name IS UNIQUE;
CREATE INDEX wizard_active IF NOT EXISTS FOR (w:Wizard) ON (w.active);
CREATE INDEX wizard_author IF NOT EXISTS FOR (w:Wizard) ON (w.author);

// -------------------- System Options --------------------
CREATE CONSTRAINT system_options_id_unique IF NOT EXISTS FOR (so:SystemOptions) REQUIRE so.id IS UNIQUE;
CREATE INDEX system_options_id_index IF NOT EXISTS FOR (so:SystemOptions) ON (so.id);

// -------------------- Relationships --------------------
CREATE INDEX has_sbom_is_latest_idx IF NOT EXISTS FOR ()-[r:HAS_SBOM]-() ON (r.is_latest);
CREATE INDEX has_task_status_idx IF NOT EXISTS FOR ()-[r:HAS_TASK]-() ON (r.status);
CREATE INDEX member_of_active_idx IF NOT EXISTS FOR ()-[r:MEMBER_OF]-() ON (r.active);
