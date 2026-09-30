# `haproxy` role

The `haproxy` role runs [HAProxy](https://www.haproxy.org/), the load balancer of the Kubernetes API server, as a
container that containerd starts and systemd manages: Docker is not needed. furyctl runs it during the installation of a
cluster; see the [installer README](../../README.md) for how furyctl uses the roles.

## Requirements

- containerd runs on the node, configured by the [`containerd` role](../containerd/README.md).
- The node can pull the HAProxy container image from its registry.

<!-- ANSIBLE DOCSMITH MAIN START -->
## Role variables

Run HAProxy on the node as a container managed by systemd.

Pulls the HAProxy container image with containerd, writes the HAProxy configuration file and a systemd unit that runs HAProxy with `ctr`, and starts the service. The role pulls the image on every run and reports a change when the tag points to a new image; it does not restart HAProxy for a new image alone, so the running container keeps the old image until the service restarts. A changed configuration is first checked in a temporary container, then loaded by a reload of HAProxy; a changed unit restarts the service. The role ends by waiting until port 8405, the Prometheus frontend of HAProxy, is open.

| Variable | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| <a id="variable-haproxy_container_image"></a>`haproxy_container_image` | `str` | Yes | — | Container image of HAProxy, with its registry and without the tag. containerd pulls it with the registry configurations in `/etc/containerd/certs.d`. |
| <a id="variable-haproxy_container_tag"></a>`haproxy_container_tag` | `str` | Yes | — | Tag of the HAProxy container image. |
| `haproxy_configuration_file_path` | `path` | No | `/etc/haproxy/haproxy.cfg` | Path of the HAProxy configuration file on the node. The whole directory that holds the file is mounted into the container at `/usr/local/etc/haproxy/`, read-only. [Details](#variable-haproxy_configuration_file_path). |
| `haproxy_configuration` | `str` | No | [See details](#variable-haproxy_configuration) | Content of the HAProxy configuration file, before the Prometheus frontend that the role appends. [Details](#variable-haproxy_configuration). |
| <a id="variable-kubernetes_local_pki_dir"></a>`kubernetes_local_pki_dir` | `path` | No | — | Directory on the furyctl host with the Kubernetes PKI created by `furyctl create pki`, such as its `pki/master` directory. When set, the role copies the Kubernetes CA certificate `ca.crt` from it next to the HAProxy configuration file, as `kubernetes.crt`; HAProxy finds it at `/usr/local/etc/haproxy/kubernetes.crt`, for example to check the TLS certificates of the control-plane nodes. When unset, the role copies nothing. |

### `haproxy_configuration_file_path`<a id="variable-haproxy_configuration_file_path"></a>

Path of the HAProxy configuration file on the node. The whole directory that holds the file is mounted into the container at `/usr/local/etc/haproxy/`, read-only.

The check of a changed configuration reads `/usr/local/etc/haproxy/haproxy.cfg` in the container, so the file name must stay `haproxy.cfg`.

### `haproxy_configuration`<a id="variable-haproxy_configuration"></a>

Content of the HAProxy configuration file, before the Prometheus frontend that the role appends.

The Prometheus frontend is always enabled: the role appends to the file a `prometheus` frontend that serves the HAProxy metrics on port 8405, and uses it to check that HAProxy runs.

The default is an example that only serves a statistics page on port 1936 and has no backend for the Kubernetes API server: do not use it for a cluster.

Default:

```text
# example haproxy.cfg
global
  maxconn 512
frontend stats
  bind *:1936
  mode http
  log global
  maxconn 10
  timeout client 100s
  stats enable
  stats uri /stats
  stats hide-version
  stats refresh 30s
  stats show-node
```

<!-- ANSIBLE DOCSMITH MAIN END -->
