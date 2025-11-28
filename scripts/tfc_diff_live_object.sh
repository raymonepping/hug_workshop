#!/usr/bin/env bash
set -euo pipefail

# tfc_diff_live_object.sh
#
# Compare local Terraform STATE with live TFC / HCP Terraform
# for a single resource using `terraform plan -refresh-only`.
#
# This answers:
#   "Has the remote object drifted away from my local state,
#    and what are the before/after values?"
#
# Usage:
#   ./scripts/tfc_diff_live_object.sh --address 'tfe_team.personal["raymon.epping@ibm.com"]'
#   ./scripts/tfc_diff_live_object.sh --address 'tfe_team.personal["raymon.epping@ibm.com"]' --output personal_live_diff
#
# Output JSON example:
# {
#   "resource": "tfe_team.personal[\"raymon.epping@ibm.com\"]",
#   "in_state": true,
#   "drift": true,
#   "change": {
#     "before": { ... values from local state ... },
#     "after":  { ... values from live TFC ... }
#   }
# }

VERSION="1.2.0"

JT_MODE=false
RESOURCE_ADDRESS=""
OUTPUT_BASENAME=""
OUTPUT_DIR="."
WORKDIR=""
PLAN_FILES=()
KEEP_PLAN=false

usage() {
  cat <<EOF
tfc_diff_live_object.sh v${VERSION}

Usage:
  $0 --address <resource_address> [--output <basename>] [--output-dir <dir>] [--workdir <dir>] [--keep-plan] [--jt]

Options:
  --address, -a       Full Terraform resource address, for example:
                        'tfe_team.personal["raymon.epping@ibm.com"]'
  --output, -o        Output basename (without extension).
                      Default: derived from address (safe characters only).
  --output-dir, -d    Directory where the JSON and plan files will be written.
                      Default: current directory.
  --workdir, -w       Terraform working directory.
                      Default: auto-detected from script location.
  --keep-plan         Do not delete generated .tfplan/.json plan files on exit.
  --jt, --bring-sexy-back
                      Enable Justin Timberlake mode for root detection logs.
  --help, -h          Show this help and exit.

Behavior:
  - Verifies the resource exists in terraform state.
  - Runs: terraform plan -refresh-only -target=<resource_address>
  - If no drift:
      {
        "resource": "...",
        "in_state": true,
        "drift": false,
        "change": null
      }
  - If drift:
      {
        "resource": "...",
        "in_state": true,
        "drift": true,
        "change": {
          "before": { ... state values ... },
          "after":  { ... live values ... }
        }
      }
EOF
}

cleanup_plans() {
  if [[ "${KEEP_PLAN}" == "true" ]]; then
    return
  fi

  for f in "${PLAN_FILES[@]}"; do
    [[ -f "$f" ]] && rm -f "$f"
  done
}

trap cleanup_plans EXIT

log() {
  if [[ "${JT_MODE}" == true ]]; then
    printf '%s\n' "$@" >&2
  fi
}

# --- Terraform Root Auto-Detection (JT Edition) ------------------------------
# 🎵 "I'm bringin' sexy back..." 🎵

