# Recommended Practice: Model Selection by Role

*Back to [Implementation Guides](README.md) → Section 3.4*

---

## The Principle

Match LLM capability to role complexity. Not every agent needs the most powerful (and expensive) model. Use the right tool for the job.

---

## The Three Tiers

### Tier 1: High Capability (Complex Reasoning)

**Models**: Claude Opus, GPT-4, Gemini Ultra

**Use for agents that**:
- Make multi-factor decisions weighing competing objectives
- Synthesise inputs from multiple sources into a coherent strategy
- Perform independent safety validation with nuanced judgment
- Resolve conflicts between competing recommendations

**Typical roles**: Decision-Maker, Guardian/Validator

**Characteristics**: Slower response (10-30 sec), higher cost, best reasoning quality, largest context window

### Tier 2: Balanced (Substantial Analysis)

**Models**: Claude Sonnet, GPT-4o, Gemini Pro

**Use for agents that**:
- Perform domain-specific analysis (engineering, economic, scientific)
- Interpret data patterns and predict trajectories
- Provide quantified assessments with reasoning
- Need good reasoning but not the absolute best

**Typical roles**: Analysts (Separation, Economic, Diagnostic)

**Characteristics**: Moderate response (5-15 sec), moderate cost, good reasoning, good context window

### Tier 3: Fast and Efficient (Structured Operations)

**Models**: Claude Haiku, GPT-4o-mini, Gemini Flash

**Use for agents that**:
- Process structured data (read tags, format messages)
- Perform straightforward operations (write setpoints, confirm execution)
- Handle high-frequency, low-complexity tasks
- Need speed more than deep reasoning

**Typical roles**: Monitor/Observer, Executor/Controller

**Characteristics**: Fast response (1-5 sec), low cost, adequate reasoning for structured tasks, smaller context window

---

## Selection Decision Tree

```
Does this agent make complex multi-factor decisions?
├── Yes → Does it need to resolve competing objectives or validate safety?
│   ├── Yes → TIER 1 (Opus/GPT-4)
│   └── No → TIER 2 (Sonnet/GPT-4o)
└── No → Does it perform domain-specific analysis?
    ├── Yes → TIER 2 (Sonnet/GPT-4o)
    └── No → TIER 3 (Haiku/GPT-4o-mini)
```

---

## Cost-Performance Trade-offs

| Factor | Tier 1 | Tier 2 | Tier 3 |
|--------|--------|--------|--------|
| Response time | 10-30 sec | 5-15 sec | 1-5 sec |
| Cost per call | $$$ | $$ | $ |
| Reasoning depth | Excellent | Good | Adequate |
| Context window | Largest | Large | Moderate |
| Calls per hour (typical) | 2-4 | 4-12 | 12-60 |
| Monthly cost (est.) | High | Moderate | Low |

**Rule of thumb**: If 80% of your team's LLM cost comes from Monitor and Executor agents, you're using the wrong models. Those should be Tier 3.

---

## Token Limit Guidance

| Agent Role | Recommended Max Tokens | Why |
|-----------|----------------------|-----|
| Monitor | 2,048-4,096 | Structured data processing; short outputs |
| Analyst | 4,096-8,192 | Detailed assessments with reasoning |
| Decision-Maker | 8,192-16,384 | Complex reasoning with multiple inputs |
| Guardian | 8,192-16,384 | Thorough constraint validation |
| Executor | 2,048-4,096 | Simple confirmation and status reporting |
| Coordinator | 8,192-16,384 | Orchestrating multiple agent inputs |

---

## When to Upgrade or Downgrade

**Upgrade to a higher tier when**:
- The agent's reasoning quality is noticeably poor (missing nuances, contradicting itself)
- The agent can't handle the context window needed for its inputs
- Safety-critical decisions are being made with insufficient reasoning depth

**Downgrade to a lower tier when**:
- The agent's task is more structured than originally expected
- Response time is more important than reasoning depth
- Cost is a concern and the agent's output quality is acceptable at a lower tier

---

## Checklist

- [ ] Each agent assigned a model tier based on role complexity
- [ ] Decision-Maker and Guardian use Tier 1 (if safety-critical)
- [ ] Analysts use Tier 2
- [ ] Monitor and Executor use Tier 3
- [ ] Token limits set appropriately per role
- [ ] Cost estimate reviewed — bulk of cost should be in Tier 1/2 agents, not Tier 3
- [ ] Response time tested against planning cycle requirements
