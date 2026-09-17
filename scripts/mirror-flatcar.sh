#!/usr/bin/env bash
# Copyright (c) 2017-present SIGHUP s.r.l All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# Mirror one Flatcar release into the S3 buckets that Nebraska serves, then print the values
# needed by the Nebraska "Add Package" dialog. Needs only curl, openssl and gpg.
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: mirror-flatcar.sh <version> [arch...]

Mirrors one Flatcar release into the S3 buckets Nebraska serves, verifies every artifact
against the Flatcar signing key, and prints the values for Nebraska's "Add Package" dialog.
Defaults to both amd64 and arm64. Artifacts already mirrored are skipped.

  mirror-flatcar.sh 4593.2.3              both arches
  mirror-flatcar.sh 4593.2.3 amd64        one arch
  DRY_RUN=1 mirror-flatcar.sh 4593.2.3    show what would be uploaded

Required
  S3_ENDPOINT_URL        S3 endpoint, e.g. https://s3.example.com
  AWS_ACCESS_KEY_ID      credentials for that endpoint
  AWS_SECRET_ACCESS_KEY

Optional
  CHANNEL                Flatcar channel (default: stable)
  RELEASE_BUCKET         bucket for images/PXE/sysext (default: flatcar-stable-release)
  UPDATE_BUCKET          bucket for the Omaha payload (default: nebraska-flatcar-updates)
  PACKAGE_BASE_URL       public base URL holding <arch>-usr/<version>/
                         (default: https://update.release.sighup-prod.sighup.io)
  AWS_REGION             SigV4 region (default: us-east-1)
  RECAP_DIR              where the API payload and immutable.yaml snippet are written
                         (default: current dir)
  ASSET_BASE_URL         host the immutable.yaml urls point at
                         (default: https://stable.release.sighup-prod.sighup.io)
  DRY_RUN=1              print uploads instead of performing them
  FORCE=1                re-download and re-upload even when already mirrored
  NEBRASKA_URL           also create the package through the Nebraska API
  NEBRASKA_TOKEN         token for that API; omit when the endpoint needs no auth
  NEBRASKA_AUTH_SCHEME   Authorization scheme (default: Bearer; use Pomerium for a service account)
  NEBRASKA_APP_ID        Nebraska application (default: Flatcar's well-known app id)
USAGE
}

case "${1:-}" in
  -h | --help) usage; exit 0 ;;
  "") usage >&2; exit 1 ;;
esac

