# <i>NixOS Configs</i>

# Host Onboarding

If a new system,

1. Clone to `~/nixos`
2. Build your new host under `hosts/`
3. Define a new `nixosConfigurations` section in `flake.nix`

Otherwise,

Run `sudo nixos-rebuild switch --experimental-features flake --flake .#<host>` where `<host>` is the host name in `nixosConfigurations`

# Structure

```
.
├── common
│   ├── commonly re-usable components
│   └── ...
├── flake.nix (where host entries are defined)
├── hosts
│   └── various host systems
│   └── ...
└── format.sh (run for nix formatting)
```

# Useful Alises

- `nixr` maps to rebuilding NixOS using the flake
- `nixu` maps to updating the flake lock and then updating the system
- `nixs` is a shorthand for `nix-shell`
