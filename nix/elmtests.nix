{ elmPackages, pkgs, stdenv, testsSrc }:
stdenv.mkDerivation {
  name = "elm-test-results";
  src = testsSrc;

  buildInputs = with elmPackages; [ elm elm-test ];

  buildPhase = pkgs.elmPackages.fetchElmDeps {
    elmPackages = import ./elm/elm-srcs.nix;
    elmVersion = "0.19.1";
    registryDat = ./elm/registry.dat;
  };

  installPhase = ''
    set -e
    elm-test
    echo "passed" > $out
  '';
}
