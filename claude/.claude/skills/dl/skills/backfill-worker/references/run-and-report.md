# Steps 11-14 — Estimate, kick off, report progress, final report

## 11. Estimates — two tables, then the user picks

Run `scripts/size_backfill.py` twice (see verification.md § Recommendation): once on Development's daily volume, once on Production's, both with the time per row measured in the Development speed test.

- Show **two separate tables**, each with the script's title line ("Estimated time to complete the full backfill — <table> #<ticket>, <ENV>"), context line, and the two notes under it. Never merge them.
- Under each table, one plain sentence: the ★ recommendation (one warehouse, one chunk size, time limit, total time, credits) and why.
- Say plainly what the numbers rest on (time per row measured on one size in Development; other sizes estimated).
- Ask the user to answer with an option number per environment. If an environment is not ready (framework, worker or columns not deployed), say what is missing and size it anyway; it cannot be started until ready.

## 12. Kick off (with permission)

For the chosen option:

1. Say in plain words what will happen: one backfill (`<TABLE>_<TICKET>`), its range, chunk size, compute (warehouse name, or serverless), time limit, and the total time to finish from the table. It runs on its own until it completes.
2. **Ask for permission to start.** Do nothing until the user says yes.
3. Through the query loop, one file (`NN_register_<name>.sql` + `.result.json`): `REGISTER_BACKFILL(...)` then `START_BACKFILL('<name>')`. The user runs it and pastes the results. Explain the result ("registered and started; first chunk within a minute").
4. `START_BACKFILL` needs SYSADMIN to hold `EXECUTE TASK` (warehouse) or `EXECUTE MANAGED TASK` (serverless). If unknown, check it first through the query loop (`SHOW GRANTS TO ROLE SYSADMIN`).
5. **Write the rows-touched query** for this backfill — `NN_rows_touched.sql` in `backfills/<TABLE>_<TICKET>/`, from the template in § Rows touched below — and give it to the user to run on their own whenever they want. Every progress report runs it too.

## 13. Progress reports

1. **Ask how often**, scaled to the total time to finish, with a suggestion: under 2 hours → every 15 min; 2-12 hours → hourly; over 12 hours → every 4 hours or twice a day. The user picks.
2. **Schedule it in this session** (CronCreate, or `/loop <interval>`). The `CLAUDE` connection signs in through the user's browser on this Mac, so the session must stay open here; a cloud routine cannot reach Snowflake. Say so.
   **The scheduled prompt must be self-contained**: it fires with only its own text, so anything it does not spell out gets skipped. Write into it: the backfill name and the progress folder; the three reads below (status, run log, `NN_rows_touched.sql`); the exact `status_header.py` command with `--to-fill` set to the kickoff `STILL_EMPTY` total and `--chunks`; the report layout in order — header in a code block, then the plain-words report (problems first), then the rows-touched table; the baseline counts; the user's time zone; the line to append to `progress.md`; and the completion check from item 6, including deleting the job. Re-create the job (delete + create) whenever the report format changes.
