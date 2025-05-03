let
  zsh = {
    enable = true;
    enableCompletion = true;
    enableVteIntegration = true;
    defaultKeymap = "emacs";
    autosuggestion = {
      enable = true;
      strategy = [
        "completion"
        "history"
        "match_prev_cmd"
      ];
    };
    syntaxHighlighting.enable = true;

    initExtra = ''
      source ~/.p10k.zsh
      bindkey "^[[1;5D" backward-word
      bindkey "^[[1;5C" forward-word
    '';
    zplug = {
      enable = true;
      plugins = [
        { name = "romkatv/powerlevel10k"; tags = [ as:theme depth:1 ]; }
      ];
    };
  };
in
{
  inherit zsh;
}
