{ elm-review-tool, pkgs }:
let
  updateElmNixDeps = pkgs.writeScriptBin "update-elm-nix-deps" ''
    set -e
    RR="$(realpath $(git rev-parse --show-toplevel))"
    echo "Repo Root is $RR"
    cd "$RR"

    echo creating registry snapshot at "$RR"/nix/elm/registry.dat ...
    elm2nix snapshot
    mv -f "$RR"/registry.dat "$RR"/nix/elm/registry.dat

    # TODO: make elm2nix also record the shar256ForDocs?
    # or do we switch over to jeslie0/mkElmDerivation, do it there?

    echo "Generating Nix expressions from elm.json, for the main app..."
    elm2nix convert > "$RR"/nix/elm/elm-srcs-main.nix
    nixfmt "$RR"/nix/elm/elm-srcs-main.nix
    echo "$RR"/nix/elm/elm-srcs-main.nix has been updated.

    echo "Generating Nix expressions from elm.json, for elm-review..."
    elm2nix convert > "$RR"/nix/elm/elm-srcs-review.nix
    nixfmt "$RR"/nix/elm/elm-srcs-review.nix
    echo "$RR"/nix/elm/elm-srcs-review.nix has been updated.

    echo "todo: update npmDepsHash for elm-review-tool"
  '';
  liveDev = pkgs.writeScriptBin "livedev" ''
    cd "$(git rev-parse --show-toplevel)"
    elm-live app/Main.elm -d dist -Hu -- --output="dist/Main.js"
  '';
in pkgs.mkShell {
  name = "tulars";

  buildInputs = with pkgs; [
    elm-review-tool
    elm2nix
    elmPackages.elm
    elmPackages.elm-format
    elmPackages.elm-json
    elmPackages.elm-live
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
