#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl gawk coreutils
# shellcheck shell=bash
# Bump the pinned upstream .debs (packages/<app>/source.json) to the newest
# version in each vendor's apt repository. Reads only the repo's Packages
# index — version, pool path and SHA256 all come from there, so nothing is
# downloaded. Never commits; the `nixuc` alias does that.
#
# Env overrides (used by packages/tests/update-desktop-debs.test.sh):
#   REPO_ROOT     checkout to write into (default: this script's repo)
#   CLAUDE_REPO   apt repo base URL for claude-desktop
#   CHATGPT_REPO  apt repo base URL for chatgpt
set -euo pipefail

repo_root=${REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}

# <dir under packages/>  <apt package name>  <apt repo base URL>
apps=(
  "claude-desktop claude-desktop ${CLAUDE_REPO:-https://downloads.claude.ai/claude-desktop/apt/stable}"
  "chatgpt-desktop chatgpt ${CHATGPT_REPO:-https://persistent.oaistatic.com/codex-app-prod/linux/deb}"
)

status=0
for entry in "${apps[@]}"; do
  read -r dir pkg base <<< "$entry"
  out="$repo_root/packages/$dir/source.json"

  if ! index=$(curl -fsSL "$base/dists/stable/main/binary-amd64/Packages"); then
    echo "$dir: failed to fetch index from $base" >&2
    status=1
    continue
  fi

  # One "version filename sha256" line per stanza of this package; the index
  # is not sorted, so pick the highest version with sort -V.
  newest=$(awk -v pkg="$pkg" '
    /^Package: / { p = $2 }
    /^Version: / { v = $2 }
    /^Filename: / { f = $2 }
    /^SHA256: / { s = $2 }
    /^$/ { if (p == pkg && v && f && s) print v, f, s; p = v = f = s = "" }
    END { if (p == pkg && v && f && s) print v, f, s }
  ' <<< "$index" | sort -V -k1,1 | tail -n 1)

  if [ -z "$newest" ]; then
    echo "$dir: no $pkg package in $base" >&2
    status=1
    continue
  fi
  read -r version filename sha256 <<< "$newest"

  json=$(printf '{\n  "version": "%s",\n  "url": "%s/%s",\n  "sha256": "%s"\n}\n' \
    "$version" "$base" "$filename" "$sha256")

  old=$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$out" 2>/dev/null || true)
  if [ -f "$out" ] && [ "$json" = "$(cat "$out")" ]; then
    echo "$dir: up to date"
    continue
  fi

  mkdir -p "$(dirname "$out")"
  tmp=$(mktemp "$out.XXXXXX")
  printf '%s\n' "$json" > "$tmp"
  mv "$tmp" "$out"
  echo "$dir: ${old:-none} -> $version"
done

exit "$status"
