<!-- markdownlint-disable MD013 MD060 -->
# Installing the SIGHUP Distribution Immutable Kind

[`furyctl`][furyctl] is the cluster lifecycle CLI for the [SIGHUP Distribution (SD)][sd-repo]. Its
**Immutable kind** — implemented by this repository — installs Kubernetes onto a **node**, which may be a
**bare-metal machine or a virtual machine**. This page is the overview: it shows the boot decision, links to a
focused document per case, and describes the flow that every case shares. Key terms link to their official
docs inline on first mention.

> **Scope — what actually runs the install.** The boot and provisioning described here (Ignition generation,
> iPXE serving, the boot cases) is performed by [`furyctl`][furyctl], **not by this repository**. This
> repository provides the post-boot [Ansible roles](../roles) that assemble Kubernetes once a node is already
> running [Flatcar][flatcar]. Your job is to configure the environment (DHCP / PXE / boot media) so furyctl
> can reach each node and serve it the right config.

## Prerequisites

The Immutable kind is **alpha** and is driven entirely by [`furyctl`][furyctl] — install **furyctl ≥ 0.34.2**
(see the [compatibility matrix][compatibility-matrix]). Before you start, gather:

- **A furyctl host** — a machine that runs furyctl and whose built-in boot server (HTTP, default port `8080`)
  every node can reach over the network.
- **Per node:** its **MAC address**, the **install disk** (e.g. `/dev/sda`), and its network settings
  (static IP / gateway / DNS, or DHCP).
- **An SSH public key** — injected into every node for `core`-user access.
- **`kubectl`** on the furyctl host, to verify the cluster afterwards.

## The boot decision: pick your case

How a node gets bootstrapped depends on the network — specifically, whether a [DHCP][dhcp] server exists and
whether you can change it. The decision tree is captured in the diagram below
([source `.puml`](immutable-baremetal-decision.puml)):

![Immutable installation decision flow](immutable-baremetal-decision.png)

The four cases are **target-agnostic** — they apply whether the node is bare metal or a VM (a VM is just a node
on a virtual network, with media attached as a virtual CD-ROM). Pick the one that matches your network:

| Your network situation                    | Case document                                          | furyctl automation |
| ----------------------------------------- | ------------------------------------------------------ | ------------------ |
| [DHCP][dhcp] exists **and** you can modify it | [Existing DHCP with PXE flags](install-case-dhcp-pxe.md)   | Full           |
| DHCP exists but you **cannot** modify it  | [iPXE ISO boot](install-case-ipxe-iso.md)                  | Full               |
| No DHCP, but you **can deploy** one       | [Deploy a new DHCP + PXE](install-case-deploy-dhcp.md)     | Full               |
| No DHCP **and** none deployable           | [Manual OS ISO install](install-case-os-iso.md)            | Ignition only      |

Cases 1–3 converge on a network [iPXE][ipxe] boot; case 4 is the fully manual fallback where only the
[Ignition][ignition] config is served by furyctl.

## Shared flow (every case)

Whatever case bootstraps the node, the rest of the install is the same:

1. **furyctl generates the assets.** From your cluster configuration and each node's **MAC address**,
   [`furyctl`][furyctl] generates an [Ignition][ignition] config and the [PXE][pxe]/[iPXE][ipxe] boot assets,
   then serves each node the right config **based on its MAC address**.
2. **The node boots.** Per the chosen case, the node reaches furyctl's iPXE server; the iPXE script carries the
   kernel/initrd URLs, the Ignition config URL, and the network configuration, and downloads the
   [Flatcar][flatcar] assets (kernel + initrd).
3. **Ignition applies.** furyctl serves the Ignition config for that MAC; Flatcar boots with it and Ignition
   applies it during first boot — partitioning disks, creating users, writing network config, and enabling
   services. The node comes up **fully configured**, with the pinned [systemd-sysext][sysext] component images
   in place.
