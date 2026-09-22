<!-- markdownlint-disable MD013 -->
# Replacement of an etcd member on the Immutable kind

Status: proposal.
Scope: `installer-immutable` (the `etcd` role) and `distribution` (the kubernetes apply playbook).
Written against `installer-immutable` `c88b94b`, `distribution` `b655882e`, and `furyctl` `624ef2c6`.
Related: `docs/IMMUTABLE_PREFLIGHT_DESIGN.md` in `sighupio/furyctl`.

## Summary

A control-plane node that you recreate cannot join the etcd cluster again. The node writes
`ETCD_INITIAL_CLUSTER_STATE=new` into `/etc/etcd/etcd.env`, so etcd tries to start a new cluster.

The value `existing` is the correct value for a recreated node. That change alone is not sufficient.
etcd also needs a new member registration, and it needs the correct member list.

This document gives the cause, the full replacement procedure, and two faults in the current plays that
block the procedure. It also gives the prior art from Cluster API, which supplies three of the safety
steps below, and it explains why a change to `kubeadm join` gives no help.

## A recreated node is a new member

etcd identifies a member by its **member ID**. The cluster assigns this ID at `member add`, and etcd
keeps it in the write-ahead log, under `/var/lib/etcd/member`. The name and the peer URLs are attributes
of that ID. They are not the identity. The `member update` command can change a peer URL, and the member
stays the same member.

The command `flatcar-install -d <installDisk>` deletes the data directory. It therefore deletes the
member ID. The node that comes back is a new member with the same address.

etcd has no operation for a member that returns without its data. The etcd documentation calls this
procedure "replace a failed member". Cluster API uses the same word.

The same hostname and the same IP address give no continuity to etcd. They give three conveniences to
the deployment:

- The static `ETCD_INITIAL_CLUSTER` map of names to peer URLs stays correct.
- The etcd server and peer certificates stay correct. `kubeadm-etcd.yml.j2` puts the hostname and
  `etcd_address` in the SANs.
- The `Node` object, the HAProxy backend list, and the kubeadm configuration stay correct.

The same address also has one cost. The entry of the old member holds the same name and the same peer
URL. You must remove that entry before you add the new member. Cluster API has no such cost, because it
never uses a member name a second time.

## The cause

`roles/etcd/defaults/main.yml:22` sets `etcd_initial_cluster_state: "new"`. No other file changes this
value. The furyctl inventory at `templates/kubernetes/immutable/hosts.yaml.tpl:227` in the
`distribution` repository sets `etcd_initial_cluster` and `etcd_endpoints`, but not the state.

As a result, `roles/etcd/templates/etcd.env.j2:9` writes `ETCD_INITIAL_CLUSTER_STATE=new` on every node,
on every apply.

etcd reads this variable at the first start of a member only. If `/var/lib/etcd/member` exists, etcd
reads the write-ahead log and ignores the variable. On a healthy node the wrong value is therefore
inert.

A node that you reinstall through PXE has an empty data directory. etcd then obeys the variable. With
`new`, etcd starts a cluster with a new cluster ID, and the other members refuse it.

## Why `existing` alone is not sufficient

With an empty data directory and the value `existing`, etcd must find itself in the member list of the
cluster. The entry of the old member is still in that list. That entry holds the old member ID and the
`started` status, so etcd refuses to start.

The correct procedure has six steps. The variable is only one of them:

1. Make sure that the surviving members hold quorum after the change. See "Limits" below.
2. Remove the entry of the old member. Run `etcdctl member remove <member ID>` from a surviving node.
3. Add the new member as a learner. Run
   `etcdctl member add <name> --learner --peer-urls=https://<ip>:2380`.
4. On the replacement node, make sure that the data directory is empty. Set
   `ETCD_INITIAL_CLUSTER_STATE=existing`. Set `ETCD_INITIAL_CLUSTER` to the value that `member add`
   returns.
5. Start etcd on the replacement node. The learner then copies the data from the leader.
6. Run `etcdctl member promote <member ID>`. The command fails until the learner is in sync, so use a
   retry.

Step 3 uses a learner because a learner does not count for quorum. The cluster therefore cannot lose
quorum while the new member copies the data. Cluster API relies on the same property.

Step 4 has one detail that is easy to miss. The `member add` command returns the surviving members plus
the new member. The static list from `hosts.yaml.tpl` holds all the members of the configuration. If a
second member is also absent, the static list names a member that is not registered. etcd then stops
with the error `member count is unequal`.

The replacement path must therefore override `etcd_initial_cluster`. It must not use the static list.

> **NOTE:** Do not use `etcdctl snapshot restore` for one member. That command writes a new member ID
> and a new cluster ID. It is a recovery operation for a whole cluster.

## The four cases

The data directory decides the case, not the address. A node that keeps its data directory keeps its
member ID, and it rejoins the cluster with no help.

