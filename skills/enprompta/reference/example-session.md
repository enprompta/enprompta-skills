# Worked example: from a 0.2 trace to a green regression suite

A concrete end-to-end run of the core loop. Use it as a template — the shape
matters more than the exact ids.

## 1. Find the failures

> User: "Some support answers have been bad today. Can you look?"

```
list_traces({ scoreBelow: 0.5, limit: 10 })
```

Returns 3 traces. The worst:

```
- `tr_9f2a` · openai/gpt-4o · SUCCESS · 1840ms · Human Review: 0.20 ✗
  ↳ How do I get a refund after 60 days?
```

## 2. Read it in full

```
get_trace({ trace_id: "tr_9f2a" })
```

The output confidently cites a "90-day refund window" — but the policy is 30
days. That's a hallucinated policy, not a tone problem. The `spans` show the
retrieval step returned no policy document, so the model improvised.

## 3. Record the judgment

```
score_trace({
  trace_id: "tr_9f2a",
  score: 0.1,
  reasoning: "Hallucinated a 90-day refund window; actual policy is 30 days. Root cause: retrieval returned no policy doc, model improvised."
})
```

The reasoning names the **root cause**, not just the symptom — that's what a
human triaging the queue tomorrow needs.

## 4. Make it a fixture

```
add_traces_to_dataset({
  dataset_id: "ds_refund_policy",
  items: [{
    input: "How do I get a refund after 60 days?",
    expectedOutput: "Refunds are only available within 30 days of purchase. After 60 days the order is outside the refund window; offer store credit or escalation instead."
  }]
})
```

→ `Added 1 item to dataset ds_refund_policy (now 24 rows).`

## 5. Run the suite and report a verdict

```
run_evaluation({ test_run_id: "tr_refund_suite" })
get_eval_results({ test_run_id: "tr_refund_suite" })   // poll until not RUNNING
```

> "Ran the refund-policy suite (24 cases). Pass rate 22/24 — the two failures
> are both the hallucinated-window pattern we just caught. The fix should target
> retrieval fallback: when no policy doc is returned, the model must refuse to
> state a window rather than guess. Want me to draft that prompt change?"

Note the ending: a **verdict and a next step**, not a JSON dump. That's the
difference between an agent that triages and one that just queries.
