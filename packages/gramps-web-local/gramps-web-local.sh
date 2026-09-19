# Run a private Gramps Web instance against the local Gramps DESKTOP database,
# so tools speaking the Gramps Web REST API - notably gramps-mcp - can work on
# the same tree you edit in the desktop app.
#
# Why a container: gramps-webapi needs seven Python packages that are not in
# nixpkgs and pins PyGObject below the version nixpkgs ships, so the upstream
# image is the realistic way to run it. Nix cannot start a container at build
# time either, since the build sandbox has no daemon and no network. Readiness
# is therefore systemd's job: `run` is the unit's ExecStart and `wait` is its
# ExecStartPost, so `systemctl --user start gramps-web` returns only once the
# REST API actually answers and the API user exists.
#
# SAFETY - read this before trusting the setup with a real tree.
# Upstream does not support pointing Gramps Web at a live desktop database; the
# sanctioned route is two databases kept in step by the Gramps Web Sync addon.
# The lock file cannot be used to make the two mutually exclusive, because
# Gramps opens and closes the database on every API request and its close()
# calls clear_lock_file() unconditionally - so Gramps Web deletes any lock
# present, including one the desktop wrote. What this script does instead:
#   * refuses to start while the desktop holds the tree, which catches the
#     common case;
#   * leaves IGNORE_DB_LOCK off, so Gramps Web still refuses writes whenever it
#     does observe a desktop lock, which is the only built-in protection;
#   * takes a Gramps XML backup before every start, because the residual risk
#     is real and a backup is the honest mitigation.
# Keep the desktop app closed while this service is running.

set -euo pipefail

IMAGE="${GRAMPS_WEB_LOCAL_IMAGE:-ghcr.io/gramps-project/grampsweb:latest}"
CONTAINER="${GRAMPS_WEB_LOCAL_CONTAINER:-gramps-web-local}"
PORT="${GRAMPS_WEB_LOCAL_PORT:-5555}"
DB_DIR="${GRAMPS_DB_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/gramps/grampsdb}"
STATE_DIR="${GRAMPS_WEB_LOCAL_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/gramps-web-local}"
MEDIA_DIR="${GRAMPS_MEDIA_DIR:-}"
API_USER="${GRAMPS_WEB_LOCAL_USER:-mcp}"
UNIT="${GRAMPS_WEB_LOCAL_UNIT:-gramps-web.service}"
BASE_URL="http://127.0.0.1:$PORT"
BACKUP_KEEP=5

log() { printf 'gramps-web-local: %s\n' "$*" >&2; }
die() {
  log "error: $*"
  exit 1
}

usage() {
  cat <<'USAGE'
Usage: gramps-web-local <command>

  run        Run the Gramps Web container in the foreground (unit ExecStart).
  wait       Block until the API answers, then ensure the API user and search
             index are in place (unit ExecStartPost).
  stop       Stop the container (unit ExecStop).
  cleanup    Remove a leftover container (unit ExecStopPost).
  reindex    Rebuild the full-text search index from scratch.
  hold       Keep the server up for browsing the web UI; Ctrl-C to release.
  backup     Take a Gramps XML backup of the tree right now.
  env        Print the environment a Gramps Web API client needs.
  info       Show URL, tree and status.

Environment:
  GRAMPS_TREE_ID                 tree directory name; auto-detected if only one
  GRAMPS_DB_DIR                  default ~/.local/share/gramps/grampsdb
  GRAMPS_MEDIA_DIR               media folder to expose to the server
  GRAMPS_WEB_LOCAL_PORT          default 5555, bound to localhost only
  GRAMPS_WEB_LOCAL_IMAGE         default ghcr.io/gramps-project/grampsweb:latest
  GRAMPS_WEB_LOCAL_SKIP_BACKUP=1          skip the pre-start backup
  GRAMPS_WEB_LOCAL_SKIP_VERSION_CHECK=1   skip the Gramps version guard
USAGE
}

# Rootless Docker exports DOCKER_HOST from the login shell, but a systemd user
# unit does not inherit it, so fall back to the per-user socket.
docker_host_default() {
  local runtime="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
  if [ -z "${DOCKER_HOST:-}" ] && [ -S "$runtime/docker.sock" ]; then
    DOCKER_HOST="unix://$runtime/docker.sock"
    export DOCKER_HOST
  fi
}

require_runtime() {
  command -v docker >/dev/null 2>&1 ||
    die "docker not found on PATH - this host needs virtualisation.docker enabled"
  docker_host_default
}

