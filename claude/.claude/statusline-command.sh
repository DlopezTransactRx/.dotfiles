#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Extract values
model_id=$(echo "$input" | jq -r '.model.id // "unknown"')
model_display=$(echo "$input" | jq -r '.model.display_name // "Claude"')
project_dir=$(echo "$input" | jq -r '.workspace.project_dir // .workspace.current_dir // ""')
session_name=$(echo "$input" | jq -r '.session_name // empty')
cost_usd=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
duration_ms=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
used_percent=$(echo "$input" | jq -r '.context_window.used_percentage // 0')

# Determine model short name
if [[ "$model_id" == *"opus"* ]]; then
    model_short="Opus"
elif [[ "$model_id" == *"sonnet"* ]]; then
    model_short="Sonnet"
elif [[ "$model_id" == *"haiku"* ]]; then
    model_short="Haiku"
else
    model_short=$(echo "$model_display" | cut -d' ' -f1)
fi

# Get project name from directory
if [ -n "$project_dir" ]; then
    project_name=$(basename "$project_dir")
else
    project_name="~"
fi

# Get git branch (skip locks for performance)
git_branch=""
if [ -d "$project_dir/.git" ]; then
    git_branch=$(cd "$project_dir" 2>/dev/null && git -c core.fileMode=false -c core.preloadindex=true branch --show-current 2>/dev/null || echo "")
fi
if [ -z "$git_branch" ]; then
    git_branch="no-branch"
fi

# Calculate progress bar for context usage
bar_width=10
filled=$(printf "%.0f" $(echo "$used_percent * $bar_width / 100" | bc -l 2>/dev/null || echo "0"))
[ "$filled" -lt 0 ] && filled=0
[ "$filled" -gt "$bar_width" ] && filled=$bar_width
empty=$((bar_width - filled))

# Build progress bar with green filled and dotted remaining
progress=""
for ((i=0; i<filled; i++)); do
    progress+="█"
done
for ((i=0; i<empty; i++)); do
    progress+="·"
done

# Cost as reported by Claude Code (list-price estimate, all models)
cost=$(printf "%.2f" "$cost_usd" 2>/dev/null || echo "0.00")

# Elapsed session time as reported by Claude Code
duration_s=$(( ${duration_ms%.*} / 1000 ))
elapsed="$((duration_s / 60))m $((duration_s % 60))s"

# ANSI color codes (dimmed as noted)
RESET="\033[0m"
DIM="\033[2m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
CYAN="\033[36m"
MAGENTA="\033[35m"
NAME_GREEN="\033[1;92m"  # bold bright green

# Session name segment (only when the session has a name or title)
name_segment=""
if [ -n "$session_name" ]; then
    name_segment=" ${MAGENTA}🏷${RESET} ${NAME_GREEN}${session_name}${RESET} ${DIM}|${RESET}"
fi

# Build status line
printf "${DIM}[${RESET}%s${DIM}]${RESET}%b ${BLUE}📁${RESET} %s ${DIM}|${RESET} ${GREEN}🌿${RESET} %s ${GREEN}%s${RESET} ${CYAN}%d%%${RESET} ${DIM}|${RESET} ${YELLOW}\$%s${RESET} ${DIM}|${RESET} 🕐 %s" \
    "$model_short" \
    "$name_segment" \
    "$project_name" \
    "$git_branch" \
    "$progress" \
    "$used_percent" \
    "$cost" \
    "$elapsed"
