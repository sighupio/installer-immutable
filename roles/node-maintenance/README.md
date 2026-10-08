# `node-maintenance` role

The `node-maintenance` role is a library of task files that furyctl uses during the upgrade of a cluster; see the
[installer README](../../README.md) for how furyctl uses the roles. It has no `main` entry point: each task file is a
separate entry point, which the upgrade playbooks include on its own with `include_role` and `tasks_from`. Together, its
three entry points, `preflight.yml`, `drain.yml` and `uncordon.yml`, open and close one maintenance window per node,
shared by every step of the upgrade that disrupts the node.

The default values of the variables are in [`defaults/main.yml`](defaults/main.yml).

## Requirements

- `kubectl` on the furyctl host: the role runs every `kubectl` command there.
- `super-admin.conf` of the cluster on the furyctl host, which the `fetch_admin_conf.yml` entry point of the
  [`upgrade-gates` role](../upgrade-gates/README.md) fetches.
- The worker nodes in the inventory group `nodes`.

<!-- ANSIBLE DOCSMITH MAIN START -->
## Entry point: `preflight.yml`

Decide whether the upgrade must drain the node.

Sets the fact `node_upgrade_drain_required` to `true` when the node will reboot for an operating system update, that is when [`os_update_apply`](#preflight.yml-variable-os_update_apply) and [`os_update_reboot`](#preflight.yml-variable-os_update_reboot) are `true` and the node runs a Flatcar version older than [`os_update_target_version`](#preflight.yml-variable-os_update_target_version). During an upgrade, it is also `true` for a worker node, a node of the inventory group `nodes`, that does not run [`kubernetes_version`](#preflight.yml-variable-kubernetes_version) yet or whose system extensions changed. The role reads the Kubernetes version of the node with `kubectl` on the furyctl host.

| Variable | Type | Required | Description |
| --- | --- | --- | --- |
| <a id="preflight.yml-variable-upgrade"></a>`upgrade` | `bool` | No | `true` when the run is a cluster upgrade. Only then does the role compare the Kubernetes version of a worker node with [`kubernetes_version`](#preflight.yml-variable-kubernetes_version). |
| <a id="preflight.yml-variable-kubectl_bin"></a>`kubectl_bin` | `str` | No | Path of `kubectl` on the furyctl host, with which the role reads the Kubernetes version of the node. |
| <a id="preflight.yml-variable-kubernetes_hostname"></a>`kubernetes_hostname` | `str` | No | Name of the Kubernetes node. Defaults to the fully qualified domain name of the node. |
| <a id="preflight.yml-variable-kubernetes_kubeconfig_path"></a>`kubernetes_kubeconfig_path` | `path` | No | Directory on the furyctl host, ending with `/`, that holds `super-admin.conf`, the kubeconfig file of `kubectl`. The `fetch_admin_conf.yml` entry point of the upgrade-gates role always writes the file as `./super-admin.conf`, whatever the value of this variable is. |
| <a id="preflight.yml-variable-kubernetes_version"></a>`kubernetes_version` | `str` | Yes | Target Kubernetes version of the upgrade, compared with the version of the kubelet of a worker node. |
| <a id="preflight.yml-variable-os_update_apply"></a>`os_update_apply` | `bool` | No | Whether the run applies an operating system update. Together with [`os_update_reboot`](#preflight.yml-variable-os_update_reboot), it makes the role expect a reboot of a node that runs a Flatcar version older than [`os_update_target_version`](#preflight.yml-variable-os_update_target_version). |
| <a id="preflight.yml-variable-os_update_reboot"></a>`os_update_reboot` | `bool` | No | Whether the run may reboot the node to activate an operating system update; see [`os_update_apply`](#preflight.yml-variable-os_update_apply). |
| <a id="preflight.yml-variable-os_update_target_version"></a>`os_update_target_version` | `str` | Yes | Target Flatcar version of the operating system update, compared with the Flatcar version of the node. |
| <a id="preflight.yml-variable-sysext_changed_components"></a>`sysext_changed_components` | `list` | No | System extensions changed during the run. A non-empty list makes the role drain a worker node during an upgrade. When this entry point runs, no system extension has been aligned yet, so the list is empty. |

## Entry point: `drain.yml`

Drain the node before the disruptive steps of the upgrade.

Runs `kubectl drain` for the node on the furyctl host: the node is cordoned and its pods are evicted, ignoring DaemonSets and deleting emptyDir data, with a grace period of 60 seconds and a timeout of 6 minutes. Pods that no controller manages are deleted too (`--force`). A failed drain is retried up to 3 times.

| Variable | Type | Required | Description |
| --- | --- | --- | --- |
| <a id="drain.yml-variable-kubectl_bin"></a>`kubectl_bin` | `str` | No | Path of `kubectl` on the furyctl host, with which the role drains the node. |
| <a id="drain.yml-variable-kubernetes_hostname"></a>`kubernetes_hostname` | `str` | No | Name of the Kubernetes node. Defaults to the fully qualified domain name of the node. |
| <a id="drain.yml-variable-kubernetes_kubeconfig_path"></a>`kubernetes_kubeconfig_path` | `path` | No | Directory on the furyctl host, ending with `/`, that holds `super-admin.conf`, the kubeconfig file of `kubectl`. The `fetch_admin_conf.yml` entry point of the upgrade-gates role always writes the file as `./super-admin.conf`, whatever the value of this variable is. |

## Entry point: `uncordon.yml`

Uncordon the node after the upgrade and wait for its pods.

Runs `kubectl uncordon` for the node on the furyctl host, then waits until every pod of the node is Ready, checking every 15 seconds. Pods that completed are not checked.

| Variable | Type | Required | Description |
| --- | --- | --- | --- |
| <a id="uncordon.yml-variable-kubectl_bin"></a>`kubectl_bin` | `str` | No | Path of `kubectl` on the furyctl host, with which the role uncordons the node and reads its pods. |
| <a id="uncordon.yml-variable-kubernetes_hostname"></a>`kubernetes_hostname` | `str` | No | Name of the Kubernetes node. Defaults to the fully qualified domain name of the node. |
| <a id="uncordon.yml-variable-kubernetes_kubeconfig_path"></a>`kubernetes_kubeconfig_path` | `path` | No | Directory on the furyctl host, ending with `/`, that holds `super-admin.conf`, the kubeconfig file of `kubectl`. The `fetch_admin_conf.yml` entry point of the upgrade-gates role always writes the file as `./super-admin.conf`, whatever the value of this variable is. |
| <a id="uncordon.yml-variable-skip_pods_running_check"></a>`skip_pods_running_check` | `bool` | No | When `true`, the role does not wait for the pods of the node after it uncordons the node. |
| <a id="uncordon.yml-variable-pods_running_retries"></a>`pods_running_retries` | `int` | No | Number of times, 15 seconds apart, that the role checks the pods of the node again after the first check, before it fails. |

<!-- ANSIBLE DOCSMITH MAIN END -->
