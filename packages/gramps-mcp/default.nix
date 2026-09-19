{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  python3,
  makeWrapper,
}:

let
  # Runtime dependencies from upstream's pyproject.toml `[project].dependencies`.
  # All of them exist in nixpkgs at versions satisfying the lower bounds, so
  # there's no need to vendor uv.lock.
  pythonEnv = python3.withPackages (
    ps: with ps; [
      fastapi
      httpx
      markdownify
      mcp
      pydantic
      pyjwt
      python-dotenv
      uvicorn
    ]
  );
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "gramps-mcp";
  version = "1.1.0";

  src = fetchFromGitHub {
    owner = "cabout-me";
    repo = "gramps-mcp";
    tag = "v${finalAttrs.version}";
    hash = "sha256-7dj8Ol4MBkDFOhUXXM8tctWHrmDVGVQg/jEkRBFFLyA=";
  };

  # Upstream bug: create_family accepts child_handles, reports success and
  # drops it. The request body is a plain model_dump of FamilySaveParams, and
  # Gramps stores children as child_ref_list, so the family half of every
  # parent/child link was silently discarded - family views showed no children
  # and ancestor/descendant traversal stopped there.
  # Reported upstream: https://github.com/cabout-me/gramps-mcp
  patches = [ ./child-ref-list.patch ];

  nativeBuildInputs = [ makeWrapper ];

  dontConfigure = true;
  dontBuild = true;

  # Upstream's pyproject.toml declares no build backend and no console script —
  # the published Docker image just runs `python -m src.gramps_mcp.server` out
  # of a checkout. So install the package tree directly and supply the entry
  # point here. Every runtime import inside src/gramps_mcp is relative, so it
  # works as a plain top-level `gramps_mcp` package; only the tests use the
  # `src.gramps_mcp.*` prefix. The .md files under resources/ are read relative
  # to __file__ at runtime, so they have to come along with the code.
  installPhase = ''
    runHook preInstall

    mkdir -p "$out/${python3.sitePackages}"
    cp -r src/gramps_mcp "$out/${python3.sitePackages}/"

    makeWrapper ${pythonEnv}/bin/python "$out/bin/gramps-mcp" \
      --add-flags "-m gramps_mcp.server" \
      --prefix PYTHONPATH : "$out/${python3.sitePackages}"

    runHook postInstall
  '';

  meta = {
    description = "MCP server for AI-assisted genealogy research against the Gramps Web API";
    longDescription = ''
      Exposes the Gramps Web API as MCP tools (people, families, events,
      sources, citations, places, notes and media) so an assistant can search
      and edit a family tree. It is a REST client: it needs the URL and
      credentials of a running Gramps Web instance, supplied through
      GRAMPS_API_URL, GRAMPS_USERNAME, GRAMPS_PASSWORD and GRAMPS_TREE_ID (a
      .env file in the working directory is also read). Run `gramps-mcp stdio`
      for an MCP client that speaks stdio; with no argument it serves
      streamable HTTP on port 8000.
    '';
    homepage = "https://github.com/cabout-me/gramps-mcp";
    license = lib.licenses.agpl3Only;
    mainProgram = "gramps-mcp";
    platforms = lib.platforms.all;
  };
})
