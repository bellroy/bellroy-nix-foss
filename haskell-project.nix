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

  haskell-ci =
    let
      # Hopefully many of these overrides become redundant in future
      # dependency update cycles, as the default version in
      # `nixpkgs.haskellPackages` become compatible with `haskell-ci`.
      haskellPackages = nixpkgs.haskellPackages.override {
        overrides = hfinal: hprev: with nixpkgs.haskell.lib.compose; {
          aeson = doJailbreak hprev.aeson_2_2_2_0;
          base-compat = hprev.base-compat_0_14_0;
          haskell-ci = doJailbreak (hprev.callCabal2nix "haskell-ci" inputs.haskell-ci { });
          lattices = doJailbreak hprev.lattices;
          primitive = dontCheck hprev.primitive_0_9_0_0;
          ShellCheck = hprev.ShellCheck_0_9_0;
          time-compat = doJailbreak hprev.time-compat;
        };
      };
    in
    haskellPackages.haskell-ci;

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
