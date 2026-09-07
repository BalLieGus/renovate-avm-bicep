# Renovate AVM Bicep Modules

This repository demonstrates automated version updates for Azure Verified Modules (AVM) referenced from Bicep files. GitHub Actions runs Renovate, which scans supported module references and opens pull requests for available upgrades.

## Components

### `.github/workflows/modules-updater.yaml`

The workflow runs on `ubuntu-latest` and invokes `renovatebot/github-action@v44.0.5` with the repository `GITHUB_TOKEN`. Its permissions allow Renovate to inspect repository content and create branches, commits, issues, checks, and pull requests.

It can currently be started from the **Actions** tab with `workflow_dispatch`. The scheduled daily run at 03:00 UTC is present but commented out. To enable it, uncomment:

```yaml
schedule:
  - cron: "0 3 * * *"
```

The concurrency group allows only one run of this workflow at a time; a new run waits for an active one to finish. Renovate debug logging is enabled through `LOG_LEVEL: 'debug'`.

### `.github/workflows/helpers/renovate-config.json`

This is the configuration file passed to Renovate by the workflow. It extends Renovate's `config:recommended` preset and defines a custom regex manager for AVM Bicep module references.

The manager scans every `.bicep` file for references in this form:

```bicep
module example 'br/public:avm/res/resources/deployment-script:0.5.2' = {
```

Only public registry references beginning with `br/public:` and versions in `major.minor.patch` form are matched. For each match, Renovate queries the corresponding Microsoft Container Registry tag list at:

```text
https://mcr.microsoft.com/v2/bicep/<module-path>/tags/list
```

Versions use `semver-coerced` comparison, so Renovate can determine the newest compatible SemVer release.

## How Version Updates Work

When the workflow runs, Renovate updates AVM module references in this sequence:

1. It scans every file whose name ends in `.bicep`.
2. It finds text matching `br/public:<module-path>:<major>.<minor>.<patch>`. For example, `br/public:avm/res/resources/deployment-script:0.5.2` identifies the module path `avm/res/resources/deployment-script` and current version `0.5.2`.
3. It requests the tag list for that module from Microsoft Container Registry. The example above becomes `https://mcr.microsoft.com/v2/bicep/avm/res/resources/deployment-script/tags/list`.
4. It transforms the returned registry tags into Renovate releases, compares them with the current version using SemVer, and selects available newer versions.
5. For each selected update, Renovate changes only the version segment in the Bicep module reference, such as `:0.5.2` to `:0.5.3`.
6. It creates a branch and pull request using the configured commit-message policy. The pull request includes the module changelog link; minor and major version updates also carry the breaking-change warning suffix.

References with a non-public registry alias, a version that does not contain exactly three numeric components, or a format that does not match the configured expression are not managed by this workflow.

## Update Policy

All Renovate concurrency limits are set to `0`, meaning the configuration does not impose limits on concurrent branches, pull requests, or pull requests per hour.

Patch updates produce ordinary Renovate pull requests. Minor and major updates use the same AVM changelog link but append `:warning:possible breaking change:warning:` to the commit message, making higher-risk upgrades easier to identify during review.

Changelog links point to the matching module path in the Azure Bicep Registry Modules repository.

## Scope and Safety

`autodiscover` is enabled. Renovate can therefore discover and process every repository that the token used by the GitHub Actions runner is allowed to access. Restrict the token's repository access or replace `autodiscover` with an explicit repository list when this workflow should update only selected repositories.

Review each generated pull request before merging, particularly minor and major updates. Confirm that the target module version exists, review the linked changelog, and validate the affected Bicep deployment in the intended environment.