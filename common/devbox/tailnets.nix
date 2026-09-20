# common/devbox/tailnets.nix
#
# Two tailnets, two layers. The devbox is on BOTH the personal tailnet (the way
# in) and the WORK tailnet (Google-SSO; where everything it talks to lives):
#
#   daemon           tailnet    mode                  CLI          socket
#   tailscaled       personal   userspace (no TUN)    `tailscale`  /run/tailscale/tailscaled.sock
#   tailscaled-work  work       kernel TUN tailscale0 `tswork`     /run/tailscale-work/tailscaled.sock
#
# Why the roles are this way round
# --------------------------------
# Two kernel-mode tailscales can't coexist in one VM: they share routing table
# 52, the ip-rule priorities, the nftables `ts-*` chains, and both want
# 100.100.100.100 as the MagicDNS resolver — and either one's `--cleanup` on
# stop flushes the other's state. So exactly ONE daemon gets the kernel.
#
#   * The personal tailnet is only ever used INBOUND (ssh/mosh/RDP into the
#     VM). A daemon in `--tun=userspace-networking` still accepts inbound and
#     hands the connections to loopback (TCP and UDP — it's how `tailscale
#     serve` works in containers), so ssh/RDP/mosh keep arriving. Having no
#     kernel footprint, nothing on the work side can ever break the way in.
#     Cost: connections show up as from 127.0.0.1, and OUTBOUND to personal
#     peers needs the proxy on 127.0.0.1:1056 (`via-home`, `home-ssh`, or
#     the Firefox PAC below). Personal MagicDNS names are not in the OS
#     resolver.
#   * The work tailnet gets the real TUN: peer routes, accepted subnet routes,
#     and MagicDNS in the OS resolver (systemd-resolved, per-link on
#     tailscale0). Everything — Firefox, curl, kubectl, ssh, git, docker
#     containers — reaches work resources with no per-app config, including
#     company names that public DNS points into the tailnet (e.g.
#     tkndash.mountthor.dev -> 100.127.87.162). `--shields-up` stays on: the
#     node's packet filter rejects ALL inbound from work peers, so the VM is a
#     client of the work tailnet, never a server for it. (Defence in depth:
#     the personal door comes in via loopback, so the 22/3389/mosh firewall
#     openings only matter to rowlett's slirp forwards — not to tailscale0.)
#
# What the work admin can now influence: with `--accept-routes`, approved
# subnet routes are installed; with the default `--accept-dns`, the tailnet's
# DNS config (today: none beyond MagicDNS) applies to the OS resolver. Exit
# nodes and Tailscale SSH still require explicit opt-in on this node.
#
# State: the rootfs is tmpfs, so each daemon's node key/prefs live on its own
# persistent volume (guest.nix `microvm.volumes`): tailscale-state.img and
# tailscale-work-state.img. Switching a daemon's mode does not touch its
# identity — no re-login needed when this file changes.
#
# Work login (once, prints a URL; open anywhere with the work Google account;
# a work admin may need to approve the device). Re-run when `tswork status`
# reports the key expired:
#
#   sudo tswork up --shields-up --accept-routes --operator=dev --hostname=devbox-work
#
# Break-glass if the personal door ever fails: rowlett's loopback forwards
# (`ssh -p 2222 dev@127.0.0.1`, RDP to 127.0.0.1:13389) and `devvm-console`.
{ config, pkgs, lib, ... }:

