#!/usr/bin/env bash
# Builds a Daily Red ROM with the project-local toolchain
# (scripts/setup-macos.sh or scripts/setup-windows.sh) and puts a gzipped
# copy in web/game/ for the website.
#
#   scripts/build-rom.sh            # English FireRed ROM
#   scripts/build-rom.sh --fr       # French Rouge Feu ROM
#   scripts/build-rom.sh clean      # extra args are passed to make
#   scripts/build-rom.sh --fr clean
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TC="$ROOT/.toolchain"

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

# Parsed after the Windows re-entry so the flag is still in "$@".
LANG_CODE=en
if [ "${1:-}" = "--fr" ] || [ "${1:-}" = "fr" ]; then
  LANG_CODE=fr
  shift
fi

if [ "$LANG_CODE" = "fr" ]; then
  GAME="$ROOT/pokefirered-fr"
  ROM_BASENAME="pokerougefeu_modern.gba"
  WEB_ROM="dailyred-fr.gba.gz"
else
  GAME="$ROOT/pokefirered"
  ROM_BASENAME="pokefirered_modern.gba"
  WEB_ROM="dailyred.gba.gz"
fi

if [ ! -d "$GAME" ]; then
  if [ "$LANG_CODE" = "fr" ]; then
    echo "pokefirered-fr/ is missing. Run scripts/get-pokerougefeu.sh first."
  else
    echo "pokefirered/ is missing. Run scripts/get-pokefirered.sh first."
  fi
  exit 1
fi

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

# English keeps the original make command. French names Rouge Feu explicitly
# so the tree's LeafGreen target cannot be selected by a config default.
make_rom() {
  if [ "$LANG_CODE" = "fr" ]; then
    make -C "$GAME" -j"$JOBS" TOOLCHAIN="$TC/arm-none-eabi" MODERN=1 GAME_VERSION=FIRERED GAME_LANGUAGE=FRENCH "$@"
  else
    make -C "$GAME" -j"$JOBS" TOOLCHAIN="$TC/arm-none-eabi" MODERN=1 "$@"
  fi
}

if [ "$#" -gt 0 ]; then
  make_rom "$@"
  exit 0
fi

make_rom

ROM="$GAME/$ROM_BASENAME"
# The website downloads a gzipped copy (16 MB -> ~5.5 MB, mostly 0xFF padding)
# and unpacks it in the browser, so it stays small on any static host.
mkdir -p "$ROOT/web/game"
rm -f "$ROOT/web/game/${WEB_ROM%.gz}"
gzip -9 -n -c "$ROM" > "$ROOT/web/game/$WEB_ROM"
# RED's battle sprite for the site's title card. The French and English
# decomp sprites match, so both builds write the same web/game/red.png.
cp "$GAME/graphics/trainers/front_pics/red_front_pic.png" "$ROOT/web/game/red.png"
echo
echo "Built $ROM"
echo "Website copy: web/game/$WEB_ROM ($(wc -c < "$ROOT/web/game/$WEB_ROM" | tr -d ' ') bytes)"
