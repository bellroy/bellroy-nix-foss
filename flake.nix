{
  # Use 'nix flake show' to discover the structure of the output.
  # Multiple versions of compiler is supported.
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    haskell-ci = {
      url = "github:haskell-ci/haskell-ci";
      flake = false;
    };
    nixpkgs.url = "nixpkgs/nixpkgs-unstable";
    pre-commit-hooks = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:cachix/pre-commit-hooks.nix";
    };
  };

  outputs = inputs:
    {
      lib.haskellProject = import ./haskell-project.nix inputs;
    };
}
