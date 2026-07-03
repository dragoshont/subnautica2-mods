#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

test -f NeverNight/Scripts/main.lua
test -f mods.manifest.json

grep -q 'RegisterConsoleCommandGlobalHandler("day"' NeverNight/Scripts/main.lua
grep -q 'register_stats_command("stats_100"' NeverNight/Scripts/main.lua
grep -q 'RegisterConsoleCommandGlobalHandler("survival_guard_10s"' NeverNight/Scripts/main.lua
grep -q 'ClientMessage' NeverNight/Scripts/main.lua
grep -q 'PrintString' NeverNight/Scripts/main.lua

python3 -m json.tool mods.manifest.json >/dev/null

if command -v dotnet >/dev/null 2>&1; then
  dotnet build src/SN2NeverNightInstaller/SN2NeverNightInstaller.csproj -c Release --nologo
else
  echo "dotnet not found; skipping installer build" >&2
fi

echo "validation ok"
