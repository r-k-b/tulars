{ pkgs ? import <nixpkgs> { } }:
pkgs.mkShell {
  name = "tulars";

  buildInputs = with pkgs; [
    elmPackages.elm
    elmPackages.elm-format
    elmPackages.elm-live
    elmPackages.elm-test
    nodejs
  ];
}

