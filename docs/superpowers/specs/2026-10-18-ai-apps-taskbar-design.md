# ChatGPT + Claude launchers on the right of the taskbar — design

Date: 2026-10-18

## Why

Chris wants one-click access to the ChatGPT and Claude desktop apps from the
Plasma taskbar. For Claude, Cowork is what matters, and Cowork needs the
official Linux app. The icons belong at the right end of the bar, but they
must not use up room when the screen is small or the bar is already full of
windows.

## Goals

1. **Claude**: Anthropic's official Linux app (`claude-desktop` .deb), with a
   **working Cowork tab**, on rowlett and celebi.
2. **ChatGPT**: OpenAI's official Linux preview app (`chatgpt` .deb), on
   rowlett and celebi.
3. **A taskbar widget** at the right end of the bottom panel, just left of the
   system tray, holding the two launchers:
   - **Room on the bar**: two icons side by side (ChatGPT, Claude).
   - **Bar crowded** (lots of windows open): collapses to **one icon**. A click
     opens a small popup with both launchers.
   - **No wide screen connected**: the widget is **hidden** and takes up
     **zero width**. "Wide" means a connected screen at least ~1600 logical
     px wide. The rule checks **all connected screens**, not only the one the
     panel is on, because when celebi is docked its panel **stays on the
     built-in laptop screen** (Chris). So:
     - celebi undocked: hidden.
     - celebi docked to a wide monitor: shown, on the laptop-screen panel.
     - rowlett: always shown.
   - **Running indicator**: while an app has a window open, its icon shows a
     dot or underline like the task manager's. In the collapsed state, the
     single icon shows the indicator if either app is running (builder's
     choice of presentation).
   - Clicking launches the app, or focuses it if it's already running.
4. Applies to **rowlett and celebi only**. wailmer's panel stays as it is.

## Non-goals

- No autostart and no start-minimized-to-tray.
- Running windows are **not** moved out of the left task list. They still
  show there like any other app; the right-side widget only adds a launcher
  and a running dot.
- No .rpm, no arm64, no Computer Use or dictation (neither exists on Linux).
- No memory/cgroup caps on the apps or the Cowork VM for now.

## Anti-goals (it fails even if it technically works when…)

- The Cowork tab reports "Cowork requires QEMU / hardware virtualization
  (KVM) / permission to use /dev/kvm / vhost_vsock".
- The Claude sign-in isn't remembered after a restart (keyring not reached).
- The widget takes space from the task list when the bar is crowded, or leaves
  a blank gap when hidden.
- wailmer's panel, or rowlett's xrdp XFCE session (`hosts/rowlett/xfce-panel.nix`),
  changes or breaks.
- An app's **package** silently updates outside Nix, or nags about updates
  in a way that breaks it. This does **not** cover what the apps download for
  themselves at runtime (the Cowork VM image, Claude Code, Codex, …). Those
  stay as shipped; don't pin or block them.

## Context and constraints

**Panel config.** The bottom panel is declared once in `common/plasma.nix`
(plasma-manager) and shared by rowlett, celebi and wailmer. Each host passes
args to it (`launchers`, `extraSystrayItems`, …). Widget order today:
`kickoff, icontasks (fillWidth), marginsseparator, systemTray, digitalclock,
showdesktop`. The panel exists on screen 0 only. Add a new arg, defaulting to
off, so only rowlett and celebi get the widget.

**Screens.**
- rowlett: DP-2 2560×1440 landscape (the panel lives here) plus DP-1
  1080×1920 portrait (no panel).
- celebi: Framework 13 laptop. Its built-in screen is under 1600 logical px
  wide. It is sometimes docked to an external monitor, and sometimes has an
  iPad attached as an extra display (sunshine/evdi).

**Existing Claude package (to be replaced).** `flake.nix` has input
`claude-desktop.url = "github:ChristopherJMiller/claude-for-linux"`, an
unofficial macOS-DMG repack (v1.1.3770, last updated March 2026). It's wired
in as `customPackages.claude-desktop` and installed on rowlett and celebi
through `custom-pkgs` in their `home.nix`. The `nixuc` alias in
`common/configuration.nix` runs `nix flake update claude-desktop … && nixr`.
Remove the input and its lock entry, and replace the alias.

**Official Claude app.**
- Apt repo: `https://downloads.claude.ai/claude-desktop/apt/stable`.
- Index: `dists/stable/main/binary-amd64/Packages`. It lists versioned pool
  files with SHA256s; as of 2026-10-18 the newest is `2.42304.0`, at
  `pool/main/c/claude-desktop/claude-desktop_2.42304.0_amd64.deb`
  (sha256 `74cd2ccc29d24165144e455cbc872c6cc2a24a263b83e73420e95f89166d4aa4`).
- Depends: gtk3, libnotify, nss, xdg-utils, at-spi, libdrm, gbm, xcb-dri3,
  libsecret, libxtst, libuuid, pipewire, xdg-desktop-portal (+ a backend).
- Recommends: alsa/pulse, appindicator, ca-certificates, keyring (KDE Wallet
  is fine; rowlett has kwallet PAM), **bubblewrap, socat, openssh-client,
  qemu-system-x86, ovmf, virtiofsd**.
