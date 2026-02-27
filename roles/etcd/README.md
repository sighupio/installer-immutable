# etcd Role for SD Immutable

## Assumptions

This role assumes:

- etcd sysext from [installer-immutable-sysext][immutable-sysext] repository
- etcd sysext is loaded (binaries, user, service)
- kubernetes sysext is loaded (kubeadm for cert generation)
- Butane created /etc/etcd/etcd.env (placeholder) and /var/lib/etcd
- furyctl create pki generated the CA in pki/etcd/

## Configuration

Here's a list of the most relevant configuration options of the role. For a full list see the [defaults file](./defaults/main.yaml).

| Variable                | Description                                                                    | Default Value |
| ----------------------- | ------------------------------------------------------------------------------ | ------------- |
| `etcd_on_control_plane` | Determines whether etcd is running or not on Kubernetes control plane nodes[1] | `true`        |
| `etcd_endpoints`        | List of endpoints used to connect to etcd using etcdctl                        | `[]`          |
| `etcd_initial_cluster`  | Comma-sperated list of the initial cluster members [2]                         | ``            |
| `etcd_pki_local_dir`    | Path to the folder that contains the PKI (CA and certificates) for etcd [3]    | `../pki/etcd` |

[1] When etcd is not running on the control plane nodes there are tasks that will run like copying the needed certificates.
[2] Important to set this parameter, otherwise the etcd cluster won't start.
[3] Expected folder structure is the one from the output of the `furyctl create pki` command.

[immutable-sysext]: https://github.com/sighupio/installer-immutable-sysext
