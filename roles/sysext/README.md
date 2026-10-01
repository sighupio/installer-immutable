# `sysext` role

The `sysext` role is a library of task files that brings the system extensions of a node, such as containerd, etcd,
keepalived and Kubernetes, to their target versions during the upgrade of a cluster; see the
[installer README](../../README.md) for how furyctl uses the roles. It has no `main` entry point: its only entry point
is the task file `align.yml`, which other roles of the installer include with `include_role` and `tasks_from` for the
components they own.

The default values of the variables are in [`defaults/main.yml`](defaults/main.yml).

## Requirements

- The system extensions were placed on the node when it was provisioned, each with an active link in the directory of
  active links: the role never installs a component that the node does not have.
- The node can download the images of the targets, and the `SHA256SUMS` file of each release, from their URLs.
- `cosign` or `gpg` on the node when the signature check is on.

<!-- ANSIBLE DOCSMITH MAIN START -->
## Entry point: `align.yml`

Bring selected system extensions of the node to their target versions.

For each component of [`sysext_components`](#variable-sysext_components) that is installed on the node and not at the version that [`sysext_targets`](#variable-sysext_targets) gives, downloads the target `.raw` image, verifies it against the `SHA256SUMS` file of its release and, optionally, the signature of that file, points the active link of the component to it, and keeps only the current and the previous image. The role lists the changed components in [`sysext_changed_components`](#variable-sysext_changed_components). With [`sysext_refresh_after`](#variable-sysext_refresh_after), it activates the new versions at once with `systemd-sysext refresh`; otherwise it records that a system extension waits for the next boot of the node.

| Variable | Type | Required | Description |
| --- | --- | --- | --- |
| <a id="variable-sysext_targets"></a>`sysext_targets` | `dict` | Yes | Target version and image of every system extension: a map from the name of a component to its `version` and to `arch`, a map from each architecture to the `url` of the `.raw` image of the component. The `SHA256SUMS` file of the release must be next to the image. |
| <a id="variable-sysext_components"></a>`sysext_components` | `list` | Yes | Components of [`sysext_targets`](#variable-sysext_targets) to align in this run; the role leaves the other components as they are. |
| <a id="variable-sysext_refresh_after"></a>`sysext_refresh_after` | `bool` | No | When `true`, the role runs `systemd-sysext refresh` at the end, so that the aligned versions are active at once. Otherwise, the role records that a system extension waits for the next boot of the node. |
| <a id="variable-sysext_changed_components"></a>`sysext_changed_components` | `list` | No | Components whose image changed in this run. The role empties the list when it starts and fills it as it goes, so that the task file that includes this entry point can read it afterwards. |
| `sysext_arch` | `str` | No | Architecture of the system extensions of the node, the key into the `arch` map of each target. Defaults to [`node_arch`](#variable-node_arch) or, when that is not set, to `arm64` on an `aarch64` node and to `x86-64` otherwise. [Details](#variable-sysext_arch). |
| `node_arch` | `str` | No | Architecture of the node. When set, it is the default of [`sysext_arch`](#variable-sysext_arch). [Details](#variable-node_arch). |
| <a id="variable-sysext_extensions_store"></a>`sysext_extensions_store` | `path` | No | Directory on the node where the role keeps the downloaded images, one subdirectory per component. |
| <a id="variable-sysext_active_dir"></a>`sysext_active_dir` | `path` | No | Directory of the active links, `<name>.raw`, that systemd-sysext merges. A component without a link in this directory is not installed on the node, and the role leaves it alone. |
| <a id="variable-sysext_verify_signature"></a>`sysext_verify_signature` | `bool` | No | When `true`, the role verifies the signature of the `SHA256SUMS` file of the release before it activates an image. The releases publish only `SHA256SUMS` today, without a signature. |
| `sysext_signature_tool` | `str` | No | Tool that verifies the signature when [`sysext_verify_signature`](#variable-sysext_verify_signature) is `true`. [Details](#variable-sysext_signature_tool). |
| <a id="variable-sysext_signature_key"></a>`sysext_signature_key` | `str` | No | Key of the signature check: the key given to `cosign --key`, or the keyring given to `gpg --keyring`. Needed when [`sysext_verify_signature`](#variable-sysext_verify_signature) is `true`. |
| <a id="variable-sysext_signature_ext"></a>`sysext_signature_ext` | `str` | No | Extension of the signature file, `SHA256SUMS.<ext>`, that the role downloads next to `SHA256SUMS` when [`sysext_verify_signature`](#variable-sysext_verify_signature) is `true`. |

### `sysext_arch`<a id="variable-sysext_arch"></a>

Architecture of the system extensions of the node, the key into the `arch` map of each target. Defaults to [`node_arch`](#variable-node_arch) or, when that is not set, to `arm64` on an `aarch64` node and to `x86-64` otherwise.

Choices: `x86-64`, `arm64`.

### `node_arch`<a id="variable-node_arch"></a>

Architecture of the node. When set, it is the default of [`sysext_arch`](#variable-sysext_arch).

Choices: `x86-64`, `arm64`.

### `sysext_signature_tool`<a id="variable-sysext_signature_tool"></a>

Tool that verifies the signature when [`sysext_verify_signature`](#variable-sysext_verify_signature) is `true`.

Choices: `cosign`, `gpg`.

<!-- ANSIBLE DOCSMITH MAIN END -->
