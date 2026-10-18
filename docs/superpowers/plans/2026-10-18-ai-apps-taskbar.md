# ChatGPT + Claude Taskbar Launchers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Install the official ChatGPT and Claude Linux desktop apps (Claude with working Cowork) on rowlett and celebi, and launch them from a width-aware widget at the right end of the Plasma taskbar.

**Architecture:** Each app is a pinned upstream `.deb` unpacked into a `buildFHSEnv`. Claude's FHS env also provides qemu, OVMF and virtiofsd at Debian paths. A shared NixOS module adds the KVM/vsock prerequisites. The widget is a small Plasma 6 plasmoid kept in this repo, with its decision logic in a pure JS file covered by `qmltestrunner` tests. It is installed and placed by `common/plasma.nix` only when a host passes launchers.

**Tech Stack:** NixOS 26.05 flake, home-manager, plasma-manager, `buildFHSEnv`, Plasma 6.6 QML (`org.kde.plasma.plasmoid`, `org.kde.taskmanager`, `org.kde.plasma.extras`), Qt 6 `qmltestrunner`, bash.

**Spec:** `docs/superpowers/specs/2026-10-18-ai-apps-taskbar-design.md`

## Global Constraints

- Hosts: **rowlett and celebi only**. wailmer's evaluated `programs.plasma.panels` JSON must be byte-identical before and after.
- `hosts/rowlett/configuration.nix` has an **unrelated uncommitted Firefox cgroup hunk**. Never stage it; verify with `git diff --cached` before every commit that touches that file.
- Claude source: repo `https://downloads.claude.ai/claude-desktop/apt/stable`, package `claude-desktop`; pin `2.42304.0` (sha256 `74cd2ccc29d24165144e455cbc872c6cc2a24a263b83e73420e95f89166d4aa4`) or whatever newer version the index lists on the day.
- ChatGPT source: repo `https://persistent.oaistatic.com/codex-app-prod/linux/deb`, package `chatgpt`; pin `26.1013.40934` (sha256 `3ca59e7f9a6641b9e2fb9ad680683784b5ab8026ff7418fb212a0ebe5df3a1d7`) or newer from the index. Never use the `…/latest/…` URL.
- Index path for both repos: `dists/stable/main/binary-amd64/Packages`.
- Widget: plugin id `xyz.chrismiller.widelaunchers`, config keys `launchers` (desktop ids, order ChatGPT then Claude) and `minScreenWidth` (default `1600`, logical px, checked against **every** connected screen).
- Don't pin or block anything the apps download at runtime (Cowork VM image, Claude Code, Codex). No autostart.
- Never delete `~/.config/Claude` (left by the old repack). If it has to move, rename it to `~/.config/Claude.repack-bak`.
- Nix style: match the surrounding files (nixfmt-rfc-style layout). Don't run `./format.sh`; it reformats the whole repo with a different formatter.
- `$SCRATCH` = `/tmp/claude-1000/-home-chris-nixos/569cfa43-8164-40c5-a40e-b6ee2323a11f/scratchpad`. All build symlinks, logs, screenshots and unpacked .debs go there. Unpack each .deb into its own fresh subdirectory.
- One-off tools come from `nix-shell -p …`. The user's `nixs` alias may not expand in non-interactive shells.
- Rebuilding needs sudo (`nixr` = `sudo nixos-rebuild switch --flake ~/nixos`). If sudo asks for a password, ask Chris to run `! nixr` in the prompt.
- Every commit message ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **Leftover `~/.config/Claude` from the repack.** The official app must start against the existing profile, or the problem must be recognised and the profile moved aside (never deleted). Task 3 smoke-launches against the real profile.
2. **Screens come and go at runtime** (celebi docking; scale changes). The widget should show or hide without a plasmashell restart. Task 7 tests this live by switching DP-2 to scale 2 and back.
3. **Clicking an app that's already running** should focus its existing window, not start a second instance. Covered in Task 7.
4. **Crowded, then uncrowded.** The widget collapses, then comes back to two icons, with no flicker and nothing stuck. Covered in Task 7.
5. **Claude sign-in survives an app restart** (Secret Service via KDE Wallet). Covered in Task 8.

