{ pkgs, ... }:

let
  extensions = with pkgs.vscode-extensions; [
    bbenoist.nix
    arrterian.nix-env-selector
    tamasfe.even-better-toml
  ];
in
{
  inherit extensions;
}
