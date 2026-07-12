# Verify a trace landed, and fix it when it didn't

Because tracing is **fail-silent** (it never throws), "no trace" is the normal
symptom of every misconfiguration. Work this top to bottom — the causes are
ordered by how often they're the culprit.

## Verify

1. Run the app and make **one** LLM call.
2. Check for the trace:
   ```bash
   npm install -g @enprompta/cli
   enprompta auth login --api-key $ENPROMPTA_API_KEY
   enprompta auth status                 # confirms the key + workspace
   enprompta trace list --limit 1        # one row = success
   ```
   No shell/CLI? Open `/dashboard/traces` — a trace appears within a few seconds.

If a trace is there, you're done. If not:

## No trace — decision tree

1. **Is `ENPROMPTA_API_KEY` actually set in the process that ran the app?**
   `echo %ENPROMPTA_API_KEY%` (cmd) / `echo $ENPROMPTA_API_KEY` (sh). A key set
   in your shell is not seen by a different terminal, a container, or a prod
   host. Fix: set it where the app runs (SKILL step 5). Get/rotate keys at
   `/dashboard/api-keys`.

2. **(Node ESM) Was `modules` passed to `init()`?** This is the most common
   silent no-op. In an ESM app or a bundler, `init()` *without*
   `modules: { openai: OpenAI }` patches a different module copy and instruments
   nothing. The SDK logs a warning when `init()` runs but nothing gets
   instrumented — check your logs. Fix: pass the client you imported.

3. **Does init run BEFORE the provider is imported/used?** The patch applies on
   import. If the provider client is imported (or the module that imports it
   runs) before `init()` / `auto_instrument()`, that copy is never patched. Fix:
   move the init call to the very top of the true entrypoint. (Python: run with
   `auto_instrument(debug=True)` to see which SDKs were patched and why.)

4. **Is the provider one the SDK instruments?** Auto-instrumentation covers
   OpenAI, Anthropic, and Gemini. A different/self-hosted client won't
   auto-trace — use the manual fallback (`tracedOpenAI` / `observe` /
   `traces.wrap` in Node; the `@trace` decorator in Python).

5. **Did the app actually make a call, and did it succeed?** No LLM call → no
   trace. A call that errored before reaching the provider also won't produce a
   normal trace.

6. **Can the app reach the ingest endpoint?** Traces POST to
   `{baseUrl}/api/ingest/traces` (default `https://enprompta.com`), framework
   spans to `{baseUrl}/api/ingest/otlp/v1/traces`. If the host blocks or
   TLS-intercepts that domain (corporate proxy/firewall), ingestion fails
   silently. Fix: allow the domain, or point `baseUrl` / `base_url` at a
   reachable Enprompta host. (This is environment-specific — only override when
   the user tells you their host/network requires it.)

7. **Plan/scope for API verification:** reading traces via the CLI/API needs a
   Pro/Enterprise workspace and a key with `traces:read`; free accounts can
   *record* traces but not read them via API — verify those in the dashboard
   instead. On a 403 seat/plan error, surface it; don't retry.

## Framework span tree is flat (raw call traced, but no nested spans)

The `instrumentFrameworks()` / `instrument_frameworks()` step didn't take.
Confirm the OpenInference instrumentor for that framework is installed
(`@enprompta/instrument-langchain` / `openinference-instrumentation-<name>`) and
that it runs before the framework is invoked. See the framework reference.
