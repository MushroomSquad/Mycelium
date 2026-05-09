# Mycelium Architecture

## Identity

Mycelium is a terminal-native workspace environment.

Primary target:

- MacBook Air M1 2020
- Fedora Linux Asahi Remix
- ARM64 userspace
- terminal-first daily workflow

## Stack

- `tty` is the display server
- `zellij` is the window manager and compositor
- tabs are workspaces
- panes are windows
- shell and TUI tools are the application layer

Boot and login path:

```text
kernel
 -> systemd
   -> tty1
     -> autologin
       -> shell
         -> zellij
           -> cockpit layout
```

## Workspaces

- `1:main`: shell + `nnn`
- auxiliary tabs are opened on demand from the active pane's current directory
- `edit`: `nvim .`
- `git`: `lazygit`
- `monitor`: `btop`
- `logs`: `journalctl -f` on Linux, equivalent platform log stream elsewhere

## Input Model

- `Alt+1..6`: tab switching
- `Alt+,` / `Alt+.`: previous / next tab
- `Alt+w`: session manager overlay
- `Alt+Shift+w`: create or switch the `home` session
- `Alt+o`: built-in session mode
- `Alt+Enter`: fullscreen focused pane
- `Alt+h/j/k/l`: directional focus
- `Alt+n`: new pane
- `Alt+e/g/m/s`: open `edit` / `git` / `monitor` / `logs` tabs
- `Alt+x`: close focused pane
- `Alt+r`: rename tab mode

## Session Model

- one `zellij` session is the top-level project workspace
- active pane cwd is the source for new tabs in that session
- `Alt+Shift+w` creates or switches a session rooted at the user's home directory
- built-in session controls are used for session list and manual switching

## System Architecture

Mycelium v2 has three layers:

### Layer 1: chezmoi (dotfile management)

All config files and shell configurations live in `home/` as a chezmoi source directory.
chezmoi handles:

- Template-based config generation per platform (`.tmpl` files)
- External file downloads (btop/bat Catppuccin themes via `.chezmoiexternal.toml`)
- Idempotent apply (`chezmoi apply` skips unchanged files)
- Drift detection (`chezmoi verify`, `chezmoi diff`)
- Uninstall (`chezmoi purge`)
- One-time scripts (`run_once_` for bat cache rebuild)

### Layer 2: provision (packages and system config)

`scripts/provision.sh` handles:

- Platform and profile detection
- Package installation via system package manager
- System configuration (autologin, systemd target, vconsole — fedora-asahi only)
- TUI install wizard (optional packs, shell choice)
- chezmoi initialization with profile data

### Layer 3: Garuda upstream (theme references)

`scripts/garuda-upstream.sh` handles:

- Cloning/updating 4 Garuda Linux reference repos
- Comparing local chezmoi configs with Garuda upstream
- Importing upstream configs into chezmoi source directory
- Extracting fish shell config from Garuda upstream

### CLI Router

`scripts/mycelium.sh` is a thin router that delegates:

- `install`, `update`, `verify` → `provision.sh`
- `theme-sync`, `theme-diff`, `theme-import`, `garuda-shell-import` → `garuda-upstream.sh`
- `profile` → inline detection
- `start` → `exec zellij`

## Profile System

Profiles declare platform-specific package lists and behaviors:

- **Declarative profiles** (`.conf`): arch-generic, debian-generic, fedora-generic, suse-generic, macos-generic, linux-generic, unknown
- **Script profile** (`.sh`): fedora-asahi (unique COPR, cargo zellij, system config logic)

The profile engine (`profiles/_engine.sh`) reads `.conf` files and generates the required `profile_*` functions.

Shared libraries in `scripts/lib/`:

- `core.sh` — logging, file ops, verification helpers
- `detect.sh` — OS detection, profile resolution, profile loading
- `packages.sh` — package manager abstraction, chezmoi bootstrap
- `wizard.sh` — TUI prompts (whiptail/dialog/text fallback)

## Theme Model

- Default theme: `garuda-catppuccin-mocha`
- Static configs live in `home/dot_config/` (starship, fastfetch, lazygit, yazi, helix, aerc, bat, btop)
- Garuda upstream references stored in `themes/garuda-catppuccin-mocha/`:
  - `upstream.conf` — Git repo URLs
  - `candidate-map.conf` — tool → upstream file path mapping
  - `fish-extract.awk` — AWK script for fish config extraction

## Platform Assumptions

Linux reference assumptions:

- systemd present
- PipeWire / WirePlumber stack
- DRM/KMS console path
- `journalctl` available
- shell profile autostart allowed
- package management available through `dnf` on the reference platform
- `cargo` is used to install `zellij` on fedora-asahi
- `lazygit` is sourced from the `dejan/lazygit` COPR on fedora-asahi
- console boot is expected to use `multi-user.target`
- `tty1` autologin is part of the reference install
- console noise is reduced through `kernel.printk`
- console font is expected to be Terminus via `/etc/vconsole.conf`

macOS and generic Unix are supported as degraded variants:

- log workspace uses platform-native alternatives
- dashboard commands avoid Linux-only hard dependencies where possible
- package installation falls back to the host package manager if available
