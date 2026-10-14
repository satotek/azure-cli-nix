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
          pkgs = import nixpkgs { inherit system; };
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
