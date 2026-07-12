# Enprompta Agent Skill

An [Agent Skill](https://docs.claude.com/en/docs/claude-code/skills) that teaches
coding agents (Claude Code, Cursor, and any client that supports the open Skills
standard) how to triage traces and run evaluations in Enprompta — via the
`@enprompta/cli` (preferred when the agent has shell access) or the Enprompta
MCP server.

It is **instructions, not capabilities** — the actual capabilities come from the
CLI (`enprompta trace|eval|api …`) or the MCP server (`list_traces`,
`get_trace`, `score_trace`, `add_traces_to_dataset`, `run_evaluation`,
`get_eval_results`). The skill gives the agent the playbooks and guardrails to
use them well, and prefers the CLI because it costs nothing from the context
window.

## Contents

- `SKILL.md` — the skill: setup, operations, the core loop, playbooks, guardrails.
- `reference/example-session.md` — a worked end-to-end run, from a bad trace to
  a green regression suite.

## Install

**Claude Code** — copy into your skills directory (project or user scope):

```
cp -r skills/enprompta ~/.claude/skills/
```

Then give the agent a way to reach Enprompta. Either install the CLI:

```
npm install -g @enprompta/cli
enprompta auth login --api-key $ENPROMPTA_API_KEY
```

…or connect the MCP server (for surfaces without a shell):

```
claude mcp add --transport http enprompta https://enprompta.com/api/mcp \
  --header "Authorization: Bearer $ENPROMPTA_API_KEY"
```

The skill activates automatically when a task matches its `description` (traces,
eval failures, regressions, "why did the model do X").

## Distribution

This lives in the repo so it versions alongside the CLI and MCP tools it
documents. When the command surface, tool set, or scopes change, update
`SKILL.md` in the same PR — the skill and the tools must stay in lockstep.
