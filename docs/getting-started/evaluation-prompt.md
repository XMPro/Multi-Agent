# MAGS Suitability Evaluation - LLM Prompt

## How to Use This Evaluation

**Copy the prompt below** and paste it into your favorite LLM chatbot (ChatGPT, Claude, Gemini, Grok, etc.) along with a description of your use case.

The LLM will guide you through a structured assessment to determine if XMPro MAGS is appropriate for your needs.

---

## The Evaluation Prompt

```
You are an expert consultant helping evaluate whether XMPro Multi-Agent Generative Systems (MAGS) is appropriate for a specific use case.

MAGS is an intelligence platform (~90% business process intelligence, ~10% LLM utility) designed for operational/tactical decisions in industrial environments. It excels at decisions that:
- Take 15 minutes to days (not milliseconds)
- Benefit from learning and continuous improvement
- Require coordination among multiple perspectives
- Need explainable, auditable decision-making

Your task is to conduct a structured GO/NO-GO assessment using 7 criteria.

---

## Assessment Criteria

For each criterion, ask clarifying questions, then score YES/NO with brief evidence.

**Note:** For decision support use cases (augmenting experts vs. automating decisions), focus on whether MAGS can provide intelligent synthesis and better decision quality within 15+ minute cycles.

### 1. Decision Type
**Questions to ask**:
- Is this an operational/tactical decision (not strategic planning)?
- Can decisions be made within 15 minutes to days (not milliseconds)?
- Are there clear trigger conditions or planning cycles?

**Gather**: What triggers decisions? What's the acceptable response time?

**Score**: YES/NO with evidence

---

### 2. Measurable Success
**Questions to ask**:
- Can success be measured with specific metrics?
- Are there quantifiable business impacts (cost, time, quality, efficiency)?
- Can improvements be measured over 15+ minute time horizons?

**Gather**: What specific metrics would measure success?

**Score**: YES/NO with evidence

---

### 3. Data Availability
**Questions to ask**:
- Is sufficient historical and real-time data available?
- Is data quality adequate for reliable decision-making?
- Can data be accessed and processed within MAGS timing constraints?

**Gather**: What data sources exist? What is their quality/quantity?

**Score**: YES/NO with evidence

---

### 4. Decision Logic
**Questions to ask**:
- Can human decision-making be articulated and documented?
- Are decisions based on patterns/procedures rather than pure intuition?
- Is the logic complex enough to benefit from LLM reasoning?
- Can the decision process accommodate 15+ minute cycles?

**Gather**: How do humans currently make these decisions?

**Score**: YES/NO with evidence

---

### 5. Risk Tolerance
**Questions to ask**:
- Are failure modes acceptable compared to current manual processes?
- Can human oversight or approval workflows manage risks?
- Is a 15+ minute decision delay acceptable?
- Are there adequate safeguards for delayed decision-making?

**Gather**: What happens if decisions are wrong or delayed?

**Score**: YES/NO with evidence

---

### 6. Technical Feasibility
**Questions to ask**:
- Is the response time requirement compatible with LLM-based agents (15+ minutes)?
- Can the decision logic work within current LLM reasoning capabilities?
- Does the use case align with observe-reflect-plan-act cycles?
- Are there adequate data integration points?

**Gather**: What are the technical constraints and timing requirements?

**Score**: YES/NO with evidence

---

### 7. Business Value
**Questions to ask**:
- Is there clear business value from better decisions (not just faster decisions)?
- Are there quantifiable impacts from improved decision quality?
- Does the value justify 15+ minute decision cycles?
- Is decision quality/consistency currently a challenge?

**Gather**: What is the value of better decisions? What does poor decision quality cost?

**Score**: YES/NO with evidence

---

## Scoring and Recommendation

**Calculate**: Count YES responses (1 point each)

**Rating Scale**:
- **7 points**: Excellent fit → ✅ GO
- **5-6 points**: Good fit → ✅ GO
- **3-4 points**: Marginal fit → ⚠️ CAUTION
- **0-2 points**: Poor fit → 🛑 NO-GO

---

## Output Format

Provide your assessment in this format:

**Rating**: [X]/7

**Decision**: ✅ GO | ⚠️ CAUTION | 🛑 NO-GO

**Scoring**:
1. Decision Type: [YES/NO] - [Brief evidence]
2. Measurable Success: [YES/NO] - [Brief evidence]
3. Data Availability: [YES/NO] - [Brief evidence]
4. Decision Logic: [YES/NO] - [Brief evidence]
5. Risk Tolerance: [YES/NO] - [Brief evidence]
6. Technical Feasibility: [YES/NO] - [Brief evidence]
7. Business Value: [YES/NO] - [Brief evidence]

**Key Strengths** (3 bullets):
- [Strength 1]
- [Strength 2]
- [Strength 3]

**Key Risks** (2 bullets with mitigation):
- [Risk 1]: [Mitigation approach]
- [Risk 2]: [Mitigation approach]

**Recommendation**:
[Provide clear GO/CAUTION/NO-GO recommendation with reasoning]

**Next Steps**:
[If GO: Suggest next steps]
[If CAUTION: Identify what needs to be addressed]
[If NO-GO: Suggest alternatives]

---

## Additional Context

**MAGS Strengths**:
- Operational/tactical decisions (15 min to days)
- Multi-objective optimization
- Learning from experience
- Team coordination
- Explainable decisions
- Continuous improvement

**MAGS Limitations**:
- Not for real-time control (< 1 second)
- Not for pure strategic planning
- Not for simple automation
- Requires adequate data
- Requires documentable decision logic

**Alternatives if NO-GO**:
- Real-time control: Traditional control systems, PLCs
- Simple automation: Workflow engines, RPA
- Strategic planning: BI platforms, analytics
- Pure content: Standard LLM applications

---

Now, please describe your use case and I'll conduct the assessment.
```

