{ elm-review-tool, elmKernelReplacements, pkgs }:
let
  liveDev = pkgs.writeScriptBin "livedev" ''
    cd "$(git rev-parse --show-toplevel)"
    export ELM_HOME="''${ELM_HOME:-$(realpath ./elm-home/elm-stuff)}"
    mkdir -p "$ELM_HOME"
    echo "⚠️ elm-safe-virtual-dom will now patch YOUR local ELM_HOME files, under ''${ELM_HOME:-./elm-home/elm-stuff}."
    echo "🛈️ Don't forget to clear ./elm-stuff each time you remove/apply these patches, or you'll get weird results!"
    rm -rf ./elm-kernel-replacements
    cp --no-preserve=mode -r "${elmKernelReplacements}"/elm-kernel-replacements ./
    ${pkgs.nodejs}/bin/node -e "import('./elm-kernel-replacements/replace-kernel-packages.mjs').then(m => m.replaceKernelPackages())"
    elm-live app/Main.elm -d dist -Hu -- --output="dist/Main.js"
  '';
in pkgs.mkShell {
  name = "tulars";

  buildInputs = with pkgs; [
    elm-review-tool
    elmPackages.elm
    elmPackages.elm-format
    elmPackages.elm-json
    elmPackages.elm-live
    elmPackages.elm-test
    cypress
    just # for discoverable project-specific commands. Simpler than Make, plus Nix already handles the build system.
    liveDev
    nixfmt-classic
  ];

  shellHook = ''
    export CYPRESS_INSTALL_BINARY=0
    export CYPRESS_RUN_BINARY=${pkgs.cypress}/bin/Cypress

    if [ "''${TULARS_DEV_SHELL:-x}" == "entered" ]; then
      exit 0
    fi
    echo ""
    echo "This is the dev shell for the Tulars project."
    just --list --list-heading $'Run \'just\' to see the available commands:\n'
    echo ""

    export TULARS_DEV_SHELL="entered"
  '';
}
