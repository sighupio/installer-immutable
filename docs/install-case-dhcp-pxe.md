<!-- markdownlint-disable MD013 -->
# Install case: existing DHCP with PXE flags

> Part of the [Immutable install guide](IMMUTABLE_INSTALL.md). Key terms link to their official docs inline.

## When to use this case

Use this case when the network **already has a [DHCP][dhcp] server and you can modify its configuration**. It
is the most automated path: the node boots over the network and [`furyctl`][furyctl] does the rest. The target
node can be **bare metal or a virtual machine** — for a VM, this is a guest on a virtual network whose DHCP you
control (for example a libvirt network or a cloud subnet with custom DHCP options).

## Flow

![Case 1 flow — existing DHCP with PXE flags](immutable-case-dhcp-pxe.png)

> [Diagram source](immutable-case-dhcp-pxe.puml) · continues into the
> [Shared flow (every case)](IMMUTABLE_INSTALL.md#shared-flow-every-case).

## How to set it up

You only need to add PXE/iPXE boot options to your **existing** [DHCP][dhcp] server. The logic is the same on every
DHCP server, but **the exact directives and syntax depend on which DHCP server you run** — translate the three rules
below into your server's configuration language. furyctl serves only the per-MAC iPXE/[Ignition][ignition] script and
assets; it **does not run DHCP or TFTP**, so the DHCP + TFTP side is entirely your environment.

There are **three things** to configure:

1. **Serve the iPXE bootloader to plain PXE clients over [TFTP][tftp].** For a UEFI fleet (the modern default —
   bare metal and every hypervisor) hand **every** client `ipxe.efi`: one binary, no arch matching. You
   build/obtain it from [iPXE][ipxe] ([download][ipxe-download]) and host it on your TFTP server. Only a
   **mixed BIOS+UEFI** fleet needs to branch on DHCP [option 93 (client architecture, RFC 4578)][rfc4578]
   (`0x0000` = BIOS → `undionly.kpxe`, `0x0007` = x86-64 UEFI → `ipxe.efi`), because BIOS firmware cannot run
   `ipxe.efi`.
2. **Detect the iPXE user-class and chainload to furyctl.** Once iPXE is running it re-requests DHCP carrying
   user-class (option 77) `"iPXE"`; match that and return the **furyctl per-MAC boot URL** instead of the binary again.
   This breaks the chainload loop — see the [iPXE DHCP howto][ipxe-dhcpd] and [chainloading howto][ipxe-chainload].
3. **Point TFTP at where the iPXE binaries live** (the `next-server` / option 66 TFTP-server-name).

The settings to translate into your DHCP server (shown as commented flags — adapt names/syntax to your product):

```text
# (1) serve the iPXE binary to plain PXE clients over TFTP (UEFI fleet = one binary)
#   default boot file -> "ipxe.efi"
#   (mixed BIOS+UEFI only: branch on option 93 — 0x0000 -> "undionly.kpxe", 0x0007 -> "ipxe.efi")
#
# (2) detect already-running iPXE and chainload to furyctl's per-MAC boot URL
#   DHCP user-class (option 77) == "iPXE"
#     -> boot file = http://<furyctl-host>:8080/boot/${mac:hexhyp}
#        (only <furyctl-host> is yours to fill in; the path, port and ${mac:hexhyp}
#         scheme are fixed by furyctl — see the Note)
#
# (3) TFTP server that hosts ipxe.efi (and undionly.kpxe only if you support BIOS)
#   next-server / option 66 -> <your-TFTP-server-IP>
```

For reference only, here is the same logic as **illustrative [ISC `dhcpd`][isc-dhcpd] syntax** — do **not** copy it
verbatim unless you actually run ISC dhcpd, and note that **ISC dhcpd is [end-of-life since October 2022][isc-eol]**;
new deployments should use a maintained server such as [Kea][kea], [dnsmasq][dnsmasq], or a router/appliance:

```conf
# ILLUSTRATIVE ISC dhcpd syntax — add inside your existing subnet block (UEFI fleet)
if exists user-class and option user-class = "iPXE" {
    # Chainload to furyctl's built-in boot server (per-MAC). Replace only <furyctl-host>.
    filename "http://<furyctl-host>:8080/boot/${mac:hexhyp}";
} else {
    filename "ipxe.efi";          # plain PXE client → iPXE bootloader (UEFI)
}
next-server 192.0.2.10;           # your TFTP server hosting ipxe.efi

# Mixed BIOS+UEFI fleet only — define option 93 and branch by arch instead of the single else:
#   option arch code 93 = unsigned integer 16;
#   ... } elsif option arch = 00:07 { filename "ipxe.efi"; } else { filename "undionly.kpxe"; }
```

**Where to look up the exact syntax for your DHCP server:**

- [ISC `dhcpd`][isc-dhcpd] (legacy/EOL): `filename` + `next-server` + `if exists user-class` conditionals.
- [Kea][kea] (ISC's maintained successor): JSON config — `next-server`, `boot-file-name`, `tftp-server-name`,
  plus client classes matching option 93 / the iPXE user-class.
- [dnsmasq][dnsmasq]: `dhcp-match` / `dhcp-userclass` tags + `dhcp-boot=tag:...` per architecture and for iPXE.
- [MikroTik RouterOS][mikrotik]: `next-server` / `boot-file-name` on `/ip dhcp-server network`.
- [Windows Server DHCP][windows-dhcp]: scope options 066 (TFTP server) / 067 (bootfile), arch/iPXE logic via WDS/policies.
- [pfSense / OPNsense][pfsense]: Network Booting UI with separate BIOS / UEFI / HTTPBoot filenames (OPNsense uses Kea/dnsmasq).

Then:

1. Apply the three rules above to your DHCP server and reload it. Make the iPXE bootloader `ipxe.efi` (add
   `undionly.kpxe` only if you support legacy BIOS) available over TFTP at your `next-server`.
2. Set each node's firmware to **network boot** (bare metal: enable PXE in BIOS/UEFI; VM: put the virtual NIC
   first in the boot order).
3. Start furyctl so its iPXE/[Ignition][ignition] boot server is serving per-MAC configs — see
   [Installing with furyctl](IMMUTABLE_INSTALL.md#installing-with-furyctl) (`furyctl apply --phase infrastructure`).
4. Power on the nodes. They net-boot, chainload to furyctl, pull their config, boot [Flatcar][flatcar], and
   continue through the shared flow.

> **Note:** in the chainload URL `http://<furyctl-host>:8080/boot/${mac:hexhyp}`, the only value you supply is
> `<furyctl-host>` (the host/IP running furyctl). The `/boot/${mac:hexhyp}` path scheme and the default port `8080`
> are **fixed by furyctl** — change the port only if you set `spec.infrastructure.ipxeServer.bindPort`. You do **not**
> need to worry about MAC letter-case: iPXE emits `${mac:hexhyp}` lowercase (e.g. `52-54-00-10-00-01`) and furyctl
> normalizes it server-side. furyctl serves only the per-MAC script — it does **not** serve the `undionly.kpxe` /
> `ipxe.efi` binaries; those are yours to host on TFTP.

<!-- Links -->

[dhcp]: https://datatracker.ietf.org/doc/html/rfc2131
[ipxe]: https://ipxe.org/
[furyctl]: https://github.com/sighupio/furyctl/
[ignition]: https://coreos.github.io/ignition/
[flatcar]: https://www.flatcar.org/
[tftp]: https://datatracker.ietf.org/doc/html/rfc1350
[rfc4578]: https://www.rfc-editor.org/rfc/rfc4578
[ipxe-dhcpd]: https://ipxe.org/howto/dhcpd
[ipxe-chainload]: https://ipxe.org/howto/chainloading
[ipxe-download]: https://ipxe.org/download
[isc-dhcpd]: https://man.archlinux.org/man/dhcpd.conf.5.en
[isc-eol]: https://www.isc.org/blogs/isc-dhcp-eol/
[kea]: https://kea.readthedocs.io/en/latest/arm/dhcp4-srv.html
[dnsmasq]: https://thekelleys.org.uk/dnsmasq/docs/dnsmasq-man.html
[mikrotik]: https://help.mikrotik.com/docs/spaces/ROS/pages/24805500/DHCP
[windows-dhcp]: https://learn.microsoft.com/en-us/troubleshoot/windows-server/networking/pxe-clients-not-start-dhcp-60-66-67-option
[pfsense]: https://docs.netgate.com/pfsense/en/latest/services/dhcp/ipv4.html
