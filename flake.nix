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

        toSource = fsets:
          fileset.toSource {
            root = ./.;
            fileset = fileset.unions fsets;
          };

        # The build cache will be invalidated if any of the files within change.
        # So, exclude files from here unless they're necessary for `elm make` et al.
        minimalElmSrc = toSource [
          (fileset.fileFilter (file: file.hasExt "elm") ./app)
          ./dist
          ./elm.json
          ./nix/elm/registry.dat
        ];

        testsSrc = toSource [
          (fileset.difference (fileset.fromSource minimalElmSrc) ./dist)
          (fileset.fileFilter (file: file.hasExt "elm") ./tests)
        ];

        reviewSrc = toSource [
          (fileset.fromSource testsSrc)
          (fileset.fileFilter (file: file.hasExt "elm") ./review)
          ./review/elm.json
        ];

        failIfDepsOutOfSync =
          callPackage ./nix/failIfDepsOutOfSync.nix { inherit minimalElmSrc; };

        elm2nix = callPackage ./nix/default.nix { inherit minimalElmSrc; };

        built = callPackage ./nix/built.nix {
          inherit elm2nix minimalElmSrc;
          sourceInfo = self.sourceInfo;
        };

        peekSrc = name: src:
          stdenv.mkDerivation {
            src = src;
            name = "peekSource-${name}";
            buildPhase = "mkdir -p $out";
            installPhase = "cp -r ./* $out";
          };
      in {
        packages = {
          inherit built;
          default = built;
          rawElm2Nix = elm2nix;
          minimalElmSrc = peekSrc "minimal-elm" minimalElmSrc;
          testsSrc = peekSrc "tests" testsSrc;
          reviewSrc = peekSrc "elm-review" reviewSrc;
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
