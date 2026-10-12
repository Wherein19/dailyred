#!/usr/bin/env bash
# Recreates pokefirered/ from a clean checkout: fetches pret/pokefirered at the
# pinned commit and applies the Daily Red changes from patches/.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GAME="$ROOT/pokefirered"
PATCH="$ROOT/patches/pokefirered-dailyred.patch"
PRET_URL="https://github.com/pret/pokefirered.git"
PRET_COMMIT="037335f4c725d7c9aecdac87066f2002b4bd7e14"

if [ -e "$GAME" ]; then
  echo "pokefirered/ already exists. Delete it first to start from a fresh copy."
  exit 1
fi

git init -q "$GAME"
# The decomp is LF-only. A global core.autocrlf=true (the Windows default)
# would check the sources out with CRLF and break the assembler.
git -C "$GAME" config core.autocrlf false
git -C "$GAME" remote add origin "$PRET_URL"
echo ">> Fetching pret/pokefirered @ ${PRET_COMMIT:0:10}"
git -C "$GAME" fetch -q --depth 1 origin "$PRET_COMMIT"
git -C "$GAME" checkout -q FETCH_HEAD
echo ">> Applying $(basename "$PATCH")"
if ! git -C "$GAME" apply --check --whitespace=nowarn "$PATCH" 2>/dev/null; then
  # Git 2.47+ rejects "GIT binary patch" hunks that omit ---/+++ lines when
  # -p1 strips a path component. `git diff --binary` from older Git omits
  # those lines for new binary files. Restore them and retry.
  echo ">> Adjusting binary patch headers for this Git"
  fixed="$(mktemp)"
  awk '
    /^diff --git / {
      print
      line = $0
      sub(/^diff --git a\//, "", line)
      oldp = line
      sub(/ b\/.*$/, "", oldp)
      newp = line
      sub(/^.* b\//, "", newp)
      sawdash = 0
      newfile = 0
      deleted = 0
      next
    }
    /^new file mode / { newfile = 1 }
    /^deleted file mode / { deleted = 1 }
    /^--- / { sawdash = 1 }
    /^GIT binary patch/ && !sawdash {
      if (newfile) print "--- /dev/null"
      else print "--- a/" oldp
      if (deleted) print "+++ /dev/null"
      else print "+++ b/" newp
    }
    { print }
  ' "$PATCH" > "$fixed"
  git -C "$GAME" apply --whitespace=nowarn "$fixed"
  rm -f "$fixed"
else
  git -C "$GAME" apply --whitespace=nowarn "$PATCH"
fi
echo "Done. Build with: scripts/build-rom.sh"
