# Enprompta Agent Skills

Official [Agent Skills](https://docs.claude.com/en/docs/claude-code/skills) for
[Enprompta](https://enprompta.com) — the prompt registry, observability, and
evaluation platform for AI apps. Install them into Claude Code, Cursor, or any
client that supports the open Skills standard with
[`npx skills`](https://github.com/vercel-labs/skills).

Together they cover the loop end to end: **instrument an app → get traces →
triage failures → run evals.**

## Skills

### `enprompta-instrumentation`
Instrument an application to send LLM traces to Enprompta: detect the stack,
install the SDK, wire auto-instrumentation at the entrypoint, and **verify a
trace actually lands**. Handles OpenAI / Anthropic / Gemini (raw SDK) and
LangChain / LlamaIndex / CrewAI (framework span trees), for Node/TypeScript and
Python.

```bash
npx skills add enprompta/enprompta-skills --skill enprompta-instrumentation
```

> ✅ **Validated** (2026-07-12). Verified by real runs: **Node ESM + OpenAI**
> end-to-end (a real call, patched via `modules`, emits a complete OpenInference
> trace); **Python + OpenAI** `auto_instrument()` (patch + `/api/ingest/traces`
> path confirmed, provider detection incl. `google-generativeai`); and **live in
> production** — gridmix.co.uk's tool-calling agent is ingesting traces with this
> flow. The framework span-tree path (`instrumentFrameworks` /
> `instrument_frameworks` for LangChain) is documented but not yet independently
> run here — treat it as such.

### `enprompta`
Triage traces that already exist and close the loop to a passing regression
test: read a bad production trace, score it with reasoning, turn failures into a
dataset, and run an evaluation — via the `@enprompta/cli` or the Enprompta MCP
server.

```bash
npx skills add enprompta/enprompta-skills --skill enprompta
```

## Usage

1. Install a skill (above).
2. Set your key — get one at your dashboard (`/dashboard/api-keys`). The skills
   **never** handle the key value; you set it yourself:
   ```bash
   export ENPROMPTA_API_KEY=ep_...
   ```
3. Prompt your agent, e.g. *"Set up Enprompta tracing in my app"* or *"Triage my
   worst traces from the last day."* The right skill activates automatically
   from its description.

## Layout

Flat skills layout that `npx skills` reads directly:

```
skills/
  enprompta-instrumentation/SKILL.md   (+ reference/)
  enprompta/SKILL.md                   (+ reference/)
```

## Source of truth & updates

These skills are **instructions over capabilities** — the capabilities come from
the Enprompta SDKs (`@enprompta/sdk`, `enprompta`), the `@enprompta/cli`, and the
Enprompta MCP server. When an SDK's install command, init signature, supported
framework list, or ingest path changes, the matching skill must be updated in
lockstep. The SDK READMEs are authoritative over anything written here.

## License

MIT
