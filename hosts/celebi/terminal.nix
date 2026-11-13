# Trial terminal design for celebi. Keep it here until it is ready to share.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  zsh = (import ../../common/zsh.nix).zsh;
  kitty = (import ../../common/kitty.nix).kitty;
  colors = {
    base = "#24273a";
    surface0 = "#363a4f";
    surface1 = "#494d64";
    overlay0 = "#6e738d";
    subtext0 = "#a5adcb";
    text = "#cad3f5";
    mauve = "#c6a0f6";
    green = "#a6da95";
    red = "#ed8796";
    yellow = "#eed49f";
  };
  preview = ''
    if [[ -d $realpath ]]; then
      ${lib.getExe pkgs.eza} --all --color=always --group-directories-first -- "$realpath"
    elif [[ -f $realpath ]]; then
      ${lib.getExe pkgs.bat} --color=always --paging=never --style=numbers --line-range=:160 -- "$realpath"
    fi
  '';
  tabTitle = ''" {index} {bell_symbol}{activity_symbol}{(title.rstrip('/').rsplit('/', 1)[-1] if title.startswith('/') else title)[:24] or '/'} "'';
in
{
  home.file.".p10k.zsh".text =
    builtins.readFile ../../common/p10k.zsh + "\n" + builtins.readFile ./terminal-prompt.zsh;

  programs.zsh = zsh // {
    dotDir = config.home.homeDirectory;
    enableVteIntegration = false;
    zplug.enable = false;
    plugins = [
      {
        name = "powerlevel10k";
        src = pkgs.zsh-powerlevel10k;
        file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
      }
    ];
    autosuggestion = zsh.autosuggestion // {
      highlight = "fg=${colors.overlay0}";
    };
    syntaxHighlighting = zsh.syntaxHighlighting // {
      styles = {
        command = "fg=${colors.green}";
        builtin = "fg=${colors.green}";
        alias = "fg=${colors.green}";
        unknown-token = "fg=${colors.red},underline";
        path = "underline";
        single-quoted-argument = "fg=${colors.yellow}";
        double-quoted-argument = "fg=${colors.yellow}";
      };
    };
    initContent = lib.mkMerge [
      zsh.initContent
      ''
        zstyle ':completion:*' menu no
        zstyle ':completion:*' group-name ""
        zstyle ':completion:*:descriptions' format '[%d]'
        zstyle ':completion:*' matcher-list "" 'm:{a-zA-Z}={A-Za-z}'
        zstyle ':completion:*:sudo::' environ PATH="$PATH:/run/wrappers/bin:/run/current-system/sw/bin"
        zstyle ':completion:*' list-colors "''${(s.:.)LS_COLORS}"

        zstyle ':fzf-tab:*' fzf-flags --height=45% --layout=reverse --border=rounded \
          --color=${
            lib.concatStringsSep "," (lib.mapAttrsToList (k: v: "${k}:${v}") config.programs.fzf.colors)
          }
        zstyle ':fzf-tab:*' switch-group '<' '>'
        zstyle ':fzf-tab:complete:*' fzf-preview ${lib.escapeShellArg preview}
      ''
      # After fzf's keybindings (910), before syntax highlighting (1200).
      (lib.mkOrder 1150 ''
        source ${pkgs.zsh-fzf-tab}/share/fzf-tab/fzf-tab.plugin.zsh
      '')
      (lib.mkOrder 1160 ''
        typeset -g _CELEBI_DIRENV_BIN=${lib.getExe config.programs.direnv.package}
        source ${./terminal-direnv.zsh}
      '')
    ];
    shellAliases = {
      # Explicit auto detection restores interactive colors even when the
      # launching application exports NO_COLOR, without coloring pipelines.
      ls = "eza --color=auto";
      ll = "eza --color=auto --long --header --git --icons=auto --group-directories-first";
      lt = "eza --color=auto --tree --level=2 --icons=auto --group-directories-first";
    };
  };

  programs.kitty = lib.recursiveUpdate kitty {
    font = {
      name = "JetBrainsMono Nerd Font";
      package = pkgs.nerd-fonts.jetbrains-mono;
      size = 11;
    };
    settings = {
      # Let Home Manager load shell integration once, without VTE also
      # trying to set titles and mark prompts.
      shell_integration = "no-rc";
      window_padding_width = 6;
      background_opacity = "0.94";
      tab_bar_style = "separator";
      tab_separator = ''"  "'';
      tab_bar_margin_width = 6;
      tab_bar_margin_height = "4 4";
      tab_bar_background = colors.base;
      active_tab_foreground = colors.mauve;
      active_tab_background = colors.surface0;
      active_tab_font_style = "bold";
      inactive_tab_foreground = colors.subtext0;
      inactive_tab_background = colors.base;
      inactive_tab_font_style = "normal";
      tab_title_template = tabTitle;
      active_tab_title_template = tabTitle;
    };
    keybindings = {
      "ctrl+shift+g" = "show_last_command_output";
      "ctrl+shift+h" = "show_scrollback";
      "ctrl+shift+z" = "scroll_to_prompt -1";
      "ctrl+shift+x" = "scroll_to_prompt 1";
      "ctrl+shift+p>f" = "kitten hints --type path --program -";
      "ctrl+shift+p>n" = "kitten hints --type linenum --linenum-action tab";
    };
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
    defaultOptions = [
      "--height=40%"
      "--layout=reverse"
      "--border=rounded"
    ];
    colors = {
      fg = colors.text;
      bg = colors.base;
      "fg+" = colors.text;
      "bg+" = colors.surface0;
      hl = colors.mauve;
      "hl+" = colors.mauve;
      prompt = colors.mauve;
      pointer = colors.mauve;
      marker = colors.green;
      spinner = colors.mauve;
      header = colors.subtext0;
      info = colors.subtext0;
      border = colors.surface1;
    };
    fileWidgetOptions = [
      "--preview 'if [ -d {} ]; then ${lib.getExe pkgs.eza} --all --color=always -- {}; else ${lib.getExe pkgs.bat} --color=always --paging=never --style=numbers --line-range=:160 -- {}; fi'"
      "--preview-window=right,50%,border-left"
    ];
    changeDirWidgetOptions = [ "--preview '${lib.getExe pkgs.eza} --all --color=always -- {}'" ];
  };

  programs.bat = {
    enable = true;
    config = {
      theme = "Catppuccin Macchiato";
      style = "numbers,changes,header";
    };
  };
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      syntax-theme = "Catppuccin Macchiato";
      dark = true;
      navigate = true;
      line-numbers = true;
      file-style = "bold ${colors.mauve}";
      file-decoration-style = "none";
      hunk-header-style = "file line-number syntax";
      hunk-header-decoration-style = "none";
      minus-style = ''syntax "#3b2d3d"'';
      minus-emph-style = ''syntax "#623c50"'';
      plus-style = ''syntax "#303d39"'';
      plus-emph-style = ''syntax "#435b46"'';
      line-numbers-minus-style = colors.red;
      line-numbers-plus-style = colors.green;
      line-numbers-zero-style = colors.overlay0;
    };
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
    nix-direnv.enable = true;
    config.global = {
      hide_env_diff = true;
      log_filter = "^$";
    };
  };
}
