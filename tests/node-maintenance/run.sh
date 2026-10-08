#!/usr/bin/env bash
# Copyright (c) 2017-present SIGHUP s.r.l All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# Run preflight.yml, drain.yml and uncordon.yml of the node-maintenance role on localhost against
# kubectl-stub.sh, one case after the other, and check the state of the node and the calls of each
# case. Prints "<case>: ok" or "<case>: FAILED" per case and exits 1 when a case failed. Needs
# ansible-playbook; reaches no cluster and writes only under a temporary directory.
# shellcheck disable=SC2317,SC2329  # the case_* functions are called by name, from the list of cases
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: run.sh [-v] [<case>...]

Runs the cases of the node-maintenance test (all of them when none is named) and prints one
line per case: "<case>: ok" or "<case>: FAILED", followed by the check that failed.

  -v    also print the output of ansible-playbook of a failed case

  run.sh
  run.sh -v failed-run second-run
USAGE
}

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"

# The default of node_upgrade_drain_marker. The cases never set the variable, so a change of the
# default, or of the key in one task file only, fails them.
marker="installer-immutable.sighup.io/drained-by-upgrade"
# The targets of the upgrade, as vars.yml gives them to the role.
target_kubelet="v1.36.5"
old_kubelet="v1.35.1"
target_flatcar="4459.2.1"
old_flatcar="4230.2.3"

call_annotate="^annotate node [a-z0-9]+ ${marker//./\\.}=true "
call_remove="^annotate node [a-z0-9]+ ${marker//./\\.}- "
call_drain="^drain "
call_uncordon="^uncordon "
call_pods="^get pods "
# The dots of the key are escaped, or kubectl reads a nested field and answers nothing.
call_read_marker="^get node [a-z0-9]+ -o jsonpath=\{\.metadata\.annotations\.${marker//./\\\\\\.}\} "

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Ansible keeps its temporary files under the home directory unless told otherwise.
export ANSIBLE_HOME="$work/ansible"
export ANSIBLE_REMOTE_TMP="$work/ansible/tmp"
export ANSIBLE_ROLES_PATH="$repo/roles"
export ANSIBLE_NOCOLOR=1
export ANSIBLE_FORCE_COLOR=0

# --- The node of the case --------------------------------------------------

# new_node <kubelet version> <schedulable|cordoned> [marked]
new_node() {
  export KUBECTL_STUB_DIR="$work/$case_name"
  mkdir -p "$KUBECTL_STUB_DIR"
  : >"$KUBECTL_STUB_DIR/calls.log"
  : >"$KUBECTL_STUB_DIR/ansible.log"
  {
    echo "kubeletVersion=$1"
    [[ "$2" == cordoned ]] && echo "unschedulable=true" || echo "unschedulable=false"
    echo "podsNotReady=0"
    [[ "${3:-}" != marked ]] || echo "annotation $marker=true"
  } >"$KUBECTL_STUB_DIR/node"
}

node_set() {
  sed -i "/^${1%%=*}=/d" "$KUBECTL_STUB_DIR/node"
  echo "$1" >>"$KUBECTL_STUB_DIR/node"
}

# --- The runs --------------------------------------------------------------

# play <playbook> <node> [<ansible-playbook argument>...]: the exit code is the one of the play.
play() {
  local playbook="$1" node="$2"
  shift 2
  ansible-playbook -i "$here/inventory.ini" "$here/$playbook" \
    --limit "$node" \
    -e "node_flatcar_version=$target_flatcar" \
    -e "kubectl_bin=$here/kubectl-stub.sh" \
    -e "kubernetes_kubeconfig_path=$KUBECTL_STUB_DIR/" \
    "$@" >>"$KUBECTL_STUB_DIR/ansible.log" 2>&1 </dev/null
}

entry_point() {
  local file="$1" node="$2"
  shift 2
  play entry-point.yml "$node" -e "entry_point=$file" "$@"
}

# --- The checks: each prints why it fails ----------------------------------

