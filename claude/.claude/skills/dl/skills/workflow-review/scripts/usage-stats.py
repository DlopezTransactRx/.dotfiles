#!/usr/bin/env python3
"""Count how Claude Code actually gets used, for the dl:workflow-review skill.

Reads ~/.claude/history.jsonl (every typed prompt) and the session transcripts
under ~/.claude/projects/ (tool calls, skills, rejections). Read-only.

    usage-stats.py [--days N | --since YYYY-MM-DD]

Prints plain-text sections the skill turns into a ranked review. Prompt samples
are truncated; the skill must still keep PHI, secrets, and names out of its report.
"""
import argparse
import collections
import datetime as dt
import glob
import json
import os
import re
import statistics

HOME = os.path.expanduser("~")
HISTORY = os.path.join(HOME, ".claude", "history.jsonl")
TRANSCRIPTS = os.path.join(HOME, ".claude", "projects", "*", "*.jsonl")
PROJECTS_PREFIX = os.path.join(HOME, "Documents", "Development", "Projects") + "/"

# Prompt patterns worth counting. Grouped so near-duplicates land together.
PATTERNS = {
    "watch/summarize CI": r"watch (the )?(ci|deploy|build|action)|summari[sz]e (the )?(ci|run)|why did (this|it|ci) fail",
    "pasted Actions run URL": r"github\.com/.+/actions/runs",
    "open PR/issue/run in browser": r"open .*(browser|browswer|browsr)|\bopen (the )?(pr|issue|ci|action|run)\b",
    "commit / push by hand": r"\bcommit( it| this| the)?\b|\bpush( it| this)?\b",
    "don't commit / let me review": r"(don'?t|do not|dont) (commit|push)|unstaged",
    "dev to prod / promote": r"dev(elopment)? (to|->|→) prod|\bpromote\b",
    "merged, watch CI": r"merged.*(watch|ci)",
    "shorter / simpler answer": r"10ke|simple terms|no nonsense|simply explain|too long|tl;?dr|\bshorter\b",
    "didn't understand / yes or no": r"i don'?t understand|yes or no|\bconfused\b",
    "where did you get / don't infer": r"where did you get|do not infer|don'?t infer|why did you add|verbatim",
    "punch list / item N": r"punch ?list|\bitem [0-9]+\b",
    "log this (Obsidian)": r"\blog (this|it|that)\b|obsidian",
    "handoff": r"\bhand ?off\b|\$?hop\b",
    "worktree complaints": r"worktree|i don'?t see (the|my) changes",
    "try again / again": r"\btry again\b|\bagain\b",
    "what time/day is it": r"what (time|day|date) is it",
    "login / expired": r"sso login|^/login|expired",
    "PHI / PII": r"\bphi\b|\bpii\b",
}

# `cd X && ` / `cd "X"; ` in front of a command, repeated.
CD_PREFIX = re.compile(r"""^(cd\s+("[^"]*"|'[^']*'|\S+)\s*(&&|;)\s*)+""")

CORRECTION = re.compile(
    r"^(no\b|nope|wrong|stop\b)|that'?s (wrong|not)|\bi said\b|\bi told you|why did you|why are you"
    r"|not what i|you (didn'?t|did not|missed|forgot)|\bundo\b|\brevert\b|i asked|\bdidn'?t ask"
    r"|without asking|you were supposed|do not infer|don'?t infer"
)


def norm(text, width=80):
    text = re.sub(r"[0-9]+", "N", text.strip().lower())
    return re.sub(r"\s+", " ", text)[:width]


def short(text, width=140):
    return re.sub(r"\s+", " ", text.strip())[:width]


def project_name(path):
    if not path:
        return "(none)"
    if path.startswith(PROJECTS_PREFIX):
        return path[len(PROJECTS_PREFIX):]
    return path.replace(HOME, "~")


def load_history(cutoff_ms):
    rows = []
    with open(HISTORY) as fh:
        for line in fh:
            try:
                row = json.loads(line)
            except ValueError:
                continue
            if row.get("timestamp", 0) >= cutoff_ms and isinstance(row.get("display"), str):
                rows.append(row)
    return rows


def section(title):
    print(f"\n## {title}")


def report_history(rows):
    section("Volume")
    sessions = collections.defaultdict(list)
    for row in rows:
        sessions[row.get("sessionId", "none")].append(row)
    lengths = [len(v) for v in sessions.values()] or [0]
    days = collections.Counter(dt.datetime.fromtimestamp(r["timestamp"] / 1000).date() for r in rows)
    print(f"prompts {len(rows)}, sessions {len(sessions)}, active days {len(days)}")
    print(f"prompts/session median {statistics.median(lengths)}, max {max(lengths)}; "
          f"1-prompt sessions {sum(1 for n in lengths if n == 1)}, 30+ prompt sessions {sum(1 for n in lengths if n >= 30)}")
    weeks = collections.Counter(dt.datetime.fromtimestamp(r["timestamp"] / 1000).strftime("%G-W%V") for r in rows)
    print("prompts per week: " + ", ".join(f"{k} {v}" for k, v in sorted(weeks.items())))

    section("Prompts by project (top 15)")
    for name, count in collections.Counter(project_name(r.get("project")) for r in rows).most_common(15):
        print(f"{count:5}  {name}")

    section("Slash commands typed (top 30)")
    slash = collections.Counter(r["display"].split()[0] for r in rows if r["display"].startswith("/"))
    for name, count in slash.most_common(30):
        print(f"{count:5}  {name}")

    section("First prompt of a session (top 10)")
    first = collections.Counter(norm(v[0]["display"], 50) for v in sessions.values())
    for text, count in first.most_common(10):
        print(f"{count:5}  {text}")

    section("Repeated prompts, near-duplicates grouped (count >= 3, top 40)")
    typed = [r for r in rows if not r["display"].startswith("/")]
    for text, count in collections.Counter(norm(r["display"]) for r in typed).most_common(40):
        if count >= 3:
            print(f"{count:5}  {text}")

    section("Prompt patterns")
    for label, pattern in PATTERNS.items():
        hits = [r for r in rows if re.search(pattern, r["display"].lower())]
        if hits:
            print(f"{len(hits):5}  {label}   e.g. \"{short(hits[-1]['display'], 90)}\"")

    section("Correction-style prompts (regex; includes false positives), latest 25")
    fixes = [r for r in typed if CORRECTION.search(r["display"].lower())]
    print(f"total {len(fixes)}")
    for row in fixes[-25:]:
        print(f"  - [{project_name(row.get('project'))}] {short(row['display'])}")


