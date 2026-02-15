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
      # Official Anthropic plugin with rate-limit detection.
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
