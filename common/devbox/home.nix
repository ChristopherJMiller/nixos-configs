# common/devbox/home.nix
#
# home-manager config for the `dev` user inside the devbox microVM.
# Reuses the fleet's shared kitty/zsh/bash/claude modules so the terminal
# experience (theme, p10k prompt, keybindings, Claude Code) matches celebi
# and rowlett. Everything stateful lives under /home/dev, which is the
# persistent 180G volume — so gh auth, repos and caches survive reboots.
#
# Takes pkgs-unstable (for claude-code) the same way the host home.nix
# files do; wired in flake.nix.
pkgs-unstable:
{ config, pkgs, ... }:

let
  claude = import ../claude-code.nix pkgs-unstable;
  bashCfg = import ../bash.nix;

  # devbox-specific context appended to the shared user CLAUDE.md, so agents
  # running in the VM know the lay of the land (persistent workspace, HTTPS
  # git, no signing). The shared base stays the single source of truth.
  devboxTips = ''

    ## devbox VM

    - This is the `devbox` dev VM. Your workspace is `/home/dev` — a persistent
      volume that survives reboots; put repos and long-lived state there.
    - Git uses **HTTPS via the `gh` CLI**. There are no SSH keys and no GPG
      signing in this VM: `git push` over HTTPS just works. Do NOT switch
      remotes to SSH, and do NOT enable commit/tag signing.
    - Docker is available for builds and containers.
  '';
in
{
  home.username = "dev";
  home.homeDirectory = "/home/dev";
  home.stateVersion = "25.11";

  # Shared terminal experience (identical to celebi/rowlett).
  programs.kitty = (import ../kitty.nix).kitty;
  programs.zsh = (import ../zsh.nix).zsh;
  programs.bash = bashCfg.bash;
  programs.readline = bashCfg.readline;

  # p10k prompt sourced by zsh.nix's initContent (`source ~/.p10k.zsh`), plus
  # the shared user CLAUDE.md extended with the devbox-specific tips above.
  home.file = claude.files // {
    ".p10k.zsh".source = ../p10k.zsh;
    ".claude/CLAUDE.md".text = claude.files.".claude/CLAUDE.md".text + devboxTips;
  };

  # Claude Code (unstable channel package + the shared CLAUDE.md memory).
  # gh/git themselves are installed at the system level (guest.nix) so their
  # auth/config stays unmanaged — `gh auth login` writes freely and agents
  # can drive pushes over HTTPS with no SSH agent in the way.
  home.packages = [ claude.package ] ++ (with pkgs; [
    ripgrep
    jq
    yq-go
    fzf
    fd
    bat
    xclip
    gnumake
  ]);

  programs.home-manager.enable = true;
}
