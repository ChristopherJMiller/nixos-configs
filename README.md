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

On celebi, direnv and nix-direnv load project environments when entering a
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

# Celebi terminal

The terminal design is scoped to `hosts/celebi/terminal.nix` and its
`terminal-*.zsh` helpers while it is being tried on celebi.
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
listing, and `lt` for a two-level tree. Diffs use a unified layout for the laptop;
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
- `Meta+Left` / `Meta+Right`: tile the current window.

Sudo's password prompt identifies the host and target user and displays asterisks
as you type.
