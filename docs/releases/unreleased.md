# SD Immutable Installer vTBD

Welcome to the release of version TBD of the Immutable installer for the [`SIGHUP Distribution`](https://github.com/sighupio/distribution) maintained by SIGHUP by ReeVo team.

## Package Versions 🚢

TBD

## Breaking Changes 💔

- The `os-upgrade` role needs the new variable `os_update_payload_pins`, which furyctl makes from the `flatcar.arch.<arch>.update` entries of `immutable.yaml`. Use a furyctl version that gives this variable. An older furyctl stops at the argument check of the role, before it changes a node.
- The `os-upgrade` role no longer has the variables `os_update_server`, `os_update_group`, `os_update_reboot_strategy`, `os_update_conf_path`, `os_update_marker_path`, `os_update_stage_async_timeout` and `os_update_stage_async_retries`. If you set them, the role ignores them.

## Bug Fixes 🐛

- [[#32](https://github.com/sighupio/installer-immutable/pull/32)] The download of the system extensions during an upgrade now uses the proxy of `spec.infrastructure.proxy`. An Ansible task runs in a non-login shell, so it got no proxy variable. Thus the upgrade failed on a node that reaches the Internet only through a proxy. The reachability check of the preflight uses the proxy too.
- The OS upgrade now installs the exact Flatcar version of `immutable.yaml`. Before, update-engine got the version of the `stable` channel of the update server (Nebraska), which can be different from the pinned version. Then the upgrade stopped after the drain, with the wrong version staged. Now the `os-upgrade` role downloads the update payload of the pinned version from `update.release.sighup-prod.sighup.io`, compares its SHA-256 checksum with `immutable.yaml`, and stages it with `flatcar-update`. The role contacts no update server, and `/etc/flatcar/update.conf` gets `SERVER=disabled`.
- The installer no longer masks update-engine, as the Flatcar documentation recommends. `SERVER=disabled` in `/etc/flatcar/update.conf` makes every update check fail, so the node gets no automatic OS update. The upgrade writes this line and unmasks update-engine on each node that it stages.
- The OS stage now completes before the drain of the node. A missing payload, a bad checksum or a bad signature stops the upgrade while the node still serves.
- The free space on `/` that the upgrade preflight needs is now 2 GiB, because the role downloads the update payload (400 to 550 MB) to `/var/tmp`.
- The downloads of the system extensions and of the OS update payload now retry. Before, one failed connection stopped the install or the upgrade at once, and an upgrade could stop with a node already cordoned. Now a download that fails with a connection error or a timeout is tried again 5 times, with 10 seconds between the attempts. When it keeps failing, the log shows a `FAILED - RETRYING` line for each attempt, and the task fails after about 50 seconds with the same error message as before. A download with a checksum that does not match fails at once, as before.
- [[#38](https://github.com/sighupio/installer-immutable/pull/38)] After the uncordon of a node, the upgrade now waits until the pods of the node are Ready. Before, it continued when the pods were only Running. Then the next phase could replace the Cilium pod of the last rebooted node before it was Ready. This triggers a Cilium bug ([cilium/cilium#44891](https://github.com/cilium/cilium/issues/44891)): `hubble-relay` stays not Ready on that node until the node reboots, and `furyctl apply` waits on it. A pod that never becomes Ready now stops the upgrade when the wait times out. `--force pods-running-check` still skips the wait.
- A node that a failed upgrade left cordoned is now uncordoned by the next run. Before, when an upgrade failed after the drain of a node, for example after its reboot, the node was already at its target versions. Then the next run decided that the node needed no drain, skipped the uncordon too, and ended with success while the node was still `SchedulingDisabled`. Now the `node-maintenance` role sets the annotation `installer-immutable.sighup.io/drained-by-upgrade` on the node before the drain and removes it after the uncordon. A node that still has the annotation is drained again, which returns at once, and uncordoned. A node that you cordoned yourself has no annotation and stays cordoned, as before. A node left cordoned by a failed upgrade of an older installer version has no annotation either: run `kubectl uncordon <node>` for it once.

## New features 🌟

TBD
