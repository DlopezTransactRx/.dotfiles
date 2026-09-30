---
name: adversarial-review
description: >
  Run an iterative adversarial code review: spawn N independent reviewer agents
  (blind to each other, default all Claude — the user may swap some for Codex
  agents, and if so must name the specific Codex model to use), verify every
  finding against actual source/git history before touching anything, auto-fix
  what's real, then re-run the whole panel against the updated code. Repeats
  until every agent comes back clean in the same round, or a user-chosen stop
  condition (round count or time budget) is hit. Use when the user asks for
  "adversarial review", "iterative review", "review and fix until clean", or
  wants a repo/diff hammered on by multiple agents until nothing real is left.
---

# Adversarial Review

Multiple independent reviewers hammer on the same code, blind to each other. Every
finding gets verified against actual source (or git history) before it's trusted —
never fixed on an agent's say-so alone. Real findings get fixed immediately, then the
whole panel re-runs against the updated code. Repeat until the panel agrees there's
nothing left, or the user's stop condition is hit.

The value isn't "more eyeballs." It's that agreement between agents is never the bar
for action — verification against source is. Two models can be confidently wrong the
same way; a single agent finding something the others miss is exactly as actionable as
three agreeing, once it's checked. Expect to catch your own mistakes mid-loop too: a
fix applied in round N is fair game for round N+1's reviewers to tear apart, and when
they're right, the fix gets corrected — not defended.

## Step 0 — Ask the setup questions

Before touching anything, ask (a single `AskUserQuestion` call covering all of these):

1. **How many reviewer agents per round?** (2 is the minimum for "independent," but
   there's no fixed cap — more agents costs more tokens/time per round for broader
   coverage.)
2. **Should any of them be Codex instead of Claude?** Default is **all Claude**. If the
   user wants some Codex agents, **they must name the exact Codex model** to use (e.g.
   from `codex --version` / whatever they have configured) — never guess or assert an
   "equivalent" Codex tier for the current Claude model. There is no published
   cross-vendor tier mapping between Anthropic and OpenAI models; asserting one is
   asserting something false. If the user doesn't know which Codex model to name, tell
   them to check (`codex --version`, or their Codex config) and come back — don't
   default silently.
3. **Stop condition**: a fixed number of rounds, or a wall-clock time budget (e.g. "30
   minutes"), whichever the user prefers. Either way, the loop can also end EARLY if
   every agent in a round comes back clean — don't run to the cap if the panel agrees
   first.
4. **Scope**: whole repo, a specific PR/diff, or the working tree's uncommitted
   changes. Same as any code review — confirm before starting.

If Codex agents are in the mix, run the Prerequisites check from the
`code-review-cross-agent` skill's Codex section (`which codex && codex --version`,
`codex login status`) before the first round — a missing/unauthenticated Codex found
mid-loop wastes the whole round. If it can't be made to work, tell the user plainly and
either drop to all-Claude (relabeled honestly, not silently) or stop — never claim a
mixed panel ran when it didn't.

## The loop

Each round:

### 1. Spawn all N agents in parallel, blind to each other

One message, N `Agent` tool calls (or for a Codex agent, the same pattern
`code-review-cross-agent` uses: a subagent that runs `codex review "<harsh prompt>"`
and returns the raw JSON). None of them know the others exist, and none see another's
output — that independence is the entire value of running more than one.

Base prompt (adapt per agent, alternate whether an agent reads CLAUDE.md/README first
or reviews cold and only checks docs afterward — that variance is itself a source of
different blind spots):

```
Review this [whole repository / diff / working tree] as a harsh, senior code reviewer.
Assume the code is wrong until proven right.

Repo root: <path>
Scope: <how to get the diff, or "review the current state under pkg/, cmd/, etc.">

Read surrounding source, not just the diff/files in isolation — check callers, call
ordering, and what changed functions depend on.

Hunt for: correctness bugs, race conditions, security holes, leaked secrets/PHI-in-logs
violations, missing error handling, unhandled edge cases, resource leaks, broken
invariants, and call-order mistakes.

Severity, strict:
- blocking: wrong output, data loss, crash, security hole, broken invariant.
- major: a real defect with a plausible trigger, or a missing guard that will fire.
- minor: true but inconsequential.

For a claimed defect, state the concrete input/state that triggers it. If you cannot
name one, it is minor at most.

Do NOT report: style, naming, formatting, test-coverage gaps, or stale docs/comments
that disagree with the code (unless the stale doc would cause a wrong operational
action).

Do not praise. If you find nothing real, say so explicitly and return an empty list.

Return ONLY a JSON array:
[{"file":"","line":0,"severity":"","what":"","breaks":"","fix":""}]
```

