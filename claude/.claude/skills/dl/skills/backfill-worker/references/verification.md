# Steps 4-10 — Verify and measure

Every query below reaches the user through the **query loop** in SKILL.md: one query at a time, explained before and after, saved as `NN_<step>.sql` + `NN_<step>.result.json` in `backfills/<TABLE>_<TICKET>/`. The file names in this document (`q1_find_rows`, `q2_check_values`, `q3_dev_run`) are the step names; use them as `<step>`. Kick-off, progress reports and the final report: run-and-report.md.

Files go to `backfills/<TABLE>_<TICKET>/` in the owning repo (git-ignored; see SKILL.md). Every step is labelled **READ-ONLY** (you run it through `snow sql -c CLAUDE -q "..." --format JSON`) or **WRITE — user runs** (never you). Results shown to the user are counts only — never values from the table.

The `CLAUDE` role often lacks `USAGE` on project UDFs (e.g. `EXTRACT_NCPDP_FIELD`); Snowflake then reports "Unknown user-defined function". Any read-only step that calls a UDF goes to the user to run, with `USE ROLE SYSADMIN;` at the top of its file. Queries without UDFs (counts, `GET_DDL`, `DESCRIBE`) still run through `CLAUDE` on `WH_CLAUDE_DEV` / `WH_CLAUDE` (the role has no default warehouse — always `USE WAREHOUSE` first).

Pick a test window `W` for Development: one chunk-sized window (default 1 day) with rows still NULL in the guard column. Pick a comparison window `L`: a recent day **after** the columns went live, where the live load already filled them.

## § Development — the two questions, then `q3_dev_run.sql`

Before any write, the worker must answer two questions. Each is its own read-only file:

| File | Question | How it answers |
|---|---|---|
| `q1_find_rows.sql` | "Can the worker find every row it is supposed to fix?" | Rebuilds the worker's source for window W, recreates each row's match key exactly as the live load does, and joins it to the target rows still empty. Proves no duplicate keys and no row left behind. |
| `q2_check_values.sql` | "When the worker fills a row, does it get the right answer?" | Uses window L, where the live load already filled the new columns (the answer key). Finds each row's source (proves the match), recalculates the columns with the worker's logic, and compares with what the live load stored (proves the values). Needs the new columns deployed and the live load to have run since. |

**Every generated `.sql` file opens with a plain-language header**: the question it answers, one or two sentences on what it does, READ-ONLY or WRITE, the environment and window, and how to read each result column (what "pass" looks like). Someone must understand the file without reading the query. Name files by their order and purpose (`q1_…`, `q2_…`), never by step numbers in another file.

Then `q3_dev_run.sql`

Fully qualified `<DB>_DEV` names only. The file opens with:

```sql
-- Backfill worker verification — <TABLE>_<TICKET> — DEVELOPMENT ONLY
USE ROLE SYSADMIN;
USE SECONDARY ROLES NONE;
EXECUTE IMMEDIATE $$
DECLARE not_dev EXCEPTION (-20900, 'q3_dev_run.sql: every database in this file must end in _DEV.');
BEGIN
    IF (NOT (ENDSWITH('<TARGET_DB>', '_DEV') AND ENDSWITH('<FRAMEWORK_DB>', '_DEV'))) THEN RAISE not_dev; END IF;
END;
$$;
```

