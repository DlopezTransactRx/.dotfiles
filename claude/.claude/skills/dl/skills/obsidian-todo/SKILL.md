---
name: obsidian-todo
description: Add an item to the user's GTD to-do list in Obsidian (EFFORT/GTD.md). Use when the user types /obsidian-todo, or says "add this to my to-do list", "add to my todo", "put this on my list", "add to GTD", "track this for later", "remind me to", or otherwise asks to capture an open loop or next action. Not for logging finished work — that is obsidian-log-update.
---

# Obsidian To-Do

Append one or more `- [ ]` items to the bottom of the user's GTD list, matching the existing format exactly.

**Core principle:** GTD.md is the single authority on what is open. Capture the item there and nowhere else. Do not also write a daily-log entry.

## Locating the File

1. Read the vault path from Obsidian's own config — never guess or search the filesystem:
   ```bash
   cat ~/Library/Application\ Support/obsidian/obsidian.json
   ```
   The `vaults` object maps an id to `{"path": "..."}`. If more than one vault has `"open": true`, ask which.

2. The list is `<vault>/EFFORT/GTD.md`. If it does not exist, stop and tell the user. Do not create it somewhere else.

3. Read the whole file before writing.

## Item Format

Copy the shape the existing items use:

```markdown
- [ ] Sync the POSTGRES tables Amy requested on Friday.
	https://github.com/transactrx/RasDataServicesDags/pull/31
```

- **One line, one task.** Start with a verb when it reads naturally ("Follow up with Mario about…", "Update the Postgres sync to…"). Keep the user's own wording; tighten it, don't rewrite it.
- **Make it a next action.** If the user names a person or a thing to do, keep both. "Derrick" alone is not an item; "Follow up with Derrick about the bucket policy" is.
- **Context goes on the next line, tab-indented.** A URL, a `[[wiki link]]`, or a short note. Use a real link from the session — a PR, issue, or CI run URL from `gh` — never a hand-assembled one.
- **Sub-steps** are nested `- [ ]` items, tab-indented under the parent. Only when the user gives them.
- **Ideas** that are not actionable yet keep the `IDEA:` prefix the list already uses.
- **No tags.** No `#ai-claude`, no topical tags, no timestamp. Those belong to log entries.
- **No screenshots.** Only the user pastes `![[Pasted image ...]]`. Never fabricate one.
- **No PHI.** Same rule as everywhere: identifiers and shapes, never patient data.

If the user asks for several items at once, add each as its own `- [ ]` line, in the order given.

## Writing

**Append at the bottom of the file.** Never insert in the middle, reorder, reword, check off, or delete existing items — even ones that look stale or done. If something looks wrong, mention it in your reply instead.

Make sure the new item starts on its own line, separated from the last line of the file by a newline.

The vault sits under the `/Users/dlopez` git repo, so in a background job the Write and Edit tools may be refused with an isolation error. Do not use EnterWorktree — Obsidian would never see the copy. Append with a heredoc instead:

```bash
F="<vault>/EFFORT/GTD.md"
[ -n "$(tail -c1 "$F")" ] && printf '\n' >> "$F"
cat >> "$F" <<'EOF'
- [ ] Item text
	https://link
EOF
tail -n 5 "$F"
```

Read the tail back to confirm it landed.

## Reply

One line: what you added, quoted, and that it went to the bottom of GTD.md. If you reworded the user's phrasing to make it a next action, show the final text so they can correct it.

## Common Mistakes

| Mistake | Fix |
| ------- | --- |
| Writing the item into today's daily note | To-dos go only in `EFFORT/GTD.md` |
| Also adding a daily-log entry | Don't. One place for open loops |
| Inserting at the top or under a section | Append at the bottom |
| Tidying, reordering, or checking off existing items | Leave them alone; mention issues in the reply |
| Adding `#ai-claude` or other tags | Items carry no tags |
| Vague item ("Derrick") | Name the next physical action |
| Fabricated URL or image link | Use `gh` for links; only the user adds screenshots |
| Using EnterWorktree to get past the write guard | Append with a Bash heredoc to the real vault file |