---

### Task 1: Cowork system prerequisites

**Files:**
- Create: `common/cowork.nix`
- Modify: `hosts/rowlett/configuration.nix` (imports list, ~line 14), `hosts/celebi/configuration.nix` (imports list, ~line 16)

**Interfaces:**
- Produces: NixOS module that sets `users.users.chris.extraGroups = [ "kvm" ];` and `boot.kernelModules = [ "vhost_vsock" ];` (both merge with the host lists). Its header comment says why: Cowork's QEMU VM needs `/dev/kvm` and `/dev/vhost-vsock`, the app checks once at launch, and a group change needs a log out/in.

- [ ] **Step 1: Write the failing check.** Run:
  ```bash
  for h in rowlett celebi; do nix eval --json .#nixosConfigurations.$h.config.users.users.chris.extraGroups | grep -q '"kvm"' && nix eval --json .#nixosConfigurations.$h.config.boot.kernelModules | grep -q '"vhost_vsock"' && echo "$h OK" || echo "$h MISSING"; done
  ```
  Expected: `rowlett MISSING`, `celebi MISSING`.
- [ ] **Step 2: Create `common/cowork.nix` and add `../../common/cowork.nix` to both hosts' `imports`.**
- [ ] **Step 3: Re-run the Step 1 command.** Expected: `rowlett OK`, `celebi OK`. Also run `nix eval --json .#nixosConfigurations.wailmer.config.boot.kernelModules | grep -c vhost_vsock`. Expected: `0`.
- [ ] **Step 4: Commit.** Stage `common/cowork.nix` and `hosts/celebi/configuration.nix` normally. For rowlett, stage only the imports hunk with `printf 'y\nn\n' | git add -p hosts/rowlett/configuration.nix` (the imports hunk comes first, the Firefox hunk second). Check `git diff --cached hosts/rowlett/configuration.nix` shows only the import line, then commit `cowork: kvm group + vhost_vsock on rowlett and celebi`.

### Task 2: Pinned sources and the update script

**Files:**
- Create: `packages/update-desktop-debs.sh` (executable), `packages/claude-desktop/source.json`, `packages/chatgpt-desktop/source.json`
- Create (test): `packages/tests/update-desktop-debs.test.sh`, `packages/tests/fixtures/claude/dists/stable/main/binary-amd64/Packages`, `packages/tests/fixtures/chatgpt/dists/stable/main/binary-amd64/Packages`
- Modify: `common/configuration.nix:197` (`nixuc` alias)