| Step | Kind | Query | Pass |
|---|---|---|---|
| 0 Prerequisites | READ-ONLY | `DESCRIBE TABLE` target (TASK_META present if stamped); `DESCRIBE PROCEDURE <worker>(TIMESTAMP_NTZ, TIMESTAMP_NTZ, OBJECT)`; `SHOW TABLES LIKE 'BACKFILL_CONTROL' IN SCHEMA <framework>`; `SHOW USER FUNCTIONS` for any function the worker calls | All exist. If the worker or TASK_META is missing, the user must merge/apply first — stop |
| 1 Drift | READ-ONLY | `SELECT GET_DDL('TASK', '<live task>')` | Matches the Terraform the worker was built from (filters, key, derivations) |
| 2 Q1 — `q1_find_rows.sql` (window W) | READ-ONLY | The worker's `USING (...)` source with `:P_START/:P_END` replaced by W, joined to the target on the key: `COUNT(*)` source rows, `COUNT(DISTINCT key)`, target rows in W, target rows in W with guard NULL, source keys matching a guard-NULL target row | Source unique on key; matching keys = guard-NULL rows in W |
| 3 Q2 — `q2_check_values.sql` (window L) | READ-ONLY | Same source over L, joined to the target on the key, rows where the live load already filled the columns: `COUNT_IF(target.<col> IS DISTINCT FROM source.<col>)` per column | 0 for every column — the worker derives exactly what the live load writes |
| 4 One run (W) | **WRITE — user runs** | `CALL <worker>('<W start>', '<W end>', OBJECT_CONSTRUCT('OPERATION','MANUAL_TEST','BACKFILL_NAME','<TABLE>_<TICKET>'));` | Returns N > 0. User pastes N and the elapsed seconds |
| 5 After the run | READ-ONLY | Target rows in W: `COUNT_IF(<guard> IS NULL)`; per filled column `COUNT_IF(<col> IS NOT NULL)`; if stamped, `COUNT_IF(TASK_META[0]:OPERATION::STRING = 'MANUAL_TEST')` | Guard-NULL = 0 (or exactly the rows step 2 showed have no source copy); stamped rows = N |
| 6 Re-run (W) | **WRITE — user runs** | Same `CALL` as step 4 | Returns 0 |
| 7 No double stamp | READ-ONLY | `COUNT_IF(ARRAY_SIZE(TASK_META) > 1 AND TASK_META[1]:OPERATION::STRING = 'MANUAL_TEST')` over W | 0 |

**Manual-test stamps use the full shape.** Every hand-written `CALL` passes a `P_META` with the same keys the framework writes — `RUN_GROUP_ID`, `ROOT_TASK_NAME`, `ROOT_TASK_UUID`, `TASK_NAME`, `SCHEDULED_TIME`, `RUN_TIME`, `OPERATION`, `BACKFILL_NAME`, `CHUNK_START`, `CHUNK_END`, `REASON`, `REGISTERED_BY` — with `MANUAL_TEST` in the task keys and `OPERATION`. A two-key stamp leaves test rows shaped differently from every other row.

Steps 0 and 4-7 make up `q3_dev_run.sql`, numbered there 1-5 (prerequisites, one run, check, re-run, no double stamp); steps 2 and 3 are `q1_find_rows.sql` and `q2_check_values.sql`, run before it.

**Speed test (part of Q3).** A small test window measures startup cost, not throughput (3,822 rows in 4 s says nothing about a 26M-row hour). After the correctness steps pass, add a WRITE step that runs the worker on the **busiest hour** of the Development range (find it with a read-only count per hour of guard-NULL rows) and record rows and seconds. Use that as the rate.

**Every timed WRITE step is followed by its timing query.** The `CLAUDE` role cannot read the user's query history, so the file must include, right after any `CALL` whose duration matters, a READ-ONLY step the user runs as themselves:

```sql
SELECT ARRAY_AGG(OBJECT_CONSTRUCT(*)) WITHIN GROUP (ORDER BY START_TIME DESC) AS RESULT_JSON
FROM (
    SELECT QUERY_ID, START_TIME, END_TIME,
           ROUND(TOTAL_ELAPSED_TIME / 1000) AS SECONDS, ROUND(TOTAL_ELAPSED_TIME / 60000, 1) AS MINUTES,
           WAREHOUSE_NAME, WAREHOUSE_SIZE, EXECUTION_STATUS
    FROM TABLE(<DB>.INFORMATION_SCHEMA.QUERY_HISTORY_BY_USER(RESULT_LIMIT => 200))
    WHERE QUERY_TEXT ILIKE '%<WORKER NAME>%<window start>%'
      AND QUERY_TEXT NOT ILIKE '%QUERY_HISTORY_BY_USER%'
);
```

It returns duration, warehouse and size in one row, so the user never has to ask how to find them. Never ask the user for a timing without having given this query.

**Spikes.** Count guard-NULL rows per day over the whole range and name any day far above the median (e.g. a bulk-load day). **Never split the range into several backfills because of a spike.** A backfill is set and forget: one registered backfill, one chunk size, one warehouse, run to completion. A spike only makes the longest chunk longer; the sizer accounts for it (longest chunk, time limit) and moves to a bigger warehouse when a chunk would run too long.

