# Google Drive Sync Backend — Design

**Date:** 2026-07-02
**Status:** Approved (pending implementation)
**Branch:** `worktree-google-drive-sync`

## Summary

Make Google Drive a complete, fully functional cloud-sync backend on all five
supported platforms (iOS, macOS, Android, Windows, Linux). The Drive REST
layer already exists and is complete; this work adds a second authentication
path for desktop, per-platform OAuth configuration, UI re-enablement,
availability gating, error-handling refinements, and test coverage.

## Current state

- `lib/core/services/cloud_storage/google_drive_storage_provider.dart`
  fully implements `CloudStorageProvider` against Drive v3's hidden
  `appDataFolder` (`drive.appdata` scope): idempotent create-or-update
  upload by name, streaming download, `name contains` list filtering,
  delete, folder management, sign-in/sign-out with deferred silent auth.
- All dependencies are already declared: `google_sign_in` ^7.2.0,
  `googleapis` ^16.0.0, `extension_google_sign_in_as_googleapis_auth`
  ^3.0.0, `googleapis_auth` ^2.0.0.
- `CloudProviderType.googledrive` participates in the factory
  (`cloudProviderInstanceFor`), per-provider sync cursors (schema v81),
  and the backend-switch safety machinery with no engine changes needed.
- iOS OAuth is configured (`GIDClientID` + reversed-client-ID URL scheme
  in `ios/Runner/Info.plist`, project `433819313354`).
- The provider was deliberately hidden (commit `d884ee2a4c2`): the
  settings tile is removed from `cloud_sync_page.dart` and a persisted
  `googledrive` selection is coerced to `null` (lines 56–62).
- Gaps: no macOS or Android OAuth config, no Windows/Linux auth path at
  all (`google_sign_in` does not support them), `isAvailable()` returns
  a hard `true`, no persistent desktop credentials, no tests.

## Decisions made

| Decision | Choice |
|---|---|
| Platforms | All five: iOS, macOS, Android, Windows, Linux |
| Data location | Hidden `appDataFolder` (`drive.appdata` scope) — unchanged |
| Auth architecture | One provider, pluggable authenticator seam (Approach A) |
| Desktop auth | PKCE loopback, no client secret (client_secret optional for Google Desktop-app clients) |
| Acceptance | Full unit/widget coverage + manual device checklist pass |

No client secret is committed. The desktop flow uses PKCE (code_verifier /
S256 code_challenge, already implemented in `googleapis_auth`) on a
loopback redirect; Google's native-app OAuth lists `client_secret` as
optional for Desktop-app clients, so the token exchange is authenticated by
the PKCE verifier alone. Only OAuth client IDs -- public identifiers -- are
committed, so no `no hardcoded secrets` waiver is needed and GitHub secret
scanning has nothing to flag. (An earlier revision committed the desktop
client secret under an RFC 8252 §8.5 rationale; PKCE removes the need for it
entirely.)

## Architecture

One `GoogleDriveStorageProvider` remains the single `CloudProviderType.googledrive`
implementation. Authentication is extracted behind an internal seam so the
Drive REST code is shared and platform-agnostic.

The seam boundary is `http.Client`, not `DriveApi`: both
`extension_google_sign_in_as_googleapis_auth` (mobile/macOS) and
`googleapis_auth` (desktop) produce an authorized `http.Client`, so the
provider constructs `DriveApi(client)` itself and neither auth world leaks
into the REST layer.

### New files (mirroring the `s3/` submodule pattern)

| File | Purpose |
|---|---|
| `lib/core/services/cloud_storage/google_drive/google_drive_authenticator.dart` | Abstract seam: `authenticate()`, `attemptSilentAuth()`, `getAuthClient()` → authorized `http.Client`, `signOut()`, `userEmail` |
| `lib/core/services/cloud_storage/google_drive/google_sign_in_authenticator.dart` | iOS/macOS/Android: the existing `google_sign_in` v7 logic lifted out of the provider, behavior unchanged, including the `_allowSilentAuth` deferral that avoids keychain prompts before the user opts in |
| `lib/core/services/cloud_storage/google_drive/desktop_oauth_authenticator.dart` | Windows/Linux: loopback OAuth via `googleapis_auth` `clientViaUserConsent`, silent re-auth from a stored refresh token |
| `lib/core/services/cloud_storage/google_drive/google_drive_token_store.dart` | Desktop-only `AccessCredentials` persistence in `FallbackSecureStorage` under key `sync_gdrive_credentials`; same JSON-blob pattern as `S3CredentialsStore`, including preserving (not deleting) a corrupt blob |
| `lib/core/services/cloud_storage/google_drive/google_drive_client_config.dart` | Committed client IDs only (desktop client ID, Android `serverClientId` Web client ID); no client secret — desktop uses PKCE |

### Changed files

