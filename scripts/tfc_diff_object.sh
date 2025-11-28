#!/usr/bin/env bash
set -euo pipefail

# tfc_diff_object.sh
#
# Detect drift for a given Terraform Cloud / HCP Terraform object by:
#   1) Mapping logical object + kind to a Terraform resource address
#   2) Running a targeted terraform plan
#   3) Emitting a JSON drift report (before/after + actions)
#
# Requirements:
#   - terraform
#   - jq

VERSION="1.3.0"

JT_MODE=false
OBJECT_NAME=""
RESOURCE_KIND=""       # e.g. tfe_team, tfe_team_access, tfe_agent_pool
RESOURCE_ADDRESS=""    # full address override
OUTPUT_BASENAME=""
OUTPUT_DIR="."
WORKDIR=""
FORMAT="json"

PLAN_FILES=()
KEEP_PLAN=false

usage() {
  cat <<EOF
tfc_diff_object.sh v${VERSION}

Usage:
  $0 --object <name> --kind <tfe_resource_type> [--output <basename>] [--output-dir <dir>] [--workdir <dir>] [--format json] [--keep-plan] [--jt]
  $0 --address <resource_address> [--output <basename>] [--output-dir <dir>] [--workdir <dir>] [--format json] [--keep-plan] [--jt]

Options:
  --object, -o        Logical object name (for example: team_raymon).
  --kind, -k          Terraform resource kind (for example: tfe_team, tfe_team_access, tfe_agent_pool).
                      This must match a supported resource type from:
                        https://registry.terraform.io/providers/hashicorp/tfe/latest/docs/resources
  --address, -a       Full Terraform resource address (for example: tfe_team.team_raymon).
                      If set, --object and --kind are not required.
  --output, -O        Output basename (without extension). Default:
                        - If --address is set: derived from address
                        - Else: "<kind>_<object>"
  --output-dir, -d    Directory where the JSON and plan files will be written.
                      Default: current directory.
  --workdir, -w       Terraform working directory.
                      Default: auto-detected from script location.
  --format, -f        Output format. Currently only "json" is supported. Default: json.
  --keep-plan         Do not delete generated .tfplan/.json files on exit.
  --jt, --bring-sexy-back
                      Enable Justin Timberlake mode for root detection logs.
  --help, -h          Show this help and exit.

Behavior:
  - Checks whether the resource address is in Terraform state.
  - If not in state:
      Writes JSON with "status": "not_in_state".
  - If in state and no drift:
      Writes JSON with "drift": false.
  - If drift exists:
      Writes JSON with:
        - resource address
        - actions (create, update, delete)
        - before and after attribute maps.
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
# "I am bringin' sexy back"

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
    --object|-o)
      OBJECT_NAME="${2:-}"
      shift 2
      ;;
    --kind|-k)
      RESOURCE_KIND="${2:-}"
      shift 2
      ;;
    --address|-a)
      RESOURCE_ADDRESS="${2:-}"
      shift 2
      ;;
    --output|-O)
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
    --format|-f)
      FORMAT="${2:-}"
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

# Validate basic combinations
if [[ -z "${RESOURCE_ADDRESS}" ]]; then
  if [[ -z "${OBJECT_NAME}" || -z "${RESOURCE_KIND}" ]]; then
    echo "Error: either --address OR (--object AND --kind) must be provided." >&2
    usage
    exit 1
  fi
  RESOURCE_ADDRESS="${RESOURCE_KIND}.${OBJECT_NAME}"
fi

case "${FORMAT}" in
  json)
    EXT="json"
    ;;
  *)
    echo "Error: unsupported format '${FORMAT}'. Only 'json' is supported right now." >&2
    exit 1
    ;;
esac

# Dependencies
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
  # Start one level above scripts, where your main .tf and state live
  DEFAULT_WORKDIR="$(auto_detect_workdir "$(cd "$SCRIPT_DIR/.." && pwd)")"
  WORKDIR="${DEFAULT_WORKDIR}"
fi

WORKDIR="$(cd "$WORKDIR" && pwd)"

