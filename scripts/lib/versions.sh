# shellcheck shell=bash
# Helpers around versions.json. Requires jq.

# all_versions
all_versions() {
  jq -r '.versions[].rn' "${MATRIX_ROOT}/versions.json"
}

# get_version <rn> -> JSON object on stdout, non-zero if not found.
get_version() {
  local rn="$1"
  jq -e --arg rn "$rn" '.versions[] | select(.rn == $rn)' "${MATRIX_ROOT}/versions.json"
}

# version_field <rn> <field>
version_field() {
  local rn="$1" field="$2"
  jq -er --arg rn "$rn" --arg f "$field" \
    '.versions[] | select(.rn == $rn) | .[$f] // empty' \
    "${MATRIX_ROOT}/versions.json"
}

# require_known_version <rn> — exits non-zero with a clear error if unknown.
require_known_version() {
  local rn="$1"
  if ! get_version "$rn" >/dev/null; then
    err "unknown RN version: $rn"
    err "known versions:"
    all_versions | sed 's/^/  - /' >&2
    exit 1
  fi
}
