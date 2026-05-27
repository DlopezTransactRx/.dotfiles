# prd.json schema (shared artifact)

`prd.json` lives at the repo root. It is a single **top-level JSON array**. Each
element is a feature object. This skill treats prd.json as **read-only**.

## Feature object

| Field | Type | Rules |
|-------|------|-------|
| `id` | string | Unique, zero-padded sequential, e.g. `FEAT-001`. May be milestone-prefixed (`M1-FEAT-001`). |
| `category` | string | One of: `functional`, `api-contract`, `cli`, `integration`, `technical`, `non-functional`. |
| `description` | string | One sentence, present tense. |
| `depends_on` | string[] | Feature ids that must have a `pass` entry in progress.jsonl before this feature is workable. May be empty. |
| `steps` | string[] | 1–6 black-box assertions/actions. |
| `goal_condition` | string | ≤4000 chars. The exact string passed verbatim to `/goal`. Never rewrite it. |
| `validation` | object | `{ "command": string, "expect_exit_code": int, "expect_stdout_contains"?: string }`. |
| `turn_cap` | integer | Max turns for the goal session. |
| `progress_log_entry` | object | `{ "feature_id": string, "status": "pass" }`. |

**There is NO `passes` field.** Completion state lives only in `progress.jsonl`.

## progress.jsonl line shapes

Append-only file at repo root, one JSON object per line.

- Pass (written by the agent during a goal session): `{"feature_id":"FEAT-007","status":"pass","timestamp":"<ISO8601 UTC>"}`
- Fail (written by THIS skill on next invocation): `{"feature_id":"FEAT-007","status":"fail","timestamp":"...","reason":"turn_cap_exceeded"}` or `"reason":"session_cleared"`
- Skipped (written by THIS skill on user request): `{"feature_id":"FEAT-007","status":"skipped","timestamp":"..."}`

Only `pass` entries unlock dependents. Skipped features do NOT unlock dependents.

A feature is **passed** if it has any `pass` entry. Features with only `fail` or
`skipped` entries are eligible for re-dispatch (unless explicitly skipped via the
skip intent).
