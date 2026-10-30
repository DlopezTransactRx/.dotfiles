---
name: backfill-worker
description: Build, verify, size, start and monitor a worker for the Snowflake backfill framework (SnowflakeWHAdministration-Modules//backfill), or review an existing worker against its contract. Use when the user types /backfill-worker, or says "backfill these columns", "write a backfill worker", "review this backfill worker", "how do I backfill table X", "how long will the backfill take", or needs existing rows of a table filled after new columns were added.
argument-hint: "<table and columns to backfill, ticket> [fresh] | review <worker file>"
---

# backfill-worker

Takes a backfill from "these columns need filling" to "done, here is the report": builds a contract-correct **worker**, proves it in Development, estimates the total time for Development and Production, starts the option the user picks, reports progress on a schedule, and finishes with an HTML report.

The framework (control table, run log, lifecycle procedures, one task per backfill) is generic. The worker is the one table-specific piece: a stored procedure that fills one time window. Framework docs: `backfill/README.md` in SnowflakeWHAdministration-Modules (pin the tag the caller uses).

**Two modes:** *build* (default, the checklist below) and *review an existing worker* (static review only — [references/contract.md](references/contract.md)).

## Hard rules

- **Never run a write.** Read-only SQL runs through `snow sql -c CLAUDE`. Every `CALL`, `UPDATE`, `MERGE`, `REGISTER_BACKFILL`, `START_BACKFILL` goes to the user through the query loop.
- **Never commit.** Worker Terraform lands unstaged on `feature/dlopez` in the owning repo.
- **Development only for test writes.** Production gets read-only checks; the framework's first chunk is its first write.
- **No PHI** in exception messages, file names, logs, reports or replies. Counts and key shapes only, never row values from PHI columns.
- **Self-contained worker.** Its SQL is written out in full in its own file. No shared locals, no reuse of the live task's SQL string, no generator module.
- **Explain every step in plain words** before the user runs it, and explain every result in plain words before moving on. Never hand over SQL without saying what it does and what "pass" looks like.

## The checklist (show it, keep it updated)

Show this list at the start and again after every step, with ✅ done / ▶ next / ⬜ to do, and one line of result next to each done item.

1. ⬜ **Gather** — read the table's Terraform and live load, and find streams on the target and their consumers ([references/gather.md](references/gather.md)).
2. ⬜ **Write the worker** — `backfill_<table>_<ticket>.tf` ([references/worker.md](references/worker.md)).
3. ⬜ **Static review** — the 14 contract checks ([references/contract.md](references/contract.md)).
4. ⬜ **Q1 — Can it find every row?** (read-only)
5. ⬜ **Q2 — Does it build the right values?** (read-only)
6. ⬜ **Deploy the worker to Development** (user promotes the PR).
7. ⬜ **Q3 — Does it fix one day, and leave it alone on a re-run?** (Development writes)
8. ⬜ **Speed test — how long does a heavy hour take?** (Development write + timing)
9. ⬜ **Development volume** — rows to fill per day (read-only)
10. ⬜ **Production volume** — rows to fill per day (read-only)
11. ⬜ **Estimates** — two tables, Development and Production; each recommends one warehouse + one chunk size (one backfill, set and forget); the user picks an option for each.
12. ⬜ **Kick off** — register and start the chosen option (user runs, with permission).
13. ⬜ **Progress reports** — on the schedule the user chooses; each shows the rows-touched table (what the target itself shows, per chunk).
14. ⬜ **Final report** — HTML, per-time averages and issues.
15. ⬜ **Retire the worker** — only after Production completes: `git mv` the `.tf` to `backfills/<TABLE>_<TICKET>/backfill_<table>_<ticket>.tf.archived` and commit it with both HTML reports (tracked via a `.gitignore` exception), promote Dev then Prod; each plan destroys only the worker.

**Progress file — the checklist survives a new session.** Keep the checklist in `backfills/<TABLE>_<TICKET>/progress.md` (owning repo, git-ignored): each step's state, its one-line result, and the facts later steps need (worker name and where it is deployed, test windows used, measured speed and warehouse size, daily-volume files, chosen option, backfill names, schedule). Update it after every step.

**`fresh` starts over.** If the user says `fresh` (or "from scratch"), move any existing `backfills/<TABLE>_<TICKET>/` to `backfills/_archive_<TABLE>_<TICKET>_<YYYYMMDD-HHMM>/`, start at step 1, and redo every step — including rewriting the worker file (show the diff against the existing one) and picking test windows from fresh counts, since earlier runs may have filled some. Deployed objects and already-filled rows stay as they are; say which steps that affects.

**Otherwise, at the start, look for it.** If `progress.md` exists, read it, show the checklist, and resume at the first unfinished step — never redo finished steps. Then re-check only what can have changed since: is the worker still deployed, are the test windows still empty (an earlier run may have filled them — pick new ones from fresh counts), are any backfills already registered (`BACKFILL_STATUS`). If there is no progress file but the worker file or Snowflake objects already exist, say so, record what you find as done, and continue from there.

Details for 4-10: [references/verification.md](references/verification.md). Steps 11-15: [references/run-and-report.md](references/run-and-report.md).

## The query loop (every query the user must run)

The user runs a query when `CLAUDE` lacks permission (writes, project UDFs, their own query history). Do it **one query at a time**, never as a multi-step file to work through:

1. **Explain** in plain words: what the query does, why it is needed now, read-only or write, and what a passing result looks like.
2. **Write two files** in `backfills/<TABLE>_<TICKET>/` (owning repo, git-ignored):
   - `NN_<step>.sql` — the query with its plain-language header (kept as the record).
   - `NN_<step>.result.json` — the same query, followed by the line `-- Replace everything in this file with the RESULT_JSON cell value, then save.`
3. **Open** the result file for the user: `open -a TextEdit backfills/<TABLE>_<TICKET>/NN_<step>.result.json`.
4. The user runs the query, copies the single `RESULT_JSON` cell, pastes it over the file's contents, saves, and says so.
5. **Read** the file. If it still holds the query or is not valid JSON, say so plainly and wait.
6. **Explain the result** in plain words — what it shows, pass or fail, what it means — then update the checklist and move to the next step.

**Every user-run file returns its result as one JSON cell.** The user copies one cell and pastes it; they never convert a grid to JSON. Shape the query so its last statement returns a single column `RESULT_JSON`:

- A `SELECT` (one row or many): wrap it — `SELECT ARRAY_AGG(OBJECT_CONSTRUCT(*)) AS RESULT_JSON FROM ( <query without its trailing ;> );`. Use `ARRAY_AGG(...) WITHIN GROUP (ORDER BY ...)` when order matters.
- A `CALL`, `SHOW` or `DESCRIBE`: follow it with `SELECT ARRAY_AGG(OBJECT_CONSTRUCT(*)) AS RESULT_JSON FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));`.
- A file with several steps (e.g. `q3_dev_run`): still one paste for the whole file. After each step whose result matters, keep it in a session variable (`SET STEP2_ROWS = (SELECT $1 FROM TABLE(RESULT_SCAN(LAST_QUERY_ID())));`), and end the file with one `SELECT OBJECT_CONSTRUCT('step2_rows', $STEP2_ROWS, ...) AS RESULT_JSON;`.
- Say so in the file header: "Returns ONE cell, RESULT_JSON — copy its value into the .result.json file."

Read-only queries that `CLAUDE` can run (no project UDFs) run directly through `snow sql -c CLAUDE` (on `WH_CLAUDE_DEV` / `WH_CLAUDE`); still explain them and their results the same way, and save them as `NN_<step>.sql` + `NN_<step>.result.json` for the record.

Before the first file, make sure the owning repo's `.gitignore` has `backfills/` (`git check-ignore -q backfills/x`); if not, append it under a comment and tell the user `.gitignore` changed.

## Red flags — stop

- Reporting a gap, failure, count mismatch or badly slow chunk without having run the issue analysis (run-and-report.md § Issue analysis) — run it first, unasked.
- Kicking off while a standard stream on the target has a consumer whose impact was not predicted and whose handling the user has not chosen → gather.md § Streams on the target.
- About to run a `CALL`/DML yourself → it goes through the query loop instead.
- Handing over SQL without a plain explanation, or moving on without explaining a result.
- Worker copies the live task's per-record dedup on an insert-only, hash-keyed table → worker.md § Insert-only hash-keyed.
- Target has TASK_META and the worker does not prepend `P_META` → contract fails.
- Rows still NULL after the one-chunk Development run → stop; the source or key derivation is wrong.
- `GET_DDL` of the deployed task differs from the Terraform you read → stop; ask which is current.
- Asking the user for a timing without giving them the query-history query.
- Recommending more than one backfill for an environment, or splitting a range around a spike day → one backfill, one chunk size, one warehouse, run to completion.
