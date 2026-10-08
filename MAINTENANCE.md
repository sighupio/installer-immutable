# SD Immutable Installer Maintenance Guide

## Versioning

The installer's versioning is **NOT** Semantic Versioning. The version of the installer is `v<maximum version of Kubernetes supported/tested>`. If a release includes fixes to the roles, bumps dependencies, etc. but it does NOT change the maximum supported version of Kubernetes, add the `-rev.X` suffix. For example, if the installer supports Kubernetes `v1.35.5` as maximum, a release of the installer must be `v1.35.5`, and a second release of the installer that does not change the maximum Kubernetes version is released, it should have the `v1.35.5-rev.1` version.

## Releasing a new version

New releases are performed via CI pipelines. To trigger a new release:

1. Make sure that you have the `/docs/releases/<version>.md` file ready with the release notes (IMPORTANT: this file is not a changelog, but releases notes in human readable format with just the relevant information for the users).
2. Make sure that CI linting and tests are green on `main`.
3. Tag a release candidate if needed, using the tag format `v<version>-rc.<rc numnber>` (for example, `v1.35.5-rc.0`).
4. Tag the release with `v<version>` (for example, `v1.35.5`) to trigger the release.

## Bumping a system extension

To change the version of a system extension (for example etcd or containerd) for one or more Kubernetes versions, use the `bump-sysext` task. It reads the checksums from the `SHA256SUMS` file of the [installer-immutable-sysext](https://github.com/sighupio/installer-immutable-sysext/releases) release and updates the URLs and checksums in `immutable.yaml`:

```sh
mise run bump-sysext -n docs/releases/v1.36.5.md etcd v3.6.15 1.35.9 1.36.5
```

The `-n` option is optional. It also updates the package tables of the release notes. Update the other text of the release notes yourself.

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
| `mise run docs`        | Generate the variable reference of every role README (see below).            |
| `mise run docs-check`  | Check that every role README is up to date; writes nothing.                  |
| `mise run test:download-retries` | Check that every `get_url` task of the roles has a retry (see `tests/download-retries/README.md`). |

> Note: `mise run lint` runs `ansible-lint` with `profile: production` and `strict: true` by default — there is no looser local profile. Findings against this profile are tracked as follow-up work and are not gated by this section. Run `mise run fmt-check && mise run fmt` to clean YAML formatting drift before sending a PR.

If the system already has a broken `/usr/bin/ansible-lint`, prefer `mise exec -- ansible-lint ...` or activate `mise` in your shell so the pinned version wins on `PATH`.

## Role documentation

The `README.md` of every role has two parts:

- a hand-written part for the users of the installer: a level-1 heading with the role name, an introduction that says
  what the role does and when furyctl runs it, a `## Requirements` section, and any other section the role needs;
- the variable reference, which [ansible-docsmith](https://github.com/foundata/ansible-docsmith) generates from the
  `meta/argument_specs.yml` of the role with the template `docs/templates/role-readme.md.j2`.

The variable reference is the text between these two markers:

```markdown
<!-- ANSIBLE DOCSMITH MAIN START -->
<!-- ANSIBLE DOCSMITH MAIN END -->
```

That text is generated: never edit it by hand, because the next generation overwrites it and `mise run docs-check` fails
until then. To change it, change the argument spec (or the template) and generate again. Everything outside the markers is
written by hand and is never touched by the generator.

Run `mise run docs` after changing an argument spec, and commit the READMEs it updates. It rewrites only the text between
the markers of `roles/*/README.md`; it does not touch the `defaults/` files.

```sh
mise run docs
```

Run `mise run docs-check` before sending a pull request; CI runs it too, in the `docs-check` step of the QA pipeline. It
changes no file and fails when a README is not up to date or has no markers, when a variable of a `defaults/` file is
missing from the argument spec, when a `default` of the argument spec differs from the `defaults/` file, when a role
README breaks the Markdown rules of `.markdownlint.yaml`, or when a role README still has the placeholder text (`FIXME`)
of a README that the generator created.

```sh
mise run docs-check
```

### Writing the argument specs

- Write every `short_description` and `description` for someone who operates a cluster with furyctl and has never opened
  this repository: say what the variable controls and what its value changes. Mark code, values and option names with
  Ansible markup, `C(...)`, `V(...)` and `O(...)`; the generator turns them into Markdown. Write a placeholder between
  angle brackets inside `C(...)`, so that it is not taken for HTML.
- A description can be a list of paragraphs. The table of the README shows the first paragraph; the other paragraphs,
  the choices, a default that spans several lines and nested options go to a details block after the table.
- In the `main` entry point, give every variable whose value in `defaults/main.yml` (`defaults/main.yaml` in the `sysctl`
  role) is a literal a `default` with the same literal value. `mise run docs-check` fails when the two differ.
- Never give a templated default, a value that contains `{{`, as `default` in an argument spec: Ansible resolves it when the
  role starts, and the play can fail. Leave the `default` out and describe the default in words, for example "Defaults to
  the fully qualified domain name of the node.".
- Entry points named after a task file, such as `preflight.yml`, cannot have a `default` either: the generator looks for a
  `defaults/<entry point>.yml` file that does not exist. The README of these roles links to `defaults/main.yml` instead.

### Documenting a new role

1. Write `meta/argument_specs.yml`, with a description for the role, for every entry point and for every variable, and the
   literal defaults of the `main` entry point.
2. Write `README.md` with the hand-written part and the two markers, with nothing between them. Without a README, the
   generator creates one with placeholder text that must be replaced.
3. Run `mise run docs`, then `mise run docs-check`.
4. Add the role to the table of roles of the repository `README.md`.