Rate for sizing: `N / elapsed seconds` from step 4.

Stop at the first failing step and say which check failed and what it means. Do not move to Production.

## § Production — `q4_q4_prod_check.sql` (read-only, no writes at all)

| Step | Query | Use |
|---|---|---|
| Drift | `GET_DDL('TASK', '<live task in PROD>')` | Must match the Terraform |
| Framework | `SHOW TABLES LIKE 'BACKFILL_CONTROL' IN SCHEMA <framework PROD>` | Must exist before kickoff; if not, the framework is not deployed in Production yet |
| Preview | Step 2 above on one recent Production window | Source unique; keys match guard-NULL rows |
| Coverage | `MIN(<stage window col>)` of the stage vs `MIN(<target window col>)` of guard-NULL target rows; count of guard-NULL target rows older than the stage minimum | Rows older than the stage cannot be rebuilt — report the count |
| Daily volume | Over the range: guard-NULL target rows per day (rows to update) and, for stage replay, stage rows per day (copies to read) | Feeds the recommendation |

### Recommendation — one warehouse + one chunk size, with an ETA

The user will ask "how long will this take?" Answer it before they ask, as a table they pick from. Every option, and the recommendation, is **one backfill with one chunk size on one warehouse**, run until it completes. Never recommend several backfills for one environment.

1. **Volume per day.** READ-ONLY, over the whole range: rows still to fill per day (guard NULL) and the busiest hour per day. Save as JSON `[{"D","ROWS_DAY","BUSIEST_HOUR"}]` (counts only).
2. **Speed = time per row.** From the Development speed test (busiest-hour `CALL` + its timing query): rate = rows ÷ seconds; time per row = seconds ÷ rows (µs). Report both, with the warehouse size it ran on. The table shows time per row for every size (measured for the tested size, estimated for the others).
   - **Production uses the Development time per row on Production's own counts.** Run step 1 against Production (read-only). If the new columns are not deployed in Production yet, every row needs filling: count all rows per day and busiest hour, not guard-NULL rows. Run the sizer with `--env Production --label "<TABLE> #<ticket>, Production"` and say the time per row was measured in Development.
3. **Read the compute limits** (READ-ONLY; the `CLAUDE` role usually cannot see the warehouse, so this goes through the query loop):
   - The candidate warehouse's `STATEMENT_TIMEOUT_IN_SECONDS` (`SHOW PARAMETERS LIKE 'STATEMENT_TIMEOUT_IN_SECONDS' IN WAREHOUSE <wh>`). Snowflake stops a task at the **lower** of the task's time limit (`USER_TASK_TIMEOUT_MS`, set by the framework) and this timeout, so the sizer keeps every warehouse time limit under it. Pass it as `--wh-timeout-s`.
   - The account's `SERVERLESS_TASK_MAX_STATEMENT_SIZE` (`SHOW PARAMETERS LIKE 'SERVERLESS_TASK%' IN ACCOUNT`): the largest size serverless can scale to. The framework starts serverless tasks at XSMALL.
   - The serverless-tasks credit multiplier from Snowflake's consumption table. Pass it as `--serverless-multiplier` (default 0.9); say it was not verified if you could not check it.
