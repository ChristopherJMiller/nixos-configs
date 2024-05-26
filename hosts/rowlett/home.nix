{ config, pkgs, ... }:

{
  home.username = "chris";
  home.homeDirectory = "/home/chris";

  # link the configuration file in current directory to the specified location in home directory
  # home.file.".config/i3/wallpaper.jpg".source = ./wallpaper.jpg;

  home.file.".p10k.zsh".source = ../../common/p10k.zsh;
  home.file.".config/plasma-org.kde.plasma.desktop-appletsrc".source = ../../common/plasma-applets.txt;
  home.file.".face.icon".source = ./icon.png;

  services.vscode-server.enable = true;

  # link all files in `./scripts` to `~/.config/i3/scripts`
  # home.file.".config/i3/scripts" = {
  #   source = ./scripts;
  #   recursive = true;   # link recursively
  #   executable = true;  # make all files executable
  # };

  # encode the file content in nix configuration file directly
  # home.file.".xxx".text = ''
  #     xxx
  # '';

  # set cursor size and dpi for 4k monitor
  #xresources.properties = {
  #  "Xcursor.size" = 16;
  #  "Xft.dpi" = 172;
  #};

  # basic configuration of git, please change to your own
  programs.git = {
    enable = true;
    userName = "Christopher Miller";
    userEmail = "git@chrismiller.xyz";
    lfs.enable = true;
    extraConfig = {
      init.defaultBranch = "main";
    };
    signing = {
      key = "6BFB8037115ADE26";
      signByDefault = true;
    };
  };

  # Packages that should be installed to the user profile.
  home.packages = with pkgs; [
    # here is some command line tools I use frequently
    # feel free to add your own or remove some of them

    # Social
    spotify
    discord
    element-desktop
    telegram-desktop
    mumble
    steam
    slack

    # Creative
    gimp-with-plugins
    kdenlive
    ardour
    blender-hip
    vlc
    notion-app-enhanced

    # archives
    zip
    xz
    unzip
    p7zip

    # utils
    ripgrep # recursively searches directories for a regex pattern
    jq # A lightweight and flexible command-line JSON processor
    yq-go # yaml processer https://github.com/mikefarah/yq
    fzf # A command-line fuzzy finder
    kubectl
    k9s
    git-crypt
    kubeseal
    ffmpeg
    ventoy-full
    zfs

    # networking tools
    mtr # A network diagnostic tool
    iperf3
    dnsutils # `dig` + `nslookup`
    ldns # replacement of `dig`, it provide the command `drill`
    aria2 # A lightweight multi-protocol & multi-source command-line download utility
    socat # replacement of openbsd-netcat
    nmap # A utility for network discovery and security auditing
    ipcalc # it is a calculator for the IPv4/v6 addresses
    firefox
    chromium

    # misc
    cowsay
    file
    which
    tree
    gnused
    gnutar
    gawk
    zstd
    gnupg

    openrgb-with-all-plugins
    rustup

    # Games
    prismlauncher

    # nix related
    #
    # it provides the command `nom` works just like `nix
    # with more details log output
    nix-output-monitor

    # productivity
    glow # markdown previewer in terminal
    kate

    # btop/htop included as common system package
    iotop # io monitoring
    iftop # network monitoring
    radeontop # gpu monitoring

    # system call monitoring
    strace # system call monitoring
    ltrace # library call monitoring
    lsof # list open files

    # system tools
    sysstat
    lm_sensors # for `sensors` command
    ethtool
    pciutils # lspci
    usbutils # lsusb
  ];

  programs.vscode = {
    enable = true;
    extensions = with pkgs.vscode-extensions; [
      rust-lang.rust-analyzer
      skellock.just
      ms-azuretools.vscode-docker
    ] ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
      {
        name = "catppuccin-vsc";
        publisher = "Catppuccin";
        version = "3.14.0";
        sha256 = "90d405475821745245e172d6085815a5e5c267f5e21c6aff3b5889c964d3dc18";
      }
    ] ++ (import ../../common/vscode.nix pkgs).extensions;
    globalSnippets = {
      workbench.colorTheme = "Catppuccin Macchiato";
    };
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    initExtra = ''
      source ~/.p10k.zsh
      bindkey -e
    '';
    zplug = {
      enable = true;
      plugins = [
        { name = "zsh-users/zsh-autosuggestions"; }
        { name = "romkatv/powerlevel10k"; tags = [ as:theme depth:1 ]; }
      ];
    };
  };

  programs.alacritty = {
    enable = true;
  };

  # This value determines the home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update home Manager without changing this value. See
  # the home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "22.11";

  # Let home Manager install and manage itself.
  programs.home-manager.enable = true;

  home.sessionVariables = {
    EDITOR = "nvim";
    BROWSER = "firefox";
    TERMINAL = "alacritty";
    DELTA_PAGER = "less -R";
  };

}