VERSION="$1"
shift
ARCHES=("$@")
if [ ${#ARCHES[@]} -eq 0 ]; then ARCHES=(amd64 arm64); fi

CHANNEL="${CHANNEL:-stable}"
ENDPOINT="${S3_ENDPOINT_URL:?set S3_ENDPOINT_URL to the S3 endpoint, e.g. https://s3.example.com}"
REGION="${AWS_REGION:-us-east-1}"
REL_BUCKET="${RELEASE_BUCKET:-flatcar-stable-release}"
UPD_BUCKET="${UPDATE_BUCKET:-nebraska-flatcar-updates}"
REL_SRC="https://${CHANNEL}.release.flatcar-linux.net"
UPD_SRC="https://update.release.flatcar-linux.net"
KEY_URL="${FLATCAR_KEY_URL:-https://www.flatcar.org/security/image-signing-key/Flatcar_Image_Signing_Key.asc}"
KEY_FPR="${FLATCAR_KEY_FPR:-F88CFEDEFF29A5B4D9523864E25D9AED0593B34A}"  # Flatcar Buildbot (Official Builds)
# Base URL the nodes fetch updates from: the directory that holds <arch>-usr/<version>/.
# This is the public host in front of the update bucket, not the S3 endpoint.
PACKAGE_BASE_URL="${PACKAGE_BASE_URL:-https://update.release.sighup-prod.sighup.io}"
# Flatcar's well-known Omaha application ID.
NEBRASKA_APP_ID="${NEBRASKA_APP_ID:-e96281a6-d1af-4bde-9a0a-97b76e56dc57}"
RECAP_DIR="${RECAP_DIR:-$PWD}"
# Host serving the release artifacts, as installer-immutable's immutable.yaml references them.
ASSET_BASE_URL="${ASSET_BASE_URL:-https://stable.release.sighup-prod.sighup.io}"

# Assets kept in the release bucket with their .DIGESTS/.DIGESTS.asc/.sig sidecars.
ASSETS=(flatcar_production_image.bin.bz2 flatcar_production_pxe_image.cpio.gz flatcar_production_pxe.vmlinuz)

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

die() { echo "$*" >&2; exit 1; }
hex() { awk '{print $NF}'; }                                   # last field of an openssl dgst line
sha256_file() { openssl dgst -sha256 "$1" | hex; }
sha256_str() { printf %s "$1" | openssl dgst -sha256 | hex; }
hmac() { openssl dgst -sha256 -mac HMAC -macopt "hexkey:$1" | hex; }   # data on stdin, hex key
sum() { if command -v "sha${1}sum" >/dev/null; then "sha${1}sum" "$2"; else shasum -a "$1" "$2"; fi; }
filesize() { wc -c < "$1" | tr -d ' '; }

# SigV4 signing, path-style. Object keys here are plain names, so no URI escaping.
# ponytail: the secret is passed to openssl on the command line (visible in ps); move to a
# signing helper that reads it from a file if this ever runs on a shared host.
EMPTY_SHA256=e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
sign() { # <method> <canonical-path> <payload-hash>; sets SIG_HEADERS
  local method="$1" path="$2" payload="$3" host amzdate datestamp creq sts scope k
  host="${ENDPOINT#*://}"; host="${host%%/*}"
  amzdate="$(date -u +%Y%m%dT%H%M%SZ)"; datestamp="${amzdate%%T*}"
  scope="${datestamp}/${REGION}/s3/aws4_request"
  creq="${method}
${path}

host:${host}
x-amz-content-sha256:${payload}
x-amz-date:${amzdate}

host;x-amz-content-sha256;x-amz-date
${payload}"
  sts="AWS4-HMAC-SHA256
${amzdate}
${scope}
$(sha256_str "$creq")"
  k="$(printf %s "$datestamp" | openssl dgst -sha256 -hmac "AWS4${AWS_SECRET_ACCESS_KEY}" | hex)"
  k="$(printf %s "$REGION" | hmac "$k")"
  k="$(printf %s s3 | hmac "$k")"
  k="$(printf %s aws4_request | hmac "$k")"
  k="$(printf %s "$sts" | hmac "$k")"
  SIG_HEADERS=(
    -H "x-amz-date: ${amzdate}"
    -H "x-amz-content-sha256: ${payload}"
    -H "Authorization: AWS4-HMAC-SHA256 Credential=${AWS_ACCESS_KEY_ID}/${scope}, SignedHeaders=host;x-amz-content-sha256;x-amz-date, Signature=${k}"
  )
}

s3_put() { # <file> <bucket> <key>
  local file="$1" bucket="$2" key="$3"
  if [ -n "${DRY_RUN:-}" ]; then echo "DRY_RUN: PUT ${ENDPOINT}/${bucket}/${key} <- ${file##*/}"; return; fi
  sign PUT "/${bucket}/${key}" "$(sha256_file "$file")"
  curl -fsS --retry 3 -X PUT -T "$file" "${SIG_HEADERS[@]}" \
    "${ENDPOINT}/${bucket}/${key}" || die "upload failed: ${bucket}/${key}"
}

s3_size() { # <bucket> <key> -> size in bytes, empty when the object is absent
  sign HEAD "/${1}/${2}" "$EMPTY_SHA256"
  curl -sS --head "${SIG_HEADERS[@]}" "${ENDPOINT}/${1}/${2}" \
    | awk 'tolower($1)=="content-length:"{v=$2} END{gsub(/\r/,"",v); print v}'
}

src_size() { # <url> -> upstream size in bytes
  curl -fsIL "$1" | awk 'tolower($1)=="content-length:"{v=$2} END{gsub(/\r/,"",v); print v}'
}

# A Flatcar artifact never changes once a version is published, so a size match means the object
# is already mirrored and both the download and the upload can be skipped. FORCE=1 redoes them.
# ponytail: size, not checksum. FORCE=1 is the escape hatch after a truncated upload.
in_sync() { # <bucket> <key> <source-url>
  local have
  { [ -n "${FORCE:-}" ] || [ -n "${DRY_RUN:-}" ]; } && return 1
  have="$(s3_size "$1" "$2")"
  [ -n "$have" ] && [ "$have" = "$(src_size "$3")" ]
}

group_in_sync() { # <asset> <prefix> <source-dir-url>
  local f="$1" prefix="$2" src="$3" ext
  if [ "$f" = flatcar-python.raw ]; then
    [ -n "$(s3_size "$REL_BUCKET" "${prefix}/SHA256SUMS")" ] || return 1
    in_sync "$REL_BUCKET" "${prefix}/${f}" "${src}/${f}"
    return
  fi
  for ext in "" .DIGESTS .DIGESTS.asc .sig; do
    in_sync "$REL_BUCKET" "${prefix}/${f}${ext}" "${src}/${f}${ext}" || return 1
  done
}

if [ -z "${DRY_RUN:-}" ]; then
  : "${AWS_ACCESS_KEY_ID:?set AWS_ACCESS_KEY_ID}" "${AWS_SECRET_ACCESS_KEY:?set AWS_SECRET_ACCESS_KEY}"
fi

# Isolated keyring: only the pinned Flatcar signing key can produce a good signature.
export GNUPGHOME="${WORK}/gnupg"
mkdir -p "$GNUPGHOME" && chmod 700 "$GNUPGHOME"
curl -fsSL -o "${WORK}/key.asc" "$KEY_URL"
gpg --batch --quiet --import "${WORK}/key.asc"
gpg --batch --list-keys "$KEY_FPR" >/dev/null 2>&1 || die "signing key ${KEY_FPR} not in ${KEY_URL}"

verify() { # <file>, with <file>.sig and <file>.DIGESTS.asc alongside
  local want got
  gpg --batch --quiet --verify "$1.DIGESTS.asc" >/dev/null 2>&1 || die "bad signature: $1.DIGESTS.asc"
  gpg --batch --quiet --verify "$1.sig" "$1" >/dev/null 2>&1 || die "bad signature: $1.sig"
  want=$(awk '/SHA512 HASH/{getline; print $1}' "$1.DIGESTS.asc")   # hash read from the signed copy
  got=$(sum 512 "$1" | cut -d' ' -f1)
  [ -n "$want" ] && [ "$want" = "$got" ] || die "checksum mismatch: $1"
}

# Values for the Nebraska "Add Package" dialog, and the same payload as JSON for the API.
# Hash is base64 SHA1, Flatcar Action SHA256 is base64 SHA256, both of the update payload.
SNIPPET="${RECAP_DIR}/immutable-${VERSION}.yaml"

# sha256 of every artifact, rendered as the block installer-immutable/immutable.yaml expects.
# Hashes come from the files this run downloaded; a skipped group reuses the previous snippet.
record_sha() { # <arch> <path>
  printf '%s %s %s\n' "$1" "${2##*/}" "$(sum 256 "$2" | cut -d' ' -f1)" >> "${WORK}/shas.txt"
}

prev_sha() { # <arch> <filename>
  [ -f "$SNIPPET" ] || return 0
  grep -A1 "/${1}-usr/${VERSION}/${2}$" "$SNIPPET" | awk '/sha256:/{print $2; exit}'
}

sha_entry() { # <arch> <filename>
  local sha
  sha="$(awk -v a="$1" -v f="$2" '$1==a && $2==f {print $3; exit}' "${WORK}/shas.txt" 2>/dev/null)"
  [ -n "$sha" ] || sha="UNKNOWN-rerun-with-FORCE=1"
  printf '            url: %s/%s-usr/%s/%s\n            sha256: %s\n' \
    "${ASSET_BASE_URL%/}" "$1" "$VERSION" "$2" "$sha"
}

immutable_snippet() {
  local a key
  {
    echo "      - name: flatcar-python"
    echo "        version: ${VERSION}"
    echo "        arch:"
    for a in "${ARCHES[@]}"; do
      case "$a" in amd64) key=x86-64 ;; *) key="$a" ;; esac
      echo "          ${key}:"
      sha_entry "$a" flatcar-python.raw
    done
    echo "    flatcar:"
    echo "      version: ${VERSION}"
    echo "      channel: ${CHANNEL}"
    echo "      arch:"
    for a in "${ARCHES[@]}"; do
      case "$a" in amd64) key=x86-64 ;; *) key="$a" ;; esac
      echo "        ${key}:"
      echo "          kernel:"
      echo "            filename: flatcar_production_pxe.vmlinuz"
      sha_entry "$a" flatcar_production_pxe.vmlinuz
      echo "          initrd:"
      echo "            filename: flatcar_production_pxe_image.cpio.gz"
      sha_entry "$a" flatcar_production_pxe_image.cpio.gz
      echo "          image:"
      echo "            filename: flatcar_production_image.bin.bz2"
      sha_entry "$a" flatcar_production_image.bin.bz2
    done
  } > "$SNIPPET"
}

