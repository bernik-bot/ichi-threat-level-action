#!/usr/bin/env bash
# Fetch the current ICHI index and expose it as GitHub Actions outputs.
# Portable to bash 3.2 (macOS runners). Requires curl + jq.
set -uo pipefail

API_URL="${ICHI_API_URL:-https://ichi.global/api/current-index}"
FAIL_ON="$(printf '%s' "${ICHI_FAIL_ON_BAND:-}" | tr '[:lower:]' '[:upper:]' | tr -d '[:space:]')"
MODE="$(printf '%s' "${ICHI_MODE:-warn}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
STRICT="$(printf '%s' "${ICHI_STRICT:-false}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
TIMEOUT="${ICHI_TIMEOUT:-15}"
SUMMARY_ON="$(printf '%s' "${ICHI_SUMMARY:-true}" | tr '[:upper:]' '[:lower:]')"
OUT="${GITHUB_OUTPUT:-/dev/null}"
SUMMARY="${GITHUB_STEP_SUMMARY:-/dev/null}"
LINK="https://ichi.global"
METHODOLOGY="https://ichi.global/methodology"

case "$TIMEOUT" in ''|*[!0-9]*) TIMEOUT=15 ;; esac
[ "$SUMMARY_ON" = "true" ] || SUMMARY=/dev/null

set_out() { printf '%s=%s\n' "$1" "$2" >> "$OUT"; }

# Band order, lowest to highest (see https://ichi.global/methodology).
band_rank() {
  case "$1" in
    NORMAL) echo 0 ;; GUARDED) echo 1 ;; ELEVATED) echo 2 ;;
    HIGH) echo 3 ;; CRITICAL) echo 4 ;; *) echo -1 ;;
  esac
}

degrade() {
  msg="$1"
  for k in score band evaluated_at rounded headline_state; do set_out "$k" ""; done
  set_out threshold_met false
  set_out available false
  {
    echo "### ICHI — Internet Cyber Health Index"
    echo ""
    echo "Index unavailable: ${msg}. See [ichi.global](${LINK})."
  } >> "$SUMMARY"
  if [ "$STRICT" = "true" ]; then
    echo "::error title=ICHI unavailable::${msg}"
    exit 1
  fi
  echo "::warning title=ICHI unavailable::${msg} (continuing; set strict: true to fail)"
  exit 0
}

case "$MODE" in warn|fail) ;; *)
  echo "::warning title=ICHI::Unknown mode '${MODE}', using 'warn'"; MODE=warn ;;
esac

if [ -n "$FAIL_ON" ] && [ "$(band_rank "$FAIL_ON")" -lt 0 ]; then
  echo "::warning title=ICHI::Ignoring invalid fail-on-band '${FAIL_ON}' (expected NORMAL, GUARDED, ELEVATED, HIGH or CRITICAL)"
  FAIL_ON=""
fi

command -v curl >/dev/null 2>&1 || degrade "curl not found on runner"
command -v jq >/dev/null 2>&1 || degrade "jq not found on runner"

body="$(curl -fsS --max-time "$TIMEOUT" --retry 2 --retry-delay 2 \
  -H 'Accept: application/json' -A 'ichi-threat-level-action/1' "$API_URL" 2>/dev/null)" \
  || degrade "could not fetch ${API_URL}"

printf '%s' "$body" | jq -e 'type == "object"' >/dev/null 2>&1 || degrade "response was not a JSON object"

j() { printf '%s' "$body" | jq -r "$1" 2>/dev/null; }

score="$(j '.current.score // .current.final_score // empty')"
band="$(j '.current.band // empty' | tr '[:lower:]' '[:upper:]')"
evaluated_at="$(j '.current.completed_at // .current.built_at // .current.epoch // empty')"
rounded="$(j '.current.rounded // empty')"
state="$(j '.headline_state // empty')"
impaired="$(j '((.impaired_sources // []) | length)')"
stale="$(j '((.stale_inputs // []) | length)')"

[ -n "$score" ] && [ -n "$band" ] || degrade "response missing current.score or current.band"

set_out score "$score"
set_out band "$band"
set_out evaluated_at "$evaluated_at"
set_out rounded "$rounded"
set_out headline_state "$state"
set_out available true

echo "ICHI: score=${score} band=${band} evaluated_at=${evaluated_at} state=${state:-unknown}"

threshold_met=false
if [ -n "$FAIL_ON" ]; then
  r="$(band_rank "$band")"
  t="$(band_rank "$FAIL_ON")"
  if [ "$r" -lt 0 ]; then
    echo "::warning title=ICHI::Unrecognised band '${band}'; threshold check skipped"
  elif [ "$r" -ge "$t" ]; then
    threshold_met=true
  fi
fi
set_out threshold_met "$threshold_met"

{
  echo "### ICHI — Internet Cyber Health Index"
  echo ""
  echo "| Score | Band | Evaluated at | State |"
  echo "|---|---|---|---|"
  echo "| **${score}** | **${band}** | ${evaluated_at:-n/a} | ${state:-n/a} |"
  echo ""
  if [ "${impaired:-0}" != "0" ] || [ "${stale:-0}" != "0" ]; then
    echo "Note: ${impaired:-0} impaired source(s), ${stale:-0} stale input(s) reported by ICHI."
    echo ""
  fi
  if [ -n "$FAIL_ON" ]; then
    echo "Threshold \`${FAIL_ON}\` (mode \`${MODE}\`): $([ "$threshold_met" = true ] && echo met || echo 'not met')."
    echo ""
  fi
  echo "Outside-in, internet-wide directional signal — not an organization-specific risk score. [ichi.global](${LINK}) · [methodology](${METHODOLOGY})"
} >> "$SUMMARY"

if [ "$threshold_met" = true ]; then
  msg="Ambient ICHI band ${band} (score ${score}) is at or above ${FAIL_ON}"
  if [ "$MODE" = "fail" ]; then
    echo "::error title=ICHI threshold::${msg}"
    exit 1
  fi
  echo "::warning title=ICHI threshold::${msg}"
fi
exit 0
