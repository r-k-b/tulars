{
  description = "Trying out flakes with Tulars";

  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        inherit (pkgs) lib callPackage;
      in { devShell = import ./shell.nix { inherit pkgs; }; });
}
