#!/usr/bin/env bash
# Copyright (c) 2017-present SIGHUP s.r.l All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# Vendors the kube-bench profiles of installer-on-premises into profiles/ and records where
# they come from in profiles/PROVENANCE.md. Needs git, patch, sha256sum and yamlfmt.
set -euo pipefail

tool_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repo_dir="$(cd "${tool_dir}/../.." && pwd)"
profiles_dir="${tool_dir}/profiles"
overlay_dir="${profiles_dir}/overlay"
provenance="${profiles_dir}/PROVENANCE.md"
versions="${tool_dir}/vars/versions.yml"
upstream_path="utils/kube-bench"
empty_overlay="The overlay is empty"

usage() {
  cat <<'USAGE'
Usage: sync-profiles.sh [--ref <commit> | --source <checkout>] [--check]

Rebuilds profiles/ from utils/kube-bench of installer-on-premises: copy, drop policies.yaml,
format with the repository's yamlfmt, apply profiles/overlay/*.patch in lexical order. Then
rewrites the hash tables of profiles/PROVENANCE.md and the commit of vars/versions.yml.

  --ref <commit>       fetch this installer-on-premises commit over HTTPS
  --source <checkout>  read a local installer-on-premises checkout, no network
  --check              change no file; exit non-zero when profiles/ or PROVENANCE.md differ
                       from what the recorded commit produces
  -h, --help           show this help

With neither --ref nor --source, the commit recorded in vars/versions.yml is fetched.

  sync-profiles.sh --check
  sync-profiles.sh --ref 80fc521d4047aeb468eab8215b2e6cc571975bdc
  sync-profiles.sh --source ~/src/installer-on-premises
USAGE
}

die() {
  echo "sync-profiles.sh: $*" >&2
  exit 1
}

recorded() {
  sed -n "s/^$1: *\"\{0,1\}\([^\" ]*\)\"\{0,1\} *$/\1/p" "${versions}"
}

sha256_of() {
  sha256sum "$1" | cut -d ' ' -f 1
}

format_yaml() {
  if command -v yamlfmt >/dev/null 2>&1; then
    yamlfmt -conf "${repo_dir}/.yamlfmt" "$@"
  elif command -v mise >/dev/null 2>&1; then
    mise exec -- yamlfmt -conf "${repo_dir}/.yamlfmt" "$@"
  else
    die "yamlfmt is not on PATH and mise is not installed"
  fi
}

# A checkout extracted inside another repository must not report that repository's HEAD.
checkout_commit() {
  local top
  top="$(git -C "$1" rev-parse --show-toplevel 2>/dev/null || true)"
  if [[ -n "${top}" && "$(cd "${top}" && pwd -P)" == "$(cd "$1" && pwd -P)" ]]; then
    git -C "$1" rev-parse HEAD
  fi
}

fetch_commit() {
  local commit="$1" destination="$2"
  git init -q "${destination}"
  if ! git -C "${destination}" fetch -q --depth 1 "${source_repo}" "${commit}"; then
    die "cannot fetch ${commit} from ${source_repo}"
  fi
  if ! git -C "${destination}" checkout -q FETCH_HEAD -- "${upstream_path}"; then
    die "${commit} of ${source_repo} has no ${upstream_path}"
  fi
}

overlay_patches() {
  find "${overlay_dir}" -maxdepth 1 -type f -name '*.patch' 2>/dev/null | LC_ALL=C sort
}

vendored_files() {
  (cd "$1" && find config.yaml cis-* -type f 2>/dev/null | LC_ALL=C sort)
}

# Copies the upstream profiles, drops policies.yaml, formats them with yamlfmt and applies
# the overlay.
build_stage() {
  local upstream="$1" stage="$2" benchmark patch file
  local -a files=()

  [[ -f "${upstream}/config.yaml" ]] || die "${upstream} has no config.yaml"
  mkdir -p "${stage}"
  cp "${upstream}/config.yaml" "${stage}/config.yaml"
  for benchmark in "${upstream}"/cis-*/; do
    [[ -d "${benchmark}" ]] || die "${upstream} has no cis-* benchmark"
    cp -r "${benchmark%/}" "${stage}/"
  done
  find "${stage}" -type f -name policies.yaml -delete

  while IFS= read -r file; do
    files+=("${stage}/${file}")
  done < <(vendored_files "${stage}")
  # From the repository, where mise resolves the pinned yamlfmt.
  (cd "${repo_dir}" && format_yaml "${files[@]}")

  while IFS= read -r patch; do
    if ! patch -p1 -s -f --no-backup-if-mismatch -d "${stage}" -i "${patch}" >&2; then
      die "overlay patch $(basename "${patch}") does not apply"
    fi
    find "${stage}" -type f \( -name '*.rej' -o -name '*.orig' \) -delete
  done < <(overlay_patches)
}

