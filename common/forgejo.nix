# common/forgejo.nix
#
# Forgejo (git.realliance.net, the main forge) via the `fj` CLI
# (forgejo-cli), shared by the hosts (./git.nix) and the devbox guest
# (./devbox/guest.nix + ./devbox/home.nix). A plain attrset, not a module,
# because the two sides wire git differently: the hosts through home-manager's
# programs.git, the devbox through a system-level /etc/gitconfig.
#
# Run `fj auth login` once per machine — browser OAuth through the realliance
# "forgejo-cli (fj)" app — and git rides on that login through
# `credentialHelper` below. Without `homeModule`'s client_ids file fj refuses
# with "Your installation of fj doesn't support `login` for git.realliance.net"
# (it only ships client IDs for a handful of big instances). Until the first
# login every fj command also prints "Could not find keys file. Creating a new
# file." — fj doesn't actually write keys.json until it has a login to save.
rec {
  host = "git.realliance.net";

  # Public PKCE client registered on realliance for fj — no secret, safe to
  # commit.
  clientId = "41ec7227-eca9-435c-a904-1785bcae60b9";

  # git credential helper backed by fj's login, like `gh auth git-credential`
  # is backed by gh's (fj has no such subcommand). fj keeps the token in
  # keys.json, but an OAuth access token expires hourly and fj only refreshes
  # it when it runs — so poke `fj whoami` first (a no-op while the token is
  # fresh, otherwise a silent refresh + save), then hand git the token.
  # Forgejo ignores the username when the password is a token.
  credentialHelper =
    pkgs:
    pkgs.writeShellScript "git-credential-fj" ''
      cat >/dev/null
      [ "$1" = get ] || exit 0
      ${pkgs.forgejo-cli}/bin/fj -C / -H https://${host} whoami >/dev/null 2>&1
      keys="''${XDG_DATA_HOME:-$HOME/.local/share}/forgejo-cli/keys.json"
      token=$(${pkgs.jq}/bin/jq -r '.hosts["${host}"].token // empty' "$keys" 2>/dev/null)
      [ -n "$token" ] || exit 0
      printf 'username=fj\npassword=%s\n' "$token"
    '';

  # home-manager side: the CLI, its client ID, and FJ_FALLBACK_HOST so `fj`
  # targets realliance outside a checkout (inside one, fj follows the remote).
  homeModule =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.forgejo-cli ];
      home.sessionVariables.FJ_FALLBACK_HOST = "https://${host}";
      xdg.configFile."forgejo-cli/client_ids".text = ''
        ${host} ${clientId}
      '';
    };
}
