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
    nixfmt
    nodejs
  ];
}

