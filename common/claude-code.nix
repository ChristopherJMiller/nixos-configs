pkgs-unstable:

let
  settingsContent = builtins.toJSON {
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

    attribution = {
      commit = "trailer";
      pr = "footer";
    };

    extraKnownMarketplaces = {
      claude-plugins-official = {
        source = {
          source = "github";
          repo = "anthropics/claude-plugins-official";
        };
      };
    };

    enabledPlugins = {
      "frontend-design@claude-plugins-official" = true;
    };
  };

  memoryText = ''
    # Tips

    - Use `nixs` alias for `nix-shell`
    - Use `gh` for GitHub interactions (PRs, issues, etc.)
    - Use tasks to track your work over time
  '';
in
{
  package = pkgs-unstable.claude-code;
  files = {
    ".claude/settings.json".text = settingsContent;
    ".claude/CLAUDE.md".text = memoryText;
  };
}
