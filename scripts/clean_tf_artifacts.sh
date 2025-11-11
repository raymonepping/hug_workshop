#!/usr/bin/env bash
# clean_tf_artifacts.sh
# Cleans Terraform artifacts and prepares repo for HCP Terraform Stacks

# shellcheck disable=SC2034
VERSION="1.0.0"

set -euo pipefail

echo "🧹 Removing local Terraform artifacts..."
find . -type d -name '.terraform' -prune -exec rm -rf {} +
find . -type f -name '.terraform.lock.hcl' -exec rm -f {} +
find . -type f -name 'terraform.tfstate' -exec rm -f {} +
find . -type f -name 'terraform.tfstate.backup' -exec rm -f {} +

echo "🧐 Checking for tracked lock/state files..."
FILES=$(git ls-files '**/.terraform.lock.hcl' 'terraform.tfstate' 'terraform.tfstate.backup' '**/terraform.tfstate' '**/terraform.tfstate.backup' || true)
if [ -n "$FILES" ]; then
  echo "🚨 Removing tracked files:"
  echo "$FILES"
  git rm -f --cached $FILES
fi

echo "🛡️ Updating .gitignore..."
grep -q ".terraform.lock.hcl" .gitignore || cat >> .gitignore <<'EOF'

# Terraform artifacts (ignore anywhere)
.terraform/
**/.terraform/
.terraform.lock.hcl
**/.terraform.lock.hcl
*.tfstate
**/*.tfstate
*.tfstate.backup
**/*.tfstate.backup
EOF

echo "🧾 Ensuring repo has minimal stack files..."
ls -la

echo "📦 Staging cleanup..."
git add -A
git commit -m "chore(stack-app): purge terraform artifacts + fix stack root" || echo "ℹ️ Nothing to commit"

echo "🚀 Push to remote..."
git push

echo "✅ Cleanup complete. Go to HCP Terraform → Fetch latest → Plan → Apply"
