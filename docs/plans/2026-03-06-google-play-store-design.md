# Google Play Store Publication Design

> **Date:** 2026-03-06
> **Status:** Approved
> **Approach:** Single-phase, comprehensive launch

## Overview

Publish Submersion to the Google Play Store with automated Fastlane uploads, a privacy policy, complete store listing, and data safety compliance. Health Connect is gated for the initial release and will be enabled after Google grants restricted permission approval.

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Upload workflow | Automated via Fastlane | Mirrors iOS App Store setup; sustainable for ongoing releases |
| Timeline | No rush, do it right | Comprehensive preparation before first submission |
| Health Connect | Disabled initially, add later | Avoids restricted permission rejection; unblocks initial release |
| Privacy policy hosting | GitHub markdown (`PRIVACY.md` in repo root) | Simple, version-controlled, publicly accessible |
| Play App Signing | Let Google generate signing key | Existing keystore becomes upload key; no migration needed |

## Section 1: Health Connect Gating

The `health` package (v13.3.0) compiles into all builds. On Android, it uses Health Connect APIs which require Google's restricted permission approval. The initial Play Store build must not request Health Connect permissions.

**Implementation:**

- Add `--dart-define=HEALTH_CONNECT_ENABLED=false` to the AAB build command in CI
- The APK build (GitHub distribution) and iOS builds are unaffected
- In Dart code, check `const bool.fromEnvironment('HEALTH_CONNECT_ENABLED', defaultValue: true)` to conditionally hide wearable import UI on Android when disabled
- The `health` package remains in `pubspec.yaml` (removing it would break iOS HealthKit)
- Verify whether the `health` package auto-merges Health Connect permissions into `AndroidManifest.xml` and override with `tools:node="remove"` if needed

**Rationale:** Google reviews whether the app requests Health Connect permissions at runtime, not whether the package is in the dependency tree. Gating the UI entry points prevents permission requests.

**Future:** Once Health Connect approval is granted, remove the dart define gate and ship with full functionality.

## Section 2: Privacy Policy

Create `PRIVACY.md` in the repo root. Linked in Play Store listing via GitHub rendered URL: `https://github.com/submersion-app/submersion/blob/main/PRIVACY.md`

**Required sections:**

| Section | Content |
|---------|---------|
| Data collected | Location (dive site GPS), photos/videos (dive attachments), personal info (diver name, cert info, buddy contacts), device info (dive computer data) |
| Data storage | All data stored locally on-device in SQLite. No server-side storage. |
| Cloud backup | Google Drive backup is user-initiated and optional. Data goes to user's own Google Drive, not a Submersion server. |
| Data sharing | No data shared with third parties. No analytics, no telemetry, no ads. |
| Health data | (Future) HealthKit on iOS, Health Connect on Android -- read-only, never transmitted off-device. Not enabled on Android initially. |
| Permissions | Why each permission is needed (Bluetooth for dive computers, location for dive sites, camera/photos for dive media, contacts for buddy picker, notifications for gear reminders) |
| Data deletion | Users can delete any/all data within the app. Uninstalling removes all local data. |
| Children | App is not directed at children under 13 |
| Changes | Policy may be updated; changes reflected with a "last updated" date |
| Contact | Email address for privacy questions |

## Section 3: Fastlane for Android

Mirror the iOS Fastlane setup with `android/fastlane/` for automated Play Store uploads.

**Files to create:**

| File | Purpose |
|------|---------|
| `android/Gemfile` | Ruby deps: `fastlane` |
| `android/fastlane/Appfile` | Package name: `app.submersion` |
| `android/fastlane/Fastfile` | Two lanes: `beta` and `release` |

**Lanes:**

- **`beta`** -- Uploads AAB to internal testing track. Triggered by pre-release tags (e.g., `v1.2.0-beta.1`).
- **`release`** -- Uploads AAB to production track with `rollout: 0.2` (20% staged rollout). Triggered by clean tags (e.g., `v1.2.0`).

**Authentication:**

1. Create a Google Cloud service account with Google Play Developer API access
2. Grant it "Release manager" role in Play Console > API access
3. Base64-encode the JSON key and store as `GOOGLE_PLAY_SERVICE_ACCOUNT_KEY` GitHub secret

