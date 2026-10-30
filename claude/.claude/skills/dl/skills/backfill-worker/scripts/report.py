#!/usr/bin/env python3
"""Backfill completion report (HTML) from BACKFILL_CONTROL and BACKFILL_RUN_LOG rows exported as JSON.

Usage: report.py control.json runlog.json [--estimate-hours H] [--credits credits.json] --out report.html
credits.json: list of {"SOURCE": str, "CREDITS": number, "NOTE": str} (e.g. the backfill task, test runs).
--rows-touched: the rows-touched markdown table (CHUNK ... STILL_EMPTY, PCT_DONE); any STILL_EMPTY > 0 is flagged.
--analysis: the issue analysis (plain text; "## " headings and "- " bullets), shown when given.
Counts, times and states only; no data values.
"""
import argparse, datetime as dt, html, json, statistics
from collections import defaultdict

def ts(v):
    if not v:
        return None
    v = str(v).replace("Z", "+00:00")
    for f in ("%Y-%m-%d %H:%M:%S.%f %z", "%Y-%m-%d %H:%M:%S %z"):
        try:
            return dt.datetime.strptime(v, f)
        except ValueError:
            pass
    try:
        return dt.datetime.fromisoformat(v)
    except ValueError:
        return None

def hours(s):
    return f"{s/3600:.1f} h" if s >= 3600 else f"{s/60:.0f} min"

def table(head, rows):
    h = "".join(f"<th>{html.escape(str(c))}</th>" for c in head)
    b = "".join("<tr>" + "".join(f"<td>{html.escape(str(c))}</td>" for c in r) + "</tr>" for r in rows)
    return f"<table><tr>{h}</tr>{b}</table>"

