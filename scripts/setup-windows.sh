#!/usr/bin/env bash
# Installs everything needed to build the Daily Red ROM on Windows:
#
#   - Node.js 18+ (winget, OpenJS.NodeJS.LTS) when `node` is missing
#   - MSYS2 UCRT64 host tools: gcc, make, libpng, zlib, pkg-config
#     (winget installs MSYS2 itself when C:\msys64 is absent)
#   - xPack GNU Arm Embedded GCC 14.2.1-1.1 (win32-x64) into ./.toolchain
#     The Windows release is a zip, not the tar.gz the macOS script uses.
#     The tree is renamed to .toolchain/arm-none-eabi (no symlink: creating
#     one needs Developer Mode or an elevated shell).
#
# Run from Git Bash. Re-running is safe: finished steps are skipped.
# The ROM build (scripts/build-rom.sh) re-enters the UCRT64 environment.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TC="$ROOT/.toolchain"
mkdir -p "$TC/downloads"

GCC_VER="14.2.1-1.1"
MSYS_BASH="/c/msys64/usr/bin/bash.exe"

winget_install() {
  local id="$1"
  local winget
  winget="$(command -v winget || command -v winget.exe || true)"
  if [ -z "$winget" ]; then
    echo "winget is required to install $id."
    exit 1
  fi
  "$winget" install --id "$id" -e \
    --accept-package-agreements --accept-source-agreements \
    --disable-interactivity
}

if ! command -v node >/dev/null 2>&1 && ! command -v node.exe >/dev/null 2>&1; then
  if [ ! -x "/c/Program Files/nodejs/node.exe" ]; then
    echo ">> Installing Node.js LTS"
    winget_install OpenJS.NodeJS.LTS
  fi
  if [ -x "/c/Program Files/nodejs/node.exe" ]; then
    export PATH="/c/Program Files/nodejs:$PATH"
  fi
fi
if command -v node >/dev/null 2>&1; then
  echo ">> $(node --version)"
else
  echo "Node.js was installed but this shell cannot see it yet. Open a new terminal."
fi

if [ ! -x "$MSYS_BASH" ]; then
  echo ">> Installing MSYS2"
  winget_install MSYS2.MSYS2
fi
if [ ! -x "$MSYS_BASH" ]; then
  echo "MSYS2 was not found at C:\\msys64. Install it, then re-run this script."
  exit 1
fi

msys() {
  MSYSTEM=UCRT64 CHERE_INVOKING=1 "$MSYS_BASH" -lc "$1"
}

if ! msys "command -v gcc >/dev/null && command -v make >/dev/null && pkg-config --exists libpng"; then
  echo ">> Updating MSYS2 (the first upgrade may restart the MSYS2 runtime)"
  msys "pacman -Syu --noconfirm" || true
  msys "pacman -Syu --noconfirm"
  echo ">> Installing the host compiler, make and libpng"
  msys "pacman -S --noconfirm --needed make mingw-w64-ucrt-x86_64-gcc mingw-w64-ucrt-x86_64-libpng mingw-w64-ucrt-x86_64-zlib mingw-w64-ucrt-x86_64-pkgconf"
fi
msys "gcc --version | head -1"

GCC_NAME="xpack-arm-none-eabi-gcc-$GCC_VER"
if [ ! -x "$TC/arm-none-eabi/bin/arm-none-eabi-gcc.exe" ] && [ ! -x "$TC/arm-none-eabi/bin/arm-none-eabi-gcc" ]; then
  archive="$GCC_NAME-win32-x64.zip"
  url="https://github.com/xpack-dev-tools/arm-none-eabi-gcc-xpack/releases/download/v$GCC_VER/$archive"
  echo ">> Downloading $archive"
  curl -fL --retry 3 -o "$TC/downloads/$archive" "$url"
  curl -fsL -o "$TC/downloads/$archive.sha" "$url.sha"
  expected="$(awk '{print $1}' "$TC/downloads/$archive.sha")"
  actual="$(shasum -a 256 "$TC/downloads/$archive" | awk '{print $1}')"
  [ "$expected" = "$actual" ] || { echo "Checksum mismatch for $archive"; exit 1; }
  echo ">> Checksum OK, extracting"
  unzip -q -o "$TC/downloads/$archive" -d "$TC"
  rm -rf "$TC/arm-none-eabi"
  mv "$TC/$GCC_NAME" "$TC/arm-none-eabi"
  rm -f "$TC/downloads/$archive"
fi
"$TC/arm-none-eabi/bin/arm-none-eabi-gcc" --version | head -1
echo 'int f(void){return 0;}' | "$TC/arm-none-eabi/bin/arm-none-eabi-gcc" -x c -c -o "$TC/downloads/cc-test.o" -
rm -f "$TC/downloads/cc-test.o"

echo
echo "Toolchain ready. Next:"
echo "  scripts/get-pokefirered.sh"
echo "  scripts/fetch-vendor.sh"
echo "  scripts/build-rom.sh"
echo "  node scripts/serve.mjs"
