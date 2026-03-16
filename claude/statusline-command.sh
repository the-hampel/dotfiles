#!/bin/sh
# Claude Code status line - derived from ~/.zshrc PROMPT
input=$(cat)
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
home="$HOME"
# Replace home directory with ~
display_dir=$(echo "$cwd" | sed "s|^$home|~|")
host=$(hostname -s)
git_branch=$(git -C "$cwd" --no-optional-locks branch 2>/dev/null | grep "^\*" | sed 's/^\* //')
time_str=$(date +%H:%M:%S)

# ANSI colors matching zsh %F{} codes:
# 214 = orange, 166 = dark orange, 142 = olive green, 108 = sage green, 246 = grey
c214=$'\033[38;5;214m'
c166=$'\033[38;5;166m'
c142=$'\033[38;5;142m'
c108=$'\033[38;5;108m'
c246=$'\033[38;5;246m'
reset=$'\033[0m'

if [ -n "$git_branch" ]; then
  branch_str=" (${c108}${git_branch}${reset})"
else
  branch_str=""
fi

printf "${c214}%s ${c166}[${c142}%s${c166}]${reset}%s ${c246}%s${reset}" \
  "$host" "$display_dir" "$branch_str" "$time_str"
