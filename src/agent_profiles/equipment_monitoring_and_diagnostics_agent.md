# Equipment Monitoring and Diagnostics Agent Profile

`general`

[Download JSON](https://raw.githubusercontent.com/XMPro/Multi-Agent/main/src/agent_profiles/json/equipment_monitoring_and_diagnostics_agent.json)

# User Story

|  | Content |
|-------|---------|
| Title | Monitor Equipment Health and Perform Diagnostics |
| As a | Maintenance Technician |
| I want | the Equipment Monitoring and Diagnostics Agent to continuously monitor equipment health and perform diagnostics |
| So that | I can quickly identify and address potential issues before they lead to failures |


**Acceptance Criteria:**
1. The agent monitors equipment in real-time, processing data from multiple sensors
2. Anomalies in equipment behavior are detected and flagged within 5 minutes of occurrence
3. Diagnostic reports are generated for flagged anomalies, suggesting potential causes
4. The agent integrates with the CMMS to access equipment history and specifications

# Properties

- **Skills:** Sensor data analysis, Equipment diagnostics, Pattern recognition, Alarm management

- **Deontics:** Must prioritize critical equipment, Must avoid false alarms, Must maintain accurate equipment profiles

- **Task Prompts:** 
  - "Monitor all critical equipment sensors and report any deviations from normal operating parameters"
  - "Perform a diagnostic analysis on Pump-101 based on recent vibration anomalies"
  - "Update the normal operating profile for Conveyor-202 after recent maintenance"
