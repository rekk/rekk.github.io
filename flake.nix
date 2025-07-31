{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs = inputs:
    with builtins;
    let
      pname = "rekk.github.io";

      inherit (inputs.nixpkgs) lib;
      foreach = xs: f: with lib; foldr recursiveUpdate { } (
        if isList xs then map f xs
        else if isAttrs xs then mapAttrsToList f xs
        else throw "foreach: expected list or attrset but got ${typeOf xs}"
      );
      sourceFilter = root: with lib.fileset; toSource {
        inherit root;
        fileset = fileFilter (file: any file.hasExt [ "cabal" "hs" "md" ]) root;
      };
      ghcsFor = pkgs: with lib; foldlAttrs
        (acc: name: hp:
          let
            version = getVersion hp.ghc;
            majorMinor = versions.majorMinor version;
            ghcName = "ghc${replaceStrings ["."] [""] majorMinor}";
          in
          if hp ? ghc && ! acc ? ${ghcName} && versionAtLeast version "9.2" && versionOlder version "9.11"
          then acc // { ${ghcName} = hp; }
          else acc
        )
        { }
        pkgs.haskell.packages;
      hpsFor = pkgs: { default = pkgs.haskellPackages; } // ghcsFor pkgs;
      overlay = lib.composeManyExtensions [
        (final: prev: {
          haskell = prev.haskell // {
            packageOverrides = lib.composeManyExtensions [
              prev.haskell.packageOverrides
              (hfinal: hprev: with prev.haskell.lib.compose; {
                ${pname} = hfinal.callCabal2nix pname (sourceFilter ./.) { };
              })
            ];
          };
        })
      ];
    in
    foreach inputs.nixpkgs.legacyPackages
      (system: pkgs':
        let
          pkgs = pkgs'.extend overlay;
          hps = hpsFor pkgs;
          bins = pkgs.buildEnv {
            name = "${pname}-bins";
            paths = [ hps.default.${pname} ];
            pathsToLink = [ "/bin" ];
          };
          libs = pkgs.buildEnv {
            name = "${pname}-libs";
            paths = map (hp: hp.${pname}) (attrValues hps);
            pathsToLink = [ "/lib" ];
          };
          docs = pkgs.haskell.lib.documentationTarball hps.default.${pname};
          sdist = pkgs.haskell.lib.sdistTarball hps.default.${pname};
          docsAndSdist = pkgs.linkFarm "${pname}-docsAndSdist" { inherit docs sdist; };
        in
        {
          formatter.${system} = pkgs.nixpkgs-fmt;
          legacyPackages.${system} = pkgs;
          packages.${system}.default = pkgs.symlinkJoin {
            name = "${pname}-all";
            paths = [ bins libs docsAndSdist ];
            inherit (hps.default.syntax) meta;
          };
          devShells.${system} =
            foreach hps (ghcName: hp: {
              ${ghcName} = hp.shellFor {
                packages = ps: [ hp.${pname} ];
                nativeBuildInputs = [
                  pkgs'.haskellPackages.cabal-install
                  hp.fourmolu
                  hp.haskell-language-server
                  pkgs'.zlib
                ];
              };
            });
        }
      ) // {
      overlays.default = overlay;
    };
}
