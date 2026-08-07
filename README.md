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

> [!WARNING]
> The Immutable Installer is in **alpha** status and is under active development. Its configuration and behavior can
> change between releases.

<!-- <SD-DOCS> -->

**Immutable Installer** is a Kubernetes installer for the [SIGHUP Distribution (SD)][sd-repo]. The installer has a set of
Ansible roles that create a Kubernetes cluster on [Flatcar Container Linux][flatcar-site] machines.

If you are new to SD, refer to the [official documentation][sd-docs] to get started.

## Overview

The installer uses open source tools to create a Kubernetes cluster on Flatcar Container Linux machines. `furyctl`
bootstraps and configures these machines with [Ignition][ignition] and with the system extensions (`sysext`) from the
[`installer-immutable-sysext`][immutable-sysext] repository.

## Roles

These roles are part of the SIGHUP Distribution Immutable Installer:

| Role                                           | Description                                                                                   |
| ---------------------------------------------- | --------------------------------------------------------------------------------------------- |
| [containerd](roles/containerd)                 | Ansible role to configure [`containerd`][containerd] as the container runtime                 |
| [etcd](roles/etcd)                             | Ansible role to configure [`etcd`][etcd] on the control-plane nodes or on separate nodes      |
| [haproxy](roles/haproxy)                       | Ansible role to configure [`HAProxy`][haproxy] as the load balancer for the API server        |
| [keepalived](roles/keepalived)                 | Ansible role to configure `keepalived` for a virtual IP address that the nodes share (HA)     |
| [kube-control-plane](roles/kube-control-plane) | Ansible role to configure the control-plane nodes                                             |
| [kube-worker](roles/kube-worker)               | Ansible role to configure the worker nodes and to join them to the cluster                    |
| [node-maintenance](roles/node-maintenance)     | Task-file library for upgrades: it cordons, drains, and then uncordons a node                 |
| [os-upgrade](roles/os-upgrade)                 | Task-file library for upgrades: it does the Flatcar A/B OS update (stage, reboot, mark good)  |
| [sysctl](roles/sysctl)                         | Ansible role to configure the kernel parameters on the machines                               |
| [sysext](roles/sysext)                         | Helper role to align the binary system extensions to their target versions                    |
| [upgrade-gates](roles/upgrade-gates)           | Task-file library for upgrades: read-only checks of the cluster health and the infrastructure |

Click on each role to read its full documentation.

## Compatibility

Refer to the [compatibility matrix][compatibility-matrix] for the versions that this installer supports.

## Usage

To create or to upgrade a Kubernetes cluster with this installer, use [`furyctl`][furyctl-repo]. `furyctl` is our companion
CLI tool that manages the full life cycle of SD clusters.

The `Immutable` provider automates this installer completely. SIGHUP does not support stand-alone use of the installer.
If you use it stand-alone, you accept the risk.

The [Immutable Installation Guide][immutable-install] shows how the `Immutable` kind installs a cluster, on bare-metal
machines or on virtual machines. The guide is an index: it shows the boot decision and the flow that all the cases have in
common. It also links to one document for each case: DHCP and PXE, iPXE ISO, deploy DHCP, and manual OS ISO. In the guide,
key terms link to their official documentation.

<!-- Links -->

[furyctl-repo]: https://github.com/sighupio/furyctl/
[immutable-install]: docs/IMMUTABLE_INSTALL.md
[compatibility-matrix]: https://github.com/sighupio/installer-immutable/blob/main/docs/COMPATIBILITY_MATRIX.md
[sd-repo]: https://github.com/sighupio/distribution/
[sd-docs]: https://docs.sighup.io/docs/distribution/
[getting-started]: https://docs.sighup.io/docs/getting-started/distro-on-vms
[immutable-sysext]: https://github.com/sighupio/installer-immutable-sysext
[flatcar-site]: https://www.flatcar.org/
[ignition]: https://coreos.github.io/ignition/
[containerd]: https://containerd.io/
[etcd]: https://etcd.io/
[haproxy]: https://www.haproxy.org/

<!-- </SD-DOCS> -->

<!-- <FOOTER> -->

### Reporting Issues

In case you experience any problems with the installer, please [open a new issue](https://github.com/sighupio/installer-immutable/issues/new/choose).

## License

This module is open-source and it's released under the following [LICENSE](LICENSE).

<!-- </FOOTER> -->
