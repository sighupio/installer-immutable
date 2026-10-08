#!/usr/bin/env bash
# Copyright (c) 2017-present SIGHUP s.r.l All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# Stub kubectl for the node-maintenance test: one node, whose state is the file
# $KUBECTL_STUB_DIR/node. Every call is appended to $KUBECTL_STUB_DIR/calls.log, one line of
# arguments per call. It answers the calls of the role, and the read of the cordon that a mistaken
# preflight makes, and fails on any other.
#
# Lines of the state file:
#   kubeletVersion=<version>       answer to the kubelet-version read
#   unschedulable=<true|false>     set by drain, cleared by uncordon
#   annotation <key>=<value>       one line per annotation of the node
#   podsNotReady=<n>               pods that the pod read reports as not Ready
#   fail=<command>                 "annotate", "get", ...: that command exits 1 and changes nothing
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: KUBECTL_STUB_DIR=<directory> kubectl-stub.sh <kubectl arguments>

  kubectl-stub.sh get node <name> -o jsonpath=<path>
  kubectl-stub.sh get pods -A --field-selector <selector> -o custom-columns=<columns>
  kubectl-stub.sh annotate node <name> <key>=<value> [--overwrite]
  kubectl-stub.sh annotate node <name> <key>-
  kubectl-stub.sh drain <name>
  kubectl-stub.sh uncordon <name>
USAGE
}

if [[ $# -eq 0 || "$1" == "-h" || "$1" == "--help" ]]; then
  usage
  exit 0
fi

state="${KUBECTL_STUB_DIR:?set KUBECTL_STUB_DIR to the directory of the node state}/node"
printf '%s\n' "$*" >>"$KUBECTL_STUB_DIR/calls.log"

# Both match $1 as plain text at the start of a line: the key of an annotation has dots and a slash.
state_get() {
  awk -v prefix="$1=" 'index($0, prefix) == 1 { print substr($0, length(prefix) + 1) }' "$state"
}

# Replace the line that starts with $1 by $1$2; with no $2 the line is only removed.
state_put() {
  local kept
  kept="$(awk -v prefix="$1" 'index($0, prefix) != 1' "$state")"
  {
    [[ -z "$kept" ]] || printf '%s\n' "$kept"
    [[ $# -lt 2 ]] || printf '%s%s\n' "$1" "$2"
  } >"$state"
}

unsupported() {
  echo "kubectl-stub: unsupported call: $*" >&2
  exit 64
}

args=()
output=""
overwrite=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o)
      output="$2"
      shift
      ;;
    --kubeconfig | --field-selector) shift ;;
    --overwrite) overwrite=true ;;
    -*) ;;
    *) args+=("$1") ;;
  esac
  shift
done

if [[ "$(state_get fail)" == "${args[0]}" ]]; then
  echo "kubectl-stub: ${args[0]} fails, as the state file asks" >&2
  exit 1
fi

case "${args[*]:0:2}" in
  "get node")
    path="${output#jsonpath=\{}"
    path="${path%\}}"
    case "$path" in
      .status.nodeInfo.kubeletVersion) state_get kubeletVersion ;;
      # The role does not read this field. A preflight that decides by the cordon, the mistake that
      # the case hand-cordoned guards against, does, and it must get the answer of kubectl:
      # nothing for a schedulable node, where the field is absent.
      .spec.unschedulable) [[ "$(state_get unschedulable)" != true ]] || printf 'true' ;;
      .metadata.annotations.*)
        key="${path#.metadata.annotations.}"
        # kubectl splits the path on every dot that is not escaped, so a key with a bare dot
        # names a nested field that no annotation has, and the answer is empty.
        bare="${key//\\./}"
        [[ "$bare" != *.* ]] || exit 0
        state_get "annotation ${key//\\./.}"
        ;;
      *) unsupported "${args[@]}" "$output" ;;
    esac
    ;;
  "get pods")
    echo READY
    for ((i = 0; i < $(state_get podsNotReady); i++)); do
      echo False
    done
    ;;
  "annotate node")
    change="${args[3]}"
    if [[ "$change" == *- ]]; then
      # Like kubectl, removing an annotation that is not there is not an error.
      state_put "annotation ${change%-}="
    else
      key="${change%%=*}"
      if [[ "$overwrite" != true && -n "$(state_get "annotation $key")" ]]; then
        echo "error: --overwrite is false but found the following declared annotation(s): '$key' already has a value" >&2
        exit 1
      fi
      state_put "annotation $key=" "${change#*=}"
    fi
    ;;
  drain\ *) state_put "unschedulable=" true ;;
  uncordon\ *) state_put "unschedulable=" false ;;
  *) unsupported "${args[@]}" ;;
esac
