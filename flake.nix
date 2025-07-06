{
  description = "Trying out flakes with Tulars";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "nixpkgs/nixos-unstable";
    elm-review-tool-src = {
      url = "github:jfmengels/node-elm-review";
      flake = false;
    };
    elmSafeVirtualDom = {
      url = "github:lydell/elm-safe-virtual-dom";
      flake = false;
    };
    # These "Lydell" packages are replacements for core/kernel Elm packages, needed for elm-safe-virtual-dom.
    lydellElmBrowser = {
      url = "github:lydell/browser";
      flake = false;
    };
    lydellElmHtml = {
      url = "github:lydell/html";
      flake = false;
    };
    lydellElmVirtualDom = {
      url = "github:lydell/virtual-dom";
      flake = false;
    };
    mkElmDerivation = {
      url = "github:r-k-b/mkElmDerivation?ref=support-elm-review";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { elm-review-tool-src, elmSafeVirtualDom, lydellElmBrowser
    , lydellElmHtml, lydellElmVirtualDom, self, mkElmDerivation, nixpkgs
    , flake-utils }:
    let supportedSystems = with flake-utils.lib.system; [ x86_64-linux ];
    in flake-utils.lib.eachSystem supportedSystems (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ mkElmDerivation.overlays.makeDotElmDirectoryCmd ];
        };
        inherit (pkgs) lib stdenv callPackage;
        inherit (lib) fileset hasInfix hasSuffix;

        toSource = fsets:
          fileset.toSource {
            root = ./.;
            fileset = fileset.unions fsets;
          };

        elmVersion = "0.19.1";

        elmKernelReplacements =
          pkgs.callPackage ./nix/elm-kernel-replacements.nix {
            inherit elmSafeVirtualDom elmVersion lydellElmBrowser lydellElmHtml
              lydellElmVirtualDom;
          };

        # The build cache will be invalidated if any of the files within change.
        # So, exclude files from here unless they're necessary for `elm make` et al.
        minimalElmSrc = toSource [
          (fileset.fileFilter (file: file.hasExt "elm") ./app)
          ./dist
          ./elm.json
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

        elm-review-tool = callPackage ./nix/elm-review-tool.nix {
          inherit elm-review-tool-src;
        };

        compiledElmApp = callPackage ./nix/default.nix {
          inherit elmKernelReplacements minimalElmSrc;
        };

        built = callPackage ./nix/built.nix {
          inherit compiledElmApp minimalElmSrc;
          sourceInfo = self.sourceInfo;
        };

        elmtests = callPackage ./nix/elmtests.nix { inherit testsSrc; };
        elmReviewed = callPackage ./nix/elmReviewed.nix {
          inherit elm-review-tool elmVersion reviewSrc;
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
          inherit built compiledElmApp elm-review-tool;
          elm-review-tool-src = pkgs.runCommand "elm-review-tool-src" { }
            "ln -s ${elm-review-tool-src} $out";
          default = built;
          minimalElmSrc = peekSrc "minimal-elm" minimalElmSrc;
          testsSrc = peekSrc "tests" testsSrc;
          reviewSrc = peekSrc "elm-review" reviewSrc;
        };
        checks = { inherit built elmReviewed elmtests; };
        devShells.default =
          import ./nix/shell.nix { inherit elm-review-tool pkgs; };
        apps.default = {
          type = "app";
          program = "${pkgs.writeScript "tularsApp" ''
            #!${pkgs.bash}/bin/bash

            xdg-open ${built}/index.html
          ''}";
        };
      });
}
