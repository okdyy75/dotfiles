#!/bin/bash
input=$(cat)
cwd=$(echo "$input" | jq -r '.workspace.current_dir')
cwd_display=$(echo "$cwd" | sed "s|^$HOME|~|")
time=$(date +%H:%M:%S)

# Model name
model=$(echo "$input" | jq -r '.model.display_name')

# Context window usage
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
if [ -n "$used" ]; then
  context="[${used}%]"
else
  context=""
fi

# Git branch info
branch=""
if cd "$cwd" 2>/dev/null && git rev-parse --git-dir >/dev/null 2>&1; then
  branch=$(git --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
  if [ -n "$branch" ]; then
    branch=" ($branch)"
  fi
fi

printf "[%s] %s%s | %s %s" "$time" "$cwd_display" "$branch" "$model" "$context"
