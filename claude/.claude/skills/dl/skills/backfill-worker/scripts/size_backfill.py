#!/usr/bin/env python3
"""Backfill sizing: per-day volume + a measured speed -> options (warehouse and serverless, one chunk size each)
and ONE recommendation.

A backfill is set and forget: ONE registered backfill, ONE chunk size, ONE compute choice (a named warehouse or
serverless), run to completion. Never split a range into consecutive backfills. Spike days only make the longest
chunk longer.

Input JSON: list of {"D": "YYYY-MM-DD", "ROWS_DAY": int, "BUSIEST_HOUR": int} — rows still to fill per day
(guard-NULL), from a read-only count. Usage:
  size_backfill.py daily.json --rate 44467 --measured-size SMALL --env Production --label "T #1, Production"
      [--max-chunk-min 120] [--overhead-s 10] [--wh-timeout-s 172800] [--serverless-multiplier 0.9]
      [--sizes SMALL,MEDIUM,...]

Warehouse rows: per size, every chunk size (1 HOUR, 1/2/3/7/14/30 DAY) over the calendar-aligned range; keeps the
one that finishes soonest with its longest chunk <= min(--max-chunk-min, half the warehouse statement timeout).
Billed for the whole run (warehouse kept resumed by the one-minute schedule).

Serverless rows: "if Snowflake settles at this size". Only the measured size can be recommended (Snowflake picks
the size); the others are marked (scenario). Same speed as the warehouse of that size, billed only for
run time x the serverless multiplier. The framework starts serverless tasks at XSMALL and Snowflake scales from
there, so the chunk size must also let the longest chunk finish at XSMALL speed within the time limit, which is
capped at the framework's 1440 minutes.

Time limit = 2x the longest chunk, rounded up to 30 min, never above the framework's 1440 min or (warehouse) the
warehouse statement timeout.
"""
import argparse, datetime as dt, json, math

SIZES = [("XSMALL", 1), ("SMALL", 2), ("MEDIUM", 4), ("LARGE", 8), ("XLARGE", 16), ("XXLARGE", 32)]
STEP = 1.8
CHUNKS = [("1 HOUR", None), ("1 DAY", 1), ("2 DAY", 2), ("3 DAY", 3), ("7 DAY", 7), ("14 DAY", 14), ("30 DAY", 30)]
ENV_SIZES = {
    "DEVELOPMENT": ["XSMALL", "SMALL", "MEDIUM", "LARGE"],
    "PRODUCTION": ["SMALL", "MEDIUM", "LARGE", "XLARGE", "XXLARGE"],
}
CHEAP_BAND = 1.25        # Production: fastest option within 25% of the cheapest option's credits
FRAMEWORK_MAX_MIN = 1440  # REGISTER_BACKFILL refuses a longer time limit

def calendar(days):
    """Fill missing dates with zero rows so chunks align to the range start, as the framework's do."""
    by_day = {d["D"]: d for d in days}
    cur, end, out = dt.date.fromisoformat(days[0]["D"]), dt.date.fromisoformat(days[-1]["D"]), []
    while cur <= end:
        k = cur.isoformat()
        out.append(by_day.get(k, {"D": k, "ROWS_DAY": 0, "BUSIEST_HOUR": 0}))
        cur += dt.timedelta(days=1)
    return out

def chunk_rows(days, n):
    """Rows per chunk for one chunk size. n=None means hourly (busiest hour + 23 even hours per day)."""
    if n is None:
        out = []
        for d in days:
            peak, total = d["BUSIEST_HOUR"], d["ROWS_DAY"]
            out += [peak] + [(total - peak) / 23] * 23
        return out
    return [sum(d["ROWS_DAY"] for d in days[i:i + n]) for i in range(0, len(days), n)]

def limit_min(longest_s, ceiling_min):
    return min(ceiling_min, max(60, math.ceil(2 * longest_s / 60 / 30) * 30))

def best_chunk(days, rate, overhead_s, cap_s, xs_rate=None, ceiling_min=FRAMEWORK_MAX_MIN):
    """Soonest-finishing chunk size whose longest chunk fits the cap (and, for serverless, finishes at XSMALL
    speed inside the time-limit ceiling). Returns (best or None, the closest miss)."""
    best, closest = None, None
    for label, n in CHUNKS:
        rows = chunk_rows(days, n)
        runs = [overhead_s + r / rate for r in rows]
        wall = sum(max(60, math.ceil(r / 60) * 60) for r in runs)
        longest = max(runs)
        gate = longest if xs_rate is None else overhead_s + max(rows) / xs_rate  # what the time limit must cover
        cand = {"chunk": label, "chunks": len(runs), "longest": longest, "gate": gate,
                "compute": sum(runs), "wall": wall}
        ok = longest <= cap_s and 2 * gate <= ceiling_min * 60
        if closest is None or cand["gate"] < closest["gate"]:
            closest = cand
        if ok and (best is None or cand["wall"] < best["wall"]):
            best = cand
    if best:
        best["limit"] = limit_min(best["gate"], ceiling_min)
    return best, closest

