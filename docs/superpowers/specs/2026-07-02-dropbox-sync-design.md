# Dropbox Sync Provider — Design

**Date:** 2026-07-02
**Status:** Approved
**Scope:** Add Dropbox as a first-class cloud sync backend on all five platforms (iOS, Android, macOS, Windows, Linux).

## Goal

Users can select Dropbox as their sync backend the same way they select
iCloud, Google Drive, or S3 today. The sync engine (changesets, epochs,
cursors, tombstones, backend-switch safety) is untouched; Dropbox is a new
implementation of the existing `CloudStorageProvider` interface.

## Decisions

| Decision | Choice |
| --- | --- |
| Dropbox access model | App folder (`Apps/Submersion/`), minimal scopes |
| API integration | Hand-rolled Dropbox HTTP API v2 client over `http`, mirroring the S3 provider structure. No third-party Dropbox packages. |
| OAuth completion | Copy-paste authorization code on all platforms (no `redirect_uri`, no URL schemes, no loopback server) |
| Auth security | OAuth 2 PKCE (S256). App key embedded as a plain constant — public by design under PKCE; there is no client secret. |
| Token persistence | Refresh token + account info as one JSON blob in `FallbackSecureStorage`, mirroring `S3CredentialsStore` |
| Scope | Sync backend only. Photo/service connector is future work, but the auth layer is written so a connector could reuse it. |
| Dropbox app registration | Not yet created; runbook below |

## Rejected alternatives

- **Community Dropbox packages** (`dropbox_client` et al.): wrap the official
  mobile SDKs, so desktop platforms are unsupported; pure-Dart alternatives
  are unmaintained. The needed API surface is ~6 endpoints.
- **Custom-folder mode + Dropbox desktop client**: already exists as a
  workaround, but has no mobile story. It remains supported and unchanged.
- **Redirect-based OAuth** (URL scheme on mobile, loopback listener on
  desktop): better UX but three distinct platform mechanisms. The copy-paste
  flow is one identical, fully unit-testable pure-Dart path everywhere. Can
  be upgraded later without touching storage or provider code.

## Architecture

New module `lib/core/services/cloud_storage/dropbox/`:

### `dropbox_api_client.dart`

Thin REST wrapper with an injectable `http.Client`:

- `POST /2/files/upload` (`mode: overwrite`) for files up to 150 MB;
  chunked upload sessions (`upload_session/start|append_v2|finish`) above
  that. Sync changesets are small; chunking is a safety valve for large
  compacted bases, not the common path.
- `POST /2/files/download` (payload in body, args in `Dropbox-API-Arg`
  header).
- `POST /2/files/list_folder` + `list_folder/continue` — pagination is
  always followed to cursor exhaustion.
- `POST /2/files/delete_v2`, `POST /2/files/get_metadata`.
- `POST /2/users/get_current_account` (display name/email for the UI).

### `dropbox_auth.dart`

PKCE flow and token lifecycle:

- Generates code verifier/challenge (RFC 7636, S256).
- Builds the authorize URL:
  `https://www.dropbox.com/oauth2/authorize?client_id=<appkey>&response_type=code&code_challenge=<c>&code_challenge_method=S256&token_access_type=offline`
  — **no `redirect_uri`**, which makes Dropbox display the authorization
  code for the user to copy. Launched with the existing `url_launcher`
  dependency.
- Exchanges pasted code + verifier at `POST /oauth2/token` for an access
  token (~4 h lifetime) and a refresh token.
- Transparently refreshes the access token when missing or expired.
  Refresh is single-flight: concurrent API calls awaiting a refresh share
  one token request.

### `dropbox_auth_store.dart`

Refresh token + account info persisted as a single JSON blob under key
`sync_dropbox_auth` via `FallbackSecureStorage` (keychain, with the
legacy-keychain retry for no-sandbox macOS builds). Follows the
`S3CredentialsStore` rules exactly:

- One blob keeps load/save atomic; nothing touches SharedPreferences or
  the database.
- A corrupt blob is returned as null but **left in place** — a transient
  decode bug must never destroy credentials.
- Cleared only on explicit disconnect.

### `dropbox_storage_provider.dart`

Implements `CloudStorageProvider` with `CloudStorageProviderMixin`.

- `providerId: 'dropbox'`, `providerName: 'Dropbox'`.
- `isAvailable()` → true on every platform.
- `isAuthenticated()` → auth store has a refresh token.
- File IDs are Dropbox paths (as the iCloud provider uses relative paths).
- App-folder scope means `getOrCreateSyncFolder()` resolves to the app
  folder root; Dropbox surfaces it to the user as `Apps/Submersion/`.
