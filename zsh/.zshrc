
#******************************************************************************
# Command Aliases
#******************************************************************************
# Refresh ZSH Source
alias r="source ~/.zshrc"

# Pretty List With Eza
alias ll="eza -la -g --icons --git"

# Pretty Tree With Eza
alias llt="eza -la --icons --tree --git-ignore"

# Change Directory
alias ..="cd .."
alias .1="cd ../.."
alias .2="cd ../../.."
alias .3="cd ../../../.."
alias .4="cd ../../../../.."
alias .5="cd ../../../../../../.."

# File Management
alias mv="mv -I"
alias rm="rm -I"
alias cp="cp -I"
alias ln='ln -I'
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

#Claude
alias cl="claude --model sonnet"

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
# Snowfalke Warehouse Admin (Personal Script)
#******************************************************************************
if [ -f ~/.zsh_snowflake_wh_admin ]; then
  source ~/.zsh_snowflake_wh_admin
fi


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
# Network Test
#******************************************************************************
if [ -f ~/.zsh_network_test ]; then
  source ~/.zsh_network_test
fi
export PATH="$HOME/.local/bin:$PATH"
export PATH="/opt/homebrew/bin:$PATH"