def fmt_h(s):
    h = s / 3600
    return f"{h:.1f} h" if h < 48 else f"{h/24:.1f} days"

def fmt_min(s):
    if s < 60:
        return f"{s:.0f} s"
    m = s / 60
    return f"{m:.0f} min" if m < 120 else f"{m/60:.1f} h"

def main():
    a = argparse.ArgumentParser()
    a.add_argument("daily"); a.add_argument("--rate", type=float, required=True)
    a.add_argument("--measured-size", required=True)
    a.add_argument("--env", required=True, help="Development or Production (picks the sizes and the recommendation rule)")
    a.add_argument("--max-chunk-min", type=int, default=120, help="longest chunk allowed (minutes)")
    a.add_argument("--overhead-s", type=float, default=10, help="fixed seconds per chunk (measured: small-window CALL time minus rows/rate)")
    a.add_argument("--wh-timeout-s", type=int, default=172800,
                   help="the warehouse's STATEMENT_TIMEOUT_IN_SECONDS (SHOW PARAMETERS ... IN WAREHOUSE); caps warehouse rows")
    a.add_argument("--serverless-multiplier", type=float, default=0.9,
                   help="credits per compute-hour multiplier for serverless tasks (check Snowflake's consumption table)")
    a.add_argument("--sizes", help="comma list overriding the environment's sizes")
    a.add_argument("--label", default="backfill", help="e.g. \"TRANSACTION_LOG #182, Production\"")
    o = a.parse_args()
    env = o.env.upper()
    if env not in ENV_SIZES:
        a.error("--env must be Development or Production")
    names = [s for s, _ in SIZES]
    measured = o.measured_size.upper()
    if measured not in names:
        a.error(f"--measured-size must be one of {', '.join(names)}")
    sizes = [s.strip().upper() for s in o.sizes.split(",")] if o.sizes else ENV_SIZES[env]
    bad = [s for s in sizes if s not in names]
    if bad:
        a.error(f"unknown size(s) {', '.join(bad)}; use {', '.join(names)}")
    days = calendar(json.load(open(o.daily)))
    total = sum(d["ROWS_DAY"] for d in days)
    speed = lambda size: o.rate * STEP ** (names.index(size) - names.index(measured))
    xs_rate = speed("XSMALL")
    wh_ceiling = min(FRAMEWORK_MAX_MIN, o.wh_timeout_s // 60)
    wh_cap = min(o.max_chunk_min * 60, o.wh_timeout_s / 2)

    rows = []
    for mode in ("WAREHOUSE", "SERVERLESS"):
        for size in sizes:
            cph, rate = dict(SIZES)[size], speed(size)
            if mode == "WAREHOUSE":
                best, miss = best_chunk(days, rate, o.overhead_s, wh_cap, ceiling_min=wh_ceiling)
                cost = (lambda b, c=cph: b["wall"] / 3600 * c)
            else:
                best, miss = best_chunk(days, rate, o.overhead_s, o.max_chunk_min * 60, xs_rate=xs_rate)
                cost = (lambda b, c=cph: b["compute"] / 3600 * c * o.serverless_multiplier)
            rows.append({"mode": mode, "size": size, "rate": rate, "best": best, "miss": miss,
                         "credits": cost(best) if best else None})

    # Serverless size is Snowflake's choice, not ours: only the measured size can be recommended; the other
    # serverless rows are "if Snowflake scales up" scenarios.
    fits = [r for r in rows if r["best"] and (r["mode"] == "WAREHOUSE" or r["size"] == measured)]
    rec, why = None, ""
    if fits:
        cheapest = min(fits, key=lambda r: (r["credits"], r["best"]["wall"]))
        if env == "PRODUCTION":
            band = [r for r in fits if r["credits"] <= cheapest["credits"] * CHEAP_BAND]
            rec = min(band, key=lambda r: (r["best"]["wall"], r["credits"]))
            why = (f"fastest option costing no more than {round((CHEAP_BAND - 1) * 100)}% over the cheapest "
                   f"(#{rows.index(cheapest) + 1}, ~{cheapest['credits']:,.0f} credits)")
        else:
            rec = cheapest
            why = "cheapest option (Development: credits over speed)"

    print(f"### Estimated time to complete the full backfill — {o.label}")
    print(f"Range {days[0]['D']} -> {days[-1]['D']} ({len(days)} days), {total:,} rows to fill. "
          f"Based on a measured {o.rate:,.0f} rows/s on {measured}. One backfill, one chunk size, one compute choice "
          "(a warehouse, or serverless), run to completion. Each row is the best chunk size for that choice; pick a number.\n")
    print(f"Average time per row on {measured}: {1e6/o.rate:.1f} µs (≈ {o.rate*60:,.0f} rows per minute).\n")
    print("| # | Compute | Time per row | Chunk size | Chunks | Warehouse timeout | Avg time per chunk | Longest chunk | "
          "Processing time | **Total time to finish** | Credits |")
    print("|---|---|---|---|---|---|---|---|---|---|---|")
    for i, r in enumerate(rows, 1):
        tag = " (measured)" if r["size"] == measured else " (est.)"
        label = (f"Warehouse {r['size']}" if r["mode"] == "WAREHOUSE"
                 else f"Serverless ≈ {r['size']}" + ("" if r["size"] == measured else " (scenario)"))
        mark = " ★" if r is rec else ""
        b = r["best"]
        if b:
            print(f"| {i}{mark} | {label} | {1e6/r['rate']:.1f} µs{tag} | {b['chunk']} | {b['chunks']:,} | "
                  f"{b['limit']} min | {fmt_min(b['compute'] / b['chunks'])} | {fmt_min(b['longest'])} | {fmt_h(b['compute'])} | "
                  f"{fmt_h(b['wall'])} | ~{r['credits']:,.0f} |")
        else:
            m = r["miss"]
            reason = (f"even {m['chunk']} chunks need {fmt_min(m['gate'])} at XSMALL start speed"
                      if r["mode"] == "SERVERLESS" else f"shortest possible is {fmt_min(m['longest'])} ({m['chunk']})")
            print(f"| {i} | {label} | {1e6/r['rate']:.1f} µs{tag} | — | — | ⚠ {reason}, over the timeout | — | — | — | — | — |")
    print()
    if rec:
        b = rec["best"]
        what = f"warehouse {rec['size']}" if rec["mode"] == "WAREHOUSE" else f"serverless (≈ {rec['size']})"
        print(f"**Recommended: #{rows.index(rec) + 1} — {what}, {b['chunk']} chunks, warehouse timeout {b['limit']} min, "
              f"~{fmt_h(b['wall'])}, ~{rec['credits']:,.0f} credits.** Why: {why}.\n")
    else:
        print("**No option fits.** Raise --max-chunk-min or add bigger sizes.\n")
    print("Warehouse timeout = the most one chunk may run before Snowflake stops it (the backfill's time limit per "
          "chunk, set to ~2x the longest chunk); compare it with Avg time per chunk and Longest chunk to see the "
          "headroom. Processing time = time the compute is working. Total time to finish = start to done, including the "
          "one-chunk-per-minute schedule. Longest chunk = the slowest single call (usually the spike day). Warehouse "
          "credits = total time x credits/hour (kept resumed); serverless credits = processing time x credits/hour x "
          f"{o.serverless_multiplier} (verify the serverless-tasks multiplier in Snowflake's consumption table).")
    print(f"Assumptions: ~{STEP}x throughput per size step (not measured; least certain at XLARGE/XXLARGE); chunk "
          f"sizes tried: 1 HOUR, 1/2/3/7/14/30 DAY; longest chunk capped at {o.max_chunk_min} min; {o.overhead_s:.0f} s "
          "fixed cost per chunk; 1 chunk per minute minimum. Warehouse timeout ≤ the warehouse statement timeout "
          f"({o.wh_timeout_s:,} s) and ≤ {FRAMEWORK_MAX_MIN} min. Serverless: Snowflake picks the size (starts at "
          "XSMALL, scales up to the account's SERVERLESS_TASK_MAX_STATEMENT_SIZE), so its speed is not guaranteed — only serverless at the measured size can be recommended, other serverless rows are "
          "scenarios; its "
          f"warehouse timeout covers the longest chunk at XSMALL speed, max {FRAMEWORK_MAX_MIN} min.")

if __name__ == "__main__":
    main()
