inputs:
{
  # A list of packages in the project.
  # Example:
  #   [
  #     {
  #       name = "timeline";
  #       path = ./package.nix;
  #     }
  #   ]
  cabalPackages
  # A list of compiler versions supported in the project.
  # Valid values are keys of haskell.compiler in nixpkgs.
, supportedCompilers
  # Default compiler version to choose. Must be one of the supportedCompilers.
, defaultCompiler ? builtins.head supportedCompilers
  # Extra tools to include in the shell. This is a function that takes nixpkgs
  # as the argument and returns a list of packages.
, extraTools ? nixpkgs: [ ]
, haskellPackagesOverride ? { compilerName, final, prev }: { }
}:
inputs.flake-utils.lib.eachDefaultSystem (system:
  let
    nixpkgs = import inputs.nixpkgs { inherit system; };

    makePackageSet = compilerName: haskellPackages: haskellPackages.override {
      overrides = final: prev:
        let
          projectPackages =
            builtins.listToAttrs
              (
                builtins.map
                  (cabalPackage: {
                    name = cabalPackage.name;
                    value = prev.callPackage cabalPackage.path { };
                  })
                  cabalPackages
              );
          overridenDependencies = haskellPackagesOverride {
            inherit compilerName;
            haskellLib = nixpkgs.haskell.lib;
            inherit final;
            inherit prev;
          };
        in
        projectPackages // overridenDependencies;
    };

    essentialTools = with nixpkgs; [
      cabal-install
      hlint
      nixpkgs-fmt
      ormolu
      haskellPackages.cabal-fmt
      cabal2nix
      haskell-ci
      miniserve
    ] ++ extraTools nixpkgs;

    makeShell = compilerName: haskellPackages: (makePackageSet compilerName haskellPackages).shellFor {
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
                let pkgSet = makePackageSet compilerName nixpkgs.haskell.packages.${compilerName};
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
                value = makeShell compilerName nixpkgs.haskell.packages.${compilerName};
              })
              supportedCompilers
          ); in
      devShellsWithoutDefault // {
        default = devShellsWithoutDefault.${defaultCompiler};
        light = lightShell;
      };
  }
)
