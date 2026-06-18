# shellcheck shell=bash
# Apply matrix overlays onto a freshly-init'd HostApp directory.
#
# Sources:
#   overlays/_shared/      (applied first)
#   overlays/<version>/    (applied second; per-version overrides)
#
# A file named 'package.json.patch.json' anywhere under an overlay is NOT
# rsynced as-is; it's applied as a JSON Merge Patch (RFC 7396) against
# <host_app>/package.json using jq.

# apply_overlays <version> <host_app_dir>
apply_overlays() {
  local version="$1" dest="$2"
  local shared_dir="${MATRIX_ROOT}/overlays/_shared"
  local per_ver_dir="${MATRIX_ROOT}/overlays/${version}"

  [[ -d "$dest" ]] || die "apply_overlays: $dest does not exist"

  _rsync_overlay_files "$shared_dir" "$dest"
  if [[ -d "$per_ver_dir" ]]; then
    _rsync_overlay_files "$per_ver_dir" "$dest"
  fi

  _apply_package_json_patch "$shared_dir/package.json.patch.json" "$dest/package.json"
  _apply_package_json_patch "$per_ver_dir/package.json.patch.json" "$dest/package.json"
}

_rsync_overlay_files() {
  local src="$1" dest="$2"
  [[ -d "$src" ]] || return 0
  # Exclude the patch file itself from the verbatim copy.
  rsync -a --exclude='package.json.patch.json' "$src/" "$dest/"
}

_apply_package_json_patch() {
  local patch="$1" target="$2"
  [[ -f "$patch" ]] || return 0
  [[ -f "$target" ]] || die "package.json target missing: $target"
  local tmp
  tmp="$(mktemp)"
  # JSON Merge Patch via jq: recursive object merge, last-write-wins on scalars.
  jq -s '.[0] * .[1]' "$target" "$patch" > "$tmp"
  mv "$tmp" "$target"
  info "applied package.json patch: $patch -> $target"
}