json_get() { # <field> <file>
  grep -o "\"$1\": *\"[^\"]*\"" "$2" | head -1 | sed 's/.*: *"//; s/"$//'
}

# Values for the Nebraska "Add Package" dialog, and the same payload as JSON for the API.
# Hash is base64 SHA1, Flatcar Action SHA256 is base64 SHA256, both of the update payload.
recap() { # <arch> <size> <sha1-base64> <sha256-base64>
  local arch="$1" size="$2" hash="$3" sha256="$4" url arch_id json
  url="${PACKAGE_BASE_URL%/}/${arch}-usr/${VERSION}/"
  # Nebraska stores this URL verbatim, so a wrong base silently breaks every node's update.
  curl -fsIL -o /dev/null --max-time 15 "${url}flatcar_production_update.gz" ||
    echo "   WARNING: ${url}flatcar_production_update.gz is not reachable - check PACKAGE_BASE_URL" >&2
  case "$arch" in amd64) arch_id=1 ;; arm64) arch_id=2 ;; *) arch_id=0 ;; esac
  json="${RECAP_DIR}/nebraska-package-${arch}-${VERSION}.json"
  cat > "$json" <<JSON
{
  "application_id": "${NEBRASKA_APP_ID}",
  "type": 1,
  "arch": ${arch_id},
  "url": "${url}",
  "filename": "flatcar_production_update.gz",
  "description": "Flatcar ${CHANNEL} ${VERSION} ${arch}",
  "version": "${VERSION}",
  "size": "${size}",
  "hash": "${hash}",
  "channels_blacklist": [],
  "flatcar_action": { "sha256": "${sha256}" }
}
JSON
  cat >> "${WORK}/recap.txt" <<RECAP

