---
name: workflow-review
description: Review how Daniel actually uses Claude Code — repeated prompts, corrections, CI polling, permission and popup friction, unused skills — compare it with the last review, and return a ranked, verified list of workflow improvements plus Claude Code techniques he isn't using yet. Use when the user types /workflow-review, or asks to "review my usage", "analyze my workflow", "what could I improve", "how am I using Claude", or "redo the usage review".
argument-hint: "[days to look back, default: since last review or 90]"
---

# workflow-review: find what to improve in how I use Claude Code

Measure first, then recommend. Every number comes from the script or a file you read. Every claim about Claude Code features gets checked before it reaches the user.

This skill is **read-only**. Don't build, edit, or commit anything. The output is a list the user picks from.

Snapshots of past reviews live in `~/.claude/state/dl-workflow-review/YYYY-MM-DD.md`.

## 1. Pick the window

- If the user gave a number of days, use it.
- Otherwise, if a past snapshot exists, start at the newest snapshot's date, so this review covers what changed since then.
- Otherwise, use 90 days.

## 2. Measure usage

Run the bundled script (the path is relative to this skill's base directory):

```bash
python3 <base>/scripts/usage-stats.py --since YYYY-MM-DD   # or --days N
```

It prints:
- volume, projects, and slash commands
- first prompts of sessions, repeated prompts, and prompt-pattern counts with an example each
- correction-style prompts
- tool, skill, and subagent counts
- Bash prefixes, CI polling, and `cd X &&` chains
- friction: interrupts, popup rejections, user rejections, hook and classifier blocks

Pattern counts are regex hits. Before you rely on a count, read its example lines and discount the false positives. For example, prompts *about* designing a skill match that skill's pattern.

For deeper digging, like reading the transcripts behind a spike or finding what a correction was about, send a `general-purpose` subagent with a read-only brief and keep only its findings. Transcripts are `~/.claude/projects/*/*.jsonl`. Prompts are `~/.claude/history.jsonl`.

## 3. Inventory the setup (read-only)

- `~/.claude/settings.json` (a symlink into `~/.dotfiles`): permissions, hooks, deny list.
- `~/.claude/settings.local.json` and project `.claude/settings.local.json` files: the allow-rule count, `disabledMcpjsonServers`, and **any secrets written into rules**. Report secrets redacted, never printed.
- `claude plugin list` and `claude plugin details dl@skills-dir`: installed plugins, `dl` skills and hooks.
- `~/.claude/me.md`, `work.md`, and the memory index (`~/.claude/projects/-Users-dlopez/memory/MEMORY.md`).
- `ls -l ~/.claude/skills`: what's personal (`dl`) and what's third-party (links into `~/.agents`).

## 4. Look for techniques he isn't using

Ask the `claude-code-guide` agent what Claude Code features fit this setup that it doesn't use yet (hooks, skills, subagents, permissions, statusline, output styles, background jobs, `/loop`, scheduled routines, headless `claude -p`, and anything new). Give it the inventory from step 3.

**Verify every suggestion before passing it on.** A past report from that agent invented settings keys, CLI subcommands, and hook syntax. Check against `claude --help`, `claude plugin --help`, `claude plugin validate`, or the official docs. Drop anything you can't confirm, and say you dropped it.

## 5. Compare with the last review

If a snapshot exists, read it. Give every item it lists a status:
- **Done**: the fix exists and the numbers moved.
- **Partly done**: say what's left.
- **Still open**: the numbers didn't move.
- **Gone**: the pattern stopped on its own.

New patterns are **New**.

## 6. Report

Lead with one plain sentence: the single biggest time sink right now.

Then a numbered list, ranked by time saved. Each item:
- **The pattern, with counts.** Use this review's numbers, plus the last review's if they exist ("CI polling: 610 → 140 calls").
- **One short example.** Quote no more than a few words of a prompt. No PHI, secrets, names, or record ids.
- **The fix, typed:** a `dl` skill, a `dl` hook, a `me.md` line, a memory, an allowlist rule, or a settings change. Give it 1-2 lines. Respect the standing rules: no commits to `Development`, regular branches not worktrees, and no `terraform apply` without approval.
- **Its status** versus the last review, when there is one.

Then, only if non-empty:
- **Security**: exposed secrets, over-broad permissions. Redacted.
- **Housekeeping**: unused skills, allow-rule sprawl, stale memories.
- **Dropped**: suggestions that failed verification, one line each.

End with a recommendation of which 2-3 items to do next, and offer to build them. Present options as a numbered list in plain text, never the question popup.

## 7. Save the snapshot

Write `~/.claude/state/dl-workflow-review/<today>.md` with a bash heredoc. It holds the window, the key numbers (prompts, sessions, CI polling, popups and rejections, classifier blocks, `cd` chains, the top patterns), and the numbered list with statuses. It's what the next review compares against. No PHI or secrets in it.
