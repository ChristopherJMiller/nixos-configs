# Pi coding agent, configured the same on every host and in the devbox.
#
# Pi keeps rewriting its own JSON files (settings.json records the last
# changelog it showed, /settings and `pi install` edit it, the marketplace
# and MCP adapter write theirs), so they can't be read-only symlinks. Instead,
# every activation deep-merges the values below into the live files: keys set
# here win, anything else Pi or you added is kept. Change a synced setting
# here, not in Pi, or the next switch puts it back.
#
# Per-machine, not managed: auth.json (run `/login` → GitHub Copilot once),
# sessions, installed package checkouts, and engram's memory (~/.engram).
pkgs-unstable:
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Keep in lockstep with gentle-engram below (see packages/engram).
  engram = pkgs.callPackage ../packages/engram { };

  # Pinned so every machine runs the same code; Pi installs anything missing
  # (or at a different version) on its next start. Bump deliberately.
  packages = [
    # Claude Code-style subagents: the `Agent` tool (Explore, Plan,
    # general-purpose), live fleet view, Ctrl+B to background.
    "npm:@tintinweb/pi-subagents@0.25.0"
    # Claude Code-style TaskCreate/TaskList/TaskUpdate/... with a live list.
    "npm:@tintinweb/pi-tasks@0.9.1"
    # AskUserQuestion: a structured multiple-choice questionnaire.
    "npm:@juicesharp/rpiv-ask-user-question@2.15.0"
    # MCP with lazy servers (start on first use, stop after 10 idle min) and
    # live import of Claude Code's MCP servers. Replaces Pi's built-in MCP.
    "npm:pi-mcp-adapter@7.0.1"
    # Claude plugin marketplaces (commands, skills, MCP) — see claudePlugins.
    "npm:pi-claude-marketplace@0.23.0"
    # Compaction without an LLM call, plus `vcc_recall` over the history
    # that was compacted away.
    "npm:@sting8k/pi-vcc@0.11.2"
    # Engram memory (native mem_* tools). Must match the engram binary.
    "npm:gentle-engram@0.7.1"
    # Background bash: `bash` gains `background: true` (the agent is woken
    # when the command exits), plus bash_output/bash_tasks/bash_kill, /bg,
    # and ctrl+shift+b to background a running command. pi/background-key.ts
    # adds ctrl+b for the same and reads this package's internal registry,
    # so re-check that file when bumping this pin.
    "npm:pi-bg-bash@0.6.0"
    # Superpowers skills, loaded on demand. Its bootstrap extension (which
    # injects "use a skill before ANY response" into every request) is off
    # here; turn it on for a project with .pi/settings.json:
    #   { "packages": ["git:github.com/obra/superpowers@v7.0.2"] }
    {
      source = "git:github.com/obra/superpowers@v7.0.2";
      extensions = [ ];
    }
  ];

  # Copilot models with ~1M-token windows: compact at ~400K instead of
  # ~984K. Long before the window fills, requests get slow and the model
  # loses the thread.
  bigContextModels = [
    "claude-opus-5.5"
    "claude-sonnet-5.5"
    "claude-fable-5.2"
    "gpt-6.1-sol"
    "gpt-6-astra"
  ];

  settings = {
    defaultProvider = "github-copilot";
    defaultModel = "claude-opus-5.5";
    modelThinkingLevels = {
      "github-copilot/claude-opus-5.5" = "xhigh";
      "github-copilot/gpt-6.1-sol" = "xhigh";
      "github-copilot/gpt-6-astra" = "high";
    };
    followUpMode = "all";
    steeringMode = "all";
    quietStartup = true;
    enableInstallTelemetry = false;
    defaultProjectTrust = "ask";

    inherit packages;
    npmCommand = [ "${pkgs.nodejs}/bin/npm" ];
    # pi-mcp-adapter replaces the built-in MCP; say so up front so the
    # adapter doesn't have to edit this file on first start.
    extensions = [ "-builtin:mcp" ];
    # Load rarely used tools on demand, like Claude Code's ToolSearch: MCP
    # tools and engram's less common mem_* tools stay out of every request
    # until the model searches for them. (Without tool_search, gentle-engram
    # declares all of its ~28 tools up front.)
    defaultTools = [ "+tool_search" ];

    compaction.modelOverrides = lib.genAttrs (map (m: "github-copilot/${m}") bigContextModels) (_: {
      reserveTokens = 600000;
    });
  };

  # pi-mcp-adapter. Claude Code is the source of truth for MCP servers
  # (`claude mcp add ...`); Pi imports them live from ~/.claude.json.
  mcpAdapter = {
    imports = [ "claude-code" ];
    mcpServers = {
      # Web search + clean-markdown page fetch. Keyless; Pi only, since
      # Claude Code has its own WebSearch/WebFetch.
      exa = {
        url = "https://mcp.exa.ai/mcp";
        directTools = true;
      };
      # Pi reaches engram through gentle-engram's native tools; engram says
      # not to also register its MCP server, so skip the one Claude has.
      engram.disabled = true;
    };
  };

  # pi-claude-marketplace's desired state. autoapply installs anything
  # missing when Pi loads, so new machines catch up on their own.
  claudePlugins = {
    schemaVersion = 1;
    autoapply = true;
    marketplaces.claude-plugins-official = {
      source = "anthropics/claude-plugins-official";
      autoupdate = true;
    };
    plugins."frontend-design@claude-plugins-official" = { };
  };

  # pi-tasks: keep task files under ~/.pi/agent, not in each repo's .pi/.
  tasksConfig.taskScope = "session-global";

  managedJson = {
    ".pi/agent/settings.json" = settings;
    ".pi/agent/mcp-adapter.json" = mcpAdapter;
    ".pi/agent/claude-plugins.json" = claudePlugins;
    ".pi/agent/tasks-config.json" = tasksConfig;
  };

  jsonFormat = pkgs.formats.json { };

  # merge-json TARGET MANAGED: deep-merge MANAGED into TARGET (MANAGED wins;
  # arrays are replaced, not concatenated). A missing or unparsable TARGET is
  # replaced outright, keeping a backup of the unparsable one.
  mergeJson = pkgs.writeShellScript "pi-merge-json" ''
    set -eu
    target=$1 managed=$2
    mkdir -p "$(dirname "$target")"
    if [ -s "$target" ] && ${pkgs.jq}/bin/jq -e 'type == "object"' "$target" >/dev/null 2>&1; then
      tmp=$(mktemp "$target.XXXXXX")
      ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "$target" "$managed" >"$tmp"
      chmod --reference="$target" "$tmp" 2>/dev/null || chmod 644 "$tmp"
      mv "$tmp" "$target"
    else
      if [ -e "$target" ] || [ -L "$target" ]; then
        mv "$target" "$target.unparsable-$(date +%s)"
      fi
      install -m 644 "$managed" "$target"
    fi
  '';
in
{
  home = {
    packages = [
      pkgs-unstable.pi-coding-agent
      engram
    ];

    file = {
      # Pi reads the same user-level instructions as Claude Code, whether a
      # host generates ~/.claude/CLAUDE.md from Nix or edits it by hand.
      ".pi/agent/CLAUDE.md".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.claude/CLAUDE.md";
      ".pi/agent/extensions/copilot-credits.ts".source = ./pi/copilot-credits.ts;
      ".pi/agent/extensions/footer.ts".source = ./pi/footer.ts;
      ".pi/agent/extensions/background-key.ts".source = ./pi/background-key.ts;
    };

    activation.piConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] (
      lib.concatStrings (
        lib.mapAttrsToList (path: value: ''
          run ${mergeJson} "$HOME/${path}" ${jsonFormat.generate (baseNameOf path) value}
        '') managedJson
      )
    );
  };
}
