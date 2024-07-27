{
  description = "Trying out flakes with Tulars";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let supportedSystems = with flake-utils.lib.system; [ x86_64-linux ];
    in flake-utils.lib.eachSystem supportedSystems (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        inherit (pkgs) lib stdenv callPackage;
        inherit (lib) fileset hasInfix hasSuffix;

        # The build cache will be invalidated if any of the files within change.
        # So, exclude files from here unless they're necessary for `elm make` et al.
        minimalElmSrc = fileset.toSource {
          root = ./.;
          fileset = fileset.unions [
            (fileset.fileFilter (file: file.hasExt "elm") ./.)
            ./dist
            ./elm.json
            ./nix/elm/registry.dat
          ];
        };

        failIfDepsOutOfSync = stdenv.mkDerivation {
          name = "failIfDepsOutOfSync";
          src = minimalElmSrc;
          nativeBuildInputs = with pkgs; [ jq ];
          buildPhase = ''
            jq '.dependencies.direct * .dependencies.indirect * ."test-dependencies".direct * ."test-dependencies".indirect' \
              --sort-keys < ./elm.json > flat-elm-deps.json

            jq . --sort-keys < ${
              pkgs.writeText "elmSrcsNixFlattened.json" (builtins.toJSON
                (builtins.mapAttrs (k: value: value.version)
                  (import ./nix/elm/elm-srcs.nix)))
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
        };

        elm2nix = import ./nix/default.nix { inherit pkgs minimalElmSrc; };

        built = stdenv.mkDerivation {
          name = "tulars";
          src = minimalElmSrc;
          # build-time-only dependencies
          nativeBuildDeps = with pkgs; [ git nodejs ];
          # runtime dependencies
          buildDeps = [ ];
          buildPhase = ''
            patchShebangs *.sh
            cat >./dist/context.js <<EOF
            // This file generated within flake.nix
            // (not by write-context-js.sh, there's no access to the git metadata inside a nix build)

            window.appContext = {
                nix: {
                  outPath: ${builtins.toJSON self.sourceInfo.outPath},
                },
            }
            EOF
          '';
          installPhase = ''
            mkdir -p $out
            cp -r dist/* $out/
            cp ${elm2nix}/*.js $out/
          '';
        };

        # See the listing @ <https://github.com/NixOS/nixpkgs/blob/1e1396aafccff9378b8f3d0c686e277c226398cf/lib/sources.nix#L23-L26>
        isFile = type: type == "regular";
      in {
        packages = {
          inherit built;
          default = built;
          rawElm2Nix = elm2nix;
          minimalElmSrc = stdenv.mkDerivation {
            src = minimalElmSrc;
            name = "minimal-elm-source";
            buildPhase = "mkdir -p $out";
            installPhase = "cp -r ./* $out";
          };
        };
        checks = { inherit built failIfDepsOutOfSync; };
        devShells.default = import ./nix/shell.nix { inherit pkgs; };
        apps.default = {
          type = "app";
          program = "${pkgs.writeScript "tularsApp" ''
            #!${pkgs.bash}/bin/bash

            xdg-open ${built}/index.html
          ''}";
        };
      });
}
