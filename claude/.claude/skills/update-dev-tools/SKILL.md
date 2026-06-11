---
name: update-dev-tools
description: >
  Update local developer tooling — Neovim plugins (Lazy), Neovim LSP/tool
  packages (Mason), and Homebrew formulae/casks — from the command line without
  opening interactive UIs. Use this skill whenever the user asks to update,
  upgrade, or refresh their dev environment, editor plugins, language servers,
  or brew packages — including phrasings like "update my nvim plugins", "run
  Lazy update", ":Mason update", "update Mason", "brew update", "upgrade my
  tools", "keep my environment current", or "update everything". Trigger even
  when the user names only one of the three tools, and offer to run the others.
---

# Update Dev Tools

Update three pieces of local developer tooling from the shell, replicating the
interactive UI actions a developer would otherwise perform by hand. The whole
point is to run these non-interactively so they can be driven by an agent and
summarized cleanly, instead of launching a TUI and pressing keys.

Run only the tools the user asks for. If they say "update everything" or name
the environment generally, do all three. If they name just one (e.g. "update my
nvim plugins"), do that one, then offer the others.

After each tool, report a short **summary table** of what actually changed —
version deltas, what was already current, and anything skipped — rather than
dumping raw output. The raw logs are large and noisy; the developer wants the
signal. Strip ANSI color codes when parsing captured output (`perl -pe
's/\e\[[0-9;]*m//g'`).

## 1. Neovim plugins — Lazy (`:Lazy` → `U`)

The headless equivalent of opening `:Lazy` and pressing `U` (Update):

```bash
nvim --headless "+Lazy! update" +qa
```

The `!` runs the operation synchronously, which is essential in headless mode —
without it nvim can exit before the update finishes. Output can be tens of KB;
parse it for the per-plugin checkout lines (`HEAD is now at <sha> <msg>`) to
build the summary. Plugins that only fetched with no new commits were already
up to date.

## 2. Neovim Mason packages (`:Mason` → `U`)

First refresh the registry, then update outdated packages. Two steps because
`:MasonUpdate` only refreshes the registry metadata — it does **not** update the
installed packages.

```bash
# Step 1: refresh the registry metadata
nvim --headless "+MasonUpdate" +qa

# Step 2: update all outdated installed packages
nvim --headless "+luafile ~/.claude/skills/update-dev-tools/scripts/mason_update.lua" +qa
```

Why the bundled script: Mason 2.x removed the old `pkg:check_new_version()` API,
and there is no single built-in command to "update all" headlessly. The script
[`scripts/mason_update.lua`](scripts/mason_update.lua) reproduces what the Mason
UI's `U` action does internally — compare `get_installed_version()` against
`get_latest_version()` and `install()` the ones that differ. It prints
`OUTDATED:` lines (what it will update) and `RESULTS:` lines (`OK:`/`FAIL:` per
package), which are easy to summarize. If a future Mason version changes the API
and the script errors, inspect `lua/mason/ui/instance.lua` in the mason.nvim
install (the `UPDATE_ALL_PACKAGES` / `check_new_package_versions` functions) to
see the current update logic, and adjust the script to match.

## 3. Homebrew (`brew update`)

```bash
brew update
```

`brew update` only refreshes formula/cask metadata and reports what is outdated
— it installs nothing. Report the outdated formulae and casks it lists, then
**ask the user before running `brew upgrade`**, since upgrades can be slow,
large, or disruptive. Don't auto-upgrade unless the user explicitly asks to.

```bash
# Only after the user confirms:
brew upgrade                  # everything
brew upgrade <formula>...     # or a specific subset
```

Homebrew's newer tap-trust gate may skip third-party taps it considers
untrusted (printed as `Skipping <tap> because it is not trusted`). Surface these
in the summary — those taps' formulae won't update until the user runs `brew
trust <tap>`. Mention it; don't run `brew trust` automatically, since it grants
the tap permission to run arbitrary code.

## Closing summary

End with a brief combined recap across whichever tools ran: what was updated,
what was already current, and any follow-up actions the user must take manually
(e.g. `brew upgrade`, `brew trust <tap>`). Note plainly if nothing needed
updating.
