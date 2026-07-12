# Node / TypeScript — raw provider SDK (OpenAI, Anthropic, Gemini)

Auto-instrument every LLM call with one `init()` at the entrypoint. Captures
provider, model, prompt, response, tokens, latency, cost, errors, **and
tool-call turns** — no per-call-site changes.

## Install

```bash
npm install @enprompta/sdk
```

## Wire (top of the entrypoint, before the provider is imported)

```typescript
import { init } from '@enprompta/sdk'
import OpenAI from 'openai'            // or: import Anthropic from '@anthropic-ai/sdk'
                                        // or: import { GenerativeModel } from '@google/generative-ai'

init({
  apiKey: process.env.ENPROMPTA_API_KEY,
  modules: { openai: OpenAI },          // { anthropic: Anthropic } / { google: GenerativeModel }
  environment: 'production',
})

// Existing code is now traced — no wrapper functions, no call-site edits.
const openai = new OpenAI()
await openai.chat.completions.create({
  model: 'gpt-4o',
  messages: [{ role: 'user', content: 'Hello' }],
})
```

### Why `modules` is not optional in ESM

Modern Node/TS (`"type": "module"`) and bundlers resolve module copies in a way
that lets the SDK patch a *different* instance than your code imports — so the
patch does nothing and **no traces appear, with no error**. Passing the client
you imported (`modules: { openai: OpenAI }`) removes the ambiguity. Only a plain
CommonJS app (`require`) may omit `modules`. When in doubt, pass it — it's
always safe.

## Multiple providers

```typescript
import OpenAI from 'openai'
import Anthropic from '@anthropic-ai/sdk'

init({
  apiKey: process.env.ENPROMPTA_API_KEY,
  modules: { openai: OpenAI, anthropic: Anthropic },
})
```

## Fallback: auto-patch can't reach the call

If the call goes through a client the SDK can't see (an unusual wrapper, a
dynamically-required module), wrap it explicitly instead:

```typescript
import { Enprompta, tracedOpenAI } from '@enprompta/sdk'
import OpenAI from 'openai'

const enprompta = new Enprompta({ apiKey: process.env.ENPROMPTA_API_KEY })
const openai = tracedOpenAI(enprompta, new OpenAI())   // all calls on this client are traced
```

Other manual helpers for fine-grained control: `observe(client, meta, fn)` and
`client.traces.wrap(meta, fn)` — see `packages/sdk-typescript/README.md`.

## Self-hosted / preview only

Default ingest is `https://enprompta.com`. Override just for a self-hosted or
preview deployment (a value the user provides):

```typescript
init({ apiKey: process.env.ENPROMPTA_API_KEY, modules: { openai: OpenAI }, baseUrl: 'https://your-enprompta-host' })
```

Then verify per the main SKILL step 6.
