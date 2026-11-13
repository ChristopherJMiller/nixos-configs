# common/devbox/home.nix
#
# home-manager config for the `dev` user inside the devbox microVM.
# Reuses the fleet's shared terminal and coding CLI modules so the terminal
# experience (theme, p10k prompt, keybindings, Claude Code) matches celebi
# and rowlett. Everything stateful lives under /home/dev, which is the
# persistent 180G volume — so gh auth, repos and caches survive reboots.
#
# Takes pkgs-unstable (for coding CLIs) the same way the host home.nix
# files do; wired in flake.nix.
pkgs-unstable:
{ pkgs, ... }:

let
  claude = import ../claude-code.nix pkgs-unstable;

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
    - Firefox and Chromium are installed. For browser automation, launch
      `chromium-agent` in the desktop session (or `chromium-agent --headless`
      over SSH), then connect to `http://127.0.0.1:9222` using CDP. It uses a
      separate persistent profile under `~/.local/state/chromium-agent`.
    - Claude Code, Codex and Pi are installed. Pi supports GitHub Copilot:
      start `pi`, then `/login` and choose **GitHub Copilot**. Logins and
      sessions live in this persistent home and are not managed by Nix.
    - **Networking / tailnets.** The VM's real network interface (`tailscale0`)
      is the WORK tailnet: work hosts (`*.tail8f0356.ts.net`, company names
      like `tkndash.mountthor.dev` that resolve to `100.x`, subnet routes)
      just work from any program — curl, kubectl, ssh, docker. `tswork status`
      / `tswork ping host` inspect it. The PERSONAL tailnet (`tailscale`, no
      prefix; `*.taildca8.ts.net`) is inbound-only in userspace mode: it
      cannot be reached directly from here — for the rare outbound trip to a
      personal peer, prefix the command with `via-home` or use `home-ssh`.
      Never set proxy env globally.
  '';
in
{
  imports = [
    ../terminal.nix
    (import ../ai-tools.nix pkgs-unstable)
    ./desktop.nix
    ./browser.nix
    ./xfce-panel.nix
  ];

  home.username = "dev";
  home.homeDirectory = "/home/dev";
  home.stateVersion = "25.11";

  # Shared user CLAUDE.md extended with the devbox-specific tips above.
  home.file = claude.files // {
    ".claude/CLAUDE.md".text = claude.files.".claude/CLAUDE.md".text + devboxTips;
    ".codex/AGENTS.md".text = devboxTips;
    ".pi/agent/AGENTS.md".text = devboxTips;
  };

  # Claude Code (unstable channel package + the shared CLAUDE.md memory).
  # gh/git themselves are installed at the system level (guest.nix) so their
  # auth/config stays unmanaged — `gh auth login` writes freely and agents
  # can drive pushes over HTTPS with no SSH agent in the way.
  home.packages = [
    claude.package
  ]
  ++ (with pkgs; [
    ripgrep
    jq
    yq-go
    fd
    xclip
    gnumake
    forgejo-cli
  ]);

  programs.home-manager.enable = true;
}