**Interfaces:**
- Produces: `source.json` schema `{"version": "<deb Version>", "url": "<repo>/<Filename>", "sha256": "<hex SHA256 from index>"}`. Tasks 3 and 4 read it with `lib.importJSON ./source.json` and `fetchurl { inherit (src) url sha256; }`.
- Produces: `packages/update-desktop-debs.sh`. Shebang `#!/usr/bin/env nix-shell` / `#!nix-shell -i bash -p curl gawk coreutils`.
  - It handles two apps: `claude-desktop` (repo above, package `claude-desktop`) and `chatgpt-desktop` (repo above, package `chatgpt`).
  - For each app it fetches `<repo>/dists/stable/main/binary-amd64/Packages`, picks the stanza with the **highest `Version` by `sort -V`** (the index is not sorted) and writes `packages/<app>/source.json` relative to `REPO_ROOT` (default: the script's repo).
  - It prints `<app>: <old> -> <new>` or `<app>: up to date`.
  - Env overrides for tests: `CLAUDE_REPO`, `CHATGPT_REPO` (any URL curl accepts, including `file://`) and `REPO_ROOT`.
  - It never commits.
- Produces: `nixuc` alias, which becomes `~/nixos/packages/update-desktop-debs.sh && git -C ~/nixos commit -q -m "desktop apps: bump .debs" -- packages/claude-desktop/source.json packages/chatgpt-desktop/source.json; nixr`.

- [ ] **Step 1: Write the fixtures and the failing test.**
  - The Claude fixture has three `claude-desktop` stanzas: `2.37337.1`, `2.42304.0`, `2.9.0`, in that order, so the highest is in the middle and `2.9.0` would win a plain string sort. Each stanza has `Filename: pool/main/c/claude-desktop/claude-desktop_<v>_amd64.deb` and a distinct `SHA256:`.
  - The ChatGPT fixture has the single real stanza for `26.1013.40934`.
  - The test copies nothing. It runs the script with `REPO_ROOT=$(mktemp -d)` and `file://` repo overrides, then asserts:
    - `claude-desktop/source.json` equals `{"version":"2.42304.0","url":"file://…/claude/pool/main/c/claude-desktop/claude-desktop_2.42304.0_amd64.deb","sha256":"<fixture hash for 2.42304.0>"}` after `tr -d ' \n'` normalisation.
    - `chatgpt-desktop/source.json` has version `26.1013.40934`.
    - A second run prints `claude-desktop: up to date` and `chatgpt-desktop: up to date`, and leaves both files' mtimes unchanged.
    - An unreachable repo (`CLAUDE_REPO=file:///nonexistent`) makes the script exit non-zero without touching an existing `source.json`.
- [ ] **Step 2: Run `bash packages/tests/update-desktop-debs.test.sh`.** Expected: FAIL (script missing).
- [ ] **Step 3: Implement `packages/update-desktop-debs.sh`** per the interface. Write the JSON to a temp file and `mv` it into place only when the content changed, which is how the mtime assertion holds.
- [ ] **Step 4: Run the test.** Expected: all assertions PASS. Also run `nix-shell -p shellcheck --run 'shellcheck packages/update-desktop-debs.sh packages/tests/update-desktop-debs.test.sh'` and expect no output.
- [ ] **Step 5: Generate the real pins** with `packages/update-desktop-debs.sh`. Expected: `source.json` for both apps, with versions ≥ the Global Constraints pins. Update the `nixuc` alias.
- [ ] **Step 6: Commit** the script, tests, fixtures, both `source.json` files and `common/configuration.nix`, with message `desktop debs: pinned sources + update script`.

### Task 3: Claude Desktop package (official .deb, FHS, Cowork deps)

**Files:**
- Create: `packages/electron-fhs-libs.nix`. It is a function `pkgs: [ … ]` returning the runtime libraries common to both .debs' `Depends` (gtk3, nss, nspr, libnotify, at-spi2-atk, libdrm, mesa/libgbm, libxkbcommon, xorg libs, alsa-lib, cups, dbus, expat, pango, cairo, glib, libsecret, libuuid, pipewire, systemd (libudev), libGL, vulkan-loader, xdg-utils).
- Create: `packages/claude-desktop/default.nix`
- Modify: `flake.nix` (drop the `claude-desktop` input at line 20 and its destructured argument at line 46; change `customPackages.claude-desktop` at line 68 to `pkgs.callPackage ./packages/claude-desktop { }`), `flake.lock` (via `nix flake lock`)

**Interfaces:**
- Consumes: `packages/claude-desktop/source.json` (Task 2).
- Produces: derivation `claude-desktop` with `bin/claude-desktop` (the FHS wrapper), `share/applications/claude-desktop.desktop` (from the .deb, with `Exec=` rewritten to the wrapper and its `StartupWMClass` kept), and the .deb's `share/icons/**`. `meta.license = lib.licenses.unfree`. Task 7 refers to the desktop id `claude-desktop`. If the .deb's desktop file has a different basename, rename it to `claude-desktop.desktop` so the id stays stable.
- The FHS `targetPkgs` are `electron-fhs-libs` plus `qemu_kvm`, `OVMF.fd`, `virtiofsd`, `bubblewrap`, `socat`, `openssh`.
- A small `runCommand` layout derivation, also in `targetPkgs`, links the Nix files to the exact Debian paths the app uses. Step 2 discovers those paths.

- [ ] **Step 1: Fetch and unpack the .deb for inspection** into a fresh scratch dir: `nix-prefetch-url <url from source.json>`, then `dpkg-deb -x` via `nix-shell -p dpkg`. Record: the binary path, desktop file name and contents, and icon paths.
- [ ] **Step 2: Discover Cowork's host paths.** Unpack `app.asar` (`nix-shell -p asar --run 'asar extract …'`). Run `grep -raoh -E '/usr/(share|lib|libexec|bin)/[A-Za-z0-9_./-]*(qemu|OVMF|ovmf|edk2|virtiofsd)[A-Za-z0-9_./-]*' | sort -u`, and also `grep -raoh -E 'qemu-system-[a-z0-9_]+|virtiofsd|OVMF[A-Za-z0-9_.-]*\.fd' | sort -u`. Write the resulting path list into a comment in `default.nix`. The layout derivation must cover every path the app probes **first**. If it probes several candidates, one hit is enough.
- [ ] **Step 3: Write the failing smoke test** in this exact form:
  ```bash
  nix build --impure --expr 'let f = builtins.getFlake (toString ./.); in f.nixosConfigurations.rowlett.pkgs.callPackage ./packages/claude-desktop { }' -o $SCRATCH/claude-result && \
  ( timeout 25 $SCRATCH/claude-result/bin/claude-desktop > $SCRATCH/claude-smoke.log 2>&1; echo "exit=$?" ) && \
  grep -E -c 'error while loading shared libraries|cannot open shared object|FATAL' $SCRATCH/claude-smoke.log
  ```
  Expected for now: the build fails (no `default.nix`).
- [ ] **Step 4: Implement `packages/electron-fhs-libs.nix` and `packages/claude-desktop/default.nix`.** Use `buildFHSEnv` with `runScript` pointing at the unpacked app's launcher, and `extraInstallCommands` for the desktop file and icons. In the FHS shell, check that every path from Step 2 exists (`ls` them).
- [ ] **Step 5: Run the smoke test.** Expected: `exit=124` (it was still running when killed), a grep count of `0`, and a Claude window visible during the 25 s against the existing `~/.config/Claude`. If it crashes on the old profile, quit, move the profile to `~/.config/Claude.repack-bak`, rerun, and note this in the commit message.
- [ ] **Step 6: Rewire the flake.** Remove the input, run `nix flake lock` (it drops `claude-for-linux` from `flake.lock`), and check that `nix eval .#nixosConfigurations.rowlett.config.system.build.toplevel.drvPath` and the same for celebi succeed. Then run `grep -c claude-for-linux flake.lock`. Expected: `0`.
- [ ] **Step 7: Commit** the package, the libs file, `flake.nix` and `flake.lock`, with message `claude-desktop: official Linux .deb in FHS env, drop claude-for-linux`.

### Task 4: ChatGPT Desktop package

**Files:**
- Create: `packages/chatgpt-desktop/default.nix`
- Modify: `flake.nix` `customPackages`: add `chatgpt-desktop = pkgs.callPackage ./packages/chatgpt-desktop { };`. Both hosts' `custom-pkgs` pick it up automatically; wailmer has no `custom-pkgs`.

**Interfaces:**
- Consumes: `packages/chatgpt-desktop/source.json`, `packages/electron-fhs-libs.nix`.
- Produces: `bin/chatgpt`, `share/applications/<id>.desktop` and icons. Record the desktop id (expected `chatgpt`) for Task 7. Extra `targetPkgs` cover what the `Depends` list adds: `tpm2-tss`, `libusb1`, `xz`, plus `git` (Recommends).

- [ ] **Step 1: Write the failing smoke test.** It is the Task 3 Step 3 command with `chatgpt-desktop`, `bin/chatgpt` and `$SCRATCH/chatgpt-*` paths. Expected: the build fails.
- [ ] **Step 2: Implement it** by unpacking and inspecting the .deb the same way as Task 3 Step 1, then writing `default.nix`. If the native Wayland window misbehaves (no window, or a blank one), add `--ozone-platform=x11` in the wrapper and say why in a comment.
- [ ] **Step 3: Run the smoke test.** Expected: `exit=124`, a grep count of `0`, and a ChatGPT window visible.
- [ ] **Step 4: Commit** with message `chatgpt-desktop: official Linux preview .deb in FHS env`.

### Task 5: Widget decision logic (pure JS, tested)

**Files:**
- Create: `packages/plasma-widelaunchers/package/contents/ui/logic.js` (`.pragma library`)
- Test: `packages/plasma-widelaunchers/tests/tst_logic.qml`

**Interfaces:**
- Produces, all pure:
  - `hasWideScreen(screenWidths: number[], minWidth: number) -> bool`: true iff some width ≥ minWidth.
  - `displayMode(wide: bool, allocatedWidth: number, slot: number, count: number) -> "hidden" | "full" | "collapsed"`: `"hidden"` if `!wide` or `count === 0`; `"full"` if `allocatedWidth >= slot * count - 0.5`; otherwise `"collapsed"`.
  - `appState(rows: {AppId: string, IsLauncher: bool}[], appId: string) -> {row: number, running: bool}`: `row` is the index of the first row with that AppId (or -1). `running` is true iff some row with that AppId has `IsLauncher === false`.
  - `anyRunning(states: {running: bool}[]) -> bool`.

- [ ] **Step 1: Write `tst_logic.qml`** (`import QtTest`, `import "../package/contents/ui/logic.js" as Logic`, `TestCase { name: "Logic" … }`) with these cases:
  - `hasWideScreen([2560,1080],1600)` → true
  - `hasWideScreen([1504],1600)` → false
  - `hasWideScreen([1504,2560],1600)` → true (celebi docked: the panel is on the narrow screen but a wide one is connected)
  - `hasWideScreen([],1600)` → false
  - `hasWideScreen([1600],1600)` → true (boundary)
  - `displayMode(false,200,44,2)` → `"hidden"`
  - `displayMode(true,88,44,2)` → `"full"`
  - `displayMode(true,87.7,44,2)` → `"full"` (sub-pixel tolerance)
  - `displayMode(true,60,44,2)` → `"collapsed"`
  - `displayMode(true,44,44,0)` → `"hidden"`
  - `appState([{AppId:"chatgpt",IsLauncher:true},{AppId:"claude-desktop",IsLauncher:false}],"claude-desktop")` → `{row:1,running:true}`
  - the same rows with `"chatgpt"` → `{row:0,running:false}`
  - `appState([], "chatgpt")` → `{row:-1,running:false}`
  - `anyRunning([{running:false},{running:true}])` → true
- [ ] **Step 2: Run** `nix-shell -p qt6.qtdeclarative --run 'QT_QPA_PLATFORM=offscreen qmltestrunner -input packages/plasma-widelaunchers/tests'`. Expected: FAIL (`logic.js` not found).
- [ ] **Step 3: Implement `logic.js`.**
- [ ] **Step 4: Re-run.** Expected: a `Totals:` line with `0 failed`, `0 skipped`, and every case above asserted.
- [ ] **Step 5: Commit** with message `plasma-widelaunchers: decision logic + tests`.

### Task 6: The plasmoid

**Files:**
- Create: `packages/plasma-widelaunchers/package/metadata.json`, `…/package/contents/config/main.xml`, `…/package/contents/ui/main.qml`, `packages/plasma-widelaunchers/default.nix`

**Interfaces:**
- Consumes: `logic.js` (Task 5).
- Produces: derivation installing `share/plasma/plasmoids/xyz.chrismiller.widelaunchers/`, with `doCheck = true` running the Task 5 `qmltestrunner` command offscreen (`nativeCheckInputs = [ qt6.qtdeclarative ]`).
- `metadata.json`: `KPackageStructure: "Plasma/Applet"`, `KPlugin.Id: "xyz.chrismiller.widelaunchers"`, `KPlugin.Name: "Wide Launchers"`, `KPlugin.Icon: "dialog-messages"`, `X-Plasma-API-Minimum-Version: "6.0"`.
- `main.xml` (group `General`): `launchers` StringList (default empty) and `minScreenWidth` Int (default 1600).
- `main.qml` behaviour, as decided:
  - **Root:** `PlasmoidItem` with `preferredRepresentation: fullRepresentation`. `slot` = panel thickness (`height` in a horizontal panel). `Layout.minimumWidth: mode === "hidden" ? 0 : slot`. `Layout.preferredWidth: mode === "hidden" ? 0 : slot * count`. `Layout.maximumWidth` equals the preferred width. When hidden, `Plasmoid.status` is `HiddenStatus` and `visible` is false.
    - Collapse detection rides on the panel squeezing the widget below its preferred width. The preferred width deliberately stays at `slot * count` in collapsed mode, so the widget can tell when room comes back.
  - **Mode:** `mode = Logic.displayMode(Logic.hasWideScreen(Qt.application.screens.map(s => s.width), Plasmoid.configuration.minScreenWidth), width, slot, count)`. Reference `Qt.application.screens` directly in the binding so screen hotplug re-evaluates it.
  - **Tasks model:** a private `TaskManager.TasksModel` with `filterByScreen`, `filterByVirtualDesktop` and `filterByActivity` all false, `groupMode: GroupApplications`, `separateLaunchers: false`, `launchInPlace: true`, and `launcherList: Plasmoid.configuration.launchers.map(id => "applications:" + id + ".desktop")`.
    - Rows are read through an `Instantiator`/`Repeater` into `{AppId, IsLauncher}` for `Logic.appState`.
    - Clicking an app: if it's running, `requestActivate(tasksModel.makeModelIndex(row, 0))` (the first window of the group). Otherwise `requestNewInstance(tasksModel.makeModelIndex(row))`.
  - **Full mode:** one icon per launcher (icon from the model's `decoration` role, tooltip = app name). A 3 px high, `slot/2` wide, `Kirigami.Theme.highlightColor` bar at the panel-edge side under each running app.
  - **Collapsed mode:** one `dialog-messages` icon, centred in the allocated width, with the same bar if `Logic.anyRunning`. Clicking it opens a `PlasmaExtras.Menu` (`openRelative()`) with one item per app (icon + name); choosing an item runs the same click logic.

- [ ] **Step 1: Write the failing smoke test:** `nix build --impure --expr 'let f = builtins.getFlake (toString ./.); in f.nixosConfigurations.rowlett.pkgs.callPackage ./packages/plasma-widelaunchers { }' -o $SCRATCH/wl-result && ls $SCRATCH/wl-result/share/plasma/plasmoids/xyz.chrismiller.widelaunchers/contents/ui/main.qml`. Expected: FAIL.
- [ ] **Step 2: Write `metadata.json`, `main.xml`, `main.qml` and `default.nix`.**
- [ ] **Step 3: Run the smoke test.** Expected: the build passes, including checkPhase (the test totals line is in the build log via `nix log`), and `ls` prints the path.
- [ ] **Step 4: Load check in plasmoidviewer.** Get plasmoidviewer from the **flake's** nixpkgs so its Qt/Plasma matches the running session: `nix shell --impure --expr '(builtins.getFlake (toString ./.)).nixosConfigurations.rowlett.pkgs.kdePackages.plasma-sdk' -c plasmoidviewer -a $SCRATCH/wl-result/share/plasma/plasmoids/xyz.chrismiller.widelaunchers -f horizontal`.
  - For this run only, set a temporary `main.xml` default of `launchers` = `chatgpt,claude-desktop`, rebuild, run the viewer, then revert the default.
  - Expected: no QML errors on stderr, and two icons (ChatGPT, Claude).
  - If plasmoidviewer itself can't start (a missing Plasma QML module, not a widget error), say so and leave the behaviour checks to Task 7.
  - Clicking ChatGPT launches it; a second click focuses the same window, and `pgrep -c -f chatgpt` doesn't grow by a new main process.
- [ ] **Step 5: Commit** with message `plasma-widelaunchers: right-side launchers that collapse/hide by width`.

### Task 7: Put the widget on the rowlett and celebi panels

**Files:**
- Modify: `common/plasma.nix` (new arg, install the plasmoid, insert the widget between `org.kde.plasma.icontasks` and `org.kde.plasma.marginsseparator`; the module args become `{ lib, pkgs, ... }`)
- Modify: `hosts/rowlett/home.nix:174-192`, `hosts/celebi/home.nix:178-190`

**Interfaces:**
- Consumes: the plasmoid derivation (Task 6), desktop ids (Tasks 3 and 4).
- Produces: `common/plasma.nix` arg `rightLaunchers ? [ ]` (list of desktop ids). When it's non-empty:
  - `home.packages` gets `pkgs.callPackage ../packages/plasma-widelaunchers { }`.
  - The panel gets `{ name = "xyz.chrismiller.widelaunchers"; config.General = { launchers = rightLaunchers; minScreenWidth = 1600; }; }`.
  - When it's empty, the panel's widget list is exactly today's.
- rowlett and celebi pass `rightLaunchers = [ "chatgpt" "claude-desktop" ];` (adjusted to the ids recorded in Tasks 3 and 4).

- [ ] **Step 1: Capture the wailmer baseline before editing:** `nix eval --json .#nixosConfigurations.wailmer.config.home-manager.users.chris.programs.plasma.panels > $SCRATCH/wailmer-panels.before.json`.
- [ ] **Step 2: Write the failing check:**
  ```bash
  for h in rowlett celebi; do nix eval --json .#nixosConfigurations.$h.config.home-manager.users.chris.programs.plasma.panels | grep -q xyz.chrismiller.widelaunchers && echo "$h OK" || echo "$h MISSING"; done
  ```
  Expected: both `MISSING`.
- [ ] **Step 3: Implement the arg and wire both hosts.**
- [ ] **Step 4: Run the checks.** Expected: both `OK`. Then run `nix eval --json …wailmer…panels | cmp - $SCRATCH/wailmer-panels.before.json && echo SAME`. Expected: `SAME`. `nixos-rebuild build --flake .#celebi` and `.#wailmer` succeed.
- [ ] **Step 5: Switch rowlett and reload the shell:** `nixr` (sudo; see Global Constraints), then `kdereload`. Expected: two icons appear left of the tray, ChatGPT then Claude. `journalctl --user -u plasma-plasmashell --since -2min | grep -i widelaunchers` shows no QML errors.
- [ ] **Step 6: Live behaviour checks on rowlett** (take a `spectacle -b -n -o <scratch>/<name>.png` screenshot for each):
  1. **Crowding.** Run `for i in $(seq 40); do kitty --detach --class "crowd$i" sleep 600; done` (separate classes, so the task manager doesn't group them). Expected: the widget collapses to a single icon, and the popup launches both apps. Then `pkill -f 'sleep 600'`. Expected: back to two icons, with no flicker while windows close.
     - **STOP condition:** if the widget never collapses (the panel never squeezes it), don't invent a fallback. Log `width`/`slot` with `console.log`, read them from the journal, and report the measurements back.
  2. **Running dot.** Opening Claude shows the bar under its icon; quitting it clears the bar. Clicking the icon while Claude is open focuses the existing window.
  3. **Screen change.** `kscreen-doctor output.DP-2.scale.2` → the widget hides with no gap left of the tray (DP-2 is now 1280 logical, DP-1 is 1080, so neither reaches 1600). `kscreen-doctor output.DP-2.scale.1` → it reappears. No plasmashell restart in between.
- [ ] **Step 7: Commit** `common/plasma.nix` and both `home.nix` files, with message `plasma: ChatGPT + Claude launchers on the right for rowlett and celebi`.

### Task 8: End-to-end app verification on rowlett (with Chris)

**Files:** none, unless a fix is needed. Fixes go into the owning task's files and get their own commit.

- [ ] **Step 1: Ask Chris to log out and back in** (this makes the `kvm` group live), then confirm with `id | grep -o kvm`. Expected: `kvm`.
- [ ] **Step 2: Claude checks** (Chris signs in):
  - The Cowork tab shows **none** of "requires QEMU / hardware virtualization (KVM) / permission … /dev/kvm / vhost_vsock".
  - A small Cowork task ("list the files in a new empty folder and write hello.txt") runs to completion.
  - Quitting the app (tray → Quit) and relaunching from the widget keeps Chris signed in.
- [ ] **Step 3: ChatGPT checks** (Chris signs in): a chat round-trip works, and it is still signed in after quit + relaunch.
- [ ] **Step 4: Report.** For each spec Verification item, give pass/fail with evidence (screenshots and command output). Include any profile move from Task 3.
