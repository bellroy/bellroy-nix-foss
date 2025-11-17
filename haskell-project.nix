inputs:
{
  # Source directory of the project using this flake.
  src,
  # A list of compiler versions supported in the project.
  # Valid values are keys of haskell.compiler in nixpkgs.
  supportedCompilers,
  # Default compiler version to choose. Must be one of the supportedCompilers.
  defaultCompiler ? builtins.head supportedCompilers,
  # Additional haskell packages whose deps should be included in the
  # shell. We want cabal to provide most packages, so only list
  # packages with native dependencies. That ensures the provided GHC
  # can find necessary native libraries on NixOS.
  haskellFfiPackages ? hpkgs: [ ],
  # Extra tools to include in the shell. This is a function that takes nixpkgs
  # as the argument and returns a list of packages.
  extraTools ? nixpkgs: [ ],
  # Customizes the attrset being passed to 'hooks' in https://github.com/cachix/git-hooks.nix.
  # Use this to add new pre-commit hooks or override default hooks enabled by this function.
  preCommitHooks ? { },
}:
let
  evalPkgs = import inputs.nixpkgs { system = "x86_64-linux"; };
  systems = with inputs.flake-utils.lib.system; [
    aarch64-darwin
    x86_64-darwin
    x86_64-linux
  ];

  perSystem = inputs.flake-utils.lib.eachSystem systems (
    system:
    let
      nixpkgs = import inputs.nixpkgs { inherit system; };

      checks.pre-commit-check = inputs.git-hooks.lib.${system}.run {
        inherit src;
        hooks = {
          cabal-fmt.enable = true;
          hlint.enable = true;
          nixfmt-rfc-style.enable = true;
          ormolu.enable = true;
        }
        // preCommitHooks;
      };

      essentialTools =
        with nixpkgs;
        [
          cabal-install
          cabal2nix
          haskellPackages.cabal-fmt
          haskellPackages.ghcid
          haskellPackages.haskell-language-server
          hlint
          nixpkgs-fmt
          ormolu
        ]
        ++ extraTools nixpkgs;

      makeShell =
        compilerName:
        nixpkgs.haskell.packages.${compilerName}.shellFor {
          inherit (checks.pre-commit-check) shellHook;

          # Provide zlib by default because anything non-trivial will depend on it.
          packages = hpkgs: [ hpkgs.zlib ] ++ haskellFfiPackages hpkgs;
          nativeBuildInputs = [ essentialTools ] ++ checks.pre-commit-check.enabledPackages;
        };
    in
    {
      devShells =
        let
          devShellsWithoutDefault = builtins.listToAttrs (
            builtins.map (compilerName: {
              name = compilerName;
              value = makeShell compilerName;
            }) supportedCompilers
          );
        in
        devShellsWithoutDefault // { default = devShellsWithoutDefault.${defaultCompiler}; };
    }
  );

  hydraJobs = {
    aggregate = evalPkgs.runCommand "aggregate" {
      _hydraAggregate = true;
      constituents = builtins.concatMap (
        system:
        builtins.map (ghc: "devShells.${system}.${ghc}") supportedCompilers
        ++ [ "devShells.${system}.default" ]
      ) systems;
    } "touch $out";
  }
  // {
    inherit (perSystem) devShells;
  };
in
perSystem // { inherit hydraJobs; }
