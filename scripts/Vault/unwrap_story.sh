#!/usr/bin/env bash
set -euo pipefail

# unwrap_story.sh
#
# Usage:
#   ./unwrap_story.sh <wrapped_token>
#   WRAPPED_TOKEN=<wrapped_token> ./unwrap_story.sh
#   echo <wrapped_token> | ./unwrap_story.sh
#
# Requires: vault
# Optional: jq (for pretty output)

usage() {
  cat <<EOF
Usage:
  $0 <wrapped_token>
  WRAPPED_TOKEN=<wrapped_token> $0
  echo <wrapped_token> | $0

The script will try, in order:
  1) First argument
  2) WRAPPED_TOKEN environment variable
  3) STDIN (if piped)

It uses "vault unwrap -format=json" and, if available, "jq" to render a
nice "story reveal" view of the unwrapped KV secret.

If the payload does not look like a KV v2 story (no .data.data.attendee/email/quote),
the script will just pretty-print the full JSON.
EOF
}

# Help flag early exit
if [[ "${1-}" == "-h" || "${1-}" == "--help" ]]; then
  usage
  exit 0
fi

###########################################################
# 1) Resolve the wrapped token from arg / env / stdin
###########################################################

TOKEN="${1-}"

# Fall back to WRAPPED_TOKEN env
if [[ -z "${TOKEN}" && "${WRAPPED_TOKEN-}" != "" ]]; then
  TOKEN="${WRAPPED_TOKEN}"
fi

# Fall back to stdin if still empty and stdin is not a TTY
if [[ -z "${TOKEN}" && ! -t 0 ]]; then
  read -r TOKEN || true
fi

# Trim whitespace just in case
TOKEN="${TOKEN#"${TOKEN%%[![:space:]]*}"}"
TOKEN="${TOKEN%"${TOKEN##*[![:space:]]}"}"

if [[ -z "${TOKEN}" ]]; then
  echo "❌ No wrapped token provided." >&2
  usage
  exit 1
fi

###########################################################
# 2) Basic tooling checks
###########################################################

if ! command -v vault >/dev/null 2>&1; then
  echo "❌ 'vault' CLI not found in PATH." >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "⚠️  'jq' not found, showing raw unwrap output:" >&2
  vault unwrap "${TOKEN}"
  exit $?
fi

###########################################################
# 3) Perform unwrap, defensively
###########################################################

set +e
JSON_OUTPUT="$(vault unwrap -format=json "${TOKEN}" 2>&1)"
STATUS=$?
set -e

if (( STATUS != 0 )); then
  if echo "${JSON_OUTPUT}" | grep -qi "wrapping token is not valid"; then
    echo "❌ Wrapping token is expired, not valid, or does not exist." >&2
    echo "ℹ️  You can request or generate a new wrapped token." >&2

    # interactive prompt
    read -r -p "🔄 Do you want to issue a new wrapped token now? (y/n): " ANSWER

    case "$ANSWER" in
      y|Y)
        echo "➡️  Issuing new wrapped token..."
        echo "   VAULT_NAMESPACE=${VAULT_NAMESPACE:-<unset>}"
        echo ""

        # Execute the wrap request
        set +e
        NEW_WRAP_JSON="$(vault kv get -wrap-ttl=60m -format=json secret/story 2>&1)"
        NEW_STATUS=$?
        set -e

        if (( NEW_STATUS != 0 )); then
          echo "❌ Failed to generate a new wrapped token." >&2
          echo "${NEW_WRAP_JSON}" >&2
          exit 3
        fi

        NEW_TOKEN="$(echo "$NEW_WRAP_JSON" | jq -r '.wrap_info.token // empty')"

        if [[ -z "$NEW_TOKEN" || "$NEW_TOKEN" == "null" ]]; then
          echo "❌ Vault did not return a wrapped token." >&2
          echo "${NEW_WRAP_JSON}" >&2
          exit 4
        fi

        echo "✅ New wrapped token issued:"
        echo ""
        echo "   ${NEW_TOKEN}"
        echo ""
        echo "👉 You can now run:"
        echo "   WRAPPED_TOKEN=${NEW_TOKEN} ./unwrap_story.sh"
        exit 0
        ;;

      n|N)
        echo "ℹ️  No new token issued. Exiting."
        exit 2
        ;;

      *)
        echo "❌ Invalid choice. Exiting."
        exit 2
        ;;
    esac
  fi

  echo "❌ Error unwrapping token:" >&2
  echo "${JSON_OUTPUT}" >&2
  exit $STATUS
fi

# Ensure the output is valid JSON
if ! echo "${JSON_OUTPUT}" | jq . >/dev/null 2>&1; then
  echo "ℹ️  Unwrapped output is not valid JSON, printing raw content:"
  echo "${JSON_OUTPUT}"
  exit 0
fi

###########################################################
# 4) Try KV v2 "story" structure first
###########################################################
# Expected shape:
# {
#   "data": {
#     "data": {
#       "attendee": "...",
#       "email": "...",
#       "quote": "..."
#     },
#     "metadata": { ... }
#   }
# }

if echo "${JSON_OUTPUT}" | jq -e '.data.data.attendee, .data.data.email, .data.data.quote' >/dev/null 2>&1; then
  echo "${JSON_OUTPUT}" | jq -r '
    .data.data as $s
    | "✨ Story Reveal ✨\n" +
      "Attendee: \($s.attendee)\n" +
      "Email:    \($s.email)\n" +
      "\n📜 Quote:\n\($s.quote)\n"
  '
  exit 0
fi

###########################################################
# 5) Fallback: maybe data is directly at .data (non-KV or different wrap)
###########################################################

if echo "${JSON_OUTPUT}" | jq -e '.data.attendee, .data.email, .data.quote' >/dev/null 2>&1; then
  echo "${JSON_OUTPUT}" | jq -r '
    .data as $s
    | "✨ Story Reveal ✨\n" +
      "Attendee: \($s.attendee)\n" +
      "Email:    \($s.email)\n" +
      "\n📜 Quote:\n\($s.quote)\n"
  '
  exit 0
fi

###########################################################
# 6) Last resort: just pretty-print whatever we got
###########################################################

echo "ℹ️  Unwrapped JSON (unexpected structure, printing as-is):"
echo "${JSON_OUTPUT}" | jq .
