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

## New features 🌟

TBD
