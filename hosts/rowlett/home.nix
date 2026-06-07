pkgs-unstable:

{
  config,
  pkgs,
  customPackages,
  ...
}:

let
  stable-pkgs = with pkgs; [
    # Social
    spotify
    element-desktop
    telegram-desktop
    mumble
    steam
    slack
    zoom-us

    # Creative
    gimp-with-plugins
    kdePackages.kdenlive
    # ardour comes from customPackages.ardour-mcp (fork with MCP HTTP control surface)
    blender-hip
    vlc
    notion-app-enhanced
    calibre

    # Office
    libreoffice-qt6-fresh
    hunspell
    hunspellDicts.en_US

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
    zfs
    imwheel
    xclip

    # Virtualization
    qemu
    quickemu
    spice
    spice-vdagent

    # networking tools
    mtr # A network diagnostic tool
    iperf3
    dnsutils # `dig` + `nslookup`
    ldns # replacement of `dig`, it provide the command `drill`
    aria2 # A lightweight multi-protocol & multi-source command-line download utility
    socat # replacement of openbsd-netcat
    nmap # A utility for network discovery and security auditing
    ipcalc # it is a calculator for the IPv4/v6 addresses
    chromium
    firefox
    remmina
    gh
    strawberry

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
    stm32cubemx
    stm32flash
    stlink
    dfu-util
    platformio
    openocd
    espflash

    # Games
    prismlauncher
    jdk25
    runelite

    # nix related
    #
    # it provides the command `nom` works just like `nix
    # with more details log output
    nix-output-monitor

    # productivity
    glow # markdown previewer in terminal
    kdePackages.kate
    kdePackages.ksshaskpass # GUI sudo/ssh password prompt (SUDO_ASKPASS target)
    transmission_4-qt
    freecad
    cura-appimage

    # btop/htop included as common system package
    iotop # io monitoring
    iftop # network monitoring
    radeontop # gpu monitoring

    # system call monitoring
    strace # system call monitoring
    ltrace # library call monitoring
    lsof # list open files

    # system tools
    minikube
    sysstat
    lm_sensors # for `sensors` command
    ethtool
    pciutils # lspci
    usbutils # lsusb
    nixfmt-rfc-style
  ];

  # The pinned nixpkgs-unstable feed lags behind upstream GitHub Copilot CLI
  # releases. Override the version/src here to track the latest release until
  # the feed catches up.
  github-copilot-cli-latest = pkgs-unstable.github-copilot-cli.overrideAttrs (old: rec {
    version = "1.0.60";
    src = pkgs-unstable.fetchurl {
      url = "https://github.com/github/copilot-cli/releases/download/v${version}/github-copilot-${version}.tgz";
      hash = "sha256-wUEBstKx8Yb9m6ynIi137ZXR7dO39uepnv/yGFVE/qQ=";
    };
    # 1.0.60 bundles musl prebuilds of keytar that reference
    # libc.musl-x86_64.so.1; these are never used on this glibc host, so
    # ignore the unsatisfiable musl dependency rather than fail the build.
    autoPatchelfIgnoreMissingDeps = (old.autoPatchelfIgnoreMissingDeps or [ ]) ++ [
      "libc.musl-x86_64.so.1"
    ];
  });

  unstable-pkgs = with pkgs-unstable; [
    discord
    code-cursor
    gemini-cli
    github-copilot-cli-latest
  ];

  # Exclude celebi/laptop-specific custom packages:
  # - sunshine-prerelease: iPad-as-second-display dock (laptop only)
  # - bluez-patched: Galaxy Buds3 Pro LE Audio fix (used by celebi system bluez)
  custom-pkgs = builtins.attrValues (
    builtins.removeAttrs (customPackages pkgs) [
      "sunshine-prerelease"
      "bluez-patched"
    ]
  );

  claude-code-config = import ../../common/claude-code.nix pkgs-unstable;
  happy-coder-pkg = pkgs.callPackage ../../packages/happy-coder { };
  fastmail = import ../../common/fastmail.nix { inherit pkgs; };
  webdav-sync = import ../../common/webdav-sync.nix { inherit pkgs; };

  # Cura plugins: Cura has no declarative plugin API, but the AppImage scans
  # ~/.local/share/cura/<version>/plugins/ at startup, so we drop sources there.
  # Bump the version path when cura-appimage moves past 5.11.
  cura-octoprint-plugin = pkgs.fetchFromGitHub {
    owner = "fieldOfView";
    repo = "Cura-OctoPrintPlugin";
    rev = "v3.7.3";
    hash = "sha256-OFfXzjd8MeXEa/pDi4SUzsPh/XNeWBKO1cmBgoZN+SI=";
  };
