{
  description = "Azure CLI with selected extensions and declarative keyring support";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              (final: prev: {
                pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
                  (pyFinal: pyPrev: {
                    # nixpkgs marks fabric 3.2.x broken with invoke >= 3
                    # (https://github.com/fabric/fabric/issues/2376), and azure-cli
                    # depends on fabric. Pin invoke to 2.x for the whole Python set
                    # (paramiko also depends on it, so a fabric-only pin duplicates it).
                    invoke = pyPrev.invoke.overridePythonAttrs (old: rec {
                      version = "2.2.1";
                      src = final.fetchPypi {
                        pname = "invoke";
                        inherit version;
                        hash = "sha256-UVv0m0pIkyt5sCRZA0jaIvOcSULf+ZGtH7i4uuob5wc=";
                      };
                    });
                  })
                ];
              })
            ];
          };
          # Avoid runtime pip installation in the immutable Nix store.
          devops = pkgs.azure-cli.extensions.azure-devops.overridePythonAttrs (old: {
            propagatedBuildInputs = (old.propagatedBuildInputs or [ ]) ++ [ pkgs.python3Packages.keyring ];
          });
          # The wheel pins Kubernetes 24.2.0, while this nixpkgs ships 35.0.0.
          containerapp = pkgs.azure-cli.extensions.containerapp.overridePythonAttrs (old: {
            pythonRelaxDeps = (old.pythonRelaxDeps or [ ]) ++ [ "kubernetes" ];
          });
          azure-cli = pkgs.azure-cli.withExtensions ([ devops containerapp ] ++ (with pkgs.azure-cli.extensions; [
            ssh
            account
            application-insights
            resource-graph
            log-analytics
          ]));
        in
        {
          inherit azure-cli;
          default = azure-cli;
        });

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/az";
        };
      });

      checks = forAllSystems (system: {
        azure-cli = self.packages.${system}.default;
      });
    };
}
