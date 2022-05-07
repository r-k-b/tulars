{
  description = "Trying out flakes with Tulars";

  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        inherit (pkgs) lib stdenv callPackage;

        # The build cache will be invalidated if any of the files within change.
        # So, exclude files from here unless they're necessary for `elm make` et al.
        minimalElmSrc = lib.cleanSourceWith {
          name = "tulars-cleaned-source";
          filter = name: type:
            let
              baseName = baseNameOf (toString name);
              relevantName =
                # turns paths like `/nix/store/eurr2u3-source/foo/bar.baz` into `foo/bar.baz`:
                lib.elemAt
                (builtins.match "^/[^/]*/[^/]*/[^/]*/(.*)$" (toString name)) 0;

            in (lib.cleanSourceFilter name type
              && !(lib.hasSuffix ".lock" baseName && isFile type)
              && !(lib.hasSuffix ".md" baseName && isFile type)
              && !(lib.hasSuffix ".nix" baseName && isFile type)
              && !(lib.hasSuffix ".json" baseName && isFile type)
              && !(lib.hasSuffix ".patch" baseName && isFile type)
              && !(lib.hasSuffix ".sh" baseName && isFile type)
              # fdgjfdgk
              && !(relevantName == "Makefile") && !(relevantName == "LICENSE")
              && !(lib.hasPrefix "cypress" relevantName)
              && !(lib.hasPrefix "dist/" relevantName)
              && !(lib.hasPrefix "hook-samples/" relevantName)
              || (relevantName == "elm.json"));
          src = pkgs.nix-gitignore.gitignoreRecursiveSource "" ./.;
        };

        elm2nix = import ./default.nix { inherit pkgs minimalElmSrc; };

        built = stdenv.mkDerivation {
          name = "tulars";
          src = pkgs.nix-gitignore.gitignoreRecursiveSource "" ./.;
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
                gitHash: '${if (self ? rev) then self.rev else "NO_GIT_REPO"}',
                nix: {
                  availableSourceInfo: ${
                    builtins.toJSON (lib.attrNames self.sourceInfo)
                  },
                  lastModified: ${builtins.toJSON self.sourceInfo.lastModified},
                  lastModifiedDate: ${
                    builtins.toJSON self.sourceInfo.lastModifiedDate
                  },
                  narHash: ${builtins.toJSON self.sourceInfo.narHash},
                  outPath: ${builtins.toJSON self.sourceInfo.outPath},
                  rev: ${
                    if (self ? rev) then builtins.toJSON self.rev else "'dirty'"
                  },
                  revCount: ${
                    if self.sourceInfo ? revCount then
                      builtins.toJSON self.sourceInfo.revCount
                    else
                      "'dirty'"
                  },
                  shortRev: ${
                    if (self ? shortRev) then
                      builtins.toJSON self.shortRev
                    else
                      "'dirty'"
                  },
                  submodules: ${
                    if self.sourceInfo ? submodulestoString then
                      builtins.toJSON self.sourceInfo.submodules
                    else
                      "null"
                  },
                },
            }
            EOF
          '';
          installPhase = ''
            mkdir -p $out
            cp -r dist/* $out/
            cp ${elm2nix}/Main.js $out/
          '';
        };

        # See the listing @ <https://github.com/NixOS/nixpkgs/blob/1e1396aafccff9378b8f3d0c686e277c226398cf/lib/sources.nix#L23-L26>
        isFile = type: type == "regular";
      in {
        packages = {
          default = built;
          rawElm2Nix = elm2nix;
          minimalElmSrc = stdenv.mkDerivation {
            src = minimalElmSrc;
            name = "minimal-elm-source";
            buildPhase = "mkdir -p $out";
            installPhase = "cp -r ./* $out";
          };
        };
        devShells.default = import ./shell.nix { inherit pkgs; };
        apps.default = {
          type = "app";
          program = "${pkgs.writeScript "tularsApp" ''
            #!${pkgs.bash}/bin/bash

            xdg-open ${built}/index.html
          ''}";
        };
      });
}
