#!/usr/bin/env bash
set -euo pipefail

# tfc_drift.sh
#
# Umbrella helper for:
#   - tfc_rights_extract.sh
#   - tfc_diff_object.sh
#   - tfc_diff_live_object.sh
#
# Provides a single entry point to:
#   - inspect team rights from state
#   - diff config vs state
#   - diff live TFC vs state
#   - run all three as a "triage" flow
#
# Usage examples:
#   ./scripts/tfc_drift.sh rights --email raymon.epping@ibm.com
#   ./scripts/tfc_drift.sh diff-config --address 'tfe_team.personal["raymon.epping@ibm.com"]'
#   ./scripts/tfc_drift.sh diff-live --address 'tfe_team.personal["raymon.epping@ibm.com"]'
#   ./scripts/tfc_drift.sh triage --email raymon.epping@ibm.com
#
# Global flags:
#   --output-dir ./scripts/output
#   --jt / --bring-sexy-back

VERSION="1.0.1"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_OUTPUT_DIR="${SCRIPT_DIR}/output"

GLOBAL_OUTPUT_DIR="${DEFAULT_OUTPUT_DIR}"
JT_MODE=false

# Colors
BOLD=$'\e[1m'
DIM=$'\e[2m'
RED=$'\e[31m'
GREEN=$'\e[32m'
YELLOW=$'\e[33m'
BLUE=$'\e[34m'
RESET=$'\e[0m'

error() {
  echo "${RED}❌ $*${RESET}" >&2
}

info() {
  echo "${BLUE}ℹ️  $*${RESET}"
}

ok() {
  echo "${GREEN}✅ $*${RESET}"
}

warn() {
  echo "${YELLOW}⚠️  $*${RESET}"
}

require_script() {
  local s="$1"
  local path="${SCRIPT_DIR}/${s}"
  if [[ ! -x "$path" ]]; then
    if [[ -f "$path" ]]; then
      error "Script '${s}' exists but is not executable. Run: chmod +x ${path}"
    else
      error "Required script '${s}' not found in ${SCRIPT_DIR}"
    fi
    exit 1
  fi
}

usage() {
  cat <<EOF
${BOLD}Terraform Cloud Drift Toolkit${RESET} ${DIM}(v${VERSION})${RESET}

Wrapper around:
  - tfc_rights_extract.sh
  - tfc_diff_object.sh
  - tfc_diff_live_object.sh

${BOLD}Global usage${RESET}
  tfc_drift.sh [global flags] <command> [command flags]

${BOLD}Global flags${RESET}
  ${GREEN}--output-dir <dir>${RESET}   Directory for JSON and plan artifacts
                                      Default: ${BLUE}${DEFAULT_OUTPUT_DIR}${RESET}
  ${GREEN}--jt, --bring-sexy-back${RESET}
                            Enable JT mode where supported (fun logs)
  ${GREEN}-h, --help${RESET}         Show this help
  ${GREEN}-V, --version${RESET}      Show script version

${BOLD}Commands${RESET}

  ${GREEN}rights${RESET}
    Read team rights from Terraform state via tfc_rights_extract.sh.

    Flags:
      ${GREEN}--email <email>${RESET}
      ${GREEN}--address <resource_address>${RESET}
      ${GREEN}--output <file.json>${RESET}   (optional, passed through)
    Example:
      tfc_drift.sh rights --email raymon.epping@ibm.com

  ${GREEN}diff-config${RESET}
    Detect drift between Terraform configuration and state for a single resource
    using tfc_diff_object.sh.

    Flags:
      ${GREEN}--address <resource_address>${RESET}
      or:
      ${GREEN}--object <name> --kind <tfe_resource_type>${RESET}
    Example:
      tfc_drift.sh diff-config --address 'tfe_team.personal["raymon.epping@ibm.com"]'

  ${GREEN}diff-live${RESET}
    Detect drift between state and live TFC / HCP using tfc_diff_live_object.sh.

    Flags:
      ${GREEN}--address <resource_address>${RESET}
    Example:
      tfc_drift.sh diff-live --address 'tfe_team.personal["raymon.epping@ibm.com"]'

  ${GREEN}triage${RESET}
    Run a full drift triage for a team:
      1) rights from state
      2) diff config vs state
      3) diff live vs state

    Flags:
      ${GREEN}--email <email>${RESET}         (maps to tfe_team.personal["<email>"])
      or:
      ${GREEN}--address <resource_address>${RESET}

    Example:
      tfc_drift.sh triage --email raymon.epping@ibm.com

