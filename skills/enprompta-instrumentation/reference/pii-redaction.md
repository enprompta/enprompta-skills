# Redacting PII before it leaves the app

Instrumentation captures prompts and responses. In a production app that is
user-submitted text, and it is sent to Enprompta's servers. Both SDKs can redact
it **client-side first — before anything is transmitted** — and the feature is
**off by default**.

Offer it whenever the app handles real user input. Do not switch it on silently:
it changes what the user sees in their own traces, so it is their call.

## What it catches

Five categories, all enabled when you turn it on: `email`, `phone`, `ssn`,
`credit_card`, `ip_address`.

Three ways to handle a match:

| Action | Result | Use when |
|---|---|---|
| `mask` (default) | `[EMAIL]` | you just want it gone |
| `hash` | `[EMAIL:a1b2c3d4]` | you still need to correlate — the same input always produces the same tag, and it is not reversible |
| `drop` | removed entirely, no placeholder | the placeholder itself is noise |

`hash` is usually the better default for debugging: "the same user hit this
error twice" survives redaction, the address itself does not.

## Node

```typescript
import { init } from '@enprompta/sdk'
import OpenAI from 'openai'

init({
  apiKey: process.env.ENPROMPTA_API_KEY,
  modules: { openai: OpenAI },
  pii: { action: 'hash' },              // all five categories
})
```

Narrow it, or bring your own:

```typescript
pii: { categories: ['email', 'credit_card'], action: 'drop' }
pii: { mask: (text) => myRedactor(text) }   // overrides categories/action entirely
```

## Python

`auto_instrument()` takes no `pii` argument. Build the client yourself and pass
it in — **if you let `auto_instrument()` construct its own client, nothing is
redacted**, with no warning:

```python
from enprompta import Enprompta, PiiConfig, auto_instrument
import os

client = Enprompta(
    api_key=os.environ["ENPROMPTA_API_KEY"],
    pii=PiiConfig(action="hash"),          # or categories=[...], or mask=fn
)
auto_instrument(client)
```

The config is applied by `traces.record()`, which is the path
`auto_instrument()` dispatches through, so it covers the auto-instrumented
calls as well as anything you record by hand.

## Say what it is, not more

This is regex category matching, not a classifier. It will not catch a name, a
free-text address, or an account number in a format it does not know. It
reduces exposure; it does not make a trace safe to treat as anonymous, and it
is not a compliance control on its own. Tell the user that plainly rather than
letting them infer a guarantee.

For a stricter boundary, `pii.mask` takes any function, so their own redactor
can run instead.
