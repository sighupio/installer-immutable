<!-- markdownlint-disable MD013 -->
# Install case: deploy a new DHCP + PXE

> Part of the [Immutable install guide](IMMUTABLE_INSTALL.md). Key terms link to their official docs inline.

## When to use this case

Use this case when the network segment **has no [DHCP][dhcp] server, but you are able to deploy one**. After
standing up DHCP with [PXE][pxe] flags, the path is the same fully-automated network boot as the
"existing DHCP" case. The target node can be **bare metal or a virtual machine** — for VMs, the new DHCP/PXE
service is typically a small VM on the same virtual network.

## Flow

![Case 3 flow — deploy a new DHCP + PXE](immutable-case-deploy-dhcp.png)

> [Diagram source](immutable-case-deploy-dhcp.puml) · continues into the
> [Shared flow (every case)](IMMUTABLE_INSTALL.md#shared-flow-every-case).

## How to set it up

[`furyctl`][furyctl] serves the iPXE script and [Ignition][ignition] config but **does not run DHCP or TFTP** —
so the new DHCP service must hand plain PXE clients the iPXE bootloader (`ipxe.efi`) over TFTP and then chainload
iPXE clients to furyctl. There is **no official [`dnsmasq`][dnsmasq] container** (dnsmasq ships only as source / distro
packages), so — following the Flatcar / [matchbox][matchbox] ecosystem recommendation — we deploy the
`quay.io/poseidon/dnsmasq` container: it does DHCP + TFTP + iPXE chainload in one command and **bundles the
iPXE binaries** (`undionly.kpxe`, `ipxe.efi`), so there is nothing to build by hand.

Run the container on a host reachable on the node's network segment. There are **two equivalent ways** — pick
whichever fits your workflow.

### Option A — declarative (config file, clean command)

Copy [`examples/dnsmasq.conf`](examples/dnsmasq.conf) (validated with `dnsmasq --test`), set
`<furyctl-host>` in it, then mount it into the container:

```sh
docker run --rm --cap-add=NET_ADMIN --net=host \
  -v "$PWD/dnsmasq.conf:/etc/dnsmasq.conf:ro" \
  quay.io/poseidon/dnsmasq -d -q
```

The command stays short and the DHCP/PXE settings live in a reviewable, versionable file.

### Option B — command-only (one-shot, flags inline)

Same directives, no file — everything on the command line:

```sh
docker run --rm --cap-add=NET_ADMIN --net=host quay.io/poseidon/dnsmasq -d -q \
  --dhcp-range=192.0.2.50,192.0.2.150,12h \
  --enable-tftp --tftp-root=/var/lib/tftpboot \
  --dhcp-userclass=set:ipxe,iPXE \
  --dhcp-boot=tag:ipxe,http://<furyctl-host>:8080/boot/${mac:hexhyp} \
  --dhcp-boot=ipxe.efi     # iPXE clients → furyctl URL above; everyone else → ipxe.efi (UEFI fleet)
```

> **Mixed BIOS + UEFI fleet?** The single `--dhcp-boot=ipxe.efi` fallback assumes a UEFI fleet (the modern
> default — bare metal and every hypervisor). Only if you also have legacy-BIOS nodes do you need to match
> architecture ([option 93][rfc4578], because BIOS firmware cannot run `ipxe.efi`); replace that fallback with:
> `--dhcp-match=set:bios,option:client-arch,0 --dhcp-boot=tag:bios,undionly.kpxe` and
> `--dhcp-match=set:efi,option:client-arch,7 --dhcp-boot=tag:efi,ipxe.efi`.

### Then, either way

1. Start furyctl so its iPXE/Ignition boot server is serving per-MAC configs — see
   [Installing with furyctl](IMMUTABLE_INSTALL.md#installing-with-furyctl) (`furyctl apply --phase infrastructure`).
2. Set each node to **network boot** and power it on. It net-boots via the container, chainloads to furyctl,
   pulls its config, boots [Flatcar][flatcar], and continues through the shared flow.

> **Why this image?** There is no Docker Official Image or verified-publisher dnsmasq container, so we use the
> Flatcar/matchbox ecosystem recommendation: [`quay.io/poseidon/dnsmasq`][matchbox] (the matchbox project's
> image, purpose-built for PXE + iPXE chainload). If you prefer not to run a third-party image, install the
> distro `dnsmasq` package and supply the iPXE binaries yourself.
>
> **Note:** the only value to fill in is `<furyctl-host>` (the host/IP running furyctl). The boot server
> listens on port `8080` by default; `${mac:hexhyp}` is expanded by iPXE to each node's MAC, so one line
> serves every node.

<!-- Links -->

[dhcp]: https://datatracker.ietf.org/doc/html/rfc2131
[pxe]: https://ipxe.org/howto/chainloading
[rfc4578]: https://www.rfc-editor.org/rfc/rfc4578
[dnsmasq]: https://thekelleys.org.uk/dnsmasq/doc.html
[matchbox]: https://matchbox.psdn.io/network-setup/
[furyctl]: https://github.com/sighupio/furyctl/
[ignition]: https://coreos.github.io/ignition/
[flatcar]: https://www.flatcar.org/
