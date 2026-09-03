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
#   * NO commit/tag signing. GPG signing can't run non-interactively — it
#     blocks on a pinentry prompt — so `signByDefault` fought every remote /
#     agent-driven commit (the graphical popup that started all this). Sign
#     deliberately with `git commit -S` if you ever need to; no key is wired
#     up by default.
#
# Mirrors the devbox guest's system-level /etc/gitconfig (common/devbox/
# guest.nix) so the policy is identical whether you're on a host or in the VM.
{ pkgs, ... }:
{
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

      # HTTPS-via-gh for GitHub + gists.
      credential = {
        "https://github.com".helper = "!${pkgs.gh}/bin/gh auth git-credential";
        "https://gist.github.com".helper = "!${pkgs.gh}/bin/gh auth git-credential";
      };

      # Route SSH-style GitHub remotes through HTTPS so they authenticate via
      # gh instead of an ssh key. Covers `git@github.com:owner/repo` and
      # `ssh://git@github.com/owner/repo`.
      url."https://github.com/" = {
        insteadOf = [
          "git@github.com:"
          "ssh://git@github.com/"
        ];
      };
    };
  };
}
