# kube-control-plane Role for SD Immutable

## Assumptions

- `kubernetes` sysext from [installer-immutable-sysext][immutable-sysext] repository

## Configuration

Here's a list of the most relevant configuration options of the role. For a full list see the [defaults file](./defaults/main.yaml).

| Variable                           | Description                                                                                            | Default Value                |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------ | ---------------------------- |
| `kubernetes_cluster_name`          | Name for the cluster, to be saved in kubeadm's configuration                                           | `immutable-dev`              |
| `kubernetes_control_plane_address` | Address where the Kubernetes API server will be accesible (e.g. the Load Balancer VIP in HA clusters.) | host's fqdn                  |
| `kubeadm_skip_phases`              | Phases to skip while initializing the cluster, e.g. `kubeProxy`                                        | `[]`                         |
| `etcd_endpoints`                   | List of etcd endpoints                                                                                 | `["https://127.0.0.1:2379"]` |

[immutable-sysext]: https://github.com/sighupio/installer-immutable-sysext
