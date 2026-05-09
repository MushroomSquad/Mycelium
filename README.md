# Mycelium

> terminal-native workspace environment
> for Apple Silicon laptops and terminal-first Unix systems

Mycelium turns `tty` + `zellij` + TUI apps into a desktop-like workspace model.

Primary reference machine:

- MacBook Air M1 2020
- Fedora Linux Asahi Remix
- `multi-user.target`
- `tty1` autologin
- shell -> `zellij` -> `cockpit`

## Model

- `tty` is the display server
- `zellij` is the window manager / compositor
- tabs are workspaces
- panes are windows
- shell and TUI tools are the app layer

Default workspace:

- `1:main`: shell + `nnn`

Tool tabs open on demand from the active pane's current directory:

- `Alt+w`: session manager overlay for session list / switch / create
- `Alt+Shift+w`: create or switch a `home` session from the user's home directory
- `Alt+o`: built-in session mode
- `Alt+e`: `edit` -> `nvim .`
- `Alt+g`: `git` -> `lazygit`
- `Alt+m`: `monitor` -> `btop`
- `Alt+s`: `logs` -> platform log stream

Key bindings:

- `Alt+1..6`: switch tabs by index
- `Alt+,` / `Alt+.`: previous / next tab
- `Alt+w`: show session manager
- `Alt+Shift+w`: create or switch the `home` session
- `Alt+o`: switch to session mode
- `Alt+Enter`: fullscreen focused pane
- `Alt+h/j/k/l`: move focus
- `Alt+n`: new pane
- `Alt+x`: close focused pane
- `Alt+r`: rename tab

Session and tab model:

- active pane is the source of `cwd`
- new tool tabs inherit the active pane directory
- `Alt+Shift+w` creates or switches a session rooted at the user's home directory
- built-in `zellij` session controls remain available for list and manual switching

## Install

Local checkout:

```bash
./install.sh
```

Remote bootstrap:

```bash
curl -fsSL https://raw.githubusercontent.com/MushroomSquad/Mycelium/main/install.sh | bash
```

Or with an explicit git URL:

```bash
curl -fsSL https://raw.githubusercontent.com/MushroomSquad/Mycelium/main/install.sh | \
  MYCELIUM_REPO_URL=https://github.com/MushroomSquad/Mycelium.git bash
```

Non-interactive install:

```bash
MYCELIUM_TUI=0 ./install.sh
```

## Install Flow

`install.sh` is the bootstrap layer. Real provisioning happens in `scripts/provision.sh`, and dotfile management is handled by chezmoi.

Execution flow:

1. `install.sh` resolves the repo source.
2. `scripts/provision.sh` detects the host OS and profile.
3. The selected profile installs required packages.
4. chezmoi applies all managed configs from `home/` (zellij, shell, theme, TUI tools).
5. Catppuccin themes for `btop`/`bat` are fetched via chezmoi externals.
6. A post-install summary prints.

Interactive install wizard:

- detects the host profile
- asks about system-level setup when the profile supports it
- lets you select optional TUI role packs
- lets non-`fedora-asahi` installs switch the primary interactive shell to `fish`

## Commands

After install, `~/.local/bin/mycelium` points at the orchestrator.

- `mycelium install`
- `mycelium update`
- `mycelium start`
- `mycelium verify`
- `mycelium profile`
- `mycelium theme-sync`
- `mycelium theme-diff`
- `mycelium theme-import`
- `mycelium garuda-shell-import`
- `mycelium garuda-starship-import`

Typical usage:

```bash
mycelium profile
mycelium verify
mycelium update
mycelium theme-diff
mycelium garuda-shell-import
```

## Profiles

Declarative profiles live in `profiles/*.conf`. The profile engine generates install functions from these data files. `fedora-asahi` keeps a script profile (`profiles/fedora-asahi.sh`) for its unique COPR and system config logic.

Current profiles:

- `fedora-asahi` (script)
- `fedora-generic`
- `arch-generic`
- `debian-generic`
- `suse-generic`
- `macos-generic`
- `linux-generic`
- `unknown`

Profile responsibilities:

- declare required packages
- define optional TUI role packs
- declare the shell package for fish
- perform platform-specific system configuration (fedora-asahi only)
- define required binaries for verification

Reference profile:

- `fedora-asahi` is the primary, fully opinionated profile
- it installs the exact package stack for Fedora Asahi
- it defaults the primary interactive shell to `fish`
- it can apply `multi-user.target`, `tty1` autologin, quiet console, `tlp`, video-group brightness access, and console font setup

## Package Layers

Mycelium has three package layers.

Base bootstrap layer:

- `install.sh` only assumes `git`

Profile required layer:

- core tools like `zellij`, `nnn`, `nvim`, `btop`, `fastfetch`, `lazygit`, `bat`, `eza`, `zoxide`, `fzf`, `ripgrep`, `jq`, `tmux`
- on `fedora-asahi`, also audio, power, console, and build dependencies

