{ elm2nix, minimalElmSrc, pkgs, sourceInfo, stdenv }:
stdenv.mkDerivation {
  name = "tulars";
  src = minimalElmSrc;
  # build-time-only dependencies
  nativeBuildDeps = with pkgs; [ git ];
  # runtime dependencies
  buildDeps = [ ];
  buildPhase = ''
    patchShebangs *.sh
    cat >./dist/context.js <<EOF
    // This file generated within flake.nix

    window.appContext = {
        nix: {
          outPath: ${builtins.toJSON sourceInfo.outPath},
        },
    }
    EOF
  '';
  installPhase = ''
    mkdir -p $out
    cp -r dist/* $out/
    cp ${elm2nix}/*.js $out/
  '';
}
