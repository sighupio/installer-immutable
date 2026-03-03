# HAProxy Role for SD Immutable

This Ansible role installs and configures HAproxy on a machine running on a container using `containerd` (no docker required).

## Prerequisites

- [`containerd`](../containerd/README.md)

## Configuration

| Variable                          | Description                                                     | Default Value                                                  |
| --------------------------------- | --------------------------------------------------------------- | -------------------------------------------------------------- |
| `haproxy_configuration_file_path` | Path where the configuration file will be stored in the host[1] | `/et/haproxy/haproxy.cfg`                                      |
| `haproxy_configuration`           | Configuration that will be written to the configuration file[2] | See `defaults/main.yaml` for an example, don't use the default |
| `haproxy_container_image`         | Container image name, including registry                        | `registry.sighup.io/fury/on-premises/haproxy`                  |
| `haproxy_container_tag`           | Container image tag                                             | `3.2.9`                                                        |
| `kubernetes_local_pki_dir`        | Path to the local Kubernetes PKI directory (optional)[3]        | Unset                                                          |

[1] The **whole folder** that contains the configuration file in the host will be mounted on the container on the `/usr/local/` path.

[2] Please note that the Prometheus frontend will always be enabled and included in the configuration because it is used by the playbook to check if HAProxy is properly running.

[3] You can set the `kubernetes_local_pki_dir` variable to a furyctl-generated `pki/master` folder in the host running Ansible. If the variable is set, the role will automatically copy the Kubernetes CA certificate so you can use it to check SSL status on the control plane nodes. NOTE: The files will be copied to the `/usr/local/etc/haproxy/` path inside the haproxy container.
