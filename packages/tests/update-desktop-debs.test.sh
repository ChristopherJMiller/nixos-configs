#!/usr/bin/env bash
# Tests for packages/update-desktop-debs.sh against local apt-index fixtures.
# Run: bash packages/tests/update-desktop-debs.test.sh
set -u

here=$(cd "$(dirname "$0")" && pwd)
script="$here/../update-desktop-debs.sh"
fixtures="$here/fixtures"
fails=0

check() { # check <description> <expected> <actual>
  if [ "$2" = "$3" ]; then
    echo "ok   - $1"
  else
    echo "FAIL - $1"
    echo "       expected: $2"
    echo "       actual:   $3"
    fails=$((fails + 1))
  fi
}

run() { # run <repo_root> [extra env...] — prints combined output
  env REPO_ROOT="$1" \
    CLAUDE_REPO="file://$fixtures/claude" \
    CHATGPT_REPO="file://$fixtures/chatgpt" \
    "${@:2}" bash "$script" 2>&1
}

normalise() { tr -d ' \n' < "$1"; }

root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT
mkdir -p "$root/packages/claude-desktop" "$root/packages/chatgpt-desktop"

# 1. Picks the highest version by version sort, not file order or string sort
#    (fixture order: 2.37337.1, 2.42304.0, 2.9.0).
run "$root" > /dev/null
check "claude: highest version, its url and sha256" \
  "{\"version\":\"2.42304.0\",\"url\":\"file://$fixtures/claude/pool/main/c/claude-desktop/claude-desktop_2.42304.0_amd64.deb\",\"sha256\":\"2222222222222222222222222222222222222222222222222222222222222222\"}" \
  "$(normalise "$root/packages/claude-desktop/source.json")"
check "chatgpt: single stanza pinned" \
  "{\"version\":\"26.1013.40934\",\"url\":\"file://$fixtures/chatgpt/pool/main/c/chatgpt/chatgpt_26.1013.40934_amd64.deb\",\"sha256\":\"3ca59e7f9a6641b9e2fb9ad680683784b5ab8026ff7418fb212a0ebe5df3a1d7\"}" \
  "$(normalise "$root/packages/chatgpt-desktop/source.json")"

# 2. Second run: reports up to date and does not rewrite the files.
before=$(stat -c %Y.%N "$root"/packages/*/source.json | md5sum)
sleep 1.1
out=$(run "$root")
check "second run: claude up to date" "1" "$(grep -c '^claude-desktop: up to date$' <<< "$out")"
check "second run: chatgpt up to date" "1" "$(grep -c '^chatgpt-desktop: up to date$' <<< "$out")"
check "second run: files untouched" "$before" "$(stat -c %Y.%N "$root"/packages/*/source.json | md5sum)"

# 3. An unreachable repo fails loudly and leaves the existing pin alone.
cp "$root/packages/claude-desktop/source.json" "$root/claude.bak"
if run "$root" CLAUDE_REPO=file:///nonexistent > /dev/null; then rc=0; else rc=1; fi
check "unreachable repo: non-zero exit" "1" "$rc"
check "unreachable repo: pin untouched" "$(normalise "$root/claude.bak")" "$(normalise "$root/packages/claude-desktop/source.json")"

# 4. A bump is reported as old -> new.
printf '{"version":"2.37337.1","url":"x","sha256":"y"}\n' > "$root/packages/claude-desktop/source.json"
out=$(run "$root")
check "bump reported" "1" "$(grep -c '^claude-desktop: 2.37337.1 -> 2.42304.0$' <<< "$out")"

echo
if [ "$fails" -ne 0 ]; then echo "$fails failed"; exit 1; fi
echo "all passed"
