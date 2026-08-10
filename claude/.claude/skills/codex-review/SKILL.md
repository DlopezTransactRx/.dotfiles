---
name: codex-review
description: Use when the user wants a second-opinion code review of their current uncommitted/staged git changes OR of a GitHub pull request, asks to "run codex review", pastes a PR URL for review, wants Codex to critique a diff, or wants an adversarial quality check before committing or merging.
---

# Codex Review

## Overview

Review a diff with **two independent reviewers** — a Claude subagent and the Codex CLI — then adjudicate their findings against the real source before showing the user anything. Two models have different blind spots. One model reviewing alone passes its blind spots straight through.

Two modes, one review engine:

- **Working-tree mode** (default) — reviews staged + unstaged + untracked changes.
- **PR mode** — triggered when the user supplies a pull request. Same engine, plus the user can post chosen findings back to the PR as inline review comments.

The engine (Phases A–C) is identical in both modes. Only the diff setup and the posting step differ.

## Prerequisites

- `codex` installed (`which codex`) and authenticated (`codex login status`). If not authenticated, tell the user to run `codex login` themselves — do not attempt it.
- PR mode also needs `gh` installed and authenticated (`gh auth status`). Same rule: the user runs `gh auth login`.

---

# The review engine

## Phase A — Two reviewers, in parallel, blind to each other

Spawn **both** in a single message so they run concurrently. Set `run_in_background: false` on both — their results are needed before anything else happens. Neither reviewer is told the other exists, and neither sees the other's output. That independence is the entire value; do not summarize one into the other's prompt.

### Reviewer 1 — Claude subagent

`subagent_type: general-purpose`. Prompt it with:

```
Review this diff as a harsh, senior code reviewer. Assume the code is wrong until proven right.

Diff scope: <how to get it — e.g. `git diff --cached` in <dir>, or `gh pr diff <pr>`>
Repo root: <path>

Read the surrounding source, not just the diff. A change can be correct in isolation and
broken in context — check callers, call ordering, and what the changed function depends on.

Hunt for: correctness bugs, race conditions, security holes, leaked secrets, missing error
handling, unhandled edge cases, resource leaks, broken invariants, and call-order mistakes.

For each issue return: file, line, severity (blocking/major/minor), what the code does,
what breaks, and a concrete fix. Do not praise. Do not report style preferences.
If you find nothing real, say so explicitly and return an empty list.

Return ONLY a JSON array:
[{"file":"","line":0,"severity":"","what":"","breaks":"","fix":""}]
```

### Reviewer 2 — Codex subagent

`subagent_type: general-purpose`. It runs the CLI and returns the raw findings:

```
Run this exact command from <repo root or worktree path> and return its findings verbatim
as JSON. Do not add findings of your own. Do not evaluate them.

codex review "You are a harsh, senior code reviewer. Assume the code is wrong until proven right. Find correctness bugs, race conditions, security holes, leaked secrets, missing error handling, unhandled edge cases, resource leaks, and broken invariants. For each issue give file:line, severity (blocking/major/minor), and a concrete fix. Do not praise. If you find nothing critical, say so explicitly."

It may take a minute. Let it finish.

Return ONLY a JSON array:
[{"file":"","line":0,"severity":"","what":"","breaks":"","fix":""}]
Empty array if it found nothing.
```

### The Codex flag conflict (verified on codex-cli 0.147.0)

`--uncommitted`, `--base`, and `--commit` are each **mutually exclusive with a custom `[PROMPT]`**. These all error out:

```
codex review --uncommitted "<prompt>"     # error: cannot be used with [PROMPT]
codex review --base main "<prompt>"       # error: cannot be used with [PROMPT]
```

A bare prompt is allowed and defaults to reviewing **uncommitted** changes:

```bash
codex review "<prompt>"     # works — reviews staged + unstaged + untracked
```

So the harsh prompt only works against uncommitted changes. To review anything else, make that diff *appear* uncommitted first (see PR mode Step 3). Never drop the prompt just to use a scope flag — the default review is far weaker.

## Phase B — Cross-examination

**The critique of a finding must come from the model that did not produce it.** A Claude finding checked by a Claude verifier shares the reviewer's blind spots — if Claude is confidently wrong, a Claude refuter is likely wrong the same way. Cross-model is the whole point.

