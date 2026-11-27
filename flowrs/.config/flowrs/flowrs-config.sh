#!/usr/bin/env zsh
# flowrs-config [aws-profile ...]
#
# Generates config.toml for flowrs with every Amazon MWAA (Airflow) environment found
# in a list of AWS profiles. The list comes from, in order of precedence:
#   1. profiles passed as arguments
#   2. $FLOWRS_AWS_PROFILES (space-separated)
#   3. the aws-profiles file next to this script (one name per line, # comments)
# See ~/.dotfiles/flowrs/README.md for setup.
#
# Nothing account-specific lives in this script: environment names, versions, and
# hosts are looked up from AWS on every run. The config is written next to this
# script's stowed location (~/.config/flowrs), and its server entries call
# mwaa-token.sh from that same folder. The previous config is saved as config.toml.bak.

# This script uses zsh syntax. If started with sh or bash, restart it under zsh.
[ -n "$ZSH_VERSION" ] || exec zsh "$0" "$@"

config_dir=${XDG_CONFIG_HOME:-$HOME/.config}/flowrs
config=$config_dir/config.toml
profiles_file=$config_dir/aws-profiles
token_script=$config_dir/mwaa-token.sh

if (( $# )); then
  profiles=($@)
elif [[ -n $FLOWRS_AWS_PROFILES ]]; then
  profiles=(${=FLOWRS_AWS_PROFILES})
elif [[ -r $profiles_file ]]; then
  profiles=(${(f)"$(sed -e 's/#.*//' -e 's/[[:space:]]//g' $profiles_file)"})
fi
(( $#profiles )) || {
  echo "flowrs-config: no AWS profiles. List them in $profiles_file, pass them as arguments, or set FLOWRS_AWS_PROFILES" >&2
  exit 1
}

[[ -x $token_script ]] || {
  echo "flowrs-config: missing $token_script (run: cd ~/.dotfiles && stow flowrs)" >&2
  exit 1
}

servers=""
count=0

for p in $profiles; do
  aws sts get-caller-identity --profile $p >/dev/null 2>&1 || {
    echo "flowrs-config: $p is not signed in (run: aws sso login --profile $p)" >&2
    exit 1
  }

  envs=(${(f)"$(aws mwaa list-environments --profile $p --query 'Environments[]' --output text | tr '\t' '\n')"})
  (( $#envs )) || { echo "  no Airflow environments in $p"; continue; }

  for e in $envs; do
    read -r ver url < <(aws mwaa get-environment --profile $p --name $e \
      --query '[Environment.AirflowVersion,Environment.WebserverUrl]' --output text)
    [[ -n $url ]] || { echo "flowrs-config: could not read $e in $p" >&2; exit 1; }

    major=${ver%%.*}
    if [[ $major == 3 ]]; then
      api=V3 auth=Token token_ver=v3
    else
      api=V2 auth=Cookie token_ver=v2
    fi

    servers+="
[[servers]]
name = \"$p - Airflow $major ($e)\"
endpoint = \"https://$url\"
version = \"$api\"
[servers.auth.$auth]
cmd = \"$token_script $p $e $token_ver\"
"
    (( count += 1 ))
    echo "  found $e (Airflow $ver) in $p"
  done
done

(( count )) || { echo "flowrs-config: no Airflow environments found; config left unchanged" >&2; exit 1; }

backup_note=""
if [[ -f $config ]]; then
  cp $config $config.bak
  backup_note=" (previous config saved as config.toml.bak)"
fi
umask 077
{
  print 'managed_services = []'
  print 'poll_interval_ms = 2000'
  print 'theme = "auto"'
  print -r -- "$servers"
} > $config

echo "Wrote $count servers to $config$backup_note"
