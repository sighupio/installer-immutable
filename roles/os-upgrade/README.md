# `os-upgrade` role

The `os-upgrade` role is a library of task files that furyctl uses during the upgrade of a cluster to update Flatcar
Container Linux, the operating system of the nodes, with its A/B partitions; see the [installer README](../../README.md)
for how furyctl uses the roles. It has no `main` entry point: each task file is a separate entry point, which the
upgrade playbooks include on its own with `include_role` and `tasks_from`; the
[`kube-worker` role](../kube-worker/README.md) also includes `os_reboot.yml` during the upgrade of a worker node.
`os_stage.yml` starts the update in the background while the other steps of the upgrade run, and `os_reboot.yml` later
boots the node into it.

The default values of the variables are in [`defaults/main.yml`](defaults/main.yml).

## Requirements

- The Omaha update server of `os_update_server`, whose default is in [`defaults/main.yml`](defaults/main.yml), offers
  the target Flatcar version for the architecture of every node. If you use your own server, such as Nebraska, it must
  serve that version for every architecture of the cluster.
- Both A/B operating system partitions on the node, `USR-A` and `USR-B`, which a rollback needs.
- `os_stage.yml` runs before `os_reboot.yml` in the same run: `os_reboot.yml` uses the facts that `os_stage.yml` sets.
- The variables of the [`sysext` role](../sysext/README.md), since `os_reboot.yml` includes it to stage the
  flatcar-python system extension of the new version.

<!-- ANSIBLE DOCSMITH MAIN START -->
## Entry point: `os_stage.yml`

Stage a Flatcar operating system update on the inactive partition of the node.

Writes the configuration of the Flatcar update engine and fails when the node runs a Flatcar version newer than `os_update_target_version`: downgrades are not supported. When the node runs an older version, the role starts the update engine and launches the download of the update to the inactive A/B partition in the background, unless the target version is already staged. It fails early, before any node is drained, when the update server offers no update for the architecture of the node.

| Variable | Type | Required | Description |
| --- | --- | --- | --- |
| <a id="os_stage.yml-variable-os_update_target_version"></a>`os_update_target_version` | `str` | Yes | Target Flatcar version, compared with the Flatcar version of the node and with the version that is already staged. |
| <a id="os_stage.yml-variable-os_update_conf_path"></a>`os_update_conf_path` | `path` | No | Path on the node of the configuration file of the update engine. |
| <a id="os_stage.yml-variable-os_update_server"></a>`os_update_server` | `str` | No | URL of the Omaha update server that the update engine asks for updates (`SERVER` in its configuration). An arm64 node needs a server that serves arm64 updates. |
| <a id="os_stage.yml-variable-os_update_group"></a>`os_update_group` | `str` | No | Flatcar release track that the update engine follows (`GROUP` in its configuration). |
| `os_update_reboot_strategy` | `str` | No | Reboot strategy of the update engine (`REBOOT_STRATEGY` in its configuration). Keep `off`, so that the update engine never reboots the node by itself: during an upgrade, the `os_reboot.yml` entry point reboots the node, and outside upgrades a tool such as Kured can coordinate reboots. [Details](#os_stage.yml-variable-os_update_reboot_strategy). |
| <a id="os_stage.yml-variable-os_update_marker_path"></a>`os_update_marker_path` | `path` | No | File on the node where the role records the staged version, because the update engine forgets it when it restarts. |
| <a id="os_stage.yml-variable-os_update_stage_async_timeout"></a>`os_update_stage_async_timeout` | `int` | No | Longest time, in seconds, that the background download may take. |

### `os_update_reboot_strategy`<a id="os_stage.yml-variable-os_update_reboot_strategy"></a>

Reboot strategy of the update engine (`REBOOT_STRATEGY` in its configuration). Keep `off`, so that the update engine never reboots the node by itself: during an upgrade, the `os_reboot.yml` entry point reboots the node, and outside upgrades a tool such as Kured can coordinate reboots.

Choices: `off`, `reboot`, `etcd-lock`, `best-effort`.

## Entry point: `os_reboot.yml`

Reboot the node into the staged Flatcar version and confirm that it booted.

When the node runs an older version than the target, the role waits for the background download to finish, checks that the update engine staged `os_update_target_version`, records it in `os_update_marker_path` and stages the flatcar-python system extension of the new version. When [`os_update_reboot`](#os_reboot.yml-variable-os_update_reboot) is `true` and an operating system update or a system extension waits for a reboot, the role reboots the node.

After an operating system update, the role checks that the node booted the target version and marks the partition as good, so that the boot loader does not roll back at the next reboot; when the node booted the previous version instead, the role restores the previous system extensions and fails. In every case, it leaves the update engine stopped and masked.

| Variable | Type | Required | Description |
| --- | --- | --- | --- |
| <a id="os_reboot.yml-variable-os_update_target_version"></a>`os_update_target_version` | `str` | Yes | Target Flatcar version that the staged update and the booted system must match. |
| <a id="os_reboot.yml-variable-os_update_reboot"></a>`os_update_reboot` | `bool` | No | Whether the role may reboot the node. When `false`, the role does not reboot the node. |
| <a id="os_reboot.yml-variable-os_update_stage_async_retries"></a>`os_update_stage_async_retries` | `int` | No | Number of times, 5 seconds apart, that the role checks the background download again after the first check, before it fails. Keep 5 times this value at least equal to [`os_update_stage_async_timeout`](#os_stage.yml-variable-os_update_stage_async_timeout), so that the download can use all of its time. |
| <a id="os_reboot.yml-variable-os_update_marker_path"></a>`os_update_marker_path` | `path` | No | File on the node where the role records the staged version; the role deletes it once the node booted the target version. |
| <a id="os_reboot.yml-variable-os_update_reboot_timeout"></a>`os_update_reboot_timeout` | `int` | No | Longest time, in seconds, that the role waits for the node to come back after the reboot. |
| <a id="os_reboot.yml-variable-os_update_server"></a>`os_update_server` | `str` | No | URL of the update server, named in the error message when the staged version is not the target version. |
| <a id="os_reboot.yml-variable-os_update_group"></a>`os_update_group` | `str` | No | Flatcar release track, named in the error message when the staged version is not the target version. |

<!-- ANSIBLE DOCSMITH MAIN END -->
