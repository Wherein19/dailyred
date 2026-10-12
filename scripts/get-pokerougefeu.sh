#!/usr/bin/env bash
# Recreates pokefirered-fr/ from a clean checkout: fetches qigast/pokerougefeu
# at the pinned commit and applies the Daily Red changes from patches/.
#
# That commit is pokerougefeu's newest master (2026-07-04). It merged
# pret/pokefirered at df4449a (2026-06-24). The English Daily Red pin,
# pret 037335f (2026-09-26), is three commits later and those commits do not
# touch any file the Daily Red changes edit. Rouge Feu is the default build.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GAME="$ROOT/pokefirered-fr"
PATCH="$ROOT/patches/pokerougefeu-dailyred.patch"
PRET_URL="https://github.com/qigast/pokerougefeu.git"
PRET_COMMIT="932b2ffc1b9567c6bc412f9ecf829308bca2c3b2"

if [ -e "$GAME" ]; then
  echo "pokefirered-fr/ already exists. Delete it first to start from a fresh copy."
  exit 1
fi

git init -q "$GAME"
# The decomp is LF-only. A global core.autocrlf=true (the Windows default)
# would check the sources out with CRLF and break the assembler.
git -C "$GAME" config core.autocrlf false
git -C "$GAME" remote add origin "$PRET_URL"
echo ">> Fetching qigast/pokerougefeu @ ${PRET_COMMIT:0:10}"
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
echo "Done. Build with: scripts/build-rom.sh --fr"
