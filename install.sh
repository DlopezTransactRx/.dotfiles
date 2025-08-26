#!/usr/bin/env bash
set -euo pipefail

# --- Config ---
DOTFILES_DIR="${HOME}/.dotfiles"
DOTFILES_BREW_DIR="${DOTFILES_DIR}/homebrew"
BREWFILE="${DOTFILES_BREW_DIR}/Brewfile"

# --- 0) Prime sudo once and keep it alive (for casks/helpers that need it) ---
if command -v sudo >/dev/null 2>&1; then
  sudo -v
  # Keep-alive: update existing `sudo` time stamp until this script finishes.
  trap 'kill $(jobs -p) >/dev/null 2>&1 || true' EXIT
  while true; do sudo -n true; sleep 60; done >/dev/null 2>&1 &
fi

# --- 1) Install Homebrew non-interactively if missing ---
if ! command -v brew >/dev/null 2>&1; then
  export NONINTERACTIVE=1
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# --- 2) Ensure brew is on PATH for this shell (Apple Silicon vs Intel) ---
if [[ -d /opt/homebrew/bin ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -d /usr/local/bin ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
else
  eval "$("$(/usr/bin/which brew)" shellenv)"
fi

# --- 3) Brew config (non-interactive) ---
export NONINTERACTIVE=1
export HOMEBREW_NO_ENV_HINTS=1
export HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_NO_AUTO_UPDATE=1   # optional: skip auto-update for speed

# --- 4) Brewfile sanity check & install ---
[[ -f "$BREWFILE" ]] || { echo "Brewfile not found at $BREWFILE"; exit 1; }
brew update --force --quiet || true

cd "$DOTFILES_BREW_DIR"
brew bundle --file="$BREWFILE"

echo "✅ Homebrew + Brewfile install complete."

# --- 5) Stow dotfiles ---
cd "$DOTFILES_DIR"
for dir in */; do
  # Skip hidden dirs (like .git/) and homebrew folder (we already ran it)
  [[ "$dir" == .* ]] && continue
  [[ "$dir" == "homebrew/" ]] && continue

  echo "➡️  Stowing ${dir%/}"
  stow "${dir%/}"
done

echo "✅ Dotfiles stowed successfully."
