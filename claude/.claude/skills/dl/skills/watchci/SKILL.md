---
name: watchci
description: Watch the GitHub Actions CI run on a branch's newest commit, open the finished run in the browser, and summarize what changed in plain words. Use when the user types /watchci <branch> (Dev and Prod are shorthand), or says "I merged it, watch CI", "watch the CI on Development/Production", or "what's CI doing on <branch>". Also called by dl:promote.
argument-hint: "<branch: Dev | Prod | Development | Production | any branch>"
---

# watchci: watch CI, open it, summarize the changes

Read-only. This skill never commits, pushes, merges, or creates PRs.

The script is `~/.claude/skills/dl/scripts/ci.sh`. Run it from the repo root.

## Steps

1. **Branch.** If no branch was given, ask for one. `Dev` means `Development` and `Prod` means `Production`, in any case. Any other name is used as-is.
2. **Watch.** Run `~/.claude/skills/dl/scripts/ci.sh watch <branch>` in ONE Bash call with `run_in_background: true` and a 30-minute timeout. Wait for the completion notification. Don't poll with `gh run list`, `gh run view`, or `sleep` loops yourself.

   The script watches the newest commit on `origin/<branch>`. After a merge, that's the merge commit. The script opens the browser itself with `open`: only the failed runs if any failed, otherwise only the run that finished last. Prechecks that passed are not opened. Don't open anything again.
3. **Read the result.**
   - Exit 0: CI passed.
   - Exit 1: CI failed. The output includes the failed jobs' log tails.
   - Exit 3 (`NO_RUNS`): no CI started for that commit. Say so plainly.

## Report

Keep it short and plain. No headers.

1. One line: branch, short sha, pass/fail, which workflows ran, and how long they took.
2. **What changed**: from the `--- changes ---` section, one plain-words line per change. Say what it does, not the commit wording. Merge PRs whose commits say the same thing. No PHI, secrets, or record ids.
3. **On failure**: the root cause in 3 lines or fewer, quoting the key error line from the log. Don't start fixing anything unless the user asks.

When dl:promote calls this skill, return the result to promote's flow instead of ending the turn.
