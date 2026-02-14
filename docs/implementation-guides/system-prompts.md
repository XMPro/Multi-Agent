# Recommended Practice: Writing System Prompts

*Back to [Implementation Guides](README.md) → Section 3.1*

---

## The Principle

The system prompt defines **WHO the agent is** — its identity, expertise, and personality. It should NOT contain operational instructions, specific procedures, or step-by-step workflows. Those belong in behavioural rules, tools, and plan actions.

---

## What Belongs in a System Prompt

| Include | Don't Include |
|---------|--------------|
| Agent's role and identity | Step-by-step procedures |
| Domain expertise and background | Specific data tag names |
| Communication style and tone | Tool usage instructions |
| Scope and boundaries (what it covers) | Timing parameters |
| Relationship to other agents | Specific threshold values |
| High-level decision philosophy | Detailed calculation methods |

---

## System Prompt Structure

A well-structured system prompt has **2-3 paragraphs** covering:

### Paragraph 1: Identity and Role
*Who are you? What is your primary responsibility?*

> "You are the [Role Name] for the [Team Name]. Your role is to [primary responsibility] by [how you do it]."

### Paragraph 2: Data and Context
*What information do you work with? What do you observe?*

> "You [read/receive/monitor] [data types] from [sources]. From this data, you [assess/evaluate/predict] [what you determine]."

### Paragraph 3: Output and Boundaries
*What do you produce? What don't you do?*

> "You provide [outputs] to [recipients]. You do not [boundaries — what's outside your scope]."

---

## Examples

### Good System Prompt ✅

> "You are the Separation Performance Analyst for the NGL Depropaniser Autonomous Optimisation Team. Your role is to understand and predict how the depropaniser column is performing its C3/C4 separation, and how changes in feed composition or operating conditions will affect product impurities.
>
> You receive state assessments from the Process Monitor containing current feed composition, flows, temperatures, pressures, levels, and analyser readings. From this data, you assess separation difficulty, predict where impurities are heading if conditions remain unchanged, and determine whether the column has spare separation capacity or is approaching constraints.
>
> You provide your separation performance assessment to the Optimisation Decision-Maker. You do not make economic judgments or propose setpoint values — you provide the engineering analysis that informs them."

**Why it's good**: Clear identity, clear data context, clear output, clear boundaries.

### Bad System Prompt ❌

> "You are an AI agent that monitors TI3106 temperature tag and QI3103 analyser tag. When TI3106 exceeds 83°C, calculate the impurity trajectory using the formula: impurity_change = 0.15 * (temp - 80) / 3. If the result exceeds 1.8 mol%, send a message to agent DEC-001 with the format: {alert_type: 'impurity_warning', value: X, predicted_time: Y}. Check every 15 minutes."

**Why it's bad**: Contains specific tag names (should be in tool config), calculation formulas (should be in the LLM's reasoning), message formats (should be in tool config), and timing parameters (should be in profile config). If any of these change, the system prompt must be rewritten.

---

## The System Prompt vs Other Configuration

| Configuration Element | Where It Goes | Why |
|----------------------|--------------|-----|
| "You are a separation analyst" | **System Prompt** | Identity — rarely changes |
| "You MUST assess impurity trajectory every cycle" | **Behavioural Rules** (Obligation) | Operational rule — may be tuned |
| "Read tag TI3106 every 10 seconds" | **Tool Configuration** | Data access — changes per deployment |
| "Planning cycle: 15 minutes" | **Profile Technical Specs** | Timing — changes per environment |
| "Impurity limit: 2.0 mol%" | **Constraint Configuration** | Hard limit — managed separately |
| "Steepness: 3.5 for impurity utility" | **Utility Function Config** | Preference tuning — adjusted over time |

---

## Tips for Effective System Prompts

### 1. Write in Second Person
Use "You are..." and "Your role is..." — this establishes the agent's identity clearly for the LLM.

### 2. Be Specific About Expertise
Don't say "You are an expert." Say "You have deep knowledge of distillation thermodynamics, C3/C4 separation behaviour under varying feeds, and the relationship between reflux ratio, reboiler duty, and product purity."

### 3. Define Boundaries Explicitly
State what the agent does NOT do. This prevents the LLM from overstepping: "You do not make economic judgments" or "You do not write to any controller."

### 4. Keep It Stable
The system prompt should rarely change. If you find yourself updating it frequently, you're probably putting operational details in it that belong elsewhere.

### 5. Test with a Simple Question
After writing the prompt, ask: "If I gave this prompt to a new employee on their first day, would they understand their role?" If yes, it's a good system prompt.

---

## Checklist

- [ ] System prompt defines identity and role (Paragraph 1)
- [ ] System prompt describes data context (Paragraph 2)
- [ ] System prompt defines outputs and boundaries (Paragraph 3)
- [ ] No specific tag names, thresholds, or timing parameters in the prompt
- [ ] No step-by-step procedures or calculation formulas
- [ ] Boundaries explicitly state what the agent does NOT do
- [ ] Prompt is stable — wouldn't need to change for a different deployment
