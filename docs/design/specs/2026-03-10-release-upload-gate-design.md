# Release Workflow Upload Gate

Gate store uploads behind all platform builds succeeding, preventing partial releases.

## Problem

The release workflow uploads to Apple App Store and Google Play **inline within build jobs**. If one platform's build fails after another has already uploaded, the app stores receive an inconsistent release — some platforms updated, others not.

## Solution

Separate store uploads into dedicated jobs that depend on ALL 5 build jobs via `needs:`. No upload runs unless every build succeeds.

## Dependency Graph

```text
build-macos ──────┐                    ┌── upload-macos ──┐
build-windows ────┤                    │                  │
build-linux ──────┼── gate ──┬─────────┼── upload-ios ────┼── create-release ── validate
build-android ────┤          │         │                  │
build-ios ────────┘          │         └── upload-android ┘
                             │
                             └── generate-appcast ────────────┘
```

`generate-appcast` runs in parallel with upload jobs (it only needs build artifacts, not upload results). `create-release` waits for both `generate-appcast` and all uploads.

## Recovery Model

Best-effort with gate: if a build fails, no uploads run. If all builds pass but an upload fails, re-run the failed upload job from the GitHub Actions UI. Re-run must happen within the 5-day artifact retention window.

## Changes

### 1. Build Job Changes

**build-macos:**

- Change `fastlane "$FASTLANE_LANE"` (release/beta) to `fastlane build` (build-only)
- Remove: "Determine Fastlane lane", "Upload to App Store / TestFlight" steps
- Add: Upload `macos/build/Submersion.pkg` as new `macos-pkg` artifact (this artifact does not exist today — the pkg is currently consumed inline by the Fastlane upload step)
- Keep: Ruby, certificates, API key (needed for `build_mac_app` automatic provisioning)
- Keep: "Restore Release.xcconfig for App Store build" step (needed before `fastlane build`)

**build-ios:**

- Change `fastlane "$FASTLANE_LANE"` to `fastlane build` (build-only)
- Remove: "Determine Fastlane lane" step, "Build and upload iOS" step
- Add: New step calling `fastlane build` (build-only, no upload)
- Keep: Certificates, API key (needed for `build_ios_app` signing)
- Keep: IPA rename step and `ios-ipa` artifact upload (already exist)

**build-android:**

- Remove: "Setup Google Play service account key", "Upload to Google Play" steps
- Remove: Google Play key from "Cleanup sensitive files"
- Keep: AAB artifact upload (already exists as `android-aab`)

### 2. New Upload Jobs

All three declare `needs: [build-macos, build-windows, build-linux, build-android, build-ios]`.

Upload jobs are lightweight — they do NOT require Flutter, Xcode, or signing certificates. Only Ruby (for Fastlane) and the API key / service account key are needed.

Each upload job preserves the existing 2-attempt retry loop (with 30s delay) from the current inline upload steps, so transient API failures self-heal without manual re-runs.

**upload-macos** (`macos-15`, 20 min timeout):

1. Checkout repository (for Gemfile)
2. Setup Ruby (`bundler-cache: true`, `working-directory: macos`)
3. Decode App Store Connect API key to `macos/fastlane/AuthKey.p8`
4. Download `macos-pkg` artifact to `macos/build/`
5. Determine lane (beta vs release based on tag pattern)
6. Call `fastlane upload_only` or `fastlane upload_testflight_only` with `pkg:` option
7. Cleanup API key

Why `macos-15`: Fastlane's `upload_to_app_store` uses `iTMSTransporter` which requires macOS.

**upload-ios** (`macos-15`, 20 min timeout):

1. Checkout repository (for Gemfile)
2. Setup Ruby (`bundler-cache: true`, `working-directory: ios`)
3. Decode App Store Connect API key to `ios/fastlane/AuthKey.p8`
4. Download `ios-ipa` artifact
5. Locate IPA via glob (`Submersion-*-iOS.ipa`) — the build job renames it to include the version tag
6. Determine lane (beta vs release based on tag pattern)
7. Call `fastlane upload_only` or `fastlane upload_testflight_only` with `ipa:` option pointing to the resolved path
8. Cleanup API key

**upload-android** (`ubuntu-latest`, 15 min timeout):

1. Checkout repository (for Gemfile)
2. Setup Ruby (`bundler-cache: true`, `working-directory: android`)
3. Decode Google Play service account JSON key
4. Download `android-aab` artifact to workspace root
5. Call existing `fastlane upload` lane (the `find_aab` helper resolves `../../Submersion-*-Android.aab` relative to `android/fastlane/`, which correctly resolves to the workspace root)
6. Cleanup service account key

### 3. Fastlane Lane Additions

**macos/fastlane/Fastfile** — add two lanes:

- `upload_only`: accepts `pkg:` option (default `./build/Submersion.pkg`), calls `upload_to_app_store`
- `upload_testflight_only`: accepts `pkg:` option, calls `upload_to_testflight` with `skip_waiting_for_build_processing: true`

**ios/fastlane/Fastfile** — add two lanes:

- `upload_only`: accepts `ipa:` option (default `./build/Submersion.ipa`), calls `upload_to_app_store`
- `upload_testflight_only`: accepts `ipa:` option, calls `upload_to_testflight` with `skip_waiting_for_build_processing: true`

**android/fastlane/Fastfile** — no changes. Existing `upload` lane works standalone.

### 4. Downstream Dependency Update

`generate-appcast` keeps its current `needs:` (all 5 build jobs only). It does not need upload results — it only uses build artifacts and Sparkle EdDSA signatures.

`create-release` adds upload jobs to its `needs:`:

```yaml
needs: [build-macos, build-windows, build-linux, build-android, build-ios, generate-appcast, upload-macos, upload-ios, upload-android]
```

This ensures the GitHub Release is not created until both appcast generation and all store uploads succeed. `validate-release` remains unchanged (chains off `create-release`).

### 5. Error Handling

- **Build failure**: All uploads and `generate-appcast` skipped (via `needs:`), no GitHub Release created
- **Upload failure**: Other uploads still run; `create-release` blocked; re-run failed upload job within 5-day retention window
- **generate-appcast failure**: `create-release` blocked; re-run from generate-appcast step
- **No new secrets or permissions needed**

## Files Modified

| File | Change |
|------|--------|
| `.github/workflows/release.yml` | Strip uploads from build jobs, add `macos-pkg` artifact, add 3 upload jobs, update `create-release` needs |
| `macos/fastlane/Fastfile` | Add `upload_only` and `upload_testflight_only` lanes |
| `ios/fastlane/Fastfile` | Add `upload_only` and `upload_testflight_only` lanes |