**Every round after the first**, append a running list of what's already settled — real
fixes already applied, and findings already investigated and refuted with the reasoning
why — so agents don't re-litigate the same ground every round. Keep this list accurate
and current; it grows every round.

### 2. Verify every finding yourself before acting

For each finding from each agent, actually read the cited file/line and confirm the
claim against real behavior — grep for the referenced function, check what a library
dependency actually does, check git history/blame if a comment claims something is
"deliberate" or "spec-derived," trace the call path the finding claims exists. Do not
fix anything on an agent's assertion alone.

- **Confirmed real** → fix it immediately (see Step 3). No pause to ask permission
  per-fix — that was the point of choosing this loop over a plain review.
- **Refuted** → say so, with the specific evidence that settles it (a file:line, a git
  commit, a library function's actual behavior). A "no concrete trigger named" finding
  is refuted by the same bar the prompt sets for reporting it in the first place.
- **A finding that critiques a fix you made in an earlier round** — take these
  seriously, not defensively. If the critique is right (a prior fix traded a confirmed
  harm for an unconfirmed one, or introduced its own regression), revert or correct it,
  and log that correction the same way as any other real finding. This is normal and
  expected, not a failure of the process — see "What NOT to report" below for how it
  gets summarized afterward.

### 3. Fix and verify

Apply the fix. Then run the project's actual build/vet/test commands (whatever the
repo uses — `go build && go vet && go test -race ./...`, `npm test`, etc.) before
moving to the next round. Never carry a round forward on an unverified fix.

### 4. Decide whether to continue

- If every agent in this round returned an empty finding list (or every non-empty
  finding was refuted) → **the panel agrees, stop**, even if the round/time cap isn't
  hit yet.
- If the round/time cap is hit first → stop and report where things stand, findings or
  not.
- Otherwise → next round, with the settled-list updated.

## Time-boxing

If the user gave a time budget, track wall-clock elapsed against it as rounds complete
— each round (N agents in parallel, plus verification/fix time) typically runs a few
minutes; don't launch a new round if there's not reasonably enough budget left for it
to finish, and say so when stopping early for that reason.

## Reporting

**During the loop**: after each round, give a short update — what each agent found (or
"clean"), what got verified vs. refuted, what got fixed. Keep it tight; the user is
watching a multi-round process and doesn't need a re-read of the full findings every
time, just the delta.

**At the end**, two different things may be asked for — don't conflate them:

- **"Do the agents agree?"** — answer literally, round by round if useful. Agreement
  happening in the *final* round is the stop condition; it does not imply agreement
  happened in every round, and usually it didn't. Say plainly when a "real" fix came
  from only one agent catching what the other missed.
- **"Summarize the flaws found and fixed"** — this means **pre-existing flaws in the
  code, from the state before the review started, and their fixes.** It does NOT mean
  a round-by-round transcript, and it must exclude:
  - Findings that were refuted (they were never real).
  - **Fixes to your own fixes.** If round 2 corrected something round 1 introduced,
    that whole cycle collapses into nothing for this summary — it was never a flaw in
    the code the user started with, it was churn in the process of getting to the
    final fix. Only the net final state of that area of code, and why it needed
    changing from where it started, belongs in the list.
  - If asked for a 10,000-foot view specifically, keep each item to one line: what was
    wrong, one line on the fix. Save the mechanism/reasoning detail for if they ask.

## What NOT to do

- **Don't skip verification.** An agent's finding is a claim, not a fact, regardless of
  how many agents raised it independently — see the "80+ agents unanimously endorsed a
  non-existent vulnerability" result from real research on this pattern; consensus is
  not correctness.
- **Don't silently degrade a mixed panel to all-Claude** if Codex fails to start —
  say so.
- **Don't guess a Codex "equivalent" model.** Make the user name it.
- **Don't ask for per-fix approval** once the loop has started — that was explicitly
  opted into as an always-auto-fix loop. (If the user didn't opt into that for this
  run, ask up front in Step 0, not mid-loop.)
- **Don't let a critique of your own fix go unaddressed just because it's
  embarrassing.** Revert or correct it exactly like any other verified finding.
- **Don't report intermediate self-corrections as if they were bugs in the original
  code** when summarizing at the end.
