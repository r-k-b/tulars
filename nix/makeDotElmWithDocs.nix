# based on https://github.com/NixOS/nixpkgs/blob/d05f19f5c298f33707c033863d131bfbd0af7ec5/pkgs/development/compilers/elm/lib/makeDotElm.nix
{ stdenv, lib, pkgs, fetchurl, registryDat }:

ver: deps:
let
  cmds = lib.mapAttrsToList (name: info:
    let
      pkg = stdenv.mkDerivation {
        name = lib.replaceStrings [ "/" ] [ "-" ] name + "-${info.version}";

        src = fetchurl {
          url =
            "https://package.elm-lang.org/packages/${name}/${info.version}/docs.json";
          meta.homepage = "https://github.com/${name}/";
          inherit (info) sha256ForDocs;
        };
        nativeBuildInputs = with pkgs.elmPackages;
          [
            #          elm
            #          elm-doc-preview
            #          pkgs.strace
            #          pkgs.breakpointHook
          ];

        dontConfigure = true;
        dontBuild = true;

        installPhase = ''
          mkdir -p $out
          cp -r * $out
        '';
      };
    in ''
      mkdir -p .elm/${ver}/packages/${name}
      cp -R ${pkg} .elm/${ver}/packages/${name}/${info.version}
    '') deps;

  mkDocs = lib.mapAttrsToList (name: info:
    let _ = "";
    in ''
      base="$PWD"
      echo "zzz base is $base"
      echo .elm/${ver}/packages/${name}/${info.version}
      cd .elm/${ver}/packages/${name}/${info.version}
      ls -la
      export ELM_HOME="$base"/.elm
      elm make --docs=docs.json
      cd "$base"
    '') deps;
in (lib.concatStrings cmds) + ''
  mkdir -p .elm/${ver}/packages;
  cp ${registryDat} .elm/${ver}/packages/registry.dat;
  chmod -R +w .elm
'' + (lib.concatStrings mkDocs)
