#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${1:-dist}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${GITHUB_REF_NAME:-local}"
MOD_NAME="SN2-NeverNight-UE4SS"
INSTALLER_NAME="SN2NeverNightInstaller"

cd "$ROOT"
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR/$MOD_NAME/NeverNight/Scripts"
cp README.md "$OUT_DIR/$MOD_NAME/README.md"
cp NeverNight/Scripts/main.lua "$OUT_DIR/$MOD_NAME/NeverNight/Scripts/main.lua"
(
  cd "$OUT_DIR"
  zip -r -q "$MOD_NAME-$VERSION.zip" "$MOD_NAME"
)

if command -v dotnet >/dev/null 2>&1; then
  dotnet publish src/SN2NeverNightInstaller/SN2NeverNightInstaller.csproj \
    -c Release \
    -r win-x64 \
    --self-contained true \
    -p:PublishSingleFile=true \
    -p:PublishReadyToRun=false \
    -p:DebugType=none \
    -p:DebugSymbols=false \
    -o "$OUT_DIR/$INSTALLER_NAME"
  (
    cd "$OUT_DIR"
    zip -r -q "$INSTALLER_NAME-win-x64-$VERSION.zip" "$INSTALLER_NAME"
  )
fi

shasum -a 256 "$OUT_DIR"/*.zip > "$OUT_DIR/SHA256SUMS.txt"
cat "$OUT_DIR/SHA256SUMS.txt"
