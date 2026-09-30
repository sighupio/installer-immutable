# `kube-worker` role

The `kube-worker` role joins the worker nodes to the Kubernetes cluster with
[kubeadm](https://kubernetes.io/docs/reference/setup-tools/kubeadm/), keeps their kubelet configuration up to date, and
upgrades them. furyctl runs it during the installation of a cluster and again during an upgrade; see the
[installer README](../../README.md) for how furyctl uses the roles.

## Requirements

- The kubernetes system extension from the
  [installer-immutable-sysext](https://github.com/sighupio/installer-immutable-sysext) repository is installed on the node.
- containerd runs on the node, configured by the [`containerd` role](../containerd/README.md).
- A working control plane to join the node to, created by the
  [`kube-control-plane` role](../kube-control-plane/README.md), with a bootstrap token and the hash of its certificate
  authority.

During an upgrade, the role also needs:

- `kubectl` at [`kubectl_bin`](#variable-kubectl_bin) and the `super-admin.conf` kubeconfig in
  [`kubernetes_kubeconfig_path`](#variable-kubernetes_kubeconfig_path), both on the furyctl host;
- the variable `sysext_targets` of the [`sysext` role](../sysext/README.md), with the target versions of the kubernetes
  and kubeadm system extensions;
- the `os_stage.yml` entry point of the [`os-upgrade` role](../os-upgrade/README.md), run earlier in the same play, and
  `os_update_reboot` set to `true`: without them the role does not reboot the node into what it staged.

## Further kubelet settings

Besides the `kubelet_config_*` variables listed below, the kubelet configuration that the role writes accepts further
variables named `kubelet_config_<field>`, where `<field>` is a field of the kubelet configuration in snake case (for
example `kubelet_config_max_pods` for `maxPods`); the role writes each of them that is defined into the kubelet
configuration of the node.

<!-- ANSIBLE DOCSMITH MAIN START -->
## Role variables

Join the node to the cluster as a worker node, or upgrade it.

Writes the kubelet configuration patch of the node and, on a node that has not joined the cluster yet, the `kubeadm` join configuration, then runs `kubeadm join`. On a node that already joined, the role applies a changed kubelet configuration with `kubeadm upgrade node phase kubelet-config` and restarts the kubelet.

During an upgrade, the role does not apply the kubelet configuration in place: it stages the new versions of the kubernetes and kubeadm system extensions installed on the node and calls the `os_reboot.yml` entry point of the os-upgrade role, which reboots the node into what is staged when `os_update_reboot` is `true` and an operating system update or a system extension was staged. This needs the `os_stage.yml` entry point of the os-upgrade role to have run earlier in the same play. After that step, the role checks that the target version is at most one minor version away from the version of the node, runs `kubeadm upgrade node` and restarts the kubelet.

| Variable | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| <a id="variable-kubeadm_config_file"></a>`kubeadm_config_file` | `path` | No | `/etc/kubernetes/kubeadm.yml` | Path on the node of the `kubeadm` join configuration. The role writes it only on a node that has not joined the cluster yet. |
| <a id="variable-kubelet_config_path"></a>`kubelet_config_path` | `path` | No | `/var/lib/kubelet/kubelet-config` | Directory on the node whose `patches` subdirectory holds the kubelet configuration patch of the node, which `kubeadm join` and `kubeadm upgrade node` apply. |
| <a id="variable-kubernetes_control_plane_address"></a>`kubernetes_control_plane_address` | `str` | Yes | — | Address of the Kubernetes API server that the node joins (`apiServerEndpoint` of the `kubeadm` join configuration), such as the virtual IP address or the load balancer in front of the control-plane nodes, with its port: for example `ctrl01.example.com:6443`. |
| <a id="variable-kubernetes_bootstrap_token"></a>`kubernetes_bootstrap_token` | `str` | No | `""` | Bootstrap token with which the node joins the cluster. The kube-control-plane role creates one, valid for 30 minutes, with `kubeadm token create`. The empty default is not enough to join a cluster. |
| <a id="variable-kubernetes_ca_hash"></a>`kubernetes_ca_hash` | `str` | No | `""` | Hash of the public key of the Kubernetes certificate authority (`caCertHashes`), in the form `sha256:<hex>`, with which the node verifies the control plane when it joins. The kube-control-plane role computes it. The empty default is not enough to join a cluster. |
| <a id="variable-kubernetes_cloud_provider"></a>`kubernetes_cloud_provider` | `str` | No | `""` | Value of the `cloud-provider` flag of the kubelet, set when the node joins; the role does not apply a later change to a node that already joined. |
| <a id="variable-kubernetes_hostname"></a>`kubernetes_hostname` | `str` | No | — | Name of the Kubernetes node (`nodeRegistration.name` of the `kubeadm` join configuration), set when the node joins; changing it later does not rename the node. During an upgrade, the role reads the version of the node under this name. Defaults to the fully qualified domain name of the node. |
| <a id="variable-kubernetes_role"></a>`kubernetes_role` | `str` | No | `worker` | Value of the `node.kubernetes.io/role` label of the node, set when the node joins. |
| <a id="variable-kubernetes_taints"></a>`kubernetes_taints` | `list` | No | `[]` | Taints of the node (`nodeRegistration.taints` of the `kubeadm` join configuration), as a list of Kubernetes taints with the keys `key`, `value` and `effect`, set when the node joins. The empty default sets none. |
| `kubelet_config_cgroup_driver` | `str` | No | `systemd` | cgroup driver of the kubelet (`cgroupDriver` of the kubelet configuration). The containerd role configures containerd with the systemd cgroup driver. [Details](#variable-kubelet_config_cgroup_driver). |
| <a id="variable-kubelet_config_streaming_connection_idle_timeout"></a>`kubelet_config_streaming_connection_idle_timeout` | `str` | No | `5m` | Time after which the kubelet closes an idle streaming connection, such as the one of `kubectl exec` (`streamingConnectionIdleTimeout` of the kubelet configuration). |
| <a id="variable-kubelet_config_read_only_port"></a>`kubelet_config_read_only_port` | `int` | No | `0` | Port of the read-only API of the kubelet, which needs no authentication (`readOnlyPort` of the kubelet configuration). `0` disables it. |
| <a id="variable-kubelet_config_server_tls_bootstrap"></a>`kubelet_config_server_tls_bootstrap` | `bool` | No | `true` | When `true`, the kubelet requests its serving certificate from the cluster (`serverTLSBootstrap` of the kubelet configuration); the CronJob that the kube-control-plane role installs approves these requests. |
| <a id="variable-kubelet_config_pod_pids_limit"></a>`kubelet_config_pod_pids_limit` | `int` | No | `4096` | Largest number of processes in a pod (`podPidsLimit` of the kubelet configuration). |
| <a id="variable-kubelet_config_static_pod_path"></a>`kubelet_config_static_pod_path` | `str` | No | `""` | Directory from which the kubelet runs static pods (`staticPodPath` of the kubelet configuration). The empty default disables static pods on the node; when set, the role creates the directory. |
| `kubelet_tls_cipher_suites` | `list` | No | [See details](#variable-kubelet_tls_cipher_suites) | TLS cipher suites that the kubelet of the node accepts (`tlsCipherSuites` of the kubelet configuration). [Details](#variable-kubelet_tls_cipher_suites). |
| <a id="variable-upgrade"></a>`upgrade` | `bool` | No | — | `true` when the role runs during a cluster upgrade. The role then does not apply a changed kubelet configuration in place and runs the upgrade steps. Unset means `false`. |
| <a id="variable-kubectl_bin"></a>`kubectl_bin` | `str` | No | — | Path of `kubectl` on the furyctl host, with which the role reads the current Kubernetes version of the node during an upgrade. This role has no default for it; the node-maintenance and upgrade-gates roles define `kubectl` as their own default. |
| <a id="variable-kubernetes_kubeconfig_path"></a>`kubernetes_kubeconfig_path` | `path` | No | — | Directory on the furyctl host, ending with `/`, that holds `super-admin.conf`, with which the role reads the current Kubernetes version of the node during an upgrade. This role has no default for it. |
| <a id="variable-kubernetes_version"></a>`kubernetes_version` | `str` | Yes | — | Target Kubernetes version of an upgrade. The role reads it only during an upgrade, and refuses a target more than one minor version away from the version of the node before it runs `kubeadm upgrade node`. The check runs after the reboot step, so it cannot prevent the reboot into the staged system extensions. |
| <a id="variable-kubelet_certificate_authority_file"></a>`kubelet_certificate_authority_file` | `path` | No | `/etc/kubernetes/pki/ca.crt` | Path on the node of the CA certificate with which the API server verifies the serving certificates of the kubelets. The kube-control-plane role uses it; the kube-worker role does not read it. |
| `tls_cipher_suites` | `list` | No | [See details](#variable-tls_cipher_suites) | TLS cipher suites that the API server, the scheduler and the controller manager accept. The kube-control-plane role uses it; the kube-worker role does not read it. [Details](#variable-tls_cipher_suites). |

### `kubelet_config_cgroup_driver`<a id="variable-kubelet_config_cgroup_driver"></a>

cgroup driver of the kubelet (`cgroupDriver` of the kubelet configuration). The containerd role configures containerd with the systemd cgroup driver.

Choices: `systemd`, `cgroupfs`.

### `kubelet_tls_cipher_suites`<a id="variable-kubelet_tls_cipher_suites"></a>

TLS cipher suites that the kubelet of the node accepts (`tlsCipherSuites` of the kubelet configuration).

Default:

```json
[
  "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256",
  "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256",
  "TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305",
  "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384",
  "TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305",
  "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384"
]
```

### `tls_cipher_suites`<a id="variable-tls_cipher_suites"></a>

TLS cipher suites that the API server, the scheduler and the controller manager accept. The kube-control-plane role uses it; the kube-worker role does not read it.

Default:

```json
[
  "TLS_AES_128_GCM_SHA256",
  "TLS_AES_256_GCM_SHA384",
  "TLS_CHACHA20_POLY1305_SHA256",
  "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256",
  "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384",
  "TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305",
  "TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256",
  "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256",
  "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384",
  "TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305",
  "TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256"
]
```

<!-- ANSIBLE DOCSMITH MAIN END -->
