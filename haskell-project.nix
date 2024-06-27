inputs:
{
  # A list of compiler versions supported in the project.
  # Valid values are keys of haskell.compiler in nixpkgs.
  supportedCompilers
  # Default compiler version to choose. Must be one of the supportedCompilers.
, defaultCompiler ? builtins.head supportedCompilers
  # Extra tools to include in the shell. This is a function that takes nixpkgs
  # as the argument and returns a list of packages.
, extraTools ? nixpkgs: [ ]
}:
inputs.flake-utils.lib.eachDefaultSystem (system:
  let
    nixpkgs = import inputs.nixpkgs { inherit system; };

    essentialTools = with nixpkgs; [
      cabal-install
      cabal2nix
      haskell-ci
      haskellPackages.cabal-fmt
      haskellPackages.haskell-language-server
      hlint
      nixpkgs-fmt
      ormolu
    ] ++ extraTools nixpkgs;

    makeShell = compilerName: nixpkgs.mkShell {
      packages = essentialTools ++ [
        nixpkgs.haskell.compiler.${compilerName}
      ];
    };
  in
  {
    devShells =
      let devShellsWithoutDefault =
        builtins.listToAttrs
          (
            builtins.map
              (compilerName: {
                name = compilerName;
                value = makeShell compilerName;
              })
              supportedCompilers
          ); in
      devShellsWithoutDefault // {
        default = devShellsWithoutDefault.${defaultCompiler};
      };
  }
)