Optional role-pack layer:

- `ops-pack`: `k9s`, `lazydocker`, `bottom`, `mosh`
- `media-pack`: `mpv`, `cmus`, `chafa`
- `news-pack`: `newsboat`
- `web-pack`: `w3m`, `lynx`, `yt-dlp`
- `disk-pack`: `ncdu`, `dua-cli`, `du-dust`
- `mail-pack`: `aerc`, `notmuch`
- `writing-pack`: `helix`, `glow`, `mdcat`
- `file-pack`: `yazi`, `broot`, `ranger`

All optional packs are intended to stay terminal-native.

## Theme And Garuda Layer

Default theme:

- `garuda-catppuccin-mocha`

Theme configs live in `themes/garuda-catppuccin-mocha/`. Static TUI configs live in `home/dot_config/`. Upstream management is handled by `scripts/garuda-upstream.sh`.

Garuda reference sources:

- `garuda-mokka`
- `garuda-common-settings`
- `website-catppuccin`
- `garuda-pkgbuilds`

Theme responsibilities:

- sync Garuda upstream reference repos into Mycelium state
- pull Catppuccin Mocha theme assets for `btop` and `bat`
- import Garuda-derived shell behavior for `fish`, `starship`, and `fastfetch`
- apply managed Catppuccin/Garuda payloads for TUI tools
- reapply optional role-pack theme payloads from recorded install state
- expose `theme-diff`, `theme-import`, and `garuda-shell-import`

Garuda-managed shell layer:

- `BAT_THEME`
- Catppuccin `FZF_DEFAULT_OPTS`
- `zoxide init`
- `starship init`
- `fastfetch` on interactive local shells
- `eza`/`bat`-based replacements
- audio helpers

Garuda-managed TUI targets:

- `starship.toml`
- `fastfetch/config.jsonc`
- `lazygit/config.yml`
- `yazi/theme.toml`
- `helix/config.toml`
- `aerc/aerc.conf`
- `aerc/stylesets/mycelium`

Important behavior:

- `fish` is not blindly overwritten
- Garuda shell import is rule-level
- imported `fish alias` entries are normalized into `abbr`
- theme payloads are applied even when upstream refs are unavailable

## Theme/Pack Coupling

Optional packs and theme hooks are tied together on purpose.

Current coupling:

- `ops-pack` -> `lazygit`, `bottom`
- `media-pack` -> `cmus`
- `mail-pack` -> `aerc`
- `writing-pack` -> `helix`
- `file-pack` -> `yazi`

This means install/update/theme-import keeps both package selection and visual integration in the same model.

## Shell Model

Bootstrap and installer shell:

- always `bash`

Primary interactive shell:

- `fish` by default on `fedora-asahi`
- `bash` by default on the other profiles
- can be overridden with `MYCELIUM_PRIMARY_SHELL`

Useful override:

```bash
MYCELIUM_PRIMARY_SHELL=fish ./install.sh
```

Autostart hooks are written for:

- `~/.bash_profile`
- `~/.zprofile`
- `~/.config/fish/config.fish`

Interactive shell UX blocks are written for:

- `~/.bashrc`
- `~/.zshrc`
- `~/.config/fish/config.fish`

## Verification

`mycelium verify` writes a tab-separated report to Mycelium state and prints a summary table.

Verification checks include:

- required commands for the selected profile
- managed `zellij` layout and config files
- installed `mycelium` command link
- theme-managed files
- profile-specific system checks

On `fedora-asahi`, extra checks include:

- `systemctl get-default`
- installed Asahi-related RPMs
- `wpctl status`
- `aplay -l`
- `brightnessctl get`
- `brightnessctl max`
- battery capacity

## Installed Paths

- repo: `~/.local/share/mycelium/repo`
- state: `~/.local/share/mycelium`
- command: `~/.local/bin/mycelium`
- layouts: `~/.config/zellij/layouts/*.kdl`
- keymap: `~/.config/zellij/config.kdl`
- verification report: `~/.local/share/mycelium/verify.tsv`
- install metadata: `~/.local/share/mycelium/install.env`

If the normal state root is not writable, Mycelium falls back to `/tmp/mycelium`.

## Useful Overrides

```bash
MYCELIUM_TUI=0 ./install.sh
MYCELIUM_PROFILE=fedora-asahi ./install.sh
MYCELIUM_OPTIONAL=ops-pack,mail-pack ./install.sh
MYCELIUM_THEME=garuda-catppuccin-mocha ./install.sh
MYCELIUM_PRIMARY_SHELL=fish ./install.sh
MYCELIUM_CONFIGURE_SYSTEM=0 ./install.sh
MYCELIUM_SESSION_NAME=cockpit ./install.sh
MYCELIUM_LAYOUT_NAME=cockpit ./install.sh
```

## Reference

System model and architecture are documented in [ARCHITECTURE.md](ARCHITECTURE.md).
