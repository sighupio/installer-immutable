# `upgrade-gates` role

The `upgrade-gates` role is a library of task files that furyctl uses during the upgrade of a cluster: read-only checks,
where a check that fails stops the upgrade, and `fetch_admin_conf.yml`, which copies the cluster kubeconfig to the
furyctl host; see the [installer README](../../README.md) for how furyctl uses the roles. It has no `main` entry
point: each of its task files, `fetch_admin_conf.yml`, `cluster_health_gate.yml`, `infra_preflight.yml` and
`sanity.yml`, is a separate entry point, which the upgrade playbooks include on its own with `include_role` and
`tasks_from`.

The default values of the variables are in [`defaults/main.yml`](defaults/main.yml).

## Requirements

- `kubectl` on the furyctl host, where the checks run their `kubectl` commands against the cluster. `sanity.yml` also
  runs `kubelet`, `kubeadm`, `kubectl` and `containerd` on the node itself.
- The control-plane nodes in the inventory group `control_plane`.
- The `etcdctl` profile that the [`etcd` role](../etcd/README.md) writes, on the nodes where `cluster_health_gate.yml`
  runs.

<!-- ANSIBLE DOCSMITH MAIN START -->
## Entry point: `fetch_admin_conf.yml`

Fetch super-admin.conf from a control-plane node to the furyctl host.

Copies `/etc/kubernetes/super-admin.conf` from the first node of the inventory group `control_plane` to `./super-admin.conf` on the furyctl host, once per run, for the checks that run `kubectl` on the furyctl host. The run fails when the file cannot be fetched.

This entry point takes no variables.

## Entry point: `infra_preflight.yml`

Check the infrastructure of the node before the upgrade drains it.

Fails when the root file system of the node has less free space than [`node_upgrade_min_free_bytes`](#infra_preflight.yml-variable-node_upgrade_min_free_bytes), when the `.raw` image of a target of `sysext_targets` does not answer an HTTP `HEAD` request, or when the node lacks one of the two A/B operating system partitions, `USR-A` and `USR-B`, that a rollback needs. The checks change nothing on the node.

| Variable | Type | Required | Description |
| --- | --- | --- | --- |
| <a id="infra_preflight.yml-variable-node_upgrade_min_free_bytes"></a>`node_upgrade_min_free_bytes` | `int` | No | Smallest free space, in bytes, on the root file system of the node. The system extensions and the Flatcar update payload use this space during the upgrade. |
| <a id="infra_preflight.yml-variable-sysext_targets"></a>`sysext_targets` | `dict` | No | Targets of the system extensions, in the format of the `sysext_targets` variable of the sysext role. The role checks that the image of every target for the architecture of the node is reachable; when unset, it skips that check. |
| `sysext_arch` | `str` | No | Architecture of the system extensions of the node, the key into the `arch` map of each target. Defaults to [`node_arch`](#infra_preflight.yml-variable-node_arch) or, when that is not set, to `arm64` on an `aarch64` node and to `x86-64` otherwise. [Details](#infra_preflight.yml-variable-sysext_arch). |
| `node_arch` | `str` | No | Architecture of the node. When set, it is the default of [`sysext_arch`](#infra_preflight.yml-variable-sysext_arch). [Details](#infra_preflight.yml-variable-node_arch). |

### `sysext_arch`<a id="infra_preflight.yml-variable-sysext_arch"></a>

Architecture of the system extensions of the node, the key into the `arch` map of each target. Defaults to [`node_arch`](#infra_preflight.yml-variable-node_arch) or, when that is not set, to `arm64` on an `aarch64` node and to `x86-64` otherwise.

Choices: `x86-64`, `arm64`.

### `node_arch`<a id="infra_preflight.yml-variable-node_arch"></a>

Architecture of the node. When set, it is the default of [`sysext_arch`](#infra_preflight.yml-variable-sysext_arch).

Choices: `x86-64`, `arm64`.

## Entry point: `sanity.yml`

Check the node after its upgrade.

Fails unless the kubelet, `kubeadm` and `kubectl` of the node report `kubernetes_version`, containerd reports the target version of its system extension when `sysext_targets` gives one, the kubernetes system extension is merged, and the node is Ready. The role waits for the node to be Ready with `kubectl` on the furyctl host.

| Variable | Type | Required | Description |
| --- | --- | --- | --- |
| <a id="sanity.yml-variable-kubernetes_version"></a>`kubernetes_version` | `str` | Yes | Target Kubernetes version that the kubelet, `kubeadm` and `kubectl` of the node must report. |
| <a id="sanity.yml-variable-kubectl_bin"></a>`kubectl_bin` | `str` | No | Path of `kubectl` on the furyctl host, with which the role waits for the node to be Ready. |
| <a id="sanity.yml-variable-kubernetes_kubeconfig_path"></a>`kubernetes_kubeconfig_path` | `path` | No | Directory on the furyctl host, ending with `/`, that holds `super-admin.conf`, the kubeconfig file of `kubectl`. The `fetch_admin_conf.yml` entry point always writes the file as `./super-admin.conf`, whatever the value of this variable is. |
| <a id="sanity.yml-variable-kubernetes_hostname"></a>`kubernetes_hostname` | `str` | No | Name of the Kubernetes node. Defaults to the fully qualified domain name of the node. |
| <a id="sanity.yml-variable-sysext_targets"></a>`sysext_targets` | `dict` | No | Targets of the system extensions, in the format of the `sysext_targets` variable of the sysext role. The role reads only the `version` of `containerd`, and skips the containerd check when it is missing. |

## Entry point: `cluster_health_gate.yml`

Check the health of the cluster before the upgrade touches any node.

Fails unless the API server answers and every node is Ready; the nodes run one Kubernetes version, or two versions of which one is `kubernetes_version`, as after an interrupted upgrade that can resume; and every member of the etcd cluster is healthy. The `kubectl` commands run on the furyctl host; the etcd check runs on the node, with the `etcdctl` profile that the etcd role writes.

| Variable | Type | Required | Description |
| --- | --- | --- | --- |
| <a id="cluster_health_gate.yml-variable-kubernetes_version"></a>`kubernetes_version` | `str` | Yes | Target Kubernetes version of the upgrade. A cluster whose nodes run two versions passes only when one of them is this one. |
| <a id="cluster_health_gate.yml-variable-kubectl_bin"></a>`kubectl_bin` | `str` | No | Path of `kubectl` on the furyctl host, with which the role reads the nodes of the cluster. |
| <a id="cluster_health_gate.yml-variable-kubernetes_kubeconfig_path"></a>`kubernetes_kubeconfig_path` | `path` | No | Directory on the furyctl host, ending with `/`, that holds `super-admin.conf`, the kubeconfig file of `kubectl`. The `fetch_admin_conf.yml` entry point always writes the file as `./super-admin.conf`, whatever the value of this variable is. |

<!-- ANSIBLE DOCSMITH MAIN END -->
