{ pkgs }:

pkgs.bluez.overrideAttrs (oldAttrs: {
  pname = "bluez-patched";

  # Fix Galaxy Buds3 Pro LE Audio support
  # Changes metadata_context from Unspecified (0x0001) to Conversational (0x0002)
  # Based on: https://github.com/bluez/bluez/issues/1548
  postPatch = (oldAttrs.postPatch or "") + ''
    # Replace the Unspecified context (0x0001) with Conversational (0x0002)
    # This is the fix for Galaxy Buds3 Pro LE Audio
    substituteInPlace src/shared/bap.c \
      --replace 'cpu_to_le16(0x0001); /* Context = Unspecified */' \
                'cpu_to_le16(0x0002); /* Context = Conversational */'
  '';

  meta = oldAttrs.meta // {
    description = oldAttrs.meta.description + " (patched for Galaxy Buds3 Pro)";
  };
})
