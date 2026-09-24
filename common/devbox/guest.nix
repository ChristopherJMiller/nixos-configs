# common/devbox/guest.nix
#
# The `devbox` dev VM: a headless XFCE desktop reached over RDP, on TWO
# tailnets (see ./tailnets.nix). Runs as an OFF-BY-DEFAULT qemu microVM on
# rowlett (see flake.nix: `microvm.vms.devbox`, autostart = false).
#
# Access model:
#   * In — the PERSONAL tailnet makes it `devbox`: RDP (xfreerdp / Remmina /
#     KRDC) or `ssh dev@devbox` from anywhere on it. That daemon runs in
#     userspace mode (no TUN) purely as the inbound door.
#   * Out — the WORK tailnet owns the VM's real TUN (tailscale0): work peers,
#     subnet routes and MagicDNS are transparent to every program, incl.
#     docker. Shields up, so work peers can't reach in.
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
  imports = [ ./tailnets.nix ];

  networking.hostName = "devbox";
  system.stateVersion = "25.11";

  # ---- microVM shape -------------------------------------------------------
  microvm.hypervisor = "qemu";
  microvm.vcpu = 12; # of rowlett's 16 threads

  # ---- Memory ---------------------------------------------------------------
  # rowlett has 31 GiB and its own desktop wants ~13 of them. The guest's RAM
  # is a host memfd that the host can only reclaim by SWAPPING it out, and the
  # guest fills whatever it is given with page cache within a day. At 26 GiB
  # that ended (2026-09-21) with 15 GiB of guest memory in rowlett's swap, a
  # guest thrashing so hard that sshd dropped connections at key exchange
  # ("can't reach devbox" — tailscale and the loopback forward were both fine),
  # and a `devvm-down` that crawled while the host paged it all back in at
  # ~80 MB/s. Three levers, all needed:
  #  1) mem: a ceiling rowlett can actually back. 16 GiB touched-set worst
  #     case leaves the host ~15 GiB — headroom over what it uses.
  #  2) balloon: virtio-balloon with free-page-reporting. The guest hands
  #     freed pages (a finished build, evicted cache) back to the host instead
  #     of them staying resident-or-swapped until the VM stops. Nothing ever
  #     inflates it from the host (no initialBalloonMem, no `microvm-balloon`
  #     calls) — only the reporting side is in play. qemu 10.x no longer
  #     inhibits balloon discards for vhost-user devices, so the virtiofs
  #     ro-store share below doesn't defeat it.
  #  3) direct on the data volumes (below): qemu opens them O_DIRECT so the
  #     host doesn't ALSO page-cache home-dev.img / nix-overlay.img. That
  #     second copy of the guest's disk data was ~17 GiB of the host's RAM
  #     while the guest's own copy of the same data sat in swap.
  # `devvm-mem` on rowlett shows the guest's resident/swapped footprint.
  microvm.mem = 16384; # 16 GiB
  microvm.balloon = true; # -device virtio-balloon-pci,free-page-reporting=on

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
  # Sizes are MiB (max apparent size; images are sparse, so real host usage
  # tracks only what's written — AND what was written-then-freed until the
  # guest TRIMs; see services.fstrim below). WARNING: these sum to ~230 GiB
  # and rowlett's disk runs nearly full — if the guest fills home-dev AND the
  # store overlay it CAN exhaust the host, not just hit ENOSPC in the guest.
  # The nix min-free/GC settings below (plus `dev-prune`) keep the overlay
  # bounded; check `df -h /` on the host before growing any of these.
  # `direct` = O_DIRECT (cache=none): the guest already page-caches its own
  # disks, so a host-side copy is pure double-caching (see Memory above).
  # Guest flushes are still honoured; this is the standard VM-disk mode.
  microvm.volumes = [
    {
      image = "home-dev.img";
      mountPoint = "/home/dev";
      size = 184320;
      direct = true;
    } # 180 GiB — repos, caches, docker data
    {
      image = "nix-overlay.img";
      mountPoint = config.microvm.writableStoreOverlay;
      size = 49152;
      direct = true;
    } # 48 GiB
    {
      image = "tailscale-state.img";
      mountPoint = "/var/lib/tailscale";
      size = 1024;
    } # 1 GiB — personal tailnet node key/prefs
    {
      image = "tailscale-work-state.img";
      mountPoint = "/var/lib/tailscale-work";
      size = 1024;
    } # 1 GiB — work tailnet node key/prefs (./tailnets.nix); rootfs is
    #   tmpfs, so without this the SSO login would be lost on every boot
  ];

  # Hand freed blocks back to rowlett. qemu runs these volumes with
  # discard=unmap, but nothing in the guest ever issued a TRIM, so every block
  # the guest freed (docker prune, nix GC, cargo clean…) stayed allocated in
  # the sparse image on the host. Found 2026-09-20: /home/dev held 44 GiB
  # inside the guest while home-dev.img occupied 157 GiB on rowlett (+40 GiB
  # of the same in nix-overlay.img) — that's the "rowlett disk mysteriously
  # near-full" pressure. Monotonic timer (boot + every 6h) instead of the
  # module's weekly OnCalendar: the rootfs is tmpfs so Persistent= has no
  # stamp to catch up from, and a wall-clock slot would rarely coincide with
  # this off-by-default VM being up. `sudo fstrim -av` runs it by hand.
  services.fstrim.enable = true;
  systemd.timers.fstrim.timerConfig = {
    OnBootSec = "5min";
    OnUnitActiveSec = "6h";
    AccuracySec = "1min"; # upstream timer: 1h
    RandomizedDelaySec = "1min"; # upstream timer: 100min
  };

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

  # Keep the 48 GiB writable store overlay from filling up — a full overlay
  # means failed/half-written builds and a guest that can't stage a new
  # closure. (The "my shell config got nuked" symptom turned out to be
  # separate: home-manager activation silently failing at boot — see the
  # `home-manager.overwriteBackup` note in flake.nix.) Two independent layers:
  #   1) min-free/max-free: DURING a build, if free store space drops below
  #      min-free, nix garbage-collects until max-free is available. This is
  #      the important one — it prevents ENOSPC mid-build without waiting for
  #      a timer, which is the usual "ran out of space and everything broke"
  #      trigger.
  #   2) a scheduled GC every 6h with short retention, as a background floor.
  # (auto-optimise stays off — required with writableStoreOverlay — but GC and
  # min-free are independent of it and safe.)
  nix.gc = {
    automatic = true;
    dates = "*-*-* 00/6:00:00"; # every 6 hours
    options = "--delete-older-than 3d";
    persistent = true; # run a missed GC on next boot (VM is off-by-default)
  };
  nix.settings.min-free = 5368709120; # 5 GiB — GC triggers below this free
  nix.settings.max-free = 10737418240; # 10 GiB — GC frees up to this much

  # ---- In-guest networking -------------------------------------------------
  networking.useNetworkd = true;
  systemd.network.enable = true;
  systemd.network.networks."10-usernet" = {
    matchConfig.Type = "ether";
    networkConfig.DHCP = "yes";
  };
  boot.kernelModules = [
    "tun" # the work tailscale's TUN (tailnets.nix)
    "virtio_balloon" # free-page-reporting (udev would autoload it; be explicit)
  ];

  # The home-dev volume mounts as a fresh, root-owned ext4 at /home/dev, so the
  # `dev` user (and home-manager activation) can't write to its own home. chown
  # it via tmpfiles, which runs after the mount. Without this, first-boot
  # home-manager fails and `gh auth login` / mkdir hit "permission denied".
  systemd.tmpfiles.rules = [
    "d /home/dev 0700 dev users - -"
  ];

  # VM has no LAN footprint. Personal-tailnet inbound arrives via loopback
  # (userspace daemon, see tailnets.nix) and never meets these rules; they
  # matter only for rowlett's loopback forwards, which land on the slirp NIC.
  # The work TUN is covered by that node's shields-up packet filter.
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [
    22
    3389
  ];
  # mosh for resilient shells into the VM over the tailnet (survives roaming /
  # flaky links). Installs mosh system-wide and opens its UDP range
  # (60000-61000); no LAN footprint here, so it's safe. Pair with tmux for
  # persistence: `mosh dev@devbox -- tmux new -A -s main`.
  programs.mosh.enable = true;

  # ---- Tailscale -----------------------------------------------------------
  # Both daemons (personal = inbound door, work = the VM's TUN) live in
  # ./tailnets.nix, together with the reasoning for that split.

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
  # Identity is the mounthor account (chris@mounthor.com) — this VM is for
  # mounthor work; `gh auth login` here should use that GitHub account.
  # url.insteadOf routes any git@github.com: remote through HTTPS+gh, since
  # the VM has no SSH keys (mirrors ../../common/git.nix on the hosts).
  environment.etc."gitconfig".text = ''
    [init]
        defaultBranch = main
    [user]
        name = Christopher Miller
        email = chris@mounthor.com
    [commit]
        gpgsign = false
    [tag]
        gpgSign = false
    [push]
        autoSetupRemote = true
    [url "https://github.com/"]
        insteadOf = git@github.com:
        insteadOf = ssh://git@github.com/
    [credential "https://github.com"]
        helper = !${pkgs.gh}/bin/gh auth git-credential
    [credential "https://gist.github.com"]
        helper = !${pkgs.gh}/bin/gh auth git-credential
  '';

  # Firefox as a NixOS program (not a bare package) so policies can be
  # attached declaratively — the personal-tailnet PAC in ./tailnets.nix.
  programs.firefox.enable = true;

  # ---- Tooling -------------------------------------------------------------
  environment.systemPackages = with pkgs; [
    # git + github (HTTPS auth via gh)
    git
    git-lfs
    gh
    # terminal + browsers (firefox comes via programs.firefox below so
    # ./tailnets.nix can attach a proxy policy to it)
    kitty
    chromium
    # desktop apps + panel plugins (launchers wired up in ./xfce-panel.nix)
    thunar # file manager ("directory")
    xfce4-whiskermenu-plugin # searchable app menu
    xfce4-taskmanager # system monitor (resource-capped VM)
    xfce4-screenshooter # screenshots
    # clipboard bits (RDP cliprdr does text+image; these help CLI + xfce)
    xfce4-clipman-plugin
    xclip
    xsel
    # dev baseline
    curl
    wget
    htop
    btop
    # tmux is provided per-user with config via home-manager (common/tmux.nix)
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
    # Repair the dev user's shell after a disk-full / corruption event WITHOUT
    # touching the VM. Clears only regenerable zsh runtime state (never the
    # shell history) and re-runs home-manager activation, which relinks every
    # managed dotfile from the read-only store. Run it INSIDE the VM
    # (`ssh dev@devbox`, then `dev-fix-shell`) when the prompt/completion breaks
    # but the VM still boots. If the VM won't boot at all (corrupt store
    # overlay), use the host's `devvm-reset-overlay` instead. If the
    # activation step fails, `journalctl -u home-manager-dev` has the reason —
    # for weeks it was an xfconf-vs-home-manager file collision that
    # `home-manager.overwriteBackup` (flake.nix) now resolves.
    (pkgs.writeShellScriptBin "dev-fix-shell" ''
      set -euo pipefail
      echo "== clearing regenerable zsh state (history is kept) =="
      rm -rf "$HOME/.zplug" "$HOME/.cache/gitstatus" "$HOME/.cache/p10k"* \
             "$HOME"/.zcompdump* "$HOME/.zcompcache" 2>/dev/null || true
      echo "== re-running home-manager activation (relinks managed dotfiles) =="
      sudo systemctl restart home-manager-dev.service
      echo "== done — run 'exec zsh' or open a new terminal for a clean shell =="
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
    autoPrune.enable = true;
    daemon.settings.data-root = "/home/dev/.docker";
  };

  # ---- Self-healing --------------------------------------------------------
  systemd.services.xrdp.serviceConfig.Restart = lib.mkDefault "on-failure";
  systemd.services.xrdp.serviceConfig.RestartSec = lib.mkDefault "3s";

  # ---- Shutdown ------------------------------------------------------------
  # The `dev` user's `systemd --user` instance never stops cleanly under an RDP
  # session (gvfs FUSE / xfce user services) and holds the ENTIRE shutdown for
  # user@.service's default 120 s stop timeout: 2026-09-21 console trace,
  # "Stopping User Manager for UID 1000" 09:06:40 → next line 09:08:41. Until
  # it dies, /home/dev can't unmount, so every `devvm-down` paid those two
  # minutes (and before the host-side TimeoutStopSec was raised, got SIGKILLed
  # mid-unmount instead). Nothing here needs the grace: the session scope has
  # already been SIGTERMed by this point, repos live on ext4, and tmux/editors
  # die with the VM regardless. Cap it.
  systemd.services."user@" = {
    overrideStrategy = "asDropin";
    serviceConfig.TimeoutStopSec = "30s";
  };

  # TEMPORARY INSTRUMENTATION (added 2026-09-22) — remove once the shutdown
  # freeze described here is root-caused.
  #
  # Twice now (2026-09-14, 2026-09-22) the guest has frozen at the very end of
  # shutdown: "[!!!!!!] Failed to execute shutdown binary." → "Freezing
  # execution." qemu then never exits, so the host burns the whole
  # TimeoutStopSec=10min net and SIGKILLs it with every volume still mounted
  # rw. From t=0 of the stop, nothing needing fork+exec of a store binary
  # worked — run-initramfs.mount and save-hwclock failed instantly (neither is
  # sandboxed; both just spawn a plain store binary), every umount failed in
  # the same second, then PID 1's own execv of systemd-shutdown failed. Both
  # freezes had an xrdp session with drive redirection live
  # (/home/dev/thinclient_drives mounted); the six clean shutdowns had none.
  # virtiofsd stayed connected throughout and there was no guest OOM, so the
  # store backend and the 09-21 memory changes are both ruled out.
  #
  # What's missing is the errno, and we can't get it after the fact: / is
  # tmpfs, so the guest journal dies with the VM, and PID 1 is frozen by the
  # time we notice. Mirroring the journal to ttyS0 puts it in the host's
  # `journalctl -u microvm@devbox`, which survives. info (not warning) on
  # purpose: this fires maybe once a week, so catch the reason on the first
  # reproduction rather than re-instrumenting. Costs a chunk of host journal
  # volume while it's on, and rowlett has been tight on disk.
  #
  # To reproduce: connect RDP with drive redirection, then `devvm-down`.
  services.journald.extraConfig = ''
    ForwardToConsole=yes
    MaxLevelConsole=info
  '';
}
