---
name: handoff
description: Write a handoff prompt that lets a fresh agent pick up the current work with no other context. Use when the user types /handoff, $handoff, or handoff (or the old /hop, $hop, or hop), or asks for a "handoff prompt", or to "transfer this to another agent/session".
argument-hint: "[who it's for or what to focus on]"
---

# handoff — Handoff prompt

Write one self-contained prompt that a new agent can act on cold. The receiver has not seen this conversation. It may be a subagent or background job that does not load the user's rules. Everything it needs goes in the prompt.

## Gather first (read-only)

Don't write from memory alone. Check the current state:

- `git -C <repo> status --short`, `git -C <repo> branch --show-current`, `git -C <repo> log --oneline -5` for each repo touched
- The issue or PR being worked, if there is one: `gh issue view <N>` / `gh pr view <N>`
- Any CI run still in flight

## Prompt contents, in this order

1. **Goal.** One or two sentences: what is being built or fixed, and why.
2. **Where things are.** The repos with absolute paths, branches, and the issue/PR URL. Say whether changes are committed, pushed, or unstaged.
3. **Done so far.** Facts only, with file paths. What's verified and how (test run, plan output, CI URL).
4. **Left to do.** A numbered list, in order. Mark anything blocked and what it's blocked on.
5. **Decisions already made.** Choices the user settled and must not be reopened, each with a one-line reason.
6. **Rules the receiver must follow.** Copy them in, don't reference them:
   - Don't commit or push unless the user explicitly asks. Leave changes unstaged for review.
   - Work on a regular branch (`feature/dlopez`, or `Development` in `SnowflakeWHAdministration`), not a worktree.
   - No PHI/PII in logs or error strings. Log `eventId` instead.
   - Never run `terraform apply`/`destroy`. Run `plan` and show the output.
   - Infrastructure changes go through Terraform only.
   - Any repo-specific rule from that repo's CLAUDE.md or `Projects/PATTERNS.md` that applies.
7. **Gotchas.** Anything that already bit this session, in one line each.
8. **Done when.** Concrete, checkable finish conditions.

## Output

- Put the prompt in ONE fenced code block so the user can `/copy` it. No commentary inside the block.
- Keep it under ~400 words unless the work genuinely needs more. Point to files instead of pasting them.
- No PHI, secrets, or credentials in the prompt.
- If an argument was given, write the prompt for that audience or focus.
- After the block, one line: what the receiver will do first.
