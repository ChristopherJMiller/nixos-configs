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

      # Official Anthropic plugins
      # ralph-loop: rate-limit-aware autonomous looping (PR #120 adds full auto-wait)
      # frontend-design: distinctive, production-grade frontend interfaces
      enabledPlugins = {
        "ralph-loop@claude-plugins-official" = true;
        "frontend-design@claude-plugins-official" = true;
      };
    };

    # Shared memory (~/.claude/CLAUDE.md)
    # This is loaded at the start of every Claude Code session.
    # Add anything you want Claude to always know: preferences, conventions, context.
    memory = {
      text = ''
        # Environment

        - NixOS with Home Manager (flake-based, 25.05 stable channel)
        - Three hosts: rowlett (desktop/AMD GPU), celebi (Framework 13 laptop), wailmer (desktop/NVIDIA)
        - Shell: zsh with PowerLevel10k
        - Editor: neovim (EDITOR), VSCode
        - Git: signed commits (GPG key 6BFB8037115ADE26), user Christopher Miller <git@chrismiller.xyz>
        - Languages: Rust (rustup), Nix, occasional Python/JS
        - Containers: rootless Docker
        - Desktop: KDE Plasma 6 / Wayland
        - Package manager: nix flakes (rebuild alias: `nixr`)

        # Preferences

        - Keep code simple and direct — avoid over-engineering
        - Prefer explicit over clever
        - Use nixfmt-rfc-style for Nix formatting
      '';
    };
  };
in
{
  inherit claude-code;
}
