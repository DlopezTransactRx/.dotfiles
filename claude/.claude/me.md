# About Me

## My machine setup
All my terminal configuration — zsh, tmux, neovim, git, and my Claude settings — lives in
`~/.dotfiles` and is symlinked into place with GNU Stow. Each top-level directory maps to
home: `zsh/.zshrc` → `~/.zshrc`, `claude/.claude/me.md` → `~/.claude/me.md`.
Edit the real file under `~/.dotfiles`, not the symlink target, and run `stow -R <dir>`
from `~/.dotfiles` after adding or moving files.

## My second brain
Obsidian is my second brain. It's where I keep daily logs and collect anything worth
holding onto — notes, research, decisions, reference material. Daily notes are
`YYYY-MM-DD.md` at the vault root. Find the vault path from Obsidian's own config
(`~/Library/Application Support/obsidian/obsidian.json`), never by guessing or searching
the filesystem. When I say "log this" or want something written up, that's where it goes.

### AIOS folder
The vault has an `AIOS/` folder holding markdown files about my Obsidian setup itself —
structure, conventions, and maps of the vault (`AIOS/MAPS/`). These are meant to be loaded
into context. When a task touches how my vault is organized, where notes live, or how I
want notes written, read the relevant files under `AIOS/` first instead of inferring it
from the vault contents.

## Philosophies I subscribe to in regards to learning and productivity
- Remember It! by Nelson Dellis
- Getting Things Done: The Art of Stress-Free Productivity by David Allen

## How to explain things to me
Lead with one plain sentence that answers the question.
No nonsense. Straight to the point.
Short sentences. One idea each. No stacked clauses.
Use everyday words. If a technical term is unavoidable, define it inline, once, then use it.
Give a concrete example instead of an abstract description.
Say what something is not when people commonly get it wrong.
Skip headers and bullet lists for anything under ~200 words. Just talk.
Don't hedge. If there's a real caveat, state it in one sentence and move on.
If I need the precise or technical version, I'll ask for it.
Use analogies and memory tricks if they’ll make concepts easier to grasp.
When presenting issues to me, I prefer them as a numbered list.

## Development Preferences
- All code being developed should be done in a local feature branch called 'feature/dlopez' unless stated otherwise.
  - **Exception — `SnowflakeWHAdministration`:** work on the local `Development` branch instead. No `feature/dlopez` there; PRs always go `Development` -> `Production`.
- When requesting coding to be done, never automatically commit changes. I like to review the unstaged changes.  I will explicitly tell the agent when to commit.
## My personal skills
My personal skills live in my `dl` plugin (`~/.dotfiles/claude/.claude/skills/dl/`). Run each one as `/dl:<name>`. When I name one, with or without the `dl:` prefix, run that skill. It holds the full definition.
1. **promote**: `Dev` commits on `feature/dlopez`, pushes, watches CI, and on success opens the PR to `Development`. `Prod` only creates the `Development` → `Production` PR and opens it.
2. **watchci**: watches CI on a branch (`Dev`, `Prod`, or any name), opens the finished run, and summarizes what changed.
3. **handoff**: writes a copy-ready prompt so a fresh agent can pick up the current work. `hop` still triggers it.
4. **issuestatus**: lists an issue's own unchecked boxes and "Done when" items, quoted exactly and checked against the code.
5. **10ke**: a plain, big-picture 10,000-foot explanation of a topic.
6. **obsidian-log-update**: adds an entry for the work just finished to today's Obsidian daily note.
7. **obsidian-weekly-status**: summarizes the week's accomplishments from my Obsidian log.
8. **adversarial-review**: sends several independent reviewers over code, checks every finding against the source, fixes the real ones, and repeats until a round comes back clean.
9. **explain-code**: explains code with diagrams and analogies.
10. **snowflake-role-grant-comparison**: generates SQL to compare a Snowflake role's grants between environments, like dev and prod.
11. **validate-table-sync**: checks that pairs of tables in two Snowflake schemas match in structure, row counts, and data.


## Commit messages
Subject line: what changed, in plain words, imperative mood, under 60 chars.
Body: 1-2 sentences on why. Skip the body if the subject says it all.
No bullet lists of every file touched. The diff already says that.

## Issue and PR reviews
Open with: what this is asking for, in one sentence.
Then: what's actually wrong or missing, plainly stated.
Then: what it would take to fix. Rough, not a spec.
Flag anything that looks like it'll bite later, but say it in one line.
