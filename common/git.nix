# common/git.nix
#
# Shared git config for the `chris` user across every desktop host
# (rowlett / celebi / wailmer). One place for the fleet-wide policy:
#
#   * GitHub auth is HTTPS via the `gh` CLI — no SSH keys, so nothing ever
#     pops an ssh-askpass dialog when you're driving a host remotely (or an
#     agent is). `url.insteadOf` transparently rewrites `git@github.com:`
#     remotes to https, so even SSH-cloned repos push through `gh`. Run
#     `gh auth login` once per machine; the token lives in the gh keyring.
#
#   * Forgejo (git.realliance.net, the main forge) works the same way via the
#     `fj` CLI (forgejo-cli). Run `fj auth login` once per machine — browser
#     OAuth through the realliance "forgejo-cli (fj)" app, whose client ID fj
#     reads from ~/.config/forgejo-cli/client_ids — and git rides on that
#     login through `fjCredential` below. FJ_FALLBACK_HOST points `fj` at
#     realliance outside a checkout (inside one, fj follows the remote).
#
#   * NO commit/tag signing. GPG signing can't run non-interactively — it
#     blocks on a pinentry prompt — so `signByDefault` fought every remote /
#     agent-driven commit (the graphical popup that started all this). Sign
#     deliberately with `git commit -S` if you ever need to; no key is wired
#     up by default.
#
# Mirrors the devbox guest's system-level /etc/gitconfig (common/devbox/
# guest.nix) so the policy is identical whether you're on a host or in the VM.
{ pkgs, ... }:
let
  forgejoHost = "git.realliance.net";
  # Public PKCE client registered on realliance for fj — no secret, safe to
  # commit. fj only ships client IDs for a handful of big instances.
  fjClientId = "41ec7227-eca9-435c-a904-1785bcae60b9";

  # git credential helper backed by fj's login, like `gh auth git-credential`
  # is backed by gh's (fj has no such subcommand). fj keeps the token in
  # keys.json, but an OAuth access token expires hourly and fj only refreshes
  # it when it runs — so poke `fj whoami` first (a no-op while the token is
  # fresh, otherwise a silent refresh + save), then hand git the token.
  # Forgejo ignores the username when the password is a token.
  fjCredential = pkgs.writeShellScript "git-credential-fj" ''
    cat >/dev/null
    [ "$1" = get ] || exit 0
    ${pkgs.forgejo-cli}/bin/fj -C / -H https://${forgejoHost} whoami >/dev/null 2>&1
    keys="''${XDG_DATA_HOME:-$HOME/.local/share}/forgejo-cli/keys.json"
    token=$(${pkgs.jq}/bin/jq -r '.hosts["${forgejoHost}"].token // empty' "$keys" 2>/dev/null)
    [ -n "$token" ] || exit 0
    printf 'username=fj\npassword=%s\n' "$token"
  '';
in
{
  home.packages = [ pkgs.forgejo-cli ];
  home.sessionVariables.FJ_FALLBACK_HOST = "https://${forgejoHost}";
  xdg.configFile."forgejo-cli/client_ids".text = ''
    ${forgejoHost} ${fjClientId}
  '';

  programs.git = {
    enable = true;
    lfs.enable = true;
    settings = {
      user.name = "Christopher Miller";
      user.email = "git@chrismiller.xyz";
      init.defaultBranch = "main";
      push.autoSetupRemote = true;

      # No signing — see header.
      commit.gpgsign = false;
      tag.gpgSign = false;

      # HTTPS-via-gh for GitHub + gists, HTTPS-via-fj for Forgejo.
      credential = {
        "https://github.com".helper = "!${pkgs.gh}/bin/gh auth git-credential";
        "https://gist.github.com".helper = "!${pkgs.gh}/bin/gh auth git-credential";
        "https://${forgejoHost}".helper = "${fjCredential}";
      };

      # Route SSH-style remotes through HTTPS so they authenticate via gh / fj
      # instead of an ssh key. Covers `git@host:owner/repo` and
      # `ssh://git@host/owner/repo`.
      url."https://github.com/" = {
        insteadOf = [
          "git@github.com:"
          "ssh://git@github.com/"
        ];
      };
      url."https://${forgejoHost}/" = {
        insteadOf = [
          "git@${forgejoHost}:"
          "ssh://git@${forgejoHost}/"
        ];
      };
    };
  };
}
