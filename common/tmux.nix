# common/tmux.nix
#
# Shared tmux config for the machines reached over flaky links (rowlett + the
# devbox — e.g. from a plane). Pair it with mosh:
#
#     mosh <host> -- tmux new -A -s main
#
# mosh keeps the connection alive across network changes and latency (it's UDP
# and roams with your IP), while tmux persists the session across a FULL drop —
# detach/reattach and long-running jobs (builds, `claude`, ...) keep going. Run
# anything long-lived inside tmux so a dead connection never kills it.
#
# `new -A -s main` attaches to session "main" if it exists, else creates it —
# so the same command reconnects you every time.
let
  tmux = {
    enable = true;
    mouse = true;
    baseIndex = 1;
    escapeTime = 10; # snappier ESC (helps vim/neovim over the wire)
    historyLimit = 50000;
    keyMode = "emacs"; # match the zsh emacs keymap (zsh.nix)
    terminal = "tmux-256color";
    extraConfig = ''
      # true-color passthrough for modern terminals (kitty, alacritty, ...)
      set -ga terminal-overrides ",*256col*:Tc"
      set -g renumber-windows on
      set -g set-clipboard on
      # keep sessions alive when the last client detaches — the whole point
      set -g destroy-unattached off
      # obvious "you're in tmux" marker + clock for long-lived remote sessions
      set -g status-right ' #{session_name}  %Y-%m-%d %H:%M '
    '';
  };
in
{
  inherit tmux;
}