**CI integration:** Add Fastlane upload steps to the `build-android` job in `release.yml`, after the AAB build. Lane selection based on tag pattern (beta vs release), matching the existing iOS logic.

The APK build and GitHub Release attachment remain unchanged. Fastlane only handles the AAB-to-Play-Store path.

## Section 4: Play Store Listing & Data Safety

### Store Listing

| Field | Value |
|-------|-------|
| App name | Submersion Dive Log |
| Short description | Open-source dive log for scuba divers. Track dives, gear, sites, and stats. |
| Full description | Detailed feature list: dive logging, dive computer download (BLE), site management with GPS/maps, gear tracking with service reminders, statistics, dive planning, cloud backup to Google Drive, import/export (UDDF, Subsurface, Garmin FIT, CSV, PDF). Emphasize: free, open-source, no ads, no accounts required, privacy-first. |
| Category | Sports |
| Content rating | Everyone (E) / PEGI 3 -- no violence, mature content, gambling, or user-generated content sharing |

### Store Assets (manual creation required)

| Asset | Spec |
|-------|------|
| Hi-res icon | 512x512 PNG |
| Feature graphic | 1024x500 PNG |
| Phone screenshots | Min 2, 16:9 or 9:16, 320-3840px. Key screens: dive list, dive detail with profile, site map, stats, gear |
| Tablet screenshots | Optional but recommended |

### Data Safety Declaration

| Question | Answer |
|----------|--------|
| Does your app collect or share user data? | Collects; does not share |
| Location | Collected (approximate & precise) for dive sites. Not shared. On-device only. User-deletable. |
| Photos/videos | Collected (user-selected) for dive attachments. Not shared. On-device only. |
| Personal info | Collected (name, contacts for buddy picker). Not shared. On-device only. |
| Files and docs | Collected (dive log imports). Not shared. On-device only. |
| App activity | Not collected |
| Data encrypted in transit? | Yes (Google Drive uses HTTPS) |
| Users can request deletion? | Yes (delete within app or uninstall) |
| Families policy? | No (not targeted at children) |

### Permission Justifications

| Permission | Justification |
|------------|---------------|
| `BLUETOOTH_SCAN/CONNECT` | Required to discover and communicate with BLE dive computers for downloading dive logs |
| `ACCESS_FINE_LOCATION` | Used to tag dive sites with GPS coordinates (only on Android 11 and below for BLE scanning) |
| `READ_MEDIA_IMAGES/VIDEO` | Allows users to attach photos and videos from their gallery to dive log entries |
| `ACCESS_MEDIA_LOCATION` | Reads GPS coordinates from photo EXIF data to suggest dive site locations |
| `SCHEDULE_EXACT_ALARM` | Sends precise gear maintenance reminders (e.g., regulator service due dates) |
| `POST_NOTIFICATIONS` | Delivers gear service reminder notifications |

## Section 5: Play App Signing & Release Flow

### Play App Signing

Let Google generate the app signing key when enrolling during first upload. The existing keystore (in CI secrets as `ANDROID_KEYSTORE_BASE64`) becomes the upload key.

### Release Flow

```
Developer pushes tag
        |
   v1.2.17-beta.1  -->  Fastlane beta lane  -->  Internal testing track
        |
   (test on device, verify)
        |
   v1.2.17          -->  Fastlane release lane -->  Production (20% staged rollout)
        |
   (monitor for crashes)
        |
   Promote to 100% in Play Console
```

### First-Time Bootstrap

Before Fastlane can upload, the very first AAB must be manually uploaded to Play Console to establish the app. This is a Google Play API limitation. All subsequent uploads are automated.

## Implementation Order

1. Gate Health Connect for Android AAB builds
2. Write `PRIVACY.md`
3. Set up Android Fastlane (`Gemfile`, `Appfile`, `Fastfile`)
4. Integrate Fastlane into `release.yml` CI workflow
5. Create Google Cloud service account and configure GitHub secret
6. Enroll in Play App Signing and manually upload first AAB
7. Fill out store listing (description, screenshots, feature graphic)
8. Complete data safety declaration
9. Complete content rating questionnaire
10. Submit to internal testing track
11. Verify on physical device
12. Promote to production with staged rollout
