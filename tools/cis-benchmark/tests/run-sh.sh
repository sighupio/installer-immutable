#!/usr/bin/env bash
# Copyright (c) 2017-present SIGHUP s.r.l All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# Tests run.sh against fake furyctl folders, with a stub ansible-playbook that records
# its arguments and environment instead of running anything. No node, no network.
set -euo pipefail

run_sh="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/run.sh"
work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT
failures=0

fail() {
  echo "FAIL: $*" >&2
  failures=$((failures + 1))
}

# Makes a furyctl folder at $1 with the clusters named after it, each with an inventory
# and an ansible.cfg, and a bin/ folder that is not a cluster.
make_furyctl_dir() {
  local dir="$1" cluster
  shift
  mkdir -p "${dir}/.furyctl/bin"
  for cluster in "$@"; do
    mkdir -p "${dir}/.furyctl/${cluster}/kubernetes"
    touch "${dir}/.furyctl/${cluster}/kubernetes/hosts.yaml" "${dir}/.furyctl/${cluster}/kubernetes/ansible.cfg"
  done
}

# Installs in the furyctl folder $1 a stub ansible-playbook for the ansible version $2.
# The stub writes to record/ of its folder: its arguments, one per line, and the
# ANSIBLE_* variables it sees.
add_ansible() {
  local bin="$1/.furyctl/bin/ansible/$2/venv/bin"
  mkdir -p "${bin}"
  cat >"${bin}/ansible-playbook" <<'STUB'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then
  echo "ansible-playbook [core stub]"
  exit 0
fi
record="$(dirname "$0")/record"
mkdir -p "${record}"
printf '%s\n' "$@" >"${record}/args"
env | grep '^ANSIBLE_' | sort >"${record}/env" || true
pwd >"${record}/pwd"
STUB
  chmod +x "${bin}/ansible-playbook"
}

# Runs run.sh with the arguments given, and sets status and output.
run() {
  status=0
  output="$("${run_sh}" "$@" 2>&1)" || status=$?
}

expect_status() {
  [[ "${status}" -eq "$1" ]] || fail "$2: exit status ${status}, expected $1. Output: ${output}"
}

expect_output() {
  [[ "${output}" == *"$1"* ]] || fail "$2: the output does not contain '$1'. Output: ${output}"
}

# The JSON value of key $2 in the extra vars that the stub in folder $1 received.
extra_var() {
  local args="$1/record/args"
  python3 -c '
import json, sys
lines = open(sys.argv[1]).read().splitlines()
print(json.loads(lines[lines.index("-e") + 1])[sys.argv[2]])' "${args}" "$2"
}

# One cluster, found without naming it; the newest shipped ansible-playbook is used.
dir="${work}/one"
make_furyctl_dir "${dir}" demo
add_ansible "${dir}" 2.9.0
add_ansible "${dir}" 2.10.0
run "${dir}"
expect_status 0 "a single cluster"
expect_output "Cluster: demo" "a single cluster"
stub="${dir}/.furyctl/bin/ansible/2.10.0/venv/bin"
[[ -f "${stub}/record/args" ]] || fail "the newest ansible-playbook (2.10.0) was not the one run"
[[ ! -e "${dir}/.furyctl/bin/ansible/2.9.0/venv/bin/record" ]] || fail "an older ansible-playbook (2.9.0) was run"
output_dir="$(extra_var "${stub}" cis_output_dir)"
[[ "${output_dir}" =~ ^${dir}/\.furyctl/demo/cis-benchmark/[0-9]{8}T[0-9]{6}Z$ ]] \
  || fail "the output folder is ${output_dir}"
expect_output "Reports: ${output_dir}" "a single cluster"
run_date="$(extra_var "${stub}" cis_date)"
[[ "${output_dir##*/}" == "$(tr -d ':-' <<<"${run_date}")" ]] \
  || fail "the folder ${output_dir##*/} and the date ${run_date} come from different clocks"
[[ "$(cat "${stub}/record/pwd")" == "${dir}/.furyctl/demo/kubernetes" ]] \
  || fail "ansible-playbook did not run from the kubernetes folder"

# A path with spaces and a key=value word reaches the playbook whole, and sets nothing.
dir="${work}/with space x=1/cis_fail_on_fail=false"
make_furyctl_dir "${dir}" demo
add_ansible "${dir}" 2.21.0
run "${dir}"
expect_status 0 "a path with spaces"
stub="${dir}/.furyctl/bin/ansible/2.21.0/venv/bin"
output_dir="$(extra_var "${stub}" cis_output_dir)"
[[ "${output_dir}" == "${dir}/.furyctl/demo/cis-benchmark/"* ]] \
  || fail "a path with spaces became ${output_dir}"

# A relative path, the arguments after --, and ANSIBLE_* and CDPATH from the shell.
dir="${work}/relative"
make_furyctl_dir "${dir}" demo
add_ansible "${dir}" 2.21.0
stub="${dir}/.furyctl/bin/ansible/2.21.0/venv/bin"
status=0
output="$(cd "${work}" && CDPATH="${work}" ANSIBLE_CONFIG=/nowhere ANSIBLE_INVENTORY=/nowhere \
  "${run_sh}" relative -- -e cis_keep_on_node=true 2>&1)" || status=$?
expect_status 0 "a relative path"
[[ "$(extra_var "${stub}" cis_output_dir)" == "${dir}/.furyctl/demo/cis-benchmark/"* ]] \
  || fail "a relative path was not resolved from the working directory"
[[ "$(cat "${stub}/record/env")" == "ANSIBLE_CONFIG=${dir}/.furyctl/demo/kubernetes/ansible.cfg" ]] \
  || fail "the ANSIBLE_* variables of the shell reached ansible-playbook: $(cat "${stub}/record/env")"
[[ "$(tail -n 2 "${stub}/record/args" | paste -sd ' ')" == "-e cis_keep_on_node=true" ]] \
  || fail "the arguments after -- were not passed last"

# Several clusters: one must be named, and a wrong name lists the ones found.
dir="${work}/several"
make_furyctl_dir "${dir}" alpha beta
add_ansible "${dir}" 2.21.0
run "${dir}"
expect_status 1 "several clusters"
expect_output "several clusters in ${dir}/.furyctl, name one of: alpha beta" "several clusters"
run "${dir}" beta
expect_status 0 "a named cluster"
expect_output "Cluster: beta" "a named cluster"
run "${dir}" gamma
expect_status 1 "an unknown cluster"
expect_output "Clusters found: alpha beta" "an unknown cluster"

# Folders that are not a furyctl folder, and wrong arguments.
mkdir -p "${work}/empty/.furyctl/bin" "${work}/plain"
run "${work}/empty"
expect_status 1 "no cluster"
expect_output "no folder of ${work}/empty/.furyctl holds kubernetes/hosts.yaml" "no cluster"
run "${work}/plain"
expect_status 1 "no .furyctl"
expect_output "it is not a furyctl folder" "no .furyctl"
run "${work}/missing"
expect_status 1 "a missing folder"
run "${work}/one" --limit cp1
expect_status 1 "an ansible-playbook option before --"
expect_output "the options of ansible-playbook go after --" "an ansible-playbook option before --"
run
expect_status 2 "no argument"
run -h
expect_status 0 "-h"
expect_output "Usage: run.sh" "-h"

if [[ "${failures}" -gt 0 ]]; then
  echo "run.sh: ${failures} failure(s)" >&2
  exit 1
fi
echo "run.sh: all cases pass"
