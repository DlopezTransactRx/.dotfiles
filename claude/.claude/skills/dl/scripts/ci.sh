#!/usr/bin/env bash
# Deterministic steps shared by the dl:watchci and dl:promote skills. The skills
# decide what to commit and write the messages; this script handles branches,
# CI watching, change lists, and URLs. Run it from inside the repo.
#
#   ci.sh branch-name <name>  normalize Dev/Prod shorthand to Development/Production
#   ci.sh watch <branch>      watch CI on the newest commit of origin/<branch>,
#                             open the finished run(s), list what changed
#   ci.sh dev-check           verify this repo can take /promote Development
#   ci.sh work-branch         switch to feature/dlopez, creating it from origin/Development
#   ci.sh prod-check          list what Development -> Production would promote
#   ci.sh pr-url <head> <base>  print the open PR URL for head -> base, if any
set -euo pipefail

repo_name() { basename "$(git rev-parse --show-toplevel)"; }

branch_name() {
  case "$(tr '[:upper:]' '[:lower:]' <<<"$1")" in
    dev|development)  echo Development ;;
    prod|production)  echo Production ;;
    *)                echo "$1" ;;
  esac
}

require_remote_branch() {
  if ! git rev-parse --verify --quiet "origin/$1" >/dev/null; then
    echo "error: origin/$1 does not exist in $(repo_name)" >&2; exit 1
  fi
}

# Uses the REST API, not `gh run view/watch`: those 404 when the run's
# workflow file was later renamed or deleted.
cmd_watch() {
  local branch sha ids=""
  branch="$(branch_name "$1")"
  git fetch --quiet origin
  require_remote_branch "$branch"
  sha="$(git rev-parse "origin/$branch")"
  echo "WATCHING: $branch at ${sha:0:7} $(git log -1 --format=%s "$sha")"

  # Runs can take a few seconds to register after a push or merge.
  for _ in $(seq 1 18); do
    ids="$(gh run list --branch "$branch" --commit "$sha" --json databaseId --jq '.[].databaseId')"
    [[ -n "$ids" ]] && break
    sleep 5
  done
  if [[ -z "$ids" ]]; then
    echo "NO_RUNS: no workflow run started for ${sha:0:7} on $branch after 90s"
    print_changes "$branch" "$sha"
    exit 3
  fi

  # Open only what matters: every failed run, or when all pass, just the run
  # that finished last (the final build/deploy), not each precheck.
  local failed=0 id run url ended last_url="" last_end="" failed_urls=()
  for id in $ids; do
    run="repos/{owner}/{repo}/actions/runs/$id"
    url="$(gh api "$run" --jq .html_url)"
    while [[ "$(gh api "$run" --jq .status)" != "completed" ]]; do sleep 15; done
    echo "RUN_URL=$url"
    gh api "$run" --jq '"WORKFLOW: \(.name) -> \(.conclusion) (\(.run_started_at) to \(.updated_at))"'
    gh api "$run/jobs" --jq '.jobs[] | "  \(.name): \(.conclusion)"'
    if [[ "$(gh api "$run" --jq .conclusion)" != "success" ]]; then
      failed=1
      failed_urls+=("$url")
      local job
      for job in $(gh api "$run/jobs" --jq '.jobs[] | select(.conclusion == "failure") | .id'); do
        echo "--- failed job $job log (last 80 lines) ---"
        gh api "repos/{owner}/{repo}/actions/jobs/$job/logs" 2>/dev/null | tail -80 || true
      done
    fi
    ended="$(gh api "$run" --jq .updated_at)"   # ISO 8601 UTC, sorts as text
    if [[ -z "$last_end" || "$ended" > "$last_end" ]]; then
      last_end="$ended"; last_url="$url"
    fi
  done
  # `gh --web` is a no-op in background sessions; macOS `open` always works.
  if (( failed )); then
    for url in "${failed_urls[@]}"; do open "$url"; done
  else
    open "$last_url"
  fi
  print_changes "$branch" "$sha"
  exit "$failed"
}

# What landed in this commit: the PRs it belongs to and their commits, or the
# commits ahead of Development when there is no PR yet.
print_changes() {
  local branch="$1" sha="$2" prs
  echo "--- changes ---"
  prs="$(gh api "repos/{owner}/{repo}/commits/$sha/pulls" --jq '.[].number' 2>/dev/null || true)"
  if [[ -n "$prs" ]]; then
    local n
    for n in $prs; do
      gh pr view "$n" --json number,title,headRefName,baseRefName \
        --jq '"PR #\(.number) \(.title) (\(.headRefName) -> \(.baseRefName))"'
      gh pr view "$n" --json commits --jq '.commits[] | "  - \(.messageHeadline)"'
    done
  elif [[ "$branch" != "Development" ]] && git rev-parse --verify --quiet origin/Development >/dev/null; then
    git log --format='  - %s' "origin/Development..$sha"
  else
    git log -1 --format='  - %s' "$sha"
  fi
}

cmd_dev_check() {
  # me.md says SnowflakeWHAdministration commits to Development, which conflicts
  # with "never commit directly to Development". Blocked until that is settled.
  if [[ "$(repo_name)" == "SnowflakeWHAdministration" ]]; then
    echo "error: SnowflakeWHAdministration has no feature/dlopez flow yet; ask how this repo should promote to Development" >&2
    exit 4
  fi
  git fetch --quiet origin
  require_remote_branch Development
  echo "WORK=feature/dlopez BASE=Development"
}

cmd_work_branch() {
  if [[ "$(git branch --show-current)" == "feature/dlopez" ]]; then
    echo "on feature/dlopez"
  elif git rev-parse --verify --quiet refs/heads/feature/dlopez >/dev/null; then
    git switch feature/dlopez   # uncommitted changes carry over; git refuses on conflict
  elif git rev-parse --verify --quiet refs/remotes/origin/feature/dlopez >/dev/null; then
    git switch --track origin/feature/dlopez
  else
    git switch -c feature/dlopez origin/Development
  fi
}

cmd_prod_check() {
  git fetch --quiet origin
  require_remote_branch Development
  require_remote_branch Production
  local count
  count="$(git rev-list --count origin/Production..origin/Development)"
  if [[ "$count" == "0" ]]; then
    echo "NOTHING: Development has no commits that Production lacks"; exit 3
  fi
  echo "COMMITS=$count"
  git log --format='  - %h %s' origin/Production..origin/Development
}

cmd_pr_url() {
  gh pr list --head "$1" --base "$2" --state open --json url --jq '.[0].url // empty'
}

case "${1:-}" in
  branch-name) branch_name "${2:?branch}" ;;
  watch)       cmd_watch "${2:?branch}" ;;
  dev-check)   cmd_dev_check ;;
  work-branch) cmd_work_branch ;;
  prod-check)  cmd_prod_check ;;
  pr-url)      cmd_pr_url "${2:?head}" "${3:?base}" ;;
  *) echo "usage: ci.sh branch-name|watch|dev-check|work-branch|prod-check|pr-url" >&2; exit 2 ;;
esac