- `google_drive_storage_provider.dart` — the ~80 lines of `google_sign_in`
  code move into `GoogleSignInAuthenticator`; the constructor takes a
  `GoogleDriveAuthenticator` with a default factory selecting by
  `Platform` (injectable for tests). All Drive REST logic is unchanged.
- `sync_providers.dart` — singleton construction only; no engine changes.
- `cloud_sync_page.dart` — tile restored, coercion removed (see UI below).
- `macos/Runner/Info.plist`, Android manifest/init — OAuth config (below).
- `storage_providers.dart` — the currently-dead `supportsGoogleDrive`
  capability flag is wired to the provider's real `isAvailable()` logic
  so the two cannot disagree.

## Desktop OAuth flow (Windows/Linux)

1. **First sign-in:** `authenticate()` calls `obtainAccessCredentialsViaUserConsent`
   with the desktop client ID (no secret) and the `drive.appdata` scope.
   It binds an ephemeral port on `127.0.0.1`, opens the system browser to
   Google's consent page with a PKCE `code_challenge`, and receives the
   auth code on the loopback redirect (RFC 8252 §7.3); the token exchange
   sends the `code_verifier` and an empty `client_secret`. A small in-app
   dialog shows "Complete sign-in in your browser…" with a Cancel button
   that closes the loopback listener.
2. **Persistence:** the resulting `AccessCredentials` (access token,
   refresh token, expiry, scopes) serialize to one JSON blob in
   `FallbackSecureStorage` under `sync_gdrive_credentials`.
3. **Cold launch:** `attemptSilentAuth()` rebuilds an auto-refreshing
   client from the stored refresh token — no browser, no prompt. Nothing
   touches secure storage until the user has selected Google Drive at
   least once (same "no keychain prompt before opt-in" rule the mobile
   path enforces).
4. **Sign-out:** best-effort POST to Google's token-revocation endpoint,
   then delete the stored blob. Revocation failure (e.g. offline) does
   not block local sign-out.
5. **Revoked/expired refresh token:** the auth client throws on refresh;
   the provider surfaces a `CloudStorageException` whose `displayMessage`
   asks the user to sign in again, and the stored blob is cleared so the
   next attempt re-runs the browser flow.

## Per-platform OAuth configuration

| Platform | GCP console client type | App-side config |
|---|---|---|
| iOS | Existing iOS client (done) | Already in `ios/Runner/Info.plist` |
| macOS | Reuses the iOS client (Google treats macOS apps as iOS-type clients) | Add `GIDClientID` + reversed-client-ID URL scheme to `macos/Runner/Info.plist`; add the Keychain Sharing entitlement `google_sign_in` requires on macOS |
| Android | New Android client per signing key (debug SHA-1 and release SHA-1), plus a Web application client | Web client ID passed as `serverClientId` to `GoogleSignIn.instance.initialize()` via `google_drive_client_config.dart`. No `google-services.json` (that is a Firebase artifact, not needed) |
| Windows/Linux | One shared Desktop app client | Client ID only committed in `google_drive_client_config.dart`; PKCE loopback flow needs no secret |

All clients live in the same Google Cloud project (`433819313354`) so every
platform shares the same `appDataFolder` — this is what makes cross-device
sync work, because `appDataFolder` is scoped per project, per user.

Click-by-click console instructions are in Appendix A.

## UI changes (`cloud_sync_page.dart`)

- Restore the Google Drive tile in `_buildProviderSection`, mirroring the
  iCloud tile's structure. When connected, the subtitle shows the
  signed-in account email (`getUserEmail()`).
- Sign-out reuses the page's existing Advanced > Sign Out row, which
  already confirms and disconnects the active provider; no per-tile
  sign-out affordance is added. Provider switching continues to route
  through the existing backend-departure flow (`recordBackendDeparture`),
  so the per-provider cursor (v81) is stamped and the stale-cursor bug
  class PR #327 fixed cannot recur.
- Remove the `googledrive → null` coercion (lines 56–62); a persisted
  selection resumes normally.
