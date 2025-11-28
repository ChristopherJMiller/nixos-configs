{ pkgs }:

pkgs.bluez.overrideAttrs (oldAttrs: {
  pname = "bluez-patched";

  # Fix Galaxy Buds3 Pro LE Audio support
  # Changes metadata_context from Unspecified (0x0001) to Conversational (0x0002)
  # Based on: https://github.com/bluez/bluez/issues/1548
  #
  # BlueZ 5.80 uses LTV macro format: LTV(length, low_byte, high_byte)
  # 0x0001 (Unspecified) = LTV(0x02, 0x01, 0x00)
  # 0x0002 (Conversational) = LTV(0x02, 0x02, 0x00)
  postPatch = (oldAttrs.postPatch or "") + ''
    # Replace the Unspecified context (0x0001) with Conversational (0x0002)
    # This is the fix for Galaxy Buds3 Pro LE Audio
    substituteInPlace src/shared/bap.c \
      --replace-fail '} ctx = LTV(0x02, 0x01, 0x00); /* Context = Unspecified */' \
                     '} ctx = LTV(0x02, 0x02, 0x00); /* Context = Conversational */'

    # Update test expectations to match the new context value
    # Change metadata context from 0x0001 (Unspecified) to 0x0002 (Conversational)
    # The pattern 0x04, 0x03, 0x02, 0x01, 0x00 is the LTV-encoded Streaming Audio Context
    substituteInPlace unit/test-bap.c \
      --replace '0x04, 0x03, 0x02, 0x01, 0x00' \
                '0x04, 0x03, 0x02, 0x02, 0x00' \
      --replace '0x04, 0x03, 0x02, 0x01, \' \
                '0x04, 0x03, 0x02, 0x02, \'
  '';

  meta = oldAttrs.meta // {
    description = oldAttrs.meta.description + " (patched for Galaxy Buds3 Pro)";
  };
})
