{ pkgs }:
let
  updateElmNixDeps = pkgs.writeScriptBin "update-elm-nix-deps" ''
    set -e
    cd "$(git rev-parse --show-toplevel)"
    elm2nix convert > elm-srcs.nix
    # "Snapshot only outputs any data when redirected to the registry.dat file"
    # <https://github.com/cachix/elm2nix/issues/43>
    elm2nix snapshot > registry.dat
    nixfmt elm-srcs.nix
    echo elm-srcs.nix has been updated.
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
    firebase-tools # for deploying to static hosting
    nixfmt-classic
    nodejs
    updateElmNixDeps
  ];

  shellHook = ''
    export CYPRESS_INSTALL_BINARY=0
    export CYPRESS_RUN_BINARY=${pkgs.cypress}/bin/Cypress
    export PATH=$PATH:${toString ./node_modules/.bin}

    echo ""
    echo "This is the dev shell for the Tulars project. Coming Soon: Run 'tu --help' to see available commands."
    echo ""
  '';
}
