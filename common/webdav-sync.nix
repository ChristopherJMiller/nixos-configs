{ pkgs, ... }:

let
  syncDir = "$HOME/Fastmail";
  remote = "fastmail";
  remotePath = "/";
  rcloneConfig = "$HOME/.config/rclone/rclone.conf";

  # Debounced sync script — waits for filesystem to settle, then runs bisync
  syncScript = pkgs.writeShellScript "webdav-sync" ''
    set -euo pipefail
    export PATH="${pkgs.rclone}/bin:$PATH"

    SYNC_DIR="${syncDir}"
    LOCK="/tmp/webdav-sync.lock"

    # Prevent concurrent runs
    exec 200>"$LOCK"
    ${pkgs.flock}/bin/flock -n 200 || { echo "Sync already running, skipping"; exit 0; }

    mkdir -p "$SYNC_DIR"

    echo "$(date): Starting bisync..."
    rclone bisync "${remote}:${remotePath}" "$SYNC_DIR" \
      --config "${rcloneConfig}" \
      --size-only \
      --verbose \
      --resilient \
      --recover \
      --conflict-resolve newer \
      --conflict-suffix sync-conflict-{DateOnly}- \
      --fix-case \
      2>&1 || {
        echo "bisync failed — may need --resync, check logs"
        exit 1
      }
    echo "$(date): Bisync complete"
  '';

  # Filesystem watcher with debounce
  watchScript = pkgs.writeShellScript "webdav-watch" ''
    set -euo pipefail
    export PATH="${pkgs.inotify-tools}/bin:${pkgs.coreutils}/bin:$PATH"

    SYNC_DIR="${syncDir}"
    DEBOUNCE=10  # seconds to wait after last change

    mkdir -p "$SYNC_DIR"

    echo "Watching $SYNC_DIR for changes..."
    while true; do
      # Block until a filesystem event occurs
      inotifywait -r -q \
        -e modify -e create -e delete -e move \
        --exclude '\.sync-conflict-|\.partial|~$' \
        "$SYNC_DIR"

      # Debounce: keep waiting while changes are still happening
      while inotifywait -r -q -t "$DEBOUNCE" \
        -e modify -e create -e delete -e move \
        --exclude '\.sync-conflict-|\.partial|~$' \
        "$SYNC_DIR"; do
        :  # events still firing, reset the timer
      done

      echo "$(date): Changes settled, triggering sync..."
      systemctl --user start webdav-sync.service || true
    done
  '';
in
{
  # rclone package
  package = pkgs.rclone;

  # Systemd service that performs the actual bisync
  syncService = {
    Unit = {
      Description = "Fastmail WebDAV bidirectional sync";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${syncScript}";
      TimeoutStartSec = 300;
      # Retry once on failure
      Restart = "on-failure";
      RestartSec = 30;
      RestartMaxDelaySec = 30;
    };
  };

  # Timer for periodic remote polling
  syncTimer = {
    Unit = {
      Description = "Periodic Fastmail WebDAV sync";
    };
    Timer = {
      OnCalendar = "*:0/15"; # every 15 minutes
      Persistent = true;     # run missed timers on boot
      RandomizedDelaySec = 60;
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };

  # Filesystem watcher service (debounced inotify)
  watchService = {
    Unit = {
      Description = "Watch ~/Fastmail for local changes and trigger sync";
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${watchScript}";
      Restart = "always";
      RestartSec = 5;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
