{
  description = "Rowlett NixOS";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
    home-manager.url = "github:nix-community/home-manager/release-23.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    plasma-manager.url = "github:pjones/plasma-manager";
    plasma-manager.inputs.nixpkgs.follows = "nixpkgs";
    plasma-manager.inputs.home-manager.follows = "home-manager";
    vscode-server.url = "github:nix-community/nixos-vscode-server";
  };

  outputs = inputs@{ nixpkgs, home-manager, ... }: {
    nixosConfigurations = {
      rowlett = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./rowlett/configuration.nix

          # make home-manager as a module of nixos
          # so that home-manager configuration will be deployed automatically when executing `nixos-rebuild switch`
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;

            home-manager.users.chris = import ./rowlett/home.nix;

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