- Selecting the tile triggers `authenticate()`; on failure the tile stays
  unselected and the error's `displayMessage` shows in a SnackBar with
  `persist: false` + `showCloseIcon` (the #406 SnackBar lesson).
- The existing localization string
  `settings_cloudSync_provider_googleDrive` is reused; any new strings
  are translated into all 10 non-English locales and regenerated.

## Availability gating

`isAvailable()` stops returning a hard `true`:

- iOS, macOS, Android: `true` unconditionally (config is compile-time).
- Windows, Linux: `true` only when the desktop client config constants
  are non-empty — a build without OAuth constants degrades to a hidden
  tile, not a runtime crash.

## Error handling

All Drive calls already funnel through `CloudStorageException`. Additions:

- `DetailedApiRequestError` 401 → one silent re-auth attempt, then a
  "sign in to Google Drive again" failure. (Drive access tokens expire
  hourly mid-session; one retry disambiguates a stale token from a
  revoked grant.)
- 403 `storageQuotaExceeded` → explicit "Google Drive storage is full"
  message.
- `SocketException` → the standard offline message the sync engine
  already handles.
- Auth-specific failures — browser launch failure, user closes the
  browser without consenting, loopback port bind failure — get distinct
  messages and never leave partial state (no stored blob, tile
  unselected).

## Testing

### Unit

- `test/core/services/cloud_storage/google_drive_storage_provider_test.dart`
  with a fake authenticator + mocked `http.Client` (the S3 suite is the
  template): upload create-vs-update by name, list filtering, download,
  delete, folder get-or-create caching, 401 retry-once, quota error
  mapping.
- `test/core/services/cloud_storage/google_drive/desktop_oauth_authenticator_test.dart`:
  silent auth from stored credentials, revoked-token cleanup, sign-out
  revocation best-effort semantics.
- `test/core/services/cloud_storage/google_drive/google_drive_token_store_test.dart`
  with an in-memory secure-storage fake: round-trip, corrupt blob
  preserved, delete.

### Widget

- Update the two `cloud_sync_page_test.dart` cases that currently assert
  the tile is hidden (`:554`, `:810`).
- New cases: tile shown on all platforms, selecting triggers
  authentication, connected subtitle shows the account email, sign-out
  routes through backend departure.

### Manual device checklist (acceptance gate)

Run on real hardware per platform — macOS, iPhone or iPad, Android
device, Windows, Linux:

1. Fresh sign-in from the Cloud Sync page (browser flow on desktop,
   native sheet on mobile/macOS).
2. Cold-launch silent auth: force-quit, relaunch, confirm sync works
   without any prompt.
3. Two-device sync round-trip: edit a dive on device A, Sync Now on
   both, confirm it appears on device B (and the reverse).
4. Sign out; confirm the tile deselects and no keychain prompts appear
   afterward.
5. Revoke the app's access from myaccount.google.com, then attempt a
   sync; confirm the "sign in again" recovery path works.
6. Backend switch iCloud → Google Drive (Apple platforms): confirm the
   departure/moved-marker flow and that cursors do not read stale.

## Out of scope

- Any change to the sync engine, changeset layout (`ssv1.` flat files),
  or per-provider cursor machinery — Drive slots into all of it as-is.
- A visible My Drive folder option (`drive.file` scope) — rejected in
  favor of `appDataFolder`.
- Multi-account support beyond sign-out/sign-in-as-another-user.
- Web platform support.

## Appendix A — Google Cloud Console walkthrough

All steps happen in the existing project `433819313354` at
console.cloud.google.com. Exact UI labels current as of mid-2026.

### A.1 Consent screen check (once)

1. APIs & Services → OAuth consent screen.
2. Confirm the app is configured (it must be, since the iOS client
   works). Scope `…/auth/drive.appdata` is classified non-sensitive, so
   no verification review is required. If the publishing status is
   "Testing", either add each Google account you will test with as a
   test user, or publish to "In production" (no review needed for
   non-sensitive scopes).
3. APIs & Services → Enabled APIs: confirm **Google Drive API** is
   enabled; enable it if not.

### A.2 Android clients

1. Get the debug SHA-1:
   `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android | grep SHA1`
2. Get the release SHA-1 the same way from the release keystore
   (and, if distributing via Play with Play App Signing, copy the
   app-signing SHA-1 from Play Console → Setup → App integrity).
3. APIs & Services → Credentials → Create Credentials → OAuth client ID
   → Application type **Android**. Package name: the applicationId from
   `android/app/build.gradle`. SHA-1: the debug fingerprint. Create.
4. Repeat step 3 for each additional SHA-1 (release, Play app-signing).
   Android clients need no app-side config; Google matches package +
   signature at runtime.
5. Create Credentials → OAuth client ID → Application type
   **Web application**, name "Submersion Android serverClientId". No
   redirect URIs needed. Copy its client ID — this is the
   `serverClientId` constant.

### A.3 Desktop client (Windows/Linux)

1. Create Credentials → OAuth client ID → Application type
   **Desktop app**, name "Submersion Desktop".
2. Copy the client ID — the committed `desktopClientId` constant in
   `google_drive_client_config.dart`. The client secret Google also issues
   is not used: the loopback flow authenticates with PKCE, for which
   `client_secret` is optional on Desktop-app clients. Do not commit it.

### A.4 macOS

No new console client. Reuse the existing iOS client ID:

1. Copy `GIDClientID` and the reversed-client-ID URL scheme from
   `ios/Runner/Info.plist` into `macos/Runner/Info.plist`.
2. Add the Keychain Sharing entitlement to both
   `macos/Runner/DebugProfile.entitlements` and
   `macos/Runner/Release.entitlements` as required by `google_sign_in`
   on macOS.