resolve_tree() {
  [ -d "$DB_DIR" ] || die "no Gramps database directory at $DB_DIR"
  if [ -n "${GRAMPS_TREE_ID:-}" ]; then
    printf '%s' "$GRAMPS_TREE_ID"
    return
  fi
  local found=() d
  for d in "$DB_DIR"/*; do
    [ -f "$d/sqlite.db" ] && found+=("$(basename "$d")")
  done
  case "${#found[@]}" in
    0) die "no family trees in $DB_DIR - create one in Gramps first" ;;
    1) printf '%s' "${found[0]}" ;;
    *)
      log "several family trees found; set GRAMPS_TREE_ID to one of:"
      for d in "${found[@]}"; do
        log "  $d  ($(cat "$DB_DIR/$d/name.txt" 2>/dev/null || echo 'unnamed'))"
      done
      exit 1
      ;;
  esac
}

state_init() {
  mkdir -p "$STATE_DIR/users" "$STATE_DIR/indexdir" "$STATE_DIR/secret"
  chmod 700 "$STATE_DIR"
  if [ ! -s "$STATE_DIR/api-password" ]; then
    (
      umask 077
      head -c 24 /dev/urandom | base64 | tr -d '\n=' >"$STATE_DIR/api-password"
    )
  fi
}

# Opening a tree with a different Gramps series can silently upgrade its schema
# and leave the desktop app unable to read it, so refuse to run on a mismatch.
version_check() {
  [ "${GRAMPS_WEB_LOCAL_SKIP_VERSION_CHECK:-0}" = "1" ] && return 0
  local desktop container
  desktop=$(gramps -v 2>/dev/null |
    sed -n 's/^[[:space:]]*gramps[[:space:]]*:[[:space:]]*\([0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' |
    head -1)
  container=$(docker run --rm --entrypoint python3 "$IMAGE" \
    -c 'from gramps.version import major_version; print(major_version)' 2>/dev/null |
    tr -d '\r\n')
  if [ -z "$desktop" ] || [ -z "$container" ]; then
    log "warning: could not compare desktop and container Gramps versions"
    return 0
  fi
  [ "$desktop" = "$container" ] && return 0
  die "Gramps version mismatch: desktop $desktop, container $container.
  Opening the tree with a different series can upgrade its schema and make it
  unreadable by the desktop app. Pin GRAMPS_WEB_LOCAL_IMAGE to a matching tag,
  or set GRAMPS_WEB_LOCAL_SKIP_VERSION_CHECK=1 if you know it is safe."
}

assert_not_locked() {
  local lock="$DB_DIR/$1/lock"
  [ -e "$lock" ] || return 0
  die "this tree is open in Gramps desktop (locked by $(cat "$lock" 2>/dev/null)).
  Close it there first: the desktop app and Gramps Web must not both have the
  tree open, and the lock file cannot enforce that once the server is running."
}

# The desktop CLI finds trees through Gramps' own database.path setting, so a
# non-default GRAMPS_DB_DIR has to be expressed as a GRAMPSHOME.
gramps_cli() {
  local default_db="${XDG_DATA_HOME:-$HOME/.local/share}/gramps/grampsdb"
  if [ "$DB_DIR" = "$default_db" ]; then
    gramps "$@"
    return
  fi
  case "$DB_DIR" in
    */gramps/grampsdb) GRAMPSHOME="$(dirname "$(dirname "$DB_DIR")")" gramps "$@" ;;
    *) return 1 ;;
  esac
}

backup_tree() {
  [ "${GRAMPS_WEB_LOCAL_SKIP_BACKUP:-0}" = "1" ] && return 0
  local tree="$1" dir="$STATE_DIR/backups" stamp out name
  stamp=$(date +%Y%m%d-%H%M%S)
  out="$dir/$tree-$stamp.gramps"
  mkdir -p "$dir"
  # `gramps -O` resolves a tree by its display name, not its directory name.
  name=$(cat "$DB_DIR/$tree/name.txt" 2>/dev/null || true)
  [ -n "$name" ] || name="$tree"
  if gramps_cli -O "$name" -e "$out" --yes -q >/dev/null 2>&1 && [ -s "$out" ]; then
    log "pre-start backup: $out"
    find "$dir" -maxdepth 1 -name "$tree-*.gramps" -printf '%T@ %p\n' 2>/dev/null |
      sort -rn | tail -n "+$((BACKUP_KEEP + 1))" | cut -d' ' -f2- |
      while read -r old; do rm -f "$old"; done
  else
    rm -f "$out"
    log "warning: could not take a pre-start backup - continuing without one"
  fi
}

api_token() {
  curl -fsS -X POST "$BASE_URL/api/token/" \
    -H 'Content-Type: application/json' \
    -d "$(printf '{"username":"%s","password":"%s"}' "$API_USER" "$(cat "$STATE_DIR/api-password")")" \
    2>/dev/null
}

# The container entrypoint generates the Flask secret and exports it only into
# the server process, so a bare `docker exec` fails with "SECRET_KEY must be
# specified". Feed it back from the volume the entrypoint persisted it to.
webapi() {
  local secret=""
  [ -s "$STATE_DIR/secret/secret" ] && secret=$(cat "$STATE_DIR/secret/secret")
  docker exec -e "GRAMPSWEB_SECRET_KEY=$secret" \
    "$CONTAINER" python3 -m gramps_webapi \
    --config /app/config/config.cfg "$@"
}

