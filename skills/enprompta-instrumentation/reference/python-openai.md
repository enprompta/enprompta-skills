# Python — raw provider SDK (OpenAI, Anthropic, Gemini)

One call instruments every OpenAI, Anthropic, and Gemini call the app already
makes — no client wrapping, no decorators, no call-site changes. Captures
prompt, response, tokens, latency, cost, errors, streaming, **and tool-call
turns**.

## Install

```bash
pip install enprompta
```

## Wire (at startup, before the first LLM call)

```python
import enprompta

enprompta.auto_instrument(api_key="ep_...")   # prefer reading from env, see below

# Existing, unmodified code is now traced:
from openai import OpenAI
client = OpenAI()
client.chat.completions.create(
    model="gpt-4o",
    messages=[{"role": "user", "content": "Hello"}],
)
```

**Read the key from the environment — don't hard-code it** (SKILL step 5):

```python
import os, enprompta
enprompta.auto_instrument(api_key=os.environ["ENPROMPTA_API_KEY"])
```

Notes (verified against `packages/sdk-python/README.md`):

- Traces are sent on a background thread pool — instrumentation never adds
  latency to, or raises into, your LLM calls.
- **Ordering:** `auto_instrument()` patches the installed provider SDKs. If no
  supported provider is importable when it runs, it emits a warning and
  instruments nothing — so make sure the provider package is installed and call
  `auto_instrument()` at startup. Pass `debug=True` to see why each SDK was or
  wasn't patched.
- **Streaming:** captured too; for OpenAI streamed *output* token counts, pass
  `stream_options={"include_usage": True}` on the call.
- Options: `environment="production"`, `enabled=False` to toggle off, or pass a
  pre-built `client=Enprompta(...)`. Call `enprompta.shutdown_auto_instrument()`
  to stop.

## Fallback: decorate a specific function

If you'd rather trace one function explicitly:

```python
from enprompta import Enprompta, trace
import openai

client = Enprompta(api_key=os.environ["ENPROMPTA_API_KEY"])

@trace(client, provider="openai", model="gpt-4o")
def generate(prompt: str) -> str:
    r = openai.chat.completions.create(model="gpt-4o", messages=[{"role": "user", "content": prompt}])
    return r.choices[0].message.content
```

## Self-hosted / preview only

Default ingest is `https://enprompta.com`. Override only for a self-hosted or
preview host (a value the user provides):

```python
enprompta.auto_instrument(api_key=os.environ["ENPROMPTA_API_KEY"], base_url="https://your-enprompta-host")
```

Then verify per the main SKILL step 6.
