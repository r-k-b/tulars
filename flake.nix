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

        failIfDepsOutOfSync =
          callPackage ./nix/failIfDepsOutOfSync.nix { inherit minimalElmSrc; };

        elm2nix = callPackage ./nix/default.nix { inherit minimalElmSrc; };

        built = callPackage ./nix/built.nix {
          inherit elm2nix minimalElmSrc;
          sourceInfo = self.sourceInfo;
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
