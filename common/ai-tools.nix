# Shared coding CLIs. Keep auth and settings writable so interactive logins
# and provider/model choices survive Home Manager activation.
# Pi: run /login and choose GitHub Copilot once per machine.
pkgs-unstable: {
  home.packages = with pkgs-unstable; [
    codex
    pi-coding-agent
  ];
}
