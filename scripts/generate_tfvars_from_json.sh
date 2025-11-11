#!/usr/bin/env bash
set -euo pipefail

INPUT_FILE="${1:-}"
CLEANUP="${2:-}"

if [[ -z "$INPUT_FILE" ]]; then
  echo "❌ Usage: $0 <input_json> [--cleanup]"
  echo "   Supported input:"
  echo "     • bootstrap.json → triggers Terraform user bootstrap"
  echo "     • credentials.auto.tfvars.json → generates locked_users.auto.tfvars"
  exit 1
fi

if [[ ! -f "$INPUT_FILE" ]]; then
  echo "❌ File not found: $INPUT_FILE"
  exit 1
fi

# Step 1: Bootstrap if needed
if jq -e '.emails' "$INPUT_FILE" > /dev/null 2>&1; then
  echo "🚀 Bootstrapping users from: $INPUT_FILE"

  TMP_VARS=".bootstrap.auto.tfvars.json"
  jq '{ emails: .emails }' "$INPUT_FILE" > "$TMP_VARS"

  echo "📦 Running Terraform to create users and capture IDs..."
  terraform apply \
    -var='using_locked=false' \
    -var='write_credentials_file=true' \
    -var-file="$TMP_VARS" \
    -auto-approve

  echo "📤 Fetching credentials_map from Terraform output..."
  TMP_OUTPUT=$(terraform output -json credentials_map 2>/dev/null || true)

  if [[ -z "$TMP_OUTPUT" || "$TMP_OUTPUT" == "null" || "$TMP_OUTPUT" == "{}" ]]; then
    echo "❌ Failed to retrieve 'credentials_map'. Ensure it's defined and populated in your Terraform outputs."
    rm -f "$TMP_VARS"
    exit 1
  fi

  echo "$TMP_OUTPUT" > credentials.auto.tfvars.json
  INPUT_FILE="credentials.auto.tfvars.json"

  echo "🧼 Cleaning up: $TMP_VARS"
  rm -f "$TMP_VARS"

elif jq -e '.users' "$INPUT_FILE" > /dev/null 2>&1; then
  echo "🔁 Parsing existing credentials file: $INPUT_FILE"
else
  echo "❌ Unrecognized input format. Must contain either .emails or .users"
  exit 1
fi

# Step 2: Convert to locked_users.auto.tfvars (HCL)
OUTPUT_FILE="locked_users.auto.tfvars"
echo "📄 Converting to HCL: $OUTPUT_FILE"

{
  echo "users = {"
  jq -r '
    .users
    | to_entries
    | map(
        "  \"" + .key + "\" = {\n" +
        "    username      = \"" + .value.username + "\"\n" +
        "    membership_id = \"" + .value.membership_id + "\"\n" +
        "    user_id       = \"" + (.value.user_id // "") + "\"\n" +
        "  }"
      )
    | join("\n\n")
  ' "$INPUT_FILE"
  echo "}"
} > "$OUTPUT_FILE"

echo "✅ HCL tfvars file written: $OUTPUT_FILE"

if [[ "$CLEANUP" == "--cleanup" ]]; then
  echo "🧹 Removing: $INPUT_FILE"
  rm -f "$INPUT_FILE"
fi

echo "🎉 Done."