# Derive output name
if [[ -z "${OUTPUT_BASENAME}" ]]; then
  if [[ -n "${OBJECT_NAME}" && -n "${RESOURCE_KIND}" ]]; then
    OUTPUT_BASENAME="${RESOURCE_KIND}_${OBJECT_NAME}"
  else
    SAFE_BASE="${RESOURCE_ADDRESS//[^a-zA-Z0-9_]/_}"
    OUTPUT_BASENAME="${SAFE_BASE}"
  fi
fi

OUTPUT_FILE="${OUTPUT_DIR}/drift_${OUTPUT_BASENAME}.${EXT}"

SAFE_PLAN_NAME="${RESOURCE_ADDRESS//[^a-zA-Z0-9_]/_}"
PLAN_FILE="${OUTPUT_DIR}/.plan_${SAFE_PLAN_NAME}.tfplan"
PLAN_JSON="${OUTPUT_DIR}/.plan_${SAFE_PLAN_NAME}.json"
PLAN_FILES+=("${PLAN_FILE}" "${PLAN_JSON}")

if [[ "${JT_MODE}" == true ]]; then
  echo "🎵 JT mode: \"I am bringin' Terraform back\""
  echo "🎧 Terraform workdir detected: ${WORKDIR}"
  echo ""
else
  echo "📁 Terraform dir:    ${WORKDIR}"
fi

echo "📁 Output dir:       ${OUTPUT_DIR}"
echo "🔍 Resource address: ${RESOURCE_ADDRESS}"
echo "📝 Output file:      ${OUTPUT_FILE}"
echo ""
echo "🔎 Checking if resource is in Terraform state..."

if ! terraform -chdir="${WORKDIR}" state show "${RESOURCE_ADDRESS}" >/dev/null 2>&1; then
  jq -n \
    --arg object "${OBJECT_NAME:-null}" \
    --arg resource "${RESOURCE_ADDRESS}" \
    '{
      object: ($object | select(. != "null")),
      resource: $resource,
      in_state: false,
      drift: null,
      status: "not_in_state"
    }' > "${OUTPUT_FILE}"

  echo "❌ Resource not in state. Wrote ${OUTPUT_FILE}"
  exit 0
fi

echo "✅ Resource is in state."
echo ""
echo "📦 Creating targeted plan for ${RESOURCE_ADDRESS}..."

status=0
terraform -chdir="${WORKDIR}" plan \
  -target="${RESOURCE_ADDRESS}" \
  -out="${PLAN_FILE}" \
  -detailed-exitcode \
  >/tmp/tfc_diff_object_plan.log 2>&1 || status=$?

if [[ "${status}" -eq 0 ]]; then
  jq -n \
    --arg object "${OBJECT_NAME:-null}" \
    --arg resource "${RESOURCE_ADDRESS}" \
    '{
      object: ($object | select(. != "null")),
      resource: $resource,
      in_state: true,
      drift: false,
      change: null
    }' > "${OUTPUT_FILE}"

  echo "✅ No drift detected. Wrote ${OUTPUT_FILE}"
  exit 0
fi

if [[ "${status}" -eq 2 ]]; then
  echo "⚠️  Drift detected. Converting plan to JSON..."
  terraform -chdir="${WORKDIR}" show -json "${PLAN_FILE}" > "${PLAN_JSON}"

  jq --arg addr "${RESOURCE_ADDRESS}" --arg object "${OBJECT_NAME:-null}" '
    {
      object: ($object | select(. != "null")),
      resource: $addr,
      in_state: true,
      drift: true,
      change: (
        (.resource_changes // [])
        | map(select(.address == $addr))
        | .[0]?
        | if . == null then null else {
            actions: .change.actions,
            before: .change.before,
            after:  .change.after
          } end
      )
    }
  ' "${PLAN_JSON}" > "${OUTPUT_FILE}"

  echo "📝 Drift report written to: ${OUTPUT_FILE}"
  exit 0
fi

echo "❌ terraform plan failed with status ${status}"
echo "   See /tmp/tfc_diff_object_plan.log for details."
exit "${status}"