| Data directory | Address | Case | Action |
| --- | --- | --- | --- |
| survives | same | **rejoin** | none. etcd reads the write-ahead log, contacts the peers, and catches up. The state variable is inert |
| survives | new | rejoin with a new address | run `etcdctl member update <member ID> --peer-urls=<new URL>` |
| wiped | same | **replacement** (this document) | the six steps above |
| wiped | new | replacement | remove the old entry, then add. The same six steps |

Row 1 is reachable in this product. `flatcar-install` deletes the install disk only, and the node schema
passes `storage.additionalDisks` to the butane templates. A cluster that holds `/var/lib/etcd` on a
second disk therefore rejoins after a PXE reinstall, with no operator action.

The role detects its own case:

| `/var/lib/etcd/member` | The peers answer | Correct state | Action |
| --- | --- | --- | --- |
| absent | no | `new` | first bootstrap of the cluster |
| absent | yes | `existing` | the replacement: the six steps above |
| present | — | inert | do not change the file. This is the rejoin case |

The third row is important. On a node that holds data, the value has no effect. A change to the file has
an effect, because the role restarts etcd when the file changes. See the first fault below.

The "the peers answer" condition comes from etcd itself. Run `etcdctl member list` against the other
endpoints before the role renders `etcd.env`. The `etcd_endpoints` variable is already available to the
role.

This detection needs no data from furyctl.

## Prior art: Cluster API

Cluster API solves this problem with the `KubeadmControlPlane` controller (KCP). Its premise is
different from ours, and the difference explains why our path is harder.

KCP validates `MaxSurge` to be 0 or 1, and 1 is the default
(`controlplane/kubeadm/reconcilers/kubeadmcontrolplane/update.go:142`). A replacement goes from 3 nodes
to 4 nodes, and then back to 3. KCP creates a new machine with a **new name**, joins it, and then
deletes the old one.

For KCP, `kubeadm join --control-plane` therefore does a plain `member add` of a name that never
existed. There is no old entry, no old member ID, and no conflict.

The Immutable kind reinstalls the same hostname and the same IP address, because PXE selects the node by
its MAC address. We must remove the old entry and add the name again. Cluster API gives no help with
that part. It gives good help with the safety steps around it.

### What we take from it

| Mechanism | Cluster API source | Use here |
| --- | --- | --- |
| Add the member as a learner | `preflight.go:120` accounts for members in learner mode | step 3 above: a learner cannot break quorum |
| Move the leader before you remove a member | `ForwardEtcdLeadership`, `pkg/workload_cluster_etcd.go:94` | path B below: do not stack an election on a membership change |
| Send `member remove` to a surviving node | `RemoveEtcdMember`, `pkg/workload_cluster_etcd.go:54`, builds `remainingNodes` and excludes the member | step 2 above: use `delegate_to` |
| List the members first, and stop if the member is absent | the same function returns early when the member is already gone | the task file is then idempotent |
| Refuse to remove the last member | the same function has an explicit guard | a second guard below the quorum test |
| Compute quorum on the member list **after** the change | `targetEtcdClusterHealthy` in `preflight.go` | step 1 above |
| Remove the member after the drain, not before | `scale.go:164`: the cleanup hook runs after drain | path B below |
| One operation at a time | `scale.go:73`: the preflight checks force KCP to do one operation at a time | the `serial: 1` fault below |
| A result with named reasons, not a boolean | `checkHealthiness` returns two named flags plus an error | the same argument as the preflight design |

Cluster API adds no etcd member itself. `kubeadm join --control-plane` does that. Its controller only
removes members and moves the leader.

## Two faults that block the procedure

### The etcd play runs in parallel

In the `distribution` repository, `templates/kubernetes/immutable/apply.yaml.tpl` has the play
"Set up containerd and etcd on Control Plane". That play has no `serial` keyword, so it runs on all the
control-plane nodes at the same time.

`roles/etcd/tasks/main.yml:22` restarts etcd when `etcd.env` changes:

```yaml
- name: Restart etcd if configuration changed
  ansible.builtin.systemd:
    name: etcd
    daemon_reload: true
    state: restarted
  when: etcd_config.changed and not (etcd_upgrade | default(false) | bool)
```

> **CAUTION:** Do not change `etcd.env` while the play runs in parallel. Ansible restarts every etcd
> member at the same time, and the cluster loses quorum.

This fault is present today, and it is independent of the replacement. Any change to the file has this
result. Examples are a new cipher suite, a new metrics port, or a global change of the cluster state.

The replacement needs the same fix for a second reason. Two recreated nodes in parallel both run
`member remove` and `member add`, and the two operations race. Cluster API prevents the same race with
its preflight gate, which forces one operation at a time.

