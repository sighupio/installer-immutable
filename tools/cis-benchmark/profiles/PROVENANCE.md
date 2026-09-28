# Provenance of the vendored kube-bench profiles

The files of this directory are not written by hand. `scripts/sync-profiles.sh` produces
them from the kube-bench profiles SIGHUP keeps in installer-on-premises, and
`scripts/sync-profiles.sh --check` replays the same steps and fails on any difference. The
tables between the `sync-profiles` markers are rewritten by the script: do not edit them.

## Source

<!-- sync-profiles:source:begin -->
| Field | Value |
| --- | --- |
| Repository | https://github.com/sighupio/installer-on-premises |
| Commit | `80fc521d4047aeb468eab8215b2e6cc571975bdc` |
| Path | `utils/kube-bench` |
| Synced on | 2026-09-27 |
| kube-bench version | 0.12.0 |
| Upstream `CHANGELOG.md` sha256 | `5e6db86af12722cca98edcb981ed733cf4a8d8aa4438c8bdfae15b4537ed768e` |
<!-- sync-profiles:source:end -->

The upstream `CHANGELOG.md` is not vendored. It gives the reason of every skip the
profiles declare; its sha256 shows in a re-sync when those reasons change.

## License

The profiles derive from the `cfg/` directory of
[kube-bench](https://github.com/aquasecurity/kube-bench), by Aqua Security, licensed under
the Apache License 2.0, as adapted by SIGHUP in installer-on-premises. The rest of this
repository is under its own `LICENSE`.

## Files

<!-- sync-profiles:files:begin -->
| File | Upstream sha256 | Local sha256 |
| --- | --- | --- |
| `cis-1.11/config.yaml` | `f8beefa9c5392e5c25d03e802294ad1852ac094d3bf3053903dad718f599e3b7` | `f8beefa9c5392e5c25d03e802294ad1852ac094d3bf3053903dad718f599e3b7` |
| `cis-1.11/controlplane.yaml` | `b0eed3922acd875c57eb06bfbd24ed6365108a8936c225192356fe74ec598e8f` | `b0eed3922acd875c57eb06bfbd24ed6365108a8936c225192356fe74ec598e8f` |
| `cis-1.11/etcd.yaml` | `5dfe20bb21bce5ddcfe0a55a2ce2b0ab83d2db935e77fba759dbde4c1b6f6ba3` | `874e84b0469032b3a9c6351f7798df5df526b06f7ecfb584402d09343f9e0e5d` |
| `cis-1.11/master.yaml` | `9a00bc75455710684ac01b0a9b57a9ae8730da46bd36231f0b9d84c9dbfed344` | `c02348da243041bcf9ceb945601416332ac298cab581962e5aae37e23e1fadb4` |
| `cis-1.11/node.yaml` | `ac265c9b32a7b26be72cab2b95b33861179210a94aa9aeb60131efabd2225077` | `8aefe1b9c5aaa60d0a7cec4725119740c83d7418f95f745f38c1d6b3017363fd` |
| `cis-1.12/config.yaml` | `f8beefa9c5392e5c25d03e802294ad1852ac094d3bf3053903dad718f599e3b7` | `f8beefa9c5392e5c25d03e802294ad1852ac094d3bf3053903dad718f599e3b7` |
| `cis-1.12/controlplane.yaml` | `a0a441e3b40bfc96a5acd1529a05087e401329a70d786982eda0544d0082b429` | `a0a441e3b40bfc96a5acd1529a05087e401329a70d786982eda0544d0082b429` |
| `cis-1.12/etcd.yaml` | `8d7c286edff6a68fe2dad41d790a1a4e4f298d79917100546184d4a13b19f2dd` | `995ea5dfbbc096ebee5fb9a7e6ceff733b41da6b097016bce7f357a02c1ea4a5` |
| `cis-1.12/master.yaml` | `f69396cf0cff7acfaa78189dbfcf2e95df2d0774aec3ab80446d927bff7a2b28` | `9ec89ddbd2dc98d0b7f7e251177f9c4f7e34f524a111d9a9ed99bc8e7a5989bd` |
| `cis-1.12/node.yaml` | `bb686fd58403f41501314cc406b47206c3e77cdacf42e0bcaeabbd4df39a21ad` | `2e2d661c483d4c55787f19d5408fce39495910e2e02bf783d0d5f55915777d71` |
| `config.yaml` | `94687ca794cbc4dd1cdbad6f1ad3e3c8fa5a8f59bc8f302718bcc4cac9b78325` | `94687ca794cbc4dd1cdbad6f1ad3e3c8fa5a8f59bc8f302718bcc4cac9b78325` |
<!-- sync-profiles:files:end -->

## Normalization

The local sha256 differs from the upstream one for every file the steps below rewrite:

1. Copy `config.yaml`, `cis-1.11/` and `cis-1.12/` from `utils/kube-bench` at the commit
   above.
2. Drop `cis-*/policies.yaml`. The tool never runs the `policies` target, and those are the
   only files that fail the line-length rule (220 characters) of this repository's
   yamllint. The other files have longer lines too, but the rule allows them.
3. Format with the repository's yamlfmt (`.yamlfmt`). At `80fc521` it rewrites `etcd.yaml`,
   `master.yaml` and `node.yaml` of both benchmarks by joining folded strings. The parsed
   YAML is identical before and after.
4. Apply `overlay/*.patch` in lexical order with `patch -p1`.

## Overlay

A patch changes a check only when its audit reads a path or a mechanism that does not exist
on an Immutable (Flatcar) node. A check that fails because the node is not compliant is a
finding: it is never patched and never turned into a skip.

Every patch has a section below, named after its file, with these three entries:

- **Checks:** the ids of the checks the patch changes.
- **Flatcar fact:** what differs on Flatcar and makes the upstream audit read the wrong place.
- **Evidence:** the raw JSON excerpt or the command output that shows it.

The overlay is empty: no audit of the vendored profiles is known to read a path or a
mechanism that is absent on Immutable. The end-to-end runs recorded in
[`tests/E2E.md`](../tests/E2E.md) found no `FAIL`, and the raw results show the audits
reading the files of the kubelet, the API server, etcd and the PKI where the installer
writes them. Two results are worth knowing, and neither needs a patch:

- 4.2.7 passes, because the kubelet of Immutable runs without `--hostname-override`;
- 1.1.9 and 1.1.10 warn on a control plane where `/var/lib/cni` holds no file. Their
  audit reads the `--cni-conf-dir` flag, which the kubelet no longer has, and then that
  folder: upstream behaviour, the same on any operating system.
