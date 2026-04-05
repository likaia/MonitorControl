#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
ACCOUNT_NAME="LumaGlass"
REPO_OWNER="likaia"
REPO_NAME="MonitorControl"

usage() {
  cat <<'EOF'
Usage:
  ./generate-appcast.sh <version> <zip-archive>

Example:
  ./generate-appcast.sh 1.2.0 /path/to/LumaGlass-1.2.0.zip

Notes:
  - The archive must be a .zip package containing LumaGlass.app.
  - Upload the same zip filename to the GitHub release tag v<version>.
  - The generated feed will overwrite ./appcast.xml
EOF
}

fail() {
  echo "Error: $*" >&2
  exit 1
}

VERSION="${1:-}"
ARCHIVE_PATH="${2:-}"

if [[ -z "$VERSION" || -z "$ARCHIVE_PATH" ]]; then
  usage
  exit 1
fi

if [[ ! -f "$ARCHIVE_PATH" ]]; then
  fail "Archive not found: $ARCHIVE_PATH"
fi

if [[ "${ARCHIVE_PATH##*.}" != "zip" ]]; then
  fail "Sparkle appcast generation expects a .zip archive, not $(basename "$ARCHIVE_PATH")."
fi

SPARKLE_BIN_DIR="$(find "$HOME/Library/Developer/Xcode/DerivedData" -path '*/SourcePackages/artifacts/sparkle/Sparkle/bin' -type d | head -n 1)"

if [[ -z "$SPARKLE_BIN_DIR" ]]; then
  fail "Sparkle tools not found. Build the app once in Xcode first so SwiftPM downloads Sparkle tools."
fi

GENERATE_KEYS_BIN="$SPARKLE_BIN_DIR/generate_keys"
GENERATE_APPCAST_BIN="$SPARKLE_BIN_DIR/generate_appcast"

if [[ ! -x "$GENERATE_KEYS_BIN" || ! -x "$GENERATE_APPCAST_BIN" ]]; then
  fail "Sparkle generate_keys / generate_appcast executables are missing."
fi

if ! "$GENERATE_KEYS_BIN" --account "$ACCOUNT_NAME" -p >/dev/null 2>&1; then
  echo "No Sparkle signing key found for account '$ACCOUNT_NAME'. Generating one now..."
  "$GENERATE_KEYS_BIN" --account "$ACCOUNT_NAME"
fi

TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/lumaglass-appcast.XXXXXX")"
trap 'rm -rf "$TEMP_DIR"' EXIT

ARCHIVE_NAME="$(basename "$ARCHIVE_PATH")"
cp "$ARCHIVE_PATH" "$TEMP_DIR/$ARCHIVE_NAME"

"$GENERATE_APPCAST_BIN" \
  --account "$ACCOUNT_NAME" \
  --download-url-prefix "https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/download/v${VERSION}/" \
  --link "https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/tag/v${VERSION}" \
  --full-release-notes-url "https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/tag/v${VERSION}" \
  -o "$ROOT_DIR/appcast.xml" \
  "$TEMP_DIR"

echo "Updated $ROOT_DIR/appcast.xml"
echo "Next:"
echo "1. Commit and push appcast.xml"
echo "2. Create the GitHub release tag v${VERSION}"
echo "3. Upload the archive asset named ${ARCHIVE_NAME}"
