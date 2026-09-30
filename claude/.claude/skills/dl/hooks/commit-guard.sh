#!/usr/bin/env bash
# Blocks `git commit` / `git push` unless the user's latest message asked for it.
#
#   commit-guard.sh prompt  UserPromptSubmit: allow commits for this request when
#                           the message says commit, push, or promote; revoke otherwise
#   commit-guard.sh bash    PreToolUse(Bash): deny git commit/push when not allowed
#
# The allowance is per session and per request, so subagents and background
# work launched from a "commit it" request can commit; nothing else can.
set -uo pipefail

STATE_DIR="${HOME}/.claude/state/dl-commit-guard"
input="$(cat)"
session="$(jq -r '.session_id // "unknown"' <<<"$input")"
flag="${STATE_DIR}/${session}"

case "${1:-}" in
  prompt)
    mkdir -p "$STATE_DIR"
    prompt="$(jq -r '.prompt // ""' <<<"$input")"
    if grep -qiE '(^|[^a-z])(commit|push|promote)([^a-z]|$)' <<<"$prompt"; then
      touch "$flag"
    else
      rm -f "$flag"
    fi
    # Drop allowances from sessions idle for over a day.
    find "$STATE_DIR" -type f -mtime +1 -delete 2>/dev/null
    exit 0
    ;;
  bash)
    command="$(jq -r '.tool_input.command // ""' <<<"$input")"
    # `git` at the start of a command segment, optional -C/-c options, then commit or push.
    if grep -qE '(^|[;&|(]|&&|\|\|)[[:space:]]*git([[:space:]]+-[Cc][[:space:]]+[^[:space:]]+)*[[:space:]]+(commit|push)([[:space:]]|$)' <<<"$command"; then
      if [[ ! -f "$flag" ]]; then
        jq -n '{hookSpecificOutput: {
          hookEventName: "PreToolUse",
          permissionDecision: "deny",
          permissionDecisionReason: "Commit guard: the user has not asked to commit or push in this request. Leave the changes unstaged for review, and ask if you think a commit is needed."
        }}'
      fi
    fi
    exit 0
    ;;
esac
exit 0