-- Nebraska > Add Package > ${arch} --
Type                   Flatcar
Architecture           $(echo "$arch" | tr '[:lower:]' '[:upper:]')
URL                    ${url}
Filename               flatcar_production_update.gz
Description            Flatcar ${CHANNEL} ${VERSION} ${arch}
Version                ${VERSION}
Size                   ${size}
Hash                   ${hash}
Flatcar Action SHA256  ${sha256}
Channels Blacklist     (leave empty)
API payload            ${json}
RECAP
  if [ -n "${NEBRASKA_URL:-}" ]; then
    # Nebraska behind Pomerium: either point NEBRASKA_URL at a port-forward that skips the proxy,
    # or use a Pomerium service-account JWT with NEBRASKA_AUTH_SCHEME=Pomerium. No token, no header.
    local auth=()
    [ -n "${NEBRASKA_TOKEN:-}" ] && auth=(-H "Authorization: ${NEBRASKA_AUTH_SCHEME:-Bearer} ${NEBRASKA_TOKEN}")
    curl -fsS -X POST "${NEBRASKA_URL%/}/api/apps/${NEBRASKA_APP_ID}/packages" \
      "${auth[@]}" \
      -H "Content-Type: application/json" \
      --data-binary @"$json" >/dev/null && echo "   created in Nebraska: ${arch} ${VERSION}"
  fi
}

