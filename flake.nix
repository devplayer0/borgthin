{
  description = "borgthin";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    devshell.url = "github:numtide/devshell";
    poetry2nix.url = "github:nix-community/poetry2nix";
  };

  outputs = { self, nixpkgs, flake-utils, devshell, poetry2nix }:
  let
    inherit (nixpkgs.lib) substring composeManyExtensions;
    inherit (flake-utils.lib) eachDefaultSystem;

    poetryOverrides = pkgs: pkgs.poetry2nix.defaultPoetryOverrides.extend (final: prev: {
      borgbackup = prev.borgbackup.overridePythonAttrs (old: {
        nativeBuildInputs =
          old.nativeBuildInputs ++
          (with final; [ setuptools-scm pkgconfig ]);
        buildInputs =
          old.buildInputs ++
          (with final; [ setuptools ]) ++
          (with pkgs; [
            libb2
            lz4
            xxHash
            zstd
            openssl
            acl
          ]);
      });
    });
  in
  {
    overlays = rec {
      borgthin = composeManyExtensions [
        poetry2nix.overlay
        (final: prev: (with prev; {
          borgthin = (prev.poetry2nix.mkPoetryApplication rec {
            name = "borgthin";
            projectDir = ./.;
            overrides = poetryOverrides pkgs;

            meta.mainProgram = "borgthin";
          });
        }))
      ];
      default = borgthin;
    };
  } // (eachDefaultSystem (system:
    let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          devshell.overlay
          self.overlays.default
        ];
      };
    in
    {
      devShells.default = pkgs.devshell.mkShell {
        imports = [ "${pkgs.devshell.extraModulesDir}/language/c.nix" ];

        packages = with pkgs; [
          lvm2
          thin-provisioning-tools
          poetry
          (pkgs.poetry2nix.mkPoetryEnv {
            projectDir = ./.;
            overrides = poetryOverrides pkgs;
          })
        ];
      };

      packages = rec {
        inherit (pkgs) borgthin;
        default = borgthin;
      };
    }));
}
