let pkgs = import <nixpkgs> { };

in pkgs.mkShell rec {
  name = "webdev";

  buildInputs = with pkgs; [
    elmPackages.elm
    elmPackages.elm-format
    elmPackages.elm-json
    elmPackages.elm-live
    elmPackages.elm-review
    elmPackages.elm-test
    nodejs
  ];
}