source_block() {
  local commit="$1" synced_on="$2" changelog_sha="$3"
  echo "| Field | Value |"
  echo "| --- | --- |"
  echo "| Repository | ${source_repo} |"
  echo "| Commit | \`${commit}\` |"
  echo "| Path | \`${upstream_path}\` |"
  echo "| Synced on | ${synced_on} |"
  echo "| kube-bench version | $(recorded cis_kube_bench_version) |"
  echo "| Upstream \`CHANGELOG.md\` sha256 | \`${changelog_sha}\` |"
}

files_block() {
  local upstream="$1" stage="$2" file
  echo "| File | Upstream sha256 | Local sha256 |"
  echo "| --- | --- | --- |"
  while IFS= read -r file; do
    echo "| \`${file}\` | \`$(sha256_of "${upstream}/${file}")\` | \`$(sha256_of "${stage}/${file}")\` |"
  done < <(vendored_files "${stage}")
}

# The line of PROVENANCE.md that begins or ends a block the script rewrites.
marker() {
  echo "<!-- sync-profiles:$1:$2 -->"
}

recorded_block() {
  awk -v begin="$(marker "$1" begin)" -v end="$(marker "$1" end)" '
    $0 == end { inside = 0 }
    inside { print }
    $0 == begin { inside = 1 }
  ' "${provenance}"
}

write_block() {
  local name="$1" content="$2" rewritten="$3"
  if ! grep -Fxq "$(marker "${name}" begin)" "${provenance}"; then
    die "${provenance} has no ${name} block"
  fi
  awk -v begin="$(marker "${name}" begin)" \
    -v end="$(marker "${name}" end)" -v content="${content}" '
    $0 == end { inside = 0 }
    !inside { print }
    $0 == begin { inside = 1; print content }
  ' "${provenance}" >"${rewritten}"
  cat "${rewritten}" >"${provenance}"
}

problems=0
problem() {
  echo "sync-profiles.sh: $*"
  problems=$((problems + 1))
}

check_tree() {
  local stage="$1" file
  while IFS= read -r file; do
    if [[ ! -f "${stage}/${file}" ]]; then
      problem "profiles/${file} is not produced from the recorded commit"
    fi
  done < <(vendored_files "${profiles_dir}")
  while IFS= read -r file; do
    if [[ ! -f "${profiles_dir}/${file}" ]]; then
      problem "profiles/${file} is missing"
    elif ! cmp -s "${stage}/${file}" "${profiles_dir}/${file}"; then
      problem "profiles/${file} differs from what the recorded commit produces"
      diff -u "${profiles_dir}/${file}" "${stage}/${file}" || true
    fi
  done < <(vendored_files "${stage}")
}

# The second column of a Markdown row names what the row records.
row_item() {
  echo "$1" | cut -d '|' -f 2 | tr -d '`' | sed 's/^ *//; s/ *$//'
}

check_block() {
  local name="$1" expected="$2" actual row
  actual="$(recorded_block "${name}")"
  while IFS= read -r row; do
    if ! grep -Fxq -- "${row}" <<<"${actual}"; then
      problem "PROVENANCE.md does not record what the pipeline produces for $(row_item "${row}")"
    fi
  done <<<"${expected}"
  while IFS= read -r row; do
    if [[ -n "${row}" ]] && ! grep -Fxq -- "${row}" <<<"${expected}"; then
      problem "PROVENANCE.md records $(row_item "${row}"), which the pipeline does not produce"
    fi
  done <<<"${actual}"
}

overlay_section() {
  awk -v heading="### $1" '
    /^##/ { inside = 0 }
    inside { print }
    $0 == heading { inside = 1 }
  ' "${provenance}"
}

check_overlay() {
  local patch name section field listed=0
  while IFS= read -r patch; do
    listed=1
    name="$(basename "${patch}")"
    if ! grep -Fxq "### ${name}" "${provenance}"; then
      problem "overlay patch ${name} is not listed in PROVENANCE.md"
      continue
    fi
    section="$(overlay_section "${name}")"
    for field in "Checks" "Flatcar fact" "Evidence"; do
      if ! grep -Eq "^- \*\*${field}:\*\* *[^ ]" <<<"${section}"; then
        problem "overlay patch ${name} records no ${field} in PROVENANCE.md"
      fi
    done
  done < <(overlay_patches)
  if [[ "${listed}" -eq 0 ]] && ! grep -Fq "${empty_overlay}" "${provenance}"; then
    problem "PROVENANCE.md does not state that the overlay is empty"
  fi
  if [[ "${listed}" -eq 1 ]] && grep -Fq "${empty_overlay}" "${provenance}"; then
    problem "PROVENANCE.md states that the overlay is empty, but profiles/overlay holds patches"
  fi
}

