#!/bin/zsh
# Export AWS credentials for Claude Code agent teams
# Reads AWS credentials from ~/.aws/.keys and outputs JSON

KEYS_FILE="$HOME/.aws/.keys"

# Check if keys file exists
if [[ ! -f "$KEYS_FILE" ]]; then
  echo "{\"error\": \"AWS keys file not found at $KEYS_FILE\"}" >&2
  exit 1
fi

# Source the keys file to load variables
source "$KEYS_FILE"

# Output JSON in the required format
cat <<EOF
{
  "Credentials": {
    "AccessKeyId": "$AWS_ACCESS_KEY_ID",
    "SecretAccessKey": "$AWS_SECRET_ACCESS_KEY",
    "SessionToken": "$AWS_SESSION_TOKEN"
  }
}
EOF
