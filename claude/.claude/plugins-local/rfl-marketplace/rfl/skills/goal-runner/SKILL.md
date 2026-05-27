---
name: goal-runner
description: Use when asked to "work next feature", "advance the PRD", "run next feature", "what's the next workable feature", "PRD status", "what's left in the PRD", "retry feature <id>", or "skip feature <id>" — drives the autonomous build loop over prd.json + progress.jsonl + RFL_JOURNAL.md. Language- and toolchain-agnostic.
---

# goal-runner (rfl)

Phase 2 of the Ralph Feedback Loop (RFL). Drive the autonomous build loop: read
state, reconcile prior sessions, select the next workable feature, surface
context, and emit a `/goal` dispatch line with the feature's pre-written
condition.

**Companion:** rfl:prd-generation produces the `prd.json` this skill consumes.

## How /goal constrains this skill

`/goal` keeps Claude working until an evaluator model confirms a transcript-
observable termination condition. **This skill cannot type slash commands** — it
emits the `/goal ...` line as a literal message for the user (or auto mode) to
dispatch. Pass the `goal_condition` through verbatim; never interpret or rewrite it.

## State files (all relative to current working directory)

- `./prd.json` — read-only. Schema in `prd-schema.md`.
- `./progress.jsonl` — append-only. This skill writes **only** `fail` and `skipped` lines.
- `./RFL_JOURNAL.md` — append-only. Schemas + compaction in `journal-schemas.md`.
- `./RFL_JOURNAL_ARCHIVE.md` — created during compaction.

Never use absolute paths or paths under `~/.claude/`. If `./prd.json` is missing,
say `no prd.json in this repo — run rfl:prd-generation first` and stop. The
goal_condition strings carry their own toolchain commands, so this skill needs no
language-specific knowledge — it dispatches each condition verbatim regardless of
the project's stack.

## On every invocation, first

Read `journal-schemas.md` for the compaction thresholds. If `RFL_JOURNAL.md`
exceeds 100 entries OR 500KB, run compaction **before any other work**.

**Whenever you write a journal entry (failure or skip), open `journal-schemas.md`
first and reproduce the exact header and field layout verbatim** — the
`## <feature_id> — <ISO8601 UTC> — FAIL (<reason>)` / `... — SKIPPED` header and
the bolded field names. Do not paraphrase the format.

## Intent: "work next feature"

1. **Read state.** Read prd.json (fail clearly if missing/malformed). Read
   progress.jsonl (missing = empty). Read RFL_JOURNAL.md (missing = empty).
2. **Reconcile prior session.** Infer the most recent dispatch from the last
   journal entry + progress.jsonl. If a goal session was dispatched but no `pass`
   entry exists for that feature, the previous session failed or was cleared:
   - Append a `fail` line to progress.jsonl with `reason:"turn_cap_exceeded"` or
     `reason:"session_cleared"` as appropriate.
   - Append a failure entry to RFL_JOURNAL.md (failure schema).
3. **Select next workable feature.** Lowest-id feature where every id in
   `depends_on` has a `pass` entry AND the feature itself has no `pass` entry.
   Tie-break by id ascending. Features with `fail`/`skipped` entries are eligible
   for re-dispatch unless explicitly skipped via the skip intent.
4. **Report status.** If nothing is workable, say why: "all features passed" or
   "blocked — feature X depends on Y which is not passed."
5. **Surface context.** Read the last 10 entries from the live journal. Identify
   "Context for next session" notes touching areas the upcoming feature will touch
   (heuristic match on description + steps), and any prior failure entries for the
   same feature id. Summarize in 3–10 bullets.
6. **Announce dispatch.** State selected `feature_id`, description, `turn_cap`,
   dependency status, and the context summary.
7. **Emit the /goal line.** As the literal next message line, output:
   `/goal <feature.goal_condition>` (verbatim). The user/auto mode dispatches it.
8. **Remind the in-session agent.** As a follow-up note (not part of the /goal
   line), restate that during the goal session the agent must: follow steps in
   order; surface full command output and exit codes to the transcript; append the
   `progress_log_entry` line to progress.jsonl with a real ISO-8601 UTC timestamp;
   append a success entry to RFL_JOURNAL.md (success schema); and run
   `tail -1 progress.jsonl` + `tail -40 RFL_JOURNAL.md` so both writes are visible.

## Intent: "PRD status"

Read all three files. Report: total features, passed, failed (without subsequent
pass), blocked (deps not satisfied), workable-now, and the id of the next workable
feature if any. List the first 3 workable features (id + description) and the
first 3 blocked features (id + which dep blocks them).

## Intent: "retry feature <id>"

Confirm the feature has a `fail` entry. Re-select it as the next dispatch even if
lower-id features are also workable. Otherwise proceed as "work next feature".

## Intent: "skip feature <id>"

Warn that skipped features do NOT unlock dependents — any feature with this id in
its `depends_on` becomes permanently blocked. Ask for confirmation — this gate
holds even if the user says "don't ask" or "just do it"; the blocking consequence
is irreversible, so confirm anyway. On confirm, append to progress.jsonl exactly:
`{"feature_id":"<id>","status":"skipped","timestamp":"<ISO8601 UTC>"}` (no `reason`
field — only `fail` lines carry a reason), and a skip entry to RFL_JOURNAL.md.

## What this skill must NOT do

- Don't modify prd.json. Read-only.
- Don't write `pass` entries to progress.jsonl. Only in-session agents write passes. This skill writes only `fail` and `skipped`.
- Don't type `/goal` directly. Emit it as a message line for user/auto-mode dispatch.
- Don't interpret or rewrite `goal_condition` strings. Pass them through verbatim.
- Don't compress or rewrite journal entries to save space. Compaction is the only bloat control.

## Output style

When narrating in chat (not when writing artifacts), be terse. Bullets over
paragraphs. State decisions and proceed. The structured artifacts are the durable
record; chat narration is ephemeral.

## Optional companion

A custom slash command at `~/.claude/commands/next-feature.md` containing the
trigger "work next feature" gives a one-keystroke entry point. Recommended, not
required.
