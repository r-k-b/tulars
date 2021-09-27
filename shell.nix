{ pkgs ? import <nixpkgs> { } }:
pkgs.mkShell {
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
    nixfmt
    nodejs
  ];

  shellHook = ''
    export CYPRESS_INSTALL_BINARY=0
    export CYPRESS_RUN_BINARY=${pkgs.cypress}/bin/Cypress
    export PATH=$PATH:${toString ./node_modules/.bin}
  '';
}
