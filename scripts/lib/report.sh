# shellcheck shell=bash
# Reporting: summary.json and summary.txt from per-version phases.jsonl files.

# write_summary <run_dir>
#
# Expects:
#   <run_dir>/<version>/phases.jsonl       (one JSON line per phase)
#   <run_dir>/<version>/junit.xml          (optional, written by ctest)
#
# Produces:
#   <run_dir>/summary.json
#   <run_dir>/summary.txt
#
# Prints summary.txt to stdout.
# Sets MATRIX_OVERALL_STATUS to "pass" or "fail" via a sidecar file
# (<run_dir>/.overall_status) so callers can read it portably.
write_summary() {
  local run_dir="$1"
  local started_iso="$2"
  local fw_kind="$3"      # local|tag|sibling
  local fw_value="$4"     # path or tag string
  local finished_iso
  finished_iso="$(iso_now)"

  local versions_json="["
  local sep=""
  local overall="pass"

  while IFS= read -r vdir; do
    local v jsonl
    v="$(basename "$vdir")"
    jsonl="$vdir/phases.jsonl"
    [[ -f "$jsonl" ]] || continue

    local phases_arr
    phases_arr="$(jq -s '.' "$jsonl")"

    # A version is `pass` when no phase failed or timed out. `skipped` is
    # benign — it's emitted by lazy generate (app already present) and by
    # short-circuit on an earlier failure (which itself triggers `fail` via
    # the any-fail clause above). Either way: no fail/timeout, the run is pass.
    local v_status
    v_status="$(jq -r 'if any(.status == "fail" or .status == "timeout") then "fail" else "pass" end' <<<"$phases_arr")"
    [[ "$v_status" == "fail" ]] && overall="fail"

    local test_summary='null'
    if [[ -f "$vdir/junit.xml" ]]; then
      test_summary="$(_parse_junit "$vdir/junit.xml")"
    fi

    versions_json+="${sep}$(jq -cn \
      --arg rn "$v" \
      --arg status "$v_status" \
      --argjson phases "$phases_arr" \
      --argjson test_summary "$test_summary" \
      '{rn:$rn, status:$status, phases:$phases, test_summary:$test_summary}')"
    sep=","
  done < <(find "$run_dir" -mindepth 1 -maxdepth 1 -type d | sort)

  versions_json+="]"

  jq -n \
    --arg run_id "$(basename "$run_dir")" \
    --arg started "$started_iso" \
    --arg finished "$finished_iso" \
    --arg overall "$overall" \
    --arg fw_kind "$fw_kind" \
    --arg fw_value "$fw_value" \
    --argjson versions "$versions_json" \
    '{run_id:$run_id, started:$started, finished:$finished, overall:$overall,
      framework_source:{kind:$fw_kind, value:$fw_value}, versions:$versions}' \
    > "$run_dir/summary.json"

  _render_table "$run_dir/summary.json" > "$run_dir/summary.txt"
  cat "$run_dir/summary.txt"
  echo "$overall" > "$run_dir/.overall_status"
}

_parse_junit() {
  # ctest --output-junit emits a single <testsuite> with attributes
  # tests= failures= errors= disabled= skipped=. Parse with sed.
  local f="$1"
  local total failed errors
  total="$(grep -oE 'tests="[0-9]+"' "$f" | head -1 | grep -oE '[0-9]+' || echo 0)"
  failed="$(grep -oE 'failures="[0-9]+"' "$f" | head -1 | grep -oE '[0-9]+' || echo 0)"
  errors="$(grep -oE 'errors="[0-9]+"' "$f" | head -1 | grep -oE '[0-9]+' || echo 0)"
  local bad=$((failed + errors))
  local passed=$((total - bad))
  jq -cn \
    --argjson total "$total" \
    --argjson passed "$passed" \
    --argjson failed "$bad" \
    '{total:$total, passed:$passed, failed:$failed}'
}

_render_table() {
  local summary="$1"
  local phase_order=(generate npm-install pod-install codegen-check cmake-configure cmake-build ctest)

  printf 'TurboModuleTestingMatrix — run %s\n' "$(jq -r .run_id "$summary")"
  printf 'started:  %s\n' "$(jq -r .started "$summary")"
  printf 'finished: %s\n' "$(jq -r .finished "$summary")"
  printf 'source:   %s = %s\n' \
    "$(jq -r .framework_source.kind "$summary")" \
    "$(jq -r .framework_source.value "$summary")"
  printf 'overall:  %s\n\n' "$(jq -r .overall "$summary" | tr a-z A-Z)"

  printf '%-10s' 'RN'
  for p in "${phase_order[@]}"; do printf ' %-15s' "$p"; done
  printf ' %-6s %s\n' 'tests' 'result'

  local n
  n="$(jq '.versions | length' "$summary")"
  for ((i = 0; i < n; i++)); do
    local rn status tests
    rn="$(jq -r ".versions[$i].rn" "$summary")"
    status="$(jq -r ".versions[$i].status" "$summary" | tr a-z A-Z)"
    tests="$(jq -r ".versions[$i].test_summary | if . then \"\(.passed)/\(.total)\" else \"-\" end" "$summary")"
    printf '%-10s' "$rn"
    for p in "${phase_order[@]}"; do
      local s
      s="$(jq -r --arg p "$p" ".versions[$i].phases[] | select(.phase == \$p) | .status // \"-\"" "$summary")"
      [[ -z "$s" ]] && s="-"
      printf ' %-15s' "$s"
    done
    printf ' %-6s %s\n' "$tests" "$status"
  done
}
