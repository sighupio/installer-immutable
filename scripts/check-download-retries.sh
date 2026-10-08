#!/usr/bin/env bash
# Copyright (c) 2017-present SIGHUP s.r.l All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# Report every get_url task without both "until" and "retries": one refused connection would
# fail the play, and an upgrade then stops with a node already cordoned. Needs yq.
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: check-download-retries.sh <file-or-directory>...

Reads the YAML task files given (a directory is searched for *.yml and *.yaml) and prints
"<file>: <task name>" for each get_url task that has no "until" or no "retries", at any depth
of block, rescue and always. Exits 1 when it prints at least one task.

  check-download-retries.sh roles
  check-download-retries.sh tests/download-retries/fixtures/pass.yml
USAGE
}

[[ $# -ge 1 ]] || { usage >&2; exit 1; }
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  usage
  exit 0
fi

files=()
for target in "$@"; do
  if [[ -d "$target" ]]; then
    while IFS= read -r file; do
      files+=("$file")
    done < <(find "$target" -type f \( -name '*.yml' -o -name '*.yaml' \) | LC_ALL=C sort)
  elif [[ -f "$target" ]]; then
    files+=("$target")
  else
    echo "$target: no such file or directory" >&2
    exit 1
  fi
done
[[ ${#files[@]} -gt 0 ]] || { echo "no YAML file in: $*" >&2; exit 1; }

# A task is a mapping reached only through list items and block / rescue / always keys. The
# path test keeps out a mapping that merely has a key named get_url, such as the "vars" of a task.
downloads='
  .. | select(tag == "!!map") |
  select(has("ansible.builtin.get_url") or has("ansible.legacy.get_url") or has("get_url")) |
  select([path | .[] | select(tag == "!!str")] - ["block", "rescue", "always"] | length == 0)'

missing="$(yq -N "$downloads"' |
  select((has("until") and has("retries")) | not) |
  filename + ": " + (.name // "(task without a name)")' "${files[@]}")"
if [[ -n "$missing" ]]; then
  echo "$missing"
  echo "get_url tasks without until and retries: $(wc -l <<<"$missing")" >&2
  exit 1
fi

count="$(yq -N "[$downloads] | length" "${files[@]}" | awk '{ sum += $1 } END { print sum + 0 }')"
echo "get_url tasks with until and retries: $count (${#files[@]} files read)"
