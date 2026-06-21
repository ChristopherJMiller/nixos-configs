{
  description = "Rowlett NixOS";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable-small";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    plasma-manager.url = "github:pjones/plasma-manager";
    plasma-manager.inputs.nixpkgs.follows = "nixpkgs";
    plasma-manager.inputs.home-manager.follows = "home-manager";
    vscode-server.url = "github:nix-community/nixos-vscode-server";
    bandcamp-sync.url = "github:christopherjmiller/bandcamp-sync/0.5.0";
    nutune.url = "github:christopherjmiller/nutune/main";
    loreweaver.url = "github:christopherjmiller/loreweaver/main";
    nix-flatpak.url = "github:gmodena/nix-flatpak/v0.6.0";
    claude-desktop.url = "github:ChristopherJMiller/claude-for-linux";
    timekeeper.url = "github:ChristopherJMiller/timekeeper";
    # Upstream Ardour's .gitattributes has `/* export-ignore`, which makes
    # GitHub release tarballs ship a single README. Use git+https:// so Nix
    # does a full clone instead of going through the archive API.
    ardour-mcp.url = "git+https://github.com/ChristopherJMiller/ardour.git";
    ardour-mcp.inputs.nixpkgs.follows = "nixpkgs";
    # cmspam/nixcache-oci provides the cache-proxy nixos module that talks to
    # GHCR-hosted OCI nix caches. The ChristopherJMiller/ardour fork publishes
    # its prebuilt ardour into ghcr.io/christopherjmiller/ardour/nix-cache so
    # we don't have to rebuild it on each host.
    nixcache-oci.url = "github:cmspam/nixcache-oci";
  };

  outputs =
    inputs@{
      nixpkgs,
      nixpkgs-unstable,
      nixos-hardware,
      home-manager,
      bandcamp-sync,
      nutune,
      loreweaver,
      claude-desktop,
      timekeeper,
      ardour-mcp,
      nixcache-oci,
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
        loreweaver = loreweaver.packages.x86_64-linux.default;
        nutune = nutune.packages.x86_64-linux.default;
        claude-desktop = claude-desktop.packages.x86_64-linux.claude-desktop;
        fastmail-mcp = pkgs.callPackage ./packages/fastmail-mcp { };
        sunshine-prerelease = pkgs.callPackage ./packages/sunshine-prerelease { };
        timekeeper = timekeeper.packages.x86_64-linux.default;
        ardour-mcp = ardour-mcp.packages.x86_64-linux.default;
      };
      # Shared module wiring up the nixcache-oci proxy so all hosts pull the
      # prebuilt ardour-mcp NARs from ghcr.io instead of compiling from source.
      # Until a signing key is configured in the ardour fork's CI, the cache
      # is unsigned — requireSignatures = false matches.
      ardourCacheModule = { ... }: {
        imports = [ nixcache-oci.nixosModules.default ];
        services.nixcache-proxy = {
          enable = true;
          repo = "ChristopherJMiller/ardour";
          requireSignatures = false;
        };
        # The proxy listens on localhost:37515; the substituter URL is added
        # automatically by the module.
      };
    in
    {
      nixosConfigurations = {
        rowlett = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit customPackages; };
          modules = [
            ./hosts/rowlett/configuration.nix
            ardourCacheModule

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
            ardourCacheModule

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
      };
    };
}
