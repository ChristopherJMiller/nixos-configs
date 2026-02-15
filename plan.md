# Plan: Unified Claude Code Configuration Across Hosts

## Current State

- **rowlett** and **celebi** install `claude-code` as a bare unstable package (no configuration)
- **wailmer** does not have Claude Code at all
- No `programs.claude-code` module usage anywhere — zero settings, memory, hooks, skills, or MCP config
- Home Manager 25.05 is already in use, which includes the upstream `programs.claude-code` module (526-line module with full settings, agents, commands, hooks, memory, rules, skills, MCP support)
- The `common/` directory pattern (used by `zsh.nix`, `vscode.nix`) is the established way to share config

## What This Plan Delivers

1. **Unified `common/claude-code.nix`** — single source of truth for Claude Code config, imported by all hosts
2. **Rate-limit handling via `ralph-loop` plugin** — official Anthropic plugin with rate-limit detection, pre-enabled via `enabledPlugins`
3. **Shared settings.json** — permissions, plugin marketplaces, attribution
4. **Shared CLAUDE.md memory** — consistent context about your environment across hosts
5. **Official plugin marketplace** — pre-registered so all official plugins are discoverable
6. **Clean removal of duplicate package declarations** — `claude-code` moves out of per-host `unstable-pkgs` lists
7. **100% stock Claude Code** — no external tools, ready for Happy Coder

---

## Step-by-Step Implementation

### Step 1: Create `common/claude-code.nix`

Create a new common module following the same pattern as `common/zsh.nix` — a let-binding that exports config attributes for `programs.claude-code`.

```nix
pkgs-unstable:

let
  claude-code = {
    enable = true;
    package = pkgs-unstable.claude-code;

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

      # Plugin marketplace: official Anthropic plugins
      extraKnownMarketplaces = {
        claude-plugins-official = {
          source = {
            source = "github";
            repo = "anthropics/claude-plugins-official";
          };
        };
      };

      # Enable ralph-loop for rate-limit-aware autonomous looping
      # This is the official Anthropic plugin with rate-limit detection.
      # PR #120 on claude-plugins-official adds full auto-wait on rate limits.
      enabledPlugins = {
        "ralph-loop@claude-plugins-official" = true;
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
- Takes `pkgs-unstable` as a parameter so the unstable claude-code package is used
- `ralph-loop` is pre-enabled — it's the official Anthropic plugin with rate-limit detection and autonomous looping via a Stop hook. Currently offers wait/exit on rate limit; PR #120 will add fully automatic wait-and-resume.
- Permissions are conservative — allows dev tools, denies sudo/rebuild
- Memory gives Claude context about the NixOS setup
- No external tools — everything runs within Claude Code's native plugin system

### Step 2: Update `hosts/rowlett/home.nix`

1. **Remove** `claude-code` from the `unstable-pkgs` list (line 111)
2. **Import and apply** the common claude-code module:
   ```nix
   programs.claude-code = (import ../../common/claude-code.nix pkgs-unstable).claude-code;
   ```

### Step 3: Update `hosts/celebi/home.nix`

Same changes as rowlett:
1. **Remove** `claude-code` from `unstable-pkgs` (line 127)
2. **Import and apply** the common claude-code module

### Step 4: Update `hosts/wailmer/home.nix`

Add Claude Code to wailmer (currently missing):
1. **Import and apply** the common claude-code module

### Step 5: Update `flake.nix` for wailmer

Add `specialArgs = { inherit customPackages; };` and `home-manager.extraSpecialArgs = { inherit customPackages; };` to the wailmer host config (currently missing, which is why wailmer can't reference customPackages if needed in the future).

---

## Rate-Limit Strategy: Why `ralph-loop`

There is **no dedicated auto-continue plugin** in the Claude Code ecosystem today. The options are:

| Option | Type | Status | Stock Claude? |
|--------|------|--------|---------------|
| `ralph-loop` (official) | Native plugin | Working, PR #120 adds full auto-wait | Yes |
| `autoclaude` | External Go binary + tmux | Working | No |
| Built-in auto-continue | Core feature request | Open (issues #13354, #18980) | Would be |

**`ralph-loop`** is the right choice because:
- It's an **official Anthropic plugin** from `claude-plugins-official`
- It uses Claude Code's native **Stop hook** mechanism — no external tools
- It already detects 5-hour API limits and offers wait/exit
- PR #120 will make waiting fully automatic when merged
- It's **Happy Coder compatible** — just a plugin, nothing custom
- Bonus: it also enables autonomous looping for long tasks (`/ralph-loop "task" --max-iterations 20`)

---

## Architecture Decision: Why Not a Full NixOS Module?

The handoff document describes building a comprehensive companion module with typed settings wrappers, `~/.claude.json` activation scripts, shell integration, and schema validation. That's a significant undertaking suited for an upstream contribution.

For your personal config, the simpler approach is better:
- **Use the upstream `programs.claude-code` module directly** — it already supports everything needed
- **Share config via `common/claude-code.nix`** using the same pattern as your existing modules
- **Use native plugins** for rate-limit handling — no custom packaging needed

This gives you a unified config today without the maintenance burden of a custom module system.

---

## Files Changed

| File | Action | Description |
|------|--------|-------------|
| `common/claude-code.nix` | **Create** | Shared Claude Code configuration with ralph-loop plugin |
| `flake.nix` | **Edit** | Add specialArgs to wailmer for future customPackages use |
| `hosts/rowlett/home.nix` | **Edit** | Import common claude-code, remove bare package |
| `hosts/celebi/home.nix` | **Edit** | Import common claude-code, remove bare package |
| `hosts/wailmer/home.nix` | **Edit** | Import common claude-code, add Claude Code to this host |

---

## Other Ideas Worth Considering (Not in initial scope)

- **claude-o-meter**: Rate limit usage monitoring with desktop notifications via a HyprPanel integration. Could add later as a flake input for visibility into how close you are to limits.
- **MCP servers via `roman/mcps.nix`**: Pre-built MCP server presets for GitHub, filesystem, etc. Could add as a flake input for richer tool access.
- **More official plugins**: The official marketplace has LSP plugins (rust-analyzer, pyright, typescript-language-server), code-review tools, and output styles that could be enabled.
- **Shared skills/agents**: Custom Claude skills or agents managed declaratively via `programs.claude-code.skills`, shared across hosts.
- **Project-scoped configs**: For specific repos, use `.claude/settings.json` in the project root (higher precedence than user settings). Not managed by Home Manager.