The play "Set up Kubernetes Control Plane", immediately below, already uses `serial: 1`. Give the etcd
role its own play with `serial: 1`. Do not serialize containerd with it.

### The member list comes from the static configuration

`etcd_initial_cluster` always holds every member of `furyctl.yaml`. The replacement needs the list that
`member add` returns. The role must accept an override for this variable on the replacement path.

## Limits

Compute quorum on the member list **after** the change, not before it. This is the test that Cluster API
uses in `targetEtcdClusterHealthy`.

The procedure works while the surviving members hold quorum. Examples are one absent member of three, or
two absent members of five.

`etcd.env.j2` sets `ETCD_STRICT_RECONFIG_CHECK=true`. etcd therefore refuses a `member remove` command
that breaks quorum. The cluster is safe, but the error is not clear.

> **CAUTION:** If the cluster lost quorum, do not use this procedure. Restore the cluster from a
> snapshot.

The role must do the quorum test before it runs `member remove`. It must stop with a clear message when
quorum is absent. Keep the guard against the removal of the last member as a second test.

## The Kubernetes side

### kubeadm uses external etcd

`roles/kube-control-plane/templates/kubeadm.yml.j2:22` configures `etcd.external` with the endpoints and
the client certificates. With external etcd, kubeadm skips the `control-plane-join/etcd` phase. kubeadm
manages etcd membership in the stacked topology only.

A change to `kubeadm join --control-plane` therefore gives no help with the member replacement. The
`member add` that Cluster API gets from kubeadm is not available with external etcd. The six steps above
stay necessary.

### The installer runs `kubeadm init` on every node

`roles/kube-control-plane/tasks/main.yml:127` runs `kubeadm init` on every control-plane node. The task
runs when `/etc/kubernetes/super-admin.conf` is absent. Only the `kube-worker` role uses `kubeadm join`.

Each API server keeps no local state, and the PKI comes from the local `pki/` folder. A node that you
reinstall therefore runs `kubeadm init` again against the shared etcd cluster, and it returns to
service.

Two facts limit the effect of this design:

- `kubeadm init` does not run on a healthy apply, because `super-admin.conf` is present. The command
  runs at the first install and at a replacement only.
- The `ClusterConfiguration` is the same on every control-plane node. `kubernetes_apiserver_certSANs` is
  a variable of the `control_plane` group, not of a host. The `upload-config` phase therefore writes the
  same content each time.

### The phases with cluster-wide effects

These phases run again at every replacement:

| Phase | Effect at a replacement |
| --- | --- |
| `addon/coredns` | applies the CoreDNS deployment again. SD does not manage CoreDNS, so kubeadm owns it. A change that an operator made to the deployment is lost |
| `addon/kube-proxy` | applies the DaemonSet and the ConfigMap again. Already skipped when `kubeProxy.type` is `none` |
| `bootstrap-token` | creates the token and `cluster-info` again. This has no bad effect |

Add `addon/coredns` to `kubeadm_skip_phases` when the cluster already answers. The mechanism is
available. `roles/kube-control-plane/defaults/main.yml:6` holds the default `[]`,
`kubeadm.yml.j2:18` renders the value, and the `kubeProxy.type: none` case already uses it.

Use the probe from step 3 of path A for this condition. Do not add a second probe.

### Why not `kubeadm join`

A `join` command runs the node-local phases only. It applies no addon, it uploads no configuration, and
it creates no token. The prerequisites are available: the role copies `ca.crt`, `ca.key`,
`front-proxy-ca`, `sa.key` and `sa.pub`, and it computes `kubernetes_bootstrap_token` and
`kubernetes_ca_hash` with `run_once`.

The cost is a second mode in the role. One node must still run `init`, and the other nodes must `join`.
Today every control-plane node is the same. That property is correct for an immutable model, because you
can replace any node.

The test "am I the first node?" is also weak. The value `groups.control_plane[0]` depends on the order
of the inventory. The other test is "does the cluster answer?", which is the preflight state question
again.

> **NOTE:** The choice between `init` and `join` is the same choice as the etcd topology. External etcd
> makes `init` on every node correct, and we own the member operations. Stacked etcd makes `join`
> correct, and kubeadm owns the member operations. You cannot get the kubeadm member operations without
> a move of etcd into the control plane.

> **NOTE:** This document does not confirm the behavior of the stale `Node` object. The kubelet
> registers again with the same name and a new certificate. Do a test of this path before you trust it.

## Implementation

There are two paths. Path A repairs a node that you already reinstalled. Path B prepares a node before
you reinstall it. Path A is the fix for the reported failure. Path B is the safe workflow, and it can
come later.

### Path A: replace after the reinstall

Add one task file to the `etcd` role, for example `replace.yml`. Include it before the role renders
`etcd.env`.

