---
name: promote
description: Ship work up a level. "/promote Dev" commits the user's changes on feature/dlopez, pushes, watches CI, and on success opens a PR to Development. "/promote Prod" only creates the Development → Production PR and opens it for the user to merge. Run ONLY when the user explicitly types /promote or asks to promote to Dev/Development or Prod/Production — never on your own, never because work looks finished.
argument-hint: "<Dev | Prod>"
---

# promote: ship to Development or Production

The script is `~/.claude/skills/dl/scripts/ci.sh`. Run it from the repo root.

**Never commit directly to `Development` or `Production`.** Changes reach `Development` only through a PR from `feature/dlopez`. `Production` only gets a PR from `Development`. Never force-push, never merge.

Normalize the argument with `ci.sh branch-name <arg>`. `Dev` means `Development` and `Prod` means `Production`. With no argument, or any other value, ask which.

## /promote Development

This is the only mode that commits.

1. **Check.** `ci.sh dev-check`. On exit 4, the SnowflakeWHAdministration flow is unsettled: stop and ask the user how that repo promotes. On any other error, report it and stop.
2. **Branch.** `ci.sh work-branch` switches to `feature/dlopez`, carrying the uncommitted changes. If git refuses because of a conflict, stop and report it.
3. **Stage.** Run `git status --short`. Stage the files that belong to this work, by name. Never stage `.env`, secrets, `*.tfstate`, `.terraform/`, or build output. If an untracked file's ownership is unclear, ask first. Show `git diff --cached --stat`. If nothing is staged, say so and stop.
4. **Commit.** Follow the "Commit messages" rules in `~/.claude/me.md`: a subject in plain words, imperative mood, under 60 characters. Add 1-2 sentences on why only if the subject doesn't say it. Include the attribution trailer if the session provides one.
5. **Push.** `git push -u origin feature/dlopez`. If the push is rejected, stop and report it.
6. **Watch CI.** Follow the `dl:watchci` skill for branch `feature/dlopez`. It opens the finished run itself.
7. **On success, open the PR.**
   - If `ci.sh pr-url feature/dlopez Development` returns a URL, reuse that PR. The new commit is already on it.
   - Otherwise run `gh pr create --base Development --head feature/dlopez --title "<subject>" --body "<body>"`. Write the body with the `ras-dev-toolkit:create-git-commit` skill if it's available. Otherwise use a one-paragraph plain summary followed by the technical detail.
   - Then `open "<PR_URL>"`.
8. **On failure**, report watchci's root cause. Don't create the PR, and don't start fixing anything.

Report as a numbered list: commit sha + subject, CI result, what changed, PR URL (or why there isn't one). Next step for the user: merge the PR, then `/watchci Dev`.

## /promote Production

This mode creates the PR and opens it. Nothing else: no commit, no pull, no CI watch.

1. **Check.** `ci.sh prod-check` lists the commits `Development` has that `Production` doesn't. On `NOTHING` (exit 3), say there's nothing to promote and stop.
2. **PR.**
   - If `ci.sh pr-url Development Production` returns a URL, reuse that PR.
   - Otherwise run `gh pr create --base Production --head Development --title "<plain summary of what's shipping>" --body "<body>"`. The body is a plain one-line-per-change summary of the listed commits, then the commit list. No PHI or secrets.
3. **Open it.** `open "<PR_URL>"`.

Report in 2-3 lines: the PR URL, how many commits it carries, and a plain summary. Next step for the user: merge the PR, then `/watchci Prod`.