- Docs: https://code.claude.com/docs/en/desktop-linux
- It does not self-update on Linux.

**Cowork requirements (from the docs).** Hardware virtualization; QEMU, UEFI
firmware (OVMF) and virtiofsd; the user able to open `/dev/kvm` **and**
`/dev/vhost-vsock` (the docs say to join the `kvm` group); and the
`vhost_vsock` kernel module loaded. The app checks all of this **once at
launch**. Today chris is not in the `kvm` group on rowlett, and nothing
loads `vhost_vsock` explicitly.

**Official ChatGPT app.**
- Docs: https://learn.chatgpt.com/docs/linux/linux-app
- The docs link a moving `…/linux/deb/latest/chatgpt_amd64.deb`. **Don't
  use it.** The .deb's postinst registers a real apt repo, and it has been
  checked:
  - Repo: `https://persistent.oaistatic.com/codex-app-prod/linux/deb`, suite
    `stable`, component `main`.
  - Index: `dists/stable/main/binary-amd64/Packages`.
  - As of 2026-10-18 the index lists **only** `26.1013.40934`, at
    `pool/main/c/chatgpt/chatgpt_26.1013.40934_amd64.deb`
    (sha256 `3ca59e7f9a6641b9e2fb9ad680683784b5ab8026ff7418fb212a0ebe5df3a1d7`,
    ~500 MB).
  - Pin that pool URL. Because only the newest version is listed, OpenAI may
    delete old pool files. If that happens, a host that has to re-fetch
    (celebi, or after GC) fails on the pinned URL until `nixuc` bumps it.
    That's accepted; the fix is to bump.
- Depends: the usual Electron set, plus libtss2 (TPM), libusb, libudev,
  vulkan, xz-utils. Recommends git.
- Package and binary are both named `chatgpt`.
- Wayland support is labelled experimental, so forcing XWayland is
  acceptable if native Wayland misbehaves.

**Working tree.** `hosts/rowlett/configuration.nix` has an **unrelated
uncommitted change** (Firefox cgroup cap). Don't sweep it into these commits.

## Decided

Decided with Chris:
- Official .debs for both apps, packaged **in this repo**, not in the
  claude-for-linux fork.
- Rowlett and celebi only. Collapse to one icon when crowded. Hide when no
  wide screen is connected (celebi undocked). Running dot on the right-side
  icons.
- celebi's panel stays on the laptop screen when docked, so the width check
  looks at every connected screen.

My calls (Chris can override):
- Packages live at `packages/claude-desktop` and `packages/chatgpt-desktop`
  and are `callPackage`d from `customPackages` in `flake.nix` (replacing the
  flake-input entry), so `custom-pkgs` keeps installing them on rowlett and
  celebi with no other change there.
- Each package is **pinned to one exact .deb by hash**. Nothing updates until
  bumped.
- `nixuc` becomes an update script that finds the newest version of each app
  (for Claude, from the apt `Packages` index), rewrites version + hash in the
  package files, and rebuilds.
- Claude runs inside an **FHS environment** (`buildFHSEnv`) that provides
  qemu, OVMF, virtiofsd, bubblewrap, socat and openssh at the Debian paths
  the app expects. The same goes for ChatGPT if that's the simplest way to
  run it.
- System side, on rowlett and celebi: add chris to `kvm`, and add
  `vhost_vsock` to `boot.kernelModules`.
- The widget is a **small custom Plasma 6 plasmoid (QML) kept in this repo**.
  Home-manager installs it, and plasma-manager adds it to the panel between
  icontasks and the system tray. The width threshold is a widget setting with
  default 1600.
- Every connected screen counts toward "wide", virtual ones included. That
  means celebi's iPad display (evdi) can switch the icons on when it's
  attached. That's accepted, not filtered out.
- "Does what the apps download at runtime count as silent updating?" No; see
  Anti-goals.

## Left to the builder

- How "crowded" is detected and how the widget switches. The obvious route:
  minimum width = one icon, preferred width = two icons, and switch when the
  panel gives it less than its preferred width. It **must be checked on the
  live panel** with many windows open.
- How the running dot finds each app's windows (e.g. a `TasksModel` filtered
  by app id / `StartupWMClass` from the .desktop files in the .debs).
- The collapsed icon's artwork.
- Where exactly Claude looks for qemu, OVMF and virtiofsd (read its logs, or
  grep the app bundle), and which FHS paths that means.
- FHS env vs `autoPatchelfHook` for ChatGPT.
- The plasmoid's id and where it sits in the repo.

## Verification

- `nixos-rebuild build` succeeds for rowlett, celebi **and** wailmer, and
  wailmer's generated panel config is unchanged.
- On rowlett, after a rebuild **and a log out/in** (needed for the group
  change):
  - Both apps launch from the widget.
  - Claude: sign-in survives quitting and relaunching; the Cowork tab shows
    no requirement errors; a small Cowork task runs to completion.
  - ChatGPT: signs in and chats.
  - Widget: two icons on the 2560 screen. Opening many windows collapses it
    to one icon with a working popup, and closing them restores both. The
    running dot appears and disappears with each app.
- celebi can only be build-checked from here. The hide rule can be checked
  on rowlett by temporarily setting the threshold above 2560: the widget
  should vanish with no gap.
