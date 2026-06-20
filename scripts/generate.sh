#!/usr/bin/env bash
#
# Generate or refresh _generated/<version>/HostApp for a given React Native version.
#
# Usage:
#   scripts/generate.sh <rn-version> [--force | --update]
#
#   default     fail if _generated/<rn>/HostApp/ already exists
#   --force     rm -rf and re-init from scratch
#   --update    skip the 'init' step; re-apply overlays and re-run npm/pod install
#               (the common case after a shared overlay or RTNTestableModule change)
#
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
export MATRIX_ROOT="$(cd -- "$SCRIPT_DIR/.." &>/dev/null && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=scripts/lib/versions.sh
source "$SCRIPT_DIR/lib/versions.sh"
# shellcheck source=scripts/lib/apply-overlay.sh
source "$SCRIPT_DIR/lib/apply-overlay.sh"

require_cmd jq rsync npx npm bundle pod

usage() {
  cat >&2 <<EOF
usage: scripts/generate.sh <rn-version> [--force | --update]
EOF
  exit 2
}

[[ $# -ge 1 ]] || usage
VERSION="$1"; shift
MODE="create"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --force)  MODE="force";  shift ;;
    --update) MODE="update"; shift ;;
    -h|--help) usage ;;
    *) err "unknown flag: $1"; usage ;;
  esac
done

require_known_version "$VERSION"

CLI_SPEC="$(version_field "$VERSION" cli)"
FLAVOR="$(version_field "$VERSION" cliInitFlavor)"
[[ "$FLAVOR" == "community" ]] || die "unsupported cliInitFlavor: $FLAVOR (only 'community' implemented)"

APP_DIR="${MATRIX_ROOT}/_generated/${VERSION}/HostApp"

case "$MODE" in
  create)
    if [[ -e "$APP_DIR" ]]; then
      err "_generated/${VERSION}/HostApp already exists."
      err "  --force  : rm -rf and re-init"
      err "  --update : re-apply overlays and re-run install (no re-init)"
      exit 1
    fi
    ;;
  force)
    if [[ -e "$APP_DIR" ]]; then
      warn "removing existing $APP_DIR"
      rm -rf "$APP_DIR"
    fi
    ;;
  update)
    [[ -d "$APP_DIR" ]] || die "--update requires _generated/${VERSION}/HostApp to exist"
    ;;
esac

mkdir -p "${MATRIX_ROOT}/_generated/${VERSION}"

if [[ "$MODE" != "update" ]]; then
  info "init: $CLI_SPEC init HostApp --version $VERSION"
  TMP_DIR="$(mktemp -d -t tmtm-init.XXXXXX)"
  trap 'rm -rf "$TMP_DIR"' EXIT
  (
    cd "$TMP_DIR"
    npx --yes "$CLI_SPEC" init HostApp \
      --version "$VERSION" \
      --pm npm \
      --skip-install \
      --install-pods false \
      --replace-directory true
  )
  mv "$TMP_DIR/HostApp" "$APP_DIR"
  rm -rf "$TMP_DIR"
  trap - EXIT
  # The CLI's `init` runs `git init` inside the new app. Strip it so the
  # matrix repo treats the generated app as a regular subdirectory, not a
  # nested git repo (which git would otherwise try to track as a submodule).
  rm -rf "$APP_DIR/.git"
  ok "init complete: $APP_DIR"
else
  info "skipping init (--update)"
fi

info "applying overlays"
apply_overlays "$VERSION" "$APP_DIR"

info "npm install"
( cd "$APP_DIR" && npm install )

info "bundle install"
( cd "$APP_DIR" && bundle config set --local path 'vendor/bundle' && bundle install )

info "pod install (this also triggers codegen via prepare_react_native_project!)"
( cd "$APP_DIR/ios" && bundle exec pod install )

info "codegen sanity check"
CODEGEN_OK=0
for base in \
  "$APP_DIR/ios/build/generated/ios/ReactCodegen" \
  "$APP_DIR/ios/build/generated/ios" \
; do
  if [[ -f "$base/NativeRTNTestableModuleJSI.h" ]]; then
    ok "found codegen header at: $base/NativeRTNTestableModuleJSI.h"
    CODEGEN_OK=1
    break
  fi
done
if [[ $CODEGEN_OK -ne 1 ]]; then
  warn "codegen header NOT present after pod install; trying npx react-native codegen"
  ( cd "$APP_DIR" && npx react-native codegen ) || true
  for base in \
    "$APP_DIR/ios/build/generated/ios/ReactCodegen" \
    "$APP_DIR/ios/build/generated/ios" \
  ; do
    if [[ -f "$base/NativeRTNTestableModuleJSI.h" ]]; then
      ok "found codegen header at: $base/NativeRTNTestableModuleJSI.h"
      CODEGEN_OK=1
      break
    fi
  done
fi
if [[ $CODEGEN_OK -ne 1 ]]; then
  err "codegen header NativeRTNTestableModuleJSI.h not found at either:"
  err "  $APP_DIR/ios/build/generated/ios/ReactCodegen/"
  err "  $APP_DIR/ios/build/generated/ios/"
  err "this means the matrix won't be able to compile tests for this version."
  exit 1
fi

cat <<EOF

Generation complete for RN $VERSION.

Next steps:
  git add _generated/${VERSION}/
  # node_modules/, ios/Pods/, ios/build/, vendor/bundle/ are gitignored

Lock files that SHOULD be committed:
  _generated/${VERSION}/HostApp/package-lock.json
  _generated/${VERSION}/HostApp/Gemfile.lock
  _generated/${VERSION}/HostApp/ios/Podfile.lock

EOF