ensure_user() {
  api_token >/dev/null 2>&1 && return 0
  log "creating API user '$API_USER'"
  webapi user add "$API_USER" "$(cat "$STATE_DIR/api-password")" \
    --fullname "Gramps MCP" --role 4 >/dev/null || log "user add failed"
  api_token >/dev/null 2>&1 ||
    die "could not authenticate against Gramps Web as '$API_USER'"
}

cmd_run() {
  require_runtime
  local tree
  tree=$(resolve_tree)
  version_check
  state_init
  assert_not_locked "$tree"
  backup_tree "$tree"
  printf '%s' "$tree" >"$STATE_DIR/tree-id"
  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true

  local args=(
    run --rm --name "$CONTAINER"
    -p "127.0.0.1:$PORT:5000"
    -v "$DB_DIR/$tree:/root/.gramps/grampsdb/$tree"
    -v "$STATE_DIR/users:/app/users"
    -v "$STATE_DIR/indexdir:/app/indexdir"
    -v "$STATE_DIR/secret:/app/secret"
    -e "GRAMPSWEB_TREE=$tree"
    -e "GRAMPSWEB_TREE_ID=$tree"
    # Eight workers is the image default and costs ~1.3 GiB resident. Two is
    # ample for a single local user and holds ~350 MiB.
    -e "GUNICORN_NUM_WORKERS=${GRAMPS_WEB_LOCAL_WORKERS:-2}"
  )
  [ -n "$MEDIA_DIR" ] && args+=(-v "$MEDIA_DIR:/app/media")
  exec docker "${args[@]}" "$IMAGE"
}

cmd_wait() {
  require_runtime
  local i
  for i in $(seq 1 120); do
    curl -fsS -o /dev/null "$BASE_URL/" 2>/dev/null && break
    [ "$i" -eq 120 ] && die "Gramps Web did not become ready within 120s"
    sleep 1
  done
  ensure_user
  # The desktop app writes straight to SQLite, bypassing the API, so the search
  # index does not see those edits until it is told to catch up.
  webapi search index-incremental >/dev/null 2>&1 ||
    log "warning: search index update failed; try 'gramps-web-local reindex'"
  log "ready at $BASE_URL (tree $(cat "$STATE_DIR/tree-id" 2>/dev/null || echo '?'))"
  log "keep Gramps desktop closed while this is running"
}

# The image entrypoint is not exec-ed, so PID 1 is a shell that does not forward
# SIGTERM to gunicorn; stopping the container directly is what actually works.
cmd_stop() {
  docker_host_default
  docker stop -t 15 "$CONTAINER" >/dev/null 2>&1 || true
}

cmd_cleanup() {
  docker_host_default
  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
}

cmd_reindex() {
  require_runtime
  webapi search index-full
}

cmd_backup() {
  state_init
  backup_tree "$(resolve_tree)"
}

# The service is StopWhenUnneeded, so it only lives while some unit requires
# it. This parks a scope that requires it, to keep the web UI reachable in a
# browser without an MCP session open. Ctrl-C releases it.
cmd_hold() {
  exec systemd-run --user --quiet --collect --scope \
    -p "Requires=$UNIT" -p "After=$UNIT" -- sleep infinity
}

cmd_env() {
  printf 'export GRAMPS_API_URL=%s\n' "$BASE_URL"
  printf 'export GRAMPS_USERNAME=%s\n' "$API_USER"
  printf 'export GRAMPS_PASSWORD=%s\n' "$(cat "$STATE_DIR/api-password")"
  printf 'export GRAMPS_TREE_ID=%s\n' "$(cat "$STATE_DIR/tree-id")"
}

cmd_info() {
  docker_host_default
  local tree status
  tree=$(cat "$STATE_DIR/tree-id" 2>/dev/null || echo 'not started')
  status=$(docker ps --filter "name=^${CONTAINER}\$" --format '{{.Status}}' 2>/dev/null || true)
  printf 'url:    %s\n' "$BASE_URL"
  printf 'tree:   %s\n' "$tree"
  printf 'user:   %s\n' "$API_USER"
  printf 'status: %s\n' "${status:-stopped}"
}

case "${1:-}" in
  run) cmd_run ;;
  wait) cmd_wait ;;
  stop) cmd_stop ;;
  cleanup) cmd_cleanup ;;
  reindex) cmd_reindex ;;
  backup) cmd_backup ;;
  hold) cmd_hold ;;
  env) cmd_env ;;
  info) cmd_info ;;
  -h | --help | help) usage ;;
  *)
    usage >&2
    exit 1
    ;;
esac
