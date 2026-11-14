# Maintenance of the CIS benchmark tool

This guide is for the maintainers of the tool and for anyone who contributes to it. How to
use the tool is in [README.md](README.md).

The tool runs the verification SIGHUP keeps for the
[on-premises installer](https://github.com/sighupio/installer-on-premises): the
[kube-bench](https://github.com/aquasecurity/kube-bench) version and the profiles under
`utils/kube-bench`. Nothing here is decided in this repository first. The tool reports
what kube-bench finds and compares it with nothing.

The commands below run from the root of the repository, with the tools that `mise install`
provides. `mise run check:cis-benchmark-profiles` and the download of kube-bench need
network access to GitHub.

## Bumping kube-bench

Do it when installer-on-premises moves its pin (`utils/kube-bench/README.md` there).

1. In `vars/versions.yml`, set `cis_kube_bench_version` and both entries of
   `cis_kube_bench_sha256`. Take each sha256 from `kube-bench_<version>_checksums.txt` of
   the [kube-bench release](https://github.com/aquasecurity/kube-bench/releases), the
   lines of `linux_amd64.tar.gz` and `linux_arm64.tar.gz`. Never compute them from a
   tarball you downloaded.
2. Update the version and the date in the comment of `vars/versions.yml`.
3. Run `tools/cis-benchmark/scripts/sync-profiles.sh`, which writes the new version in
   `profiles/PROVENANCE.md`.
4. Run `mise run test:cis-benchmark`. The version is in the reports, so regenerate the
   golden files (see below).
5. Go through the release checklist.

## Re-syncing the profiles

Do it when `utils/kube-bench` changes in installer-on-premises.

1. Run `tools/cis-benchmark/scripts/sync-profiles.sh --ref <commit>`, or
   `sync-profiles.sh --source <checkout>` to read a local checkout without network
   access. It rebuilds `profiles/`, applies the patches of `profiles/overlay/`, and
   rewrites the tables of `profiles/PROVENANCE.md` and `cis_profiles_source_commit` in
   `vars/versions.yml`.
2. Review the diff of `profiles/`.
3. If a patch of the overlay no longer applies, the script stops and names it. Fix the
   patch, or remove it and its section of `PROVENANCE.md` when upstream made it
   unnecessary, and run the script again.
4. Run `mise run check:cis-benchmark-profiles`. It changes no file and fails on any
   difference between `profiles/`, `PROVENANCE.md` and what the recorded commit produces.
   CI runs it too.
5. Run `mise run test:cis-benchmark`. If the texts of the checks changed, regenerate the
   golden files (see below).

## Adding an overlay patch

A patch is for a check whose audit reads a path or a mechanism that does not exist on an
Immutable node. A check that fails because the node is not compliant is a finding: do not
patch it and do not skip it.

1. Write the patch against `profiles/` as `profiles/overlay/NN-<what>.patch`, with paths
   like `a/cis-1.12/node.yaml`. Patches apply in the order of their names.
2. Justify it in `profiles/PROVENANCE.md`: add a section `### NN-<what>.patch` with these
   three entries, and remove the sentence that says the overlay is empty.
   - **Checks:** the identifiers of the checks the patch changes.
   - **Flatcar fact:** what differs on Flatcar and makes the upstream audit read the wrong
     place.
   - **Evidence:** the excerpt of a raw result or the command output that shows it.
3. Run `tools/cis-benchmark/scripts/sync-profiles.sh`, then
   `mise run check:cis-benchmark-profiles`, which refuses a patch that `PROVENANCE.md`
   does not justify.

## Handling a new Kubernetes minor

When `immutable.yaml` gains a Kubernetes minor, look for it in the `version_mapping` of
`profiles/config.yaml`.

- If it is there, nothing is needed.
- If it is not, the fallback applies: the tool runs the benchmark of the closest earlier
  minor that is mapped, and the summary says which one. Add the version to the cases of
  `tests/render.yml`.
- When installer-on-premises maps the minor, re-sync the profiles. When the minor comes
  with a new benchmark, re-syncing vendors its profiles.

## Regenerating the golden files

After a change of a template, a fixture or a pinned version that is meant to change the
reports:

```sh
ansible-playbook tools/cis-benchmark/tests/render.yml -e cis_update_golden=true
git diff tools/cis-benchmark/tests/golden
mise run test:cis-benchmark
```

Review the diff: the files under `tests/golden` are what `mise run test:cis-benchmark`
compares the rendered fixtures with. With `cis_update_golden` the comparison always
passes, so run the test again without it.

## Tests

`mise run test:cis-benchmark` runs, on localhost, without a node or network access:

- `tests/render.yml`: the validation of the inputs, the version mapping, the targets of
  every role, the removal of kube-bench from a node, the name of the cluster, the fail
  policy, and the reports rendered from the fixtures of `tests/fixtures`, compared with
  `tests/golden`;
- `tests/run-sh.sh`: `run.sh` against fake furyctl folders, with a stub
  `ansible-playbook` that records what it receives.

The play of the nodes and the download need a cluster and network access: the
end-to-end run below covers them.

## Release checklist

Before a release of the installer that changes the tool:

1. The gates pass. CI runs all of them:

   ```sh
   mise run lint
   mise run fmt-check
   mise run test:argument-specs
   mise run lint:cis-benchmark
   mise run test:cis-benchmark
   mise run check:cis-benchmark-profiles
   ```

2. The end-to-end run is done on a real Immutable cluster and recorded in
   `tests/E2E.md` (see below).
3. The release note of the installer, `docs/releases/unreleased.md`, says what changed in
   the tool.

### The end-to-end run

Run the tool as a user would on a real Immutable cluster, from a checkout of the change,
or from the copy furyctl vendors once a release contains the tool:

1. with `run.sh`;
2. a second time, to show that a run is repeatable;
3. with `-e cis_fail_on_fail=false -e cis_keep_on_node=true`;
4. through `mise run cis-benchmark`, which also removes what the third run kept.

Record the evidence in `tests/E2E.md` with these sections:

- **Runs**: a table with the columns `Run`, `Command`, `Exit code`, `Output folder` and
  `Reports written`, one row per run above.
- **Totals**: a table with the columns `Node`, `Role`, `PASS`, `FAIL`, `WARN` and `INFO`,
  one row per node.
- **Observations**: a list of what the runs showed, each item followed by how it was
  checked:
  - the same totals per node in both runs;
  - a different output folder for each run;
  - the install directory kept by the third run and removed by the fourth;
  - the summary, node reports and raw files written by every run;
  - the exit code of every run matching the fail policy.
- **FAIL results**: a table with the columns `Check`, `Nodes` and `Classification`, where
  the classification is `path/overlay` for a check that needs an overlay patch and
  `genuine finding` for a node that is not compliant. "None." when no check failed.

Name the nodes by role and index only (`cp1`, `worker1`), and the furyctl folder as
`<furyctl-dir>`: the evidence holds no host name, address, user, key or token.
