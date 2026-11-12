# celebi's Remmina setup, on top of the shared profiles in
# common/remmina.nix: sessions open fullscreen (on their own desktop, see the
# tailnet menu), passwords come from KWallet, and the app itself is dark with
# no tab bar for single sessions.
{ lib, pkgs, ... }:

let
  # Remmina rewrites remmina.pref itself, so these are merged in on each
  # activation rather than owning the file.
  prefs = {
    dark_theme = "true";
    always_show_tab = "false";
  };
in
{
  # Swipe between desktops to leave a session (Right Ctrl, Remmina's host
  # key, releases the keyboard first). `password=.` tells Remmina the
  # password lives in the keyring (KWallet, via its Secret Service API):
  # tick "Save password" once per host and it survives rebuilds, which
  # rewrite these profiles.
  remmina.profileExtra = ''
    viewmode=4
    password=.
  '';

  home.activation.remminaPrefs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    pref="$HOME/.config/remmina/remmina.pref"
    run mkdir -p "$(dirname "$pref")"
    ${lib.concatStrings (
      lib.mapAttrsToList (key: value: ''
        run ${lib.getExe pkgs.crudini} --set "$pref" remmina_pref ${key} ${value}
      '') prefs
    )}
  '';
}
