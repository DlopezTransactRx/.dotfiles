---
name: obsidian-log-update
description: Use when work in the current session is done and should be recorded in today's Obsidian daily note — "log this", "add this to my log", "obsidian log update", "write this up in my note", "log what we just did", or when wrapping up a task, meeting, research thread, or investigation worth remembering.
---

# Obsidian Log Update

Append an entry for the work just completed to today's Obsidian daily note, matching the existing entry format exactly.

**Core principle:** The note is a future-self reference, not a transcript. Record the problem, the fix, and what will bite later. Never restate the conversation.

## Locating the Vault and Today's Note

1. Read the vault path from Obsidian's own config — never guess or search the filesystem:
   ```bash
   cat ~/Library/Application\ Support/obsidian/obsidian.json
   ```
   The `vaults` object maps an id to `{"path": "..."}`. If more than one vault has `"open": true`, ask which.

2. Today's note is `<vault>/YYYY-MM-DD.md` at the **vault root** — not in a subfolder. Get the date and time from the shell, not from context:
   ```bash
   date "+%Y-%m-%d %H:%M"
   ```
   Context dates go stale mid-session; a wrong timestamp corrupts the log's ordering.

3. Read the note before writing. If it does not exist, create it with the entry as its first content. If it exists, **append after the last entry** — never insert in the middle, never overwrite.

## Entry Format

Entries are separated by `---` and open with a colored HTML header. Copy this shape exactly, including the space inside `rgb(` values:

```markdown

---
# <span style="color:rgb(0, 112, 192)">TASK</span> [17:30] - Short Descriptive Title
#task #topic1 #topic2 #ai-claude

# SECTION HEADER
Body content.
```

### Entry Types

Pick the type from what the work actually was. Templates live in `<vault>/@TEMPLATES/`.

| Type | Color | Tag | Use when |
| ---- | ----- | --- | -------- |
| TASK | `rgb(0, 112, 192)` | `#task` | Work performed — code changed, query run, thing fixed or deployed |
| RESEARCH | `rgb(0, 256, 0)` | `#research` | Investigation, reading, comparing options; no change made |
| MEETING | `rgb(255, 192, 0)` | `#meeting` | Notes from a call |
| DISCUSSION | `rgb(112, 48, 160)` | `#discussion` | A conversation with a person that produced decisions |
| TODO | `rgb(255, 20, 147)` | `#TODO` | A checklist of `- [ ]` items to do later |
| FOLLOW UP | `rgb(237, 125, 49)` | `#followup` | Something parked, awaiting someone else |

Most session write-ups are TASK.

### Tags

The tag line has three parts, in this order:

1. **The type tag** — always first, matching the entry type (`#task`, `#research`, ...).
2. **1-3 topical tags** — lowercase, no spaces.
3. **The agent attribution tag** — always last, exactly one. See below.

Add 1-3 topical tags. **Reuse existing tags** — grep the vault before inventing one:

```bash
grep -rhoE '^#[a-z][a-z0-9_-]*( #[a-z][a-z0-9_-]*)*' --include="20*.md" <vault> | tr ' ' '\n' | sort | uniq -c | sort -rn | head -30
```

If no existing topical tag fits, coin one and say so in your reply so the user can correct it.

### Agent Attribution Tag (REQUIRED on every entry)

Every entry written by an AI agent carries exactly one `#ai-<agent>` tag as the **last tag on
the tag line**. It marks the entry as agent-authored so it can be told apart from notes the
user typed himself.

**The rule:** `<agent>` is the lowercase name of the model family or agent product **you**
are — the thing that stays constant across versions. Strip version numbers, size names, and
vendor prefixes.

Resolve it by answering "what am I?" and reducing to one word:

| If you are | Write | Not |
| ---------- | ----- | --- |
| Any Claude model — Opus, Sonnet, Haiku, Fable, any version number | `#ai-claude` | `#ai-opus5`, `#ai-claude-opus-5`, `#ai-anthropic`, `#ai-sonnet` |
| Codex / the Codex CLI | `#ai-codex` | `#ai-gpt5`, `#ai-openai`, `#ai-chatgpt` |
| Gemini / Gemini CLI | `#ai-gemini` | `#ai-google`, `#ai-gemini-pro` |
| GitHub Copilot | `#ai-copilot` | `#ai-github` |
| Cursor's built-in agent | `#ai-cursor` | `#ai-cursor-agent` |
| Any other agent | `#ai-<its one-word product name>` | a version-qualified name |

**Normalization rules, applied in order:**

1. Take your model family or agent product name.
2. Lowercase it.
3. Drop every version number, date stamp, and release qualifier (`5`, `4.5`, `-latest`, `20251001`).
4. Drop the size or tier name (Opus, Sonnet, Haiku, Mini, Pro, Turbo, Flash).
5. Drop the vendor name if the product has its own name (Anthropic → the product is Claude;
   OpenAI → the product is Codex).
6. Replace any remaining spaces with `-`. The result must match `^[a-z][a-z0-9-]*$`.
7. Prefix with `ai-` and `#`.

**Worked examples:** `claude-opus-5` → family is Claude → `#ai-claude`. `Claude Haiku 4.5` →
`#ai-claude`. `gpt-5-codex` running as the Codex CLI → `#ai-codex`. `gemini-2.5-pro` →
`#ai-gemini`.

**Edge cases:**

- **Never** version the tag. Every Claude model, forever, writes `#ai-claude`. This is
  deliberate — the tag answers "was a machine involved," not "which build."
