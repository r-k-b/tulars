{ elm-review-tool, elmPackages, fetchElmDepsWithDocs, lib, pkgs, stdenv
, reviewSrc }:
let
  elmVersion = "0.19.1";
  elmPkgDeps = import ./elm/elm-srcs-main.nix
    // import ./elm/elm-srcs-review.nix;

  mkDocs = lib.mapAttrsToList (name: info:
    let _ = "";
    in ''
      base="$PWD"
      echo "zzz base is $base"
      echo "zzz EH is $ELM_HOME"
      echo .elm/${elmVersion}/packages/${name}/${info.version}
      cd .elm/${elmVersion}/packages/${name}/${info.version}
      elm make --docs=docs.json
      cd "$base"
    '') elmPkgDeps;
in stdenv.mkDerivation {
  name = "elm-reviewed";
  src = reviewSrc;

  buildInputs = with elmPackages; [
    elm
    elm-json
    elm-review-tool
    pkgs.breakpointHook
  ];

  buildPhase = elmPackages.fetchElmDeps {
    inherit elmVersion;
    elmPackages = elmPkgDeps;
    registryDat = ./elm/registry.dat;
  };

  installPhase = ''
    set -e
  '' + (lib.concatStrings mkDocs) + ''
    mkdir -p .elm/elm-review/2.12.0
    ln -s ../../${elmVersion} .elm/elm-review/2.12.0/${elmVersion}
    elm-review --offline
    echo "passed" > $out
  '';
}
