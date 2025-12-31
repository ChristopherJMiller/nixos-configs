{
  description = "Rowlett NixOS";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable-small";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    plasma-manager.url = "github:pjones/plasma-manager";
    plasma-manager.inputs.nixpkgs.follows = "nixpkgs";
    plasma-manager.inputs.home-manager.follows = "home-manager";
    vscode-server.url = "github:nix-community/nixos-vscode-server";
    bandcamp-sync.url = "github:christopherjmiller/bandcamp-sync/0.5.0";
    nutune.url = "github:christopherjmiller/nutune/main";
    loreweaver.url = "github:christopherjmiller/loreweaver/main";
    nix-flatpak.url = "github:gmodena/nix-flatpak/v0.6.0";
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
      };
    in
    {
      nixosConfigurations = {
        rowlett = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit customPackages; };
          modules = [
            ./hosts/rowlett/configuration.nix

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
          modules = [
            ./hosts/wailmer/configuration.nix

            # make home-manager as a module of nixos
            # so that home-manager configuration will be deployed automatically when executing `nixos-rebuild switch`
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "old";

              # Pass the configured unstable packages here
              home-manager.users.chris = (import ./hosts/wailmer/home.nix pkgs-unstable);

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
