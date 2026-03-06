{
  description = "Development shell for haskell-rocm";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);
    in {
      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in {
          default = pkgs.mkShell {
            packages = with pkgs; [
              ghc
              cabal-install
              clang
              pkg-config
              git
              python3
            ];

            shellHook = ''
              if [ -n "''${ROCM_PATH:-}" ] && [ -d "$ROCM_PATH" ]; then
                export HASKELL_ROCM_PATH="$ROCM_PATH"
              elif [ -d /opt/rocm ]; then
                export HASKELL_ROCM_PATH=/opt/rocm
              else
                export HASKELL_ROCM_PATH=/usr
              fi

              if [ -d "$HASKELL_ROCM_PATH/include" ]; then
                export NIX_CFLAGS_COMPILE="''${NIX_CFLAGS_COMPILE:-} -I$HASKELL_ROCM_PATH/include"
              fi

              if [ -d "$HASKELL_ROCM_PATH/lib64" ]; then
                export NIX_LDFLAGS="''${NIX_LDFLAGS:-} -L$HASKELL_ROCM_PATH/lib64"
              elif [ -d "$HASKELL_ROCM_PATH/lib" ]; then
                export NIX_LDFLAGS="''${NIX_LDFLAGS:-} -L$HASKELL_ROCM_PATH/lib"
              fi

              echo "Entering haskell-rocm devShell"
              echo "ROCm path: $HASKELL_ROCM_PATH"
              echo "Tip: $(pwd)/ci/scripts/print-cabal-rocm-flags.sh"
            '';
          };
        });
    };
}
