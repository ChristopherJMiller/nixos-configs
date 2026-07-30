# common/devbox/guest.nix
#
# The `devbox` dev VM: a headless XFCE desktop reached over RDP, joined to the
# tailnet by its OWN tailscale. Runs as an OFF-BY-DEFAULT qemu microVM on
# rowlett (see flake.nix: `microvm.vms.devbox`, autostart = false).
#
# Access model:
#   * Primary — the VM's own tailscale makes it `devbox` on the tailnet:
#     RDP (xfreerdp / Remmina / KRDC) or `ssh dev@devbox` from anywhere on it.
#   * Bootstrap / break-glass — qemu user-mode networking forwards, on
#     rowlett's LOOPBACK only, 127.0.0.1:2222 -> :22 and :13389 -> :3389 (host
#     13389, since rowlett's own xrdp holds 3389); plus serial-console
#     autologin (ttyS0). Nothing is exposed on the LAN.
#
# Git is HTTPS-via-`gh` with NO gpg/ssh signing (see /etc/gitconfig below), so
# pushes never wait on an ssh agent or pinentry — agents can drive everything.
# Persistent state lives on volumes; the rootfs is otherwise ephemeral.
{ config, pkgs, lib, ... }:

{
  networking.hostName = "devbox";
  system.stateVersion = "25.11";

  # ---- microVM shape -------------------------------------------------------
  microvm.hypervisor = "qemu";
  microvm.vcpu = 6; # of rowlett's 16 threads
  microvm.mem = 12288; # 12 GiB (Rust/link-heavy builds); rowlett keeps ~19 GiB

  # Outbound-only user-mode networking: no LAN presence. In-guest tailscale
  # reaches the tailnet via slirp NAT (+ DERP); nothing is exposed on the LAN.
  microvm.interfaces = [
    {
      type = "user";
      id = "usernet";
      mac = "02:00:00:00:d3:01";
    }
  ];
  # Convenience host->guest forwards on rowlett's loopback only (pre-tailscale
  # bootstrap + fallback). qemu + single user interface (asserted). NOTE: the
  # RDP forward uses host port 13389, NOT 3389 — rowlett runs its OWN xrdp on
  # 3389, so binding 3389 here collides and qemu refuses to start. Reach the
  # guest's RDP locally via `xfreerdp /port:13389 /v:127.0.0.1`; the primary
  # path is still RDP to `devbox` over the tailnet (unaffected).
  microvm.forwardPorts = [
    {
      host = {
        address = "127.0.0.1";
        port = 2222;
      };
      guest.port = 22;
    }
    {
      host = {
        address = "127.0.0.1";
        port = 13389;
      };
      guest.port = 3389;
    }
  ];

  # Read-only host store share (virtiofs) + writable overlay so in-guest
  # `nix build` / `nix develop` works and persists across reboots.
  microvm.shares = [
    {
      source = "/nix/store";
      mountPoint = "/nix/.ro-store";
      tag = "ro-store";
      proto = "virtiofs";
    }
  ];
  microvm.writableStoreOverlay = "/nix/.rw-store";

  # Persistent, sparse disks (backing images under /var/lib/microvms/devbox/).
  # Sizes are MiB. Sum (~205 GiB) stays under rowlett's free space so the VM
  # can never exhaust the host: worst case it hits ENOSPC inside the guest.
  microvm.volumes = [
    {
      image = "home-dev.img";
      mountPoint = "/home/dev";
      size = 184320;
    } # 180 GiB — repos, caches, docker data
    {
      image = "nix-overlay.img";
      mountPoint = config.microvm.writableStoreOverlay;
      size = 24576;
    } # 24 GiB
    {
      image = "tailscale-state.img";
      mountPoint = "/var/lib/tailscale";
      size = 1024;
    } # 1 GiB
  ];

  # writableStoreOverlay is incompatible with store optimisation (asserted).
  nix.optimise.automatic = false;
  nix.settings.auto-optimise-store = false;
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.settings.trusted-users = [
    "root"
    "dev"
  ];

  # Automatic GC of the writable store overlay so guest-built paths don't fill
  # the 24 GiB nix-overlay volume. (auto-optimise stays off — required with
  # writableStoreOverlay — but GC is independent and safe.)
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # ---- In-guest networking -------------------------------------------------
  networking.useNetworkd = true;
  systemd.network.enable = true;
  systemd.network.networks."10-usernet" = {
    matchConfig.Type = "ether";
    networkConfig.DHCP = "yes";
  };
  boot.kernelModules = [ "tun" ]; # tailscale needs /dev/net/tun

  # The home-dev volume mounts as a fresh, root-owned ext4 at /home/dev, so the
  # `dev` user (and home-manager activation) can't write to its own home. chown
  # it via tmpfiles, which runs after the mount. Without this, first-boot
  # home-manager fails and `gh auth login` / mkdir hit "permission denied".
  systemd.tmpfiles.rules = [
    "d /home/dev 0700 dev users - -"
  ];

  # VM has no LAN footprint; 22/3389 are reachable only via tailscale or the
  # loopback forwards, so opening them here is safe.
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [
    22
    3389
  ];

  # ---- Tailscale (its own tailnet node) ------------------------------------
  services.tailscale = {
    enable = true;
    # Match the rest of the fleet's test-disabling override.
    package = pkgs.tailscale.overrideAttrs (_: { doCheck = false; });
  };

  # ---- Desktop over RDP ----------------------------------------------------
  services.xserver.enable = true;
  services.xserver.desktopManager.xfce.enable = true;
  services.xserver.xkb.layout = "us";
  # No display-manager: xrdp starts its own X server per session.
  services.xrdp = {
    enable = true;
    defaultWindowManager = "xfce4-session";
    openFirewall = true; # opens 3389 (safe; no LAN — see note above)
  };

  # ---- Users ---------------------------------------------------------------
  users.users.dev = {
    isNormalUser = true;
    description = "dev";
    extraGroups = [
      "wheel"
      "docker"
    ];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICHR4q3amhKDhCF6+xa3oTXJX2ycN503+cEo/gpnOkFt git@chrismiller.xyz"
    ];
    # xrdp authenticates the RDP session via PAM, so `dev` needs a password.
    # Only reachable over the tailnet; `passwd` to change after first login
    # (or move to hashedPassword/agenix later). Terminal/agent access is
    # SSH-key + tailnet, so this password is only the RDP login gate.
    initialPassword = "devbox";
  };
  security.sudo.wheelNeedsPassword = false;
  programs.zsh.enable = true;

  # Serial-console autologin (ttyS0): break-glass + first-boot setup, before
  # tailscale or SSH keys are usable. `sudo tailscale up`, `gh auth login`.
  services.getty.autologinUser = "dev";

  # ---- SSH (tailnet + loopback forward) ------------------------------------
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
  };

  # ---- Git: HTTPS via gh; NO gpg signing, NO ssh signing -------------------
  # System-wide defaults; ~/.gitconfig stays writable so `gh auth setup-git`
  # and agents can adjust freely. A fresh HTTPS clone carries no repo-level
  # commit.gpgsign, so the signing headache can't follow a repo in here.
  environment.etc."gitconfig".text = ''
    [init]
        defaultBranch = main
    [commit]
        gpgsign = false
    [tag]
        gpgSign = false
    [push]
        autoSetupRemote = true
    [credential "https://github.com"]
        helper = !${pkgs.gh}/bin/gh auth git-credential
    [credential "https://gist.github.com"]
        helper = !${pkgs.gh}/bin/gh auth git-credential
  '';

  # ---- Tooling -------------------------------------------------------------
  environment.systemPackages = with pkgs; [
    # git + github (HTTPS auth via gh)
    git
    git-lfs
    gh
    # terminal + browsers
    kitty
    firefox
    chromium
    # desktop apps + panel plugins (launchers wired up in ./xfce-panel.nix)
    xfce.thunar # file manager ("directory")
    xfce.xfce4-whiskermenu-plugin # searchable app menu
    xfce.xfce4-taskmanager # system monitor (resource-capped VM)
    xfce.xfce4-screenshooter # screenshots
    # clipboard bits (RDP cliprdr does text+image; these help CLI + xfce)
    xfce.xfce4-clipman-plugin
    xclip
    xsel
    # dev baseline
    curl
    wget
    htop
    btop
    tmux
    neovim
    ripgrep
    jq
    fd
    tree
    file
    unzip
    docker-compose
    # ---- cache hygiene ----
    # sccache bounds the Rust compile cache (LRU auto-eviction at the cap set
    # in sessionVariables below); cargo-cache trims the registry/git caches.
    sccache
    cargo-cache
    # On-demand deep prune: docker, nix overlay GC, cargo registry, and any
    # git-IGNORED build dirs under /home/dev (target/.cargo-target/node_modules
    # only — never touches tracked files, same rule as the host cleanup).
    (pkgs.writeShellScriptBin "dev-prune" ''
      set -euo pipefail
      echo "== docker ==";        docker system prune -af || true
      echo "== nix overlay GC ==";sudo nix-collect-garbage -d || true
      echo "== cargo registry ==";cargo cache --autoclean || true
      echo "== sccache ==";       sccache --show-stats 2>/dev/null || true
      echo "== git-ignored build caches under /home/dev =="
      ${pkgs.findutils}/bin/find /home/dev -type d \
        \( -name node_modules -o -name target -o -name .cargo-target \) -prune 2>/dev/null \
      | while read -r d; do
          p=$(dirname "$d")
          if git -C "$p" check-ignore -q "$d" 2>/dev/null; then
            echo "  clearing $d"; rm -rf "$d"
          fi
        done
      echo "== usage =="; df -h /home/dev
    '')
    (pkgs.writeShellScriptBin "dev-usage" ''
      set -euo pipefail
      df -h /home/dev
      echo "-- largest dirs under /home/dev --"
      du -sh /home/dev/* 2>/dev/null | sort -rh | head -20
    '')
  ];

  # sccache config: cap the compile cache so it self-evicts (LRU) instead of
  # growing unbounded. Lives on the persistent dev volume. RUSTC_WRAPPER makes
  # cargo route through it automatically; unset per-project if a build dislikes
  # it.
  environment.sessionVariables = {
    RUSTC_WRAPPER = "sccache";
    SCCACHE_DIR = "/home/dev/.cache/sccache";
    SCCACHE_CACHE_SIZE = "30G";
  };

  # ---- Docker (rootful; data on the persistent dev volume) -----------------
  virtualisation.docker = {
    enable = true;
    package = pkgs.docker_29; # docker_28 is flagged insecure; match the fleet
    autoPrune.enable = true;
    daemon.settings.data-root = "/home/dev/.docker";
  };

  # ---- Self-healing --------------------------------------------------------
  systemd.services.xrdp.serviceConfig.Restart = lib.mkDefault "on-failure";
  systemd.services.xrdp.serviceConfig.RestartSec = lib.mkDefault "3s";
}
