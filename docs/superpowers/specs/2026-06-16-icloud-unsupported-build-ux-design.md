# Honest iCloud Availability in Unsupported macOS Builds

- Date: 2026-06-16
- Status: Approved (design)
- Branch: `feat/icloud-unsupported-build-ux`

## Problem

On the macOS **No-Sandbox / Developer ID GitHub-distribution build**, tapping the iCloud
cloud-sync provider fails with:

> iCloud connection failed: CloudStorageException: iCloud is not available. Please sign in
> to iCloud in System Settings.

This message is wrong. The user is signed into iCloud, the container
(`iCloud.app.submersion`) is healthy and syncing at the daemon level, and the sandboxed
dev build can reach it fine.

### Verified root cause

Apple only honors iCloud entitlements (`com.apple.developer.ubiquity-container-identifiers`,
CloudKit) for **Mac App Store** (sandboxed) or **Development** (dev cert + provisioning
profile) builds. A **Developer ID** build — required for direct/GitHub distribution —
**cannot use iCloud at all**. Accordingly, `macos/Runner/ReleaseNoSandbox.entitlements`
deliberately omits all iCloud keys, and the project ships **S3-Compatible Storage** as the
sync path for these builds.

**Prerequisite (2026-06-16): S3 credential storage had to be fixed first.** Shipping
S3 "instead of iCloud" only holds once S3 can persist credentials in this build --
which it could not. `S3CredentialsStore` uses `flutter_secure_storage`, whose macOS
default (data-protection) keychain fails here with the *same root class* of error,
`errSecMissingEntitlement` (-34018): the ad-hoc signature in `build_nosandbox_macos.sh`
(`codesign --sign -`) carries no team `application-identifier`, hence no keychain
access group. Fixed by (a) a runtime fallback to the legacy file-based keychain on
-34018 (shared `withKeychainFallback` helper, also applied to the media credential/
bookmark stores), and (b) declaring `keychain-access-groups` in all four entitlements
files. The change is confined to the credential stores -- not the sync engine or
container I/O paths -- so it stays consistent with the Non-Goals below.

With no ubiquity entitlement, `FileManager.url(forUbiquityContainerIdentifier:)` returns
`nil` immediately. The Dart layer (`icloud_storage_provider.dart` `authenticate()`)
interprets any `nil` container as "not signed in" and throws a hardcoded, incorrect message.

Two real defects:
1. The app **offers** iCloud as a tappable provider in a build that physically cannot use it
   (the tile is gated by `Platform.isIOS || Platform.isMacOS`, not by real capability —
   `cloud_sync_page.dart:424`).
2. When it fails, it **misreports the reason** ("sign in to iCloud").

## Goals

- The iCloud tile reflects **real runtime capability**, not just the OS.
- When iCloud is unsupported in the build, show the tile **disabled** with an honest subtitle
  that names the alternative inline.
- Distinguish, for messaging, three states: `available`, `signedOut`, `unsupported`.
- Keep all changes localized across `en` + the 10 non-`en` locales.

## Non-Goals (YAGNI)

- No compile-time `--dart-define` flavor flag (CI/script coordination, can drift).
- No exception-type refactor; the provider keeps a safe English fallback exception.
- No "Set up S3" nudge dialog or App Store deep-link.
- No change to the sync engine, S3 provider, or actual container I/O paths.

## Design Overview

A new **non-blocking native status call** reports `available | signedOut | unsupported`.
A `FutureProvider` exposes it to the cloud-sync page, which uses it as the single source of
truth for both the tile's enabled state and the failure message wording.

```
ICloudContainerHandler (Swift, macOS + iOS)
   getICloudAvailability  ──►  "available" | "signedOut" | "unsupported"
            │
ICloudNativeService.getAvailability() (Dart)  ──►  enum ICloudAvailability
            │
iCloudAvailabilityProvider (FutureProvider<ICloudAvailability>)
            │
cloud_sync_page.dart  ──►  tile enabled/disabled + subtitle + localized snackbar
```

## Components

### 1. Native — `macos/Runner/ICloudContainerHandler.swift` (+ mirror in `ios/Runner/ICloudContainerHandler.swift`)

Add a method-channel case `getICloudAvailability`. Logic (fast, no
`url(forUbiquityContainerIdentifier:)`, so no timeout needed):

```
hasUbiquityEntitlement()?
  ├─ no  → "unsupported"
  └─ yes → (ubiquityIdentityToken != nil) ? "available" : "signedOut"
```

`hasUbiquityEntitlement()` uses `SecTaskCreateFromSelf(nil)` +
`SecTaskCopyValueForEntitlement(task, "com.apple.developer.ubiquity-container-identifiers", nil)`,
returning `true` when the value is a non-empty array. Work runs on a background queue and
replies on the main thread, matching the file's existing style. iOS uses identical logic
(it will normally return `available`/`signedOut`, never `unsupported`).

### 2. Dart — `lib/core/services/cloud_storage/icloud_native_service.dart`

```dart
enum ICloudAvailability { available, signedOut, unsupported, unknown }

static Future<ICloudAvailability> getAvailability() async {
  if (!Platform.isIOS && !Platform.isMacOS) return ICloudAvailability.unsupported;
  try {
    final status = await _channel.invokeMethod<String>('getICloudAvailability');
    return switch (status) {
      'available' => ICloudAvailability.available,
      'signedOut' => ICloudAvailability.signedOut,
      'unsupported' => ICloudAvailability.unsupported,
      _ => ICloudAvailability.unknown,
    };
  } catch (_) {
    return ICloudAvailability.unknown; // MissingPluginException / platform error
  }
}
```

