# `os-upgrade` role

The `os-upgrade` role is a library of task files that furyctl uses during the upgrade of a cluster to update Flatcar
Container Linux, the operating system of the nodes, with its A/B partitions; see the [installer README](../../README.md)
for how furyctl uses the roles. It has no `main` entry point: each task file is a separate entry point, which the
upgrade playbooks include on its own with `include_role` and `tasks_from`; the
[`kube-worker` role](../kube-worker/README.md) also includes `os_reboot.yml` during the upgrade of a worker node.
`os_stage.yml` stages the update before the upgrade drains the node, and `os_reboot.yml` later boots the node into it.

The default values of the variables are in [`defaults/main.yml`](defaults/main.yml).

## Requirements

- The `flatcar.arch.<arch>.update` entry of `immutable.yaml` for the target version and for every architecture of the
  cluster. furyctl gives it to the role as `os_update_payload_pins`.
- Access from every node to the URL of the payload, directly or through the proxy of `spec.infrastructure.proxy`.
- Enough free space on `/` of every node for the payload (about 400 to 550 MB).
- No other service on the node that listens on `os_update_local_omaha_port` or `os_update_local_payload_port`.
- Both A/B operating system partitions on the node, `USR-A` and `USR-B`, which a rollback needs.
- `os_stage.yml` runs before `os_reboot.yml` in the same run: `os_reboot.yml` uses the facts that `os_stage.yml` sets.
- The variables of the [`sysext` role](../sysext/README.md), since `os_reboot.yml` includes it to stage the
  flatcar-python system extension of the new version.

<!-- ANSIBLE DOCSMITH MAIN START -->
## Entry point: `os_stage.yml`

Stage a Flatcar operating system update on the inactive partition of the node.

Fails when the node runs a Flatcar version newer than `os_update_target_version`: the role does not support downgrades. When the node runs an older version, the role downloads the payload from the URL in [`os_update_payload_pins`](#os_stage.yml-variable-os_update_payload_pins) and compares its SHA-256 checksum with the pin. Then it stages the payload on the inactive A/B partition with `flatcar-update`. The role does all of this before the upgrade drains the node. Thus a missing or bad payload stops the upgrade while the node still serves. The role contacts no update server: it sets `SERVER=disabled` in `/etc/flatcar/update.conf`, so that every update check of the update engine fails, as Flatcar recommends.

| Variable | Type | Required | Description |
| --- | --- | --- | --- |
| <a id="os_stage.yml-variable-os_update_target_version"></a>`os_update_target_version` | `str` | Yes | Target Flatcar version, compared with the Flatcar version of the node. |
| `os_update_payload_pins` | `dict` | Yes | Pins of the Flatcar update payload of the target version, one for each architecture, from the `flatcar.arch.<arch>.update` entries of `immutable.yaml`. The keys are the architectures, `x86-64` and `arm64`. Each pin has the `url` of `flatcar_production_update.gz` and its `sha256`. [Details](#os_stage.yml-variable-os_update_payload_pins). |
| <a id="os_stage.yml-variable-os_update_local_omaha_port"></a>`os_update_local_omaha_port` | `int` | No | Port on the node of the local update server that `flatcar-update` starts for the update engine. It must not be in use on the node. |
| `node_arch` | `str` | No | Architecture of the node, the key into [`os_update_payload_pins`](#os_stage.yml-variable-os_update_payload_pins). Defaults to `arm64` on an `aarch64` node and to `x86-64` otherwise. [Details](#os_stage.yml-variable-node_arch). |
| <a id="os_stage.yml-variable-os_update_local_payload_port"></a>`os_update_local_payload_port` | `int` | No | Port on the node of the local server that `flatcar-update` starts to serve the payload. It must not be in use on the node. |

### `os_update_payload_pins`<a id="os_stage.yml-variable-os_update_payload_pins"></a>

Pins of the Flatcar update payload of the target version, one for each architecture, from the `flatcar.arch.<arch>.update` entries of `immutable.yaml`. The keys are the architectures, `x86-64` and `arm64`. Each pin has the `url` of `flatcar_production_update.gz` and its `sha256`.

The checksum makes sure that the payload is `os_update_target_version`: `flatcar-update` uses the target version only as a label.

### `node_arch`<a id="os_stage.yml-variable-node_arch"></a>

Architecture of the node, the key into [`os_update_payload_pins`](#os_stage.yml-variable-os_update_payload_pins). Defaults to `arm64` on an `aarch64` node and to `x86-64` otherwise.

Choices: `x86-64`, `arm64`.

## Entry point: `os_reboot.yml`

Reboot the node into the staged Flatcar version and confirm that it booted.

When the node runs an older version than the target, the role stages the flatcar-python system extension of the new version. When [`os_update_reboot`](#os_reboot.yml-variable-os_update_reboot) is `true` and an operating system update or a system extension waits for a reboot, the role reboots the node.

After an operating system update, the role checks that the node booted the target version. Then it marks the partition as good, so that the boot loader does not roll back at the next reboot. If the node booted the previous version, the role restores the previous system extensions and fails.

| Variable | Type | Required | Description |
| --- | --- | --- | --- |
| <a id="os_reboot.yml-variable-os_update_target_version"></a>`os_update_target_version` | `str` | Yes | Target Flatcar version that the booted system must match. |
| <a id="os_reboot.yml-variable-os_update_reboot"></a>`os_update_reboot` | `bool` | No | Whether the role can reboot the node. When `false`, the role does not reboot the node. |
| <a id="os_reboot.yml-variable-os_update_reboot_timeout"></a>`os_update_reboot_timeout` | `int` | No | Longest time, in seconds, that the role waits for the node to come back after the reboot. |

<!-- ANSIBLE DOCSMITH MAIN END -->
