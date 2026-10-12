#!/usr/bin/env bash
# Builds the modified FireRed ROM with the project-local toolchain
# (scripts/setup-macos.sh or scripts/setup-windows.sh) and puts a gzipped
# copy in web/game/ for the website.
#
#   scripts/build-rom.sh            # normal build
#   scripts/build-rom.sh clean      # any extra args are passed to make
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TC="$ROOT/.toolchain"
GAME="$ROOT/pokefirered"

# Host gcc, make and libpng come from MSYS2 UCRT64. Git Bash can launch this
# script; the build itself re-enters that environment so the compiler, make
# and pkg-config all match.
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    if [ "${MSYSTEM:-}" != "UCRT64" ]; then
      msys_bash="/c/msys64/usr/bin/bash.exe"
      if [ ! -x "$msys_bash" ]; then
        echo "MSYS2 UCRT64 is required. Run scripts/setup-windows.sh first."
        exit 1
      fi
      export MSYSTEM=UCRT64
      export CHERE_INVOKING=1
      exec "$msys_bash" -lc 'cd "$1" && shift && exec scripts/build-rom.sh "$@"' _ "$ROOT" "$@"
    fi
    # win-shims sits in front of the host compiler. The Makefile then
    # prepends the ARM toolchain; the shims put the host compiler's own
    # DLLs back first (see scripts/win-shims/cc).
    export PATH="$ROOT/scripts/win-shims:/ucrt64/bin:$PATH"
    # MSYS2's login shell drops Windows' OS variable. pokefirered uses it to
    # append .exe to host tools; without it, gcc writes tool.exe and make
    # looks for a file with no extension.
    export OS="${OS:-Windows_NT}"
    ;;
esac

if [ ! -x "$TC/arm-none-eabi/bin/arm-none-eabi-gcc" ] && [ ! -x "$TC/arm-none-eabi/bin/arm-none-eabi-gcc.exe" ]; then
  echo "Toolchain missing. On macOS run scripts/setup-macos.sh; on Windows run scripts/setup-windows.sh."
  exit 1
fi

# gbagfx asks pkg-config for libpng. On macOS the project-local static libpng
# is found via CPATH/LIBRARY_PATH, and a no-op pkg-config keeps the tool
# Makefiles quiet. On Windows, MSYS2's pkg-config points at its own libpng.
if [ -d "$TC/libpng/include" ]; then
  export CPATH="$TC/libpng/include${CPATH:+:$CPATH}"
  export LIBRARY_PATH="$TC/libpng/lib${LIBRARY_PATH:+:$LIBRARY_PATH}"
fi
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    if ! command -v pkg-config >/dev/null 2>&1; then
      export PATH="$ROOT/scripts/shims:$PATH"
    fi
    ;;
  *)
    export PATH="$ROOT/scripts/shims:$PATH"
    ;;
esac

JOBS="$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo "${NUMBER_OF_PROCESSORS:-1}")"

# Windows refuses command lines longer than 8191 characters. The link recipe
# lists every object file, so the tail of the list is cut off and the ROM
# fails to link. GNU ld will read the list from a response file instead.
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    if grep -q '\$(LD).*\$(OBJS_REL)' "$GAME/Makefile"; then
      awk '
        index($0, "$(LD)") && index($0, "$(OBJS_REL)") {
          print "\t$(file >$(OBJ_DIR)/objs.rsp,$(OBJS_REL))"
          gsub(/\$\(OBJS_REL\)/, "@objs.rsp")
        }
        { print }
      ' "$GAME/Makefile" > "$GAME/Makefile.win" && mv "$GAME/Makefile.win" "$GAME/Makefile"
    fi
    ;;
esac

if [ "$#" -gt 0 ]; then
  make -C "$GAME" -j"$JOBS" TOOLCHAIN="$TC/arm-none-eabi" MODERN=1 "$@"
  exit 0
fi

make -C "$GAME" -j"$JOBS" TOOLCHAIN="$TC/arm-none-eabi" MODERN=1

ROM="$GAME/pokefirered_modern.gba"
# The website downloads a gzipped copy (16 MB -> ~5.5 MB, mostly 0xFF padding)
# and unpacks it in the browser, so it stays small on any static host.
mkdir -p "$ROOT/web/game"
rm -f "$ROOT/web/game/dailyred.gba"
gzip -9 -n -c "$ROM" > "$ROOT/web/game/dailyred.gba.gz"
# RED's battle sprite for the site's title card (from the decomp, like the ROM).
cp "$GAME/graphics/trainers/front_pics/red_front_pic.png" "$ROOT/web/game/red.png"
echo
echo "Built $ROM"
echo "Website copy: web/game/dailyred.gba.gz ($(wc -c < "$ROOT/web/game/dailyred.gba.gz" | tr -d ' ') bytes)"