4. **Ansible roles assemble the cluster.** The installer's [Ansible roles](../roles) bring up Kubernetes
   itself — `containerd`, `etcd`, `keepalived` (the control-plane **VIP**), `haproxy` (APIServer load balancer),
   `kube-control-plane` (which runs [`kubeadm`][kubeadm] to bootstrap the control plane), `kube-worker`, and
   `sysctl` — turning a fleet of identical nodes into a working SD cluster, ready for the Distribution phase.

## Installing with furyctl

The boot environment from your chosen case is the only part that differs; the furyctl commands are the same for
every case:

1. **Scaffold the config.** Pick a `--version` supported for the Immutable kind (see the
   [compatibility matrix][compatibility-matrix]):

   ```sh
   furyctl create config --kind Immutable --version <vX.Y.Z> --name <cluster>
   ```

2. **Fill in `furyctl.yaml`** — the boot-server URL, an SSH key, and one entry per node (its **MAC address**,
   install disk, and network). Minimal shape:

   ```yaml
   apiVersion: kfd.sighup.io/v1alpha2
   kind: Immutable
   metadata:
     name: <cluster>
   spec:
     distributionVersion: <vX.Y.Z>
     infrastructure:
       ipxeServer:
         url: "http://<furyctl-host>:8080"   # built-in boot server; bindAddress/bindPort optional
       ssh:
         username: "core"
         keyPath: "${HOME}/.ssh/id_ed25519.pub"
       nodes:
         - hostname: "ctrl01.example.local"
           macAddress: "52:54:00:10:00:01"   # keys this node's per-MAC boot + Ignition config
           storage:
             installDisk: "/dev/sda"
           network:
             ethernets:
               eth0:
                 addresses: ["192.168.1.11/24"]
                 gateway: "192.168.1.1"
                 nameservers:
                   addresses: ["8.8.8.8"]
     kubernetes:
       version: "<x.y.z>"
       networking:
         podCIDR: "10.244.0.0/16"
         serviceCIDR: "10.96.0.0/12"
       controlPlane:
         address: "ctrl01.example.local:6443"
         members:
           - hostname: "ctrl01.example.local"
       etcd:
         members:
           - hostname: "ctrl01.example.local"
       nodeGroups:
         - name: workers
           nodes:
             - hostname: "worker01.example.local"
     # spec.distribution.modules: see the SIGHUP Distribution docs
   ```

3. **Generate the PKI** (control-plane + etcd certificates):

   ```sh
   furyctl create pki
   ```

4. **Apply.** The `infrastructure` phase brings up furyctl's boot server (iPXE + [Ignition][ignition] + Flatcar
   assets) on `0.0.0.0:8080` and waits for the nodes to report booted:

   ```sh
   furyctl apply --phase infrastructure   # serves per-MAC configs — power on the nodes now
   furyctl apply                          # continue: kubernetes, distribution, plugins
   ```

   You can also run the server standalone:
   `furyctl serve --address 0.0.0.0 --port 8080 --path <workdir>/.furyctl/state/infrastructure/server`.

## Verify the cluster

When `furyctl apply` finishes, point `kubectl` at the kubeconfig furyctl writes to the working directory and
check the nodes:

```sh
export KUBECONFIG="$PWD/kubeconfig"   # path furyctl reports at the end of apply
kubectl get nodes
```

Every control-plane and worker node from `furyctl.yaml` should appear and reach **Ready**. From here the cluster
is ready for the Distribution phase.

<!-- Links -->

[sd-repo]: https://github.com/sighupio/distribution/
[furyctl]: https://github.com/sighupio/furyctl/
[flatcar]: https://www.flatcar.org/
[ignition]: https://coreos.github.io/ignition/
[sysext]: https://www.freedesktop.org/software/systemd/man/latest/systemd-sysext.html
[pxe]: https://ipxe.org/howto/chainloading
[ipxe]: https://ipxe.org/
[dhcp]: https://datatracker.ietf.org/doc/html/rfc2131
[kubeadm]: https://kubernetes.io/docs/reference/setup-tools/kubeadm/
[compatibility-matrix]: COMPATIBILITY_MATRIX.md
