# Google Drive Sync — Manual Device Test Checklist

Run on real hardware per platform: macOS, iPhone or iPad, Android device,
Windows, Linux. All items must pass before Google Drive sync is considered
done (acceptance gate from the 2026-07-02 design spec).

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

Cross-platform matrix (any two platforms with different auth paths, e.g.
macOS + Windows): items 1-3 passing proves both OAuth clients land in the
same appDataFolder (same Google Cloud project).
