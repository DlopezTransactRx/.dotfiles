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

## 13. Progress reports

1. **Ask how often**, scaled to the total time to finish, with a suggestion: under 2 hours → every 15 min; 2-12 hours → hourly; over 12 hours → every 4 hours or twice a day. The user picks.
2. **Schedule it in this session** (CronCreate, or `/loop <interval>`). The `CLAUDE` connection signs in through the user's browser on this Mac, so the session must stay open here; a cloud routine cannot reach Snowflake. Say so.
3. **Each report** reads, through `snow sql -c CLAUDE` (needs `SELECT` on the framework's `BACKFILL_STATUS` and `BACKFILL_RUN_LOG`):
   - `BACKFILL_STATUS` for the backfill: state, percent done, chunks done, rows so far, last chunk state and seconds, `STALLED`, `WORKER_CHANGED`, `LAST_ERROR`.
   - `BACKFILL_RUN_LOG` since the last report: chunks finished, rows, average seconds per chunk, any `FAILED` / `TIMED_OUT` / `SKIPPED`.
4. **Summarize in plain words**, a few lines: where it is (percent, chunks), speed since the last report (rows per minute), new estimated finish time (remaining rows ÷ observed speed), and anything wrong. Compare the observed speed with the estimate once.
5. **On a problem**, say it first and plainly: `FAILED` (which chunk, the safe error fields, the next step from the framework README: fix and `RESUME_BACKFILL`, or skip with a reason), `STALLED` (chunk exceeded its time limit), `WORKER_CHANGED`. Keep reporting until the user says stop.
6. **When the backfill completes**, say so, stop the schedule and go to step 14.

## 14. Final report (HTML)

1. Pull, through `snow sql -c CLAUDE --format JSON`, the control row and all run log rows for the backfill name; save them to `backfills/<TABLE>_<TICKET>/report_control.json` and `report_runlog.json`.
2. Run `python3 -I <skill>/scripts/report.py backfills/<TABLE>_<TICKET>/report_control.json backfills/<TABLE>_<TICKET>/report_runlog.json --estimate-hours <total time to finish from the chosen option> --out backfills/<TABLE>_<TICKET>/report_<ENV>.html`.
3. Open it: `open backfills/<TABLE>_<TICKET>/report_<ENV>.html`.
4. Summarize it in a few plain lines: total rows, total time vs the estimate, average speed, and every issue (or "no issues").

The report holds counts, times and states only — no data values.