- One tag per entry, even if several agents contributed. Use the agent that wrote the entry.
- A subagent uses the same tag as its parent model. Do not invent a subagent-specific tag.
- If you genuinely cannot determine what model you are, use `#ai-unknown` and say so in your
  reply so the user can correct it. Do not guess a vendor.
- Entries the user writes by hand carry no `#ai-` tag. Never add one to an existing entry you
  did not write.

## Body: Choose Sections From the Work

There is no fixed section list. `#`-level headers are chosen to fit what happened. Common ones: `# PROBLEM`, `# FIX`, `# ROOT CAUSE`, `# METRICS`, `# BACKUP`, `# EXECUTED`, `# VERIFICATION`, `# RESULT`, `# PRs`, `# WATCH OUT`, `# QUESTION`, `# NEXT STEPS`.

Guidance for the body:

- **Lead with the problem in plain words.** Why the work was needed, not what you typed.
- **Show code and SQL in fenced blocks.** Use ` ```SQL ` for SQL — that exact casing is used throughout the vault. Before/after comparisons in one block beat prose.
- **Use a Markdown table** for lists of files, fields, or environments with a note each.
- **Link every PR and issue the work touched** — see [Linking PRs and Issues](#linking-prs-and-issues) below.
- **End with the trap.** A `# WATCH OUT` section for the behavior change or silent failure mode a future reader would miss. This is the highest-value part of the entry.
- **Leave room for screenshots.** The user pastes `![[Pasted image ....png]]` under headers like `# VERIFICATION` after the fact. Do not fabricate image links.

## Linking PRs and Issues

If the work opened, updated, reviewed, or merged a PR — or closed an issue — the entry
**must** carry a live hyperlink to it. A bare `#199` or a repo name is not enough; future-you
opens the note to get to the PR, and an unlinked number costs a search.

Never hand-assemble the URL from memory. Ask `gh` for the real one and its current state:

```bash
gh pr view <number|branch> --repo transactrx/<repo> --json number,title,url,state,baseRefName,headRefName
```

For everything touched in the session at once:

```bash
gh pr list --repo transactrx/<repo> --state all --limit 5 \
  --json number,title,url,state,baseRefName,headRefName
```

If `gh` is unavailable or the PR does not exist yet, write the plain text and say so in your
reply — never fabricate a URL.

### Format

Group them under a `# PRs` header (or `# PROD PRS` when they are the promotion pair). Two
shapes are already in use — match whichever fits:

```markdown
# PRs
- [#199](https://github.com/transactrx/ras-datawarehouse-reference-data/pull/199) feature/dlopez -> Development (MERGED)
- [#200](https://github.com/transactrx/ras-datawarehouse-reference-data/pull/200) Development -> Production (OPEN)
```

```markdown
# PRs
[PR - PROD - Fix Clinical Plus SA Role](https://github.com/transactrx/SnowflakeWHAdministration/pull/978)
```

Rules:

- Use the `#<number>` + branch-arrow form when the branch flow is the point (a
  Development → Production promotion). Use the descriptive-label form when *what the PR does*
  is the point.
- Always append the state — `(OPEN)`, `(MERGED)`, `(CLOSED)`, `(DRAFT)` — on the numbered form.
  State captured at write time is a fact about that moment; do not go back and update it.
- One line per PR. A promotion pair is two lines, never one line with two links.
- Issues follow the same shape: `[#42](url) short title (CLOSED)`.
- Links to a failed or notable **workflow run** belong here too, labeled so they are not
  mistaken for the PR itself, e.g. `[PROD APPLY - run 23017445986](url)`.
- Do not nest a URL inside a URL. One `[label](url)` per line.

## Quick Reference

| Step | Action |
| ---- | ------ |
| 1 | `cat ~/Library/Application\ Support/obsidian/obsidian.json` → vault path |
| 2 | `date "+%Y-%m-%d %H:%M"` → note filename + entry timestamp |
| 3 | Read `<vault>/YYYY-MM-DD.md` to see today's existing entries |
| 4 | Pick entry type + reuse existing tags + append your `#ai-<agent>` tag last |
| 5 | `gh pr view ... --json url,state` for any PR touched → `# PRs` section |
| 6 | Append after the last entry with `Edit` |
| 7 | Tell the user what type/tags you chose so they can correct |

## Common Mistakes

| Mistake | Fix |
| ------- | --- |
| Guessing the vault path | Read `obsidian.json` |
| Looking for an `@log` folder | Daily notes sit at the vault root |
| Using the date from context | Run `date` — context dates drift |
| Timestamp copied from an earlier entry | Use the current time; entries are chronological |
| Inserting the entry at the top | Append at the bottom |
| Writing a narrative of the chat | Record problem → fix → consequence |
| Inventing a new tag when one exists | Grep the vault first |
| Omitting the `#ai-<agent>` tag | Every agent-written entry needs one, last on the tag line |
| Versioning it (`#ai-opus5`, `#ai-claude-4`) | Family name only — `#ai-claude` |
| Using the vendor (`#ai-anthropic`, `#ai-openai`) | Use the product — `#ai-claude`, `#ai-codex` |
| Writing a bare `#199` with no link | Every PR/issue mention gets a `[label](url)` |
| Hand-assembling a PR URL from memory | `gh pr view --json url` — or say it's unlinked |
| Omitting the separator | Every entry starts with `---` on its own line |
| Fabricating `![[Pasted image ...]]` links | Only the user adds screenshots |
