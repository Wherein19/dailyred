#!/usr/bin/env bash
# Saves every change made inside a decomp tree (edited and new files) to
# patches/. Run it after editing the game, and commit the patch: the trees
# themselves aren't tracked by this repository.
#
#   scripts/save-patch.sh       # pokefirered/ → patches/pokefirered-dailyred.patch
#   scripts/save-patch.sh --fr  # pokefirered-fr/ → patches/pokerougefeu-dailyred.patch
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [ "${1:-}" = "--fr" ] || [ "${1:-}" = "fr" ]; then
  GAME="$ROOT/pokefirered-fr"
  PATCH="$ROOT/patches/pokerougefeu-dailyred.patch"
else
  GAME="$ROOT/pokefirered"
  PATCH="$ROOT/patches/pokefirered-dailyred.patch"
fi

# Mark new files as "intent to add" so they appear in the diff (ignored build
# outputs stay out, thanks to pokefirered's own .gitignore).
git -C "$GAME" add --intent-to-add .
git -C "$GAME" diff --binary HEAD > "$PATCH"
git -C "$GAME" diff --stat HEAD | tail -1
echo "Saved ${PATCH#"$ROOT"/}"