EOF
}

# ─ Global flag parsing (before command) ─────────────────────────

COMMAND=""
COMMAND_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -V|--version|version)
      echo "tfc_drift.sh v${VERSION}"
      exit 0
      ;;
    --output-dir)
      GLOBAL_OUTPUT_DIR="${2:-}"
      shift 2
      ;;
    --jt|--bring-sexy-back)
      JT_MODE=true
      shift
      ;;
    rights|diff-config|diff-live|triage)
      COMMAND="$1"
      shift
      COMMAND_ARGS=("$@")
      break
      ;;
    *)
      error "Unknown global flag or command: $1"
      echo
      usage
      exit 1
      ;;
  esac
done

if [[ -z "${COMMAND}" ]]; then
  error "No command provided."
  echo
  usage
  exit 1
fi

# Normalise and create output dir
mkdir -p "${GLOBAL_OUTPUT_DIR}"
GLOBAL_OUTPUT_DIR="$(cd "${GLOBAL_OUTPUT_DIR}" && pwd)"

info "Using output dir: ${GLOBAL_OUTPUT_DIR}"

# Helper to add JT flag when enabled
jt_args=()
if [[ "${JT_MODE}" == true ]]; then
  jt_args=(--jt)
fi

# ─ Command dispatch ─────────────────────────────────────────────

