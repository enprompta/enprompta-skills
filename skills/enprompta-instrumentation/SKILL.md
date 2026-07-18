---
name: enprompta-instrumentation
description: >-
  Instrument an application to send LLM traces to Enprompta — detect the stack,
  install the SDK, wire auto-instrumentation at the entrypoint, and verify a
  trace actually lands. Use when the user wants to set up tracing/observability,
  says "instrument my app", "send traces to Enprompta", "I see no traces yet",
  or is starting from an app that isn't reporting to Enprompta. For triaging
  traces that already exist, use the `enprompta` skill instead.
version: 1.0.0
# Plain-markdown instructions with no agent-specific code — runs on any client
# that supports the open Agent Skills standard (agentskills.io).
compatible_agents:
  - claude-code
  - cursor
  - codex
  - copilot
  - gemini-cli
  - opencode
  - goose
---

# Enprompta: instrument an app for tracing

Get an app reporting LLM traces to Enprompta. The SDK auto-instruments the
provider clients you already use (OpenAI, Anthropic, Gemini) — including
**tool-call turns** — so in the common case this is: install, add one init call
at the entrypoint, set an env var, and confirm a trace arrives.

> **The one rule that makes this skill worth running:** Enprompta tracing is
> **fail-silent by design** — it never throws. A broken setup produces **no
> error, just no traces**. So "done" is not "I added `init()`" — **done is a
> trace you can see.** Always finish with the verification step. If you skip it,
> you will confidently report success on a no-op (this is the #1 failure mode,
> see the ESM gotcha below).

## Procedure

Work through these in order. Don't jump to writing code before you've detected
the stack — the right snippet depends on it.

### 1. Detect the stack

Read the repo; do not ask the user what you can determine yourself.

- **Language:** `package.json` → Node/TypeScript; `pyproject.toml` /
  `requirements.txt` / `*.py` → Python.
- **Module system (Node only — this decides correctness):** ESM if
  `package.json` has `"type": "module"`, the files use `import`/`export`, or
  they're `.mjs`. Otherwise CommonJS. **When unsure, treat it as ESM** (the safe
  choice — see step 3).
- **Provider:** which client is imported — `openai`, `@anthropic-ai/sdk`,
  `@google/generative-ai` (Node); `openai`, `anthropic`,
  `google-generativeai` (Python).
- **Framework:** is a framework orchestrating the calls — LangChain,
  LlamaIndex, CrewAI, etc.? If so you'll add framework instrumentation *as well*
  (step 4) to capture the full nested span tree, not just the raw LLM call.
- **Entrypoint:** the first module that runs — the server bootstrap, `main`,
  `index.ts`, `app.py`, `if __name__ == "__main__"`. Instrumentation must run
  **here, before any provider client is imported or called.**

### 2. Pick the path

| Stack | Primary reference |
|---|---|
| Node + raw OpenAI/Anthropic/Gemini SDK | [`reference/node-openai.md`](reference/node-openai.md) |
| Node + LangChain (or other framework) | [`reference/node-langchain.md`](reference/node-langchain.md) |
| Python + raw OpenAI/Anthropic/Gemini SDK | [`reference/python-openai.md`](reference/python-openai.md) |
| Python + LangChain / LlamaIndex / CrewAI | [`reference/python-langchain.md`](reference/python-langchain.md) |

Read the matching reference for the exact, current snippet. **Treat the SDK
READMEs (`packages/sdk-typescript/README.md`, `packages/sdk-python/README.md`)
as the source of truth** — if a reference here disagrees with the README, the
README wins and this skill is stale.

### 3. Install and wire (at the entrypoint)

- **Install with no pinned version** — `npm install @enprompta/sdk` /
  `pip install enprompta`. Let the registry resolve the latest; pinning here
  goes stale.
- **Add the init call at the very top of the entrypoint, before the provider is
  imported.** The SDK patches the provider module on import; if your code
  imports the provider before init runs, that copy is never patched.
- **Node ESM — pass `modules` explicitly.** `init({ apiKey, modules: { openai:
  OpenAI } })`. Without `modules`, in ESM and bundlers the patch resolves a
  *different copy* of the module than your code uses and **silently instruments
  nothing** — the classic "it says it's set up but there are no traces" bug.
  (CommonJS may omit `modules` and rely on auto-detection.)
- **Idempotency:** if init/auto-instrument is already present, don't add a
  second one — adjust the existing call instead.

### 4. Add framework instrumentation (only if a framework was detected)

Raw-call instrumentation captures the model call; framework instrumentation
captures the **whole** trace — retrievals, tool calls, sub-agent steps, and
their nesting — as typed spans. Follow the framework reference for the extra
install + the one-line `instrumentFrameworks()` / `instrument_frameworks()`
call. It coexists with step 3; add both.

### 5. Auth — this is the user's step, not yours

The app reads the key from the environment; **you never write the key value into
code or config.** Add the *reference* (`process.env.ENPROMPTA_API_KEY` /
`api_key=os.environ["ENPROMPTA_API_KEY"]`) and tell the user to set it:

```bash
export ENPROMPTA_API_KEY=ep_...      # from the dashboard → /dashboard/api-keys
```

For production, tell them to put it in that platform's secret store
(Vercel/Netlify env, Docker secret, systemd `Environment=`), **not** in a
tracked file. Never paste a real key into the repo, a commit, or chat.

### 6. Verify a trace lands (mandatory — this is the definition of done)

1. Run the app and trigger **one** LLM call.
2. Confirm the trace arrived. With shell access and the CLI installed:
   ```bash
   npm install -g @enprompta/cli
   enprompta auth login --api-key $ENPROMPTA_API_KEY
   enprompta trace list --limit 1        # a row = success
   ```
   Otherwise, open **`/dashboard/traces`** — a trace appears within a few
   seconds.
3. **No trace?** Do not declare success. Work the decision tree in
   [`reference/verify-and-troubleshoot.md`](reference/verify-and-troubleshoot.md)
   (ESM `modules`, entrypoint ordering, unset key, base URL / network).

## Guardrails

- **Done = a visible trace, never "I added the code."** Always run step 6.
- **Never handle the key value.** Reference the env var; setting it is the
  user's action. Never write, commit, log, or print a real `ep_...` key.
- **Init before the provider import**, at the true entrypoint. Ordering is the
  second-most-common reason for zero traces after the ESM `modules` gap.
- **Don't pin SDK versions** in install commands — they rot. Reference the
  README for API shape, the registry for the version.
- **Surgical, idempotent edits.** One init call. If instrumentation exists,
  edit it; don't stack a second.
- **If the provider or framework is genuinely ambiguous, ask** — one question
  beats instrumenting the wrong client.
- **Base URL:** default is `https://enprompta.com`. Only override (`baseUrl` /
  `base_url`) for self-hosted/preview deployments — and that's a value the user
  gives you, not one you invent.
