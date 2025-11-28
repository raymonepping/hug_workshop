#!/usr/bin/env bash
set -euo pipefail

# tfc_rights_extract.sh
#
# Read-only helper to extract current organization_access rights
# for a TFC team from Terraform state as JSON.
#
# Usage:
#   ./scripts/tfc_rights_extract.sh --email raymon.epping@ibm.com
#   ./scripts/tfc_rights_extract.sh --address 'tfe_team.personal["raymon.epping@ibm.com"]'
#   ./scripts/tfc_rights_extract.sh --email raymon.epping@ibm.com --output rights_raymon.json
#
# Output JSON example:
# {
#   "resource": "tfe_team.personal[\"raymon.epping@ibm.com\"]",
#   "team_email": "raymon.epping@ibm.com",
#   "in_state": true,
#   "name": "team_raymon_epping",
#   "organization": "HUGS_NL",
#   "visibility": "secret",
#   "allow_member_token_management": true,
#   "organization_access": [
#     {
#       "read_workspaces": false,
#       ...
#     }
#   ]
# }

VERSION="1.2.0"

JT_MODE=false
TEAM_EMAIL=""
RESOURCE_ADDRESS=""
OUTPUT_FILE=""
OUTPUT_DIR="."
WORKDIR=""

usage() {
  cat <<EOF
tfc_rights_extract.sh v${VERSION}

Usage:
  $0 --email <email> [--output <file.json>] [--output-dir <dir>] [--workdir <dir>] [--jt]
  $0 --address <resource_address> [--output <file.json>] [--output-dir <dir>] [--workdir <dir>] [--jt]

Options:
  --email, -e        User email. Maps to tfe_team.personal["<email>"].
  --address, -a      Full Terraform resource address, for example:
                     'tfe_team.personal["raymon.epping@ibm.com"]'
  --output, -o       Output JSON file. Default:
                       rights_<email>.json or rights_<safe_address>.json
  --output-dir, -d   Directory where the JSON will be written.
                     Default: current directory.
  --workdir, -w      Terraform working directory.
                     Default: auto-detected from script location.
  --jt, --bring-sexy-back
                     Enable Justin Timberlake mode for root detection logs.
  --help, -h         Show this help and exit.
EOF
}

log() {
  if [[ "${JT_MODE}" == true ]]; then
    printf '%s\n' "$@" >&2
  fi
}

# --- Terraform Root Auto-Detection (JT Edition) ------------------------------
# "I am bringin' Terraform back"

auto_detect_workdir() {

  local start="$1"
  local dir="$start"

  # Nice newline before the first JT log, stderr only
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

# Arg parsing
while [[ $# -gt 0 ]]; do
  case "$1" in
    --email|-e)
      TEAM_EMAIL="${2:-}"
      shift 2
      ;;
    --address|-a)
      RESOURCE_ADDRESS="${2:-}"
      shift 2
      ;;
    --output|-o)
      OUTPUT_FILE="${2:-}"
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

if [[ -z "${RESOURCE_ADDRESS}" && -z "${TEAM_EMAIL}" ]]; then
  echo "Error: provide either --email or --address." >&2
  usage
  exit 1
fi

if [[ -z "${RESOURCE_ADDRESS}" && -n "${TEAM_EMAIL}" ]]; then
  RESOURCE_ADDRESS="tfe_team.personal[\"${TEAM_EMAIL}\"]"
fi

# Prepare output name if not overridden
if [[ -z "${OUTPUT_FILE}" ]]; then
  if [[ -n "${TEAM_EMAIL}" ]]; then
    SAFE_EMAIL="${TEAM_EMAIL//[^a-zA-Z0-9_]/_}"
    OUTPUT_FILE="rights_${SAFE_EMAIL}.json"
  else
    SAFE_ADDR="${RESOURCE_ADDRESS//[^a-zA-Z0-9_]/_}"
    OUTPUT_FILE="rights_${SAFE_ADDR}.json"
  fi
fi

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
OUTPUT_FILE="${OUTPUT_DIR}/${OUTPUT_FILE}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -z "${WORKDIR}" ]]; then
  # Start one level above scripts, where your main .tf and state live
  DEFAULT_WORKDIR="$(auto_detect_workdir "$(cd "$SCRIPT_DIR/.." && pwd)")"
  WORKDIR="${DEFAULT_WORKDIR}"
fi

WORKDIR="$(cd "$WORKDIR" && pwd)"

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
    --arg addr "${RESOURCE_ADDRESS}" \
    --arg email "${TEAM_EMAIL}" \
    '{
      resource: $addr,
      team_email: ($email | select(. != "")),
      in_state: false,
      organization_access: null
    }' > "${OUTPUT_FILE}"
  echo "❌ Resource not in state. Wrote ${OUTPUT_FILE}"
  exit 0
fi

echo "✅ Resource is in state. Reading full state as JSON..."

# Search the full module tree, not just root_module
terraform -chdir="${WORKDIR}" show -json \
  | jq --arg addr "${RESOURCE_ADDRESS}" --arg email "${TEAM_EMAIL}" '
    def all_resources(m):
      [
        ((m.resources // [])[]),
        ((m.child_modules // [])[] | all_resources(.))
      ]
      | flatten;

    .values.root_module as $root
    | (all_resources($root)
       | map(select(.address == $addr))
       | .[0]?
      ) as $res
    | if $res == null then
        empty
      else
        {
          resource: $res.address,
          team_email: ($email | select(. != "")),
          in_state: true,
          name: $res.values.name,
          organization: $res.values.organization,
          visibility: $res.values.visibility,
          allow_member_token_management: $res.values.allow_member_token_management,
          organization_access: $res.values.organization_access
        }
      end
  ' > "${OUTPUT_FILE}"

if [[ ! -s "${OUTPUT_FILE}" ]]; then
  # Fallback if not found in the JSON tree for some reason
  jq -n \
    --arg addr "${RESOURCE_ADDRESS}" \
    --arg email "${TEAM_EMAIL}" \
    '{
      resource: $addr,
      team_email: ($email | select(. != "")),
      in_state: true,
      organization_access: null
    }' > "${OUTPUT_FILE}"
  echo "⚠️ Resource is in state but not found in JSON tree. Wrote minimal info to ${OUTPUT_FILE}"
else
  echo "✅ Rights extracted to: ${OUTPUT_FILE}"
fi
