{ pkgs, ... }:

# Read-only rclone mounts of galaxy's B2 mirrors, for browsing the family
# archive and the personal archive from anywhere (luma-homeops
# docs/backups.md "Browse from a laptop"). Reads come from Backblaze, not the
# home uplink, and are free up to 3x stored data per month. The mirrors trail
# the cluster by up to a day (nightly sync); at home, rowlett uses NFS instead.
#
# Credentials: remotes `b2family-ro` and `b2archive-ro` in their own file,
# ~/.config/rclone/galaxy-b2-ro.conf (chmod 600) — kept apart from the main
# rclone.conf so installing it is one copy. Source of truth is the git-crypt
# encrypted luma-homeops laptops/celebi/galaxy-b2-ro.secret.conf, decrypted on
# rowlett and copied over; never in this (public) repo or the Nix store.
# Read-only keys (galaxy-*-laptop-ro): a lost laptop can read, never change or
# delete — revoke and re-issue in B2 if one goes missing.
let
  mount = { description, remote, dir }: {
    Unit.Description = description;
    Service = {
      Type = "notify";
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${dir}";
      ExecStart = builtins.concatStringsSep " " [
        "${pkgs.rclone}/bin/rclone mount ${remote} ${dir}"
        "--config %h/.config/rclone/galaxy-b2-ro.conf"
        "--read-only"
        # Full cache: a file opened once is served locally afterwards, which
        # is what makes Dolphin usable on hotel wifi.
        "--vfs-cache-mode full"
        "--vfs-cache-max-size 20G"
        "--vfs-cache-max-age 720h"
        # The mirrors change at most nightly; S3 has no change polling.
        "--dir-cache-time 12h"
        "--poll-interval 0"
        # Dead link (captive portal, blackholed wifi): fail instead of freezing
        # the file manager. Measured 2026-10-14 by freezing the network under a
        # live mount: 1m/15s/3 retries hung an uncached read 368 s and a listing
        # 367 s; these fail them in 45 s and 30 s. Cached listings stay instant.
        # Trade-off: a link silent for 15 s aborts a transfer (rclone retries).
        "--timeout 15s"
        "--contimeout 10s"
        "--low-level-retries 1"
      ];
      ExecStop = "/run/wrappers/bin/fusermount3 -u ${dir}";
      Environment = [ "PATH=/run/wrappers/bin" ]; # rclone finds the setuid fusermount3 here
      Restart = "on-failure";
      RestartSec = "30s";
    };
    Install.WantedBy = [ "default.target" ];
  };
in
{
  family = mount {
    description = "galaxy family archive (B2 mirror, read-only)";
    remote = "b2family-ro:galaxy-family/current";
    dir = "%h/Galaxy/family";
  };
  archive = mount {
    description = "galaxy personal archive (B2 mirror, read-only)";
    remote = "b2archive-ro:galaxy-archive/current";
    dir = "%h/Galaxy/archive";
  };
}
