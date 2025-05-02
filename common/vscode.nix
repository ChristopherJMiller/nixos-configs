{ pkgs, ... }:

let
  extensions = with pkgs.vscode-extensions; [
    rust-lang.rust-analyzer
    skellock.just
    ms-azuretools.vscode-docker
    jnoortheen.nix-ide
    arrterian.nix-env-selector
    tamasfe.even-better-toml
    github.vscode-pull-request-github
    github.vscode-github-actions
    github.copilot
  ];
  globalSnippets = {
    workbench.colorTheme = "Catppuccin Macchiato";
  };
in
{
  inherit extensions;
  inherit globalSnippets;
}
