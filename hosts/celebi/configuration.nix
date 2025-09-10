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

  # Systemd-boot lets you mash the space bar to select a boot entry
  # when timeout is set to 0
  boot.loader.timeout = 0;

  networking.hostId = "f5ae0848";

  networking.hostName = "celebi"; # Define your hostname.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;
  systemd.services.NetworkManager-wait-online.enable = false;

  # Set timezone to be automatic
  services.automatic-timezoned.enable = true;
  services.geoclue2.geoProviderUrl = "https://api.beacondb.net/v1/geolocate";

  # Delay time sync until network online
  systemd.services.systemd-timesyncd.wantedBy = [ "network-online.target" ];

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

  # Enable Fingerprint Daemon
  services.fprintd.enable = true;
  # Disable fprint for login PAM service to
  # disable fingerprint authentication for login
  # which fixes interactions between SDDM-KDE handoff
  # and KWallet Authentication.
  security.pam.services.login.fprintAuth = false;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  nixpkgs.config.allowUnfree = true;

  # Power Management
  powerManagement.enable = true;
  services.power-profiles-daemon.enable = false;
  services.tlp.enable = true;
  services.thermald.enable = true;

  # Bluetooth Support
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  # GPU Support
  services.xserver.videoDrivers = [ "amdgpu" ];
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  services.flatpak.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.chris = {
    isNormalUser = true;
    description = "Chris";
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
    ];
    shell = pkgs.zsh;
  };

  programs.gnupg.agent.pinentryPackage = pkgs.pinentry-qt;

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  services.tailscale = {
    enable = true;
    # Disable tests to work around build failures
    package = pkgs.tailscale.overrideAttrs (oldAttrs: {
      doCheck = false;
    });
  };

  security.pam.services.kwallet = {
    name = "kwallet";
    enableKwallet = true;
  };

  # Enable Docker
  virtualisation.docker = {
    enable = true;
    enableOnBoot = false;
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

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
}
