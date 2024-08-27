{ pkgs, ... }:

let
  extensions = with pkgs.vscode-extensions; [
    rust-lang.rust-analyzer
    skellock.just
    ms-azuretools.vscode-docker
    bbenoist.nix
    arrterian.nix-env-selector
    tamasfe.even-better-toml
  ];
in
{
  inherit extensions;
}
