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

  # Enable RDP
  services.xrdp.enable = true;
  services.xrdp.defaultWindowManager = "startplasma-x11";
  services.xrdp.openFirewall = true;

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
    autoPrune = {
      enable = true;
    };
    rootless = {
      enable = true;
      setSocketVariable = true;
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
