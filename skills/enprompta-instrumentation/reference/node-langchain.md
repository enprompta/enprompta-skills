# Node / TypeScript — LangChain (or other framework)

A framework fans one request out into retrievals, tool calls, and sub-steps.
`init()` alone captures the raw model call; **framework instrumentation** adds
the whole nested span tree (Retrieval, Tool, Reranker, Agent, … spans) via the
OpenInference bridge. Add **both**: `init()` for the raw call, plus
`instrumentFrameworks()` for the tree.

## Install

```bash
# raw-call instrumentation (as in node-openai.md)
npm install @enprompta/sdk

# OpenTelemetry peer deps + the instrumentor(s) for your framework
npm install @opentelemetry/sdk-trace-node @opentelemetry/sdk-trace-base \
  @opentelemetry/exporter-trace-otlp-http @opentelemetry/resources
npm install @enprompta/instrument-langchain    # also available: @enprompta/instrument-openai
```

## Wire (entrypoint, before the framework runs)

```typescript
import { init, instrumentFrameworks } from '@enprompta/sdk'
import OpenAI from 'openai'

// 1) raw LLM calls
init({ apiKey: process.env.ENPROMPTA_API_KEY, modules: { openai: OpenAI } })

// 2) the framework's nested spans
instrumentFrameworks({
  apiKey: process.env.ENPROMPTA_API_KEY!,
  frameworks: ['langchain'],          // or omit `frameworks` to auto-detect installed instrumentors
})
```

- Exports over Enprompta's OTLP endpoint using the API key as a Bearer token,
  and **coexists** with an existing OpenTelemetry setup if the app has one.
- Returns a handle — call `.uninstrument()` to stop.
- Supported JS instrumentor names today: **`langchain`** and **`openai`** (the
  JS OpenInference ecosystem is younger than Python's — for LlamaIndex/CrewAI on
  a JS app, capture the raw calls via `init()` and track the framework roadmap).

## Verify

Framework spans should show up as a **span tree** under one trace (open the
trace in `/dashboard/traces` — you'll see nested Tool/Retrieval spans, not a
flat row). Then follow the main SKILL step 6. If the raw call is traced but the
tree is flat, the instrumentor step (2) didn't take — recheck the OTel peer deps
installed and that `instrumentFrameworks` runs before the framework is invoked.