---

## Example Usage

### Step 1: Copy the Prompt
Copy the entire prompt above (everything in the code block).

### Step 2: Open Your LLM
Open ChatGPT, Claude, Gemini, Grok, or your preferred LLM chatbot.

### Step 3: Paste and Describe
Paste the prompt, then describe your use case. For example:

```
[Paste the evaluation prompt above]

My use case: We want to use MAGS for predictive maintenance on 50 pumps in our chemical plant. Currently, maintenance is scheduled based on time intervals, but we have 2 years of sensor data (vibration, temperature, current) and maintenance logs. We want to predict failures 24-72 hours in advance to schedule maintenance optimally and reduce unplanned downtime.
```

### Step 4: Answer Questions
The LLM will ask clarifying questions about your use case. Answer them to help it assess fit.

### Step 5: Review Assessment
The LLM will provide a scored assessment with GO/CAUTION/NO-GO recommendation and next steps.

---

## What the LLM Will Evaluate

The LLM will assess your use case against 7 criteria:
1. **Decision Type**: Operational/tactical with appropriate timing
2. **Measurable Success**: Clear metrics and quantifiable impact
3. **Data Availability**: Sufficient historical and real-time data
4. **Decision Logic**: Documentable, pattern-based reasoning
5. **Risk Tolerance**: Acceptable failure modes with oversight
6. **Technical Feasibility**: Compatible with MAGS architecture
7. **Business Value**: Clear value from better decisions

**Scoring**:
- 7/7 or 6/7: Excellent fit - Proceed with MAGS
- 5/7: Good fit - Proceed with MAGS
- 3-4/7: Marginal - Address concerns first
- 0-2/7: Poor fit - Consider alternatives

---

## After the Evaluation

### If GO (5-7 rating)
**Next Steps**:
1. Review [Use Cases](../use-cases/README.md) for similar applications
2. Study [Design Patterns](../design-patterns/README.md) for implementation approaches
3. Read [Understanding MAGS](understanding-mags.md) for core concepts
4. Follow [First Steps](first-steps.md) for your role
5. Contact XMPro: support@xmpro.com

### If CAUTION (3-4 rating)
**Next Steps**:
1. Address identified concerns
2. Develop mitigation strategies
3. Re-run evaluation after addressing gaps
4. Consider pilot/proof-of-concept approach
5. Consult with XMPro: support@xmpro.com

### If NO-GO (0-2 rating)
**Alternatives**:
- **Real-time control** (< 1 second): Traditional control systems, PLCs
- **Simple automation**: Workflow engines, RPA
- **Strategic planning**: Business intelligence, analytics platforms
- **Pure content generation**: Standard LLM applications

**Do not proceed** unless you modify the use case to address suitability concerns.

---

## Why Use an LLM for Evaluation?

**Benefits**:
- **Interactive**: LLM asks clarifying questions
- **Contextual**: Understands your specific situation
- **Thorough**: Explores nuances and edge cases
- **Immediate**: Get assessment in minutes
- **Unbiased**: Objective evaluation based on criteria

**Supported LLMs**:
- ChatGPT (OpenAI)
- Claude (Anthropic)
- Gemini (Google)
- Grok (xAI)
- Any capable LLM chatbot

---

## Related Documentation

- [Evaluation Guide](evaluation-guide.md) - Detailed written guide
- [Understanding MAGS](understanding-mags.md) - Core concepts
- [Use Cases](../use-cases/README.md) - Real-world applications
- [Getting Started](README.md) - Complete onboarding

---

**Document Version**: 1.0  
**Last Updated**: December 6, 2025  
**Status**: ✅ Complete