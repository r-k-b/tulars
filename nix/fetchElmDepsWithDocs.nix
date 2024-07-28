# based on https://github.com/NixOS/nixpkgs/blob/ae5eab1bf17d71ab2e7c467aa13ccd3811d73fff/pkgs/development/compilers/elm/lib/fetchElmDeps.nix
{ pkgs, fetchurl }:

{ elmPackages, registryDat, elmVersion }:

let
  makeDotElm =
    pkgs.callPackage ./makeDotElmWithDocs.nix { inherit registryDat; };
in ''
  export ELM_HOME=`pwd`/.elm
'' + (makeDotElm elmVersion elmPackages)
