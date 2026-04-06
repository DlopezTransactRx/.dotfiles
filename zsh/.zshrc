
#******************************************************************************
# Command Aliases
#******************************************************************************
# Refresh ZSH Source
alias r="source ~/.zshrc"

# Pretty List With Eza
alias ll="eza -la -g --icons --git"

# Pretty Tree With Eza
alias llt="eza -la --icons --tree --git-ignore"

# Tail 
alias t="tail -f"

# Copy Working Directory to Clipboard
alias pwdc="pwd | pbcopy"
alias rp="realpath"
function rpc () {
  realpath "$@" | pbcopy
}

# Change Directory
alias ..="cd .."
alias .1="cd ../.."
alias .2="cd ../../.."
alias .3="cd ../../../.."
alias .4="cd ../../../../.."
alias .5="cd ../../../../../../.."

# File Management
alias mkdir="mkdir -pv"

# git
alias ga="git add"
alias gc="git commit"
alias gca="git commit --amend"
alias gcm="git commit -m"
alias gs="git status"
alias gsw="git switch"
alias gb="git branch"
alias gp="git push"
alias gpl="git pull"
alias gr="git reset"
alias grs="git reset --soft"
alias grm="git reset --mixed"
alias grh="git reset --hard"
alias grst="git restore"
alias grv="git revert"
alias gd="git diff"
alias gm="git merge"
alias gf="git fetch"
alias gl="git log"
alias gll="git log --oneline --graph --decorate"
alias gbl="git blame"
alias gspo="git stash pop"
alias gspu="git stash push"

# GitHub CLI
alias ghb="gh browse"

# Lazygit
alias lg="lazygit"

# terraform
alias tfi="terraform init"
alias tfiu="terraform init -upgrade"
alias tfv="terraform validate"
alias tfp="terraform plan"
alias tfpv="terraform plan -var-file=variables.tfvars"
alias tfss="terraform state show"
alias tfsl="terraform state list"
alias tfr="terraform refresh"
alias tfwl="terraform workspace list"
alias tfws="terraform workspace select"


# Functions - Just Method Names
alias functions="print -l ${(k)functions}"

# Utility Script to create a script to convert resources from one to another.
function tfConvert(){

    terraform state list | rg "$1" | while read -r OLD_RESOURCE; do

    # Extract the ID of the old resource
    local ID=$(terraform state show "$OLD_RESOURCE" | rg 'id\s*=\s*"' | rg -o '"([^"]*)"' -r '$1')

    #Grab Prefix and Suffix
    local NEW_RESOURCE=$(echo $OLD_RESOURCE | sed s/$1/$2/)

    #Echo RM Statement
    echo "terraform state rm '$OLD_RESOURCE'"
    echo "terraform import '$NEW_RESOURCE' '$ID'"

  done
  
}

# TLDR
alias tldrs="tldr \`tldr -l | fzf  -e\`"

# SKHD + Yabai
alias ys="skhd --start-service && yabai --start-service"
alias yss="skhd --stop-service && yabai --stop-service"
alias yr="skhd --restart-service && yabai --restart-service"

#Homebrew
alias bu="brew update && brew upgrade && brew cleanup"

# Util
alias ping="ping -c 5"
alias fastping="ping -c 100 -i 0.2"
alias c="clear"
alias h="history"
alias now='echo "[ Zulu     ]: $(TZ="UTC" date)"; \
echo "[ Eastern  ]: $(TZ="America/New_York" date) (UTC-5)"; \
echo "[ Central  ]: $(TZ="America/Chicago" date) (UTC-6)"; \
echo "[ Mountain ]: $(TZ="America/Denver" date) (UTC-7)"; \
echo "[ Pacific  ]: $(TZ="America/Los_Angeles" date) (UTC-8)"'
alias m="cmatrix -s"


# Claude
alias cch='claude --model haiku'
alias ccs='claude --model sonnet'
alias cco='claude --model opus'
alias ccae='claude --permission-mode acceptEdits'
alias ccx='claude --allow-dangerously-skip-permissions'
# NOTE: As of the this time, claude MCP servers cannot be configured globally. They must exist locally to the project.  This alias will create a symlink to my .mcp.json file to make MCP available to a project.
alias ccmcp='ln -sf ~/.claude/.mcp.json .mcp.json'

