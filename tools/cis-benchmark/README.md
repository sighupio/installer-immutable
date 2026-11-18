# CIS benchmark tool

## What the tool is

This tool runs the [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
with [kube-bench](https://github.com/aquasecurity/kube-bench) on every node of a cluster
that furyctl installed with the Immutable installer, and reports what it found: one
Markdown report per node, with every check that failed or warned, and a summary of the
cluster.

The verification is the one SIGHUP runs for the
[on-premises installer](https://github.com/sighupio/installer-on-premises): the same
kube-bench release, pinned and verified by checksum, and the same kube-bench profiles,
vendored in `profiles/`. The tool reports the results as they are: it does not compare
them with an expected result.

## What the tool is not

- The tool is not part of the installation: furyctl never calls it and no role uses it.
- It does not harden anything. A `FAIL` it reports is a finding to look at, not something
  the tool fixes. On the nodes it only writes `/opt/kube-bench` for the duration of the
  run, and removes it at the end (see [Security](#security)).
- The load balancers are out of scope: they are not in the inventory of the cluster, and
  kube-bench has no checks for HAProxy.
- The `policies` target (section 5 of the benchmark) is out of scope: it needs access to
  the API of the cluster, and the profiles do not run it.

## Prerequisites

- A furyctl folder of an Immutable cluster: the directory that holds `.furyctl/`, where
  furyctl rendered the inventory and the `ansible.cfg` of the cluster
  (`.furyctl/<cluster-name>/kubernetes/hosts.yaml` and `ansible.cfg`). The tool uses the
  ansible-core that furyctl installed under `.furyctl/bin/ansible/<version>/` when it is
  there, the newest one when furyctl installed several, and otherwise the
  `ansible-playbook` on your `PATH`.
- SSH access as furyctl uses it: the user and the key of that inventory, from the machine
  that runs the tool to every node.
- Access to the kube-bench release on GitHub from that machine. The nodes download
  nothing. Without network access, see [A checksum mismatch](#a-checksum-mismatch).

The tool lives in the installer repository. furyctl vendors the whole repository in the
cluster folder, so from the first installer release that contains the tool it is also at
`.furyctl/<cluster-name>/vendor/installers/immutable/tools/cis-benchmark/`, at the
version of the installer the cluster runs. It is not in the release tarball.

## Quick start

From a checkout of the installer repository, for the cluster folder
`~/clusters/my-cluster`:

```sh
tools/cis-benchmark/run.sh ~/clusters/my-cluster
```

The same through mise, from any directory of the checkout. A relative furyctl folder is
resolved from the directory you run mise in:

```sh
mise run cis-benchmark -- ~/clusters/my-cluster
```

With the copy that furyctl vendored, on a cluster installed with an installer release
that contains the tool:

```sh
~/clusters/my-cluster/.furyctl/my-cluster/vendor/installers/immutable/tools/cis-benchmark/run.sh ~/clusters/my-cluster
```

`run.sh` prints the folder of the reports on the line `Reports:`,
`~/clusters/my-cluster/.furyctl/my-cluster/cis-benchmark/<UTC timestamp>/`. Open
`SUMMARY.md` there.

## Parameters

```sh
tools/cis-benchmark/run.sh [-h] <furyctl-dir> [cluster-name] [-- <ansible-playbook args>]
```

| Parameter | Required | Meaning |
| --- | --- | --- |
| `furyctl-dir` | yes | The directory that holds `.furyctl/`. |
| `cluster-name` | no | The folder of the cluster under `.furyctl/`. Omit it when only one folder there holds `kubernetes/hosts.yaml`. With none or several, `run.sh` stops and names the ones it found. |
| `ansible-playbook args` | no | What follows `--` is passed to `ansible-playbook`, for example the variables below. |
| `-h`, `--help` | no | Show the usage. |

```sh
tools/cis-benchmark/run.sh ~/clusters/my-cluster my-cluster
tools/cis-benchmark/run.sh ~/clusters/my-cluster -- -e cis_fail_on_fail=false
tools/cis-benchmark/run.sh ~/clusters/my-cluster my-cluster -- -e cis_keep_on_node=true
```

`run.sh` prints the cluster, the ansible-playbook it uses, the folder of the reports and
the command it runs, then exits with the exit code of `ansible-playbook`. It drops every
`ANSIBLE_*` variable set in your shell, so that the configuration furyctl rendered is the
one in use. It refuses to run when the folder of the reports already exists, which only
happens when two runs start in the same second.

The tool benchmarks every node of the inventory. `--limit` is not supported: Ansible
applies it to the plays that run on `localhost` too, which validate the inputs and write
the reports, so a limited run stops with an error before any node is contacted.

### Running the playbook directly

`run.sh` is a convenience. This is equivalent, except that it uses the `ansible-playbook`
on your `PATH`:

```sh
cd <furyctl-dir>/.furyctl/<cluster-name>/kubernetes
env -u ANSIBLE_COLLECTIONS_PATH ANSIBLE_CONFIG="$PWD/ansible.cfg" \
  ansible-playbook -i "$PWD/hosts.yaml" <path-to>/tools/cis-benchmark/cis-benchmark.yml \
  -e "{\"cis_output_dir\": \"$(dirname "$PWD")/cis-benchmark/$(date -u +%Y%m%dT%H%M%SZ)\"}"
```

Pass `cis_output_dir` as JSON, as above: in the `key=value` form Ansible splits the value
at the first space.

## Variables

Set them with `-e` after `--`.

| Variable | Default | Meaning |
| --- | --- | --- |
| `cis_output_dir` | required | Absolute path, without a trailing slash, of the folder the reports are written to. `run.sh` sets it. |
| `cis_fail_on_fail` | `true` | Exit non-zero when a check has the result `FAIL`. A node without a result fails the run whatever this is. |
| `cis_keep_on_node` | `false` | Leave `/opt/kube-bench` on the nodes, to debug. The next run replaces it, or remove it with `sudo rm -rf /opt/kube-bench` on each node. |
| `cis_benchmark` | resolved from `kubernetes_version` | The benchmark to run, `cis-1.11` or `cis-1.12`, instead of the one the Kubernetes version maps to. |
| `cis_cluster_name` | the folder under `.furyctl/` | The name of the cluster in the summary. |
| `cis_date` | the time the run starts | The date written in the reports. `run.sh` sets it to the time of the folder name. |

## What runs on each node

The groups of the inventory decide the kube-bench targets of a node:

| Role | Host is in | Targets |
| --- | --- | --- |
| Control plane with etcd | `control_plane`, and `etcd_on_control_plane` is true or not set | `master,etcd,controlplane,node` |
| Control plane without etcd | `control_plane`, and `etcd_on_control_plane` is false | `master,controlplane,node` |
| Dedicated etcd | `etcd` | `etcd` |
| Worker | `nodes` | `node` |

A host in several groups gets the targets of all of them.

| Target | Section | What it checks |
| --- | --- | --- |
| `master` | 1 | Files, API server, controller manager and scheduler of the control plane. |
| `etcd` | 2 | The configuration of etcd. |
| `controlplane` | 3 | Authentication and audit logging of the API server. |
| `node` | 4 | Files and configuration of the kubelet and kube-proxy. |

The benchmark follows the Kubernetes version of the inventory: 1.29 to 1.31 run
`cis-1.11`, 1.32 to 1.35 run `cis-1.12`. A later minor that the profiles do not map yet
falls back to the closest earlier one, and the summary says so.

## Output layout

```text
<furyctl-dir>/.furyctl/<cluster-name>/cis-benchmark/
  .downloads/                 kube-bench tarballs, reused by the next run
  <UTC timestamp>/
    SUMMARY.md                the cluster: the result, every node, the failures and warnings
    nodes/<short-name>.md     one report per node
    raw/<short-name>.json     what kube-bench wrote on the node
```

Every run has its own folder, named after the time it started, so a run never overwrites
an earlier one. Nothing else is written in the furyctl folder.

An excerpt of a summary, from the test fixtures:

```markdown
## Result

| Result | Count |
| --- | --- |
| Nodes with a result | 3 of 4 |
| PASS | 106 |
| FAIL | 1 |
| WARN | 7 |
| INFO | 15 |
| Nodes without a result | 1 |

## Nodes

| Node | Role | Targets | PASS | FAIL | WARN | INFO |
| --- | --- | --- | --- | --- | --- | --- |
| [cp1](nodes/cp1.md) | control-plane | master,etcd,controlplane,node | 81 | 0 | 5 | 11 |
| [etcd1](nodes/etcd1.md) | etcd | etcd | 7 | 0 | 0 | 0 |
| [worker1](nodes/worker1.md) | worker | node | 18 | 1 | 2 | 4 |
| [worker2](nodes/worker2.md) | worker | node | no result | no result | no result | no result |

## Failures

| Check | Description | Nodes |
| --- | --- | --- |
| 4.2.1 | Ensure that the --anonymous-auth argument is set to false (Automated) | worker1 |
```

And of a node report:

```markdown
## Totals

| Target | Section | Description | PASS | FAIL | WARN | INFO |
| --- | --- | --- | --- | --- | --- | --- |
| master | 1 | Control Plane Security Configuration | 53 | 0 | 3 | 4 |
| etcd | 2 | Etcd Node Configuration | 7 | 0 | 0 | 0 |
| controlplane | 3 | Control Plane Configuration | 1 | 0 | 1 | 3 |
| node | 4 | Worker Node Security Configuration | 20 | 0 | 1 | 4 |
| Total |  |  | 81 | 0 | 5 | 11 |

## Failures

None.
```

The full files are in `tests/golden/`.

## Reading the results

Every check of the benchmark has one of four results:

- `PASS`: the node does what the check asks.
- `FAIL`: the node does not. It is a finding: the report gives the remediation the
  benchmark proposes. The tool applies nothing.
- `WARN`: kube-bench could not decide, because the check is manual or its audit found
  nothing to test. The report gives the remediation the benchmark proposes.
- `INFO`: the check did not run. Most are declared skips: the checks the profiles skip on
  purpose because they do not apply to how SIGHUP installs Kubernetes, for example the
  checks of an etcd pod manifest when etcd runs as a systemd service. The node report
  lists them.

Start from `SUMMARY.md`:

- **Result**: how many nodes gave a result, and the number of `PASS`, `FAIL`, `WARN` and
  `INFO` results over all of them.
- **Nodes**: one row per node with its counts, or `no result` when the node gave none.
- **Failures** and **Warnings**: every check that did not pass, with the nodes it occurs
  on.
- **Nodes without a result**: the error of every node that gave no result.

Then open the report of a node, `nodes/<short-name>.md`, for its counts per section, the
remediation of each of its failures and warnings, and its declared skips.

The result of a check can change between two runs when what its audit reads changes.
1.1.9 and 1.1.10, for example, read the files of `/var/lib/cni`, and warn when there is
none: that is the audit of the upstream profiles, the same on any operating system.

## Exit codes

| Condition | Reports | Exit status |
| --- | --- | --- |
| No FAIL and every node has a result | written | zero |
| A FAIL with `cis_fail_on_fail` true | written | non-zero |
| A FAIL with `cis_fail_on_fail` false | written | zero |
| A node without a result | written | non-zero |
| An input is not valid, kube-bench cannot be downloaded, or `--limit` is set | not written: the run stops before any node is contacted | non-zero |

A `WARN` never fails the run. `run.sh` exits with the code of `ansible-playbook`, and
non-zero when its own arguments are wrong.

## Troubleshooting

### An unreachable host

The run goes on with the other nodes. The report of the host, `nodes/<short-name>.md`,
holds the error instead of results, the summary lists it under **Nodes without a result**,
and the run exits non-zero. Check that furyctl itself reaches the node with the same
inventory, then run the tool again: every run benchmarks all the nodes.

A host lost in the middle of its benchmark is reported the same way, but the tool cannot
remove `/opt/kube-bench` from it: the next run replaces it.

### An unsupported Kubernetes version

A minor later than the ones the profiles map falls back to the closest earlier one, and
the row `Fallback` of the summary says which. When no earlier minor is mapped, the run
stops before it contacts a node and names the version. Choose the benchmark yourself:

```sh
tools/cis-benchmark/run.sh ~/clusters/my-cluster -- -e cis_benchmark=cis-1.12
```

### A checksum mismatch

The run stops before it contacts a node when the tarball it downloaded does not have the
sha256 pinned in `vars/versions.yml`. Remove the tarball from
`<furyctl-dir>/.furyctl/<cluster-name>/cis-benchmark/.downloads/` and run again. If it
fails again, do not change the pinned value: download the tarball
`kube-bench_<version>_linux_<amd64|arm64>.tar.gz` from the
[kube-bench releases](https://github.com/aquasecurity/kube-bench/releases) and compare it
with the checksums file of the release.

Without network access, put that tarball in `.downloads/` beforehand. A tarball with the
pinned sha256 is not downloaded again.

## Security

### What runs as root on the nodes

The playbook connects as furyctl does and becomes root to copy kube-bench and the
profiles to `/opt/kube-bench`, and to run kube-bench, which reads the configuration files
and the processes of the node. It writes to `/opt/kube-bench` only, restarts no service
and copies no kubeconfig: on a control plane kube-bench is pointed at the `admin.conf`
that kubeadm already wrote there. The nodes download nothing.

### What is cleaned up on the nodes

`/opt/kube-bench` is removed from every node the run reached, also when kube-bench failed
there. It stays when you ask for it with `cis_keep_on_node`, and on a node lost in the
middle of the run.

### What the reports contain

The Markdown reports hold the identifier, the text and the remediation of the checks, and
for a node without a result its error, never the output of the audit commands. That
output stays in `raw/<short-name>.json`: it includes the command lines and the
environment of the processes kube-bench audits, for example the `ETCD_*` variables of
etcd. The output folders have mode `0700` and their files `0600`. The tool reads the SSH
key through the inventory and never copies or prints a key, a token or a kubeconfig.

## Maintenance

See [MAINTENANCE.md](MAINTENANCE.md).
