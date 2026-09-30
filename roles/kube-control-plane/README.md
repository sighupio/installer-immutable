# `kube-control-plane` role

The `kube-control-plane` role creates the Kubernetes control plane with
[kubeadm](https://kubernetes.io/docs/reference/setup-tools/kubeadm/) on the control-plane nodes, keeps its configuration
up to date, and upgrades it. furyctl runs it during the installation of a cluster and again during an upgrade; see the
[installer README](../../README.md) for how furyctl uses the roles.

## Requirements

- The kubernetes system extension from the
  [installer-immutable-sysext](https://github.com/sighupio/installer-immutable-sysext) repository is installed on the node.
- containerd runs on the node, configured by the [`containerd` role](../containerd/README.md).
- The etcd cluster runs and the node has the etcd client certificates, set up by the [`etcd` role](../etcd/README.md): the
  API server always uses etcd as an external cluster.
- `furyctl create pki` generated the Kubernetes PKI in the directory that
  [`kubernetes_local_pki_dir`](#variable-kubernetes_local_pki_dir) points to.

## Further kubelet settings

Besides the `kubelet_config_*` variables listed below, the kubelet configuration that the role writes accepts further
variables named `kubelet_config_<field>`, where `<field>` is a field of the kubelet configuration in snake case (for
example `kubelet_config_max_pods` for `maxPods`); the role writes each of them that is defined into the kubelet
configuration of the node.

<!-- ANSIBLE DOCSMITH MAIN START -->
## Role variables

Create or upgrade the Kubernetes control plane of a control-plane node with kubeadm.

Copies the certificate authorities and the service-account key pair created by `furyctl create pki` to the node, writes the `kubeadm` configuration with the audit policy, the admission configuration, the optional encryption configuration and, when [`oidc_issuer_url`](#variable-oidc_issuer_url) is set, the OIDC authentication configuration of the API server, and runs `kubeadm init` on a node where the control plane does not exist yet.

On a node where the control plane exists, the role applies a changed configuration to the control-plane components, with a new API server certificate when [`kubernetes_apiserver_certSANs`](#variable-kubernetes_apiserver_certSANs) changed. It also creates the kubeconfig files of [`kubernetes_users_names`](#variable-kubernetes_users_names), fetches them and `admin.conf` to the furyctl host, and installs a CronJob that approves the serving certificate requests of the kubelets.

During an upgrade, the steps above run first. Because the target version is part of the `kubeadm` configuration, on an existing control plane they already apply the new version to the `kubeadm-config` ConfigMap and to the control-plane components. The role then activates the new versions of the kubernetes and kubeadm system extensions installed on the node, checks that the target version is at most one minor version away from the version of the node, renews the control-plane certificates and runs `kubeadm upgrade apply`.

| Variable | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| <a id="variable-kubernetes_version"></a>`kubernetes_version` | `str` | Yes | — | Kubernetes version of the control plane (`kubernetesVersion` of the `kubeadm` configuration). During an upgrade it is the target version, and the role refuses a target more than one minor version away from the version of the node before it runs `kubeadm upgrade apply`. This check comes after the role has applied the changed `kubeadm` configuration, with the new version, to the `kubeadm-config` ConfigMap and to the control-plane components of an existing control plane, so it does not prevent that change. |
| <a id="variable-kubelet_csr_approver_tag"></a>`kubelet_csr_approver_tag` | `str` | Yes | — | Tag of the `kubelet-csr-approver` image, pulled from [`kubernetes_image_registry`](#variable-kubernetes_image_registry). A CronJob in the `kube-system` namespace runs it every 5 minutes to approve the serving certificate requests of the kubelets. |
| <a id="variable-kubernetes_local_pki_dir"></a>`kubernetes_local_pki_dir` | `path` | No | `../pki/master` | Directory on the furyctl host with the Kubernetes PKI created by `furyctl create pki`. The role copies `ca.crt`, `ca.key`, `front-proxy-ca.crt`, `front-proxy-ca.key`, `sa.key` and `sa.pub` from it to `/etc/kubernetes/pki` on the node. |
| <a id="variable-audit_log_dir"></a>`audit_log_dir` | `path` | No | `/var/log/kubernetes` | Directory of the audit log of the API server, `kube-apiserver-audit.log`. The role creates it and mounts it into the API server. |
| <a id="variable-audit_policy_config_path"></a>`audit_policy_config_path` | `path` | No | `/etc/kubernetes/audit.yaml` | Path on the node where the role writes the audit policy of the API server, the policy that the role ships. The file is mounted into the API server. |
| <a id="variable-kubernetes_encryption_config"></a>`kubernetes_encryption_config` | `path` | No | `""` | File on the furyctl host with the encryption configuration of the API server. When set, the role copies it to [`kubernetes_remote_encryption_config`](#variable-kubernetes_remote_encryption_config) and gives it to the API server with the `encryption-provider-config` flag; when empty, the API server gets no encryption configuration. |
| <a id="variable-kubernetes_remote_encryption_config"></a>`kubernetes_remote_encryption_config` | `path` | No | `/etc/kubernetes/encryption-config.yml` | Path on the node of the encryption configuration of the API server, used when [`kubernetes_encryption_config`](#variable-kubernetes_encryption_config) is set. |
| <a id="variable-kubeadm_config_file"></a>`kubeadm_config_file` | `path` | No | `/etc/kubernetes/kubeadm.yml` | Path on the node of the `kubeadm` configuration that the role writes and that `kubeadm init` and the later `kubeadm` commands of the role read. |
| <a id="variable-kubeadm_patches_path"></a>`kubeadm_patches_path` | `path` | No | `/etc/kubernetes/patches/` | Directory of the `kubeadm` patches. The role writes there the kubelet configuration of the node and the patches that make the scheduler and the controller manager listen on the IPv4 address of the default network interface of the node, so that their metrics can be collected. |
| <a id="variable-kubeadm_config_path"></a>`kubeadm_config_path` | `path` | No | `/etc/kubernetes/kubeadm-config` | Directory where the role keeps backups when it applies a changed configuration to an existing control plane: the `kubeadm-config` ConfigMap and, when the subject alternative names of the API server change, the Kubernetes PKI of the node. |
| <a id="variable-kubernetes_users_kubeconfig_dir"></a>`kubernetes_users_kubeconfig_dir` | `path` | No | `/etc/kubernetes/users` | Directory on the node where the role creates the kubeconfig files of [`kubernetes_users_names`](#variable-kubernetes_users_names). |
| <a id="variable-kubernetes_users_names"></a>`kubernetes_users_names` | `list` | No | `[]` | Users for which the role creates a kubeconfig file, `<name>.kubeconfig`, with [`kubernetes_users_org`](#variable-kubernetes_users_org) as organization. The role fetches the files to [`kubernetes_kubeconfig_path`](#variable-kubernetes_kubeconfig_path) on the furyctl host. |
| <a id="variable-kubernetes_users_org"></a>`kubernetes_users_org` | `str` | No | `sighup` | Organization, which Kubernetes reads as a group, of the users of [`kubernetes_users_names`](#variable-kubernetes_users_names). |
| <a id="variable-kubernetes_kubeconfig_path"></a>`kubernetes_kubeconfig_path` | `path` | No | `.` | Directory on the furyctl host where the role fetches the kubeconfig files of [`kubernetes_users_names`](#variable-kubernetes_users_names), `admin.conf` and, during an installation, `super-admin.conf`. |
| <a id="variable-upgrade"></a>`upgrade` | `bool` | No | `false` | `true` when the role runs during a cluster upgrade. The role first runs the same steps as during an installation, which apply a changed `kubeadm` configuration, including a new [`kubernetes_version`](#variable-kubernetes_version), to the existing control plane. It then activates the new versions of the kubernetes and kubeadm system extensions installed on the node, checks the version skew and upgrades the control plane with `kubeadm upgrade apply`. During an upgrade, the role does not fetch `super-admin.conf`. |
| <a id="variable-kubernetes_hostname"></a>`kubernetes_hostname` | `str` | No | — | Name of the Kubernetes node (`nodeRegistration.name` of the `kubeadm` configuration). The node gets this name when `kubeadm init` registers it; changing the value later does not rename the node. During an upgrade, the role reads the version of the node under this name. Defaults to the fully qualified domain name of the node. |
| <a id="variable-kubernetes_apiserver_advertise_address"></a>`kubernetes_apiserver_advertise_address` | `str` | No | — | IP address that the API server of the node advertises to the cluster, on port 6443. Defaults to the IPv4 address of the default network interface of the node. |
| <a id="variable-kubernetes_control_plane_address"></a>`kubernetes_control_plane_address` | `str` | Yes | — | Address of the Kubernetes API server for the whole cluster (`controlPlaneEndpoint`), such as the virtual IP address or the load balancer in front of the control-plane nodes, with an optional port: for example `ctrl01.example.com:6443`. |
| <a id="variable-kubernetes_cluster_name"></a>`kubernetes_cluster_name` | `str` | No | `immutable-dev` | Name of the cluster (`clusterName` of the `kubeadm` configuration). furyctl always sets it from `metadata.name` of the cluster configuration. |
| <a id="variable-kubernetes_image_registry"></a>`kubernetes_image_registry` | `str` | No | `registry.sighup.io/fury/on-premises` | Registry of the control-plane images, of CoreDNS and of `kubelet-csr-approver`. furyctl always sets it: to `spec.kubernetes.advanced.registry` of the cluster configuration when that field is set, otherwise to the `imageRegistry` of the Kubernetes version in `immutable.yaml`, the versions file of the installer. |
| <a id="variable-coredns_image_prefix"></a>`coredns_image_prefix` | `str` | No | `/coredns` | Path appended to [`kubernetes_image_registry`](#variable-kubernetes_image_registry) to form the image repository of CoreDNS. When empty, the role does not set the image repository of CoreDNS. furyctl always sets it from `corednsImagePrefix` in `immutable.yaml`, the versions file of the installer. |
| <a id="variable-kubernetes_pod_cidr"></a>`kubernetes_pod_cidr` | `str` | No | `10.32.0.0/16` | IP range of the pods (`podSubnet` of `kubeadm`, and `clusterCIDR` of kube-proxy). |
| <a id="variable-kubernetes_svc_cidr"></a>`kubernetes_svc_cidr` | `str` | No | `10.96.0.0/16` | IP range of the services (`serviceSubnet` of `kubeadm`). |
| <a id="variable-kubernetes_cloud_provider"></a>`kubernetes_cloud_provider` | `str` | No | `""` | Value of the `cloud-provider` flag of the kubelet and of the controller manager. The kubelet gets the flag when `kubeadm init` sets up the node; the role passes a later change only to the controller manager. |
| <a id="variable-kubernetes_cloud_config"></a>`kubernetes_cloud_config` | `str` | No | `""` | Path on the node of the configuration file of the cloud provider. When set, the file is mounted into the controller manager and given to it with the `cloud-config` flag. |
| <a id="variable-kubernetes_apiserver_certSANs"></a>`kubernetes_apiserver_certSANs` | `list` | No | `[]` | Extra subject alternative names of the API server certificate: IP addresses or domain names. When the list changes on an existing control plane, the role backs up the Kubernetes PKI and generates a new API server certificate. |
| `etcd_endpoints` | `list` | No | [See details](#variable-etcd_endpoints) | Endpoints of the etcd cluster that the API server uses (`etcd.external.endpoints` of `kubeadm`). [Details](#variable-etcd_endpoints). |
| <a id="variable-etcd_ca_file"></a>`etcd_ca_file` | `path` | No | `/etc/etcd/pki/etcd/ca.crt` | Path on the node of the CA certificate with which the API server verifies etcd. |
| <a id="variable-etcd_key_file"></a>`etcd_key_file` | `path` | No | `/etc/etcd/pki/apiserver-etcd-client.key` | Path on the node of the client key of the API server for etcd. |
| <a id="variable-etcd_cert_file"></a>`etcd_cert_file` | `path` | No | `/etc/etcd/pki/apiserver-etcd-client.crt` | Path on the node of the client certificate of the API server for etcd. |
| <a id="variable-audit_policy_max_age"></a>`audit_policy_max_age` | `int` | No | `30` | Number of days the API server keeps a rotated audit log file (`audit-log-maxage`). |
| <a id="variable-audit_policy_max_size"></a>`audit_policy_max_size` | `int` | No | `100` | Size, in megabytes, at which the API server rotates the audit log (`audit-log-maxsize`). |
| <a id="variable-audit_policy_max_backup"></a>`audit_policy_max_backup` | `int` | No | `10` | Number of rotated audit log files the API server keeps (`audit-log-maxbackup`). |
| `eventratelimits` | `list` | No | [See details](#variable-eventratelimits) | Limits of the `EventRateLimit` admission plugin of the API server, which limits the rate at which events are accepted: a list of maps with the keys `type`, such as `Server`, `Namespace` or `User`, `qps`, `burst` and, optionally, `cacheSize`. [Details](#variable-eventratelimits). |
| <a id="variable-terminated_pod_gc_threshold"></a>`terminated_pod_gc_threshold` | `int` | No | `500` | Number of terminated pods that the controller manager keeps before it deletes them (`terminated-pod-gc-threshold`). Without it, the controller manager keeps 12500. |
| `tls_cipher_suites` | `list` | No | [See details](#variable-tls_cipher_suites) | TLS cipher suites that the API server, the scheduler and the controller manager accept (`tls-cipher-suites`). [Details](#variable-tls_cipher_suites). |
| <a id="variable-kubelet_certificate_authority_file"></a>`kubelet_certificate_authority_file` | `path` | No | `/etc/kubernetes/pki/ca.crt` | Path on the node of the CA certificate with which the API server verifies the serving certificates of the kubelets (`kubelet-certificate-authority`). |
| <a id="variable-oidc_issuer_url"></a>`oidc_issuer_url` | `str` | No | `""` | URL of the OpenID Connect (OIDC) issuer whose tokens the API server accepts to authenticate users. When set, the role writes an `AuthenticationConfiguration` file with the OIDC settings of this role to [`kubernetes_remote_authentication_config`](#variable-kubernetes_remote_authentication_config) and starts the API server with the `authentication-config` flag. When empty, the API server gets none of the OIDC settings of this role. |
| <a id="variable-oidc_client_id"></a>`oidc_client_id` | `str` | No | `""` | OIDC client ID, used when [`oidc_issuer_url`](#variable-oidc_issuer_url) is set. It is the first audience that the API server accepts in a token; [`oidc_extra_audiences`](#variable-oidc_extra_audiences) adds more, and a token needs only one of them. |
| <a id="variable-oidc_ca_file"></a>`oidc_ca_file` | `path` | No | — | Path on the node of the CA certificates with which the API server verifies the OIDC issuer, used when [`oidc_issuer_url`](#variable-oidc_issuer_url) is set. When the path differs from [`oidc_ca_file_default`](#variable-oidc_ca_file_default), the role reads the file and writes its content into the authentication configuration as `certificateAuthority`. Defaults to the value of [`oidc_ca_file_default`](#variable-oidc_ca_file_default); in that case the role writes no `certificateAuthority`, because the API server already trusts the system CA bundle. |
| <a id="variable-oidc_ca_file_default"></a>`oidc_ca_file_default` | `path` | No | `/etc/ssl/certs/ca-certificates.crt` | Path of the system CA bundle, which the API server already trusts. The role compares [`oidc_ca_file`](#variable-oidc_ca_file) with this value to decide whether it writes a `certificateAuthority`. To use another CA, set [`oidc_ca_file`](#variable-oidc_ca_file): changing only this value adds no `certificateAuthority`, because [`oidc_ca_file`](#variable-oidc_ca_file) follows it by default. |
| <a id="variable-oidc_username_claim"></a>`oidc_username_claim` | `str` | No | `email` | Claim of the OIDC token that the API server uses as the user name (`claimMappings.username.claim`), used when [`oidc_issuer_url`](#variable-oidc_issuer_url) is set. |
| <a id="variable-oidc_username_prefix"></a>`oidc_username_prefix` | `str` | No | `oidc:` | Prefix that the API server adds to the user names of OIDC users (`claimMappings.username.prefix`), used when [`oidc_issuer_url`](#variable-oidc_issuer_url) is set. The value `-` means no prefix. An empty value also means no prefix when [`oidc_username_claim`](#variable-oidc_username_claim) is `email`; with any other claim, an empty value makes the prefix the issuer URL followed by `#`. |
| <a id="variable-oidc_groups_claim"></a>`oidc_groups_claim` | `str` | No | `groups` | Claim of the OIDC token that the API server uses as the groups of the user (`claimMappings.groups.claim`), used when [`oidc_issuer_url`](#variable-oidc_issuer_url) is set. |
| <a id="variable-oidc_groups_prefix"></a>`oidc_groups_prefix` | `str` | No | `oidc:` | Prefix that the API server adds to the groups of OIDC users (`claimMappings.groups.prefix`), used when [`oidc_issuer_url`](#variable-oidc_issuer_url) is set. |
| <a id="variable-oidc_extra_audiences"></a>`oidc_extra_audiences` | `list` of `str` | No | `[]` | More audiences that the API server accepts in the OIDC tokens, in addition to [`oidc_client_id`](#variable-oidc_client_id), used when [`oidc_issuer_url`](#variable-oidc_issuer_url) is set. A token is accepted when it has at least one of the audiences. |
| <a id="variable-kubernetes_remote_authentication_config"></a>`kubernetes_remote_authentication_config` | `path` | No | `/etc/kubernetes/oidc/authentication-config.yaml` | Path on the node where the role writes the `AuthenticationConfiguration` file when [`oidc_issuer_url`](#variable-oidc_issuer_url) is set. The role creates the directory of the file and mounts that directory into the API server. |
| <a id="variable-kubeadm_skip_phases"></a>`kubeadm_skip_phases` | `list` | No | `[]` | `kubeadm` phases to skip in `kubeadm init` and `kubeadm upgrade apply`, for example the phase that installs kube-proxy. |
| `kubelet_tls_cipher_suites` | `list` | No | [See details](#variable-kubelet_tls_cipher_suites) | TLS cipher suites that the kubelet of the node accepts (`tlsCipherSuites` of the kubelet configuration). [Details](#variable-kubelet_tls_cipher_suites). |
| <a id="variable-kubelet_config_streaming_connection_idle_timeout"></a>`kubelet_config_streaming_connection_idle_timeout` | `str` | No | `5m` | Time after which the kubelet closes an idle streaming connection, such as the one of `kubectl exec` (`streamingConnectionIdleTimeout` of the kubelet configuration). |
| <a id="variable-kubelet_config_read_only_port"></a>`kubelet_config_read_only_port` | `int` | No | `0` | Port of the read-only API of the kubelet, which needs no authentication (`readOnlyPort` of the kubelet configuration). `0` disables it. |
| <a id="variable-kubelet_config_server_tls_bootstrap"></a>`kubelet_config_server_tls_bootstrap` | `bool` | No | `true` | When `true`, the kubelet requests its serving certificate from the cluster (`serverTLSBootstrap` of the kubelet configuration); the CronJob that the role installs approves these requests. |
| <a id="variable-kubelet_config_pod_pids_limit"></a>`kubelet_config_pod_pids_limit` | `int` | No | `4096` | Largest number of processes in a pod (`podPidsLimit` of the kubelet configuration). |
| `kubelet_config_cgroup_driver` | `str` | No | `systemd` | cgroup driver of the kubelet (`cgroupDriver` of the kubelet configuration). The containerd role configures containerd with the systemd cgroup driver. [Details](#variable-kubelet_config_cgroup_driver). |
| <a id="variable-kubernetes_taints"></a>`kubernetes_taints` | `list` | No | — | Taints of the node (`nodeRegistration.taints` of the `kubeadm` configuration), as a list of Kubernetes taints with the keys `key`, `value` and `effect`, set when `kubeadm init` registers the node. When unset, the role leaves the taints out of the `kubeadm` configuration and kubeadm gives the node its default control-plane taint, `node-role.kubernetes.io/control-plane:NoSchedule`; an empty list sets no taints. |
| <a id="variable-kubeadm_upgrade_config_file"></a>`kubeadm_upgrade_config_file` | `path` | No | `/etc/kubernetes/kubeadm-upgrade-config.yml` | Path on the node of the `kubeadm` configuration that the role writes for `kubeadm upgrade apply`. |
| <a id="variable-kubelet_config_path"></a>`kubelet_config_path` | `path` | No | `/var/lib/kubelet/kubelet-config` | Directory on the node whose `patches` subdirectory holds the kubelet configuration patch that the role writes during an upgrade and applies with `kubeadm upgrade node phase kubelet-config`. |

### `etcd_endpoints`<a id="variable-etcd_endpoints"></a>

Endpoints of the etcd cluster that the API server uses (`etcd.external.endpoints` of `kubeadm`).

Default:

```json
[
  "https://127.0.0.1:2379"
]
```

### `eventratelimits`<a id="variable-eventratelimits"></a>

Limits of the `EventRateLimit` admission plugin of the API server, which limits the rate at which events are accepted: a list of maps with the keys `type`, such as `Server`, `Namespace` or `User`, `qps`, `burst` and, optionally, `cacheSize`.

Default:

```json
[
  {
    "burst": 2000,
    "qps": 500,
    "type": "Server"
  },
  {
    "burst": 100,
    "cacheSize": 4096,
    "qps": 20,
    "type": "Namespace"
  },
  {
    "burst": 100,
    "cacheSize": 4096,
    "qps": 20,
    "type": "User"
  }
]
```

### `tls_cipher_suites`<a id="variable-tls_cipher_suites"></a>

TLS cipher suites that the API server, the scheduler and the controller manager accept (`tls-cipher-suites`).

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

### `kubelet_config_cgroup_driver`<a id="variable-kubelet_config_cgroup_driver"></a>

cgroup driver of the kubelet (`cgroupDriver` of the kubelet configuration). The containerd role configures containerd with the systemd cgroup driver.

Choices: `systemd`, `cgroupfs`.

<!-- ANSIBLE DOCSMITH MAIN END -->
