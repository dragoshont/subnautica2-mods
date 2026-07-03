#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${1:-dist}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if command -v pwsh >/dev/null 2>&1; then
  pwsh -NoProfile -ExecutionPolicy Bypass -File "$ROOT/scripts/package.ps1" -OutDir "$OUT_DIR"
elif command -v powershell >/dev/null 2>&1; then
  powershell -NoProfile -ExecutionPolicy Bypass -File "$ROOT/scripts/package.ps1" -OutDir "$OUT_DIR"
else
  if ! command -v zip >/dev/null 2>&1 || ! command -v shasum >/dev/null 2>&1; then
    echo "PowerShell, or zip plus shasum, is required for local packaging." >&2
    exit 127
  fi

  VERSION="${GITHUB_REF_NAME:-local}"
  MOD_NAME="SN2-NeverNight-UE4SS"
  rm -rf "$ROOT/$OUT_DIR"
  mkdir -p "$ROOT/$OUT_DIR/$MOD_NAME/NeverNight/Scripts"
  cp "$ROOT/README.md" "$ROOT/$OUT_DIR/$MOD_NAME/README.md"
  cp "$ROOT/NeverNight/Scripts/main.lua" "$ROOT/$OUT_DIR/$MOD_NAME/NeverNight/Scripts/main.lua"
  (
    cd "$ROOT/$OUT_DIR"
    zip -r -q "$MOD_NAME-$VERSION.zip" "$MOD_NAME"
  )
  shasum -a 256 "$ROOT/$OUT_DIR"/*.zip > "$ROOT/$OUT_DIR/SHA256SUMS.txt"
  cat "$ROOT/$OUT_DIR/SHA256SUMS.txt"
fi
