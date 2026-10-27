#!/bin/bash
input=$(cat)
cwd=$(echo "$input" | jq -r '.workspace.current_dir')
cwd_display=$(echo "$cwd" | sed "s|^$HOME|~|")
time=$(date +%H:%M:%S)

# Model name + version
model=$(echo "$input" | jq -r '.model.display_name')
version=$(echo "$input" | jq -r '.version // empty')
version_display=""
[ -n "$version" ] && version_display=" v${version}"

# Session name (line 1) + full resume command (line 3, copy-paste friendly)
session_name=$(echo "$input" | jq -r '.session_name // empty')
session_id=$(echo "$input" | jq -r '.session_id // empty')

session_display=""
[ -n "$session_name" ] && session_display=" — ${session_name}"

resume_display=""
[ -n "$session_id" ] && resume_display="claude --resume ${session_id}"

# Effort level (xhigh / high / medium / low / auto) — appended to model
effort=$(echo "$input" | jq -r '.effort.level // empty')
effort_suffix=""
[ -n "$effort" ] && effort_suffix=" (${effort})"

# Context window usage
ctx_used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
context_display=""
[ -n "$ctx_used" ] && context_display="🧠 ctx:${ctx_used}%"

# Session cost
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
cost_display=""
if [ -n "$cost" ] && [ "$cost" != "null" ]; then
  cost_display=$(printf "💰 \$%.2f" "$cost")
fi

# Git branch
branch=""
if cd "$cwd" 2>/dev/null && git rev-parse --git-dir >/dev/null 2>&1; then
  b=$(git --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
  [ -n "$b" ] && branch=" ($b)"
fi

# Format remaining seconds → human friendly
fmt_remain() {
  local sec=$1
  if [ "$sec" -le 0 ]; then
    echo "満了"
  elif [ "$sec" -ge 86400 ]; then
    printf "%dd%dh" $((sec / 86400)) $(((sec % 86400) / 3600))
  elif [ "$sec" -ge 3600 ]; then
    printf "%dh%02dm" $((sec / 3600)) $(((sec % 3600) / 60))
  else
    printf "%dm" $((sec / 60))
  fi
}

now_epoch=$(date +%s)

# 5h rate limit (from Claude Code official input JSON)
five_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
five_display=""
if [ -n "$five_pct" ] && [ -n "$five_reset" ]; then
  five_display=$(printf "⌛️ 5h 残%d%% (%s)" \
    "$((100 - five_pct))" "$(fmt_remain $((five_reset - now_epoch)))")
fi

# 7day rate limit
seven_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
seven_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')
seven_display=""
if [ -n "$seven_pct" ] && [ -n "$seven_reset" ]; then
  seven_display=$(printf "🔄 7d 残%d%% (%s)" \
    "$((100 - seven_pct))" "$(fmt_remain $((seven_reset - now_epoch)))")
fi

join_pipe() {
  local out=""
  for part in "$@"; do
    [ -z "$part" ] && continue
    if [ -z "$out" ]; then
      out="$part"
    else
      out="${out} | ${part}"
    fi
  done
  printf "%s" "$out"
}

# Line 1: location + session name
printf "[%s] %s%s%s" "$time" "$cwd_display" "$branch" "$session_display"

# Line 2: 🤖 model (effort) v… + 🧠 ctx + 💰 cost + ⌛ 5h + 🔄 7d
line2=$(join_pipe "🤖 ${model}${effort_suffix}${version_display}" \
  "$context_display" "$cost_display" \
  "$five_display" "$seven_display")
[ -n "$line2" ] && printf "\n%s" "$line2"

# Line 3: full resume command (copy-paste friendly)
[ -n "$resume_display" ] && printf "\n%s" "$resume_display"
