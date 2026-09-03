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

      # rtmux <[user@]host> [session]: mosh in and attach (or create) a
      # persistent tmux session. mosh rides out roaming/latency/brief drops;
      # tmux survives a FULL disconnect — so a dropped plane-wifi link never
      # kills your work. Reconnect with the same command to reattach.
      #   rtmux rowlett            # -> session "main" on rowlett
      #   rtmux dev@devbox work    # -> session "work" in the dev VM
      rtmux() {
        emulate -L zsh
        local host="$1" session="$2"
        [ -n "$host" ] || { print -u2 "usage: rtmux <[user@]host> [session=main]"; return 2; }
        [ -n "$session" ] || session=main
        mosh "$host" -- tmux new -A -s "$session"
      }

      # local tmux helpers (for when you're already on the box):
      #   ta   attach to the "main" session (creating it if it doesn't exist)
      #   tls  list running sessions
      # Detach — leaving everything inside still running — with the tmux prefix
      # then d (Ctrl-b d by default). The session and anything in it (a running
      # `claude`, a build, ...) keeps going after you detach OR the connection
      # drops; reattach later with `ta`. No need for screen.
      alias ta='tmux new -A -s main'
      alias tls='tmux ls'
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
