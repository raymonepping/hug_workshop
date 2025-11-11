#!/usr/bin/env bash
# setup_stacks.sh
# Clone/pull two stacks repos, fmt, validate, and init each.
# Usage: bash setup_stacks.sh [WORKDIR]
# Example: bash setup_stacks.sh ~/work/hug-stacks

# shellcheck disable=SC2034
VERSION="1.0.0"

set -euo pipefail

WORKDIR="${1:-$PWD/hug-stacks}"
REPOS=(
  "https://github.com/raymonepping/demo_stacks_infra.git"
  "https://github.com/raymonepping/demo_stacks_app.git"
)

# Optional: speed up provider downloads between runs
export TF_PLUGIN_CACHE_DIR="${TF_PLUGIN_CACHE_DIR:-$HOME/.terraform.d/plugin-cache}"
mkdir -p "$TF_PLUGIN_CACHE_DIR"

say() { printf "\n\033[1;36m==>\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33mWARN:\033[0m %s\n" "$*" >&2; }
fail() { printf "\033[1;31mERROR:\033[0m %s\n" "$*" >&2; exit 1; }

check_terraform() {
  if ! command -v terraform >/dev/null 2>&1; then
    fail "Terraform not found. Install Terraform >= 1.13.x and retry."
  fi

  local v
  v="$(terraform version | head -n1 | sed -E 's/^Terraform v([0-9.]+).*/\1/')"
  # crude but effective version check
  if [[ "${v%%.*}" -lt 1 ]] || [[ "${v%%.*}" -eq 1 && "${v#1.}" < 13 ]]; then
    warn "Detected Terraform v${v}. Stacks requires v1.13.x or newer."
  fi

  # Check stacks subcommand is available
  if ! terraform stacks -help >/dev/null 2>&1; then
    warn "The 'terraform stacks' command isn't available. Ensure you're on v1.13+."
  fi
}

clone_or_update() {
  local url="$1"
  local name
  name="$(basename -s .git "$url")"
  local dest="$WORKDIR/$name"

  if [[ -d "$dest/.git" ]]; then
    say "Updating repo: $name"
    git -C "$dest" fetch --prune
    git -C "$dest" checkout main 2>/dev/null || true
    git -C "$dest" pull --ff-only || warn "Non-fast-forward; resolve manually in $dest"
  else
    say "Cloning repo: $name"
    git clone "$url" "$dest"
  fi
}

fmt_validate_init() {
  local dir="$1"
  say "Terraform fmt/validate/init in: $dir"
  pushd "$dir" >/dev/null

  # Optional: enforce a TF version for workshop consistency if file exists
  if [[ -f .terraform-version ]]; then
    say "Found .terraform-version: $(cat .terraform-version)"
  fi

  terraform fmt -recursive

  # Validate stacks config first (fast fail on typos)
  terraform stacks validate

  # Initialize stacks (provider lock, etc.)
  terraform stacks init

  popd >/dev/null
}

main() {
  check_terraform
  say "Working directory: $WORKDIR"
  mkdir -p "$WORKDIR"

  for repo in "${REPOS[@]}"; do
    clone_or_update "$repo"
  done

  # Run fmt/validate/init for each repo
  for repo in "${REPOS[@]}"; do
    name="$(basename -s .git "$repo")"
    fmt_validate_init "$WORKDIR/$name"
  done

  say "All done. Next:"
  cat <<'EOF'

To run in HCP Terraform:
  1) Ensure your Agent is running and the Stacks point to these repos/branches.
  2) From each Stack's Deploy tab:
     - Plan "development" then Deploy.
     - Plan "production"  then Deploy.

Local quick checks on the Agent host (after deploy):
  docker network ls | grep stacks_net_
  docker volume ls  | grep stacks_vol_
  docker ps --format 'table {{.Names}}\t{{.Ports}}' | grep hug-nginx
  curl -I http://localhost:8080  # dev
  curl -I http://localhost:8081  # prod

EOF
}

main "$@"
