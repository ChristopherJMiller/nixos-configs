# Plan: Unified Claude Code Configuration Across Hosts

## Current State

- **rowlett** and **celebi** install `claude-code` as a bare unstable package (no configuration)
- **wailmer** does not have Claude Code at all
- No `programs.claude-code` module usage anywhere — zero settings, memory, hooks, skills, or MCP config
- Home Manager 25.05 is already in use, which includes the upstream `programs.claude-code` module (526-line module with full settings, agents, commands, hooks, memory, rules, skills, MCP support)
- The `common/` directory pattern (used by `zsh.nix`, `vscode.nix`) is the established way to share config

## What This Plan Delivers

1. **Unified `common/claude-code.nix`** — single source of truth for Claude Code config, imported by all hosts
2. **Auto-continue on rate limit** — package `autoclaude` (Go CLI) as a Nix derivation and include it on all Claude Code hosts
3. **Shared settings.json** — permissions, model preferences, plugin marketplaces, attribution
4. **Shared CLAUDE.md memory** — consistent context about your environment across hosts
5. **Official plugin marketplace** — pre-configured with the Anthropic official marketplace plugins
6. **MCP server: GitHub** — since `gh` is already installed on rowlett and celebi
7. **Clean removal of duplicate package declarations** — `claude-code` moves out of per-host `unstable-pkgs` lists

---

## Step-by-Step Implementation

### Step 1: Create `common/claude-code.nix`

Create a new common module following the same pattern as `common/zsh.nix` — a let-binding that exports config attributes for `programs.claude-code`.

The module will configure:

```nix
let
  claude-code = {
    enable = true;
    # package comes from pkgs (which is nixpkgs-unstable via useGlobalPkgs)
    # but since useGlobalPkgs=true uses stable nixpkgs, we'll pass pkgs-unstable

    settings = {
      # Permissions: allow common safe operations by default
      permissions = {
        allow = [
          "Bash(git *)"
          "Bash(nix *)"
          "Bash(gh *)"
          "Bash(npm *)"
          "Bash(cargo *)"
          "Bash(rustup *)"
          "Bash(kubectl *)"
          "Bash(docker *)"
          "Bash(ls *)"
          "Bash(cat *)"
          "Bash(find *)"
          "Bash(grep *)"
          "Bash(rg *)"
          "Bash(jq *)"
          "Bash(head *)"
          "Bash(tail *)"
          "Bash(wc *)"
          "Bash(sort *)"
          "Bash(mkdir *)"
          "Bash(cp *)"
          "Bash(mv *)"
          "Bash(rm *)"
        ];
        deny = [
          "Bash(sudo *)"
          "Bash(nixos-rebuild *)"
        ];
      };

      # Git co-authoring attribution
      attribution = {
        commit = "trailer";
        pr = "footer";
      };

      # Plugin marketplace: official Anthropic marketplace
      extraKnownMarketplaces = {
        claude-plugins-official = {
          source = {
            source = "github";
            repo = "anthropics/claude-plugins-official";
          };
        };
      };
    };

    # Shared memory: tell Claude about the NixOS environment
    memory = {
      text = ''
        # User Environment

        - NixOS with Home Manager (flake-based, 25.05 stable channel)
        - Three hosts: rowlett (desktop/AMD GPU), celebi (Framework 13 laptop), wailmer (desktop/NVIDIA)
        - Shell: zsh with PowerLevel10k
        - Editor: neovim (EDITOR), VSCode
        - Git: signed commits (GPG key 6BFB8037115ADE26), user Christopher Miller <git@chrismiller.xyz>
        - Languages: Rust (rustup), Nix, occasional Python/JS
        - Containers: rootless Docker
        - Desktop: KDE Plasma 6 / Wayland
        - Package manager: nix flakes (rebuild alias: `nixr`)
      '';
    };
  };
in
{
  inherit claude-code;
}
```

**Key design decisions:**
- Uses the same `let ... in { inherit X; }` pattern as `common/zsh.nix`
- Takes `pkgs-unstable` as a parameter (like `home.nix` files do) so we can reference the unstable claude-code package
- Permissions are conservative — allows dev tools, denies sudo/rebuild
- Memory gives Claude context about the NixOS setup so it gives better advice

### Step 2: Package `autoclaude` for Nix

Create `packages/autoclaude/default.nix` — a Nix derivation that builds the Go-based `autoclaude` tool from source (`github:henryaj/autoclaude`).