nebraska_recap() { # <update.gz> <arch>
  recap "$2" "$(filesize "$1")" \
    "$(openssl dgst -sha1 -binary "$1" | base64)" \
    "$(openssl dgst -sha256 -binary "$1" | base64)"
}

for arch in "${ARCHES[@]}"; do
  src="${REL_SRC}/${arch}-usr/${VERSION}"
  prefix="${CHANNEL}/${arch}-usr/${VERSION}"

  # flatcar-python.raw is verified like the rest, but the bucket keeps it without sidecars.
  for f in "${ASSETS[@]}" flatcar-python.raw; do
    if group_in_sync "$f" "$prefix" "$src"; then
      echo ">> ${arch}/${f} (already mirrored, skipped)"
      printf '%s %s %s\n' "$arch" "$f" "$(prev_sha "$arch" "$f")" >> "${WORK}/shas.txt"
      continue
    fi
    echo ">> ${arch}/${f}"
    for ext in "" .DIGESTS .DIGESTS.asc .sig; do
      curl -fL --retry 3 -# -o "${WORK}/${f}${ext}" "${src}/${f}${ext}"
    done
    verify "${WORK}/${f}"
    record_sha "$arch" "${WORK}/${f}"
    s3_put "${WORK}/${f}" "$REL_BUCKET" "${prefix}/${f}"
    if [ "$f" != flatcar-python.raw ]; then
      for ext in .DIGESTS .DIGESTS.asc .sig; do
        s3_put "${WORK}/${f}${ext}" "$REL_BUCKET" "${prefix}/${f}${ext}"
      done
    else
      (cd "${WORK}" && sum 256 flatcar-python.raw > SHA256SUMS)   # not published upstream
      s3_put "${WORK}/SHA256SUMS" "$REL_BUCKET" "${prefix}/SHA256SUMS"
      rm -f "${WORK}/SHA256SUMS"
    fi
    rm -f "${WORK}/${f}"*
  done

  # Omaha update payload: different host, no signature or digest published there.
  upd_key="flatcar/${arch}-usr/${VERSION}/flatcar_production_update.gz"
  upd_url="${UPD_SRC}/${arch}-usr/${VERSION}/flatcar_production_update.gz"
  recap_json="${RECAP_DIR}/nebraska-package-${arch}-${VERSION}.json"
  if [ -f "$recap_json" ] && in_sync "$UPD_BUCKET" "$upd_key" "$upd_url"; then
    echo ">> ${arch}/flatcar_production_update.gz (already mirrored, skipped)"
    recap "$arch" "$(json_get size "$recap_json")" \
      "$(json_get hash "$recap_json")" "$(json_get sha256 "$recap_json")"
  else
    echo ">> ${arch}/flatcar_production_update.gz"
    curl -fL --retry 3 -# -o "${WORK}/flatcar_production_update.gz" "$upd_url"
    s3_put "${WORK}/flatcar_production_update.gz" "$UPD_BUCKET" "$upd_key"
    nebraska_recap "${WORK}/flatcar_production_update.gz" "$arch"
    rm -f "${WORK}/flatcar_production_update.gz"
  fi
done

immutable_snippet
echo "done: ${VERSION} (${ARCHES[*]})"
if [ -f "${WORK}/recap.txt" ]; then cat "${WORK}/recap.txt"; fi
echo
echo "-- installer-immutable/immutable.yaml (${SNIPPET}) --"
cat "$SNIPPET"
