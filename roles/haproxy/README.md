# HAProxy

This Ansible role installs and configures HAproxy on a machine running on a container using `containerd` (no docker required).

## Configuration

| Variable                          | Description                                                     | Default Value                                                  |
| --------------------------------- | --------------------------------------------------------------- | -------------------------------------------------------------- |
| `haproxy_configuration_file_path` | Path where the configuration file will be stored in the host[1] | `/et/haproxy/haproxy.cfg`                                      |
| `haproxy_configuration`           | Configuration that will be written to the configuration file[2] | See `defaults/main.yaml` for an example, don't use the default |
| `haproxy_container_image`         | Container image name, including registry                        | `registry.sighup.io/fury/on-premises/haproxy`                  |
| `haproxy_container_tag`           | Container image tag                                             | `3.2.9`                                                        |

[1] The **whole folder** that contains the configuration file in the host will be mounted on the container on the `/usr/local/` path.

[2] Please note that the Prometheus frontend will always be enabled and included in the configuration because it is used by the playbook to check if HAProxy is properly running.
