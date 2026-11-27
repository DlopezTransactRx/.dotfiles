#!/usr/bin/env zsh
# mwaa-token <aws-profile> <mwaa-env> <v2|v3>
#
# Prints Airflow API credentials for an Amazon MWAA environment. flowrs calls this
# from the server entries that flowrs-config.sh writes into config.toml:
#   v3 -> bearer token (JWT from the _token cookie)
#   v2 -> "session=<cookie>"
#
# Credentials are cached for 11h in ~/.cache/mwaa-token (MWAA sessions last 12h),
# because flowrs reruns this command every 60s.
# Needs an active SSO session for the profile (aws sso login --profile <p>).

# This script uses zsh syntax. If started with sh or bash, restart it under zsh.
[ -n "$ZSH_VERSION" ] || exec zsh "$0" "$@"

profile=$1 env=$2 ver=$3
[[ -n $profile && -n $env && -n $ver ]] || {
  echo "usage: mwaa-token <aws-profile> <mwaa-env> <v2|v3>" >&2
  exit 1
}

cache=~/.cache/mwaa-token/$profile-$env-$ver
if [[ -s $cache ]] && (( $(date +%s) - $(stat -f %m $cache) < 39600 )); then
  cat $cache
  exit 0
fi

case $ver in
  v3) login_path=pluginsv2/aws_mwaa/login cookie=_token ;;
  v2) login_path=aws_mwaa/login           cookie=session ;;
  *)  echo "mwaa-token: version must be v2 or v3" >&2; exit 1 ;;
esac

read -r host token < <(aws mwaa create-web-login-token --name "$env" \
  --profile "$profile" --query '[WebServerHostname,WebToken]' --output text 2>/dev/null)
[[ -n $token ]] || {
  echo "mwaa-token: AWS login failed for $profile/$env (run: aws sso login --profile $profile)" >&2
  exit 1
}

val=$(curl -s -c - -o /dev/null -X POST "https://$host/$login_path" \
  --data-urlencode "token=$token" | awk -v n=$cookie '$6==n{print $7}')
[[ -n $val ]] || { echo "mwaa-token: Airflow login failed for $env (no $cookie cookie)" >&2; exit 1; }
[[ $ver == v2 ]] && val="session=$val"

umask 077
mkdir -p ${cache:h}
print -r -- "$val" > $cache
print -r -- "$val"