4. **Measure the fixed cost per chunk.** From Q3's one-day `CALL`: seconds − rows ÷ rate (e.g. 52 s − 1,866,213 ÷ 44,467 ≈ 10 s). Pass it as `--overhead-s` (default 10).
5. **Run the sizer:** `python3 -I <skill>/scripts/size_backfill.py daily.json --rate <rows/s> --measured-size <SIZE> --env <Development|Production> --overhead-s <s> --wh-timeout-s <s> [--serverless-multiplier 0.9] --label "<TABLE> #<ticket>, <ENV>" [--max-chunk-min 120]`. Sizes are `XSMALL SMALL MEDIUM LARGE XLARGE XXLARGE`. The output is titled **"Estimated time to complete the full backfill — <label>"**, states the range, row count and measured speed, and names the key column **Total time to finish**. Show it as printed; never strip the title, the ★ recommendation line or the two notes under it.
   - Warehouse rows, one per size: Development shows XSMALL-LARGE, Production shows SMALL-XXLARGE (Production may use an aggressive warehouse). Billed for the whole run (the one-minute schedule keeps the warehouse resumed).
   - Serverless rows, one per size, meaning "if Snowflake settles at this size". Billed only for run time x the multiplier. Snowflake picks the size, so only serverless at the **measured** size can be recommended; the other serverless rows are marked *(scenario)*. Because serverless starts at XSMALL, its chunk size must let the longest chunk finish at XSMALL speed inside the time limit (framework max 1440 min) — so serverless time limits are long.
   - Per warehouse it tries every single chunk size (1 HOUR, 1/2/3/7/14/30 DAY) over the calendar-aligned range and keeps the one that finishes soonest with its longest chunk ≤ `--max-chunk-min` (default 120). Bigger chunks usually win: each chunk costs at least a minute, so fewer chunks finish sooner.
   - Each row gives chunks, **Warehouse timeout** (the backfill's time limit per chunk: 2x the longest chunk, rounded up to 30 min — what `REGISTER_BACKFILL` gets as `time_limit_minutes`), **Avg time per chunk** right next to it, longest chunk, processing time, total time to finish and credits. The timeout sits beside the average and longest chunk so the reader can see each chunk fits with room to spare.
   - ★ marks the recommendation, across warehouse and serverless rows: Development = cheapest; Production = fastest option within 25% of the cheapest option's credits.
6. **Present the table** with its assumptions (speed per size step is estimated, not measured, least certain at XLARGE/XXLARGE; each chunk ≥ 1 minute; warehouse billed for the whole run; serverless size is Snowflake's choice). Restate the ★ row in one plain sentence: compute (warehouse name + size, or serverless), chunk size, warehouse timeout vs average and longest chunk, total time, credits, and why.
7. **The user answers with a number.** That row becomes the kickoff: one `REGISTER_BACKFILL` + `START_BACKFILL` with its chunk size, warehouse timeout (as `time_limit_minutes`) and compute — the warehouse name, or `NULL` for serverless. A warehouse row needs a real warehouse of that size that SYSADMIN can use; ask which one if more than one fits.

Facts that drive the result (say them when they apply):
- Quiet days are cheap but each chunk costs at least a minute; multi-day chunks are what shorten the ETA.
- A spike day sets the longest chunk. If it pushes every chunk size on a warehouse past the cap, that warehouse falls back to hourly chunks (slow) or shows ⚠ — the fix is a bigger warehouse, never a second backfill.
- The biggest chunk may update far more rows in one `CALL` than the speed test did; say so when the longest chunk is well above the tested hour.
- The rate is per updated row; if the stage holds many more copies than target rows, say the estimate is optimistic.
- Production is sized from Production's own volume; reuse the Development rate only with that caveat.

## § Kickoff — `q5_q5_kickoff.sql` (after Development and Production pass)

```sql
-- Kickoff — <TABLE>_<TICKET> — run in <ENV>
USE ROLE SYSADMIN;
USE SECONDARY ROLES NONE;

CALL <FRAMEWORK_DB>.<FRAMEWORK_SCHEMA>.REGISTER_BACKFILL(
    '<TABLE>_<TICKET>',                                  -- name, unique forever
    '<TARGET_DB>.<TARGET_SCHEMA>.<TABLE>',               -- target
    '<TARGET_DB>.<TARGET_SCHEMA>.BACKFILL_<TABLE>_<TICKET>', -- worker
    '<start>',                                           -- start (inclusive)
    <'<end>' | NULL>,                                    -- end (exclusive); NULL = now (required for correction workers)
    '<reason, ticket — no PHI>',
    <size>, '<DAY|HOUR>',                                -- from the recommendation
    <NULL | '<warehouse>'>,                              -- NULL = serverless
    <time limit minutes>);

-- Pause stream consumers on the target here if any must not see the updates.

CALL <FRAMEWORK_DB>.<FRAMEWORK_SCHEMA>.START_BACKFILL('<TABLE>_<TICKET>');

SELECT * FROM <FRAMEWORK_DB>.<FRAMEWORK_SCHEMA>.BACKFILL_STATUS WHERE BACKFILL_NAME = '<TABLE>_<TICKET>';
```

Remind the user: `START_BACKFILL` needs SYSADMIN to hold `EXECUTE TASK` (warehouse) / `EXECUTE MANAGED TASK` (serverless). Recovery and verification steps are in the framework README.
