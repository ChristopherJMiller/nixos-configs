{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  nodejs,
  sqlite,
  makeWrapper,
}:

buildNpmPackage rec {
  pname = "fastmail-mcp";
  version = "1.7.1";

  src = fetchFromGitHub {
    owner = "ChristopherJMiller";
    repo = "fastmail-mcp";
    rev = "3130aea";
    hash = "sha256-m9TFtT3/arssWuA/SGVOnIL5p+DHvPJuLyAbUPthjvE=";
  };

  npmDepsHash = "sha256-ePsmQRprbivPTAhD6AOtPLGlD8bOuMgC5OJ3J034fo4=";

  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    wrapProgram $out/bin/fastmail-mcp \
      --prefix PATH : ${lib.makeBinPath [ nodejs sqlite ]}
  '';

  meta = {
    description = "MCP server for Fastmail API integration";
    homepage = "https://github.com/ChristopherJMiller/fastmail-mcp";
    license = lib.licenses.mit;
    mainProgram = "fastmail-mcp";
    platforms = lib.platforms.all;
  };
}
