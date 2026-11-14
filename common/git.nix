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
#     `fj` CLI (forgejo-cli). Run `fj auth login` once per machine and git
#     rides on that login. The fj side (client ID, credential helper,
#     FJ_FALLBACK_HOST) lives in ./forgejo.nix, shared with the devbox.
#
#   * NO commit/tag signing. GPG signing can't run non-interactively — it
#     blocks on a pinentry prompt — so `signByDefault` fought every remote /
#     agent-driven commit (the graphical popup that started all this). Sign
#     deliberately with `git commit -S` if you ever need to; no key is wired
#     up by default.
#
# Mirrors the devbox guest's system-level /etc/gitconfig (common/devbox/
# guest.nix), with one exception: the devbox DOES sign every commit. Its
# gpg-agent keeps the key unlocked for 48 h and times pinentry out after 60 s,
# so a locked key fails a commit rather than hanging it.
{ pkgs, ... }:
let
  forgejo = import ./forgejo.nix;
  forgejoHost = forgejo.host;
in
{
  imports = [ forgejo.homeModule ];

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
        "https://${forgejoHost}".helper = "${forgejo.credentialHelper pkgs}";
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
