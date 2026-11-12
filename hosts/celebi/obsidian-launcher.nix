# Obsidian from the Meta launcher: vicinae script commands (Raycast format)
# for capturing into the vault's Inbox without opening Obsidian, starting a
# new note from the Note template, and jumping to the Inbox. They work on the
# vault files directly, so Obsidian picks the changes up whenever it's open.
{ config, lib, pkgs, ... }:

let
  vault = "ObsidianVault";
  vaultDir = "$HOME/${config.programs.obsidian.vaults.${vault}.target}";
  icon = "${config.programs.obsidian.package}/share/icons/hicolor/256x256/apps/obsidian.png";

  bash = lib.getExe pkgs.bash;
  jq = lib.getExe pkgs.jq;
  xdgOpen = "${pkgs.xdg-utils}/bin/xdg-open";

  # Open a vault-relative path (no .md) in Obsidian.
  openInObsidian = path: ''
    ${xdgOpen} "obsidian://open?vault=${vault}&file=$(${jq} -rn --arg p "${path}" '$p | @uri')"
  '';

  script =
    { title, description, argument ? null, body }:
    {
      executable = true;
      text = ''
        #!${bash}
        # @vicinae.schemaVersion 1
        # @vicinae.title ${title}
        # @vicinae.description ${description}
        # @vicinae.packageName Obsidian
        # @vicinae.icon ${icon}
        # @vicinae.mode silent
        ${lib.optionalString (argument != null) ''
          # @vicinae.argument1 { "type": "text", "placeholder": "${argument}" }
        ''}
        set -eu
        ${body}
      '';
    };
in
{
  xdg.dataFile."vicinae/scripts/obsidian-capture.sh" = script {
    title = "Capture to Inbox";
    description = "Append a timestamped line to Inbox/Inbox.md";
    argument = "thought, link, todo…";
    body = ''
      inbox="${vaultDir}/Inbox/Inbox.md"
      mkdir -p "$(dirname "$inbox")"
      touch "$inbox"
      # Start a list after the intro paragraph, and never glue onto a line
      # that lacks its trailing newline.
      if [ -s "$inbox" ] && [ -n "$(tail -c1 "$inbox")" ]; then echo >> "$inbox"; fi
      if [ -s "$inbox" ] && ! tail -n1 "$inbox" | grep -q '^- '; then echo >> "$inbox"; fi
      printf -- '- %s %s\n' "$(date '+%F %H:%M')" "$1" >> "$inbox"
      echo "Captured to Inbox"
    '';
  };

  xdg.dataFile."vicinae/scripts/obsidian-new-note.sh" = script {
    title = "New Note";
    description = "Create Inbox/<title>.md from the Note template and open it";
    argument = "title";
    body = ''
      # Characters Obsidian won't allow in a note name.
      title=$(printf '%s' "$1" | sed 's/[][\\/:*?"<>|#^]/-/g')
      note="${vaultDir}/Inbox/$title.md"
      if [ ! -e "$note" ]; then
        template="${vaultDir}/Templates/Note.md"
        if [ -f "$template" ]; then
          content=$(cat "$template")
          content=''${content//"{{date:YYYY-MM-DD}}"/$(date +%F)}
          content=''${content//"{{title}}"/$title}
          printf '%s\n' "$content" > "$note"
        else
          printf '# %s\n' "$title" > "$note"
        fi
      fi
      ${openInObsidian "Inbox/$title"}
    '';
  };

  xdg.dataFile."vicinae/scripts/obsidian-open-inbox.sh" = script {
    title = "Open Inbox";
    description = "Open Inbox/Inbox.md in Obsidian";
    body = openInObsidian "Inbox/Inbox";
  };
}
