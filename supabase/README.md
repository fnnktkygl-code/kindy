# Supabase secure invite backend (no custom domain required)

This folder provides a production-oriented invite backend using Supabase HTTPS endpoints.

## Cloud quickstart (recommended now)

No Docker required.

### 4 commands (exact)

Replace `<project-ref>` with your Supabase project ref.

```bash
npx supabase link --project-ref <project-ref>
npx supabase db push
npx supabase functions deploy invite-create --no-verify-jwt
npx supabase functions deploy invite-resolve --no-verify-jwt
npx supabase functions deploy invite-open --no-verify-jwt
npx supabase functions deploy invite-status --no-verify-jwt
```

Then set invite base URL secret:

```bash
npx supabase secrets set INVITE_PUBLIC_BASE="https://<project-ref>.supabase.co"
```

Run Flutter against cloud API:

```bash
flutter run --dart-define=PIGIO_INVITE_API_BASE=https://<project-ref>.supabase.co
```

### One-shot cloud script

```bash
chmod +x tool/setup_supabase_cloud.sh
./tool/setup_supabase_cloud.sh <project-ref>
```

To deploy and launch app directly:

```bash
./tool/setup_supabase_cloud.sh <project-ref> --run-flutter
```

## Security model

- 32-byte random token generated server-side.
- Only `SHA-256(token)` is stored in DB (`token_hash`), never raw token.
- Invite links expire (`expires_at`) and are one-time consumable.
- Resolution marks token `accepted` atomically to reduce replay.
- Functions run with Service Role key; anon direct DB access is blocked by RLS policies.

## 1) Apply migration

```bash
supabase db push
```

Migration file: `supabase/migrations/20260223_create_invites.sql`

## 2) Deploy Edge Functions

```bash
supabase functions deploy invite-create
supabase functions deploy invite-resolve
```

## 3) Set function secrets

```bash
supabase secrets set INVITE_PUBLIC_BASE="https://<your-project-ref>.supabase.co"
```

You also need standard Supabase function secrets (`SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`) configured by your environment.

## 4) Point Flutter app to Supabase base URL

Run app with:

```bash
flutter run --dart-define=PIGIO_INVITE_API_BASE=https://<your-project-ref>.supabase.co
```

The Flutter client calls:

- `POST /functions/v1/invite-create`
- `POST /functions/v1/invite-resolve`
- Invite click/open endpoint: `GET /functions/v1/invite-open?token=...`
- Sender sync endpoint: `GET /functions/v1/invite-status?token=...`

It also keeps compatibility with your legacy endpoints (`/v1/invitations/token`, `/v1/invitations/resolve`) as fallback.

## Local setup (Supabase CLI)

Files added for local setup:

- `supabase/config.toml`
- `supabase/.env.local.example`

### A. Start local Supabase stack

```bash
supabase start
```

From the output, copy the local `service_role` key.

### B. Prepare local env file

```bash
cp supabase/.env.local.example supabase/.env.local
```

Then paste your local `SUPABASE_SERVICE_ROLE_KEY` into `supabase/.env.local`.

### C. Apply migration locally

```bash
supabase db push
```

### D. Serve Edge Functions locally (2 terminals)

Terminal 1:

```bash
supabase functions serve invite-create --env-file supabase/.env.local
```

Terminal 2:

```bash
supabase functions serve invite-resolve --env-file supabase/.env.local
```

### E. Run Flutter app against local function gateway

```bash
flutter run --dart-define=PIGIO_INVITE_API_BASE=http://127.0.0.1:54321
```

If you test on a physical Android device, replace localhost with your machine LAN IP:

```bash
flutter run --dart-define=PIGIO_INVITE_API_BASE=http://<your-lan-ip>:54321
```

## Notes

- You can use Supabase domain now; move to your own domain later with no schema changes.
- For app links/universal links later, map your own domain to the same invite path contract (`/invite?...`).

## One-shot script (recommended)

From project root:

```bash
chmod +x tool/dev_local_invites.sh
```

Desktop / emulator mode (localhost):

```bash
./tool/dev_local_invites.sh
```

Physical Android mode (auto LAN IP):

```bash
./tool/dev_local_invites.sh --android-physical
```

The script does:

1. Checks Docker + Node/npx prerequisites.
2. Ensures `supabase/.env.local` exists.
3. Starts local Supabase.
4. Pushes local DB migration.
5. Starts both Edge Functions in background.
6. Runs Flutter with proper `PIGIO_INVITE_API_BASE`.
