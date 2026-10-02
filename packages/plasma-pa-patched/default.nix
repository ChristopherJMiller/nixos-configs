{ pkgs }:

# Plasma's volume applet (plasma-pa) with two local patches:
#
#  0001  Don't wake every suspended sink/source to draw peak meters when the
#        popup opens (KDE bug 507212). Stock plasma-pa opens an active
#        peak-detect stream per listed device, so every open resumed all 14 of
#        rowlett's endpoints at once, and playback dropped out for as long
#        as the popup stayed open. KDE's own fix (plasma-pa MR !385, the
#        DONT_INHIBIT_AUTO_SUSPEND flag) was reverted because passive streams
#        on idle nodes hang on PipeWire 1.6.x (pipewire#4991); the PipeWire
#        side (823dcd88) is master-only as of 1.6.9. This patch avoids passive
#        streams entirely: the applet simply waits for a device to be active
#        before metering it. System Settings > Sound is unchanged, so mic
#        testing there still wakes the device.
#  0002  List the current default output/input device first.
#
# Patches are against plasma-pa 6.6.6. Drop 0001 once upstream ships a fix.
pkgs.kdePackages.plasma-pa.overrideAttrs (oldAttrs: {
  patches = (oldAttrs.patches or [ ]) ++ [
    ./0001-dont-wake-suspended-devices.patch
    ./0002-default-device-first.patch
  ];
})
