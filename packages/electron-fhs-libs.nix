# Runtime libraries for upstream Electron .debs run inside a buildFHSEnv
# (packages/claude-desktop, packages/chatgpt-desktop). Covers what both
# packages' Debian `Depends:` lists ask for; app-specific extras are added
# by each package.
pkgs:
with pkgs;
[
  alsa-lib
  at-spi2-atk
  at-spi2-core
  cairo
  cups
  dbus
  expat
  gdk-pixbuf
  glib
  gtk3
  libdrm
  libGL
  libgbm
  libnotify
  libpulseaudio
  libsecret
  libuuid
  libx11
  libxcb
  libxcomposite
  libxdamage
  libxext
  libxfixes
  libxkbcommon
  libxrandr
  libxshmfence
  libxtst
  nspr
  nss
  pango
  pipewire
  systemd
  vulkan-loader
  xdg-utils
]
