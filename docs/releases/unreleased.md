# SD Immutable Installer vTBD

Welcome to the release of version TBD of the Immutable installer for the [`SIGHUP Distribution`](https://github.com/sighupio/distribution) maintained by SIGHUP by ReeVo team.

## Package Versions 🚢

TBD

## Breaking Changes 💔

TBD

## Bug Fixes 🐛

- [[#45](https://github.com/sighupio/installer-immutable/pull/45)] keepalived: the control-plane virtual IP address now moves to another node when the Kubernetes API server stops. Before this release, the API health check did not run on Flatcar 4757.2.1 or later, because `/etc` does not let programs run from it.

## New features 🌟

- [[#50](https://github.com/sighupio/installer-immutable/pull/50)] containerd: the containerd configuration now imports each `/etc/containerd/conf.d/*.toml` file. To add containerd settings to a node, for example a runtime, write a drop-in in this directory with the `storage.files` of the node. During an upgrade, the new configuration takes effect when the node reboots.
