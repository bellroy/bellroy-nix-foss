inputs:
{
  # A list of compiler versions supported in the project.
  # Valid values are keys of haskell.compiler in nixpkgs.
  supportedCompilers
  # Default compiler version to choose. Must be one of the supportedCompilers.
, defaultCompiler ? builtins.head supportedCompilers
  # Additional haskell packages whose deps should be included in the
  # shell. We want cabal to provide most packages, so only list
  # packages with native dependencies. That ensures the provided GHC
  # can find necessary native libraries on NixOS.
, haskellFfiPackages ? hpkgs: [ ]
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

  makeShell = compilerName: nixpkgs.haskell.packages.${compilerName}.shellFor {
    # Provide zlib by default because anything non-trivial will depend on it.
    packages = hpkgs: [ hpkgs.zlib ] ++ haskellFfiPackages hpkgs;
    nativeBuildInputs = [ essentialTools ];
  };
in
{
  devShells =
    let
      devShellsWithoutDefault =
        builtins.listToAttrs
          (
            builtins.map
              (compilerName: {
                name = compilerName;
                value = makeShell compilerName;
              })
              supportedCompilers
          );
    in
    devShellsWithoutDefault // {
      default = devShellsWithoutDefault.${defaultCompiler};
    };
}
)
