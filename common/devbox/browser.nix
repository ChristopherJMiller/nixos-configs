{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Explicit launch keeps CDP local and separate from normal browser sessions.
  # The profile persists on /home/dev, including any sites signed into here.
  chromiumAgent = pkgs.writeShellScriptBin "chromium-agent" ''
    set -euo pipefail
    exec ${lib.getExe config.programs.chromium.package} \
      --user-data-dir="''${XDG_STATE_HOME:-$HOME/.local/state}/chromium-agent" \
      --remote-debugging-address=127.0.0.1 \
      --remote-debugging-port=9222 \
      --no-first-run \
      --no-default-browser-check \
      "$@"
  '';
in
{
  programs.chromium.enable = true;
  home.packages = [ chromiumAgent ];
  xdg.desktopEntries.chromium-agent = {
    name = "Chromium (automation)";
    comment = "Browser for coding agents, with local CDP on port 9222";
    exec = "${lib.getExe chromiumAgent} %U";
    icon = "chromium";
    terminal = false;
    categories = [
      "Network"
      "WebBrowser"
      "Development"
    ];
  };
}
