# `sysctl` role

The `sysctl` role sets custom kernel parameters on the nodes with `sysctl` and keeps them in a `sysctl.d` file, so that
the node applies them again after a reboot. furyctl runs it during the installation of a cluster; see the
[installer README](../../README.md) for how furyctl uses the roles.

## Requirements

The role needs only the `sysctl` command on the node.

<!-- ANSIBLE DOCSMITH MAIN START -->
## Role variables

Set kernel parameters on the node and keep them across reboots.

Saves the current value of every kernel parameter to [`sysctl_dump_path`](#variable-sysctl_dump_path) the first time it runs, writes the parameters of [`sysctl_parameters`](#variable-sysctl_parameters) to the file [`sysctl_file_path`](#variable-sysctl_file_path) and, when that file changed, reloads the kernel parameters of the node with `sysctl --system`. The node reads the file again at every boot, so the parameters survive a reboot.

| Variable | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| <a id="variable-sysctl_d_path"></a>`sysctl_d_path` | `path` | No | `/etc/sysctl.d` | Directory of the `sysctl.d` configuration files. The role creates it when it does not exist. Use a directory that `sysctl --system` reads, such as `/etc/sysctl.d`: the role loads the parameters with that command, which ignores files in other directories. |
| <a id="variable-sysctl_file_path"></a>`sysctl_file_path` | `path` | No | — | File where the role writes the parameters of [`sysctl_parameters`](#variable-sysctl_parameters). Defaults to `99-sighup-distribution.conf` in [`sysctl_d_path`](#variable-sysctl_d_path). |
| <a id="variable-sysctl_dump_path"></a>`sysctl_dump_path` | `path` | No | — | File where the role saves the output of `sysctl -a`, the values of all kernel parameters, before it changes any of them. The role writes it only when it does not exist yet, so it keeps the values from before the first run. Defaults to `sysctl-dump.original` in [`sysctl_d_path`](#variable-sysctl_d_path). |
| `sysctl_parameters` | `list` | No | `[]` | Kernel parameters to set, as a list of maps with the keys `name` and `value`. [Details](#variable-sysctl_parameters). |

### `sysctl_parameters`<a id="variable-sysctl_parameters"></a>

Kernel parameters to set, as a list of maps with the keys `name` and `value`.

For example, this list sets one parameter:

```yaml
- name: net.ipv4.ip_forward
  value: 1
```

Removing a parameter from the list does not reset the parameter to its previous value. To reset it, add it to the list with its previous value, which [`sysctl_dump_path`](#variable-sysctl_dump_path) records, or reboot the node.

<!-- ANSIBLE DOCSMITH MAIN END -->
