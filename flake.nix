{
  description = "Trying out flakes with Tulars";

  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        inherit (pkgs) lib callPackage stdenv nodejs nodePackages elmPackages;
      in {
        devShell = import ./shell.nix { inherit pkgs; };
        packages.dist-files = stdenv.mkDerivation {
          name = "dist-files";
          buildInputs = [
            nodejs
            nodePackages.uglify-js
            # How to use the Elm from the new ./default.nix, that won't try to
            # download stuff from the net?
            elmPackages.elm
          ];
          src = self;
          #unpackPhase = "true";

          buildPhase = ''
            export ELM_HOME=$(mktemp -d)
            # Can we have these scripts work for non-NixOS users as well?
            ./build.sh
            ./optimize.sh
            ./debug.sh
          '';

          installPhase = ''
            mkdir -p "$out/bin"
            install dist "$out/bin"
          '';
        };
      });
}
