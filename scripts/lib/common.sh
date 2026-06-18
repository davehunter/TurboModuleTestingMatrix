# shellcheck shell=bash
# Common helpers: logging, phase wrapper, timing.

set -u

# Resolve matrix root from a script invocation. Each entry script sets
# MATRIX_ROOT before sourcing this file.
MATRIX_ROOT="${MATRIX_ROOT:-}"

_is_color_tty() { [[ -t 1 && "${NO_COLOR:-}" == "" ]]; }
if _is_color_tty; then
  C_RESET=$'\033[0m'; C_DIM=$'\033[2m'; C_RED=$'\033[31m'
  C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_BLUE=$'\033[34m'
else
  C_RESET=""; C_DIM=""; C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""
fi

log()  { printf '%s[%s]%s %s\n' "$C_DIM" "$(date -u +%H:%M:%S)" "$C_RESET" "$*" >&2; }
info() { printf '%s%s%s\n' "$C_BLUE" "$*" "$C_RESET" >&2; }
warn() { printf '%s%s%s\n' "$C_YELLOW" "$*" "$C_RESET" >&2; }
err()  { printf '%s%s%s\n' "$C_RED"   "$*" "$C_RESET" >&2; }
ok()   { printf '%s%s%s\n' "$C_GREEN" "$*" "$C_RESET" >&2; }

die() { err "fatal: $*"; exit 1; }

iso_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }
epoch_ms() { python3 -c 'import time; print(int(time.time()*1000))'; }

require_cmd() {
  for c in "$@"; do
    command -v "$c" >/dev/null 2>&1 || die "required command not on PATH: $c"
  done
}

# run_phase <version> <phase> <log_dir> <jsonl_path> <timeout_seconds> <cwd> -- <cmd...>
#
# Captures stdout+stderr to the per-phase log file, streams a prefixed copy to
# the terminal, records timing + exit status as a JSON line in <jsonl_path>.
# Returns the wrapped command's exit code (so callers can short-circuit).
run_phase() {
  local version="$1" phase="$2" log_dir="$3" jsonl="$4" timeout="$5" cwd="$6"
  shift 6
  [[ "$1" == "--" ]] || die "run_phase: missing -- separator"
  shift

  mkdir -p "$log_dir" "$(dirname "$jsonl")"
  local log_file="${log_dir}/${phase}.log"
  local prefix="[${version}][${phase}]"
  local start_iso end_iso t0 t1 ec status duration_ms
  start_iso="$(iso_now)"
  t0="$(epoch_ms)"

  info "${prefix} starting in ${cwd}"

  # macOS ships gtimeout via coreutils; fall back to no timeout if not present.
  local timeout_bin=""
  if command -v gtimeout >/dev/null 2>&1; then
    timeout_bin="gtimeout"
  elif command -v timeout >/dev/null 2>&1; then
    timeout_bin="timeout"
  fi

  # Run in a subshell with errexit disabled; capture exit code without aborting
  # the calling script (which uses set -e in some entry points).
  if [[ -n "$timeout_bin" ]]; then
    (
      set +e
      cd "$cwd" || exit 127
      "$timeout_bin" --foreground -k 30 "$timeout" "$@"
    ) > >(tee "$log_file" | sed -u "s|^|${prefix} |") 2>&1
  else
    (
      set +e
      cd "$cwd" || exit 127
      "$@"
    ) > >(tee "$log_file" | sed -u "s|^|${prefix} |") 2>&1
  fi
  ec=$?

  t1="$(epoch_ms)"
  end_iso="$(iso_now)"
  duration_ms=$((t1 - t0))

  if [[ $ec -eq 0 ]]; then
    status="pass"; ok "${prefix} pass (${duration_ms} ms)"
  elif [[ $ec -eq 124 || $ec -eq 137 ]]; then
    status="timeout"; err "${prefix} timeout after ${timeout}s"
  else
    status="fail"; err "${prefix} fail (exit ${ec})"
  fi

  # Single JSON line; jq -c assembles it safely.
  jq -cn \
    --arg version "$version" \
    --arg phase "$phase" \
    --arg status "$status" \
    --arg start "$start_iso" \
    --arg end "$end_iso" \
    --argjson duration_ms "$duration_ms" \
    --argjson exit_code "$ec" \
    --arg log "$log_file" \
    '{version:$version, phase:$phase, status:$status, start:$start, end:$end,
      duration_ms:$duration_ms, exit_code:$exit_code, log:$log}' \
    >> "$jsonl"

  return $ec
}

# record_skipped <version> <phase> <jsonl_path>
record_skipped() {
  local version="$1" phase="$2" jsonl="$3"
  jq -cn \
    --arg version "$version" \
    --arg phase "$phase" \
    '{version:$version, phase:$phase, status:"skipped",
      start:null, end:null, duration_ms:null, exit_code:null, log:null}' \
    >> "$jsonl"
}
