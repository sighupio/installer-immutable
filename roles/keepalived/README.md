# Keepalived Role for SD Immutable

## Assumptions

- keepalived sysext from [installer-immutable-sysext][immutable-sysext] repository

## Configuration

Here's a list of the most relevant configuration options of the role. For a full list see the [defaults file](./defaults/main.yaml).

| Variable                        | Description                                                                                                | Default Value    |
| ------------------------------- | ---------------------------------------------------------------------------------------------------------- | ---------------- |
| `keepalived_cluster`            | Boolean field to enable or disable keepalived                                                              | `false`          |
| `keepalived_interface`          | Interface to bind keepalived to                                                                            | `eth0`           |
| `keepalived_on_controlplane`    | Boolean indicating wether keepalived is running on a Kubernetes control plane node                         | `false`          |
| `keepalived_passphrase`         | Keepalived VRRP passphrase                                                                                 | `12345678`       |
| `keepalived_virtual_router_id`  | VRRP Virtual Router ID (must be unique between this and other potential VRRP clusters in the same network) | `51`             |
| `keepalived_ansible_group_name` | The Ansible Inventory group that contains the nodes to create the keepalived cluster with [1]              | `load_balancers` |

[1] NOTE: if the Ansible group has only one node, configuration will fail.

[immutable-sysext]: https://github.com/sighupio/installer-immutable-sysext
