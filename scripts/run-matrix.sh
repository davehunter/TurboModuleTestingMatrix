#!/usr/bin/env bash
#
# Run the matrix for all versions in versions.json (default) or a subset.
#
# Usage:
#   scripts/run-matrix.sh [<rn-version> ...]
#
# Environment:
#   TURBO_MODULE_TESTING_SRC  path to a local TurboModuleTesting checkout
#   TURBO_MODULE_TESTING_TAG  GitHub tag to FetchContent
#   MATRIX_RUN_ID             override the run id (default: timestamp+sha)
#
# Resolution order for the framework source:
#   1. TURBO_MODULE_TESTING_SRC (if set and exists)
#   2. TURBO_MODULE_TESTING_TAG (if set)
#   3. ../TurboModuleTesting sibling (fallback)
#   4. fail
#
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
export MATRIX_ROOT="$(cd -- "$SCRIPT_DIR/.." &>/dev/null && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=scripts/lib/versions.sh
source "$SCRIPT_DIR/lib/versions.sh"
# shellcheck source=scripts/lib/report.sh
source "$SCRIPT_DIR/lib/report.sh"

require_cmd jq cmake ninja ctest npm bundle pod

# ---------- args ----------
REQUESTED=()
if [[ $# -eq 0 ]]; then
  while IFS= read -r v; do REQUESTED+=("$v"); done < <(all_versions)
else
  for v in "$@"; do
    require_known_version "$v"
    REQUESTED+=("$v")
  done
fi

# ---------- framework source ----------
FW_KIND=""
FW_VALUE=""
FW_CMAKE_ARG=""

if [[ -n "${TURBO_MODULE_TESTING_SRC:-}" && -f "${TURBO_MODULE_TESTING_SRC}/CMakeLists.txt" ]]; then
  FW_KIND="local"
  FW_VALUE="$(cd "$TURBO_MODULE_TESTING_SRC" && pwd)"
  FW_CMAKE_ARG="-DTURBO_MODULE_TESTING_SRC=${FW_VALUE}"
elif [[ -n "${TURBO_MODULE_TESTING_TAG:-}" ]]; then
  FW_KIND="tag"
  FW_VALUE="$TURBO_MODULE_TESTING_TAG"
  FW_CMAKE_ARG="-DTURBO_MODULE_TESTING_TAG=${FW_VALUE}"
else
  SIBLING="$(cd "${MATRIX_ROOT}/.." 2>/dev/null && pwd)/TurboModuleTesting"
  if [[ -f "$SIBLING/CMakeLists.txt" ]]; then
    FW_KIND="sibling"
    FW_VALUE="$SIBLING"
    FW_CMAKE_ARG="-DTURBO_MODULE_TESTING_SRC=${FW_VALUE}"
  else
    die "no TurboModuleTesting source found: set TURBO_MODULE_TESTING_SRC, TURBO_MODULE_TESTING_TAG, or place TurboModuleTesting/ as a sibling of this repo"
  fi
fi
info "framework source: ${FW_KIND} = ${FW_VALUE}"

# ---------- run id / output dir ----------
SHORT_SHA=""
if command -v git >/dev/null 2>&1 && git -C "$MATRIX_ROOT" rev-parse --short HEAD >/dev/null 2>&1; then
  SHORT_SHA="-$(git -C "$MATRIX_ROOT" rev-parse --short HEAD)"
fi
RUN_ID="${MATRIX_RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)${SHORT_SHA}}"
RUN_DIR="${MATRIX_ROOT}/results/${RUN_ID}"
mkdir -p "$RUN_DIR"
ln -sfn "$RUN_ID" "${MATRIX_ROOT}/results/latest"

STARTED_ISO="$(iso_now)"
info "run id: $RUN_ID"
info "versions: ${REQUESTED[*]}"

# ---------- per-phase timeouts (seconds) ----------
T_NPM=600
T_POD=1500
T_CODEGEN=120
T_CONFIGURE=300
T_BUILD=900
T_CTEST=180

# ---------- per-version loop ----------
for V in "${REQUESTED[@]}"; do
  APP_DIR="${MATRIX_ROOT}/apps/${V}/HostApp"
  IOS_DIR="${APP_DIR}/ios"
  BUILD_DIR="${MATRIX_ROOT}/build/${V}"
  VRES_DIR="${RUN_DIR}/${V}"
  LOG_DIR="${VRES_DIR}/logs"
  JSONL="${VRES_DIR}/phases.jsonl"
  mkdir -p "$LOG_DIR"
  : > "$JSONL"

  if [[ ! -d "$APP_DIR" ]]; then
    err "[$V] apps/$V/HostApp not generated yet — run scripts/generate.sh $V first"
    record_skipped "$V" "npm-install"     "$JSONL"
    record_skipped "$V" "pod-install"     "$JSONL"
    record_skipped "$V" "codegen-check"   "$JSONL"
    record_skipped "$V" "cmake-configure" "$JSONL"
    record_skipped "$V" "cmake-build"     "$JSONL"
    record_skipped "$V" "ctest"           "$JSONL"
    continue
  fi

  # phase: npm-install
  if [[ -f "$APP_DIR/package-lock.json" ]]; then
    run_phase "$V" "npm-install" "$LOG_DIR" "$JSONL" "$T_NPM" "$APP_DIR" -- npm ci
  else
    warn "[$V] no package-lock.json; falling back to npm install"
    run_phase "$V" "npm-install" "$LOG_DIR" "$JSONL" "$T_NPM" "$APP_DIR" -- npm install
  fi
  if [[ $? -ne 0 ]]; then
    for p in pod-install codegen-check cmake-configure cmake-build ctest; do
      record_skipped "$V" "$p" "$JSONL"
    done
    continue
  fi

  # phase: pod-install
  run_phase "$V" "pod-install" "$LOG_DIR" "$JSONL" "$T_POD" "$IOS_DIR" -- \
    bash -c 'bundle config set --local path "vendor/bundle" >/dev/null && bundle install && bundle exec pod install'
  if [[ $? -ne 0 ]]; then
    for p in codegen-check cmake-configure cmake-build ctest; do
      record_skipped "$V" "$p" "$JSONL"
    done
    continue
  fi

  # phase: codegen-check (read-only; falls back to npx react-native codegen)
  run_phase "$V" "codegen-check" "$LOG_DIR" "$JSONL" "$T_CODEGEN" "$APP_DIR" -- bash -c '
    for base in ios/build/generated/ios/ReactCodegen ios/build/generated/ios; do
      if [[ -f "$base/NativeRTNTestableModuleJSI.h" ]]; then
        echo "found: $base/NativeRTNTestableModuleJSI.h"; exit 0
      fi
    done
    echo "codegen header missing; running npx react-native codegen"
    npx react-native codegen
    for base in ios/build/generated/ios/ReactCodegen ios/build/generated/ios; do
      if [[ -f "$base/NativeRTNTestableModuleJSI.h" ]]; then
        echo "found after codegen: $base/NativeRTNTestableModuleJSI.h"; exit 0
      fi
    done
    echo "codegen header still missing"
    exit 1
  '
  if [[ $? -ne 0 ]]; then
    for p in cmake-configure cmake-build ctest; do
      record_skipped "$V" "$p" "$JSONL"
    done
    continue
  fi

  # phase: cmake-configure
  rm -rf "$BUILD_DIR"
  run_phase "$V" "cmake-configure" "$LOG_DIR" "$JSONL" "$T_CONFIGURE" "$MATRIX_ROOT" -- \
    cmake -S . -B "$BUILD_DIR" -G Ninja \
      "-DEXAMPLE_APP_PATH=$APP_DIR" \
      "$FW_CMAKE_ARG"
  if [[ $? -ne 0 ]]; then
    for p in cmake-build ctest; do
      record_skipped "$V" "$p" "$JSONL"
    done
    continue
  fi

  # phase: cmake-build
  run_phase "$V" "cmake-build" "$LOG_DIR" "$JSONL" "$T_BUILD" "$MATRIX_ROOT" -- \
    cmake --build "$BUILD_DIR"
  if [[ $? -ne 0 ]]; then
    record_skipped "$V" "ctest" "$JSONL"
    continue
  fi

  # phase: ctest
  run_phase "$V" "ctest" "$LOG_DIR" "$JSONL" "$T_CTEST" "$MATRIX_ROOT" -- \
    ctest --test-dir "$BUILD_DIR" --output-on-failure --output-junit "$VRES_DIR/junit.xml"
done

# ---------- summary ----------
echo
write_summary "$RUN_DIR" "$STARTED_ISO" "$FW_KIND" "$FW_VALUE"

OVERALL="$(cat "${RUN_DIR}/.overall_status" 2>/dev/null || echo fail)"
if [[ "$OVERALL" == "pass" ]]; then
  exit 0
else
  exit 1
fi
