# node-maintenance test

Runs the three entry points of the `node-maintenance` role, `preflight.yml`, `drain.yml` and
`uncordon.yml`, on localhost against a stub `kubectl` — no cluster, no network, no privilege.
The role decides, opens and closes the cordon and drain window of a node during an upgrade; a
mistake there leaves a node cordoned after an upgrade that ends with success.

## Run

```bash
mise run test:node-maintenance
```

The task prints one line per case, `<case>: ok` or `<case>: FAILED`, and exits 1 when a case
failed. A failed case also prints the check that failed. To run some cases only, and to see the
output of `ansible-playbook` of a failed case, call the script:

```bash
tests/node-maintenance/run.sh -v failed-run second-run
```

## How it works

- **Stub** — `kubectl-stub.sh` takes the place of `kubectl` through the role variable
  `kubectl_bin`. It keeps the state of one node (kubelet version, cordoned or not, annotations)
  in a file and appends every call to a log, both under a temporary directory that the script
  removes at the end.
- **Order** — `window.yml` includes the entry points in the order and under the `when`
  conditions of the upgrade playbooks of the distribution: `preflight.yml`, then `drain.yml`
  and `uncordon.yml` only when `node_upgrade_drain_required` is true. `entry-point.yml`
  includes one entry point on its own.
- **Checks** — each case sets the state of the node, runs a playbook, and checks the exit code,
  the final state of the node and the calls in the log.

## Cases

| Case | What it checks |
| --- | --- |
| `drain-marks-first` | `drain.yml` annotates the node before it drains it. |
| `failed-annotate` | When the annotate fails, the play fails and the node is not drained. |
| `failed-run` | A worker at its target that is cordoned and marked needs the window. |
| `failed-run-control-plane` | The same for a control plane. |
| `failed-marker-read` | When the read of the marker fails, the play fails. |
| `healthy-at-target` | A node at its target with no marker needs no window. |
| `hand-cordoned` | A node cordoned by hand, with no marker, is not drained and stays cordoned. |
| `behind-target` | A worker behind the target Kubernetes version needs the window. |
| `marked-outside-upgrade` | A marked node needs the window in a run that is not an upgrade too. |
| `os-reboot-pending` | A control plane with no marker and a pending OS reboot needs the window. |
| `sysext-changed` | A worker with no marker whose system extensions changed needs the window. |
| `full-window` | A full window ends with a schedulable node and no marker. |
| `second-run` | After a run that stops after the drain, the next run uncordons the node. |
| `pod-wait-fails` | When the pod wait fails, the node is schedulable and the marker is gone. |
| `absent-marker` | `uncordon.yml` does not fail when the node has no marker. |

## What it does not check

- That the stub answers like the `kubectl` of a real cluster. The upgrade of a real cluster
  with a failed run is a separate test.
- The steps of the upgrade playbooks between the drain and the uncordon (the roles, the reboot,
  the sanity check): they need a node.
- The retry of a failed drain, and a pod wait of more than one retry.

## Files

- `run.sh` — the cases and their checks.
- `kubectl-stub.sh` — the stub `kubectl`; its header describes the state file.
- `window.yml`, `entry-point.yml` — the playbooks.
- `vars.yml` — the variables of an upgrade; the marker key is the default of the role.
- `inventory.ini` — one worker (`worker1`) and one control plane (`cp1`), both localhost.

A new case needs a `case_<name>` function in `run.sh` and its name in the `cases` list.
