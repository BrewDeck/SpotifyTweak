#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEOS_PATH="${THEOS:-/home/codespace/theos}"

if [ ! -d "$THEOS_PATH" ]; then
  echo "ERROR: Theos not found at $THEOS_PATH"
  exit 1
fi

export THEOS="$THEOS_PATH"
export PATH="$THEOS/bin:$PATH"

cd "$SCRIPT_DIR"

echo "Using THEOS=$THEOS"

if [ ! -f Makefile ]; then
  echo "ERROR: Makefile not found in $SCRIPT_DIR"
  exit 1
fi

make clean package

PACKAGE="${TWEAK_NAME:-SpotifyTweak}"-*.deb
if ls ./$PACKAGE 1> /dev/null 2>&1; then
  echo "Build succeeded. Package created:"
  ls -1 ./$PACKAGE
else
  echo "Build completed but package was not found." >&2
  exit 1
fi
