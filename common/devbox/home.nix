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
  imports = [ ./xfce-panel.nix ];

  home.username = "dev";
  home.homeDirectory = "/home/dev";
  home.stateVersion = "25.11";

  # Shared terminal experience (identical to celebi/rowlett)...
  programs.kitty = (import ../kitty.nix).kitty;
  # ...except p10k: in the VM the prompt loads from the read-only nix store
  # instead of zplug's runtime clone under ~/.zplug. That clone lives on the
  # /home/dev volume and gets corrupted/half-written whenever the disk fills,
  # which is the "my zsh config just got nuked" symptom. Sourcing the theme
  # from the store makes it structurally impossible to lose to ENOSPC, and a
  # home-manager re-activation (guest boot, or `dev-fix-shell`) always restores
  # it. Everything else in zsh.nix is inherited unchanged.
  programs.zsh = (import ../zsh.nix).zsh // {
    zplug.enable = false;
    plugins = [
      {
        name = "powerlevel10k";
        src = pkgs.zsh-powerlevel10k;
        file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
      }
    ];
  };
  programs.bash = bashCfg.bash;
  programs.readline = bashCfg.readline;
  # Persistent sessions for remote work (mosh is enabled in guest.nix).
  programs.tmux = (import ../tmux.nix).tmux;

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
    forgejo-cli
  ]);

  programs.home-manager.enable = true;
}
