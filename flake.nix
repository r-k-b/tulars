{
  description = "Trying out flakes with Tulars";

  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        inherit (pkgs) lib stdenv callPackage;

        elm2nix = import ./default.nix { inherit pkgs; };
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
      in {
        packages.default = built;
        packages.rawElm2Nix = elm2nix;
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
