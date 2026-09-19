# Glue that lets Gramps Web run against the local Gramps desktop database, and
# points the Gramps MCP server at it. See gramps-web-local.sh for the reasoning
# behind the container, the systemd readiness gate and the lock handling.
{
  lib,
  symlinkJoin,
  writeShellApplication,
  curl,
  coreutils,
  gnugrep,
  gnused,
  systemd,
  gramps,
  gramps-mcp,
}:

let
  gramps-web-local = writeShellApplication {
    name = "gramps-web-local";
    runtimeInputs = [
      curl
      coreutils
      gnugrep
      gnused
      systemd
      gramps
    ];
    text = builtins.readFile ./gramps-web-local.sh;
  };

  gramps-mcp-local = writeShellApplication {
    name = "gramps-mcp-local";
    runtimeInputs = [
      coreutils
      systemd
      gramps-mcp
    ];
    text = builtins.readFile ./gramps-mcp-local.sh;
  };
in
symlinkJoin {
  name = "gramps-web-local";
  paths = [
    gramps-web-local
    gramps-mcp-local
  ];

  passthru = { inherit gramps-web-local gramps-mcp-local; };

  meta = {
    description = "Run Gramps Web against the local Gramps desktop database, with an MCP front end";
    license = lib.licenses.mit;
    mainProgram = "gramps-mcp-local";
    platforms = lib.platforms.linux;
  };
}
