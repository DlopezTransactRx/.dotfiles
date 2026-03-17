#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Extract values
model_id=$(echo "$input" | jq -r '.model.id // "unknown"')
model_display=$(echo "$input" | jq -r '.model.display_name // "Claude"')
project_dir=$(echo "$input" | jq -r '.workspace.project_dir // .workspace.current_dir // ""')
session_start=$(echo "$input" | jq -r '.session_start // empty')
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

# Calculate cost (placeholder - you'll need actual token costs)
total_input=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
total_output=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
# Rough cost estimation (adjust rates as needed)
cost=$(echo "scale=2; ($total_input * 0.000003) + ($total_output * 0.000015)" | bc -l 2>/dev/null || echo "0.00")

# Calculate elapsed time (if session_start is available)
elapsed="0m 0s"
if [ -n "$session_start" ]; then
    start_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${session_start:0:19}" "+%s" 2>/dev/null || echo "0")
    now_epoch=$(date +%s)
    if [ "$start_epoch" -gt 0 ]; then
        elapsed_seconds=$((now_epoch - start_epoch))
        minutes=$((elapsed_seconds / 60))
        seconds=$((elapsed_seconds % 60))
        elapsed="${minutes}m ${seconds}s"
    fi
fi

# ANSI color codes (dimmed as noted)
RESET="\033[0m"
DIM="\033[2m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
CYAN="\033[36m"

# Build status line
printf "${DIM}[${RESET}%s${DIM}]${RESET} ${BLUE}📁${RESET} %s ${DIM}|${RESET} ${GREEN}🌿${RESET} %s ${GREEN}%s${RESET} ${CYAN}%d%%${RESET} ${DIM}|${RESET} ${YELLOW}\$%s${RESET} ${DIM}|${RESET} 🕐 %s" \
    "$model_short" \
    "$project_name" \
    "$git_branch" \
    "$progress" \
    "$used_percent" \
    "$cost" \
    "$elapsed"
