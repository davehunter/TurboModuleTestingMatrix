#!/usr/bin/env bash
#
# run-from.sh — discover every stable RN patch from <start-version> onward
# and run the matrix against all of them.
#
# Usage:
#   scripts/run-from.sh <start-version> [--dry-run]
#
#   start-version     e.g. "0.83" (treated as 0.83.0 floor) or "0.83.4"
#   --dry-run         print the discovered list + synthesized JSON, do not
#                     invoke the matrix
#
# LOCAL-ONLY STRESS TOOL. NOT USED BY CI.
#
# CI runs the curated `versions.json` on every PR for fast feedback. This
# script is for periodic, deliberate audits — "are there patch-level
# regressions hiding between the versions we pin?", "is our curated list
# precise enough?". A full sweep is hours of wall-clock.
#
# When this surfaces a failure at a patch we don't currently pin, the
# response is to refine the curated `versions.json` (and/or the framework
# under TurboModuleTesting) — not to add this script to CI. See
# docs/ADDING_VERSIONS.md ("Auditing patch-level coverage").
#
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
export MATRIX_ROOT="$(cd -- "$SCRIPT_DIR/.." &>/dev/null && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=scripts/lib/versions.sh
source "$SCRIPT_DIR/lib/versions.sh"

require_cmd jq npm

usage() {
  cat >&2 <<EOF
usage: scripts/run-from.sh <start-version> [--dry-run]

  start-version    e.g. "0.83" (treated as 0.83.0 floor) or "0.83.4"
  --dry-run        print the discovered list + synthesized JSON, do not
                   invoke the matrix

This is a LOCAL-ONLY stress audit. It is not used by CI.
EOF
  exit 2
}

# ---------- args ----------
DRY_RUN=0
START=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage ;;
    --) shift; break ;;
    -*) err "unknown flag: $1"; usage ;;
    *)
      if [[ -z "$START" ]]; then
        START="$1"; shift
      else
        err "unexpected positional arg: $1"; usage
      fi
      ;;
  esac
done
[[ -n "$START" ]] || usage

# ---------- validate + normalize start version ----------
# Accept "0.80" → 0.80.0, or "0.80.3" → 0.80.3. Reject anything else.
if [[ "$START" =~ ^([0-9]+)\.([0-9]+)$ ]]; then
  START_MAJOR="${BASH_REMATCH[1]}"
  START_MINOR="${BASH_REMATCH[2]}"
  START_PATCH=0
