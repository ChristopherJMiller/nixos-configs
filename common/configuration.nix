{ config, pkgs, ... }:

{
  # Enable networking
  networking.networkmanager.enable = true;
  systemd.services.NetworkManager-wait-online.enable = false;

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    # jack.enable = true;

    # Bluetooth audio configuration
    wireplumber = {
      enable = true;
      extraConfig = {
        "10-bluez" = {
          "monitor.bluez.properties" = {
            "bluez5.enable-sbc-xq" = true;
            "bluez5.enable-msbc" = true;
            "bluez5.enable-hw-volume" = true;
            # Classic Bluetooth headset roles (HSP/HFP) + A2DP + LE Audio (BAP)
            "bluez5.headset-roles" = [ "hsp_hs" "hsp_ag" "hfp_hf" "hfp_ag" ];
            # Re-enable LE Audio (BAP) with patched BlueZ that fixes Galaxy Buds3 Pro
            # Include both bap_sink and bap_source for full LE Audio support
            "bluez5.roles" = [ "hsp_hs" "hsp_ag" "hfp_hf" "hfp_ag" "a2dp_sink" "a2dp_source" "bap_sink" "bap_source" ];
            # Include lc3 codec for LE Audio support (Galaxy Buds3 Pro)
            "bluez5.codecs" = [ "sbc" "sbc_xq" "aac" "ldac" "aptx" "aptx_hd" "aptx_ll" "lc3" ];
          };
        };
        # Auto-switch to bluetooth when connected
        "11-bluetooth-policy" = {
          "wireplumber.settings" = {
            "bluetooth.autoswitch-to-headset-profile" = false;
          };
          "monitor.bluez.rules" = [
            {
              matches = [
                {
                  "device.name" = "~bluez_card.*";
                }
              ];
              actions = {
                update-props = {
                  "bluez5.auto-connect" = [ "a2dp_sink" "bap_sink" ];
                  "bluez5.hw-volume" = [ "a2dp_sink" "bap_sink" ];
                  # Force bap-duplex profile for LE Audio devices (Galaxy Buds3 Pro)
                  # Note: profile name is "bap-duplex", not "bap-sink"
                  "device.profile" = "bap-duplex";
                };
              };
            }
          ];
        };
        # Keep laptop microphone as default input
        "12-default-routes" = {
          "monitor.alsa.rules" = [
            {
              matches = [
                {
                  "node.name" = "alsa_input.pci-*";
                }
              ];
              actions = {
                update-props = {
                  "priority.driver" = 1000;
                  "priority.session" = 1000;
                };
              };
            }
          ];
        };
        # Auto-switch to Bluetooth sink when connected (higher priority)
        "13-bluetooth-default-sink" = {
          "monitor.bluez.rules" = [
            {
              matches = [
                {
                  "node.name" = "~bluez_output.*";
                }
              ];
              actions = {
                update-props = {
                  # Higher priority than laptop speakers (default ~1000)
                  # This makes Bluetooth become default sink when connected
                  "priority.driver" = 2000;
                  "priority.session" = 2000;
                };
              };
            }
          ];
        };
      };
    };
  };

  # Nix Garbage Collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # Nix Storage Optimization
  nix.optimise.automatic = true;
  nix.optimise.dates = [ "daily" ];

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    # Networking Tools
    wget
    curl

    # Git
    git
    git-lfs

    # System Tools
    efibootmgr
    btop
    neofetch
    eza

    # Keyboard Utils
    qmk
    qmk-udev-rules
    via

    # Bluetooth codecs for PipeWire
    sbc
    fdk_aac
  ];

  services.udev.packages = [ pkgs.via ];

  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
  };

  environment.variables.EDITOR = "nvim";

  programs.zsh.enable = true;
  programs.zsh.shellAliases = {
    nixr = "sudo nixos-rebuild switch --flake ~/nixos";
    nixu = "nix flake update --flake ~/nixos --commit-lock-file && nixr";
    nixs = "nix-shell";
    nixclean = "sudo nix-collect-garbage -d";
    nixrepair = "sudo nix-store --verify --check-contents --repair";
    htop = "btop";
    ls = "eza";
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  # Enable Nix Flakes
  nix = {
    package = pkgs.nixVersions.stable;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  # Standard Fonts
  fonts = {
    packages = with pkgs; [
      material-design-icons
      font-awesome
      noto-fonts
      noto-fonts-emoji
      source-sans
      nerd-fonts.fira-code
      nerd-fonts.jetbrains-mono
      nerd-fonts.hack
    ];

    fontconfig.defaultFonts = {
      serif = [ "Noto Serif" "Noto Color Emoji" ];
      sansSerif = [ "Noto Sans" "Noto Color Emoji" ];
      monospace = [ "Hack Nerd Font" "Noto Color Emoji" ];
      emoji = [ "Noto Color Emoji" ];
    };
  };
}
