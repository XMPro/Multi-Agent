# NCalc Tool — Mathematical Expression Evaluation for MAGS Agents

## Overview

The **NCalc Tool** is a built-in capability available to all MAGS agents that enables them to evaluate mathematical and logical expressions at runtime. Rather than relying on the language model to perform arithmetic directly (which can introduce rounding errors or hallucinated results), the NCalc Tool uses a dedicated expression engine to guarantee accurate, deterministic computation.

Agents can invoke this tool using plain natural language — the tool handles the translation to a precise mathematical expression internally.

---

## Why It Matters

Large language models are not calculators. When an agent needs to perform unit conversions, threshold evaluations, or engineering calculations, delegating that work to a dedicated expression engine produces more reliable and auditable results. The NCalc Tool provides this capability without requiring any external service, API key, or database configuration.

---

## How It Works

```
Agent receives query
       │
       ▼
NCalc Tool activated
       │
       ▼
Internal LLM call converts natural language → NCalc expression
       │
       ▼
NCalc engine evaluates the expression
       │
       ▼
Agent receives: Expression + Result
```

**Step-by-step:**

1. **Input** — The agent passes a natural language query to the tool (e.g., *"Convert 3.9 t/h to kg/s"*)
2. **Expression Generation** — An internal LLM call translates the query into a valid NCalc expression (e.g., `3.9 * 1000 / 3600`)
3. **Evaluation** — The NCalc engine evaluates the expression deterministically
4. **Output** — The tool returns both the generated expression and the computed result for full transparency

---

## Supported Capabilities

### Arithmetic
| Operation | Example |
|-----------|---------|
| Addition, Subtraction | `45.2 + 12.8` |
| Multiplication, Division | `3.9 * 1000 / 3600` |
| Modulo | `100 % 7` |
| Grouping | `(A + B) * C` |

### Comparisons
| Operation | Example |
|-----------|---------|
| Equal / Not equal | `pressure = 55`, `flow != 0` |
| Greater / Less than | `temp > 80`, `level <= 20` |

### Logic
| Operation | Example |
|-----------|---------|
| AND / OR / NOT | `pressure > 50 and temp < 100` |

### Mathematical Functions
| Function | Description |
|----------|-------------|
| `Abs(x)` | Absolute value |
| `Sqrt(x)` | Square root |
| `Pow(x, y)` | x raised to power y |
| `Round(x, d)` | Round to d decimal places |
| `Floor(x)` / `Ceiling(x)` | Round down / up |
| `Max(a, b)` / `Min(a, b)` | Maximum / minimum |
| `Sin(x)`, `Cos(x)`, `Tan(x)` | Trigonometric functions |
| `if(condition, true_val, false_val)` | Conditional expression |

### Constants
| Constant | Value |
|----------|-------|
| `Pi()` | 3.14159… |
| `e()` | 2.71828… |

---

## Example Interactions

| Natural Language Query | Generated Expression | Result |
|------------------------|---------------------|--------|
| Convert 3.9 t/h to kg/s | `3.9 * 1000 / 3600` | `1.0833` |
| Square root of 144 plus 2 times pi | `Sqrt(144) + 2 * Pi()` | `18.28` |
| Round 3.14159 to 2 decimal places | `Round(3.14159, 2)` | `3.14` |
| Is a pressure of 55 bar a warning? | `if(55 > 50, "warning", "ok")` | `warning` |
| Convert 80°F to Celsius | `(80 - 32) * 5/9` | `26.67` |
| Three valve moves of 0.8° plus 1.0° cumulative | `3 * 0.8 + 1.0` | `3.4` |

---

## Typical Use Cases in Industrial Settings

- **Unit conversions** — flow rates, pressures, temperatures across engineering unit systems
- **Threshold evaluations** — determining whether a measured value is within, above, or below a defined operating range
- **Engineering calculations** — heat duty, mass balance checks, efficiency ratios
- **Setpoint arithmetic** — computing adjusted setpoints based on current values and deltas
- **Conditional logic** — evaluating whether process conditions meet criteria for a recommended action

---

## Configuration

The NCalc Tool is an **internal tool** — it is built into the MAGS agent framework and does not require a database entry, external API, or agent profile configuration to be available.

### Prompt Customisation (Optional)

The internal prompt used to convert natural language into NCalc expressions can be overridden via the **Prompt Manager** using the identifier:

```
ncalc_expression_prompt
```

The prompt must include the `{input}` placeholder, which is replaced with the user's query at runtime. If no override is configured, the system default prompt is used.

### Model Override (Optional)

By default, the tool uses the same language model configured for the agent. A different model can be specified through the Prompt Manager configuration for `ncalc_expression_prompt` if a lighter or faster model is preferred for expression generation.

---

## Observability

The NCalc Tool participates fully in the MAGS telemetry and audit framework:

| Event | Log Level | Event ID | Description |
|-------|-----------|----------|-------------|
| `NCalcExpressionGenerated` | Information | 2200 | Logs the generated expression before evaluation |
| `NCalcExpressionResult` | Information | 2202 | Logs the expression and its computed result |
| `NCalcEvaluationError` | Error | 2201 | Logs evaluation failures with the offending expression |

**Metrics recorded:**
- Tool call count, response time, success/failure rate
- LLM token usage from the internal expression generation call (tracked as `InternalLLMCall`)

---

## Troubleshooting

| Symptom | Likely Cause | Resolution |
|---------|-------------|------------|
| Expression evaluation fails | LLM generated an invalid expression | Check `NCalcExpressionGenerated` log to inspect the expression |
| Division by zero error | Input query involves a zero denominator | Rephrase query or add a guard condition |
| Unexpected result | Operator precedence issue | Review the generated expression in logs; consider prompt override |
| Variables not resolved | NCalc variables are not supported | Ensure all values are numeric literals in the query |

---

## Technical Reference

- **NuGet Package**: `NCalcSync` v5.12.0
- **Tool Name (internal)**: `NCalcTool`
- **Prompt Manager Key**: `ncalc_expression_prompt`
- **Registration**: Hardcoded internal tool in `ToolLibrary.cs` — no database entry required
- **Source**: `MAGS Agent/Tool/NCalc/NCalcTool.cs`

---

*Part of the XMPro MAGS Tool System. For the full tool system reference, see the Tool System documentation.*
