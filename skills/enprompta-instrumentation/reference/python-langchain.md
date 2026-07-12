# Python — LangChain / LlamaIndex / CrewAI (frameworks)

`auto_instrument()` captures the raw LLM call; **framework instrumentation**
captures the whole agent/RAG trace — retrievals, tool calls, reranks, sub-agent
steps, and their nesting — as typed OpenInference spans (Retrieval, Tool,
Reranker, Agent, Guardrail, …). Add **both**.

## Install

```bash
pip install "enprompta[instrumentation]"
pip install openinference-instrumentation-langchain    # your framework's instrumentor(s)
```

## Wire (at startup, before the framework runs)

```python
import os, enprompta

# 1) raw LLM calls
enprompta.auto_instrument(api_key=os.environ["ENPROMPTA_API_KEY"])

# 2) the framework's nested spans — auto-detects installed instrumentors:
enprompta.instrument_frameworks(api_key=os.environ["ENPROMPTA_API_KEY"])

# ...or pick frameworks explicitly:
enprompta.instrument_frameworks(
    api_key=os.environ["ENPROMPTA_API_KEY"],
    frameworks=["langchain", "llama_index"],
)
```

- Exports to Enprompta's OTLP endpoint (`/api/ingest/otlp/v1/traces`) using the
  API key as a Bearer token — coexists with an existing OpenTelemetry setup.
- Supported instrumentor names: **`langchain`, `llama_index`, `openai`,
  `anthropic`, `crewai`, `dspy`, `haystack`**. Install the matching
  `openinference-instrumentation-<name>` package for each framework you use.
- Options mirror `auto_instrument`: pass a `client=`, set `environment=...`, or
  `enabled=False`.

## Verify

The trace should render as a **span tree** (nested Tool/Retrieval/Agent spans
under one trace in `/dashboard/traces`), not a flat row. Then follow the main
SKILL step 6. If the raw call is traced but the tree is flat, step (2) didn't
take — confirm the `openinference-instrumentation-<framework>` package is
installed and that `instrument_frameworks()` runs before the framework is
invoked.
