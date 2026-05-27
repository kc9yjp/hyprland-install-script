# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a Hyprland desktop environment installer for EndeavourOS (and other Arch-based distros). The repo contains two things: a single installer script (`install.sh`) and the dotfiles/configs it copies into place.

## Running the installer

```bash
./install.sh
```

The script is interactive — it uses `gum` for prompts (boot type, monitor resolution, mod key, Nvidia GPU). It must **not** be run as root. It requires `yay` (AUR helper) to already be installed for AUR packages.

## Repository structure

- **`install.sh`** — the entire installer; installs packages via pacman/yay, copies configs, sets up SDDM, swapfile, dev tools, kernel, and GPU drivers.
- **`config/`** — dotfiles that get copied to `~/.config/` (and some to `~/`). Edit files here, not after they've been deployed.
- **`config/hypr/hyprland.lua`** — Hyprland's entry point; it `require()`s all modules from `config/hypr/conf/`.
- **`config/hypr/conf/`** — modular Lua config files for Hyprland. The installer generates `monitor.lua` at install time from user input and optionally appends to `environment.lua` for Nvidia.
- **`config/waybar/`** — Waybar bar config (`config`, `modules.jsonc`, `style.css`) and a `launch.sh` restart helper.
- **`wallpapers/`** — bundled wallpapers; copied to `~/Pictures/` by the installer.

## Hyprland config conventions

Hyprland config uses the **Lua API** (not the legacy `.conf` format). All bindings use the `hl.*` global. Key patterns:

- `hl.bind(combo, action)` for keybindings
- `hl.env(key, value)` for environment variables
- `hl.monitor({...})` for monitor setup
- `hl.config({...})` for nested settings
- `hl.on("hyprland.start", fn)` for startup hooks

The mod key (`mainMod`) is set in `conf/keybinding.lua` and patched by `sed` during install. Custom user tweaks go in `conf/custom.lua`.

## Nvidia considerations

When Nvidia is selected during install, the script:
1. Writes `conf/environment.lua` with DRM/LIBVA env vars and `no_hardware_cursors = true`
2. Appends `require("conf/electron-flickering-fix")` to `hyprland.lua`
3. Installs `nvidia-dkms`, configures dracut/grub, and adds kernel module options

Electron app flickering on Nvidia can also be resolved per-app with the `--disable-gpu-compositing` flag in `.desktop` files.
