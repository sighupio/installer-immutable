#!/usr/bin/env bash
# Copyright (c) 2017-present SIGHUP s.r.l All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# Bump one system extension in immutable.yaml, with the checksums from the SHA256SUMS of its
# installer-immutable-sysext release. Needs curl and yq.
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: bump-sysext.sh [-n release-notes.md] <name> <version> <kubernetes-version>...

Sets <name> to <version> for each <kubernetes-version> in immutable.yaml. The URLs and the
sha256 checksums come from the installer-immutable-sysext release "<name>-<version>".
With -n, also updates the package tables of the release notes for these Kubernetes versions.

  bump-sysext.sh etcd v3.6.15 1.35.8 1.36.4
  bump-sysext.sh -n docs/releases/v1.36.4.md containerd 2.3.6 1.35.8 1.36.4
USAGE
}

notes=""
if [[ "${1:-}" == "-n" ]]; then
  notes="$2"
  shift 2
fi
[[ $# -ge 3 ]] || { usage >&2; exit 1; }

name="$1" version="$2"
shift 2

root="$(cd "$(dirname "$0")/.." && pwd)"
file="$root/immutable.yaml"
base="https://github.com/sighupio/installer-immutable-sysext/releases/download/${name}-${version}"

sums="$(curl -fsSL "$base/SHA256SUMS")"
sha() { awk -v f="${name}-${version}-$1.raw" '$2 == f { print $1 }' <<<"$sums"; }
sha_x86="$(sha x86-64)" sha_arm="$(sha arm64)"
[[ -n "$sha_x86" && -n "$sha_arm" ]] || { echo "SHA256SUMS of ${name}-${version} has no .raw for both arches" >&2; exit 1; }

for k8s in "$@"; do
  count="$(K="$k8s" N="$name" yq '[.kubernetes[strenv(K)].sysext[] | select(.name == strenv(N))] | length' "$file")"
  [[ "$count" == 1 ]] || { echo "Kubernetes $k8s has no sysext '$name' in immutable.yaml" >&2; exit 1; }

  K="$k8s" N="$name" V="$version" B="$base" X="$sha_x86" A="$sha_arm" yq -i '
    (.kubernetes[strenv(K)].sysext[] | select(.name == strenv(N))) |= (
      .version = strenv(V) |
      .arch."x86-64".url = strenv(B) + "/" + strenv(N) + "-" + strenv(V) + "-x86-64.raw" |
      .arch."x86-64".sha256 = strenv(X) |
      .arch.arm64.url = strenv(B) + "/" + strenv(N) + "-" + strenv(V) + "-arm64.raw" |
      .arch.arm64.sha256 = strenv(A)
    )' "$file"
  echo "Kubernetes $k8s: $name $version"

  if [[ -n "$notes" ]]; then
    # Replace the version cell of the "[name](...)" row in the "### Kubernetes v<k8s>" table,
    # and keep the cell width.
    tmp="$(mktemp)"
    awk -v sec="### Kubernetes v$k8s" -v row="| [$name](" -v new="\`${version#v}\`" '
      /^### / { in_sec = ($0 == sec) }
      in_sec && index($0, row) == 1 {
        n = split($0, c, "|")
        w = length(c[3])
        c[3] = sprintf(" %-" (w > length(new) + 2 ? w - 2 : length(new)) "s ", new)
        line = c[1]
        for (i = 2; i <= n; i++) line = line "|" c[i]
        $0 = line
      }
      { print }' "$notes" >"$tmp"
    cat "$tmp" >"$notes"
    rm -f "$tmp"
  fi
done
