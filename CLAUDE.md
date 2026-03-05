# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal dotfiles repository that configures a complete development environment for macOS. It uses **GNU Stow** for symlink management and **Homebrew** for package installation.

## Installation & Setup

### Full Installation
```bash
# Run the automated install script (installs Homebrew + packages, then stows all configs)
sh install.sh
```

### Selective Installation
```bash
# Install only specific configurations
cd ~/.dotfiles
stow zsh      # Symlink zsh configs to ~
stow nvim     # Symlink neovim configs to ~/.config/nvim
stow tmux     # etc.
```

### Package Management
```bash
# Install all Homebrew packages from Brewfile
brew bundle --file=~/.dotfiles/homebrew/Brewfile

# Update all packages
bu  # (alias for: brew update && brew upgrade && brew cleanup)
```

## Critical Architecture Details

### Zsh Configuration Structure

The zsh configuration is modular and split across multiple files sourced by `.zshrc`:

1. **`.zsh_hidden`** - Contains **SENSITIVE DATA** (credentials, secrets, network targets)
   - JWT tokens and secrets
   - Network test targets array (`NETWORK_TEST_TARGETS`)
   - **NEVER commit or share this file**

2. **`.zsh_work`** - Contains work-related **functions** (depends on variables from `.zsh_hidden`)
   - `jwtToken()` - Fetches JWT tokens using credentials from `.zsh_hidden`
   - `ndd()` / `ndp()` - NATS discover for dev/prod environments
   - `nt()` - Network connectivity test function

3. **`.zsh_claude`** - Claude CLI shortcuts

4. **`.zsh_ncpdp`**, `.zsh_n8n`, `.zsh_openssl`, `.zsh_snowflake_wh_admin` - Domain-specific utilities

**Source order matters**: `.zsh_hidden` must be sourced before `.zsh_work` since functions depend on environment variables.

### Stow Management

When adding/modifying files in subdirectories (zsh/, nvim/, etc.):
```bash
# Always restow after changes to update symlinks
cd ~/.dotfiles
stow -R zsh  # -R flag restows (removes old symlinks, creates new ones)
```

**Stow structure**: Each top-level directory (zsh/, nvim/, tmux/, etc.) maps to home directory:
- `zsh/.zshrc` → `~/.zshrc`
- `nvim/.config/nvim/init.lua` → `~/.config/nvim/init.lua`

### Key Integrations

- **Tmux ↔ Neovim**: Vim-style navigation (`h/j/k/l`) works seamlessly across tmux panes and neovim splits via vim-tmux-navigator plugin
- **Git + Delta**: Git diffs use delta pager with side-by-side view (configured in `git/.gitconfig`)
- **Starship + Zoxide**: Smart prompt with directory jumping (`z <partial-name>`)
- **Yabai + SKHD**: Tiling window manager with hotkey daemon for macOS window management

## Common Tasks

### Reloading Configurations
```bash
r              # Reload zsh (alias for: source ~/.zshrc)
tmux source ~/.tmux.conf   # Reload tmux config
```

### TMUX Plugin Installation
After modifying tmux plugins:
1. Start tmux: `tmux`
2. Press `Ctrl+B` then `Ctrl+I` to install plugins

### Adding New Zsh Functions

When adding new work functions:
1. **Sensitive data** (credentials, secrets) → Add to `zsh/.zsh_hidden`
2. **Functions** → Add to `zsh/.zsh_work`
3. Restow: `cd ~/.dotfiles && stow -R zsh`

## Development Tools in Brewfile

- **Languages**: Go, Node, Python, PHP
- **Shell**: zsh, tmux, starship prompt
- **Editors**: neovim (with lua config)
- **CLI Tools**: ripgrep, fzf, bat, eza, yazi, zoxide, jq
- **Git**: lazygit, gh, git-delta
- **DevOps**: terraform, awscli, docker
- **Custom Taps**: nats-discover (TransactRX), yabai, skhd

## Scripts Directory

Located at `scripts/scripts/` (nested structure):
- `ralph/` - PRD generation utilities
- `github-branch-protection/` - GitHub branch protection automation

Scripts are automatically added to PATH via `.zshrc` symlink mechanism (lines 214-229).

## Important Patterns

### NATS Discovery Functions
```bash
ndd  # NATS discover development environment (blue styling)
ndp  # NATS discover production environment (red styling)
```
These functions use `nats-discover` CLI tool with context switching and styled output via `gum` and `figlet`.

### Network Testing
```bash
nt   # Tests all targets defined in NETWORK_TEST_TARGETS array
```
Tests connectivity to Snowflake, Kafka brokers, Postgres instances using netcat.

## Neovim Configuration

Based on **Kickstart.nvim** with customizations in `nvim/.config/nvim/init.lua`. Uses lazy.nvim plugin manager. Includes gopls for Go development and Avante plugin for AI assistance.