```nix
{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule rec {
  pname = "autoclaude";
  version = "...";  # will pin to latest tag

  src = fetchFromGitHub {
    owner = "henryaj";
    repo = "autoclaude";
    rev = "v${version}";
    hash = "...";  # will compute with nix-prefetch
  };

  vendorHash = "...";  # will compute

  meta = with lib; {
    description = "Auto-continue Claude Code after rate limits in tmux";
    homepage = "https://github.com/henryaj/autoclaude";
    license = licenses.mit;
    mainProgram = "autoclaude";
  };
}
```

This requires tmux to be running. We'll also add `tmux` to the common packages if not already present.

**Note:** `autoclaude` monitors tmux panes for the rate-limit message pattern and automatically sends `Escape -> "continue" -> Enter` when the reset timer expires. It's the most mature solution for this — the official Claude Code team has not implemented auto-continue despite multiple feature requests (#13354, #18980, #6254, #16607).

### Step 3: Add `autoclaude` to `customPackages` in `flake.nix`

Add the autoclaude derivation to the `customPackages` function:

```nix
customPackages = pkgs: {
  # ... existing packages ...
  autoclaude = pkgs.callPackage ./packages/autoclaude { };
};
```

### Step 4: Update `hosts/rowlett/home.nix`

1. **Remove** `claude-code` from the `unstable-pkgs` list (line 111)
2. **Import and apply** the common claude-code module:
   ```nix
   programs.claude-code = (import ../../common/claude-code.nix pkgs-unstable).claude-code;
   ```
3. **Add** `autoclaude` and `tmux` to packages

### Step 5: Update `hosts/celebi/home.nix`

Same changes as rowlett:
1. **Remove** `claude-code` from `unstable-pkgs` (line 127)
2. **Import and apply** the common claude-code module
3. **Add** `autoclaude` and `tmux` to packages

### Step 6: Update `hosts/wailmer/home.nix`

Add Claude Code to wailmer (currently missing):
1. **Import and apply** the common claude-code module
2. **Add** `autoclaude` and `tmux` to packages
3. **Add** `customPackages` usage (currently not used on wailmer — need to also pass it via `specialArgs` in `flake.nix`)

### Step 7: Update `flake.nix` for wailmer

Add `specialArgs = { inherit customPackages; };` and `home-manager.extraSpecialArgs = { inherit customPackages; };` to the wailmer host config (currently missing, which is why wailmer can't use customPackages).

---

## Architecture Decision: Why Not a Full NixOS Module?

The handoff document describes building a comprehensive companion module with typed settings wrappers, `~/.claude.json` activation scripts, shell integration, and schema validation. That's a significant undertaking suited for an upstream contribution.

For your personal config, the simpler approach is better:
- **Use the upstream `programs.claude-code` module directly** — it already supports everything needed
- **Share config via `common/claude-code.nix`** using the same pattern as your existing modules
- **Package `autoclaude` locally** — straightforward `buildGoModule` derivation

This gives you a unified config today without the maintenance burden of a custom module system.

---

## Files Changed

| File | Action | Description |
|------|--------|-------------|
| `common/claude-code.nix` | **Create** | Shared Claude Code configuration |
| `packages/autoclaude/default.nix` | **Create** | Nix package for autoclaude |
| `flake.nix` | **Edit** | Add autoclaude to customPackages, add specialArgs to wailmer |
| `hosts/rowlett/home.nix` | **Edit** | Import common claude-code, remove bare package |
| `hosts/celebi/home.nix` | **Edit** | Import common claude-code, remove bare package |
| `hosts/wailmer/home.nix` | **Edit** | Import common claude-code, add customPackages usage |

---

## Other Ideas Worth Considering (Not in initial scope)

- **claude-o-meter**: Rate limit usage monitoring with desktop notifications. Could add later as a flake input if you want a visual indicator of how close you are to limits.
- **MCP servers via `roman/mcps.nix`**: Pre-built MCP server presets for GitHub, filesystem, etc. Could add as a flake input for richer tool access.
- **Shared skills/agents**: If you develop custom Claude skills or agents, they can be managed declaratively via `programs.claude-code.skills` and shared across hosts in the common module.
- **Project-scoped configs**: For specific repos, use `.claude/settings.json` in the project root (higher precedence than user settings). Not managed by Home Manager.
