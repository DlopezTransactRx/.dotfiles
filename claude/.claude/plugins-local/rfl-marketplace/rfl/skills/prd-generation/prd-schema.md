# prd.json schema (shared artifact)

`prd.json` lives at the repo root. It is a single **top-level JSON array**. Each
element is a feature object. No markdown fences, no comments, no prose. First
character `[`, last character `]`.

## Feature object

| Field | Type | Rules |
|-------|------|-------|
| `id` | string | Unique, zero-padded sequential, e.g. `FEAT-001`. Milestone-prefixed (`M1-FEAT-001`) when project > ~150 features. |
| `category` | string | One of: `functional`, `api-contract`, `cli`, `integration`, `technical`, `non-functional`. No `ui`. |
| `description` | string | One sentence, present tense, describes observable behavior. |
| `depends_on` | string[] | Feature ids that must have a `pass` entry in progress.jsonl before this feature is workable. May be empty `[]`. |
| `steps` | string[] | 1–6 black-box assertions/actions. No file/package/function/library names. Mirror the goal_condition assertions. |
| `goal_condition` | string | ≤4000 chars. Exact string passed to `/goal`. Format rules below. |
| `validation` | object | `{ "command": string, "expect_exit_code": int, "expect_stdout_contains"?: string }`. Authoritative deterministic re-verification command. |
| `turn_cap` | integer | Max turns for the goal session. Typically 15–30. |
| `progress_log_entry` | object | `{ "feature_id": string, "status": "pass" }`. `feature_id` MUST equal `id`. |

**There is NO `passes` field.** Completion state lives only in `progress.jsonl`.

## goal_condition format (mandatory)

1. Starts with: `Feature <id> is complete when ALL of the following are visible in this session's transcript:`
2. Numbered assertions `(1)`, `(2)`, ... each referencing a specific executed command and its exact visible evidence (exit code, output substring, empty output, PASS line).
3. Requires full command output + exit codes visible: "Each command's full output and exit code must be visible in this transcript."
4. Includes the progress.jsonl append assertion:
   `Append a line to progress.jsonl of the form {"feature_id":"<id>","status":"pass","timestamp":"<ISO8601>"} and \`cat progress.jsonl | tail -1\` must show that line in the transcript.`
5. Includes the journal append assertion:
   `Append an entry to RFL_JOURNAL.md following the success-entry schema, then run \`tail -40 RFL_JOURNAL.md\` so the entry is visible in the transcript.`
6. Ends with: `Stop after <turn_cap> turns if not complete and report what is blocking.`
7. Stays under 4000 characters.
8. No vague predicates ("tests pass", "code is clean", "feature works"). Required style references a specific command and its exact evidence, using the project's real toolchain command — e.g. ``\`<test> -run TestX -v\` was executed and the transcript shows it exited 0 with PASS visible`` (substitute the project's test command, such as `go test ./...`, `pytest -k`, `cargo test`).

## progress.jsonl line shapes

- Pass (agent, in goal session): `{"feature_id":"FEAT-007","status":"pass","timestamp":"<ISO8601 UTC>"}`
- Fail (goal-runner, next invocation): `{"feature_id":"FEAT-007","status":"fail","timestamp":"...","reason":"turn_cap_exceeded"}`
- Skipped (goal-runner, on request): `{"feature_id":"FEAT-007","status":"skipped","timestamp":"..."}`

Only `pass` entries unlock dependents. Skipped features do NOT unlock dependents.
