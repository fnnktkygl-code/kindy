#!/usr/bin/env zsh
set -euo pipefail

usage() {
  echo "Usage: $0 [--android-physical]"
  echo "  --android-physical   Use LAN IP instead of 127.0.0.1 for Flutter dart-define"
}

ANDROID_PHYSICAL=false
if [[ ${1-} == "--android-physical" ]]; then
  ANDROID_PHYSICAL=true
elif [[ ${1-} == "-h" || ${1-} == "--help" ]]; then
  usage
  exit 0
elif [[ $# -gt 0 ]]; then
  usage
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "❌ Docker CLI not found. Install Docker Desktop first: https://docs.docker.com/desktop"
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "❌ Docker daemon is not running. Start Docker Desktop, then retry."
  exit 1
fi

if ! command -v npx >/dev/null 2>&1; then
  echo "❌ npx not found. Install Node.js first."
  exit 1
fi

if [[ ! -f "supabase/.env.local" ]]; then
  cp "supabase/.env.local.example" "supabase/.env.local"
  echo "ℹ️ Created supabase/.env.local from example"
fi

if grep -q "<paste-from-supabase-start-output>" "supabase/.env.local"; then
  echo "❌ supabase/.env.local still contains placeholder service key."
  echo "   Replace SUPABASE_SERVICE_ROLE_KEY and retry."
  exit 1
fi

echo "▶ Starting Supabase local stack..."
npx supabase start

echo "▶ Applying local migrations..."
npx supabase db push --local

mkdir -p .run

echo "▶ Starting invite-create function..."
if [[ -f .run/invite-create.pid ]]; then
  kill "$(cat .run/invite-create.pid)" >/dev/null 2>&1 || true
fi
nohup npx supabase functions serve invite-create --env-file supabase/.env.local > .run/invite-create.log 2>&1 &
echo $! > .run/invite-create.pid

echo "▶ Starting invite-resolve function..."
if [[ -f .run/invite-resolve.pid ]]; then
  kill "$(cat .run/invite-resolve.pid)" >/dev/null 2>&1 || true
fi
nohup npx supabase functions serve invite-resolve --env-file supabase/.env.local > .run/invite-resolve.log 2>&1 &
echo $! > .run/invite-resolve.pid

sleep 2

BASE_URL="http://127.0.0.1:54321"
if [[ "$ANDROID_PHYSICAL" == "true" ]]; then
  LAN_IP="$(ipconfig getifaddr en0 || ipconfig getifaddr en1 || true)"
  if [[ -z "$LAN_IP" ]]; then
    echo "❌ Unable to resolve LAN IP (en0/en1)."
    exit 1
  fi
  BASE_URL="http://${LAN_IP}:54321"
fi

echo "▶ Running Flutter with PIGIO_INVITE_API_BASE=$BASE_URL"
flutter run --dart-define=PIGIO_INVITE_API_BASE="$BASE_URL"
