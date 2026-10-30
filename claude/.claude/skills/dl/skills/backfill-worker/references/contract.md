# Phase 3 — Worker contract and static review

The framework calls `CALL <worker>(P_START, P_END, P_META)` once per chunk. Every check below must pass. Report each as PASS / FAIL with the line that proves it.

| # | Check | Pass when |
|---|---|---|
| 1 | Signature | Arguments exactly `(P_START TIMESTAMP_NTZ, P_END TIMESTAMP_NTZ, P_META OBJECT)`, in that order; `return_type = "NUMBER"` |
| 2 | Window | Source (or target, for same-row) filtered `>= :P_START AND < :P_END` — `P_END` exclusive |
| 3 | Update-only | No `INSERT`, no `WHEN NOT MATCHED`, no `DELETE`, no `TRUNCATE`, no DDL |
| 4 | Raises on failure | No `EXCEPTION` handler that returns or swallows; any handler re-raises |
| 5 | No data in errors | Every `EXCEPTION (...)` message is fixed text; nothing concatenates values into an error |
| 6 | NULL guard | `<GUARD_COL> IS NULL` in the match/where — unless the header declares `CORRECTION WORKER`, which then must use `IS DISTINCT FROM` |
| 7 | Unique source | Source is unique on the match key (`QUALIFY ROW_NUMBER() ... = 1` or equivalent) |
| 8 | TASK_META | Target has `TASK_META` → `ARRAY_PREPEND(COALESCE(target.TASK_META, ARRAY_CONSTRUCT()), :P_META)` sliced to `max_history`. Target has none → no TASK_META line |
| 9 | Live filters | Every filter the live load applies to the source is present |
| 10 | Key derivation | The match key is built with the same expression and inputs as the live load |
| 11 | Insert-only hash tables | No per-record dedup that drops copies (worker.md § Insert-only hash-keyed) |
| 12 | Returns rows | Ends with `RETURN SQLROWCOUNT;` (or an equivalent count) |
| 13 | Self-contained | Only database/schema/table/function names come from Terraform; no shared SQL locals |
| 14 | Naming | File `backfill_<table>_<ticket>.tf`, procedure `BACKFILL_<TABLE>_<TICKET>`, target's schema |

Re-run safety follows from 6 + 8: a second run of the same chunk finds no NULL guard rows, so it changes nothing and adds no second stamp.

## What the framework guarantees (do not re-implement in the worker)

- Calls the worker once per chunk, never concurrently for the same backfill.
- Builds `P_META`: `RUN_GROUP_ID` (= backfill id), `ROOT_TASK_NAME`, `ROOT_TASK_UUID`, `TASK_NAME`, `SCHEDULED_TIME`, `RUN_TIME`, `OPERATION = 'BACKFILL'`, `BACKFILL_NAME`, `CHUNK_START`, `CHUNK_END`, `REASON`, `REGISTERED_BY`.
- Records the worker's `GET_DDL` hash per chunk (`WORKER_HASH`, framework ≥ v1.1.0).
- On a raised error: chunk `FAILED`, backfill `FAILED`, one notification, task suspended, cursor kept.
