# Kube-worker Role for SD Immutable Kind

## Assumptions

- `kubernetes` sysext from [installer-immutable-sysext][immutable-sysext] repository
- A working control-plane to join the nodes to

## Configuration

Here's a list of the most relevant configuration options of the role. For a full list see the [defaults file](./defaults/main.yaml).

| Variable                           | Description                                                                         | Default Value                 |
| ---------------------------------- | ----------------------------------------------------------------------------------- | ----------------------------- |
| `kubernetes_control_plane_address` | Address where the to reach the Kubernetes API server (e.g. the Load Balancer's VIP) | `{{ ansible_facts['fqdn'] }}` |
| `kubernetes_bootstrap_token`       | Bootstrap token acquired from a control plane node via kubeadm                      | Unset                         |
| `kubernetes_ca_hash`               | The hash of the Kubernetes CA for joining the node to the cluster                   | Unset                         |
| `kubernetes_hostname`              | The name which to register the node with into Kubernetes                            | `{{ ansible_facts['fqdn'] }}` |
| `kubernetes_role`                  | Role of the node                                                                    | `worker`                      |
| `kubernetes_taints`                | Taints added via the Kubelet                                                        | `[]`                          |

[immutable-sysext]: https://github.com/sighupio/installer-immutable-sysext
