#!/usr/bin/env bash
# Claude Code status line: context %, rate limits, model

input=$(cat)

# ── Colors ──
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
MAGENTA='\033[35m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

# ── Parse JSON fields ──
model=$(echo "$input" | jq -r '.model.display_name // "Unknown"')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
five_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
week_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
week_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

# ── Git info ──
branch=""
repo=""
if [ -n "$cwd" ]; then
  branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
  repo=$(basename "$(git -C "$cwd" --no-optional-locks rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null)
fi

# ── Context part (symbol + percent, no bar) ──
if [ -n "$used" ]; then
  used_int=$(printf '%.0f' "$used")
  if   [ "$used_int" -ge 90 ]; then status_emoji="🚨"; pct_color="$RED"
  elif [ "$used_int" -ge 70 ]; then status_emoji="🔥"; pct_color="$YELLOW"
  elif [ "$used_int" -ge 20 ]; then status_emoji="⚡"; pct_color="$GREEN"
  else                               status_emoji="🟢"; pct_color="$GREEN"; fi
  ctx_part="${status_emoji} ctx:${pct_color}${used_int}%${RESET}"
else
  ctx_part="🟢 ctx:${DIM}--%${RESET}"
fi

# ── Format reset epoch to human-readable ──
fmt_reset() {
  local epoch="$1" fmt="$2"
  [ -z "$epoch" ] && return
  date -d "@$epoch" "$fmt" 2>/dev/null || date -r "$epoch" "$fmt" 2>/dev/null
}

# ── 5-hour usage ──
if [ -n "$five_pct" ]; then
  five_int=$(printf '%.0f' "$five_pct")
  if   [ "$five_int" -ge 80 ]; then five_color="$RED"
  elif [ "$five_int" -ge 50 ]; then five_color="$YELLOW"
  else                               five_color="$GREEN"; fi
  five_reset_str=$(fmt_reset "$five_reset" "+%H:%M")
  five_part="${five_color}5h:${five_int}%${RESET}"
  [ -n "$five_reset_str" ] && five_part="${five_part}${DIM}(r:${five_reset_str})${RESET}"
else
  five_part="${DIM}5h:--%${RESET}"
fi

# ── 7-day usage ──
if [ -n "$week_pct" ]; then
  week_int=$(printf '%.0f' "$week_pct")
  if   [ "$week_int" -ge 80 ]; then week_color="$RED"
  elif [ "$week_int" -ge 50 ]; then week_color="$YELLOW"
  else                               week_color="$GREEN"; fi
  week_reset_str=$(fmt_reset "$week_reset" "+%a %H:%M")
  week_part="${week_color}7d:${week_int}%${RESET}"
  [ -n "$week_reset_str" ] && week_part="${week_part}${DIM}(r:${week_reset_str})${RESET}"
else
  week_part="${DIM}7d:--%${RESET}"
fi

# ── Single line ──
out=""
[ -n "$repo" ]   && out="${BOLD}${YELLOW}${repo}${RESET}"
[ -n "$branch" ] && out="${out:+$out }${BOLD}${CYAN}(${branch})${RESET}"
out="${out} ${DIM}|${RESET} ${five_part} ${week_part}"
out="${out:+$out ${DIM}|${RESET} }${ctx_part}"
out="${out} ${DIM}|${RESET} ${MAGENTA}🤖 ${model}${RESET}"

printf '%b' "$out"
