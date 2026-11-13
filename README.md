# <i>NixOS Configs</i>

# Host Onboarding

If a new system,

1. Clone to `~/nixos`
2. Build your new host under `hosts/`
3. Define a new `nixosConfigurations` section in `flake.nix`

Otherwise,

Run `sudo nixos-rebuild switch --flake .#<host>` where `<host>` is the host name in `nixosConfigurations`

# Structure

```
.
├── common
│   ├── commonly re-usable components
│   └── ...
├── flake.nix (where host entries are defined)
├── hosts
│   └── various host systems
│   └── ...
└── format.sh (run for nix formatting)
```

# Useful Alises

- `nixr` maps to rebuilding NixOS using the flake
- `nixu` maps to updating the flake lock and then updating the system
- `nixs` is a shorthand for `nix-shell`

# Development environment

On every host and devbox, direnv and nix-direnv load project environments when entering a
directory and restore the previous environment when leaving it. After rebuilding
and opening a new terminal, authorize this repository's `.envrc` once:

```sh
cd ~/nixos
direnv allow
```

The development shell provides `nixfmt`, `nixd`, `statix`, `deadnix`, and
`shellcheck`. It is also available manually with `nix develop`. Use `nix fmt` to
format Nix files. For another flake-based project with a development shell, add
`use flake` to its `.envrc`, then run `direnv allow` in that directory.

# Shared terminal

The terminal configuration lives in `common/terminal.nix` and its
`terminal-*.zsh` helpers, shared by celebi, rowlett, wailmer, and devbox.
Kitty uses JetBrainsMono Nerd Font, 94% background opacity, a little padding,
and quiet tabs. The two-line Catppuccin prompt has separate rounded badges for
the directory, Git status, and active development environments. SSH/root context,
failures, and slow command durations appear when relevant; completed prompts
collapse to a compact form.

Environment loading is quiet when cached. Loads longer than 150 ms show a
temporary spinner; errors remain visible. The active Nix badge is the persistent
indication that the development environment is ready.

Tab opens a searchable completion menu with directory/file previews, including
after `sudo`. Fzf menus, `bat` file previews, and `git diff` (via delta) use
Macchiato colors. Use `bat <file>` to read a file, `ll` for a detailed directory
listing, and `lt` for a two-level tree. Diffs use a unified layout;
`git -c delta.side-by-side=true diff` selects a side-by-side view when wanted.

- `Ctrl+R`: fuzzy command history search.
- `Ctrl+T`: fuzzy file selection.
- `Alt+C`: fuzzy directory selection.
- `z <name>`: jump to a frequently visited directory.
- `Ctrl+Shift+Left` / `Ctrl+Shift+Right`: previous / next Kitty tab.
- `Ctrl+Shift+G`: browse the last command's output.
- `Ctrl+Shift+H`: browse all scrollback.
- `Ctrl+Shift+Z` / `Ctrl+Shift+X`: jump to the previous / next prompt.
- `Ctrl+Shift+E`: open a URL using keyboard hints.
- `Ctrl+Shift+P`, then `F`: insert a path from the visible output.
- `Ctrl+Shift+P`, then `N`: open a visible `file:line` reference in the editor.
- On celebi, `Meta+Left` / `Meta+Right`: tile the current window.

Sudo's password prompt identifies the host and target user and displays asterisks
as you type on the desktop hosts. Tmux is also configured everywhere: `ta`
attaches to the persistent `main` session, and `tls` lists sessions.

# Coding agents

`common/ai-tools.nix` installs Pi (`pi-coding-agent`) and Codex from the pinned
unstable package set on every host and devbox. Claude Code remains available
alongside them. Agent settings, tokens, and sessions stay writable in each
user's home directory.

To use your GitHub Copilot subscription with Pi, run `pi`, enter `/login`,
choose **GitHub Copilot**, and complete the device login in your browser.
Then use `/model` to select a Copilot model. This is Pi's own login, separate
from `gh auth login`; repeat it once on each machine where you use Pi.
See the [Pi provider documentation](https://github.com/earendil-works/pi/blob/v1.3.0/packages/coding-agent/docs/providers.md).

For Codex on a remote shell, run `codex login --device-auth` and follow the
displayed link and code. Device code login must be enabled in your ChatGPT
account or workspace; see [Codex authentication](https://learn.chatgpt.com/docs/auth).

# Devbox desktop

Devbox uses Catppuccin Macchiato/Mauve for GTK apps, window decorations, icons,
and the terminal. XFCE screensaver locking, idle power management, X screen
blanking, and DPMS are disabled so an RDP session remains accessible when idle.
RDP login still uses the existing PAM authentication.

Firefox and Chromium are available from the panel. For coding-agent browser
work, open **Chromium (automation)** from the app menu or run `chromium-agent`
in the desktop session. Over SSH, use `chromium-agent --headless`. Connect a
CDP-capable tool to `http://127.0.0.1:9222`; the port is local to the VM and
is available only while that browser is running. The separate automation
profile persists at `~/.local/state/chromium-agent`, including its logins.
The dedicated profile follows [Chrome's remote debugging requirements](https://developer.chrome.com/blog/remote-debugging-port).

Apply host changes with `sudo nixos-rebuild switch --flake .#<host>`.
Devbox is built as part of rowlett: rebuild rowlett, then run `devvm-update`
there to restart the VM into its new configuration (ends running VM sessions).
Log back into RDP to pick up the desktop changes; open a new terminal on
other hosts to load their updated shell configuration.
