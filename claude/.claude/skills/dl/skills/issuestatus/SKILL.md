---
name: issuestatus
description: Report exactly what is still unmet on a GitHub issue — its own unchecked checkboxes and "Done when" criteria, quoted verbatim and verified against current code and deployed state. Use when the user types /issuestatus, $issuestatus, or issuestatus with an issue number, or asks "what's left on issue N" in the strict, no-inference sense.
argument-hint: "<issue number | owner/repo#N | issue URL>"
---

# issuestatus — What's actually left on an issue

Read the issue fresh. Report only its own unmet items. Verify each against reality. Don't infer, add, merge, or reword scope.

## 1. Fetch it fresh

Don't rely on anything said earlier in the conversation about this issue.

```bash
gh issue view <N> [--repo owner/repo] --json number,title,state,url,body
```

With a bare number, use the current repo. If the current directory isn't a git repo, ask which repo.

Scope is the issue **body** only. Don't use comments, linked issues, or PRs as requirements. You may use them later as evidence.

## 2. Extract, verbatim

- Every **unchecked** checkbox: lines matching `- [ ]` (including nested ones).
- Every criterion under a "Done when" / "Definition of done" / "Acceptance criteria" heading that isn't already a checked box.

Quote each item exactly as written, typos included. Skip checked `- [x]` items. If the body has neither, say so and stop. Don't invent criteria from the prose.

## 3. Verify each one

For each item, find evidence in the **current** state. Use only read-only commands:

- **Code:** grep and read the relevant files on the branch that would ship (say which branch).
- **Merged/shipped:** `gh pr list --search`, `git log`, whether the change is on `Development`/`Production`.
- **Deployed:** CI runs (`gh run list`), `terraform plan` or `state list` (never `apply`), `aws … describe/get/list`, Snowflake `SHOW`/`DESC`.

Give each item one verdict:
- **Unmet**: the evidence shows it's not done.
- **Partly met**: say exactly which part is missing.
- **Met but unchecked**: the evidence shows it's done; the box just isn't ticked.
- **Can't verify**: say what access or information is missing.

## 4. Report

- The header is `#N title (state)` + URL.
- Then a numbered list, one entry per item:
  - The quoted text: `> exact text`
  - The verdict
  - The evidence, as a file:line, commit, PR, or run URL, in one line

End with a one-line count, e.g. "3 unmet, 1 met-but-unchecked, 1 can't verify."

Don't propose extra work, related improvements, or reworded criteria. If something looks missing from the issue itself, add at most one line at the end, flagged as outside the issue's scope.
