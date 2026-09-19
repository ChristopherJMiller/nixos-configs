# Run the Gramps MCP server over stdio against a local Gramps Web instance,
# starting that instance on demand and letting it go when the last client exits.
#
# Lifetime is handled by systemd reference counting rather than by this script
# stopping anything itself. We re-exec inside a transient scope that declares
# Requires= and After= on the Gramps Web unit, so:
#   * starting the scope pulls the unit in and waits for it, and the unit is
#     only "started" once its ExecStartPost confirms the API answers - that is
#     the readiness guarantee, with no polling here;
#   * when this process exits the scope disappears, and because the unit is
#     StopWhenUnneeded it is stopped as soon as nothing references it.
# Two MCP clients at once therefore share one container, and the container only
# goes away when both have exited.

set -euo pipefail

# An MCP client may launch us with a reduced environment. systemd-run needs a
# route to the user bus, and XDG_RUNTIME_DIR alone is enough; without it and
# without DBUS_SESSION_BUS_ADDRESS it fails with "Failed to connect to user
# scope bus".
: "${XDG_RUNTIME_DIR:=/run/user/$(id -u)}"
export XDG_RUNTIME_DIR

UNIT="${GRAMPS_WEB_LOCAL_UNIT:-gramps-web.service}"
STATE_DIR="${GRAMPS_WEB_LOCAL_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/gramps-web-local}"

if [ -z "${GRAMPS_MCP_LOCAL_IN_SCOPE:-}" ]; then
  export GRAMPS_MCP_LOCAL_IN_SCOPE=1
  exec systemd-run --user --quiet --collect --scope \
    -p "Requires=$UNIT" -p "After=$UNIT" \
    -- "$0" "$@"
fi

# Inside the scope: the unit has finished activating, so the state files the
# server writes during startup are present.
for f in api-password tree-id; do
  [ -s "$STATE_DIR/$f" ] || {
    printf 'gramps-mcp-local: error: missing %s/%s\n' "$STATE_DIR" "$f" >&2
    printf 'gramps-mcp-local: see: systemctl --user status %s\n' "$UNIT" >&2
    exit 1
  }
done

GRAMPS_API_URL="http://127.0.0.1:${GRAMPS_WEB_LOCAL_PORT:-5555}"
GRAMPS_USERNAME="${GRAMPS_WEB_LOCAL_USER:-mcp}"
GRAMPS_PASSWORD="$(cat "$STATE_DIR/api-password")"
GRAMPS_TREE_ID="$(cat "$STATE_DIR/tree-id")"
export GRAMPS_API_URL GRAMPS_USERNAME GRAMPS_PASSWORD GRAMPS_TREE_ID

if [ "$#" -eq 0 ]; then set -- stdio; fi
exec gramps-mcp "$@"
