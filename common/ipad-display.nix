# iPad as secondary display via Sunshine + Moonlight.
#
# System config: import this file from configuration.nix (it's a NixOS module).
# Home config:   import ipad-display-home.nix from home.nix for packages + script.
{ config, pkgs, customPackages, ... }:

let
  # Helper scripts that run as root from udev, targeting the user's systemd instance.
  # Start both Sunshine and the virtual display on iPad plug, stop both on unplug.
  systemctl = "/run/current-system/sw/bin/systemctl";

  ipadAttach = pkgs.writeShellScript "ipad-display-attach" ''
    # Run in background so udev doesn't block/timeout.
    # Start virtual display first, give it time to register with KWin,
    # then start Sunshine so it can find the output via portal.
    (
      ${systemctl} --user -M chris@ start ipad-display.service || true
      sleep 2
      # Set scale 2 and position the virtual display to the left of eDP-1
      sudo -u chris DISPLAY=:0 ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor \
        output.Virtual-iPad.scale.2 \
        output.Virtual-iPad.position.0,0 \
        output.eDP-1.position.1180,0 || true
      sleep 1
      ${systemctl} --user -M chris@ start sunshine.service || true
    ) &
  '';

  ipadDetach = pkgs.writeShellScript "ipad-display-detach" ''
    # Run in background so udev doesn't block waiting for service stop
    (
      ${systemctl} --user -M chris@ stop sunshine.service --no-block || true
      ${systemctl} --user -M chris@ stop ipad-display.service --no-block || true
    ) &
  '';
in
{
  # USB multiplexer for pairing / trust handshake with iOS devices
  services.usbmuxd.enable = true;

  # Load ipheth for USB Ethernet to iPad when Personal Hotspot is on
  boot.kernelModules = [ "ipheth" ];

  # Udev rules:
  # 1. Rename ipheth network interface to ipad0
  # 2. Start Sunshine + virtual display when iPad is plugged in
  # 3. Stop both when iPad is unplugged
  services.udev.extraRules = ''
    SUBSYSTEM=="net", ACTION=="add", DRIVERS=="ipheth", NAME="ipad0"
    SUBSYSTEM=="usb", ACTION=="add", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="05ac", ATTR{idProduct}=="12ab", RUN+="${ipadAttach}"
    SUBSYSTEM=="usb", ACTION=="remove", ENV{DEVTYPE}=="usb_device", ENV{PRODUCT}=="5ac/12ab/*", RUN+="${ipadDetach}"
  '';

  # DHCP client on the iPad tether (iPad runs DHCP server on 172.20.10.1/28)
  networking.networkmanager.ensureProfiles.profiles.ipad-usb = {
    connection = {
      id = "iPad USB";
      type = "ethernet";
      interface-name = "ipad0";
      autoconnect = "true";
    };
    ipv4.method = "auto";
    ipv6.method = "ignore";
  };

  # Sunshine game-streaming server (pre-release with PipeWire capture support).
  # autoStart disabled — udev starts it when iPad is plugged in.
  services.sunshine = {
    enable = true;
    package = (customPackages pkgs).sunshine-prerelease;
    autoStart = false;
    capSysAdmin = true;
    openFirewall = true;
    settings = {
      sunshine_name = "celebi";
      encoder = "vaapi";
      capture = "portal";
      output_name = "p0,0,1180,820";
    };
    applications = {
      apps = [
        {
          name = "Desktop";
          auto-detach = "true";
        }
      ];
    };
  };
}
