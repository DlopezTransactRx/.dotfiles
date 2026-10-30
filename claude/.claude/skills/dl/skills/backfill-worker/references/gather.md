# Phase 1 — Gather

Collect these facts before writing anything. Read the code; never guess.

| Fact | Where to find it |
|---|---|
| Target table, Dev and Prod names | `snowflake_table` resource in the owning repo; database comes from a local (e.g. `local.database_name` → `CPE_DEV` / `CPE_PROD`) |
| Columns to fill | The user, or the most recent commit/issue that added them |
| Ticket / issue number | The user, or the issue that added the columns |
| Owning repo + branch | The repo holding the table resource; work on `feature/dlopez` |
| Live load | The `module` (ImportFromStageTable) or task feeding the table, and its `sql_import_query` |
| Framework location | The module call `...//backfill?ref=backfill-vX.Y.Z` (database + schema inputs) |

## Classify the kind

| Kind | Signal | Action |
|---|---|---|
| **Stage replay** | Live load reads a stage/landing table (`$$$STREAM$$$` over e.g. `STAGE_CPE_TRANSMISSIONS`, `STAGE_EVENTS`) that still holds history | Worker re-derives the columns from the stage for one window |
| **Same-row expression** | Every new column is computable from columns already on the target row | Worker updates from the row itself |
| **Postgres-synced** | Table is a `dbExport_*` fed by `batchDbToEventExporter` | **Stop.** No worker. Re-run the exporter (`postgres-snowflake-sync`) |

## Facts for stage replay

1. **Live filters** — every `WHERE` that drops source rows (e.g. `ARRAY_SIZE(DATA:transactions) > 0`). The worker applies the same ones.
2. **Match key** — the `ON` of the live MERGE (e.g. `target.HASH_KEY = source.HASH_KEY`) and the exact expression that builds it, including every CTE it depends on.
3. **Write mode** — insert-only (`WHEN NOT MATCHED THEN INSERT` only) or upsert. Insert-only + content-hash key → worker.md § Insert-only hash-keyed.
4. **Window column** — the stage column the window filters on (usually `INGESTED_TIMESTAMP`). Check whether the target stores the same value (e.g. `INGESTED_TIMESTAMP AS CPH_INGESTED_TIMESTAMP`): if so, the worker also filters the target on it, which prunes a date-clustered target.
5. **Derivations** — the exact expression for each column to fill, and the CTE it reads (e.g. `REQUEST` comes from a request CTE, not the raw payload). Note any functions it calls (`EXTRACT_NCPDP_FIELD`, `NORMALIZE_SWITCH_NAME`) and confirm they exist in both environments.
6. **Guard column** — one filled column the live load always sets (never NULL for new rows). The NULL guard tests it.

## Facts for same-row expression

1. The expression per column, from the live load.
2. A target timestamp column to window on.
3. The guard column.

## TASK_META

1. Stamped if the table declares a `TASK_META` column, or its ImportFromStageTable call is module-owned or external with `$$$TASK_META_NEW$$$` / `$$$TASK_META_APPEND$$$`.
2. `max_history`: the module call's `max_history` input; default **5** when unset.
3. Record whether the column is already deployed (checked in Development step 0).

## Streams on the target (downstream impact)

A backfill **updates** rows. Every standard (non-append-only) stream on the target records each updated row as a change (a DELETE + INSERT pair with `METADATA$ISUPDATE = TRUE`), and whatever reads that stream must process all of them in its next run. On a big table this can choke the consumer. Find and size this **before** the estimates, in both environments.

1. **Find the streams** (READ-ONLY): `SHOW STREAMS IN DATABASE <DB>` and keep rows whose `table_name` is the target. Record name, `mode` (`APPEND_ONLY` vs `DEFAULT`), `stale_after`, and the owning Terraform (grep the repos for the stream's resource — the name may be built from locals, so also grep `snowflake_stream_on_table` near the target's resource). Append-only streams ignore updates — no impact; say so and stop for that stream.
2. **Find the consumers** (READ-ONLY): `SHOW TASKS IN DATABASE <DB>` and keep tasks whose `definition` reads the stream (also check views/procedures that select from it). Record per consumer: schedule, compute (warehouse or serverless), `USER_TASK_TIMEOUT_MS`, `TASK_AUTO_RETRY_ATTEMPTS`, `SUSPEND_TASK_AFTER_NUM_FAILURES`, error integration, what it writes, and who uses that output. Read its Terraform for intent.
3. **Its normal load** (query loop — `CLAUDE` usually cannot see task history): the last ~14 runs from `INFORMATION_SCHEMA.TASK_HISTORY(TASK_NAME => '<task>')` joined to `QUERY_HISTORY` for duration, rows, warehouse size, spill. That is the baseline.
4. **Predict the impact**, plainly, per consumer:
   - Changes it will see: the backfill's rows to update (step 9/10 volume), split by its schedule — a daily consumer sees a whole day of chunks at once; with the chosen chunk plan, say the largest batch it will face.
   - Will it fit? Compare against its normal rows and duration and its timeout. A stream read over rewritten rows costs roughly in proportion to the changed micro-partitions, so `rows to update ÷ normal daily rows` × normal duration is a fair first guess; flag anything near or over the timeout.
   - What happens if it does not fit: each failed run (plus retries) burns compute; the stream offset does not advance, so the backlog keeps growing; if not consumed within the table's data retention (+ `MAX_DATA_EXTENSION_TIME_IN_DAYS`) the stream goes **stale** and must be recreated; the consumer's output (counts, alerts, dashboards) may show a spike of "updates" for the backfill days.
5. **Suggest options for the user to choose** — never pick silently; the consumer belongs to someone else and its impact may be unfamiliar:
   | Option | What it means | Trade-off |
   |---|---|---|
   | Let it process | No change; consumer reads the backfill's changes | Fine only if the prediction fits its timeout; output shows the update spike |
   | Bigger compute / longer timeout for the backfill window | Terraform PR on the consumer task, reverted after | Costs credits; output still shows the spike |
   | Pause → reset → resume | PR `started = false` before kickoff; after completion advance the stream with a zero-row read (`INSERT INTO <t> SELECT … FROM <stream> WHERE FALSE`, user runs) or recreate it via Terraform; PR to resume | Cheapest; the consumer never sees the backfill — and also misses normal changes in that window (recompute them if they matter) |
   | Run it more often during the backfill | Consumer keeps up chunk by chunk | Only helps if one chunk's changes fit its timeout |
   Record the user's choice in `progress.md`; it becomes part of the kickoff (step 12) and, for pause/reset/resume, of step 15.

## Read-only checks you may run now

`snow sql -c CLAUDE -q "<sql>" --format JSON` (role `CLAUDE`, SSO opens a browser on first use). If it fails on access, write the query to the output folder and ask the user to run it.

```sql
SELECT GET_DDL('TASK', '<DB>.<SCHEMA>.STREAM_TASK_<TABLE>');   -- compare with the Terraform
DESCRIBE TABLE <DB>.<SCHEMA>.<TABLE>;                           -- TASK_META deployed?
```