in
{
  imports = [
    (import ../../common/plasma.nix {
      wallpaper = "/home/chris/Pictures/Wallpapers/center.jpg";
      launchers = [
        "preferred://browser"
        "preferred://filemanager"
        "file:///etc/profiles/per-user/chris/share/applications/kitty.desktop"
        "file:///etc/profiles/per-user/chris/share/applications/code.desktop"
        "file:///etc/profiles/per-user/chris/share/applications/spotify.desktop"
        "file:///etc/profiles/per-user/chris/share/applications/discord.desktop"
        "file:///etc/profiles/per-user/chris/share/applications/element-desktop.desktop"
        "file:///etc/profiles/per-user/chris/share/applications/org.telegram.desktop.desktop"
        "file:///etc/profiles/per-user/chris/share/applications/slack.desktop"
      ];
      extraSystrayItems = [ "org.kde.plasma.nightcolorcontrol" ];
      keyboardOptions = [ "ctrl:swap_lwin_lctl" ];
      extraShortcuts = {
        plasmashell."activate application launcher" = "Ctrl+Space";
      };
    })
  ];

  home.username = "chris";
  home.homeDirectory = "/home/chris";

  # link the configuration file in current directory to the specified location in home directory
  # home.file.".config/i3/wallpaper.jpg".source = ./wallpaper.jpg;

  home.file.".p10k.zsh".source = ../../common/p10k.zsh;
  home.file.".face.icon".source = ../../common/icon.png;
  home.file.".local/bin/chrome".source = "${pkgs.chromium}/bin/chromium";
  home.file.".config/discord/settings.json".text = builtins.toJSON {
    SKIP_HOST_UPDATE = true;
  };
  home.file.".config/libreoffice/user/config/catppuccin-macchiato-mauve.soc".source =
    ../../common/catppuccin-macchiato-mauve.soc;

  home.file.".local/share/cura/5.11/plugins/OctoPrintPlugin".source = cura-octoprint-plugin;

  # Rootless Docker configuration for host.docker.internal support
  # Containers use 10.0.2.2 (slirp4netns gateway) to reach host services
  home.file.".config/docker/daemon.json".text = builtins.toJSON {
    host-gateway-ip = "10.0.2.2";
  };
  home.file.".config/systemd/user/docker.service.d/override.conf".text = ''
    [Service]
    Environment="DOCKERD_ROOTLESS_ROOTLESSKIT_DISABLE_HOST_LOOPBACK=false"
  '';

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
    lfs.enable = true;
    settings = {
      user.name = "Christopher Miller";
      user.email = "git@chrismiller.xyz";
      init.defaultBranch = "main";
    };
    signing = {
      key = "6BFB8037115ADE26";
      signByDefault = true;
    };
  };

  # Packages that should be installed to the user profile.
  home.packages =
    stable-pkgs
    ++ unstable-pkgs
    ++ custom-pkgs
    ++ [
      claude-code-config.package
      happy-coder-pkg
      webdav-sync.package
    ];

  # Flatpak configuration
  services.flatpak.packages = [
    "org.vinegarhq.Sober"
    "org.vinegarhq.Vinegar"
  ];

  # Desktop entry for Sober (Flatpak)
  xdg.desktopEntries.sober = {
    name = "Sober";
    genericName = "Roblox Player";
    comment = "Play Roblox on Linux";
    exec = "flatpak run org.vinegarhq.Sober %u";
    icon = "org.vinegarhq.Sober";
    terminal = false;
    type = "Application";
    categories = [ "Game" ];
    mimeType = [
      "x-scheme-handler/roblox"
      "x-scheme-handler/roblox-player"
    ];
  };

  # Desktop entry for Vinegar (Flatpak)
  xdg.desktopEntries.vinegar = {
    name = "Vinegar";
    genericName = "Roblox Studio";
    comment = "Roblox Studio on Linux";
    exec = "flatpak run org.vinegarhq.Vinegar %u";
    icon = "org.vinegarhq.Vinegar";
    terminal = false;
    type = "Application";
    categories = [
      "Game"
      "Development"
    ];
  };

  programs.vscode = {
    enable = true;
    profiles.default.extensions =
      pkgs.vscode-utils.extensionsFromVscodeMarketplace [
        {
          name = "catppuccin-vsc";
          publisher = "Catppuccin";
          version = "3.14.0";
          sha256 = "90d405475821745245e172d6085815a5e5c267f5e21c6aff3b5889c964d3dc18";
        }
      ]
      ++ (import ../../common/vscode.nix pkgs).extensions;
    profiles.default.globalSnippets = (import ../../common/vscode.nix pkgs).globalSnippets;
  };

  home.file.".claude/settings.json" = claude-code-config.files.".claude/settings.json";
  home.file.".claude/CLAUDE.md" = claude-code-config.files.".claude/CLAUDE.md";
  programs.zsh = (import ../../common/zsh.nix).zsh // {
    shellAliases = {
      cargo-limited = "systemd-run --user --scope --slice=dev.slice -p MemoryHigh=12G -p MemoryMax=14G -p CPUQuota=400% -p Nice=10 -- cargo";
      claude-safe = "NODE_OPTIONS=--max-old-space-size=4096 MALLOC_ARENA_MAX=2 systemd-run --user --scope --slice=dev.slice -p MemoryHigh=6G -p MemoryMax=8G -p CPUQuota=400% -- claude";
      happy-safe = "NODE_OPTIONS=--max-old-space-size=4096 MALLOC_ARENA_MAX=2 systemd-run --user --scope --slice=dev.slice -p MemoryHigh=6G -p MemoryMax=8G -p CPUQuota=400% -- happy";
    };
  };
  programs.alacritty = {
    enable = true;
  };
  programs.kitty = (import ../../common/kitty.nix).kitty;
  programs.bash = (import ../../common/bash.nix).bash;
  programs.readline = (import ../../common/bash.nix).readline;

  # Fastmail integration (email, calendar, contacts, files)
  accounts.email.accounts.fastmail = fastmail.emailAccount;
  accounts.calendar.accounts.fastmail = fastmail.calendarAccount;
  accounts.contact.accounts.fastmail = fastmail.contactAccount;
  programs.thunderbird = fastmail.thunderbird;
  xdg.desktopEntries.fastmail-files = fastmail.webdavDesktopEntry;

  # Fastmail WebDAV bidirectional sync (rclone bisync + inotify watcher)
  systemd.user.services.webdav-sync = webdav-sync.syncService;
  systemd.user.timers.webdav-sync = webdav-sync.syncTimer;
  systemd.user.services.webdav-watch = webdav-sync.watchService;

  # Resource isolation for development workloads
  systemd.user.slices.dev = {
    Unit.Description = "Development workloads (builds, Claude Code)";
    Slice = {
      CPUQuota = "1200%";
      MemoryHigh = "24G";
      MemoryMax = "28G";
      IOWeight = 50;
      TasksMax = 4096;
    };
  };

  # Happy Coder daemon for mobile Claude Code access
  systemd.user.services.happy-daemon = {
    Unit = {
      Description = "Happy Coder daemon for mobile Claude Code access";
      After = [ "default.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${happy-coder-pkg}/bin/happy daemon start";
      Slice = "dev.slice";
      MemoryHigh = "6G";
      MemoryMax = "8G";
      CPUQuota = "400%";
      Environment = [
        "NODE_OPTIONS=--max-old-space-size=4096"
        "MALLOC_ARENA_MAX=2"
        "HOME=${config.home.homeDirectory}"
        "HAPPY_HOME_DIR=${config.home.homeDirectory}/.happy"
        "PATH=${claude-code-config.package}/bin:${happy-coder-pkg}/bin:/run/current-system/sw/bin"
      ];
      Restart = "on-failure";
      RestartSec = "30s";
      WorkingDirectory = config.home.homeDirectory;
    };
    Install.WantedBy = [ "default.target" ];
  };

  # This value determines the home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new home Manager release introduces backwards
  # incompatible changes.
  services.trayscale.enable = true;

  #
  # You can update home Manager without changing this value. See
  # the home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "24.11";

  # Let home Manager install and manage itself.
  programs.home-manager.enable = true;

  home.sessionVariables = {
    EDITOR = "nvim";
    BROWSER = "firefox";
    TERMINAL = "alacritty";
    DELTA_PAGER = "less -R";
  };

}