`unknown` is the graceful-degradation bucket: an un-mirrored platform or any channel error
falls here and is treated optimistically (tile stays enabled).

### 3. Dart — `lib/core/services/cloud_storage/icloud_storage_provider.dart`

`authenticate()` keeps throwing `CloudStorageException` with a safe English fallback (it is
in `core/services`, with no `BuildContext`/l10n access). The UI owns user-facing wording.
No behavioral regression: the message is only surfaced through the page, which overrides it
with a localized, status-accurate string.

### 4. Riverpod — `lib/features/settings/presentation/providers/sync_providers.dart`

```dart
final iCloudAvailabilityProvider =
    FutureProvider<ICloudAvailability>((ref) => ICloudNativeService.getAvailability());
```

### 5. UI — `lib/features/settings/presentation/pages/cloud_sync_page.dart`

- Watch `iCloudAvailabilityProvider`. Resolve the iCloud tile:
  - `unsupported` → `enabled = false`, subtitle = localized unsupported text.
  - `available` / `signedOut` / `unknown` / loading → `enabled = true`, normal subtitle.
- Extend `_buildProviderTile` with an optional `String? disabledSubtitle` shown when
  `!isAvailable` (defaulting to the localized "not available on this platform"); also
  localize that existing hardcoded string (`cloud_sync_page.dart:450`).
- In the `_selectProvider` failure `catch`, for the iCloud provider map the current
  availability to a **localized** message instead of the raw `$e`:
  - `signedOut` → "Please sign in to iCloud in System Settings."
  - `unsupported` → unsupported message (defensive; tile is disabled).
  - `unknown` / other → "Couldn't reach iCloud. Please try again."
  - genuine `available`-but-failed → existing `connectionFailed` with `$e`.

### 6. l10n — `lib/l10n/arb/app_*.arb` (en + 10) then regenerate

New keys (English values):
- `settings_cloudSync_provider_icloud_unsupportedSubtitle`:
  "Not available in this build — use S3 or the App Store version"
- `settings_cloudSync_error_icloudUnsupported`:
  "iCloud sync isn't available in this build of Submersion. Use S3 sync, or the App Store version."
- `settings_cloudSync_error_icloudSignedOut`:
  "iCloud is not available. Please sign in to iCloud in System Settings."
- `settings_cloudSync_error_icloudUnknown`:
  "Couldn't reach iCloud. Please try again."

Reuse existing `settings_cloudSync_provider_notAvailable` ("Not available on this platform")
for the platform-disabled subtitle. All new keys translated into every non-`en` locale;
run `flutter gen-l10n` (or the project's codegen) so `app_localizations_*.dart` regenerate.

## Data Flow

1. Page builds → watches `iCloudAvailabilityProvider`.
2. Provider calls `ICloudNativeService.getAvailability()` → native `getICloudAvailability`.
3. Native returns a status string in well under a second (entitlement + token read only).
4. Page renders the tile per status; on tap failure it localizes the message from status.

## Error Handling / Edge Cases

- **Channel missing / errors** → `unknown` → tile enabled (optimistic); failure path shows
  the generic "couldn't reach iCloud" message. No crash, no dead UI.
- **Signed-out on a supported build** → tile stays enabled; tapping shows the (now correct)
  sign-in message.
- **Non-Apple platforms** → `unsupported` from the Dart guard; tile shows the existing
  platform-not-available subtitle (unchanged behavior).
- Native status call does **not** invoke `url(forUbiquityContainerIdentifier:)`, so it cannot
  hang; the existing 10s-timeout path is untouched and only used for real container access.

## Testing Strategy (TDD)

Write tests before implementation.

- **Unit** `test/core/services/cloud_storage/icloud_native_service_test.dart`: mock the
  `MethodChannel`; assert `getAvailability()` maps `available`/`signedOut`/`unsupported`,
  an unrecognized string, and a thrown `PlatformException`/`MissingPluginException` →
  the correct `ICloudAvailability` value.
- **Widget** `test/features/settings/.../cloud_sync_icloud_tile_test.dart`: override
  `iCloudAvailabilityProvider` with each state; assert the iCloud tile is
  disabled + shows the unsupported subtitle for `unsupported`, and enabled for
  `available`/`signedOut`. Tests assert rendering only (no taps), so they are host-platform
  independent; any test that *taps* the iCloud tile must be guarded Apple-only
  (`skip: !(Platform.isIOS || Platform.isMacOS)`).
- **Native** entitlement/token branches are environment-dependent → verified manually on
  device (see below), not in unit tests.

## Manual Verification

1. No-sandbox build (`scripts/release/build_nosandbox_macos.sh`): iCloud tile is disabled
   with the unsupported subtitle; S3 still works.
2. Sandboxed dev build (`flutter run -d macos`): iCloud tile enabled; connects when signed
   in; shows the correct sign-in message when signed out of iCloud in System Settings.
3. iPhone build: iCloud tile enabled and connects (regression check).

## Out of Scope / Follow-ups

- Surfacing the same honest messaging for Windows/Linux is unnecessary (iCloud never
  applies there; existing platform text covers it).
- A future "Set up S3" one-tap shortcut from the disabled iCloud tile could improve guidance
  but is deferred.
