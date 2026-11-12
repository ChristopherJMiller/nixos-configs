{
  description = "Rowlett NixOS";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable-small";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    microvm.url = "github:microvm-nix/microvm.nix";
    microvm.inputs.nixpkgs.follows = "nixpkgs";
    plasma-manager.url = "github:pjones/plasma-manager";
    plasma-manager.inputs.nixpkgs.follows = "nixpkgs";
    plasma-manager.inputs.home-manager.follows = "home-manager";
    vscode-server.url = "github:nix-community/nixos-vscode-server";
    bandcamp-sync.url = "github:christopherjmiller/bandcamp-sync/0.5.0";
    nutune.url = "github:christopherjmiller/nutune/main";
    loreweaver.url = "github:christopherjmiller/loreweaver/main";
    nix-flatpak.url = "github:gmodena/nix-flatpak/v0.6.0";
    timekeeper.url = "github:ChristopherJMiller/timekeeper";
    # KWin blur replacement (force blur, rounded blur, refraction). Source only:
    # built with our own kdePackages so it matches the exact KWin it loads into.
    kwin-effects-better-blur-dx = {
      url = "github:xarblu/kwin-effects-better-blur-dx/v2.6.0";
      flake = false;
    };
    # Alternative blur replacement with liquid-glass extras (edge lighting,
    # refraction, tint); same source-only treatment as Better Blur DX.
    kwin-effects-glass = {
      # main (2026-11-08): the v1.6.4 tag predates its KWin 6.6+ API support.
      url = "github:4v3ngR/kwin-effects-glass/5e2845fffbe893177c091fe18d603b9095cc2729";
      flake = false;
    };
    # Spotify theming (patched client + Catppuccin theme); keeps ~/.config/spotify.
    spicetify-nix.url = "github:Gerg-L/spicetify-nix";
    spicetify-nix.inputs.nixpkgs.follows = "nixpkgs";
    # Fully-built nixos-unstable, only for Vencord: it patches Discord's live
    # web app, so it has to keep pace with upstream more closely than our
    # unstable-small pin. Bump with `nix flake update nixpkgs-latest`.
    nixpkgs-latest.url = "github:nixos/nixpkgs/nixos-unstable";
    # ardour-mcp + nixcache-oci temporarily disabled until prebuilt binary
    # cache pipeline is in place; rebuild-from-source is too slow.
    # Upstream Ardour's .gitattributes has `/* export-ignore`, which makes
    # GitHub release tarballs ship a single README. Use git+https:// so Nix
    # does a full clone instead of going through the archive API.
    # ardour-mcp.url = "git+https://github.com/ChristopherJMiller/ardour.git";
    # ardour-mcp.inputs.nixpkgs.follows = "nixpkgs";
    # cmspam/nixcache-oci provides the cache-proxy nixos module that talks to
    # GHCR-hosted OCI nix caches. The ChristopherJMiller/ardour fork publishes
    # its prebuilt ardour into ghcr.io/christopherjmiller/ardour/nix-cache so
    # we don't have to rebuild it on each host.
    # nixcache-oci.url = "github:cmspam/nixcache-oci";
  };

  outputs =
    inputs@{
      nixpkgs,
      nixpkgs-unstable,
      nixos-hardware,
      home-manager,
      microvm,
      bandcamp-sync,
      nutune,
      loreweaver,
      timekeeper,
      # ardour-mcp,
      # nixcache-oci,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs-unstable = import nixpkgs-unstable {
        inherit system;
        config = {
          allowUnfree = true;
        };
      };
      customPackages = pkgs: {
        mpc-autofill = pkgs.callPackage ./packages/mpc-autofill { };
        bandcamp-sync = bandcamp-sync.packages.x86_64-linux.with-firefox;
        rbxlx-to-rojo = pkgs.callPackage ./packages/rbxlx-to-rojo { };
        bluez-patched = pkgs.callPackage ./packages/bluez-patched { };
        calibre-acsm = pkgs.callPackage ./packages/calibre-acsm { };
        loreweaver = loreweaver.packages.x86_64-linux.default;
        nutune = nutune.packages.x86_64-linux.default;
        claude-desktop = pkgs.callPackage ./packages/claude-desktop { };
        chatgpt-desktop = pkgs.callPackage ./packages/chatgpt-desktop { };
        fastmail-mcp = pkgs.callPackage ./packages/fastmail-mcp { };
        betterbird = pkgs.callPackage ./packages/betterbird { };
        photogimp = pkgs.callPackage ./packages/photogimp { };
        sunshine-prerelease = pkgs.callPackage ./packages/sunshine-prerelease { };
        timekeeper = timekeeper.packages.x86_64-linux.default;
        better-blur-dx = pkgs.kdePackages.callPackage "${inputs.kwin-effects-better-blur-dx}/nix/package.nix" { };
        kwin-glass = pkgs.kdePackages.callPackage "${inputs.kwin-effects-glass}/nix/package/kwin-glass.nix" { };
        # ardour-mcp = ardour-mcp.packages.x86_64-linux.default;
      };
      # Shared module wiring up the nixcache-oci proxy so all hosts pull the
      # prebuilt ardour-mcp NARs from ghcr.io instead of compiling from source.
      # Until a signing key is configured in the ardour fork's CI, the cache
      # is unsigned — requireSignatures = false matches.
      # ardourCacheModule = { ... }: {
      #   imports = [ nixcache-oci.nixosModules.default ];
      #   services.nixcache-proxy = {
      #     enable = true;
      #     repo = "ChristopherJMiller/ardour";
      #     requireSignatures = false;
      #   };
      #   # The proxy listens on localhost:37515; the substituter URL is added
      #   # automatically by the module.
      # };
    in
    {
      nixosConfigurations = {
        rowlett = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit customPackages; };
          modules = [
            ./hosts/rowlett/configuration.nix
            # ardourCacheModule

            # devbox dev VM — off-by-default qemu microVM (see common/devbox/).
            # Fully-declarative: rebuilds/restarts with `nixos-rebuild switch`,
            # but autostart=false keeps it out of boot. Start with `devvm-up`.
            microvm.nixosModules.host
            {
              microvm.vms.devbox = {
                autostart = false;
                config = {
                  imports = [
                    ./common/devbox/guest.nix
                    home-manager.nixosModules.home-manager
                    {
                      home-manager.useGlobalPkgs = true;
                      home-manager.useUserPackages = true;
                      home-manager.backupFileExtension = "old";
                      # xfconfd rewrites its channel files atomically (temp +
                      # rename), which turns the home-manager symlink for
                      # xfce4-panel.xml into a regular file every session. HM
                      # backs that up to `.old` and relinks — but the SECOND
                      # time, its pre-flight check refuses to clobber the
                      # existing `.old` and aborts activation BEFORE linking
                      # anything, on every boot thereafter. That is how the
                      # guest silently ran the Jul-30 dev home (zplug prompt,
                      # no tmux.conf…) for weeks while every rebuild "worked".
                      # This makes the check a warning: the declarative config
                      # always wins at boot, which is the point of this VM.
                      home-manager.overwriteBackup = true;
                      home-manager.users.dev = import ./common/devbox/home.nix pkgs-unstable;
                    }
                  ];
                };
              };
            }

            # make home-manager as a module of nixos
            # so that home-manager configuration will be deployed automatically when executing `nixos-rebuild switch`
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "old";

              home-manager.users.chris = (import ./hosts/rowlett/home.nix pkgs-unstable);
              home-manager.extraSpecialArgs = { inherit customPackages; };

              # Optionally, use home-manager.extraSpecialArgs to pass arguments to home.nix
              home-manager.sharedModules = [
                inputs.plasma-manager.homeModules.plasma-manager
                inputs.vscode-server.homeModules.default
                inputs.nix-flatpak.homeManagerModules.nix-flatpak
              ];
            }
          ];
        };

        wailmer = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit customPackages; };
          modules = [
            ./hosts/wailmer/configuration.nix
            # ardourCacheModule

            # make home-manager as a module of nixos
            # so that home-manager configuration will be deployed automatically when executing `nixos-rebuild switch`
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "old";

              # Pass the configured unstable packages here
              home-manager.users.chris = (import ./hosts/wailmer/home.nix pkgs-unstable);
              home-manager.extraSpecialArgs = { inherit customPackages; };

              # Optionally, use home-manager.extraSpecialArgs to pass arguments to home.nix
              home-manager.sharedModules = [
                inputs.plasma-manager.homeModules.plasma-manager
                inputs.vscode-server.homeModules.default
              ];
            }
          ];
        };

        celebi = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit customPackages; };
          modules = [
            ./hosts/celebi/configuration.nix

            # Framework 13 AMD 7040 hardware optimizations
            nixos-hardware.nixosModules.framework-13-7040-amd

            # make home-manager as a module of nixos
            # so that home-manager configuration will be deployed automatically when executing `nixos-rebuild switch`
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "old";

              # Pass the configured unstable packages here
              home-manager.users.chris = (import ./hosts/celebi/home.nix pkgs-unstable);
              home-manager.extraSpecialArgs = {
                inherit customPackages;
                spicePkgs = inputs.spicetify-nix.legacyPackages.${system};
                vencord-latest = inputs.nixpkgs-latest.legacyPackages.${system}.vencord;
              };

              # Optionally, use home-manager.extraSpecialArgs to pass arguments to home.nix
              home-manager.sharedModules = [
                inputs.plasma-manager.homeModules.plasma-manager
                inputs.vscode-server.homeModules.default
                inputs.nix-flatpak.homeManagerModules.nix-flatpak
                inputs.spicetify-nix.homeManagerModules.spicetify
              ];
            }
          ];
        };
      };
    };
}
