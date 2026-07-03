# Subnautica 2 Mods

Source-only UE4SS Lua mods for Subnautica 2.

## Mods

### NeverNight

`NeverNight` keeps the world at daytime/noon by holding Subnautica 2's UWE sky/time objects at time `0.50`.

It also includes convenience console commands:

- `day` - force daytime/noon and keep no-night mode on.
- `nevernight_on` - enable automatic no-night hold.
- `nevernight_off` - stop automatic no-night hold.
- `nevernight_status` - write current no-night state to the UE4SS log.
- `stats`, `stats_100`, `sn2_stats` - emergency helper: one-shot player health refill plus a temporary 10-second survival guard.
- `survival_guard_10s` - temporary no thirst/starve/suffocation/health damage guard, then toggles back off.
- `sn2_help` - command summary.

The stats helper is intentionally not a permanent god-mode setting. It uses the direct health path where available and temporarily toggles Subnautica 2's own survival cheat commands for the survival guard.

## Install

Packages are produced by GitHub Actions only. Do not hand-build release ZIPs for distribution.

1. Install UE4SS for Subnautica 2 first.
   - Place UE4SS in `Subnautica2/Subnautica2/Binaries/Win64`.
   - That folder should contain `dwmapi.dll`, `ue4ss/UE4SS.dll`, and `ue4ss/Mods/mods.txt`.
2. Download the release artifact/ZIP from this repository's GitHub release.
3. Copy `NeverNight/` into:

```text
Subnautica2/Subnautica2/Binaries/Win64/ue4ss/Mods/NeverNight
```

4. Edit:

```text
Subnautica2/Subnautica2/Binaries/Win64/ue4ss/Mods/mods.txt
```

Add:

```text
NeverNight : 1
```

5. Launch the game.

## Console

UE4SS's console enabler normally maps several keys after startup/reload, including `F10`, `F1`, `F2`, `F6`-`F12`, `Insert`, `Home`, `End`, `PageUp`, `PageDown`, `Backslash`, and `Slash`. If the console closes after Enter, command feedback is also sent to the UE4SS log and, when available, to Unreal on-screen messages.

## Trust Model

This repository ships source-only Lua mods. It does not contain the UE4SS binary loader, game files, or compiled code. Users should install UE4SS from the upstream Subnautica 2 modding release and verify that dependency separately.

## Development

Run local validation:

```sh
./scripts/validate.sh
```

Create a local package for private testing only:

```sh
./scripts/package.sh dist
```

Release packages are produced only by the GitHub Actions release workflow.
