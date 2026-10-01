# End-to-end evidence

The tool was run end to end on 2026-09-28 against an Immutable cluster installed from
scratch the same day with furyctl: distribution v1.35.0, installer v1.35.5, Kubernetes
1.35.5 on Flatcar, two load balancers, three control planes with etcd and three workers,
all `x86-64`. The layout of this file is in [MAINTENANCE.md](../MAINTENANCE.md).

`<furyctl-dir>` is the furyctl folder of the cluster and `<checkout>` a checkout of this
change. No installer release contains the tool yet, so the runs used the checkout.

## Runs

Every run used the ansible-core 2.21.0 that furyctl ships in
`<furyctl-dir>/.furyctl/bin/ansible/2.21.0/venv/bin/`, resolved the benchmark `cis-1.12`
without a fallback, and ran kube-bench 0.12.0.

| Run | Command | Exit code | Output folder | Reports written |
| --- | --- | --- | --- | --- |
| With run.sh | `<checkout>/tools/cis-benchmark/run.sh <furyctl-dir>` | 0 | `20260928T091112Z` | `SUMMARY.md`, 6 node reports, 6 raw files |
| Repeated with run.sh | `<checkout>/tools/cis-benchmark/run.sh <furyctl-dir>` | 0 | `20260928T102907Z` | `SUMMARY.md`, 6 node reports, 6 raw files |
| Keeping kube-bench, without failing on FAIL | `<checkout>/tools/cis-benchmark/run.sh <furyctl-dir> -- -e cis_fail_on_fail=false -e cis_keep_on_node=true` | 0 | `20260928T102959Z` | `SUMMARY.md`, 6 node reports, 6 raw files |
| Through mise run cis-benchmark | `mise run cis-benchmark -- <furyctl-dir>`, from `<checkout>` | 0 | `20260928T103050Z` | `SUMMARY.md`, 6 node reports, 6 raw files |

## Totals

The totals of the four runs are the same.

| Node | Role | PASS | FAIL | WARN | INFO |
| --- | --- | --- | --- | --- | --- |
| cp1 | control-plane | 80 | 0 | 6 | 11 |
| cp2 | control-plane | 80 | 0 | 6 | 11 |
| cp3 | control-plane | 80 | 0 | 6 | 11 |
| worker1 | worker | 21 | 0 | 0 | 4 |
| worker2 | worker | 21 | 0 | 0 | 4 |
| worker3 | worker | 21 | 0 | 0 | 4 |

The warnings, the same on the three control planes: 1.1.9 and 1.1.10 (no file under
`/var/lib/cni`), 1.2.20, 1.2.27, 1.2.28 and 3.1.2, all manual checks.

## Observations

- The same totals per node in every run: the `SUMMARY.md` and the six node reports of each
  run are identical to the ones of the first, the line of the date excluded (`diff` of the
  files without that line).
- A different output folder for each run: the four runs wrote to four folders named after
  the UTC time they started at, printed on the line `Reports:` of `run.sh`, and none
  touched the folder of another.
- The install directory kept by the third run and removed by the fourth: the task that
  removes `/opt/kube-bench` reported `changed` on the six nodes in the first, second and
  fourth runs, and was skipped on the six nodes in the third. The fourth run also removed
  the result the third one left (`changed` on the six nodes for the task that removes the
  result of an earlier run, `ok` in the other runs).
- The summary, node reports and raw files written by every run: every output folder holds
  `SUMMARY.md`, six files in `nodes/` and six in `raw/`, the folders with mode `0700` and
  the files with mode `0600`.
- The exit code of every run matching the fail policy: no check failed and every node gave
  a result, so the policy asks for the exit code 0 with and without `cis_fail_on_fail`,
  which is what the four runs returned. The cluster has no `FAIL`, so these runs do not
  show the exit code of a run with one: the fixture tests cover it.
- The cluster unchanged: its nodes stayed `Ready` and no pod failed after the runs.

No report holds a key, a token or a kubeconfig: a search of `SUMMARY.md` and `nodes/` of
every run for the markers of a private key, of a client key and of a token found nothing.

## FAIL results

None.

The overlay of the profiles stays empty: no check needs a patch for a path of Flatcar.
