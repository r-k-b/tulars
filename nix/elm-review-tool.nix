{ elm-review-tool-src, elmPackages, pkgs, stdenv }:
pkgs.buildNpmPackage {
  name = "elm-review-tool";
  src = elm-review-tool-src;
  # to update this hash, see `../bin/update-npmDepsHashes`
  npmDepsHash = "sha256-mI94fYNKZ9Jx1Iyo/VjZqaXQ64tZA2S8mtn5l6TtCSc=";
  patches = [ ./elm-review-offline-details.patch ];
  nativeBuildInputs = with pkgs; [ coreutils ];
  buildInputs = with elmPackages; [ elm elm-format ];
  buildPhase = ''
    substituteInPlace ./package.json \
      --replace-fail '"elm-tooling install"' '"echo skipping elm-tooling"'
    mkdir -p "$out"
    cp -r * "$out"/
    mv $out/bin/elm-review $out/bin/elm-review.js
    cat << EOF > $out/bin/elm-review
    #!${pkgs.bash}/bin/bash
    ${pkgs.nodejs}/bin/node ./elm-review.js \
      --namespace="elm-review-nix-from-src" \
      --compiler="${elmPackages.elm}/bin/elm \
      --elm-format-path="${elmPackages.elm-format}/bin/elm-format \
      "$@"
    EOF
    chmod +x $out/bin/elm-review
  '';
}
