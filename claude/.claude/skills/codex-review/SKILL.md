---
name: codex-review
description: Use when the user wants a second-opinion code review of their current uncommitted/staged git changes, asks to "run codex review", wants Codex to critique a diff, or wants an adversarial quality check before committing.
---

# Codex Review

## Overview

Run the **Codex CLI** (`codex`, an independent AI coding agent) as a harshly critical second reviewer of the current working-tree changes, then triage its findings against the real diff before presenting them. A second model catches what the author and the primary agent miss.

## Prerequisites

- `codex` must be installed (`which codex`) and authenticated (`codex login status`). If not authenticated, tell the user to run `codex login` themselves — do not attempt it.

## The command

Run exactly this — do NOT hand-roll a `codex exec` prompt or guess flags. `codex review` is purpose-built for diffs and `--uncommitted` scopes it to staged + unstaged + untracked changes:

```bash
codex review --uncommitted "You are a harsh, senior code reviewer. Assume the code is wrong until proven right. Find correctness bugs, race conditions, security holes, leaked secrets, missing error handling, unhandled edge cases, resource leaks, and broken invariants. For each issue give file:line, severity (blocking/major/minor), and a concrete fix. Do not praise. If you find nothing critical, say so explicitly."
```

- First, confirm there are changes: `git status --short`. If the tree is clean, stop and tell the user there is nothing to review.
- Run from the repo root. Let the command finish; it may take a minute.

## Triage protocol (do NOT blindly relay)

Codex is a second model, not ground truth. After it runs:

1. **Verify** each finding against `git diff` — confirm the cited file:line actually exists and the claim is real. Drop hallucinated line refs and false positives.
2. **Deduplicate** overlapping findings.
3. **Prioritize** by severity: blocking bugs and security issues first, then major, then minor/style.
4. **Present** a vetted list: severity, `file:line`, the problem, the suggested fix. Note which findings you could not confirm.

Do not auto-fix anything. Surface the issues; let the user decide.

## Sensitive data caution

`--uncommitted` sends the full working-tree diff to an external model. If the changes include credentials, keys, `.env`, or AWS exports, flag this to the user and confirm before running.

## Quick reference

| Goal | Command |
|------|---------|
| Review all uncommitted changes (default) | `codex review --uncommitted "<critical prompt>"` |
| Review vs a base branch | `codex review --base <branch> "<critical prompt>"` |
| Review a specific commit | `codex review --commit <sha> "<critical prompt>"` |
| Check auth | `codex login status` |

## Common mistakes

- **Guessing the command** (`codex exec review`, `--ask-for-approval never`). Use `codex review --uncommitted` — verified.
- **Relaying Codex output verbatim.** Always verify against the diff first.
- **Running on a clean tree.** Check `git status --short` first.
- **Auto-applying fixes.** This skill reviews only.
