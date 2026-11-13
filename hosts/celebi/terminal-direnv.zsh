# Replace the standard hook's presentation, retaining its hook registration
# and direnv's environment diff. This function runs inside $(...) so only
# exported shell code goes to stdout; the loading indicator uses stderr.
_celebi_direnv_export() {
  emulate -L zsh
  setopt localtraps
  unsetopt monitor notify

  if [[ ! -t 2 || $TERM == dumb ]]; then
    "$_CELEBI_DIRENV_BIN" export zsh
    return
  fi

  local log_file spinner_pid
  local -i export_status=0
  log_file=$(mktemp "${TMPDIR:-/tmp}/celebi-direnv.XXXXXXXX") || {
    "$_CELEBI_DIRENV_BIN" export zsh
    return
  }
  zmodload zsh/zselect

  # An EXIT trap also runs when Ctrl+C interrupts the command substitution.
  # Only stderr is buffered: exported values never go into the log file.
  _celebi_direnv_cleanup() {
    if [[ -n $spinner_pid ]]; then
      kill "$spinner_pid" 2>/dev/null
      wait "$spinner_pid" 2>/dev/null
      spinner_pid=
    fi
    # direnv can return success while reporting a rejected/broken .envrc.
    # Preserve diagnostics regardless of its exit status, after clearing
    # the spinner so they cannot be overwritten.
    [[ ! -s $log_file ]] || cat -- "$log_file" >&2
    [[ -z $log_file ]] || rm -f -- "$log_file"
    log_file=
  }
  trap '_celebi_direnv_cleanup' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  trap 'exit 129' HUP

  (
    trap - EXIT
    local -i drawn=0
    local frame
    trap '(( drawn )) && printf "\r\033[2K" >&2; exit 0' TERM INT HUP
    # Cached loads usually finish before this, avoiding a flash on each
    # prompt. zselect is a builtin, so cancellation needs no child sleep.
    zselect -t 15
    while true; do
      for frame in ⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏; do
        drawn=1
        printf '\r\033[38;2;198;160;246m%s\033[0m Loading environment…' "$frame" >&2
        zselect -t 8
      done
    done
  ) &
  spinner_pid=$!

  {
    "$_CELEBI_DIRENV_BIN" export zsh 2>"$log_file"
    export_status=$?
  } always {
    _celebi_direnv_cleanup
  }
  return $export_status
}

_direnv_hook() {
  local -i previous_status=$?
  local env_delta
  if env_delta="$(_celebi_direnv_export)"; then
    eval "$env_delta"
  fi
  return $previous_status
}