### The one-exchange rule

Each agent critiques **only the other's findings**, exactly once. No agent sees critique of its own work. There is no rebuttal round and no back-and-forth.

This is deliberate. Once a model sees its own findings challenged, it either capitulates to whatever the other said or digs in to defend. Either way you stop measuring "is this bug real" and start measuring who argued harder, and agreement between them stops being evidence.

When building the cross-examination prompts, **strip all authorship**. Do not say the claims came from another reviewer, another model, or a previous pass. Present them as bare claims to be refuted. Attribution invites deference.

**1. Match up the two lists first.** Two findings are the same issue when they point at the same root cause — same file, lines within about five of each other, same underlying defect. Different wording does not make them different findings. Merge matched pairs and keep the clearer explanation. Matched findings skip cross-examination — neither model can independently attack a claim it made itself — but still get verified against source in step 3.

**2. Cross-examine, both directions in parallel.** Spawn both in one message.

- **Codex agent** gets Claude's unmatched findings.
- **Claude agent** gets Codex's unmatched findings.

If one list is empty, that direction is a no-op — skip it and say so. An empty Codex list is common; it means half the exchange does nothing, which is fine.

Prompt for both directions:

```
Try to REFUTE each of these claimed bugs. Default to refuted=true if you are not certain a
claim is real. You are looking for reasons each claim is WRONG.

Repo: <path>
Claims:
<numbered list of findings — file, line, what, breaks, fix — with NO attribution>

For each claim, read the actual source and every relevant caller before deciding. Check call
ordering — a guard that looks missing is often enforced earlier by a caller. Check whether the
input is actually reachable and actually untrusted. Check whether the failure path the claim
describes can really be entered.

Cite the specific file and line that settles it. A verdict with no source citation is not a
verdict.

Return ONLY a JSON array, one entry per claim, in the same order:
[{"claim":1,"refuted":true|false,"reason":"one or two sentences","evidence":"file:line","confidence":"high|medium|low"}]
```

For a Codex-run cross-examination, the subagent pipes this prompt to `codex exec` rather than `codex review` — the claims are the input, not a diff.

**3. Verify what survives against source.** The parent does this itself. For every finding still standing — matched or not-refuted — confirm the cited `file:line` exists and the described code actually behaves that way. Two models agreeing does not make a claim true.

**4. Apply the verdicts:**

- Refuted with high or medium confidence, and the evidence citation checks out → **drop it**. Do not show the user refuted findings.
- Not refuted, and it survives step 3 → **keep it**.
- Refuted with low confidence, or refuted with no usable evidence citation, or the two models flatly disagree and the parent cannot settle it from source → **spawn one tiebreaker agent** on that single claim. Use the opposite model from whichever last touched it.
- Still unsettled after the tiebreaker → **unresolved**. Its own section, never the main list, never postable.

**5. Sort what survives** blocking → major → minor.

Why step 2 exists, from a real run: Codex flagged `guard.go` for interpolating env vars into SQL before validation. Structurally true, but not a vulnerability — the caller validated those identifiers one function earlier, at connection setup. Only reading the call order caught it, and it took the *other* model to look.

### Confidence tags for Phase C

Track how each surviving finding earned its place. Phase C prints this as the commentary line:

- Both reviewers raised it independently → `Both reviewers flagged this.`
- One raised it, the other model tried to refute and failed → `Raised by one reviewer; the other tried to refute it and couldn't.`
- One raised it, the other's list was empty so no cross-check ran → `Raised by one reviewer. No cross-check was possible — the other reviewer returned nothing. Weigh on the verification, not consensus.`

## Phase C — Present

One consolidated numbered list. Not two lists. Never "Claude said X, Codex said Y."

```
1. [blocking] pkg/kafka/consumer.go:212
   The code tells Kafka "done with this record" before it saves the record to S3.
   If the save fails, the record is gone for good — Kafka won't send it again.
   Save first, then tell Kafka it's done.
   → Both reviewers flagged this.
```

Write for someone smart who has not read this code. Three short sentences, in this order:

1. **What the code does** — everyday words, no jargon.
2. **What goes wrong** — the actual bad outcome. Lost data, crash, wrong answer, someone gets in who shouldn't.
3. **What to do instead** — one concrete change.

