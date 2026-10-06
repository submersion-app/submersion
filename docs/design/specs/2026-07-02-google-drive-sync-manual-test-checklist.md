# Google Drive Sync - Manual Device Test Checklist

Run on real hardware per platform: macOS, iPhone or iPad, Android device,
Windows, Linux. All items must pass before Google Drive sync is considered
done (acceptance gate from the 2026-07-02 design spec).

## Console prerequisites (do these first)

Both are Google Cloud console state for project `433819313354`, not code.
Item 1 in particular invalidates item 2 of the device matrix below if
skipped: refresh tokens issued in Testing mode expire after 7 days, so a
cold-launch silent auth that passes today fails a week later.

- [ ] A. OAuth consent screen publishing status is **In production**, not
      Testing (Google Auth Platform > Audience > Publish app). The only
      Drive scope requested is `drive.appdata`, which Google classifies as
      non-sensitive, so publishing needs no verification review and takes
      effect immediately.
- [ ] B. An Android OAuth client exists for the **release / Play App
      Signing** SHA-1, not just the debug SHA-1. Without it, sign-in works
      in debug builds and fails in release ones.
- [ ] C. The repository secret `GOOGLE_DRIVE_CLIENT_SECRET` holds the
      **Desktop** client's secret (starts with `GOCSPX-`, ~35 chars), not the
      client id. Google authenticates the Desktop-client token exchange with
      it and answers `invalid_request: client_secret is missing` without it,
      PKCE notwithstanding, so a wrong value produces a green build whose
      sign-in fails only after the user has authorised in the browser. Google
      no longer displays secrets after creation; use Add secret to mint a new
      one. Local desktop builds read the same value from the
      `GOOGLE_DRIVE_CLIENT_SECRET` environment variable
      (`scripts/release/build_nosandbox_macos.sh`); omitting it disables
      Google Drive in that build by design rather than failing at sign-in.

## Verification status (2026-08-23)

Recorded so the next person knows what is actually proven:

- **macOS Developer ID DMG** -- VERIFIED on device. Fresh sign-in and a full
  publish of 224 pending changes, on a build signed Developer ID + hardened
  runtime with `ReleaseNoSandbox.entitlements`.
- **macOS sandboxed (App Store)** -- regression-checked only: the build must
  still choose the google_sign_in path, since `KeychainGatedAuthenticator` now
  sits in front of every macOS build.
- **Windows / Linux** -- NOT verified on device. The loopback flow there was
  broken in exactly the same way (no client secret) and the fix is shared
  code, but nobody has watched sign-in complete on either platform. Treat
  items 1-7 below as outstanding for both.

## Device matrix

For each platform:

- [ ] 1. Fresh sign-in from Settings > Cloud Sync (native account sheet on
      iOS/macOS/Android; system browser + return on Windows/Linux). Tile
      shows the account email after connecting.
- [ ] 2. Cold-launch silent auth: force-quit, relaunch, run Sync Now.
      No sign-in prompt, no keychain dialog, sync succeeds.
- [ ] 3. Two-device round-trip: edit a dive on device A, Sync Now on A
      then B; the change appears on B. Repeat in the other direction.
- [ ] 4. Sign out (Advanced > Sign Out): tile deselects, subsequent
      launches show no keychain prompts.
- [ ] 5. Revoke access at myaccount.google.com > Security > Third-party
      access, then Sync Now: a "sign in again" error appears; re-auth
      via the tile recovers and sync works.
- [ ] 6. (Apple platforms) Backend switch iCloud -> Google Drive: the
      departure confirmation appears, the moved-marker lands on iCloud,
      and the per-provider cursor does not read stale (first Drive sync
      is a full first-contact sync, not an incremental continuation).
- [ ] 7. (Windows/Linux) Cancel the browser dialog mid-sign-in: the tile
      stays unselected, no credentials are stored, retrying works.
- [ ] 8. Settings > Media Storage still offers Google Drive and connects,
      on every platform where the Cloud Sync tile is enabled. The media
      store and sync share one Google session and one appDataFolder, so
      the availability gate now hides both together; check they agree.

Cross-platform matrix (any two platforms with different auth paths, e.g.
macOS + Windows): items 1-3 passing proves both OAuth clients land in the
same appDataFolder (same Google Cloud project).
