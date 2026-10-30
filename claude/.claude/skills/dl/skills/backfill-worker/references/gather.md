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

## Read-only checks you may run now

`snow sql -c CLAUDE -q "<sql>" --format JSON` (role `CLAUDE`, SSO opens a browser on first use). If it fails on access, write the query to the output folder and ask the user to run it.

```sql
SELECT GET_DDL('TASK', '<DB>.<SCHEMA>.STREAM_TASK_<TABLE>');   -- compare with the Terraform
DESCRIBE TABLE <DB>.<SCHEMA>.<TABLE>;                           -- TASK_META deployed?
```
