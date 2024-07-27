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
    liveDev
    nixfmt-classic
    updateElmNixDeps
  ];

  shellHook = ''
    export CYPRESS_INSTALL_BINARY=0
    export CYPRESS_RUN_BINARY=${pkgs.cypress}/bin/Cypress
    export PATH=$PATH:${toString ../node_modules/.bin}

    echo ""
    echo "This is the dev shell for the Tulars project. Coming Soon: Run 'tu --help' to see available commands."
    echo ""
  '';
}
