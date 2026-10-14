# Azure CLI for Nix

Azure CLI with seven selected extensions:

- `azure-devops` (with `keyring` included as a Python dependency)
- `ssh`
- `account`
- `containerapp`
- `application-insights`
- `resource-graph`
- `log-analytics`

Build targets: `x86_64-linux`, `aarch64-linux`, and `aarch64-darwin`.
GitHub Actions builds each target; support is verified by its corresponding job.

## Run

```sh
nix run github:satotek/azure-cli-nix -- --version
nix build github:satotek/azure-cli-nix
```

## Home Manager

Add this flake to your inputs and pass inputs to your Home Manager modules:

```nix
inputs.azure-cli-nix.url = "github:satotek/azure-cli-nix";
```

```nix
{ inputs, pkgs, ... }:
{
  home.packages = [ inputs.azure-cli-nix.packages.${pkgs.stdenv.hostPlatform.system}.default ];
}
```

Keep this flake's pinned nixpkgs input when using its binary cache. Overriding
that input can produce different store paths requiring a rebuild.

## Authentication

Use the standard `az devops login` flow. No custom PAT wrapper is included.
On headless Linux systems, keyring can fall back to the CLI's PAT file storage.
The upstream CLI does not enforce `0600` on that file: use a restrictive umask
(such as `umask 077`) before first login and protect the configuration directory.
Credentials are not included in the flake or builds.

The Container Apps wheel pins Kubernetes 24.2.0, but the pinned nixpkgs provides
35.0.0. This flake relaxes that dependency constraint. Command loading is tested;
live operations using the Kubernetes client need separate validation.

## Weekly updates

The Update nixpkgs workflow runs every Thursday at 03:23 JST and can also be
started manually. It updates nixpkgs, validates the same lock file on all three
platforms, and publishes the outputs before creating and merging an update PR.
A failed platform blocks the merge. A concurrent change to main also blocks it
and requires a new run.

The schedule avoids the start of the hour and leaves time before 09:00 JST.
GitHub may delay scheduled runs, so completion by 09:00 is not guaranteed.

Configure the Cachix variable and secret described below. In GitHub repository
Settings > Actions > General, enable **Allow GitHub Actions to create and
approve pull requests**. Branch protection must permit the verified update PR
to merge; the workflow does not bypass protection rules. Updates made with
GITHUB_TOKEN do not trigger a new push workflow, so validation and cache
publication are completed within the update workflow itself.

Front Door Standard/Premium uses built-in `az afd` commands. The Classic
`front-door` extension is not included. `communication` is also not included
because it is not packaged in the pinned nixpkgs extension set.

## Optional binary cache

Builds work without Cachix. To publish prebuilt outputs:

1. Create a Cachix account and a public cache.
2. Set the GitHub repository variable `CACHIX_CACHE` to its name.
3. Store a cache-scoped write token in the GitHub Actions secret
   `CACHIX_AUTH_TOKEN`. Never commit the token.
4. Run the Build workflow. Uploads are disabled for pull requests.
5. Consumers can run `cachix use <cache-name>` to configure the cache.

The official Nix cache supplies existing dependencies; Cachix stores additional
outputs. Cache capacity and retention should be monitored after publishing.