auto_detect_workdir() {

  local start="$1"
  local dir="$start"

  # Optional: pretty newline before the first JT log, on stderr only
  [[ "$JT_MODE" == true ]] && log ""

  while [[ "$dir" != "/" ]]; do

    log "🎤 Check: Do we have any *.tf? (Uh-huh)"
    if compgen -G "$dir"/*.tf >/dev/null 2>&1; then
      echo "$dir"
      return 0
    fi

    log "🎤 Check: Is the state lying around? (Yeah)"
    if [[ -f "$dir/terraform.tfstate" ]]; then
      echo "$dir"
      return 0
    fi

    log "🎤 Check: Has .terraform locked in the groove? (Come on)"
    if [[ -d "$dir/.terraform" ]]; then
      echo "$dir"
      return 0
    fi

    log "🕺 Move up the directory tree like sliding onto the dance floor"
    dir="$(cd "$dir/.." && pwd)"
  done

  log "fallback: where the beat started"
  echo "$start"
}

# Argument parsing
while [[ $# -gt 0 ]]; do
  case "$1" in
    --address|-a)
      RESOURCE_ADDRESS="${2:-}"
      shift 2
      ;;
    --output|-o)
      OUTPUT_BASENAME="${2:-}"
      shift 2
      ;;
    --output-dir|-d)
      OUTPUT_DIR="${2:-}"
      shift 2
      ;;
    --workdir|-w)
      WORKDIR="${2:-}"
      shift 2
      ;;
    --keep-plan)
      KEEP_PLAN=true
      shift
      ;;
    --jt|--bring-sexy-back)
      JT_MODE=true
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "${RESOURCE_ADDRESS}" ]]; then
  echo "Error: --address is required." >&2
  usage
  exit 1
fi

if ! command -v terraform >/dev/null 2>&1; then
  echo "Error: terraform is required on PATH." >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required on PATH." >&2
  exit 1
fi

# Normalise dirs
mkdir -p "${OUTPUT_DIR}"
OUTPUT_DIR="$(cd "${OUTPUT_DIR}" && pwd)"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -z "${WORKDIR}" ]]; then
  # Start one level above scripts/, where your main .tf and state live
  DEFAULT_WORKDIR="$(auto_detect_workdir "$(cd "$SCRIPT_DIR/.." && pwd)")"
  WORKDIR="${DEFAULT_WORKDIR}"
fi

WORKDIR="$(cd "$WORKDIR" && pwd)"

if [[ -z "${OUTPUT_BASENAME}" ]]; then
  SAFE_BASE="${RESOURCE_ADDRESS//[^a-zA-Z0-9_]/_}"
  OUTPUT_BASENAME="${SAFE_BASE}"
fi

OUTPUT_FILE="${OUTPUT_DIR}/live_diff_${OUTPUT_BASENAME}.json"
SAFE_PLAN_NAME="${RESOURCE_ADDRESS//[^a-zA-Z0-9_]/_}"

PLAN_FILE="${OUTPUT_DIR}/.plan_refresh_${SAFE_PLAN_NAME}.tfplan"
PLAN_JSON="${OUTPUT_DIR}/.plan_refresh_${SAFE_PLAN_NAME}.json"
PLAN_FILES+=("${PLAN_FILE}" "${PLAN_JSON}")

if [[ "${JT_MODE}" == true ]]; then
  echo "🎵 JT mode: \"I'm bringin' Terraform back\""
  echo "🎧 Terraform workdir detected: ${WORKDIR}"
  echo ""
else
  echo "📁 Terraform dir:    ${WORKDIR}"
fi

echo "📁 Output dir:       ${OUTPUT_DIR}"
echo "🔍 Resource address: ${RESOURCE_ADDRESS}"
echo "📝 Output file:      ${OUTPUT_FILE}"

echo ""
echo "🔎 Checking if resource exists in Terraform state..."
if ! terraform -chdir="${WORKDIR}" state show "${RESOURCE_ADDRESS}" >/dev/null 2>&1; then
  jq -n \
    --arg resource "${RESOURCE_ADDRESS}" \
    '{
      resource: $resource,
      in_state: false,
      drift: null,
      change: null,
      status: "not_in_state"
    }' > "${OUTPUT_FILE}"

  echo "❌ Resource not in state. Wrote ${OUTPUT_FILE}"
  exit 0
fi

echo "✅ Resource is in state."
echo ""
echo "📦 Creating refresh-only plan for ${RESOURCE_ADDRESS}..."

status=0
terraform -chdir="${WORKDIR}" plan \
  -refresh-only \
  -target="${RESOURCE_ADDRESS}" \
  -out="${PLAN_FILE}" \
  -detailed-exitcode \
  >/tmp/tfc_diff_live_object_plan.log 2>&1 || status=$?

if [[ "${status}" -eq 0 ]]; then
  jq -n \
    --arg resource "${RESOURCE_ADDRESS}" \
    '{
      resource: $resource,
      in_state: true,
      drift: false,
      change: null
    }' > "${OUTPUT_FILE}"

  echo "✅ No live drift detected. Wrote ${OUTPUT_FILE}"
  exit 0
fi

if [[ "${status}" -ne 2 ]]; then
  echo "❌ terraform plan -refresh-only failed with status ${status}"
  echo "   See /tmp/tfc_diff_live_object_plan.log for details."
  exit "${status}"
fi

echo "⚠️  Live drift detected. Converting plan to JSON..."
terraform -chdir="${WORKDIR}" show -json "${PLAN_FILE}" > "${PLAN_JSON}"

# We walk all modules recursively so we do not care if the resource
# lives directly in root_module or in child modules.
jq --arg addr "${RESOURCE_ADDRESS}" '
  def all_resources(m):
    [
      ((m.resources // [])[]),
      ((m.child_modules // [])[] | all_resources(.))
    ]
    | flatten;

  . as $root
  | ( $root.prior_state.values
      | all_resources(.root_module)
      | map(select(.address == $addr))
      | .[0]? ) as $before_res
  | ( $root.planned_values
      | all_resources(.root_module)
      | map(select(.address == $addr))
      | .[0]? ) as $after_res
  | if $before_res == null and $after_res == null then
      {
        resource: $addr,
        in_state: true,
        drift: true,
        change: null,
        note: "resource not found in prior_state/planned_values for this address; inspect plan JSON manually"
      }
    else
      {
        resource: $addr,
        in_state: true,
        drift: true,
        change: {
          before: ($before_res.values // null),
          after:  ($after_res.values // null)
        }
      }
    end
' "${PLAN_JSON}" > "${OUTPUT_FILE}"

echo "📝 Live drift report written to: ${OUTPUT_FILE}"
echo "  - 'before' = values from local state"
echo "  - 'after'  = values from live TFC / HCP"
