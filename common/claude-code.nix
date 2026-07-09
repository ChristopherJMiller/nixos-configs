pkgs-unstable:

# settings.json is intentionally not managed here — Claude Code needs to be
# able to update it freely (plugin marketplaces, permissions, etc.).
let
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
    ".claude/CLAUDE.md".text = memoryText;
  };
}
