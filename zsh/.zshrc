
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

# terraform
alias tp="terraform plan"
alias ta="terraform apply"
alias td="terraform destroy"
alias tsl="terraform state list"
alias tr="terraform refresh"

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
# Function to Generate a Self-Signed Certificate
# NOTE These functions will generate a self-signed certificate and encrypt the private key using standardized names
#******************************************************************************
function gencert(){

	# Notify User
	figlet "Generating Certs" | lolcat

	# Generate a self-signed certificate
	openssl genpkey -algorithm RSA -out private_key.pem -pkeyopt rsa_keygen_bits:2048
	openssl rsa -pubout -in private_key.pem -out public_key.pem

	# Convert the private key to base64
	base64 -i private_key.pem -o private_key.b64;

	# Copy the Public Key to the clipboard
	bat --style plain public_key.pem | pbcopy

	# Notify the user
	cowsay 'Public key has been copied to the clipboard' | lolcat
}


function encryptcert(){
	# Notify User
	figlet "Encrypting Cert" | lolcat

	# Encrypt the private key using the public key
	openssl pkcs8 -topk8 -in private_key.pem -out private_key_e.pem -v2 aes-256-cbc

	# Convert the encrypted private key to base64
	base64 -i private_key_e.pem -o private_key_e.b64;

	# Notify the user
	cowsay 'Encrypted Private key has been created. (private_key_e.pem & private_key_e.b64)' | lolcat 
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
