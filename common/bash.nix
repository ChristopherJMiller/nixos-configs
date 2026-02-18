let
  bash = {
    enable = true;
    initExtra = ''
      set -o emacs
    '';
  };
  readline = {
    enable = true;
    extraConfig = ''
      set editing-mode emacs
    '';
  };
in
{
  inherit bash readline;
}