let
  # Both daemons run the same package (the fleet's doCheck=false override).
  tailscale = config.services.tailscale.package;

  # ---- personal (userspace, inbound door) ----
  homeProxy = "127.0.0.1:1056"; # SOCKS5 + HTTP CONNECT — outbound TO personal peers
  homeSuffix = "taildca8.ts.net"; # `tailscale status --json | jq .MagicDNSSuffix`

  # ---- work (kernel TUN, the VM's real network) ----
  workStateDir = "/var/lib/tailscale-work"; # persistent volume (guest.nix)
  workSock = "/run/tailscale-work/tailscaled.sock";
  workPort = 41642; # WireGuard UDP; personal keeps the module default 41641

  tswork = pkgs.writeShellScriptBin "tswork" ''
    exec ${tailscale}/bin/tailscale --socket=${workSock} "$@"
  '';

  # Run one command (or an interactive shell) with proxy env pointing at the
  # personal daemon, for the rare outbound trip to a personal peer. HTTP
  # CONNECT for curl/git/Go tools, socks5h for the rest — both resolve names
  # AT the proxy, which is what makes personal MagicDNS names work.
  viaHome = pkgs.writeShellScriptBin "via-home" ''
    export HTTP_PROXY="http://${homeProxy}"  http_proxy="http://${homeProxy}"
    export HTTPS_PROXY="http://${homeProxy}" https_proxy="http://${homeProxy}"
    export ALL_PROXY="socks5h://${homeProxy}" all_proxy="socks5h://${homeProxy}"
    export NO_PROXY="localhost,127.0.0.1,::1" no_proxy="localhost,127.0.0.1,::1"
    if [ $# -eq 0 ]; then
      echo "via-home: proxy env set (${homeProxy}); starting a shell" >&2
      exec "''${SHELL:-${pkgs.zsh}/bin/zsh}"
    fi
    exec "$@"
  '';

  # ssh to a personal peer by any name (OpenBSD nc hands the hostname to the
  # SOCKS5 proxy, so MagicDNS resolves daemon-side). Names under the personal
  # suffix don't even need this — see the ssh_config rule below.
  homeSsh = pkgs.writeShellScriptBin "home-ssh" ''
    exec ${pkgs.openssh}/bin/ssh \
      -o ProxyCommand="${pkgs.netcat-openbsd}/bin/nc -X 5 -x ${homeProxy} %h %p" \
      "$@"
  '';

  # Firefox PAC: personal-suffix names -> the personal daemon's SOCKS5 (with
  # proxy-side DNS); everything else DIRECT, i.e. via the OS — which is where
  # the work tailnet now lives, so work URLs need nothing here.
  pac = pkgs.writeText "tailnets-proxy.pac" ''
    // Generated by common/devbox/tailnets.nix — do not edit here.
    function FindProxyForURL(url, host) {
      host = host.toLowerCase();
      if (dnsDomainIs(host, ".${homeSuffix}")) {
        return "SOCKS5 ${homeProxy}";
      }
      return "DIRECT";
    }
  '';
in
{
  # ---- Personal tailnet: userspace mode, inbound door ----------------------
  services.tailscale = {
    enable = true;
    # Match the rest of the fleet's test-disabling override.
    package = pkgs.tailscale.overrideAttrs (_: { doCheck = false; });
    # No TUN. Inbound (ssh/mosh/RDP from the personal tailnet) is delivered to
    # loopback by the daemon's netstack; outbound to personal peers only via
    # the proxy below.
    interfaceName = "userspace-networking";
    extraDaemonFlags = [
      "--socks5-server=${homeProxy}"
      "--outbound-http-proxy-listen=${homeProxy}"
    ];
  };
  # The upstream unit runs `tailscaled --cleanup` on stop. Without `--tun` it
  # assumes tailscale0 and (in 1.90) flushes the ts-* netfilter chains and
  # reverts tailscale0's resolved DNS — i.e. the WORK daemon's state. This
  # daemon has no kernel state to clean, so drop the hook entirely.
  systemd.services.tailscaled.serviceConfig.ExecStopPost = [ "" ];

  # ---- Work tailnet: kernel TUN, the VM's real network ---------------------
  systemd.services.tailscaled-work = {
    description = "Tailscale node agent (work tailnet, tailscale0)";
    # Mirrors the upstream tailscaled.service ordering.
    wants = [ "network-pre.target" ];
    after = [ "network-pre.target" "systemd-resolved.service" ];
    wantedBy = [ "multi-user.target" ];
    unitConfig.RequiresMountsFor = workStateDir; # state is a separate volume
    # Same PATH extras the NixOS module gives the primary daemon.
    path = [ pkgs.procps pkgs.getent pkgs.kmod ];
    serviceConfig = {
      Type = "notify"; # tailscaled sends READY=1
      ExecStart = lib.concatStringsSep " " [
        "${tailscale}/bin/tailscaled"
        "--state=${workStateDir}/tailscaled.state"
        "--statedir=${workStateDir}"
        "--socket=${workSock}"
        "--port=${toString workPort}"
        "--tun=tailscale0"
      ];
      # This IS the kernel-mode daemon now, so the upstream cleanup hook
      # belongs here: drops stale routes/netfilter/DNS state on stop.
      ExecStopPost = "${tailscale}/bin/tailscaled --cleanup";
      Restart = "on-failure";
      RuntimeDirectory = "tailscale-work";
      RuntimeDirectoryMode = "0755";
      StateDirectory = "tailscale-work";
      StateDirectoryMode = "0700";
      CacheDirectory = "tailscale-work";
      CacheDirectoryMode = "0750";
    };
  };
  # Accepted subnet routes return via tailscale0 while the kernel's strict
  # reverse-path filter expects them on the slirp NIC. Same thing the NixOS
  # module sets for `useRoutingFeatures = "client"`.
  networking.firewall.checkReversePath = "loose";
  # No firewall opening for ${workPort}: the VM sits behind qemu user-mode
  # (slirp) NAT; nothing inbound can reach it and DERP covers the rest.

  # ---- Helpers ---------------------------------------------------------------
  environment.systemPackages = [
    tswork
    viaHome
    homeSsh
  ];

  # Firefox: system policy pointing at the PAC. Not locked — Settings ->
  # Network Settings can still override it.
  environment.etc."tailnets/proxy.pac".source = pac;
  programs.firefox.policies.Proxy = {
    Mode = "autoConfig";
    AutoConfigURL = "file:///etc/tailnets/proxy.pac";
    UseProxyForDNS = true; # network.proxy.socks_remote_dns
    Locked = false;
  };

  # ssh: personal-suffix hosts are dialled through the personal daemon's
  # proxy, so `ssh chris@rowlett.<homeSuffix>` just works. Work hosts need
  # nothing — they route over tailscale0 like any other address.
  programs.ssh.extraConfig = ''
    Host *.${homeSuffix}
      ProxyCommand ${pkgs.netcat-openbsd}/bin/nc -X 5 -x ${homeProxy} %h %p
  '';
}