Hard rules on the wording:

- Short sentences. One idea each. No stacked clauses.
- Everyday words. If a technical term is truly unavoidable, define it inline the first time, then use it.
- Never assume the reader knows the function, the library, or the pattern. Say what it does, don't just name it.
- No hedging ("might", "could potentially", "consider possibly"). A real caveat gets one sentence.
- No praise, no preamble. Don't restate the severity in prose.
- No architecture essays. State the breakage and move on.

**The commentary line.** Every finding ends with one, carrying the Phase B confidence tag, so the user can weigh it:

- `→ Both reviewers flagged this.` — highest confidence.
- `→ Raised by one reviewer; the other tried to refute it and couldn't.` — survived cross-examination.
- `→ Raised by one reviewer. No cross-check was possible — the other reviewer returned nothing. Weigh on the verification, not consensus.` — weakest. Say this plainly; never let a single-source finding read as consensus.

**The unresolved section.** Below the main list, separate heading, never numbered into it:

```
Unresolved — could not confirm or rule out:
- pkg/mpi/feeder.go:88 — <plain-language claim>. <Why it couldn't be settled.>
```

These are not actionable and must never be offered for posting to a PR.

**When nothing survives.** Say exactly that: how many each reviewer raised, and one plain sentence per dropped finding on why it didn't hold. Do not pad it into looking like a real review.

**On repeat runs.** Both reviewers are nondeterministic — the same diff can yield different findings run to run. A clean result means "neither reviewer spotted anything this time," not "this code is verified safe." Say so when reporting a clean run.

---

# Mode 1 — Working tree (no PR given)

1. Confirm there are changes: `git status --short`. Clean tree → stop, say there is nothing to review.
2. Run the engine from the repo root. Reviewer 1 gets `git diff HEAD` as its scope; Reviewer 2 runs `codex review "<prompt>"` bare (no scope flag).
3. Present per Phase C. Do not auto-fix.

---

# Mode 2 — Pull request

Triggered by a PR URL (`https://github.com/owner/repo/pull/123`), a bare `#123`, or `owner/repo#123`.

## Step 1 — Resolve the PR

```bash
gh pr view <pr> --json number,title,url,baseRefName,headRefOid,headRepositoryOwner,headRepository,changedFiles,files
```

Capture `owner`, `repo`, `number`, `baseRefName`, and `changedFiles`. Say out loud which PR is about to be reviewed before doing any work.

## Step 2 — Isolated worktree

Never `gh pr checkout` in the user's working tree — it switches their branch. Always use a throwaway worktree in the scratchpad.

If the current directory is the PR's repo:

```bash
git fetch origin "pull/<N>/head:_codex_pr_<N>"
git fetch origin "<baseRefName>"
git worktree add <scratchpad>/pr-<N> _codex_pr_<N>
```

If the current directory is a different repo, or not a repo:

```bash
gh repo clone <owner>/<repo> <scratchpad>/repo-<N> -- --no-single-branch
# then the same fetch + worktree steps inside that clone
```

## Step 3 — Make the PR diff look uncommitted

`--base` cannot take the harsh prompt. Instead, soft-reset the worktree to the merge-base: `HEAD` moves back to the base commit while the files stay at the PR's content, so the whole PR diff shows up as **staged** — exactly what a bare `codex review` reads.

```bash
MB=$(git merge-base origin/<baseRefName> HEAD)
git reset --soft "$MB"
git diff --cached --stat | tail -1      # sanity check
```

Confirm that file count matches `changedFiles` from Step 1. If it doesn't, stop and investigate — you are about to review the wrong diff.

Use the merge-base, not `origin/<baseRefName>` directly. If the base branch moved after the PR opened, resetting to the tip folds unrelated commits into the review.

The soft reset only touches the throwaway worktree. The user's repo is untouched.

## Step 4 — Run the engine

Phases A–C, pointed at the worktree. Both reviewers get the worktree path. Reviewer 1's diff scope is `git diff --cached` there.

## Step 5 — Clean up (always)

Even if a reviewer fails or the user aborts:

```bash
git worktree remove --force <scratchpad>/pr-<N>
git branch -D _codex_pr_<N>
```

Leave the scratchpad clone; it is session-scoped and harmless.

