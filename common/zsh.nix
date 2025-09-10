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

    initContent = ''
      source ~/.p10k.zsh
      bindkey "^[[1;5D" backward-word
      bindkey "^[[1;5C" forward-word
      
      # better up/down arrow searching
      autoload -U up-line-or-beginning-search
      autoload -U down-line-or-beginning-search
      zle -N up-line-or-beginning-search
      zle -N down-line-or-beginning-search
      bindkey "^[[A" up-line-or-beginning-search
      bindkey "^[[B" down-line-or-beginning-search
      bindkey "^[OA" up-line-or-beginning-search
      bindkey "^[OB" down-line-or-beginning-search
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