def report_transcripts(cutoff_iso):
    tools = collections.Counter()
    skills = collections.Counter()
    agents = collections.Counter()
    bash = collections.Counter()
    polling = collections.Counter()
    cd_chains = background = interrupts = 0
    user_rejected = collections.Counter()
    classifier_blocked = collections.Counter()
    hook_blocked = 0
    ask_ids, ask_rejected = set(), 0
    files = 0

    for path in glob.glob(TRANSCRIPTS):
        files += 1
        with open(path) as fh:
            for line in fh:
                try:
                    entry = json.loads(line)
                except ValueError:
                    continue
                if entry.get("timestamp", "")[:10] < cutoff_iso:
                    continue
                content = (entry.get("message") or {}).get("content")
                if entry.get("type") == "assistant" and isinstance(content, list):
                    for block in content:
                        if block.get("type") != "tool_use":
                            continue
                        name, args = block.get("name", "?"), block.get("input") or {}
                        tools[name] += 1
                        if name == "Skill":
                            skills[args.get("skill", "?")] += 1
                        elif name in ("Agent", "Task"):
                            agents[args.get("subagent_type", "default")] += 1
                        elif name == "AskUserQuestion":
                            ask_ids.add(block.get("id"))
                        elif name == "Bash":
                            cmd = args.get("command", "").strip()
                            if CD_PREFIX.match(cmd):
                                cd_chains += 1
                            # Count the real command, not the `cd X &&` in front of it.
                            words = CD_PREFIX.sub("", cmd).split()
                            head = words[0] if words else ""
                            key = " ".join(words[:2]) if head in ("git", "gh", "aws", "terraform", "snow", "snowsql", "go", "brew", "docker", "python3", "jq", "claude") else head
                            bash[key] += 1
                            if args.get("run_in_background"):
                                background += 1
                            for probe in ("gh run view", "gh run list", "gh run watch", "sleep "):
                                if probe in cmd:
                                    polling[probe.strip()] += 1
                if entry.get("type") == "user":
                    blocks = content if isinstance(content, list) else [{"type": "text", "text": content or ""}]
                    for block in blocks:
                        if block.get("type") == "text" and "Request interrupted" in (block.get("text") or ""):
                            interrupts += 1
                        if block.get("type") != "tool_result" or not block.get("is_error"):
                            continue
                        text = block.get("content")
                        text = text if isinstance(text, str) else json.dumps(text)
                        if block.get("tool_use_id") in ask_ids:
                            ask_rejected += 1
                        if "auto mode classifier" in text:
                            reason = re.search(r"Reason: \[([^\]]+)\]", text)
                            classifier_blocked[reason.group(1) if reason else "?"] += 1
                        elif "hook" in text.lower() and ("denied" in text.lower() or "blocked" in text.lower()):
                            hook_blocked += 1
                        elif "doesn't want to proceed" in text or "rejected" in text.lower():
                            user_rejected[text[:40]] += 1

    section("Tool calls (transcripts)")
    print(f"transcript files scanned {files}")
    print(", ".join(f"{k} {v}" for k, v in tools.most_common(20)))
    section("Skills invoked")
    print(", ".join(f"{k} {v}" for k, v in skills.most_common()) or "(none)")
    section("Subagents launched")
    print(", ".join(f"{k} {v}" for k, v in agents.most_common()) or "(none)")
    section("Bash commands by prefix (top 30)")
    total_bash = sum(bash.values()) or 1
    for key, count in bash.most_common(30):
        print(f"{count:5}  {key}")
    print(f"CI polling: {dict(polling)} = {sum(polling.values())} of {total_bash} Bash calls")
    print(f"'cd X &&' chains {cd_chains}; background Bash calls {background}")
    section("Friction")
    print(f"interrupts {interrupts}")
    print(f"AskUserQuestion popups {len(ask_ids)}, rejected {ask_rejected}")
    print(f"user-rejected tool calls {sum(user_rejected.values())}")
    print(f"hook-blocked tool calls {hook_blocked}")
    print(f"auto-mode classifier blocks {sum(classifier_blocked.values())}: "
          + ", ".join(f"{k} {v}" for k, v in classifier_blocked.most_common()))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--days", type=int, default=90)
    parser.add_argument("--since", help="YYYY-MM-DD; overrides --days")
    opts = parser.parse_args()
    start = dt.datetime.strptime(opts.since, "%Y-%m-%d") if opts.since else dt.datetime.now() - dt.timedelta(days=opts.days)
    print(f"# Claude Code usage since {start.date()} (today {dt.date.today()})")
    report_history(load_history(start.timestamp() * 1000))
    report_transcripts(start.strftime("%Y-%m-%d"))


if __name__ == "__main__":
    main()