## Step 6 — Let the user choose

After presenting the numbered list, ask which numbers to post. Accept `1, 4, 7`, ranges, `all`, or `none`. Only main-list findings are eligible — never anything from the unresolved section.

## Step 7 — Confirm, then post

1. Show the exact comment bodies about to be posted, each mapped to its `file:line`.
2. Get an explicit yes. Posting is outward-facing — never skip this, never post on your own initiative.
3. Submit as **one** review:

```bash
cat > <scratchpad>/review-<N>.json <<'JSON'
{
  "event": "COMMENT",
  "body": "<summary + any unanchorable findings>",
  "comments": [
    { "path": "pkg/kafka/consumer.go", "line": 212, "side": "RIGHT", "body": "..." }
  ]
}
JSON

gh api "repos/<owner>/<repo>/pulls/<N>/reviews" --input <scratchpad>/review-<N>.json
```

4. Report the review URL back to the user.

### Lines that are not in the diff

GitHub rejects (422) an inline comment whose line is not part of the PR's diff. A real bug in untouched code cannot be anchored.

Do not drop it. Fold it into the review's top-level `body` as `file:line — <comment>`, and tell the user which findings landed there instead of inline.

Check anchorable lines before posting with `gh pr diff <pr>`. Only `+` lines and context lines inside a hunk work, on `side=RIGHT`.

### Hard limits

- Never `event=APPROVE` or `event=REQUEST_CHANGES`. `COMMENT` only.
- Never push, never commit, never edit files in the PR.
- Never post without the confirmation in Step 7.2.
- Never post an unresolved finding.

---

## Sensitive data caution

Both modes send a full diff to an external model. If the changes include credentials, keys, `.env` files, or AWS exports, flag it to the user and confirm before running.

## Quick reference

| Goal | Command |
|------|---------|
| Codex on uncommitted changes (with prompt) | `codex review "<prompt>"` |
| Codex on a PR or any base (with prompt) | `git reset --soft $(git merge-base <base> HEAD)` then `codex review "<prompt>"` |
| Scope flags — **prompt not allowed** | `codex review --uncommitted` / `--base <b>` / `--commit <sha>` |
| PR metadata | `gh pr view <pr> --json number,baseRefName,changedFiles` |
| PR diff (to check anchorable lines) | `gh pr diff <pr>` |
| Post the review | `gh api repos/O/R/pulls/N/reviews --input <file>.json` |
| Check auth | `codex login status` / `gh auth status` |

## Common mistakes

- **Running only one reviewer.** Both, always, in parallel and blind to each other. One reviewer's blind spots go straight to the user.
- **Letting the reviewers see each other's output.** Destroys the independence the whole method depends on.
- **Delegating the final call.** Subagents verify individual claims; the parent decides what ships.
- **Trusting "both flagged it" without checking.** Two models can be wrong the same way. Verify against source regardless.
- **Refuting a model's findings with the same model.** Shared blind spots — the check is worthless. Cross-model or it doesn't count.
- **Telling a cross-examiner where the claims came from.** Attribution invites deference. Present bare claims.
- **Letting the exchange turn into a debate.** One direction each, once. A rebuttal round measures which model argues harder, not which is right.
- **Skipping the cross-examination on single-source findings.** That's where false positives live.
- **Accepting a refutation with no evidence citation.** A verdict without a `file:line` that settles it is a guess — send it to a tiebreaker.
- **Printing a single-source finding as if it were consensus.** Say plainly when no cross-check was possible.
- **Showing refuted findings anyway**, hedged. Drop them, or put them in unresolved. No middle ground.
- **Presenting two lists.** One consolidated list, deduplicated.
- **Combining a scope flag with the Codex prompt.** Both error out. Bare prompt only; reshape the diff instead.
- **Dropping the prompt to keep `--base`.** The default review is much weaker.
- **Resetting to the base branch tip instead of the merge-base.** Pulls in unrelated commits.
- **`gh pr checkout` in the user's tree.** Switches their branch and can stomp in-progress work.
- **Writing findings for an expert.** Three short sentences: what the code does, what breaks, what to change.
- **Leaving the worktree behind.** Clean up on every path, including failure.
- **Auto-applying fixes.** This skill reviews only.
