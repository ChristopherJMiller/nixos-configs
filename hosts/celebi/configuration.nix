{
  config,
  pkgs,
  lib,
  customPackages,
  ...
}:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix

    # Include Common Configuration Options
    ../../common/configuration.nix
    ../../common/sddm-avatar.nix
    ../../common/ipad-display.nix
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

  # Fix S2idle and AMD GPU suspend issues
  # Based on Framework 13 AMD 7640U community fixes
  boot.kernelParams = [
    "amd_pstate=active" # Use active AMD P-state driver for better power management
    "amdgpu.runpm=1" # Enable runtime PM for AMD GPU
    "amdgpu.dcdebugmask=0x10" # Reduce GPU debug logging (helps with black screens)
    "pcie_aspm=off" # Fix suspend/resume crashes on Framework AMD (kernel 6.12.x)
    "rtc_cmos.use_acpi_alarm=1" # Better RTC handling for S2idle
  ];

  networking.hostId = "f5ae0848";

  networking.hostName = "celebi"; # Define your hostname.

  networking.hosts = {
    "127.0.0.1" = [
      "kanidm.hearth.local"
      "api.hearth.local"
      "chat.hearth.local"
      "cloud.hearth.local"
      "grafana.hearth.local"
      "cache.hearth.local"
    ];
  };

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking with iwd backend (better driver for some routers)
  networking.networkmanager = {
    enable = true;
    wifi.backend = "iwd";
  };
  systemd.services.NetworkManager-wait-online.enable = false;

  # iwd WiFi backend settings
  networking.wireless.iwd = {
    enable = true;
    settings = {
      General = {
        EnableNetworkConfiguration = false; # Let NetworkManager handle IPs
      };
      Network = {
        EnableIPv6 = true;
      };
    };
  };

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
  # Power-profiles-daemon for better AMD GPU suspends
  powerManagement.enable = true;
  services.power-profiles-daemon.enable = true;
  services.tlp.enable = false;
  services.thermald.enable = true;

  # Framework-specific features
  # Enables EC control for battery charge limits, privacy switches, LEDs
  hardware.framework.enableKmod = true;

  # Firmware updates via fwupd (automatically enabled by nixos-hardware module)
  # Use 'fwupdmgr update' to check for and install firmware updates

  # Battery charge limit (OS-level, independent of BIOS setting)
  # Note: BIOS setting takes precedence, but OS setting is useful for runtime control
  # Set to desired percentage (e.g., 80 for 80% max charge)
  systemd.services.battery-charge-threshold = {
    description = "Set battery charge threshold";
    wantedBy = [
      "multi-user.target"
      "post-resume.target"
    ];
    after = [
      "multi-user.target"
      "post-resume.target"
    ];
    startLimitBurst = 5;
    startLimitIntervalSec = 1;
    serviceConfig = {
      Type = "oneshot";
      Restart = "on-failure";
      ExecStart = "${pkgs.bash}/bin/bash -c 'echo 80 > /sys/class/power_supply/BAT1/charge_control_end_threshold'";
    };
  };

  # Bluetooth Support with patched BlueZ for Galaxy Buds3 Pro
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    # Use patched BlueZ with Galaxy Buds3 Pro metadata_context fix
    package = (customPackages pkgs).bluez-patched;
    settings = {
      General = {
        # Enable experimental features for LE Audio support (LC3 codec, BAP profile)
        Experimental = true;
        # Kernel experimental UUID for LE Audio ISO socket support
        # Required for Galaxy Buds3 Pro and other LE Audio devices
        KernelExperimental = "6fbaf188-05e0-496a-9885-d6ddfdb4e03e";
        FastConnectable = true;
      };
      Policy = {
        AutoEnable = true;
      };
    };
  };

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
      "ydotool"
      "usbmux"
    ];
    shell = pkgs.zsh;
  };

  programs.gnupg.agent.pinentryPackage = pkgs.pinentry-qt;

  # List services that you want to enable:

  programs.nix-ld.enable = true;
  programs.ydotool.enable = true;

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  services.tailscale = {
    enable = true;
    # Disable tests to work around build failures
    package = pkgs.tailscale.overrideAttrs (oldAttrs: {
      doCheck = false;
    });
  };

  services.mullvad-vpn = {
    enable = true;
    package = pkgs.mullvad-vpn;
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

  # Mount binderfs for Redroid (Android-in-Docker) emulator containers.
  # Kernel has CONFIG_ANDROID_BINDER_IPC=y and CONFIG_ANDROID_BINDERFS=y built-in.
  # Redroid needs this to provide binder IPC inside containers.
  fileSystems."/dev/binderfs" = {
    device = "binderfs";
    fsType = "binder";
    options = [ "nosuid" "nodev" "noexec" ];
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
  # NixOS (nixpkgs#139526) and Mullvad DNS is hit-or-miss.
  services.resolved = {
    enable = true;
    # Last-resort resolvers so the box keeps DNS when every tunnel is down
    # or a tunnel pushed a private resolver that is unreachable.
    fallbackDns = [ "1.1.1.1" "9.9.9.9" ];
  };

  # Make USB-tethered phone hotspots a low-priority default route so wifi
  # wins when both are up. Regular wired ethernet (docks, onboard NICs) is
  # unaffected because systemd's predictable naming only appends "u<N>" for
  # USB-attached network devices. `mountthor-up` still pins specific host
  # routes via the tether explicitly.
  networking.networkmanager.settings = {
    "connection-usb-tether-low-priority" = {
      match-device = "interface-name:enp*u*";
      "ipv4.route-metric" = 700;
      "ipv6.route-metric" = 700;
    };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
}
