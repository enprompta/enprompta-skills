---
name: enprompta
description: >-
  Debug and improve LLM applications using Enprompta — triage production traces,
  score and annotate them, turn failures into regression datasets, and run
  evaluations. Use when the user mentions Enprompta, LLM traces, eval failures,
  flaky prompts, regressions, or "why did the model do X" on observed traffic.
---

# Enprompta: trace triage & evaluation

Enprompta is a prompt registry + observability + evaluation platform. This skill
closes the loop from a bad production trace to a passing regression test —
without leaving the chat.

## Setup (once)

Two ways to drive Enprompta. **Prefer the CLI when you have shell access** — it
costs nothing from the context window (no tool schemas to carry) and composes
with pipes, files, and scripts like any other shell tool.

**CLI (preferred with shell access):**

```bash
npm install -g @enprompta/cli   # or npx @enprompta/cli
enprompta auth login --api-key $ENPROMPTA_API_KEY
enprompta auth status            # verify before doing anything else
```

Every command prints JSON to stdout by default; errors go to stderr as JSON
with a non-zero exit code. Anything without a dedicated verb is reachable via
the raw passthrough: `enprompta api <METHOD> <path> [--data <json>] [--query k=v]`.

**MCP server (chat-first surfaces without a shell):**

```
claude mcp add --transport http enprompta https://enprompta.com/api/mcp \
  --header "Authorization: Bearer $ENPROMPTA_API_KEY"
```

Either way, the API key's **scopes** decide what you can do. Read-only triage
needs `traces:read`; scoring needs `traces:write`; building datasets needs
`datasets:write`; running evals needs `prompts:write`. On a "missing scope"
error, tell the user which scope to add to their key — don't retry.

The **workspace plan** also gates access: the API needs a Pro or Enterprise
workspace. Editor seats get read/write; free viewer seats are read-only (writes
return 403 "requires an editor seat" — tell the user to ask a team owner/admin
for an editor seat). Free accounts can *record* traces but not read them via
API. On a 403 plan/seat error, surface it plainly — don't retry.

## The operations

| Goal | CLI | MCP tool |
|---|---|---|
| Find traces, newest first | `enprompta trace list --limit 10` (filter low scores: `enprompta api GET /api/v1/traces --query scoreBelow=0.5`) | `list_traces` |
| Read one trace in full | `enprompta trace get <id>` | `get_trace` |
| Attach a 0–1 score + reasoning | `enprompta api POST /api/v1/traces/<id>/score --data '{"score":0.2,"reasoning":"…"}'` | `score_trace` |
| Turn failures into dataset fixtures | `enprompta api POST /api/v1/datasets/<id>/items --data '{"items":[{"input":"…","expectedOutput":"…"}]}'` | `add_traces_to_dataset` |
| Start a test run (async) | `enprompta api POST /api/v1/tests/<id>/execute` | `run_evaluation` |
| Read a run's status & pass rates | `enprompta api GET /api/v1/tests/<id>` | `get_eval_results` |
| Score a draft prompt / compare two | `enprompta eval --prompt-a @draft.txt [--prompt-b @old.txt]` | — |
| Aggregate analytics | `enprompta trace analytics --days 7` | — |

Scores are **0..1** (not 0–100). `passed` defaults to `score >= 0.5`.

## Core loop

The reason this skill exists — production failure → verified fix:

```bash
enprompta api GET /api/v1/traces --query scoreBelow=0.5 --query limit=10
enprompta trace get <worst-id>            # diagnose from the FULL trace
enprompta api POST /api/v1/traces/<id>/score --data '{"score":0.2,"reasoning":"format drift"}'
enprompta api POST /api/v1/datasets/<dataset-id>/items --data '{"items":[…]}'
enprompta api POST /api/v1/tests/<test-id>/execute
enprompta api GET  /api/v1/tests/<test-id>   # poll until no longer RUNNING
```

Don't shortcut it. The value is the evidence trail: every judgment is recorded
on the trace, and every fix is backed by a dataset the team can re-run.

## Playbooks

### 1. Triage recent failures
1. List traces with `scoreBelow=0.5`, limit 10. If empty, widen: drop the
   filter or extend the date range before concluding "nothing's wrong."
2. For each candidate, fetch the full trace and read the **full** output +
   spans. The list view truncates — never diagnose from it.
3. Form a hypothesis (hallucination, format drift, refusal, latency, tool
   error). Look at `spans` for where it went wrong in multi-step traces.
4. Score it with a score **and a one-sentence reason**. The reason is what
   makes the annotation useful to a human later — always include it.

### 2. Turn a regression into a fixture
1. After confirming a trace is genuinely wrong, decide the **correct** output.
2. Add `{ input, expectedOutput }` items to a dataset. Group related failures
   into one named dataset (e.g. `edge-cases`, `refusals`) so the suite stays
   meaningful.
3. Confirm the row count went up; tell the user which dataset grew.

### 3. Run and read an evaluation
1. Execute the test. It must be in DRAFT or FAILED status; it runs
   **asynchronously**.
2. Poll its status until it is no longer `RUNNING`. Don't spam it — space the
   checks out.
3. Report the pass rate / summary as a verdict, not a data dump: did the fix
   land, and what's still failing?

### 4. Iterate on a prompt locally (CLI only)
1. Pull the failing prompt's text into a local file.
2. `enprompta eval --prompt-a @draft.txt --prompt-name <name> --version <n> --watch`
   — edits to the file re-run the comparison automatically.
3. When the draft wins, push it and re-run the regression suite (playbook 3).

## Guardrails

- **Read before you write.** Always fetch the full trace before scoring it.
  Never score from the list summary.
- **AI-Grader runs cost real inference** and are capped per plan (50/mo Free,
  2,000/mo Pro). Don't loop test execution to "see what happens" — each run
  consumes quota. Run deliberately.
- **Reasoning is mandatory** when scoring. A bare number is noise.
- **Surface scope errors, don't paper over them.** If a write call is denied,
  the key lacks the scope — say so plainly.
- **Mutations are real.** Scoring and dataset writes are visible to the whole
  team immediately. Treat them as you would a commit.