elif [[ "$START" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  START_MAJOR="${BASH_REMATCH[1]}"
  START_MINOR="${BASH_REMATCH[2]}"
  START_PATCH="${BASH_REMATCH[3]}"
else
  die "invalid start version '$START' — must be N.N or N.N.N"
fi

# ---------- banner ----------
warn "═══════════════════════════════════════════════════════════════"
warn "run-from.sh — LOCAL stress audit. NOT used by CI."
warn ""
warn "Failures discovered here flow back into the curated versions.json"
warn "and/or framework, not into the CI workflow. See"
warn "docs/ADDING_VERSIONS.md ('Auditing patch-level coverage')."
warn "═══════════════════════════════════════════════════════════════"

info "discovering stable RN versions >= ${START_MAJOR}.${START_MINOR}.${START_PATCH}"

# ---------- discovery ----------
# npm view returns a JSON array of every published version. Filter to plain
# N.N.N stable semvers and keep only those >= the start.
#
# The semver comparison is done in jq by splitting on "." and comparing
# each component as a number. (Lexicographic compare would order "0.10" <
# "0.9", which is wrong.)
DISCOVERED_JSON="$(npm view react-native versions --json 2>/dev/null)"
[[ -n "$DISCOVERED_JSON" ]] || die "npm view returned nothing — network issue?"

DISCOVERED=()
while IFS= read -r v; do
  [[ -n "$v" ]] && DISCOVERED+=("$v")
done < <(jq -r \
  --argjson maj "$START_MAJOR" \
  --argjson min "$START_MINOR" \
  --argjson pat "$START_PATCH" \
  '
    .[]
    | select(test("^[0-9]+\\.[0-9]+\\.[0-9]+$"))
    | . as $v
    | ($v | split(".") | map(tonumber)) as $p
    # Exclude the published-but-not-real bridgehead version (1000.0.0)
    # and any future 1.x — RN has been 0.x for years and the matrix
    # has no opinion on a hypothetical 1.0.
    | select($p[0] == 0)
    | select(
        ($p[1] > $min)
        or ($p[1] == $min and $p[2] >= $pat)
      )
    | $v
  ' <<<"$DISCOVERED_JSON" \
  | sort -V)

COUNT=${#DISCOVERED[@]}
[[ $COUNT -gt 0 ]] || die "no stable RN versions found >= ${START_MAJOR}.${START_MINOR}.${START_PATCH}"

# ---------- preview ----------
info "found $COUNT stable RN versions:"
if [[ $COUNT -le 12 ]]; then
  for v in "${DISCOVERED[@]}"; do printf '  %s\n' "$v" >&2; done
else
  for v in "${DISCOVERED[@]:0:6}"; do printf '  %s\n' "$v" >&2; done
  printf '  ... (%d more) ...\n' "$((COUNT - 12))" >&2
  for v in "${DISCOVERED[@]: -6}"; do printf '  %s\n' "$v" >&2; done
fi
# Rough estimate: ~6 min per cold version (npx init + npm + bundle + pod + cmake + build + ctest).
# Already-generated versions take ~30s each. Assume worst case (cold).
EST_MIN=$((COUNT * 6))
info ""
info "estimated wall-clock: ~${EST_MIN} min cold-cache (less if many versions already in _generated/)"
info ""

# ---------- synthesize merged versions file ----------
# Pull entries from the real versions.json for any version that's already
# curated; default everything else to safe-modern values.
REAL_VERSIONS="${MATRIX_ROOT}/versions.json"

# Build a JSON array of the discovered versions for jq to iterate.
DISCOVERED_ARRAY="$(printf '%s\n' "${DISCOVERED[@]}" | jq -R . | jq -s .)"

SYNTHESIZED="$(jq -n \
  --argjson real "$(jq '.versions' "$REAL_VERSIONS")" \
  --argjson wanted "$DISCOVERED_ARRAY" \
  '
    # Map of curated entries by rn.
    ($real | map({(.rn): .}) | add // {}) as $curated
    | {
        versions:
          ( $wanted
            | map(
                . as $rn
                | $curated[$rn] //
                  {
                    rn: $rn,
                    cli: "@react-native-community/cli@latest",
                    cliInitFlavor: "community",
                    node: ">=20",
                    ruby: "3.2",
                    notes: "discovered by run-from.sh"
                  }
              )
          )
      }
  ')"

# ---------- dry-run exit ----------
if [[ $DRY_RUN -eq 1 ]]; then
  info "dry-run: synthesized versions file would be:"
  jq -C . <<<"$SYNTHESIZED" >&2 || jq . <<<"$SYNTHESIZED" >&2
  ok "dry-run complete — no matrix run dispatched"
  exit 0
fi

# ---------- write synthesized file under results/<run-id>/ ----------
SHORT_SHA=""
if command -v git >/dev/null 2>&1 && git -C "$MATRIX_ROOT" rev-parse --short HEAD >/dev/null 2>&1; then
  SHORT_SHA="-$(git -C "$MATRIX_ROOT" rev-parse --short HEAD)"
fi
RUN_ID="${MATRIX_RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)${SHORT_SHA}}"
RUN_DIR="${MATRIX_ROOT}/results/${RUN_ID}"
mkdir -p "$RUN_DIR"
SYNTH_PATH="${RUN_DIR}/versions.discovered.json"
printf '%s\n' "$SYNTHESIZED" > "$SYNTH_PATH"
info "wrote synthesized versions file: $SYNTH_PATH"
info ""

# ---------- dispatch ----------
# Re-export MATRIX_RUN_ID so run-matrix.sh lands in the same results dir
# we just created (otherwise it'd generate its own).
export MATRIX_VERSIONS_FILE="$SYNTH_PATH"
export MATRIX_RUN_ID="$RUN_ID"

info "dispatching to scripts/run-matrix.sh with MATRIX_VERSIONS_FILE set"
exec "$SCRIPT_DIR/run-matrix.sh"
