{ elm-review-tool, pkgs }:
let
  liveDev = pkgs.writeScriptBin "livedev" ''
    cd "$(git rev-parse --show-toplevel)"
    elm-live app/Main.elm -d dist -Hu -- --output="dist/Main.js"
  '';
in pkgs.mkShell {
  name = "tulars";

  buildInputs = with pkgs; [
    elm-review-tool
    elmPackages.elm
    elmPackages.elm-format
    elmPackages.elm-json
    elmPackages.elm-live
    elmPackages.elm-test
    cypress
    just # for discoverable project-specific commands. Simpler than Make, plus Nix already handles the build system.
    liveDev
    nixfmt-classic
  ];

  shellHook = ''
    export CYPRESS_INSTALL_BINARY=0
    export CYPRESS_RUN_BINARY=${pkgs.cypress}/bin/Cypress

    if [ "''${TULARS_DEV_SHELL:-x}" == "entered" ]; then
      exit 0
    fi
    echo ""
    echo "This is the dev shell for the Tulars project."
    just --list --list-heading $'Run \'just\' to see the available commands:\n'
    echo ""

    export TULARS_DEV_SHELL="entered"
  '';
}
