# Enprompta Instrumentation Agent Skill

An [Agent Skill](https://docs.claude.com/en/docs/claude-code/skills) that teaches
coding agents (Claude Code, Cursor, and any client that supports the open Skills
standard) to **instrument an application for Enprompta tracing** — detect the
stack, install the SDK, wire auto-instrumentation at the entrypoint, and verify
a trace actually lands.

It is **instructions, not capabilities** — the capabilities come from the
Enprompta SDKs (`@enprompta/sdk`, `enprompta`). The skill encodes the decision
procedure and the gotchas that make the difference between "added `init()`" and
"traces are flowing": ESM `modules`, entrypoint ordering, the secrets boundary,
and — above all — a mandatory verification step, because Enprompta tracing is
fail-silent and a broken setup produces no error, just no traces.

This is the front half of the loop. Once traces flow, the sibling
[`enprompta`](../enprompta/) skill takes over: triage failures, score them,
build regression datasets, run evals.

## Contents

- `SKILL.md` — the procedure: detect → pick path → install & wire → auth (user
  step) → **verify** → guardrails.
- `reference/node-openai.md`, `reference/node-langchain.md`,
  `reference/python-openai.md`, `reference/python-langchain.md` — the exact,
  current snippet per stack, lifted from the SDK READMEs.
- `reference/verify-and-troubleshoot.md` — the "no traces?" decision tree.

## Install

**Claude Code** — copy into your skills directory (project or user scope):

```
cp -r skills/enprompta-instrumentation ~/.claude/skills/
```

The user then sets their key (the skill never handles the value):

```
export ENPROMPTA_API_KEY=ep_...        # from the dashboard → /dashboard/api-keys
```

…and prompts the agent: **"Set up Enprompta tracing in my app."** The skill
activates automatically when a task matches its `description` (instrument, set up
tracing/observability, "no traces yet").

## Distribution

Lives in the repo so it versions **in lockstep** with the SDKs it documents.
When an SDK's install command, init signature, supported framework list, or
ingest path changes, update the matching reference here in the **same PR** — the
SDK READMEs are the source of truth; these references must not drift from them.

To match the `npx skills add ...` ergonomics of other tools, publish this plus
the `enprompta` skill to a public skills registry repo (e.g.
`enprompta-ai/enprompta-skills`) so users can install with a single command
rather than copying by hand.

## Source of truth

- `packages/sdk-typescript/README.md` — `@enprompta/sdk` (`init`,
  `instrumentFrameworks`, manual helpers).
- `packages/sdk-python/README.md` — `enprompta` (`auto_instrument`,
  `instrument_frameworks`, `@trace`).

## Status

**Validated by real runs** (2026-07-12):

- ✅ **Node ESM + OpenAI** — end to end. A real OpenAI call, patched via the
  `modules` path, emits a complete OpenInference trace (provider, model,
  input/output, prompt/completion token counts, latency). The ESM `modules`
  gotcha is confirmed to matter and to be handled.
- ✅ **Python + OpenAI** — `auto_instrument()` patches the client and posts to
  the same `/api/ingest/traces` path (confirmed against the SDK source); provider
  detection verified for `openai`, `anthropic`, and `google-generativeai`.
- ✅ **Live in production** — a real tool-calling agent (Watt, on
  gridmix.co.uk), instrumented with this flow, is ingesting traces.

Not yet independently exercised here (still relying on the SDK docs, which are
the source of truth): the **framework span-tree path**
(`instrumentFrameworks` / `instrument_frameworks` for LangChain/LlamaIndex).
Treat that path as documented-but-unverified until it gets its own run.
