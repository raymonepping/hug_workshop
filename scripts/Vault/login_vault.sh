#!/usr/bin/env bash
set -euo pipefail

# login_vault.sh
# Usage:
#   ./login_vault.sh              # will try to auto-load a *.env if VAULT_* vars missing
#   ./login_vault.sh jorg.env     # explicitly load env file first
#   source jorg.env && ./login_vault.sh

ENV_FILE_ARG="${1:-}"

need_vars() {
  [[ -z "${VAULT_ADDR:-}" || -z "${VAULT_NAMESPACE:-}" || -z "${VAULT_USERNAME:-}" ]]
}

auto_load_env_file() {
  local file_arg="$1"

  # 1) If an env file was passed as argument, use that
  if [[ -n "$file_arg" ]]; then
    if [[ -f "$file_arg" ]]; then
      echo "📦 Loading environment from $file_arg"
      set -a
      # shellcheck disable=SC1090
      . "$file_arg"
      set +a
      return 0
    else
      echo "❌ Env file not found: $file_arg" >&2
      exit 1
    fi
  fi

  # 2) No argument: try to auto-detect a single *.env file
  mapfile -t env_files < <(ls *.env 2>/dev/null || true)

  if (( ${#env_files[@]} == 1 )); then
    echo "📦 Auto-loading environment from ${env_files[0]}"
    set -a
    # shellcheck disable=SC1090
    . "${env_files[0]}"
    set +a
    return 0
  elif (( ${#env_files[@]} > 1 )); then
    echo "❌ Multiple .env files detected, and VAULT_* variables are incomplete." >&2
    echo "   Found:" >&2
    for f in "${env_files[@]}"; do
      echo "     - $f" >&2
    done
    echo "   Please run one of:" >&2
    echo "     source <yourname>.env" >&2
    echo "     ./login_vault.sh <yourname>.env" >&2
    exit 1
  fi

  # 3) No .env files at all
  echo "❌ No .env file found and VAULT_* variables are incomplete." >&2
  echo "   Make sure you ran: source <yourname>.env" >&2
  echo "   Or call:           ./login_vault.sh <yourname>.env" >&2
  exit 1
}

# If required vars are missing, try to auto-load an env file (Option B)
if need_vars; then
  auto_load_env_file "$ENV_FILE_ARG"
fi

# Re-check after env load
if need_vars; then
  echo "❌ Missing required environment variables:"
  [[ -z "${VAULT_ADDR:-}"      ]] && echo "   - VAULT_ADDR"
  [[ -z "${VAULT_NAMESPACE:-}" ]] && echo "   - VAULT_NAMESPACE"
  [[ -z "${VAULT_USERNAME:-}"  ]] && echo "   - VAULT_USERNAME"
  echo "Tip: run:  source <yourname>.env"
  echo "     or:   ./login_vault.sh <yourname>.env"
  exit 1
fi

echo "🔐 Logging into Vault..."
echo "   VAULT_ADDR      = $VAULT_ADDR"
echo "   VAULT_NAMESPACE = $VAULT_NAMESPACE"
echo "   VAULT_USERNAME  = $VAULT_USERNAME"

vault login -method=userpass username="${VAULT_USERNAME}"

STATUS=$?

if (( STATUS == 0 )); then
  echo "✅ Logged into Vault successfully."

  # Bonus: gentle UX tip for students
  env_hint="${VAULT_USERNAME}.env"
  echo
  if [[ -f "$env_hint" ]]; then
    echo "💡 Next time, you can simply run:"
    echo "   source $env_hint && ./login_vault.sh"
  else
    echo "💡 Next time, remember to:"
    echo "   source <yourname>.env && ./login_vault.sh"
  fi
else
  echo "❌ Vault login failed (exit code: $STATUS)" >&2
fi

exit "$STATUS"