# Desktop Notification Function
function notify() {
  osascript \
    -e 'do shell script "afplay /System/Library/Sounds/Submarine.aiff >/dev/null 2>&1 &"' \
    -e "display dialog \"$1\" with title \"${2:-Notification}\" with icon POSIX file \"/System/Applications/Utilities/Terminal.app/Contents/Resources/Terminal.icns\" buttons {\"OK\"} default button \"OK\""
}



#******************************************************************************
# [Command List Menu Utility]
# _cmd_category <category> [args...]
#
# Reads $COMMANDS_FILE entries formatted as:
#   [category][label]command
#
# Filters by [category], shows results via `gum filter`,
# strips [label], and executes the command with optional args.
#
# Example wrapper:
#   logs() { _cmd_category logs "$@"; }
#   gitcmd() { _cmd_category git "$@"; }
#
# Usage:
#   logs
#   logs prod-index
#
# Requires: rg, gum
# Note: uses eval → commands file must be trusted
#
#******************************************************************************
#
function _cmd_category() {
  local category="$1"
  shift

  local -a choices
  local selected command

  choices=("${(@f)$(rg "^\[$category\]" "$COMMANDS_FILE" | sed -E 's/^\[[^]]+\]//')}")
  (( ${#choices[@]} == 0 )) && return

  selected=$(gum filter --no-fuzzy "${choices[@]}") || return
  [[ -z "$selected" ]] && return

  command="${selected#*]}"
  command="${command#"${command%%[![:space:]]*}"}"

  # Add command to buffer stack so user can press Enter to execute
  print -z "$command${@:+ $@}"
}

#******************************************************************************
# grc (Generic Colouriser) 
#******************************************************************************
function ping(){
	grc ping "$@"
}
function lsof(){
	grc lsof "$@"
}


#******************************************************************************
# Starship (Setup)
#******************************************************************************
eval "$(starship init zsh)"

#******************************************************************************
# TheFuck (Setup)
#******************************************************************************
eval "$(thefuck --alias tf)"

#******************************************************************************
# Zoxide (Setup)
#******************************************************************************
if [ -f ~/.zsh_zoxide ]; then
  source ~/.zsh_zoxide
fi
eval $(thefuck --alias)

#******************************************************************************
# Yazi
#******************************************************************************
export EDITOR=nvim
function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		builtin cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}

#******************************************************************************
# NCPDP (Personal Script)
#******************************************************************************
if [ -f ~/.zsh_ncpdp ]; then
  source ~/.zsh_ncpdp
fi

#******************************************************************************
# n8n
#******************************************************************************
if [ -f ~/.zsh_n8n ]; then
  source ~/.zsh_n8n
fi

#******************************************************************************
# OpenSsl (Personal Script)
#******************************************************************************
if [ -f ~/.zsh_openssl ]; then
  source ~/.zsh_openssl
fi

#******************************************************************************
# (Personal Work Script - Sensitive Variables)
#******************************************************************************
if [ -f ~/.zsh_hidden ]; then
  source ~/.zsh_hidden
fi

#******************************************************************************
# (Personal Work Script - Functions)
#******************************************************************************
if [ -f ~/.zsh_work ]; then
  source ~/.zsh_work

fi

#******************************************************************************
# AWS Utility Functions
#******************************************************************************
if [ -f ~/.zsh_aws ]; then
  source ~/.zsh_aws
fi

#******************************************************************************
# Scripts TODO THIS IS SUPPOSED TO MAKE SYM LINKS BUT ITS NOT WORKING.  FIX IT.
#******************************************************************************
export PATH="$HOME/.local/bin:$PATH"
export PATH="/opt/homebrew/bin:$PATH"

# --- scripts/bin setup ---
SCRIPTS_DIR="$HOME/scripts"
SCRIPTS_BIN="$SCRIPTS_DIR/bin"

mkdir -p "$SCRIPTS_BIN"
export PATH="$SCRIPTS_BIN:$PATH"

# Symlink all *.sh under ~/scripts (excluding ~/scripts/bin) into ~/scripts/bin
while IFS= read -r -d '' f; do
  base="${f##*/}"
  name="${base%.sh}"
  link="$SCRIPTS_BIN/$name"

  # Create or update the symlink
  ln -sf "$f" "$link"
done < <(find "$SCRIPTS_DIR" -type f -name "*.sh" ! -path "$SCRIPTS_BIN/*" -print0)
