#!/usr/bin/env zsh
set -euo pipefail

usage() {
  echo "Usage: $0 <project-ref> [--run-flutter]"
  echo "Example: $0 abcd1234efgh --run-flutter"
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage
  exit 1
fi

PROJECT_REF="$1"
RUN_FLUTTER=false
if [[ ${2-} == "--run-flutter" ]]; then
  RUN_FLUTTER=true
elif [[ $# -eq 2 ]]; then
  usage
  exit 1
fi

if ! command -v npx >/dev/null 2>&1; then
  echo "❌ npx not found. Install Node.js first."
  exit 1
fi

if ! npx supabase --version >/dev/null 2>&1; then
  echo "❌ Supabase CLI unavailable."
  exit 1
fi

echo "▶ Linking project $PROJECT_REF"
npx supabase link --project-ref "$PROJECT_REF"

echo "▶ Pushing database migration to cloud"
npx supabase db push

echo "▶ Deploying invite-create function"
npx supabase functions deploy invite-create --no-verify-jwt

echo "▶ Deploying invite-resolve function"
npx supabase functions deploy invite-resolve --no-verify-jwt

echo "▶ Deploying invite-open function"
npx supabase functions deploy invite-open --no-verify-jwt

echo "▶ Deploying invite-status function"
npx supabase functions deploy invite-status --no-verify-jwt

echo "▶ Deploying data-sync function"
npx supabase functions deploy data-sync --no-verify-jwt

echo "▶ Deploying send-fcm function"
npx supabase functions deploy send-fcm --no-verify-jwt

echo "▶ Deploying account-export function"
npx supabase functions deploy account-export --no-verify-jwt

echo "▶ Deploying account-delete function"
npx supabase functions deploy account-delete --no-verify-jwt

echo "▶ Setting invite public base secret"
npx supabase secrets set "INVITE_PUBLIC_BASE=https://${PROJECT_REF}.supabase.co"

echo ""
echo "✅ Cloud setup complete"
echo ""
echo "Reminder — set FCM secrets (required for push notifications):"
echo "  npx supabase secrets set FCM_PROJECT_ID=<firebase-project-id>"
echo "  npx supabase secrets set FCM_SERVICE_ACCOUNT_EMAIL=<client_email>"
echo "  npx supabase secrets set FCM_PRIVATE_KEY=\"<private_key>\""
echo ""
echo "Run app with:"
echo "  bash dev.sh"

if [[ "$RUN_FLUTTER" == "true" ]]; then
  bash dev.sh
fi
