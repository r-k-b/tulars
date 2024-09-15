{ elm-review-tool, elmPackages, lib, pkgs, stdenv, reviewSrc }:
let elmVersion = "0.19.1";

in stdenv.mkDerivation {
  name = "elm-reviewed";
  src = reviewSrc;

  buildInputs = with elmPackages; [
    elm
    elm-json
    elm-review-tool
    pkgs.breakpointHook
  ];

  installPhase = ''
    ${pkgs.makeDotElmDirectoryCmd { elmJson = ../review/elm.json; }}
    set -e
    mkdir -p .elm/elm-review/2.12.0
    ln -s ../../${elmVersion} .elm/elm-review/2.12.0/${elmVersion}
    elm-review --offline
    echo "passed" > $out
  '';
}
