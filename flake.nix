{
  description = "Rowlett NixOS";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable-small";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    plasma-manager.url = "github:pjones/plasma-manager";
    plasma-manager.inputs.nixpkgs.follows = "nixpkgs";
    plasma-manager.inputs.home-manager.follows = "home-manager";
    vscode-server.url = "github:nix-community/nixos-vscode-server";
  };

  outputs = inputs@{ nixpkgs, nixpkgs-unstable, home-manager, ... }: 
  let
    system = "x86_64-linux";
    pkgs-unstable = import nixpkgs-unstable {
      inherit system;
      config = {
        allowUnfree = true;
      };
    };
  in {
    nixosConfigurations = {
      rowlett = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hosts/rowlett/configuration.nix

          # make home-manager as a module of nixos
          # so that home-manager configuration will be deployed automatically when executing `nixos-rebuild switch`
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "old";

            home-manager.users.chris = import ./hosts/rowlett/home.nix;

            # Optionally, use home-manager.extraSpecialArgs to pass arguments to home.nix
            home-manager.sharedModules = [
              inputs.plasma-manager.homeManagerModules.plasma-manager
              inputs.vscode-server.homeModules.default
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
              inputs.plasma-manager.homeManagerModules.plasma-manager
              inputs.vscode-server.homeModules.default
            ];
          }
        ];
      };

      celebi = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./hosts/celebi/configuration.nix

          # make home-manager as a module of nixos
          # so that home-manager configuration will be deployed automatically when executing `nixos-rebuild switch`
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "old";

            # Pass the configured unstable packages here
            home-manager.users.chris = (import ./hosts/celebi/home.nix pkgs-unstable);

            # Optionally, use home-manager.extraSpecialArgs to pass arguments to home.nix
            home-manager.sharedModules = [
              inputs.plasma-manager.homeManagerModules.plasma-manager
              inputs.vscode-server.homeModules.default
            ];
          }
        ];
      };
    };
  };
}
