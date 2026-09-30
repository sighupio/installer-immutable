# `keepalived` role

The `keepalived` role runs [keepalived](https://www.keepalived.org/) on a group of nodes so that they share a virtual IP
address, such as the address of the Kubernetes API server of a highly available cluster. furyctl runs it during the
installation of a cluster and again during an upgrade, when the role also stages the new keepalived version; see the
[installer README](../../README.md) for how furyctl uses the roles.

## Requirements

- The keepalived system extension from the
  [installer-immutable-sysext](https://github.com/sighupio/installer-immutable-sysext) repository is installed on the node.
- The facts of every node of [`keepalived_ansible_group_name`](#variable-keepalived_ansible_group_name) are gathered in
  the same run: the role reads the address of each peer from them.
- When [`keepalived_on_controlplane`](#variable-keepalived_on_controlplane) is `false`, HAProxy runs on the same nodes,
  configured by the [`haproxy` role](../haproxy/README.md): the health check of keepalived looks for its process.

## Which node holds the virtual IP address

The node whose short host name ends with `1` starts as the `MASTER` of the VRRP instance, with priority 101; the other
nodes start as `BACKUP`, with priority 100. The health check that
[`keepalived_on_controlplane`](#variable-keepalived_on_controlplane) selects then changes the priority of each node.

<!-- ANSIBLE DOCSMITH MAIN START -->
## Role variables

Run keepalived on the node to share a virtual IP address between a group of nodes.

When [`keepalived_cluster`](#variable-keepalived_cluster) is `true`, writes the keepalived configuration, with one VRRP instance that holds the virtual IP address [`keepalived_ip`](#variable-keepalived_ip) and the other nodes of [`keepalived_ansible_group_name`](#variable-keepalived_ansible_group_name) as unicast peers, checks it, reloads keepalived when it changed, and starts and enables the service. When [`keepalived_cluster`](#variable-keepalived_cluster) is `false`, the role stops, disables and masks keepalived. During an upgrade, the role also stages the new keepalived system extension, which the reboot of the node activates, whatever the value of [`keepalived_cluster`](#variable-keepalived_cluster) is.

| Variable | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| <a id="variable-keepalived_cluster"></a>`keepalived_cluster` | `bool` | No | `false` | Whether keepalived runs on the node. `true` configures and starts keepalived; `false` stops, disables and masks the keepalived service. |
| <a id="variable-keepalived_interface"></a>`keepalived_interface` | `str` | No | `eth0` | Network interface of the VRRP instance. The role also reads the IPv4 address of this interface on every other node of [`keepalived_ansible_group_name`](#variable-keepalived_ansible_group_name) to list the unicast peers, so each of those nodes needs an interface with this name. |
| <a id="variable-keepalived_on_controlplane"></a>`keepalived_on_controlplane` | `bool` | No | `false` | Whether keepalived runs on control-plane nodes. When `true`, keepalived checks every 3 seconds that the Kubernetes API server answers on `https://localhost:6443/healthz`; when `false`, it checks every 2 seconds that an HAProxy process runs on the node. The result of the check changes the VRRP priority of the node. |
| <a id="variable-keepalived_passphrase"></a>`keepalived_passphrase` | `str` | No | `12345678` | Password that the nodes of the VRRP instance share (`auth_pass`, with `PASS` authentication). |
| <a id="variable-keepalived_virtual_router_id"></a>`keepalived_virtual_router_id` | `str` | No | `51` | Virtual router ID of the VRRP instance, a number written as a string. It must be unique among the VRRP clusters of the same network. |
| <a id="variable-keepalived_ansible_group_name"></a>`keepalived_ansible_group_name` | `str` | No | `load_balancers` | Inventory group of the nodes that form the keepalived cluster; the role lists the other nodes of the group as unicast peers. The configuration fails when the group has only one node. |
| <a id="variable-keepalived_ip"></a>`keepalived_ip` | `str` | No | — | Virtual IP address that the node holding the VRRP instance carries. The role has no default for it: set it whenever [`keepalived_cluster`](#variable-keepalived_cluster) is `true`. |
| <a id="variable-upgrade"></a>`upgrade` | `bool` | No | — | `true` when the role runs during a cluster upgrade. The role then stages the new keepalived system extension, which the reboot of the node activates. Unset means `false`. |

<!-- ANSIBLE DOCSMITH MAIN END -->
