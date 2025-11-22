{ elmSafeVirtualDom, elmVersion, lib, lydellElmBrowser, lydellElmHtml
, lydellElmVirtualDom, pkgs, stdenv }:
let
  inherit (lib) fileset;
  inherit (lib.asserts) assertMsg;

  readPackageVersion = package: (lib.importJSON "${package}/elm.json").version;

  # These must match the original elm* versions in elm.json, for all projects this is applied to!
  lydellVersions = {
    browser = readPackageVersion lydellElmBrowser;
    html = readPackageVersion lydellElmHtml;
    virtual-dom = readPackageVersion lydellElmVirtualDom;
  };
  depVersions = (lib.importJSON ../elm.json).dependencies;
in assert assertMsg (depVersions.direct."elm/browser" == lydellVersions.browser)
  "elm/browser version must match the Lydell patch";
assert assertMsg (depVersions.direct."elm/html" == lydellVersions.html)
  "elm/html version must match the Lydell patch";
assert assertMsg
  (depVersions.indirect."elm/virtual-dom" == lydellVersions.virtual-dom)
  "elm/virtual-dom version must match the Lydell patch";
stdenv.mkDerivation {
  name =
    "elm_kernel_replacements"; # deliberately unique spelling, so it's easy to find from error messages
  dontUnpack = true;
  buildPhase = ''
    # the `assert` guards above will enforce that the versions in hippo/elm.json must exactly match the Lydell versions

    echo "Creating elm-safe-virtual-dom's expected folder structure..."
    mkdir -p ./elm-kernel-replacements/elm-stuff/elm
    pushd ./elm-kernel-replacements/elm-stuff/elm
    mkdir -p browser/${lydellVersions.browser}
    mkdir -p html/${lydellVersions.html}
    mkdir -p virtual-dom/${lydellVersions.virtual-dom}

    cp -r ${lydellElmBrowser}/* ./browser/${lydellVersions.browser}
    cp -r ${lydellElmHtml}/* ./html/${lydellVersions.html}
    cp -r ${lydellElmVirtualDom}/* ./virtual-dom/${lydellVersions.virtual-dom}
    popd
    cp ${elmSafeVirtualDom}/replace-kernel-packages.mjs ./elm-kernel-replacements/
    echo "Done creating elm-safe-virtual-dom's expected folder structure:"

    ${pkgs.tree}/bin/tree -d .

    cat << EOF
    The expected file structure is ready!
    To use it, link or copy this derivation's files into your project folder, then run something like:

        node -e "import('./elm-kernel-replacements/replace-kernel-packages.mjs').then(m => m.replaceKernelPackages())"

    That will apply the patched versions to your \$ELM_HOME folder, or ./elm-home/elm-stuff if
    the ELM_HOME env var is not set.
    From there, Elm will use the patched versions as if they were the originals.

    More info: https://github.com/lydell/elm-safe-virtual-dom?tab=readme-ov-file#elm-safe-virtual-dom
    EOF
  '';

  installPhase = ''
    mkdir -p $out
    cp -r ./elm-kernel-replacements $out
  '';
}
