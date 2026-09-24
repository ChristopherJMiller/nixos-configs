# Genealogy research toolchain — Gramps plus the pieces a real research
# workflow needs around it. Shared by celebi and rowlett.
#
# Usage from a host's home.nix:
#   genealogy = import ../../common/genealogy.nix { inherit pkgs; };
#   home.packages = ... ++ genealogy.packages;
{ pkgs, ... }:

let
  inherit (pkgs) lib;

  # Prerequisites for the popular third-party Gramps addons. Gramps runs under
  # a wrapped interpreter with PYTHONNOUSERSITE set, so installing these into
  # the user profile would NOT make them importable — they have to be injected
  # into Gramps' own environment (below).
  #
  #   pillow     — Family Sheet
  #   networkx   — Network Chart
  #   pygraphviz — Network Chart
  #   numpy      — PedigreeChart (optional; enables the nicer layout)
  #
  # Graph View needs the GooCanvas typelib rather than a Python package: the
  # addon imports gi.repository.GooCanvas, so goocanvas2 has to be on
  # GI_TYPELIB_PATH. (python-pygoocanvas is the old GTK2 binding and is not
  # what current Gramps uses.)
  addonPython = pkgs.python3.withPackages (
    ps: with ps; [
      pillow
      networkx
      pygraphviz
      numpy
    ]
  );

  # Gramps itself already builds against graphviz, but its wrapper does not put
  # `dot` on PATH, so the built-in Graphviz reports and the Network Chart addon
  # would fail to find it. Wrap rather than override so the binary-cached
  # gramps build is reused instead of recompiling it from source on every
  # nixpkgs bump. The .desktop file uses `Exec=gramps %F` (no store path), so
  # the launcher picks up this wrapper from the profile too.
  gramps = pkgs.symlinkJoin {
    name = "gramps-${pkgs.gramps.version}-with-addon-support";
    paths = [ pkgs.gramps ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/gramps \
        --prefix PYTHONPATH : "${addonPython}/${pkgs.python3.sitePackages}" \
        --prefix GI_TYPELIB_PATH : "${pkgs.goocanvas_2}/lib/girepository-1.0" \
        --prefix PATH : "${lib.makeBinPath [ pkgs.graphviz ]}"
    '';
    inherit (pkgs.gramps) meta;
  };

  # MCP server that drives a Gramps Web instance over its REST API. Needs a
  # running Gramps Web server plus GRAMPS_API_URL / GRAMPS_USERNAME /
  # GRAMPS_PASSWORD / GRAMPS_TREE_ID; it does not talk to the desktop database.
  gramps-mcp = pkgs.callPackage ../packages/gramps-mcp { };

  # Boots Gramps Web in a container against the desktop database and fronts it
  # with the MCP server. Packaged as a container because gramps-webapi needs
  # seven Python packages that are not in nixpkgs and pins PyGObject below the
  # version nixpkgs ships. Readiness is systemd's job, not a polling loop:
  # see grampsWebService below.
  gramps-web-local = pkgs.callPackage ../packages/gramps-web-local {
    inherit gramps gramps-mcp;
  };
in
{
  inherit gramps gramps-mcp gramps-web-local;

  packages = [
    gramps
    gramps-mcp
    gramps-web-local

    # Renders the Graphviz-based Gramps reports (descendant/hourglass/family
    # lines) and any .gv the tree is exported to.
    pkgs.graphviz

    # Terminal GEDCOM database and reporting tool. Handy as a second opinion
    # when checking a GEDCOM that Gramps imported oddly, and for scripting
    # over a tree without opening the GUI.
    pkgs.lifelines

    # Source documents: genealogy is mostly scanned certificates, censuses and
    # parish registers, so digitising and making them searchable matters as
    # much as the tree software.
    pkgs.simple-scan # scanner front-end (SANE)
    pkgs.tesseract # OCR engine, all language data (old records are rarely in English)
    pkgs.ocrmypdf # add a searchable text layer to scanned PDFs
    pkgs.pdfarranger # reorder, merge and split multi-page scans
    pkgs.img2pdf # losslessly wrap scans into a PDF
    pkgs.exiftool # read/write capture metadata on scans and family photos

    # Gramps 6 keeps each tree in SQLite; useful for ad-hoc queries and for
    # checking a database that will not open.
    pkgs.sqlite
  ];

  # systemd user unit for the Gramps Web side. Nix itself cannot start a
  # container - builds are sandboxed with no daemon and no network - so
  # container readiness is delegated to systemd. ExecStartPost blocks until the
  # REST API actually answers and the API user exists, so
  # `systemctl --user start gramps-web` returns only once the service is
  # genuinely usable. Wire it up in a host with:
  #   systemd.user.services.gramps-web = genealogy.grampsWebService;
  # Deliberately not WantedBy anything: gramps-mcp-local pulls it in on demand
  # and systemd drops it again when nothing references it, so nothing is left
  # running in the background between sessions. `gramps-web-local hold` keeps
  # it up on purpose for browsing the web UI.
  grampsWebService = {
    Unit = {
      Description = "Gramps Web serving the local Gramps desktop database";
      Documentation = "https://www.grampsweb.org/";
      # Rootless Docker runs as a user service on both hosts.
      Requires = [ "docker.service" ];
      After = [ "docker.service" ];
      # gramps-mcp-local runs inside a transient scope that requires this unit,
      # so the container is torn down as soon as the last MCP client exits.
      # Eight gunicorn workers would sit on 1.3 GiB; the script asks for two.
      StopWhenUnneeded = true;
    };
    Service = {
      Type = "exec";
      ExecStart = "${gramps-web-local}/bin/gramps-web-local run";
      ExecStartPost = "${gramps-web-local}/bin/gramps-web-local wait";
      # `docker stop` kills the container, so the docker client exits 137/143.
      # Without this every ordinary stop would leave the unit "failed".
      SuccessExitStatus = "137 143";
      # The image entrypoint is not exec-ed, so the container needs stopping
      # directly rather than by signalling the docker client.
      ExecStop = "${gramps-web-local}/bin/gramps-web-local stop";
      # Clears a leftover container if a run died badly.
      ExecStopPost = "${gramps-web-local}/bin/gramps-web-local cleanup";
      # A first start may pull a 4.5 GB image and rebuild the search index.
      TimeoutStartSec = 900;
      TimeoutStopSec = 60;
      Restart = "no";
    };
  };
}