1. Run `stat` on `{{ etcd_data_dir }}/member`. Register the result.
2. If the data directory holds data, set `etcd_initial_cluster_state` to the value in the current file.
   Then end the task file. This is the rejoin case, and it needs no action.
3. Run `etcdctl member list` against the endpoints of the other members. Do not fail on a non-zero
   return code.
4. If no endpoint answers, set `etcd_initial_cluster_state` to `new`. Then end the task file.
5. Do the quorum test on the member list after the change. If quorum is absent, stop with a clear
   message.
6. Find the entry of this node in the member list, by name or by peer URL. If the entry is absent,
   continue at step 8. This test makes the task file idempotent.
7. Run `etcdctl member remove <member ID>`. Use `delegate_to` to send the command from a surviving node.
8. Run `etcdctl member add {{ etcd_name }} --learner --peer-urls=https://{{ etcd_address }}:2380`. Use
   `delegate_to` for this command too.
9. Read `ETCD_INITIAL_CLUSTER` from the output of step 8. Set `etcd_initial_cluster` to that value.
10. Set `etcd_initial_cluster_state` to `existing`.

The role then renders `etcd.env` and starts etcd. Add one task after the start:

11. Run `etcdctl member promote <member ID>`. Use a retry, because the command fails until the learner
    is in sync.

In the `distribution` repository, move the `etcd` role into its own play in
`templates/kubernetes/immutable/apply.yaml.tpl`. Give that play `serial: 1`.

`roles/etcd/meta/argument_specs.yml` already documents `etcd_initial_cluster_state` with the choices
`new` and `existing`. Update its description to say that `replace.yml` computes the value.

### Path B: prepare a node before the reinstall

Add a second task file, for example `pre_replace.yml`. Run it against the node that you are about to
reinstall, while that node is still healthy.

1. Cordon and drain the node. The `node-maintenance` role already holds these task files.
2. If this member is the leader, move the leadership to another member. Run
   `etcdctl move-leader <target member ID>`. If this member is not the leader, do nothing.
3. Run `etcdctl member remove <member ID>` from a surviving node.
4. Reinstall the node.

Path A then finds no entry for the node at step 6, and it adds the learner directly. The two paths
therefore compose.

> **NOTE:** Path B applies to a planned replacement only. After an unplanned loss the member is already
> down, and the cluster elected a new leader. Step 2 is then a no-op.

## Relation to the preflight design

The preflight design document in `sighupio/furyctl` defines the states of an Immutable cluster. The two
changes connect, but not where you expect.

The replacement does not need the preflight state. etcd is a better source than the Kubernetes API for
its own member list.

The preflight state gives the guard. The state `PartiallyProvisioned` means that several nodes are
absent at the same time. In that state an automatic replacement can break quorum. The apply must stop
and ask the operator.

This guard is the equivalent of the Cluster API preflight gate. Cluster API waits and tries again after
15 seconds. Ansible cannot wait, so the guard must stop with a clear message.

The two changes are therefore independent. Ship the replacement first. Add the guard when the preflight
state model lands.

## Files to change

| Repository | File | Change |
| --- | --- | --- |
| `installer-immutable` | `roles/etcd/tasks/replace.yml` (new) | path A: the detection and the member operations |
| `installer-immutable` | `roles/etcd/tasks/pre_replace.yml` (new, later) | path B: drain, move the leader, remove the member |
| `installer-immutable` | `roles/etcd/tasks/main.yml` | include `replace.yml` before the `etcd.env` template task, and add the promote task after the start |
| `installer-immutable` | `roles/etcd/defaults/main.yml` | keep `new` as the default, and add a comment that `replace.yml` computes the value |
| `installer-immutable` | `roles/etcd/meta/argument_specs.yml` | update the description of `etcd_initial_cluster_state` |
| `installer-immutable` | `roles/etcd/README.md` | document the two paths and their limits |
| `installer-immutable` | `roles/kube-control-plane/tasks/main.yml` | add `addon/coredns` to `kubeadm_skip_phases` when the cluster already answers |
| `distribution` | `templates/kubernetes/immutable/apply.yaml.tpl` | give the `etcd` role its own play with `serial: 1` |

## References

- [`workload_cluster_etcd.go`](https://github.com/kubernetes-sigs/cluster-api/blob/main/controlplane/kubeadm/pkg/workload_cluster_etcd.go) — `RemoveEtcdMember`, `ForwardEtcdLeadership`
- [`preflight.go`](https://github.com/kubernetes-sigs/cluster-api/blob/main/controlplane/kubeadm/reconcilers/kubeadmcontrolplane/preflight.go) — `preflightChecks`, `checkHealthiness`, `targetEtcdClusterHealthy`
- [`scale.go`](https://github.com/kubernetes-sigs/cluster-api/blob/main/controlplane/kubeadm/reconcilers/kubeadmcontrolplane/scale.go) — scale up and scale down, the cleanup hook ordering
