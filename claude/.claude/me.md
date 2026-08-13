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

## Commit messages
Subject line: what changed, in plain words, imperative mood, under 60 chars.
Body: 1-2 sentences on why. Skip the body if the subject says it all.
No bullet lists of every file touched. The diff already says that.

## Issue and PR reviews
Open with: what this is asking for, in one sentence.
Then: what's actually wrong or missing, plainly stated.
Then: what it would take to fix. Rough, not a spec.
Flag anything that looks like it'll bite later, but say it in one line.
