{ minimalElmSrc, pkgs, stdenv }:
stdenv.mkDerivation {
  name = "failIfDepsOutOfSync";
  src = minimalElmSrc;
  nativeBuildInputs = with pkgs; [ jq ];
  buildPhase = ''
    jq '.dependencies.direct * .dependencies.indirect * ."test-dependencies".direct * ."test-dependencies".indirect' \
      --sort-keys < ./elm.json > flat-elm-deps.json

    jq . --sort-keys < ${
      pkgs.writeText "elmSrcsNixFlattened.json" (builtins.toJSON
        (builtins.mapAttrs (k: value: value.version)
          (import ./elm/elm-srcs.nix)))
    } > flat-nix-deps.json

    if diff flat-elm-deps.json flat-nix-deps.json; then
      echo "Deps appear to be in sync 👍"
    else
      echo "ERROR: Looks like the nix deps are out of sync." >&2
      echo "Run update-elm-nix-deps and raise a PR.";
      exit 1
    fi;
  '';
  installPhase = ''
    mkdir -p $out
    cp -r * $out
  '';
}
