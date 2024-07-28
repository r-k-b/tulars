{ pkgs }:
let
  updateElmNixDeps = pkgs.writeScriptBin "update-elm-nix-deps" ''
    set -e
    cd "$(git rev-parse --show-toplevel)"
    echo working in "$(realpath $PWD)"

    echo creating registry snapshot at "$(realpath ./nix/elm/registry.dat)"
    elm2nix snapshot
    mv -f ./registry.dat ./nix/elm/registry.dat

    echo "Generating Nix expressions from elm.json..."
    elm2nix convert > ./nix/elm/elm-srcs.nix
    nixfmt ./nix/elm/elm-srcs.nix
    echo $(realpath ./nix/elm/elm-srcs.nix) has been updated.
  '';
  liveDev = pkgs.writeScriptBin "livedev" ''
    cd "$(git rev-parse --show-toplevel)"
    elm-live app/Main.elm -d dist -Hu -- --output="dist/Main.js"
  '';
in pkgs.mkShell {
  name = "tulars";

  buildInputs = with pkgs; [
    elm2nix
    elmPackages.elm
    elmPackages.elm-format
    elmPackages.elm-json
    elmPackages.elm-live
    elmPackages.elm-review
    elmPackages.elm-test
    cypress
    just # for discoverable project-specific commands. Simpler than Make, plus Nix already handles the build system.
    liveDev
    nixfmt-classic
    updateElmNixDeps
  ];

  shellHook = ''
    export CYPRESS_INSTALL_BINARY=0
    export CYPRESS_RUN_BINARY=${pkgs.cypress}/bin/Cypress

    echo ""
    echo "This is the dev shell for the Tulars project."
    just --list --list-heading $'Run \'just\' to see the available commands:\n'
    echo ""
  '';
}
