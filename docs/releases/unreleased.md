# SD Immutable Installer vTBD

Welcome to the release of version TBD of the Immutable installer for the [`SIGHUP Distribution`](https://github.com/sighupio/distribution) maintained by SIGHUP by ReeVo team.

## Package Versions 🚢

TBD

## Breaking Changes 💔

None

## Bug Fixes 🐛

- [[#32](https://github.com/sighupio/installer-immutable/pull/32)] The download of the system extensions during an upgrade now uses the proxy of `spec.infrastructure.proxy`. An ansible task runs in a non-login shell, so it got no proxy variable, and a node that reaches the Internet only through a proxy could not upgrade. The reachability check of the preflight uses the proxy too.

## New features 🌟

- [[#30](https://github.com/sighupio/installer-immutable/pull/30)] Add `tools/cis-benchmark`, which runs the CIS Kubernetes Benchmark on every node of an installed cluster with the kube-bench version (0.12.0) and the profiles of the on-premises installer, and writes a Markdown report per node and a summary of what passed, failed and warned. It is a tool to run on demand, not a step of the installation, and it leaves nothing on the nodes. See its [README](../../tools/cis-benchmark/README.md).