case "${COMMAND}" in
  rights)
    require_script "tfc_rights_extract.sh"

    echo
    echo "${BOLD}🔐 Rights from Terraform state${RESET}"
    "${SCRIPT_DIR}/tfc_rights_extract.sh" \
      --output-dir "${GLOBAL_OUTPUT_DIR}" \
      "${jt_args[@]}" \
      "${COMMAND_ARGS[@]}"
    ;;

  diff-config)
    require_script "tfc_diff_object.sh"

    echo
    echo "${BOLD}📘 Config vs state drift${RESET}"
    "${SCRIPT_DIR}/tfc_diff_object.sh" \
      --output-dir "${GLOBAL_OUTPUT_DIR}" \
      "${jt_args[@]}" \
      "${COMMAND_ARGS[@]}"
    ;;

  diff-live)
    require_script "tfc_diff_live_object.sh"

    echo
    echo "${BOLD}🌍 Live vs state drift${RESET}"
    "${SCRIPT_DIR}/tfc_diff_live_object.sh" \
      --output-dir "${GLOBAL_OUTPUT_DIR}" \
      "${jt_args[@]}" \
      "${COMMAND_ARGS[@]}"
    ;;

  triage)
    require_script "tfc_rights_extract.sh"
    require_script "tfc_diff_object.sh"
    require_script "tfc_diff_live_object.sh"

    # First: strip global-style flags from COMMAND_ARGS for triage parsing
    RAW_ARGS=("${COMMAND_ARGS[@]}")
    TRIAGE_ARGS=()
    i=0
    while [[ $i -lt ${#RAW_ARGS[@]} ]]; do
      arg="${RAW_ARGS[$i]}"
      next="${RAW_ARGS[$((i+1))]:-}"

      case "$arg" in
        --output-dir)
          # If someone passes --output-dir after the command, we skip it here.
          # Global output dir is controlled by the top-level parser.
          i=$((i+2))
          ;;
        --jt|--bring-sexy-back)
          # Treat JT flags here as global if they appeared after the command
          JT_MODE=true
          jt_args=(--jt)
          i=$((i+1))
          ;;
        *)
          TRIAGE_ARGS+=("$arg")
          i=$((i+1))
          ;;
      esac
    done

    TEAM_EMAIL=""
    RESOURCE_ADDRESS=""

    # Now parse ONLY triage-local flags
    i=0
    while [[ $i -lt ${#TRIAGE_ARGS[@]} ]]; do
      arg="${TRIAGE_ARGS[$i]}"
      case "$arg" in
        --email|-e)
          TEAM_EMAIL="${TRIAGE_ARGS[$((i+1))]:-}"
          i=$((i+2))
          ;;
        --address|-a)
          RESOURCE_ADDRESS="${TRIAGE_ARGS[$((i+1))]:-}"
          i=$((i+2))
          ;;
        *)
          error "Unknown triage flag: ${arg}"
          echo "   Supported: --email, --address" >&2
          exit 1
          ;;
      esac
    done

    if [[ -z "${TEAM_EMAIL}" && -z "${RESOURCE_ADDRESS}" ]]; then
      error "triage requires either --email or --address."
      echo "   Example: tfc_drift.sh triage --email raymon.epping@ibm.com" >&2
      exit 1
    fi

    if [[ -z "${RESOURCE_ADDRESS}" && -n "${TEAM_EMAIL}" ]]; then
      RESOURCE_ADDRESS="tfe_team.personal[\"${TEAM_EMAIL}\"]"
    fi

    # Derive filenames for summary
    if [[ -n "${TEAM_EMAIL}" ]]; then
      SAFE_EMAIL="${TEAM_EMAIL//[^a-zA-Z0-9_]/_}"
      RIGHTS_FILE="${GLOBAL_OUTPUT_DIR}/rights_${SAFE_EMAIL}.json"
    else
      SAFE_EMAIL=""
      RIGHTS_FILE=""
    fi

    SAFE_ADDR="${RESOURCE_ADDRESS//[^a-zA-Z0-9_]/_}"
    CONFIG_FILE="${GLOBAL_OUTPUT_DIR}/drift_${SAFE_ADDR}.json"
    LIVE_FILE="${GLOBAL_OUTPUT_DIR}/live_diff_${SAFE_ADDR}.json"

    echo
    echo "${BOLD}🧪 Triage for${RESET} ${BLUE}${RESOURCE_ADDRESS}${RESET}"
    [[ -n "${TEAM_EMAIL}" ]] && echo "   Team email: ${TEAM_EMAIL}"

    echo
    echo "${YELLOW}▶ [1/3] Rights from Terraform state${RESET}"
    if [[ -n "${TEAM_EMAIL}" ]]; then
      "${SCRIPT_DIR}/tfc_rights_extract.sh" \
        --email "${TEAM_EMAIL}" \
        --output-dir "${GLOBAL_OUTPUT_DIR}" \
        "${jt_args[@]}"
    else
      "${SCRIPT_DIR}/tfc_rights_extract.sh" \
        --address "${RESOURCE_ADDRESS}" \
        --output-dir "${GLOBAL_OUTPUT_DIR}" \
        "${jt_args[@]}"
    fi

    echo
    echo "${YELLOW}▶ [2/3] Config vs state drift${RESET}"
    "${SCRIPT_DIR}/tfc_diff_object.sh" \
      --address "${RESOURCE_ADDRESS}" \
      --output-dir "${GLOBAL_OUTPUT_DIR}" \
      "${jt_args[@]}"

    echo
    echo "${YELLOW}▶ [3/3] Live vs state drift${RESET}"
    "${SCRIPT_DIR}/tfc_diff_live_object.sh" \
      --address "${RESOURCE_ADDRESS}" \
      --output-dir "${GLOBAL_OUTPUT_DIR}" \
      "${jt_args[@]}"

    echo
    ok "Triage complete."

    echo
    echo "${BOLD}📁 Artifacts${RESET}"
    [[ -n "${RIGHTS_FILE}" ]] && echo "  • Rights:        ${RIGHTS_FILE}"
    echo "  • Config drift:  ${CONFIG_FILE}"
    echo "  • Live drift:    ${LIVE_FILE}"
    ;;

  *)
    error "Unknown command: ${COMMAND}"
    echo
    usage
    exit 1
    ;;
esac
# End of tfc_drift.sh
