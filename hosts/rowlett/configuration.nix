# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix

    # Include Common Configuration Options
    ../../common/configuration.nix
    ../../common/sddm-avatar.nix
  ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.supportedFilesystems = [
    "ext4"
    "exfat"
    "fat32"
    "ntfs"
    "zfs"
  ];
  boot.zfs.forceImportRoot = false;
  networking.hostId = "67360d1b";

  # aarch64 binfmt: lets `nix build` cross-compile aarch64-linux derivations
  # transparently (via qemu user-mode emulation). Needed to build SD images
  # for the satellites/ Pis from this x86_64 host.
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  networking.hostName = "rowlett"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Set your time zone.
  time.timeZone = "America/Los_Angeles";

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the KDE Plasma Desktop Environment.
  services.displayManager = {
    sddm.enable = true;
    sddm.wayland.enable = true;
    sddm.wayland.compositor = "kwin";
    defaultSession = "plasma";
  };

  services.desktopManager.plasma6.enable = true;

  # Enable RDP. The xrdp session runs XFCE, NOT Plasma. Plasma 6 boots through
  # the per-user systemd manager and owns single-instance D-Bus names
  # (org.kde.KWin, org.kde.plasmashell, org.kde.ksmserver ...), so a second
  # Plasma session for the same user -- which is exactly what xrdp spawns while
  # you are logged into Plasma locally on seat0 -- black-screens: plasmashell
  # never starts on the new display and kwin_x11 restart-loops forever. XFCE
  # has no such conflict, so this yields a separate remote desktop alongside
  # the local Plasma session (same approach as the devbox guest, see
  # common/devbox/guest.nix). SDDM gains an extra "Xfce Session" entry; the
  # default session stays Plasma. Deliberately `xfce4-session`, NOT
  # `startxfce4`: the latter runs xinitrc, which does
  # `dbus-update-activation-environment --systemd --all` and would overwrite
  # DISPLAY / XDG_SESSION_* in the shared user systemd manager with the RDP
  # session's values, breaking the local Plasma session's services.
  services.xserver.desktopManager.xfce.enable = true;
  services.xrdp.enable = true;
  # The session is launched through a wrapper, for two reasons:
  #  1) Force X11 backends. The local Plasma Wayland session's socket
  #     ($XDG_RUNTIME_DIR/wayland-0) is visible to the RDP session, and
  #     libwayland falls back to exactly that name when WAYLAND_DISPLAY is
  #     unset. GTK3/4 and Qt prefer Wayland when a socket is reachable, so
  #     without this every XFCE component attaches to the LOCAL compositor
  #     (panel + desktop pop up on the physical screen, xfwm4 never starts)
  #     and the RDP display stays black.
  #  2) Indirect through /run/current-system so the xrdp.conf derivation --
  #     and therefore xrdp-sesman's unit -- does not change when the wrapper
  #     does. The NixOS module sets X-RestartIfChanged=false on sesman (a
  #     restart drops live RDP sessions), so any change to the *literal*
  #     startwm command silently keeps the OLD one until
  #     `sudo systemctl restart xrdp-sesman`. With the indirection, wrapper
  #     edits apply on the next RDP login.
  services.xrdp.defaultWindowManager = "/run/current-system/sw/bin/xrdp-xfce-session";
  services.xrdp.openFirewall = true;
  environment.systemPackages = [
    # Searchable app menu for the xrdp XFCE panel (./xfce-panel.nix in home).
    pkgs.xfce.xfce4-whiskermenu-plugin
    (pkgs.writeShellScriptBin "xrdp-xfce-session" ''
      unset WAYLAND_DISPLAY
      export GDK_BACKEND=x11
      export QT_QPA_PLATFORM=xcb
      export SDL_VIDEODRIVER=x11
      export CLUTTER_BACKEND=x11
      export MOZ_ENABLE_WAYLAND=0
      export ELECTRON_OZONE_PLATFORM_HINT=x11
      export XDG_SESSION_TYPE=x11
      # Do not let xfce4-session spawn its own ssh-agent: it exports the new
      # SSH_AUTH_SOCK into the shared user systemd manager, replacing the
      # gpg-agent socket the local Plasma session (and everything dbus- or
      # systemd-started) relies on. gpg-agent already serves SSH here.
      ${pkgs.xfce.xfconf}/bin/xfconf-query -c xfce4-session \
        -p /startup/ssh-agent/enabled -n -t bool -s false
      exec xfce4-session
    '')
  ];

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  nixpkgs.config.allowUnfree = true;

  nix.settings.trusted-users = [ "root" "@wheel" ];

  # Trust the nixos-raspberrypi binary cache so SD-image builds for the
  # satellites/ Pis don't recompile the kernel / ffmpeg / etc. from source
  # under aarch64 emulation. Without these lines, the flake's nixConfig
  # substituter additions are silently ignored in non-interactive builds.
  # christopherjmiller.cachix.org receives our own SD-image build outputs
  # via the satellites-sd-images GitHub Actions workflow (runs on native
  # aarch64 runners), so subsequent local builds just substitute.
  nix.settings.trusted-substituters = [
    "https://nixos-raspberrypi.cachix.org"
    "https://christopherjmiller.cachix.org"
  ];
  nix.settings.trusted-public-keys = [
    "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
    "christopherjmiller.cachix.org-1:SpwpBjcK+4KV9+rd6V5+01ivGMu4KPBytdgbst3GNnE="
  ];

  # GPU Support
  services.xserver.videoDrivers = [ "amdgpu" ];

  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;
  hardware.graphics.extraPackages = with pkgs; [
    vulkan-loader
    vulkan-tools
    vulkan-headers
    vulkan-validation-layers
    vulkan-extension-layer
  ];

  # QMK Keyboard Support
  hardware.keyboard.qmk.enable = true;

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  services.flatpak.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.chris = {
    isNormalUser = true;
    description = "Chris Miller";
    extraGroups = [
      "scanner"
      "lp"
      "networkmanager"
      "wheel"
      "docker"
      "dialout"
      "input"
      "ydotool"
    ];
    shell = pkgs.zsh;
    linger = true;
  };

  programs.gnupg.agent.pinentryPackage = pkgs.pinentry-qt;

  # List services that you want to enable:

  programs.nix-ld.enable = true;
  programs.ydotool.enable = true;

  # Scanner support (SANE) for digitising source documents — see
  # ../../common/genealogy.nix, which installs simple-scan + OCR tooling.
  # sane-airscan covers modern driverless network scanners (eSCL/WSD);
  # USB devices come from the default backends plus the udev rules this
  # option installs. Chris is in the "scanner" and "lp" groups above so the
  # devices are reachable without root.
  hardware.sane.enable = true;
  hardware.sane.extraBackends = [ pkgs.sane-airscan ];

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;
  services.openssh.settings.X11Forwarding = true;

  services.tailscale = {
    enable = true;
    # Disable tests to work around build failures
    package = pkgs.tailscale.overrideAttrs (oldAttrs: {
      doCheck = false;
    });
  };

  # Give the devbox guest time to shut down cleanly. microvm.nix's template
  # sets TimeoutSec=150 (start AND stop); the guest's own shutdown can take
  # longer than that when an RDP session is up — the xrdp `thinclient_drives`
  # and gvfs FUSE mounts stall the /home/dev unmount for its full 90 s job
  # timeout before systemd gives up on them (seen 2026-09-14: stop requested
  # 11:04:20, SIGKILLed by the host at 11:06:53 mid-shutdown). Every such kill
  # is an unclean unmount of home-dev.img and nix-overlay.img, which is the
  # "corrupt nix DB / half-written state" failure `devvm-reset-overlay` exists
  # for. Only the stop side is raised; startup keeps microvm's default.
  systemd.services."microvm@devbox" = {
    overrideStrategy = "asDropin";
    serviceConfig.TimeoutStopSec = "10min";
  };

  # devbox dev VM controls (off-by-default microVM; see common/devbox/).
  # `devvm-up` wakes it, its tailscale lights up, then RDP/SSH over the tailnet.
  # `devvm-console` is break-glass: it stops the service and runs the qemu
  # runner in the foreground so you get the autologin serial console (Ctrl-a x
  # to quit) — used for first-boot `tailscale up` / `gh auth login`.
  programs.zsh.shellAliases = {
    devvm-up = "sudo systemctl start microvm@devbox";
    devvm-down = "sudo systemctl stop microvm@devbox";
    devvm-status = "systemctl status microvm@devbox";
    devvm-log = "journalctl -u microvm@devbox -f";
    # Apply a rebuilt devbox config to the RUNNING VM. `nixos-rebuild switch`
    # on rowlett rebuilds and stages the guest (updates the `current` symlink),
    # but the live VM keeps running its old `booted` closure until restarted —
    # this restarts it into the staged config. (If the VM is off, `devvm-up`
    # already starts it on the new config; no need for this.)
    devvm-update = "sudo systemctl restart microvm@devbox && echo 'devbox restarted into current config; devvm-log to watch it boot'";
    # Foreground console for first-boot/break-glass. Two gotchas baked in:
    #  1) virtiofsd is PartOf microvm@devbox, so stopping the service kills the
    #     store-share daemon — start it back up before the foreground run.
    #  2) the runner does a relative `touch home-dev.img`, so cwd must be the
    #     state dir. Quit qemu with Ctrl-a x, then `devvm-up`.
    devvm-console = "sudo systemctl stop microvm@devbox && sudo systemctl start microvm-virtiofsd@devbox && ( cd /var/lib/microvms/devbox && sudo -u microvm ./current/bin/microvm-run )";
    # Recovery for a corrupt writable store overlay. Symptom: the VM restart-
    # loops into emergency mode, `devvm-log` showing "[FAILED] Failed to start
    # Find NixOS closure" every boot (an unclean guest shutdown corrupts the
    # Nix store DB in nix-overlay.img; the boot closure itself is fine on the
    # host, so a host rebuild does NOT fix it). This wipes that overlay — it
    # holds only guest-built, rebuildable store paths and is never needed to
    # boot — and lets microvm recreate it fresh on start. /home/dev (repos,
    # docker, sccache/cargo caches) and tailscale-state are on separate volumes
    # and are untouched. The dev user's shell config is store-managed, so
    # home-manager activation on the fresh boot restores it automatically. If
    # the VM boots fine and only the shell is broken, DON'T wipe the overlay —
    # run `dev-fix-shell` inside the VM instead.
    devvm-reset-overlay = "echo 'Wipes nix-overlay.img (guest nix build cache; rebuildable). /home/dev + tailscale state untouched.' && read -q 'REPLY?Proceed? [y/N] ' && echo && sudo systemctl stop microvm@devbox && sudo rm -f /var/lib/microvms/devbox/nix-overlay.img && sudo systemctl start microvm@devbox && echo 'overlay recreated; devvm-log to watch it boot'";
  };

  # OOM safety net for development workloads
  services.earlyoom = {
    enable = true;
    freeMemThreshold = 5;
    freeSwapThreshold = 10;
    enableNotifications = true;
  };

  security.pam.services.kwallet = {
    name = "kwallet";
    enableKwallet = true;
  };

  # Enable Docker
  virtualisation.docker = {
    enable = true;
    package = pkgs.docker_29;
    autoPrune = {
      enable = true;
    };
    rootless = {
      enable = true;
      setSocketVariable = true;
      package = pkgs.docker_29;
    };
    daemon.settings = {
      features = {
        buildkit = true;
      };
    };
  };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;
  # (mosh — resilient remote shells — is enabled fleet-wide in
  # ../../common/configuration.nix, which opens its UDP range.)

  # VPN-friendly networking defaults.
  # Without these, any non-trivial WireGuard tunnel (wg-quick configs,
  # Mullvad, ad-hoc dev VPNs) will handshake successfully but silently drop
  # return traffic because strict rpfilter rejects decrypted packets whose
  # src IP doesn't match the kernel FIB's expected interface.
  networking.firewall.checkReversePath = "loose";

  # systemd-resolved so per-interface DNS (resolvectl dns <iface> <ip>) works
  # cleanly. Without it, wg-quick's `DNS = ...` line is silently a no-op on
  # NixOS (nixpkgs#139526).
  services.resolved = {
    enable = true;
    # Last-resort resolvers so the box keeps DNS when every tunnel is down
    # or a tunnel pushed a private resolver that is unreachable.
    fallbackDns = [ "1.1.1.1" "9.9.9.9" ];
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?

}
