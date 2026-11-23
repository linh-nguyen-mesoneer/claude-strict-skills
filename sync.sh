#!/usr/bin/env bash
# Copy the bundled skills from ~/.claude/skills (the source of truth) into the
# plugin. Run after editing a skill, then bump the version in plugin.json.
set -euo pipefail

readonly SRC="${SKILLS_SRC:-$HOME/.claude/skills}"
readonly DEST="$(cd "$(dirname "$0")" && pwd)/plugins/strict-workflow/skills"
readonly SKILLS=(
  planning-strict
  architecture-strict
  investigation-strict
  executing-plans-strict
  subagent-driven-strict
  code-review-strict
  finishing-branch-strict
)

for s in "${SKILLS[@]}"; do
  [ -f "$SRC/$s/SKILL.md" ] || { echo "sync: missing $SRC/$s/SKILL.md" >&2; exit 1; }
done

rm -rf "$DEST"
mkdir -p "$DEST"
for s in "${SKILLS[@]}"; do
  cp -R "$SRC/$s" "$DEST/$s"
done
echo "synced ${#SKILLS[@]} skills into $DEST"
