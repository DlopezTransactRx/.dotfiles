#!/usr/bin/env python3
"""Progress-report header: an ASCII-art "Status: <backfill name>" banner, the time the report was generated
(local time zone), then two progress bars.

Rows bar   = rows filled by this backfill / rows it had to fill (the STILL_EMPTY total at kickoff).
Chunks bar = chunks done / total chunks, plus what is running now.

Usage:
  status_header.py --name TRANSACTION_LOG_182 --filled 0 --to-fill 299251880 --chunks-done 0 --chunks 9 \
      [--running "chunk 1 running, 21 min"]
The banner uses figlet (font "small") when it is installed, plain text otherwise. Counts only.
"""
import argparse, datetime as dt, shutil, subprocess

WIDTH = 30

def bar(fraction):
    fraction = max(0.0, min(1.0, fraction))
    full = round(fraction * WIDTH)
    return "[" + "█" * full + "░" * (WIDTH - full) + "]"

def banner(text):
    if shutil.which("figlet"):
        out = subprocess.run(["figlet", "-f", "small", "-w", "200", text], capture_output=True, text=True)
        if out.returncode == 0 and out.stdout.strip():
            return out.stdout.rstrip("\n")
    return text

def main():
    a = argparse.ArgumentParser()
    a.add_argument("--name", required=True, help="registered backfill name, e.g. TRANSACTION_LOG_182")
    a.add_argument("--filled", type=int, required=True, help="rows filled by the backfill so far (BY_BACKFILL total)")
    a.add_argument("--to-fill", type=int, required=True, help="rows the backfill had to fill (STILL_EMPTY total at kickoff)")
    a.add_argument("--chunks-done", type=int, required=True)
    a.add_argument("--chunks", type=int, required=True)
    a.add_argument("--running", default="", help="short note, e.g. \"chunk 2 running, 3 min\"")
    o = a.parse_args()
    rows = o.filled / o.to_fill if o.to_fill else 1.0
    chunks = o.chunks_done / o.chunks if o.chunks else 1.0
    print(banner(f"Status: {o.name}"))
    print(f"Generated: {dt.datetime.now().astimezone().strftime('%Y-%m-%d %-I:%M %p %Z')}")
    print()
    print(f"Rows    {bar(rows)} {100 * rows:5.1f}%   {o.filled:,} / {o.to_fill:,}")
    note = f"  ({o.running})" if o.running else ""
    print(f"Chunks  {bar(chunks)} {o.chunks_done:>3} / {o.chunks}{note}")

if __name__ == "__main__":
    main()
