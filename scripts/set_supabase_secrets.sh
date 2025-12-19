#!/usr/bin/env bash
set -euo pipefail

REPO="dinis-78/erphpuwrubpcmlzcdjiv"

# Basic checks
command -v gh >/dev/null || { echo "Install GitHub CLI and run 'gh auth login' first."; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "Run 'gh auth login' to authenticate with sufficient permissions."; exit 1; }

# Support non-interactive usage via environment variables
: "${SUPABASE_PROJECT_REF:=}"
: "${SUPABASE_SERVICE_ROLE_KEY:=}"
: "${SUPABASE_ACCESS_TOKEN:=}"

echo "Setting secrets for repo: $REPO"

if [ -z "${SUPABASE_PROJECT_REF}" ]; then
  read -rp "Enter SUPABASE_PROJECT_REF (project ref): " SUPABASE_PROJECT_REF
fi
if [ -z "${SUPABASE_SERVICE_ROLE_KEY}" ]; then
  read -srp "Enter SUPABASE_SERVICE_ROLE_KEY (input hidden): " SUPABASE_SERVICE_ROLE_KEY; echo
fi
if [ -z "${SUPABASE_ACCESS_TOKEN}" ]; then
  read -srp "Enter SUPABASE_ACCESS_TOKEN (input hidden): " SUPABASE_ACCESS_TOKEN; echo
fi

if [ -z "${SUPABASE_PROJECT_REF}" ] || [ -z "${SUPABASE_SERVICE_ROLE_KEY}" ] || [ -z "${SUPABASE_ACCESS_TOKEN}" ]; then
  echo "All three values are required. You can pass them as environment variables (SUPABASE_PROJECT_REF, SUPABASE_SERVICE_ROLE_KEY, SUPABASE_ACCESS_TOKEN) or enter them interactively."
  exit 1
fi

echo "Creating secrets (they will not be shown again)..."
echo "$SUPABASE_PROJECT_REF" | gh secret set SUPABASE_PROJECT_REF -R "$REPO"
echo "$SUPABASE_SERVICE_ROLE_KEY" | gh secret set SUPABASE_SERVICE_ROLE_KEY -R "$REPO"
echo "$SUPABASE_ACCESS_TOKEN" | gh secret set SUPABASE_ACCESS_TOKEN -R "$REPO"

echo "Done. Secrets set for $REPO."

