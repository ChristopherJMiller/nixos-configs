let
  kitty = {
    enable = true;
    themeFile = "Catppuccin-Macchiato";

    settings = {
      # Layouts
      enabled_layouts = "tall:bias=50;full_size=1;mirrored=false";

      # Scrollback
      scrollback_lines = 10000;

      # Bell
      enable_audio_bell = false;

      # Tab bar
      tab_bar_edge = "bottom";
      tab_bar_style = "powerline";
      tab_powerline_style = "slanted";

      # Close confirmation (0 = never ask)
      confirm_os_window_close = 0;

      # Shell integration
      shell_integration = "enabled";

      # URL handling
      url_style = "curly";

      # Tab titles
      tab_title_template = "{fmt.fg.red}{bell_symbol}{activity_symbol}{fmt.fg.tab}{index}: {title}";
      active_tab_title_template = "{fmt.fg.red}{bell_symbol}{activity_symbol}{fmt.fg.tab}{index}: {title}";
      tab_activity_symbol = "*";
    };

    keybindings = {
      # New tab/window inheriting cwd
      "ctrl+shift+t" = "new_tab_with_cwd";
      "ctrl+shift+enter" = "new_window_with_cwd";

      # Tab navigation
      "ctrl+shift+right" = "next_tab";
      "ctrl+shift+left" = "previous_tab";

      # Layout cycling
      "ctrl+shift+l" = "next_layout";
    };
  };
in
{
  inherit kitty;
}
