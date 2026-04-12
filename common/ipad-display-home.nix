# iPad as secondary display — home-manager components.
# Provides packages (libimobiledevice, krfb) and the ipad-display script +
# a systemd user service for automatic virtual display on iPad plug/unplug.
{ pkgs, ... }:

let
  ipadDisplayScript = pkgs.writeShellScript "ipad-display" ''
    set -euo pipefail

    RES="2360x1640"
    PORT="5901"
    PIDFILE="''${XDG_RUNTIME_DIR:-/tmp}/ipad-display.pid"
    KRFB="${pkgs.kdePackages.krfb}/bin/krfb-virtualmonitor"
    KSCREEN="${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor"

    case "''${1:-}" in
      start)
        if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
          echo "already running (pid $(cat "$PIDFILE"))"; exit 0
        fi
        "$KRFB" --name "iPad" --resolution "$RES" --port "$PORT" --password "" &
        echo $! > "$PIDFILE"
        echo "virtual output started at $RES (pid $!)"
        ;;
      stop)
        if [[ -f "$PIDFILE" ]]; then
          kill "$(cat "$PIDFILE")" 2>/dev/null || true
          rm -f "$PIDFILE"
        fi
        echo "virtual output stopped"
        ;;
      status)
        "$KSCREEN" --outputs || true
        if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
          echo "ipad-display: running (pid $(cat "$PIDFILE"))"
        else
          echo "ipad-display: stopped"
        fi
        ;;
      *)
        echo "usage: ipad-display {start|stop|status}" >&2; exit 1 ;;
    esac
  '';
in
{
  packages = with pkgs; [
    libimobiledevice
    kdePackages.krfb
  ];

  script = {
    ".local/bin/ipad-display" = {
      executable = true;
      source = ipadDisplayScript;
    };
  };

  # Systemd user service — started/stopped by udev via ipad-display-attach.service
  displayService = {
    Unit = {
      Description = "iPad virtual display (krfb-virtualmonitor)";
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.kdePackages.krfb}/bin/krfb-virtualmonitor --name iPad --resolution 2360x1640 --port 5901 --password \"\"";
      Restart = "on-failure";
      RestartSec = 3;
    };
  };
}
