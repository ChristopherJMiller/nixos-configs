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
        # Tips

        - Use `nixs` alias for `nix-shell`
        - Use `gh` for GitHub interactions (PRs, issues, etc.)
        - Use tasks to track your work over time
      '';
    };
  };
in
{
  inherit claude-code;
}
