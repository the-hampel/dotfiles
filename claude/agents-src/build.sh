#!/usr/bin/env bash
# Build ~/git/dotfiles/claude/agents/<name>.md (installed as ~/.claude/agents via make install)
# from agents-src/<name>.md (frontmatter + role) + _common.md + _<family>.md.
# Family comes from "<!-- family: vasp|triqs|none -->" in the role file; "none" = role only.
set -euo pipefail
S=$(cd "$(dirname "$0")" && pwd); O=$S/../agents
P=$S/../../pi/agent/personas   # Pi variants: <n>.md (no frontmatter) + <n>.env (router bias)
mkdir -p "$O" "$P"; rm -f "$O"/*.md "$P"/*.md "$P"/*.env
for f in "$S"/[a-z]*.md; do
  n=$(basename "$f" .md)
  fam=$(grep -o '<!-- family: [a-z]* -->' "$f" | head -1 | sed 's/<!-- family: //; s/ -->//' || true)
  {
    sed '/<!-- family: [a-z]* -->/d' "$f"
    if [[ $fam != none ]]; then echo; cat "$S/_common.md"; fi
    if [[ -n $fam && $fam != none ]]; then cat "$S/_$fam.md"; fi
  } > "$O/$n.md"
  # Pi: strip YAML frontmatter; model: opus|sonnet becomes the d3-router bias.
  awk 'BEGIN{c=0} c<2 && /^---$/ {c++; next} c>=2' "$O/$n.md" > "$P/$n.md"
  m=$(sed -n '2,/^---$/s/^model: *//p' "$f" | head -1)
  case $m in *opus*) b=opus;; *sonnet*) b=sonnet;; *) b=neutral;; esac
  printf 'PI_PERSONA=%s\nPI_ROUTER_BIAS=%s\n' "$n" "$b" > "$P/$n.env"
done
echo "built: $(cd "$O" && echo *.md)"
