# Dotfiles

A collection of configuration files for my development environment.

## Overview

This repository contains my personal dotfiles for various tools, terminal configurations, window managers, and productivity utilities. It's designed to make setting up a new development environment quick and consistent across machines.

## Components

### Terminal Environment
- **[Zsh](./zsh)**: Shell configuration with custom aliases, functions, and integrations
- **[Tmux](./tmux)**: Terminal multiplexer with vim-style navigation and dracula theme
- **[Starship](./starship)**: Cross-shell prompt with custom styling
- **[Ghostty](./ghostty)**: Modern terminal emulator configuration

### Development Tools
- **[Neovim](./nvim)**: Text editor configuration based on Kickstart.nvim
- **[Git](./git)**: Global git configuration with delta integration
- **[Homebrew](./homebrew)**: Package management with Brewfile

### Window Management
- **[Yabai](./yabai)**: Tiling window manager for macOS
- **[SKHD](./skhd)**: Simple hotkey daemon for keyboard shortcuts

## Key Features

- Vim-style key bindings across multiple tools
- Integration between tmux and neovim for seamless navigation
- Modern terminal styling with Nerd Fonts and themes
- Extensive alias system for common commands
- Smart directory navigation with zoxide
- Custom prompt with git status information
- Window management hotkeys for productivity

## Manual Installation (Option A)

To install these dotfiles:

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/dotfiles.git ~/.dotfiles
   ```

2. Use GNU Stow to symlink configurations:
   ```bash
   cd ~/.dotfiles
   stow zsh nvim tmux # etc.
   ```

3. Install Homebrew packages:
   ```bash
   brew bundle --file=~/.dotfiles/homebrew/Brewfile
   ```

## Install Script (Option B)
At the root of this project is 'install.sh' by executing...

```bash
sh install.sh
```
- This will setup hombrew and install the entire bundle package.

## TMUX Install
```bash
tmux
```

2) Reload the configuration:

If TMUX is already running, type this in terminal:
```bash
tmux source ~/.tmux.conf
```

3) Manually copy the TMUX/configs file to their relative projects.

4) Inside a TMUX session:
- Press `CTRL + B` (prefix key)
- Then press `CTRL + I` (install plugins)
## Recent Updates

- Added Claude CLI alias
- Enabled Go language server (gopls)
- Changed Copilot auto-complete to Tab key
- Updated Ghostty key mapping (alt+space)
- Added Go and Make CLI tools

## License

This project is licensed under the MIT License - see the LICENSE file for details.