# Sets ref, source_dir and check from the arguments.
parse_arguments() {
  ref=""
  source_dir=""
  check=0
  while [[ $# -gt 0 ]]; do
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
      usage
      exit 0
    elif [[ "$1" == "--check" ]]; then
      check=1
      shift
    elif [[ "$1" == "--ref" || "$1" == "--source" ]]; then
      [[ $# -ge 2 ]] || die "$1 needs a value"
      if [[ "$1" == "--ref" ]]; then
        ref="$2"
      else
        source_dir="$2"
      fi
      shift 2
    else
      usage >&2
      die "unknown argument: $1"
    fi
  done
  [[ -z "${ref}" || -z "${source_dir}" ]] || die "--ref and --source exclude each other"
}

# Sets commit and upstream: the commit the profiles come from and where its files are.
resolve_source() {
  commit="${ref:-${recorded_commit}}"
  if [[ -n "${source_dir}" ]]; then
    [[ -d "${source_dir}/${upstream_path}" ]] || die "${source_dir} has no ${upstream_path}"
    source_dir="$(cd "${source_dir}" && pwd)"
    commit="$(checkout_commit "${source_dir}")"
    commit="${commit:-${recorded_commit}}"
    if [[ "${check}" -eq 1 && "${commit}" != "${recorded_commit}" ]]; then
      die "${source_dir} is at ${commit}, the recorded commit is ${recorded_commit}"
    fi
  else
    source_dir="${scratch}/source"
    fetch_commit "${commit}" "${source_dir}"
  fi
  upstream="${source_dir}/${upstream_path}"
  [[ -f "${upstream}/CHANGELOG.md" ]] || die "${upstream} has no CHANGELOG.md"
}

check_profiles() {
  local stage="$1" synced_on
  synced_on="$(recorded_block source | sed -n 's/^| Synced on | \(.*\) |$/\1/p')"
  check_tree "${stage}"
  check_block source "$(source_block "${commit}" "${synced_on}" "${changelog_sha}")"
  check_block files "${hashes}"
  check_overlay
  if [[ "${problems}" -gt 0 ]]; then
    die "${problems} difference(s) between profiles/ and commit ${commit}"
  fi
  echo "profiles/ and PROVENANCE.md match ${source_repo} at ${commit}"
}

install_profiles() {
  local stage="$1" file
  while IFS= read -r file; do
    rm -f "${profiles_dir:?}/${file}"
  done < <(vendored_files "${profiles_dir}")
  find "${profiles_dir}" -mindepth 1 -maxdepth 1 -type d -name 'cis-*' -empty -delete
  while IFS= read -r file; do
    mkdir -p "$(dirname "${profiles_dir}/${file}")"
    cp "${stage}/${file}" "${profiles_dir}/${file}"
    chmod 0644 "${profiles_dir}/${file}"
  done < <(vendored_files "${stage}")
}

record_source() {
  write_block source "$(source_block "${commit}" "$(date -u +%Y-%m-%d)" "${changelog_sha}")" \
    "${scratch}/provenance"
  write_block files "${hashes}" "${scratch}/provenance"
  sed "s/^cis_profiles_source_commit: .*$/cis_profiles_source_commit: ${commit}/" \
    "${versions}" >"${scratch}/versions"
  cat "${scratch}/versions" >"${versions}"
}

parse_arguments "$@"

source_repo="$(recorded cis_profiles_source_repo)"
recorded_commit="$(recorded cis_profiles_source_commit)"
if [[ -z "${source_repo}" || -z "${recorded_commit}" ]]; then
  die "${versions} records no profiles source repository and commit"
fi
[[ -f "${provenance}" ]] || die "${provenance} is missing"
if [[ "${check}" -eq 1 && -n "${ref}" && "${ref}" != "${recorded_commit}" ]]; then
  die "--check replays the recorded commit ${recorded_commit}, not ${ref}"
fi

scratch="$(mktemp -d)"
trap 'rm -rf "${scratch}"' EXIT INT TERM

resolve_source
build_stage "${upstream}" "${scratch}/stage"
changelog_sha="$(sha256_of "${upstream}/CHANGELOG.md")"
hashes="$(files_block "${upstream}" "${scratch}/stage")"

if [[ "${check}" -eq 1 ]]; then
  check_profiles "${scratch}/stage"
  exit 0
fi

install_profiles "${scratch}/stage"
record_source
check_overlay
[[ "${problems}" -eq 0 ]] || die "profiles/ is synced, but PROVENANCE.md needs the fixes above"
echo "profiles/ synced from ${source_repo} at ${commit}"
