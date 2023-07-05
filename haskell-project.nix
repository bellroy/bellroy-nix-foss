inputs:
{
  #  A list of packages in the project.
  #  Example:
  #    [
  #      {
  #        name = "timeline";
  #        path = ./package.nix;
  #      }
  #    ]
  cabalPackages
  # A list of compiler versions supported in the project.
  # Valid values are keys of haskell.compiler in nixpkgs.
, supportedCompilers
  # Default compiler version to choose. Must be one of the supportedCompilers.
, defaultCompiler
}:
inputs.flake-utils.lib.eachDefaultSystem (system:
  let
    nixpkgs = import inputs.nixpkgs { inherit system; };

    makePackageSet = haskellPackages: haskellPackages.override {
      overrides = final: prev: with nixpkgs.haskell.lib;
        builtins.listToAttrs
          (
            builtins.map
              (cabalPackage: {
                name = cabalPackage.name;
                value = prev.callPackage cabalPackage.path { };
              })
              cabalPackages
          );
    };

    essentialTools = with nixpkgs; [
      cabal-install
      hlint
      ormolu
      haskellPackages.cabal-fmt
      cabal2nix
      miniserve
    ];

    makeShell = haskellPackages: (makePackageSet haskellPackages).shellFor {
      packages = p: builtins.map (cabalPackage: p.${cabalPackage.name}) cabalPackages;
      withHoogle = true;
      buildInputs = essentialTools ++ [
        nixpkgs.haskellPackages.haskell-language-server
      ];
    };

    lightShell = nixpkgs.mkShell {
      packages = essentialTools ++ [ nixpkgs.ghc ];
    };
  in
  {
    packages =
      let packagesWithoutDefault =
        builtins.listToAttrs
          (
            builtins.concatMap
              (compilerName:
                let pkgSet = makePackageSet nixpkgs.haskell.packages.${compilerName};
                in
                builtins.map
                  (cabalPackage: {
                    name = "${compilerName}-${cabalPackage.name}";
                    value = pkgSet.${cabalPackage.name};
                  })
                  cabalPackages
              )
              supportedCompilers
          );
      in
      packagesWithoutDefault // {
        default = nixpkgs.runCommand "aggregate"
          {
            buildInputs = builtins.map (name: packagesWithoutDefault.${name})
              (builtins.attrNames packagesWithoutDefault);
          } "touch $out";
      };

    devShells =
      let devShellsWithoutDefault =
        builtins.listToAttrs
          (
            builtins.map
              (compilerName: {
                name = compilerName;
                value = makeShell nixpkgs.haskell.packages.${compilerName};
              })
              supportedCompilers
          ); in
      devShellsWithoutDefault // {
        default = devShellsWithoutDefault.${defaultCompiler};
        light = lightShell;
      };
  }
)