3. **Each report** reads, through `snow sql -c CLAUDE` (needs `SELECT` on the framework's `BACKFILL_STATUS` and `BACKFILL_RUN_LOG`):
   - `BACKFILL_STATUS` for the backfill: state, percent done, chunks done, rows so far, last chunk state and seconds, `STALLED`, `WORKER_CHANGED`, `LAST_ERROR`.
   - `BACKFILL_RUN_LOG` since the last report: chunks finished, rows, average seconds per chunk, any `FAILED` / `TIMED_OUT` / `SKIPPED`.
   - The rows-touched query (`NN_rows_touched.sql`, run as `CLAUDE` — no project UDFs): what the target table itself shows, per chunk. This is the check that the control table's counts are real rows in the target.
4. **Start every report with the header**, in a code block, rendered by `python3 -I <skill>/scripts/status_header.py --name <TABLE>_<TICKET> --filled <BY_BACKFILL total> --to-fill <STILL_EMPTY total at kickoff> --chunks-done <n> --chunks <total> [--running "chunk N running, M min"]`: an ASCII-art `Status: <backfill name>` banner (figlet, font small), a `Generated:` line with the time the report was made and the **ETA** of the whole backfill (local time zone; pass `--eta-min`), then a **Rows** bar (rows filled by the backfill ÷ rows it had to fill — starts at 0%, ends at exactly 100%) and a **Chunks** bar. Show it as printed.
   **ETA (`--eta-min`)**: minutes until the whole backfill is done = (rows still to fill − the running chunk's expected progress so far) ÷ rate, plus ~1 minute per chunk not yet started. Rate = observed rows per minute from finished chunks once any have finished, else the measured speed-test rate. If the running chunk has already run past its own estimate, count it as finishing now and say the ETA is optimistic. Use the same number in the report's "estimated finish" line.
   Then **summarize in plain words**, a few lines: where it is (percent, chunks), speed since the last report (rows per minute), new estimated finish time (remaining rows ÷ observed speed), and anything wrong. Compare the observed speed with the estimate once.
   Then **show the rows-touched table** (every chunk line plus TOTAL) and one sentence on it: how many rows the backfill has filled so far and how many are still empty. If `BACKFILL_STATUS.TOTAL_ROWS` and the table's `BY_BACKFILL` disagree for finished chunks, say so first — it is a problem.
5. **On a problem**, say it first and plainly: `FAILED` (which chunk, the safe error fields, the next step from the framework README: fix and `RESUME_BACKFILL`, or skip with a reason), `STALLED` (chunk exceeded its time limit), `WORKER_CHANGED`. Keep reporting until the user says stop.
6. **When the backfill completes**, run the rows-touched query once more. Done means `STILL_EMPTY` = 0 on every line and `TOTAL_ROWS` = `BY_BACKFILL` + `BY_MANUAL_TEST` + `BY_LIVE_LOAD`. Show the table, say so, stop the schedule and go to step 14. If `STILL_EMPTY` is not 0, say which chunks and stop — that is the "rows still NULL" red flag.

### § Rows touched — query template

Read-only, counts only. Sorts every target row in the backfill's range into one of four buckets, using `TASK_META` (search the whole array, not just `[0]`) and the guard column. Group by the backfill's own chunks (`FLOOR(DATEDIFF(<unit>, <start>, <window col>) / <chunk size>)`); if that gives more than ~60 lines (hourly or 1-day chunks over a long range), group by calendar month instead and say so in the header.

```sql
-- Rows touched — <TABLE>_<TICKET> — <ENV>
-- READ-ONLY. Run as often as you like. Each chunk's rows appear all at once when that chunk finishes.
-- DONE when STILL_EMPTY = 0 on every line and TOTAL_ROWS = BY_BACKFILL + BY_MANUAL_TEST + BY_LIVE_LOAD.
WITH T AS (
    SELECT
        FLOOR(DATEDIFF('<day|hour>', '<start>'::TIMESTAMP_NTZ, <window col>) / <chunk size>) AS CHUNK_NO,
        CASE
            WHEN <GUARD_COL> IS NULL THEN 'STILL_EMPTY'
            WHEN ARRAY_SIZE(FILTER(TASK_META, m -> m:BACKFILL_NAME::STRING = '<TABLE>_<TICKET>'
                                                AND m:OPERATION::STRING = 'BACKFILL')) > 0 THEN 'BY_BACKFILL'
            WHEN ARRAY_SIZE(FILTER(TASK_META, m -> m:BACKFILL_NAME::STRING = '<TABLE>_<TICKET>'
                                                AND m:OPERATION::STRING = 'MANUAL_TEST')) > 0 THEN 'BY_MANUAL_TEST'
            ELSE 'BY_LIVE_LOAD'
        END AS BUCKET
    FROM <DB>.<SCHEMA>.<TABLE>
    WHERE <window col> >= '<start>' AND <window col> < '<end>'
)
,BY_CHUNK AS (
    SELECT CHUNK_NO, COUNT(*) AS TOTAL_ROWS,
           COUNT_IF(BUCKET = 'BY_BACKFILL') AS BY_BACKFILL, COUNT_IF(BUCKET = 'BY_MANUAL_TEST') AS BY_MANUAL_TEST,
           COUNT_IF(BUCKET = 'BY_LIVE_LOAD') AS BY_LIVE_LOAD, COUNT_IF(BUCKET = 'STILL_EMPTY') AS STILL_EMPTY
    FROM T GROUP BY CHUNK_NO
)
SELECT IFF(CHUNK_NO IS NULL, 'TOTAL', TO_VARCHAR(CHUNK_NO + 1)) AS CHUNK,
       <FROM_DAY / TO_DAY of each chunk>,
       SUM(TOTAL_ROWS) AS TOTAL_ROWS, SUM(BY_BACKFILL) AS BY_BACKFILL, SUM(BY_MANUAL_TEST) AS BY_MANUAL_TEST,
       SUM(BY_LIVE_LOAD) AS BY_LIVE_LOAD, SUM(STILL_EMPTY) AS STILL_EMPTY,
       ROUND(100 * (SUM(TOTAL_ROWS) - SUM(BY_LIVE_LOAD) - SUM(STILL_EMPTY))
                 / NULLIF(SUM(TOTAL_ROWS) - SUM(BY_LIVE_LOAD), 0), 1) AS PCT_DONE
FROM BY_CHUNK GROUP BY GROUPING SETS ((CHUNK_NO), ()) ORDER BY CHUNK_NO NULLS LAST;
```

- Targets without `TASK_META`: drop the two stamp buckets; only `FILLED` vs `STILL_EMPTY` can be told apart, and say so.
- Before the kickoff, the `STILL_EMPTY` TOTAL is the number of rows the backfill will fill; record it in `progress.md`. At the end `BY_BACKFILL` TOTAL must equal it.
- Working example: `backfills/TRANSACTION_LOG_182/14_rows_touched.sql` in ras-datawarehouse-powerline.

## 14. Final report (HTML)

1. Pull, through `snow sql -c CLAUDE --format JSON`, the control row and all run log rows for the backfill name; save them to `backfills/<TABLE>_<TICKET>/report_control.json` and `report_runlog.json`.
2. Run `python3 -I <skill>/scripts/report.py backfills/<TABLE>_<TICKET>/report_control.json backfills/<TABLE>_<TICKET>/report_runlog.json --estimate-hours <total time to finish from the chosen option> --out backfills/<TABLE>_<TICKET>/report_<ENV>.html`.
3. Open it: `open backfills/<TABLE>_<TICKET>/report_<ENV>.html`.
4. Summarize it in a few plain lines: total rows, total time vs the estimate, average speed, and every issue (or "no issues").

The report holds counts, times and states only — no data values.