def main():
    a = argparse.ArgumentParser()
    a.add_argument("control"); a.add_argument("runlog")
    a.add_argument("--estimate-hours", type=float); a.add_argument("--out", required=True)
    a.add_argument("--credits", help="JSON list of {SOURCE, CREDITS, NOTE} from the credits query")
    a.add_argument("--rows-touched", help="markdown table from the rows-touched query")
    a.add_argument("--analysis", help="issue analysis text (## headings, - bullets)")
    o = a.parse_args()
    ctl = json.load(open(o.control)); log = json.load(open(o.runlog))
    ctl = ctl if isinstance(ctl, list) else [ctl]
    credits = json.load(open(o.credits)) if o.credits else []
    parts = []
    for c in ctl:
        name = c.get("BACKFILL_NAME")
        rows = [r for r in log if r.get("BACKFILL_NAME") == name]
        ok = [r for r in rows if r.get("STATE") == "SUCCEEDED"]
        bad = [r for r in rows if r.get("STATE") in ("FAILED", "TIMED_OUT", "SKIPPED")]
        start, end = ts(c.get("STARTED_AT")), ts(c.get("FINISHED_AT"))
        wall = (end - start).total_seconds() if start and end else None
        total_rows = sum(int(r.get("ROWS_AFFECTED") or 0) for r in ok)
        durs = [float(r["DURATION_SECONDS"]) for r in ok if r.get("DURATION_SECONDS") is not None]
        busy = sum(durs)
        hashes = sorted({r.get("WORKER_HASH") for r in rows if r.get("WORKER_HASH")})
        summary = [
            ("State", c.get("STATE")), ("Range", f"{c.get('START_TS')} → {c.get('END_TS') or 'now'}"),
            ("Chunk", f"{c.get('CHUNK_SIZE')} {c.get('CHUNK_UNIT')}"), ("Compute", c.get("WAREHOUSE") or "SERVERLESS"),
            ("Started", c.get("STARTED_AT")), ("Finished", c.get("FINISHED_AT")),
            ("Total time", hours(wall) if wall else "—"),
            ("Estimate", f"{o.estimate_hours:.1f} h" if o.estimate_hours else "—"),
            ("Rows updated", f"{total_rows:,}"), ("Chunks succeeded", f"{len(ok):,} of {len(rows):,} attempts"),
        ]
        avgs = [
            ("Rows per chunk (avg)", f"{total_rows/len(ok):,.0f}" if ok else "—"),
            ("Seconds per chunk (avg / median / max)",
             f"{statistics.mean(durs):.1f} / {statistics.median(durs):.1f} / {max(durs):.1f}" if durs else "—"),
            ("Rows per minute while working", f"{total_rows/busy*60:,.0f}" if busy else "—"),
            ("Rows per minute overall", f"{total_rows/wall*60:,.0f}" if wall else "—"),
            ("Time per row (µs, while working)", f"{busy/total_rows*1e6:.1f}" if total_rows else "—"),
            ("Busy share of total time", f"{busy/wall*100:.0f}%" if wall else "—"),
        ]
        per_hour = defaultdict(lambda: [0, 0, 0.0])
        for r in ok:
            t = ts(r.get("STARTED_AT"))
            if t:
                k = t.strftime("%Y-%m-%d %H:00")
                per_hour[k][0] += 1; per_hour[k][1] += int(r.get("ROWS_AFFECTED") or 0)
                per_hour[k][2] += float(r.get("DURATION_SECONDS") or 0)
        hour_rows = [(k, v[0], f"{v[1]:,}", f"{v[2]/v[0]:.1f}", f"{v[1]/v[2]*60:,.0f}" if v[2] else "—")
                     for k, v in sorted(per_hour.items())]
        issues = [(r.get("CHUNK_START"), r.get("STATE"), r.get("SQLCODE") or "", r.get("QUERY_ID") or "", r.get("NOTE") or "")
                  for r in bad]
        issue_notes = []
        if len(hashes) > 1:
            issue_notes.append(f"Worker changed during the run ({len(hashes)} versions: {', '.join(hashes)}).")
        if c.get("LAST_ERROR"):
            issue_notes.append(f"Last error: {c.get('LAST_ERROR')}")
        parts.append(f"<h2>{html.escape(str(name))}</h2>" + table(["", ""], summary)
                     + "<h3>Averages</h3>" + table(["Measure", "Value"], avgs)
                     + "<h3>Per hour of running</h3>" + table(["Hour", "Chunks", "Rows", "Avg s/chunk", "Rows/min"], hour_rows)
                     + "<h3>Issues</h3>"
                     + ("".join(f"<p class=warn>{html.escape(n)}</p>" for n in issue_notes)
                        + (table(["Chunk start", "State", "SQLCODE", "Query id", "Note"], issues) if issues else "")
                        if issues or issue_notes else "<p class=ok>No failed, timed-out or skipped chunks. Worker unchanged.</p>"))
    if o.rows_touched:
        lines = [l.strip() for l in open(o.rows_touched) if l.strip().startswith("|") and not l.strip().startswith("|---")]
        if lines:
            head = [c.strip() for c in lines[0].strip("|").split("|")]
            body = [[c.strip() for c in l.strip("|").split("|")] for l in lines[1:]]
            col = head.index("STILL_EMPTY") if "STILL_EMPTY" in head else None
            gaps = [r for r in body if col is not None and r[0] != "TOTAL" and r[col].replace(",", "") not in ("0", "")]
            note = ("<p class=warn>" + html.escape(f"{len(gaps)} chunk(s) still have empty rows: "
                    + ", ".join(f"chunk {r[0]} ({r[col]} rows)" for r in gaps) + ". Every chunk may still report SUCCEEDED.")
                    + "</p>") if gaps else "<p class=ok>No rows left empty in the range.</p>"
            parts.append("<h2>Rows touched — what the table itself shows</h2>" + note + table(head, body))
    if o.analysis:
        out_lines, in_list = [], False
        for raw in open(o.analysis):
            line = raw.rstrip("\n")
            if line.startswith("- "):
                if not in_list:
                    out_lines.append("<ul>"); in_list = True
                out_lines.append(f"<li>{html.escape(line[2:])}</li>"); continue
            if in_list:
                out_lines.append("</ul>"); in_list = False
            if line.startswith("## "):
                out_lines.append(f"<h3>{html.escape(line[3:])}</h3>")
            elif line.startswith("# "):
                continue
            elif line.strip():
                out_lines.append(f"<p>{html.escape(line)}</p>")
        if in_list:
            out_lines.append("</ul>")
        parts.append("<h2>Issue analysis</h2>" + "".join(out_lines))
    if credits:
        total_c = sum(float(c.get("CREDITS") or 0) for c in credits)
        rows_all = sum(int(r.get("ROWS_AFFECTED") or 0) for r in log if r.get("STATE") == "SUCCEEDED")
        crow = [(c.get("SOURCE"), f"{float(c.get('CREDITS') or 0):,.2f}", c.get("NOTE") or "") for c in credits]
        crow.append(("Total", f"{total_c:,.2f}", f"{total_c / rows_all * 1e6:,.3f} credits per million rows updated" if rows_all else ""))
        parts.append("<h2>Credits</h2>" + table(["Source", "Credits", "Note"], crow))
    css = ("body{font-family:-apple-system,Helvetica,Arial,sans-serif;margin:2em;background:#0d1117;color:#e6edf3}"
           "h1,h2,h3{color:#f0f6fc}p{color:#c9d1d9}"
           "table{border-collapse:collapse;margin:.5em 0 1.5em;background:#0d1117}"
           "td,th{border:1px solid #30363d;padding:4px 10px;text-align:left}"
           "th{background:#161b22;color:#f0f6fc}tr:nth-child(even) td{background:#11161d}li{color:#c9d1d9;margin:.2em 0}"
           ".ok{color:#3fb950}.warn{color:#f0883e;font-weight:bold}")
    title = "Backfill report — " + ", ".join(str(c.get("BACKFILL_NAME")) for c in ctl)
    out = (f"<!doctype html><html><head><meta charset=utf-8><meta name=color-scheme content=dark><title>{html.escape(title)}</title><style>{css}</style></head>"
           f"<body><h1>{html.escape(title)}</h1><p>Generated {dt.datetime.now():%Y-%m-%d %H:%M}. Counts, times and states only.</p>"
           + "".join(parts) + "</body></html>")
    open(o.out, "w").write(out)
    print(o.out)

if __name__ == "__main__":
    main()
