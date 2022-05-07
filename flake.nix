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
                  availableSourceInfo: [${
                    lib.strings.concatMapStringsSep ", " (name: "'${name}'")
                    (lib.attrNames self.sourceInfo)
                  }],
                  lastModified: '${toString self.sourceInfo.lastModified}',
                  lastModifiedDate: '${
                    toString self.sourceInfo.lastModifiedDate
                  }',
                  narHash: '${self.sourceInfo.narHash}',
                  outPath: '${self.sourceInfo.outPath}',
                  rev: '${if (self ? rev) then self.rev else "dirty"}',
                  revCount: ${
                    if self.sourceInfo ? revCount then
                      toString self.sourceInfo.revCount
                    else
                      ''"dirty"''
                  },
                  shortRev: '${
                    if (self ? shortRev) then self.shortRev else "dirty"
                  }',
                  submodules: '${toString self.sourceInfo.submodules}',
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