fail() {
  echo "  $*"
  return 1
}

succeeds() {
  "$@" || fail "the play failed: $*"
}

fails() {
  ! "$@" || fail "the play did not fail: $*"
}

decision_is() {
  grep -q "\"msg\": \"node_upgrade_drain_required=$1\"" "$KUBECTL_STUB_DIR/ansible.log" ||
    fail "node_upgrade_drain_required is not $1"
}

node_is() {
  local want=false
  [[ "$1" != cordoned ]] || want=true
  grep -qx "unschedulable=$want" "$KUBECTL_STUB_DIR/node" || fail "the node is not $1"
}

node_has_marker() {
  grep -qxF "annotation $marker=true" "$KUBECTL_STUB_DIR/node" || fail "the node has no annotation $marker=true"
}

node_has_no_annotation() {
  ! grep -q '^annotation ' "$KUBECTL_STUB_DIR/node" ||
    fail "the node still has: $(grep '^annotation ' "$KUBECTL_STUB_DIR/node" | tr '\n' ' ')"
}

# calls_in_order <pattern>...: each pattern matches a call later than the match of the one before.
calls_in_order() {
  local line=0 next pattern
  for pattern in "$@"; do
    next="$(tail -n "+$((line + 1))" "$KUBECTL_STUB_DIR/calls.log" | grep -nE -m1 -- "$pattern" | cut -d: -f1 || true)"
    [[ -n "$next" ]] || fail "no call matches '$pattern' after call $line of: $(tr '\n' ';' <"$KUBECTL_STUB_DIR/calls.log")"
    line=$((line + next))
  done
}

no_call() {
  local pattern
  for pattern in "$@"; do
    ! grep -qE -- "$pattern" "$KUBECTL_STUB_DIR/calls.log" || fail "unexpected call: $(grep -E -m1 -- "$pattern" "$KUBECTL_STUB_DIR/calls.log")"
  done
}

# --- The cases: the scenarios of the delta specs ---------------------------

# A drain marks the node first.
case_drain_marks_first() {
  new_node "$old_kubelet" schedulable
  succeeds entry_point drain.yml worker1
  node_is cordoned
  node_has_marker
  calls_in_order "$call_annotate" "$call_drain"
  # The annotate must be the first call that changes the node: a failure after a drain that
  # comes first leaves a cordoned node without a marker.
  [[ "$(head -n1 "$KUBECTL_STUB_DIR/calls.log")" =~ $call_annotate ]] || fail "the first call is not the annotate"
}

# A failed annotate stops the drain.
case_failed_annotate() {
  new_node "$old_kubelet" schedulable
  node_set fail=annotate
  fails entry_point drain.yml worker1
  no_call "$call_drain"
  node_is schedulable
}

# The run after a failed upgrade: the node is at its target, cordoned and marked.
case_failed_run() {
  new_node "$target_kubelet" cordoned marked
  succeeds entry_point preflight.yml worker1
  decision_is true
  calls_in_order "$call_read_marker"
}

# The same for a control plane, which the preflight does not compare with the Kubernetes target.
case_failed_run_control_plane() {
  new_node "$target_kubelet" cordoned marked
  succeeds entry_point preflight.yml cp1
  decision_is true
}

# A failed read of the marker fails the run, like a failed read of the kubelet version.
case_failed_marker_read() {
  new_node "$target_kubelet" schedulable
  node_set fail=get
  # cp1: the preflight reads nothing else for a control plane, so the read that fails is the marker's.
  fails entry_point preflight.yml cp1
}

# A healthy node at its target.
case_healthy_at_target() {
  new_node "$target_kubelet" schedulable
  succeeds entry_point preflight.yml worker1
  decision_is false
}

# A node cordoned by hand stays cordoned: no marker, no window.
case_hand_cordoned() {
  new_node "$target_kubelet" cordoned
  succeeds play window.yml worker1
  no_call "$call_annotate" "$call_drain" "$call_uncordon" "$call_remove"
  node_is cordoned
}