- `signOut()` calls `POST /2/auth/token/revoke` best-effort (network
  failure ignored), then clears the stored blob.

### Registration touchpoints

- `CloudProviderType.dropbox` added to the enum in
  `lib/core/data/repositories/sync_repository.dart`.
- Singleton + `cloudProviderInstanceFor` case in
  `lib/features/settings/presentation/providers/sync_providers.dart`.
- Established-provider store, backend-switch safety, and per-provider
  cursors key off the enum/provider id and pick Dropbox up automatically.

## Auth flow & settings UI

Connect flow, identical on all five platforms:

1. User taps the Dropbox tile on the Cloud Sync page → "Connect Dropbox".
2. App generates PKCE verifier/challenge and opens the system browser to
   the authorize URL.
3. App shows a dialog with a paste-friendly code field (validated
   non-empty/trimmed) and a "reopen browser" affordance.
4. On submit: code→token exchange, fetch account info, persist refresh
   token + account info.
5. Tile shows the connected account email; disconnect is offered in the
   same place.

Settings UI is a tile + dialog on
`lib/features/settings/presentation/pages/cloud_sync_page.dart` — unlike
S3 there is no multi-field config page. All new strings are localized into
all 10 non-English locales.

## Data layout, error handling, edge cases

- **Layout:** the same files the sync engine writes through the provider
  interface today (sync JSON, changeset files, epoch/moved markers),
  rooted at the app folder. Uploads use `mode: overwrite`; the sync
  engine's HLC/changeset protocol is the concurrency authority, so
  file-level last-writer-wins is correct (same as S3).
- **Errors** surface as the existing `CloudStorageException` with the
  Dropbox error summary as `cause`:
  - **401 / invalid refresh token** (user revoked access): drop in-memory
    tokens and report an auth failure so the UI offers "reconnect". The
    stored blob is not cleared by transient 401s.
  - **429:** honor `Retry-After` once, then fail with a readable message.
  - **409 path lookup errors** (`not_found`): mapped to null/false where
    the interface contract expects "doesn't exist" (`getFileInfo`,
    `fileExists`); `downloadFile` throws `CloudStorageException` as the
    contract requires.
  - **`insufficient_space`:** distinct user-facing message (the one error
    the user must fix in Dropbox, not Submersion).
  - Network/TLS failures wrapped as the S3 client does.
- **Conflicted copies:** Dropbox's "(conflicted copy)" naming is already
  matched by the mixin's `isConflictCopy()`; add a test asserting it.

## Testing

TDD; all pure Dart with a mocked `http.Client` — no live Dropbox in CI.

- **Auth:** PKCE vectors (computed with python3, not from recall),
  authorize-URL construction, token exchange, refresh-on-expiry,
  single-flight refresh under concurrency, revoked-token handling.
- **Auth store:** round-trip, corrupt-blob-preserved, clear (template:
  `S3CredentialsStore` tests).
- **API client:** request shape per endpoint (incl. `Dropbox-API-Arg`
  header), pagination continuation, every error mapping above.
- **Provider:** `CloudStorageProvider` contract round-trips,
  `isSyncFile`/`isConflictCopy`, unauthenticated-state behavior
  (template: S3 provider tests).
- **Widget tests:** tile per auth state; connect dialog validation/submit.
  Note the Apple-only tile-tap caveat from the iCloud tests on Linux CI.
- **Manual pre-merge verification:** real connect + two-device sync
  (macOS + iPhone) against the development-mode Dropbox app.

Known limitation, accepted: `SyncService` integration is not re-tested per
backend; the provider contract tests are the boundary (same policy as
Google Drive and S3).

## Dropbox developer console runbook (manual, one-time)

1. Create app at dropbox.com/developers: **Scoped access** → **App
   folder** → name "Submersion" (the name becomes the visible folder).
2. Permissions tab, before first authorization: `files.content.write`,
   `files.content.read`, `files.metadata.read`, `account_info.read`.
   Scopes are baked into tokens at authorization time.
3. No redirect URIs required.
4. Copy the app key into the codebase as a plain constant. It is public
   by design under PKCE; there is no client secret anywhere.
5. Development mode allows 500 linked users. Before public release, apply
   for production status (App-folder + minimal scopes keeps review
   routine).

## Rollout

Provider + auth + tests first; settings UI second; l10n sweep last. The
feature ships dark until the tile is added — no feature flag. Older app
versions sharing a backend fail safe on the unknown provider id (they
cannot select it; per-provider state is keyed by provider id).

## Out of scope

- Dropbox photo/service connector (future; auth layer is reusable).
- Custom Dropbox folder location (precluded by App-folder scope).
- Dropbox as a backup destination.
- Migrating custom-folder-mode users (their setup keeps working).
