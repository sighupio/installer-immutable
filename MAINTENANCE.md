# SD Immutable Installer Maintenance Guide

## Versioning

The installer's versioning is **NOT** Semantic Versioning. The version of the installer is `v<maximum version of Kubernetes supported/tested>`. If a release includes fixes to the roles, bumps dependencies, etc. but it does NOT change the maximum supported version of Kubernetes, add the `-rev.X` suffix. For example, if the installer supports Kubernetes `v1.35.5` as maximum, a release of the installer must be `v1.35.5`, and a second release of the installer that does not change the maximum Kubernetes version is released, it should have the `v1.35.5-rev.1` version.

## Releasing a new version

New releases are performed via CI pipelines. To trigger a new release:

1. Make sure that you have the `/docs/releases/<version>.md` file ready with the release notes (IMPORTANT: this file is not a changelog, but releases notes in human readable format with just the relevant information for the users).
2. Make sure that CI linting and tests are green on `main`.
3. Tag a release candidate if needed, using the tag format `v<version>-rc.<rc numnber>` (for example, `v1.35.5-rc.0`).
4. Tag the release with `v<version>` (for example, `v1.35.5`) to trigger the release.

## Lint & format

> [!NOTE]
> Linting tasks are executed automatically in CI on every push.

The repository pins its lint and format tool chain through [`mise`](https://mise.jdx.dev/):

```sh
mise install
```

This installs all the needed tools (and their dependencies) in your machine.

Tasks live under `[tasks]` in `mise.toml` (no `Makefile`). Configuration is in `.yamlfmt`, `.yamllint`, and `.ansible-lint` at the repo root.

| Task                   | What it does                                                                 |
| ---------------------- | ---------------------------------------------------------------------------- |
| `mise run fmt`         | Rewrite YAML files in place with `yamlfmt`.                                  |
| `mise run fmt-check`   | Check YAML formatting without writing; exits non-zero if changes are needed. |
| `mise run lint`        | Run `yamllint` and `ansible-lint --profile production --strict`.             |
| `mise run lint-prod`   | Alias of `mise run lint` (the `production` profile is the default).          |

> Note: `mise run lint` runs `ansible-lint` with `profile: production` and `strict: true` by default — there is no looser local profile. Findings against this profile are tracked as follow-up work and are not gated by this section. Run `mise run fmt-check && mise run fmt` to clean YAML formatting drift before sending a PR.

If the system already has a broken `/usr/bin/ansible-lint`, prefer `mise exec -- ansible-lint ...` or activate `mise` in your shell so the pinned version wins on `PATH`.