# A worker behind its target, as before the marker.
case_behind_target() {
  new_node "$old_kubelet" schedulable
  succeeds entry_point preflight.yml worker1
  decision_is true
}

# The marker decides on its own: a marked node needs the window in a run that is not an upgrade too.
case_marked_outside_upgrade() {
  new_node "$target_kubelet" cordoned marked
  succeeds entry_point preflight.yml worker1 -e upgrade=false
  decision_is true
}

# Without the marker the decision is the one before it: a pending OS reboot needs the window.
case_os_reboot_pending() {
  new_node "$target_kubelet" schedulable
  succeeds entry_point preflight.yml cp1 -e "node_flatcar_version=$old_flatcar"
  decision_is true
}

# And so does a worker whose system extensions changed.
case_sysext_changed() {
  new_node "$target_kubelet" schedulable
  succeeds entry_point preflight.yml worker1 -e '{"sysext_changed_components": ["kubernetes"]}'
  decision_is true
}

# A full window leaves nothing behind.
case_full_window() {
  new_node "$old_kubelet" schedulable
  succeeds play window.yml worker1
  calls_in_order "$call_annotate" "$call_drain" "$call_uncordon" "$call_remove" "$call_pods"
  node_is schedulable
  node_has_no_annotation
}

# A failed run followed by a second run: the second one uncordons the node.
case_second_run() {
  new_node "$old_kubelet" schedulable
  succeeds play window.yml worker1 -e stop_after_drain=true
  node_is cordoned
  node_has_marker
  node_set "kubeletVersion=$target_kubelet"
  : >"$KUBECTL_STUB_DIR/calls.log"
  succeeds play window.yml worker1
  calls_in_order "$call_uncordon" "$call_remove"
  node_is schedulable
  node_has_no_annotation
}

# The pod wait fails: the node is schedulable again, so the marker must be gone.
case_pod_wait_fails() {
  new_node "$target_kubelet" cordoned marked
  node_set podsNotReady=1
  fails entry_point uncordon.yml worker1
  calls_in_order "$call_uncordon" "$call_remove" "$call_pods"
  node_is schedulable
  node_has_no_annotation
}

# Removing a marker that is not there does not fail.
case_absent_marker() {
  new_node "$target_kubelet" cordoned
  succeeds entry_point uncordon.yml worker1
  calls_in_order "$call_uncordon" "$call_remove"
  node_is schedulable
  node_has_no_annotation
}

cases=(
  drain-marks-first
  failed-annotate
  failed-run
  failed-run-control-plane
  failed-marker-read
  healthy-at-target
  hand-cordoned
  behind-target
  marked-outside-upgrade
  os-reboot-pending
  sysext-changed
  full-window
  second-run
  pod-wait-fails
  absent-marker
)

verbose=false
selected=()
for argument in "$@"; do
  case "$argument" in
    -h | --help)
      usage
      exit 0
      ;;
    -v) verbose=true ;;
    *)
      [[ " ${cases[*]} " == *" $argument "* ]] || {
        echo "$argument: no such case (cases: ${cases[*]})" >&2
        exit 1
      }
      selected+=("$argument")
      ;;
  esac
done
[[ ${#selected[@]} -gt 0 ]] || selected=("${cases[@]}")

failed=0
for case_name in "${selected[@]}"; do
  # "set -e" has no effect in a command that "if" or "||" tests, so the case runs in a subshell
  # of its own, where the first check that fails ends it.
  set +e
  (
    set -e
    "case_${case_name//-/_}"
  ) >"$work/reason"
  status=$?
  set -e
  if [[ "$status" -eq 0 ]]; then
    echo "$case_name: ok"
  else
    echo "$case_name: FAILED"
    cat "$work/reason"
    [[ "$verbose" != true ]] || sed 's/^/    /' "$work/$case_name/ansible.log"
    failed=1
  fi
done
exit "$failed"
