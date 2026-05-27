---
description: Advance the RFL build loop — select the next workable PRD feature(s) and run each via an autonomous headless /goal session (RFL phase 2)
---

Use the rfl:goal-runner skill to read state (prd.json, progress.jsonl,
RFL_JOURNAL.md), reconcile any prior session, and SELECT the next workable
feature. Then, instead of printing the `/goal` line for the user to paste,
DISPATCH it automatically by spawning a headless Claude Code session.

`claude -p "/goal <condition>"` is the documented non-interactive form of /goal:
it runs the goal loop (Stop-hook + evaluator) to completion in a single
invocation, then exits. We use that to keep the independent /goal gate while
removing the manual copy-paste.

## Count argument

`$ARGUMENTS` may contain a single integer N (default 1) = how many features to
build this run. Loop until N features have been dispatched, OR there is no
remaining workable feature, OR a dispatched feature did not record a `pass`.

## Per-feature loop (repeat up to N times)

1. Via the goal-runner skill, select the lowest-id feature whose `depends_on` are
   all `pass` and which has no `pass` entry yet. If none, stop and report ("all
   features passed" or which dependency blocks the next feature).
2. Announce the selected feature id, description, and turn_cap.
3. Write that feature's `goal_condition` string VERBATIM to a temp file
   (e.g. `mktemp`). Do not edit or reformat it. (Writing to a file avoids shell
   quoting problems — the condition contains double quotes and backticks.)
4. From the repo working directory, dispatch the headless goal session:
   ```bash
   claude -p "/goal $(cat "$GOAL_FILE")" \
     --allowedTools "Read,Edit,Write,Bash" \
     --output-format text
   ```
   Stream/show the child's output. The child session does the implementation,
   runs the verification commands, and appends the `progress.jsonl` pass line and
   the RFL_JOURNAL.md success entry itself (those writes are part of the
   goal_condition it is enforcing).
5. After the child exits, run `cat progress.jsonl | tail -1` and confirm it shows
   a `pass` line for this feature id. If it does, count the feature done and
   continue the loop. If it does NOT, STOP the loop and report that the feature
   did not complete (the goal-runner skill will log the fail/skip on its next
   invocation). Do not fabricate a pass.
6. Remove the temp file.

After the loop, report a summary: which feature ids completed this run, and the
next workable feature id (if any).

## Notes

- The child is a full, separately-billed Claude session that inherits your auth.
- It runs with scoped tools (Read, Edit, Write, Bash) and no interactive prompts.
- progress.jsonl is the source of truth for completion — always re-read it after
  each child rather than trusting the child's narration.

$ARGUMENTS
