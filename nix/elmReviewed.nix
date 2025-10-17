{ elm-review-tool, elmPackages, elmVersion, lib, pkgs, stdenv, reviewSrc }:
let
  mainApp = builtins.fromJSON (builtins.readFile ../elm.json);

  reviewApp = builtins.fromJSON (builtins.readFile ../review/elm.json);
  elmReviewVersion = reviewApp.dependencies.direct."jfmengels/elm-review";

in stdenv.mkDerivation {
  name = "elm-reviewed";
  src = reviewSrc;

  buildInputs = with elmPackages; [ elm elm-json elm-review-tool ];

  installPhase = ''
    ${pkgs.makeDotElmDirectoryCmd {
      elmJson = ../review/elm.json;
      extraDeps = mainApp.dependencies.direct // mainApp.dependencies.indirect;
    }}
    set -e
    mkdir -p .elm/elm-review/${elmReviewVersion}
    ln -s ../../${elmVersion} .elm/elm-review/${elmReviewVersion}/${elmVersion}
    elm-review --offline
    echo "passed" > $out
  '';
}
