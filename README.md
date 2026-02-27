<!-- markdownlint-disable MD033 -->
<h1 align="center">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/sighupio/distribution/refs/heads/main/docs/assets/white-logo.png">
  <source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/sighupio/distribution/refs/heads/main/docs/assets/black-logo.png">
  <img alt="Shows a black logo in light color mode and a white one in dark color mode." src="https://raw.githubusercontent.com/sighupio/distribution/refs/heads/main/docs/assets/white-logo.png">
</picture><br/>
Kubernetes Installer for Immutable Kind
</h1>
<!-- markdownlint-enable MD033 -->

![Release](https://img.shields.io/badge/Latest%20Release-valpha1-blue)
![License](https://img.shields.io/github/license/sighupio/installer-immutablelabel=License)
![Slack](https://img.shields.io/badge/slack-@kubernetes/fury-yellow.svg?logo=slack&label=Slack)

> [!CAUTION]
> WORK IN PROGRESS

<!-- <SD-DOCS> -->

**Immutable Installer** is a Kubernetes installer for the [SIGHUP Distribution (SD)][sd-repo] that provides
several Ansible roles to create a Kubernetes cluster on top of Flatcar Container Linux machines.

If you are new to SD please refer to the [official documentation][sd-docs] on how to get started with SD.

## Overview

**Immutable Installer** uses a collection of open source tools to create a Kubernetes cluster on top of Flatcar Container Linux machines preconfigured using the `sysupdate-sysext` from the [`installer-immutable-sysext`][immutable-sysext] repository.

## Roles

The following roles are included in the SIGHUP Distributino Immutable Installer:

| Role                                           | Description                                                                      |
| ---------------------------------------------- | -------------------------------------------------------------------------------- |
| [containerd](roles/containerd)                 | Ansible role to configure containerd as container runtime                        |
| [etcd](roles/etcd)                             | Ansible role to configure etcd standalone or in the control plane machines       |
| [haproxy](roles/haproxy)                       | Ansible role to configure HAProxy as load balancer for the APIServer (and other) |
| [keepalived](roles/keepalived)                 | Ansible role to configure keepalived for a shared Virtual IP between nodes (HA)  |
| [kube-control-plane](roles/kube-control-plane) | Ansible role to configure control-plane nodes                                    |
| [kube-worker](roles/kube-worker)               | Ansible role to configure worker nodes and join them to the cluster              |
| [sysctl](roles/sysctl)                         | Ansible role to configure kernel paramaters on the machines                      |

Click on each package to see its full documentation.

## Compatibility

This version is compatible with Kubernetes 1.34.4 plus the complete list in the compatibility matrix.

Check the [compatibility matrix][compatibility-matrix] for additional information about previous releases of the module.

## Usage

This installer is intended to be used via `furyctl` and not to be used stand-alone. Use at your own risk.

<!-- Links -->

[furyctl-repo]: https://github.com/sighupio/furyctl/
[compatibility-matrix]: https://github.com/sighupio/installer-immutable/blob/master/docs/COMPATIBILITY_MATRIX.md
[sd-repo]: https://github.com/sighupio/distribution/
[sd-docs]: https://docs.sighup.io/docs/distribution/
[getting-started]: https://docs.sighup.io/docs/getting-started/distro-on-vms
[immutable-sysext]: https://github.com/sighupio/installer-immutable-sysext

<!-- </SD-DOCS> -->

<!-- <FOOTER> -->

### Reporting Issues

In case you experience any problems with the installer, please [open a new issue](https://github.com/sighupio/installer-immutable/issues/new/choose).

## License

This module is open-source and it's released under the following [LICENSE](LICENSE).

<!-- </FOOTER> -->
