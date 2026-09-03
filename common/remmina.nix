# common/remmina.nix
#
# Shared Remmina RDP connection profiles for the fleet (chris user), plus the
# Remmina app itself. Imported from each host's home.nix so every machine has
# the same pre-loaded connections. Servers use tailscale MagicDNS names, so
# there are no IPs to hardcode — reachable from any machine on the tailnet.
#
# Shared RDP defaults: clipboard on (text+image via cliprdr), self-signed cert
# accepted (xrdp uses one), dynamic resolution, start maximized.
#
# `force = true`: Remmina rewrites its .remmina files at runtime (window
# geometry, last-used, ...), so without it home-manager would try to back each
# file up on every activation and eventually fail with "would be clobbered by
# backing up ...". force overwrites with no backup — the config here is
# authoritative, so tweak connections here rather than in Remmina.
{ pkgs, ... }:
let
  rdpProfile =
    {
      name,
      group,
      server,
      username,
    }:
    {
      force = true;
      text = ''
        [remmina]
        name=${name}
        group=${group}
        protocol=RDP
        server=${server}
        username=${username}
        domain=
        resolution_mode=2
        color_depth=32
        sound=off
        microphone=off
        disableclipboard=0
        cert_ignore=1
        glyph-cache=1
        disableautoreconnect=0
        window_maximize=1
      '';
    };
in
{
  home.packages = [ pkgs.remmina ];

  # devbox dev VM — login `dev` / password from the VM's initialPassword
  # (`passwd` inside the VM to change).
  xdg.dataFile."remmina/devbox.remmina" = rdpProfile {
    name = "devbox (dev VM)";
    group = "dev";
    server = "devbox";
    username = "dev";
  };

  # rowlett host — Plasma session over xrdp (services.xrdp, port 3389), login
  # `chris` with your normal account password.
  xdg.dataFile."remmina/rowlett.remmina" = rdpProfile {
    name = "rowlett (host)";
    group = "hosts";
    server = "rowlett";
    username = "chris";
  };
}
