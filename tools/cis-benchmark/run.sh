#!/usr/bin/env bash
# Copyright (c) 2017-present SIGHUP s.r.l All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# Runs cis-benchmark.yml with what furyctl already rendered in a cluster folder: the
# inventory, the ansible.cfg and, when it is there, furyctl's own ansible-playbook.
set -euo pipefail

# An exported CDPATH would make cd print the directory it changes to, and pollute $(cd …).
unset CDPATH

tool_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'USAGE'
Usage: run.sh [-h] <furyctl-dir> [cluster-name] [-- <ansible-playbook args>]

Runs the CIS Kubernetes Benchmark (kube-bench) on the nodes of a cluster installed by
furyctl and writes the reports to
<furyctl-dir>/.furyctl/<cluster-name>/cis-benchmark/<UTC timestamp>/.

  furyctl-dir   the directory that holds .furyctl/
  cluster-name  the folder of the cluster under .furyctl/. It can be omitted when only
                one folder there holds kubernetes/hosts.yaml
  --            what follows is passed to ansible-playbook
  -h, --help    show this help

  run.sh ~/clusters/demo
  run.sh ~/clusters/demo demo -- -e cis_fail_on_fail=false
  run.sh ~/clusters/demo -- -e cis_keep_on_node=true
USAGE
}

die() {
  echo "run.sh: $*" >&2
  exit 1
}

# Sets positional to the arguments before --, and passthrough to the ones after it.
parse_arguments() {
  positional=()
  passthrough=()
  while [[ $# -gt 0 ]]; do
    if [[ "$1" == "--" ]]; then
      shift
      passthrough=("$@")
      break
    elif [[ "$1" == "-h" || "$1" == "--help" ]]; then
      usage
      exit 0
    elif [[ "$1" == -* ]]; then
      usage >&2
      die "unknown option $1: the options of ansible-playbook go after --"
    fi
    positional+=("$1")
    shift
  done
  if [[ ${#positional[@]} -lt 1 || ${#positional[@]} -gt 2 ]]; then
    usage >&2
    exit 2
  fi
}

# Sets cluster to the folder the arguments name, or to the only one of state_dir that is
# a cluster.
choose_cluster() {
  local inventory
  local -a candidates=()

  # bin/ and any other folder without an inventory is not a cluster.
  for inventory in "${state_dir}"/*/kubernetes/hosts.yaml; do
    if [[ -f "${inventory}" ]]; then
      candidates+=("$(basename "$(dirname "$(dirname "${inventory}")")")")
    fi
  done

  if [[ ${#positional[@]} -eq 2 ]]; then
    cluster="${positional[1]}"
    if [[ ! -f "${state_dir}/${cluster}/kubernetes/hosts.yaml" ]]; then
      die "${state_dir}/${cluster}/kubernetes/hosts.yaml does not exist. Clusters found: ${candidates[*]:-none}"
    fi
  elif [[ ${#candidates[@]} -eq 1 ]]; then
    cluster="${candidates[0]}"
  elif [[ ${#candidates[@]} -eq 0 ]]; then
    die "no folder of ${state_dir} holds kubernetes/hosts.yaml"
  else
    die "several clusters in ${state_dir}, name one of: ${candidates[*]}"
  fi
}

# Sets ansible_playbook to the newest one furyctl shipped, else to the one on PATH. The
# newest is the one of the latest furyctl apply: furyctl keeps every version it installed.
find_ansible_playbook() {
  local shipped
  ansible_playbook=""
  # furyctl makes venv a symbolic link into its mise data: a glob follows it, find does not.
  while IFS= read -r shipped; do
    if [[ -f "${shipped}" && -x "${shipped}" ]]; then
      ansible_playbook="${shipped}"
    fi
  done < <(printf '%s\n' "${state_dir}"/bin/ansible/*/venv/bin/ansible-playbook | sort -V)
  if [[ -z "${ansible_playbook}" ]]; then
    ansible_playbook="$(command -v ansible-playbook || true)"
  fi
  [[ -n "${ansible_playbook}" ]] || die "no ansible-playbook in ${state_dir}/bin/ansible nor on PATH"
}

# Prints its argument as a JSON string.
json_string() {
  local value="$1" escaped="" character code
  local -i index
  for ((index = 0; index < ${#value}; index++)); do
    character="${value:index:1}"
    case "${character}" in
      '"' | \\) escaped+="\\${character}" ;;
      *)
        printf -v code '%d' "'${character}"
        if ((code < 32)); then
          printf -v character '\\u%04x' "${code}"
        fi
        escaped+="${character}"
        ;;
    esac
  done
  printf '"%s"' "${escaped}"
}

parse_arguments "$@"

[[ -d "${positional[0]}" ]] || die "${positional[0]} is not a directory"
furyctl_dir="$(cd "${positional[0]}" && pwd)"
state_dir="${furyctl_dir}/.furyctl"
[[ -d "${state_dir}" ]] || die "${furyctl_dir} holds no .furyctl directory: it is not a furyctl folder"

choose_cluster
cluster_dir="${state_dir}/${cluster}"
kubernetes_dir="${cluster_dir}/kubernetes"
[[ -f "${kubernetes_dir}/ansible.cfg" ]] || die "${kubernetes_dir}/ansible.cfg does not exist"

find_ansible_playbook

# An ANSIBLE_* setting inherited from the shell overrides the configuration furyctl
# rendered: ANSIBLE_CONFIG replaces it, ANSIBLE_COLLECTIONS_PATH can shadow ansible.builtin.
while IFS= read -r variable; do
  unset "${variable}"
done < <(compgen -e | grep '^ANSIBLE_' || true)
export ANSIBLE_CONFIG="${kubernetes_dir}/ansible.cfg"

# One clock for the name of the output folder and the date in the reports.
read -r stamp run_date < <(date -u '+%Y%m%dT%H%M%SZ %Y-%m-%dT%H:%M:%SZ')
output_dir="${cluster_dir}/cis-benchmark/${stamp}"
[[ ! -e "${output_dir}" ]] || die "${output_dir} already exists: a run started in the same second"

# The working directory of furyctl, so that the relative paths of the rendered files
# resolve as they do for furyctl.
cd "${kubernetes_dir}"

# The extra vars go as JSON: a key=value string is split on whitespace, so a path with a
# space would be cut and the rest read as more variables.
command=(
  "${ansible_playbook}"
  -i "${kubernetes_dir}/hosts.yaml"
  "${tool_dir}/cis-benchmark.yml"
  -e "{\"cis_output_dir\": $(json_string "${output_dir}"), \"cis_date\": \"${run_date}\"}"
  ${passthrough[@]+"${passthrough[@]}"}
)

echo "Cluster: ${cluster}"
echo "Ansible: ${ansible_playbook} ($("${ansible_playbook}" --version | head -n 1))"
echo "Reports: ${output_dir}"
echo "Running: ANSIBLE_CONFIG=${ANSIBLE_CONFIG} ${command[*]}"
exec "${command[@]}"
