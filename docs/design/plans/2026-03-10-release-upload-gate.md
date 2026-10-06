# Release Upload Gate Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Gate store uploads (Apple App Store, Google Play) behind all 5 platform builds succeeding, preventing partial releases.

**Architecture:** Extract store upload steps from build-macos, build-ios, and build-android into 3 new dedicated upload jobs. Each upload job declares `needs:` on all 5 build jobs, creating an all-or-nothing gate. Build artifacts are passed via `actions/upload-artifact` / `actions/download-artifact`. New upload-only Fastlane lanes avoid rebuilding.

**Tech Stack:** GitHub Actions YAML, Fastlane (Ruby), App Store Connect API, Google Play API

**Spec:** `docs/superpowers/specs/2026-03-10-release-upload-gate-design.md`

---

## Chunk 1: Fastlane Upload-Only Lanes

Add upload-only lanes to macOS and iOS Fastfiles. These are independent of the workflow changes and can be committed separately. Android's existing `upload` lane already works standalone.

### Task 1: Add upload-only lanes to macOS Fastfile

**Files:**

- Modify: `macos/fastlane/Fastfile:297-322` (insert before `full_release` lane)

- [ ] **Step 1: Add `upload_only` and `upload_testflight_only` lanes**

Insert the following two lanes after the `release` lane (line 315) and before `full_release` (line 317) in `macos/fastlane/Fastfile`:

```ruby
  desc "Upload pre-built pkg to Mac App Store (no rebuild)"
  lane :upload_only do |options|
    api_key = load_api_key
    pkg_path = options[:pkg] || "./build/Submersion.pkg"

    UI.message("Uploading pkg to Mac App Store: #{pkg_path}")
    upload_to_app_store(
      api_key: api_key,
      pkg: pkg_path,
      skip_screenshots: true,
      skip_metadata: true,
      submit_for_review: false,
      automatic_release: false,
      precheck_include_in_app_purchases: false
    )
    UI.success("macOS build uploaded to Mac App Store!")
  end

  desc "Upload pre-built pkg to TestFlight (no rebuild)"
  lane :upload_testflight_only do |options|
    api_key = load_api_key
    pkg_path = options[:pkg] || "./build/Submersion.pkg"

    UI.message("Uploading pkg to TestFlight: #{pkg_path}")
    upload_to_testflight(
      api_key: api_key,
      pkg: pkg_path,
      skip_waiting_for_build_processing: true
    )
    UI.success("macOS build uploaded to TestFlight!")
  end
```

- [ ] **Step 2: Update the Fastfile header comments**

Add the new lanes to the usage comment block at the top of `macos/fastlane/Fastfile` (around lines 2-13):

```ruby
#   bundle exec fastlane upload_only           # Upload pre-built pkg to App Store
#   bundle exec fastlane upload_testflight_only # Upload pre-built pkg to TestFlight
```

Also add to the `lanes_help` lane output (after line 367, the `full_release` entry):

```ruby
    UI.message("    upload_only           - Upload pre-built pkg to App Store (CI)")
    UI.message("    upload_testflight_only - Upload pre-built pkg to TestFlight (CI)")
```

- [ ] **Step 3: Verify Fastfile syntax**

Run: `cd macos && ruby -c fastlane/Fastfile`
Expected: `Syntax OK`

### Task 2: Add upload-only lanes to iOS Fastfile

**Files:**

- Modify: `ios/fastlane/Fastfile:215-240` (insert before `full_release` lane)

- [ ] **Step 1: Add `upload_only` and `upload_testflight_only` lanes**

Insert the following two lanes after the `release` lane (line 233) and before `full_release` (line 235) in `ios/fastlane/Fastfile`:

```ruby
  desc "Upload pre-built IPA to App Store (no rebuild)"
  lane :upload_only do |options|
    api_key = load_api_key
    ipa_path = options[:ipa] || "./build/Submersion.ipa"

    UI.message("Uploading IPA to App Store Connect: #{ipa_path}")
    upload_to_app_store(
      api_key: api_key,
      ipa: ipa_path,
      skip_screenshots: true,
      skip_metadata: true,
      submit_for_review: false,
      automatic_release: false,
      precheck_include_in_app_purchases: false
    )
    UI.success("iOS build uploaded to App Store Connect!")
  end

  desc "Upload pre-built IPA to TestFlight (no rebuild)"
  lane :upload_testflight_only do |options|
    api_key = load_api_key
    ipa_path = options[:ipa] || "./build/Submersion.ipa"

    UI.message("Uploading IPA to TestFlight: #{ipa_path}")
    upload_to_testflight(
      api_key: api_key,
      ipa: ipa_path,
      skip_waiting_for_build_processing: true
    )
    UI.success("iOS build uploaded to TestFlight!")
  end
```

- [ ] **Step 2: Update the Fastfile header comments**

Add the new lanes to the usage comment block at the top of `ios/fastlane/Fastfile` (around lines 2-13):

```ruby
#   bundle exec fastlane upload_only           # Upload pre-built IPA to App Store
#   bundle exec fastlane upload_testflight_only # Upload pre-built IPA to TestFlight
```

Also add to the `lanes_help` lane output (after line 298, the `full_release` entry):

```ruby
    UI.message("    upload_only           - Upload pre-built IPA to App Store (CI)")
    UI.message("    upload_testflight_only - Upload pre-built IPA to TestFlight (CI)")
```

- [ ] **Step 3: Verify Fastfile syntax**

Run: `cd ios && ruby -c fastlane/Fastfile`
Expected: `Syntax OK`

### Task 3: Commit Fastlane changes

- [ ] **Step 1: Commit**

```bash
git add macos/fastlane/Fastfile ios/fastlane/Fastfile
git commit -m "feat: add upload-only Fastlane lanes for gated releases

Add upload_only and upload_testflight_only lanes to both macOS and iOS
Fastfiles. These lanes accept pre-built pkg/ipa paths and upload without
rebuilding, enabling the release workflow to separate build and upload
into distinct jobs."
```

---

## Chunk 2: Workflow Restructuring

Strip inline store uploads from the 3 build jobs, add 3 new upload jobs gated on all builds, and update the `create-release` dependency chain.

All changes in this chunk are to `.github/workflows/release.yml`. They must be committed atomically since stripping uploads without adding upload jobs would break the release pipeline.

### Task 4: Strip upload steps from build-macos

**Files:**

- Modify: `.github/workflows/release.yml:281-314`

- [ ] **Step 1: Replace "Determine Fastlane lane" and "Upload to App Store / TestFlight" with build-only step**

Remove lines 281-310 (the "Determine Fastlane lane" step and "Upload to App Store / TestFlight" step).

Replace with:

```yaml
      - name: Build Mac App Store package
        working-directory: macos
        env:
          APP_STORE_CONNECT_API_KEY_KEY_ID: ${{ secrets.APP_STORE_CONNECT_API_KEY_KEY_ID }}
          APP_STORE_CONNECT_API_KEY_ISSUER_ID: ${{ secrets.APP_STORE_CONNECT_API_KEY_ISSUER_ID }}
          APP_STORE_CONNECT_API_KEY_KEY_FILEPATH: fastlane/AuthKey.p8
        run: bundle exec fastlane build

      - name: Upload Mac App Store pkg artifact
        uses: actions/upload-artifact@v7
        with:
          name: macos-pkg
          path: macos/build/Submersion.pkg
          retention-days: 5
          if-no-files-found: error
```

Keep the existing "Cleanup sensitive files" step (lines 312-314) unchanged — it still needs to clean up `AuthKey.p8`.

### Task 5: Strip upload steps from build-ios

**Files:**

- Modify: `.github/workflows/release.yml:703-732`

- [ ] **Step 1: Remove "Determine Fastlane lane" step and replace "Build and upload iOS" with build-only**

Remove lines 703-732 (the "Determine Fastlane lane" step and "Build and upload iOS" step).

Replace with:

```yaml
      - name: Build iOS App Store package
        working-directory: ios
        env:
          APP_STORE_CONNECT_API_KEY_KEY_ID: ${{ secrets.APP_STORE_CONNECT_API_KEY_KEY_ID }}
          APP_STORE_CONNECT_API_KEY_ISSUER_ID: ${{ secrets.APP_STORE_CONNECT_API_KEY_ISSUER_ID }}
          APP_STORE_CONNECT_API_KEY_KEY_FILEPATH: fastlane/AuthKey.p8
        run: bundle exec fastlane build
```

Keep the existing "Rename IPA", "Upload iOS artifact", and "Cleanup sensitive files" steps (lines 734-751) unchanged.

### Task 6: Strip upload steps from build-android

**Files:**

- Modify: `.github/workflows/release.yml:504-586`

- [ ] **Step 1: Remove Ruby setup, Google Play key setup, and upload steps**

Remove these steps:

- Lines 504-509: "Setup Ruby" (no longer needed — was only for Fastlane upload)
- Lines 556-562: "Setup Google Play service account key"
- Lines 564-579: "Upload to Google Play"

- [ ] **Step 2: Remove Google Play key from cleanup**

Change the "Cleanup sensitive files" step (lines 581-586) from:

```yaml
      - name: Cleanup sensitive files
        if: always()
        run: |
          rm -f android/app/release.keystore
          rm -f android/key.properties
          rm -f android/fastlane/play-store-key.json
```

To:

```yaml
      - name: Cleanup sensitive files
        if: always()
        run: |
          rm -f android/app/release.keystore
          rm -f android/key.properties
```

### Task 7: Add upload-macos job

**Files:**

- Modify: `.github/workflows/release.yml` (insert after build-ios job, before generate-appcast)

- [ ] **Step 1: Add upload-macos job**

Insert the following job after the `build-ios` job section and before the `generate-appcast` section:

```yaml
  # ============================================================================
  # Upload macOS to App Store (gated on all builds)
  # ============================================================================
  upload-macos:
    name: Upload macOS to App Store
    runs-on: macos-15
    needs: [build-macos, build-windows, build-linux, build-android, build-ios]
    timeout-minutes: 20

    steps:
      - name: Checkout repository
        uses: actions/checkout@v6

      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.2'
          bundler-cache: true
          working-directory: macos

      - name: Setup App Store Connect API Key
        env:
          APP_STORE_CONNECT_API_KEY_KEY: ${{ secrets.APP_STORE_CONNECT_API_KEY_KEY }}
        run: |
          mkdir -p macos/fastlane
          echo "$APP_STORE_CONNECT_API_KEY_KEY" | base64 --decode > macos/fastlane/AuthKey.p8

      - name: Download macOS pkg artifact
        uses: actions/download-artifact@v8
        with:
          name: macos-pkg
          path: macos/build

      - name: Determine Fastlane lane
        id: lane
        env:
          TAG_NAME: ${{ github.ref_name }}
        run: |
          if echo "$TAG_NAME" | grep -qE '\-(alpha|beta|rc)'; then
            echo "lane=upload_testflight_only" >> "$GITHUB_OUTPUT"
          else
            echo "lane=upload_only" >> "$GITHUB_OUTPUT"
          fi

      - name: Upload to App Store / TestFlight
        working-directory: macos
        env:
          FASTLANE_LANE: ${{ steps.lane.outputs.lane }}
          APP_STORE_CONNECT_API_KEY_KEY_ID: ${{ secrets.APP_STORE_CONNECT_API_KEY_KEY_ID }}
          APP_STORE_CONNECT_API_KEY_ISSUER_ID: ${{ secrets.APP_STORE_CONNECT_API_KEY_ISSUER_ID }}
          APP_STORE_CONNECT_API_KEY_KEY_FILEPATH: fastlane/AuthKey.p8
        run: |
          for attempt in 1 2; do
            if bundle exec fastlane "$FASTLANE_LANE"; then
              break
            fi
            if [ "$attempt" -eq 2 ]; then
              echo "Fastlane upload failed after 2 attempts"
              exit 1
            fi
            echo "Fastlane attempt $attempt failed, retrying in 30s..."
            sleep 30
          done

      - name: Cleanup sensitive files
        if: always()
        run: rm -f macos/fastlane/AuthKey.p8
```

### Task 8: Add upload-ios job

**Files:**

- Modify: `.github/workflows/release.yml` (insert after upload-macos job)

- [ ] **Step 1: Add upload-ios job**

Insert the following job after `upload-macos`:

```yaml
  # ============================================================================
  # Upload iOS to App Store (gated on all builds)
  # ============================================================================
  upload-ios:
    name: Upload iOS to App Store
    runs-on: macos-15
    needs: [build-macos, build-windows, build-linux, build-android, build-ios]
    timeout-minutes: 20

    steps:
      - name: Checkout repository
        uses: actions/checkout@v6

      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.2'
          bundler-cache: true
          working-directory: ios

      - name: Setup App Store Connect API Key
        env:
          APP_STORE_CONNECT_API_KEY_KEY: ${{ secrets.APP_STORE_CONNECT_API_KEY_KEY }}
        run: |
          mkdir -p ios/fastlane
          echo "$APP_STORE_CONNECT_API_KEY_KEY" | base64 --decode > ios/fastlane/AuthKey.p8

      - name: Download iOS IPA artifact
        uses: actions/download-artifact@v8
        with:
          name: ios-ipa

      - name: Determine Fastlane lane
        id: lane
        env:
          TAG_NAME: ${{ github.ref_name }}
        run: |
          if echo "$TAG_NAME" | grep -qE '\-(alpha|beta|rc)'; then
            echo "lane=upload_testflight_only" >> "$GITHUB_OUTPUT"
          else
            echo "lane=upload_only" >> "$GITHUB_OUTPUT"
          fi

      - name: Upload to App Store / TestFlight
        working-directory: ios
        env:
          FASTLANE_LANE: ${{ steps.lane.outputs.lane }}
          APP_STORE_CONNECT_API_KEY_KEY_ID: ${{ secrets.APP_STORE_CONNECT_API_KEY_KEY_ID }}
          APP_STORE_CONNECT_API_KEY_ISSUER_ID: ${{ secrets.APP_STORE_CONNECT_API_KEY_ISSUER_ID }}
          APP_STORE_CONNECT_API_KEY_KEY_FILEPATH: fastlane/AuthKey.p8
        run: |
          IPA_PATH=$(ls $GITHUB_WORKSPACE/Submersion-*-iOS.ipa 2>/dev/null | head -1)
          if [ -z "$IPA_PATH" ]; then
            echo "Error: No IPA artifact found"
            ls -la $GITHUB_WORKSPACE/
            exit 1
          fi
          echo "Found IPA: $IPA_PATH"
          for attempt in 1 2; do
            if bundle exec fastlane "$FASTLANE_LANE" ipa:"$IPA_PATH"; then
              break
            fi
            if [ "$attempt" -eq 2 ]; then
              echo "Fastlane upload failed after 2 attempts"
              exit 1
            fi
            echo "Fastlane attempt $attempt failed, retrying in 30s..."
            sleep 30
          done

      - name: Cleanup sensitive files
        if: always()
        run: rm -f ios/fastlane/AuthKey.p8
```

Note: The IPA is located via glob because the build job renames it to `Submersion-${TAG_NAME}-iOS.ipa` before uploading the artifact.

### Task 9: Add upload-android job

**Files:**

- Modify: `.github/workflows/release.yml` (insert after upload-ios job)

- [ ] **Step 1: Add upload-android job**

Insert the following job after `upload-ios`:

```yaml
  # ============================================================================
  # Upload Android to Google Play (gated on all builds)
  # ============================================================================
  upload-android:
    name: Upload Android to Google Play
    runs-on: ubuntu-latest
    needs: [build-macos, build-windows, build-linux, build-android, build-ios]
    timeout-minutes: 15

    steps:
      - name: Checkout repository
        uses: actions/checkout@v6

      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.2'
          bundler-cache: true
          working-directory: android

      - name: Setup Google Play service account key
        env:
          GOOGLE_PLAY_SERVICE_ACCOUNT_KEY: ${{ secrets.GOOGLE_PLAY_SERVICE_ACCOUNT_KEY }}
        run: |
          mkdir -p android/fastlane
          echo "$GOOGLE_PLAY_SERVICE_ACCOUNT_KEY" | base64 --decode > android/fastlane/play-store-key.json
          chmod 600 android/fastlane/play-store-key.json

      - name: Download Android AAB artifact
        uses: actions/download-artifact@v8
        with:
          name: android-aab

      - name: Upload to Google Play
        working-directory: android
        env:
          GOOGLE_PLAY_JSON_KEY_PATH: fastlane/play-store-key.json
        run: |
          for attempt in 1 2; do
            if bundle exec fastlane upload; then
              break
            fi
            if [ "$attempt" -eq 2 ]; then
              echo "Fastlane upload failed after 2 attempts"
              exit 1
            fi
            echo "Fastlane attempt $attempt failed, retrying in 30s..."
            sleep 30
          done

      - name: Cleanup sensitive files
        if: always()
        run: rm -f android/fastlane/play-store-key.json
```

Note: The existing `find_aab` helper in `android/fastlane/Fastfile` resolves `../../Submersion-*-Android.aab` relative to `android/fastlane/`, which correctly points to the workspace root where `actions/download-artifact` places the file.

### Task 10: Update create-release dependencies

**Files:**

- Modify: `.github/workflows/release.yml:806`

- [ ] **Step 1: Add upload jobs to create-release needs**

Change line 806 from:

```yaml
    needs: [build-macos, build-windows, build-linux, build-android, build-ios, generate-appcast]
```

To:

```yaml
    needs: [build-macos, build-windows, build-linux, build-android, build-ios, generate-appcast, upload-macos, upload-ios, upload-android]
```

`generate-appcast` keeps its existing `needs:` unchanged (line 759) — it only uses build artifacts and Sparkle EdDSA signatures, not upload results. It runs in parallel with upload jobs.

### Task 11: Validate YAML

- [ ] **Step 1: Validate YAML syntax**

Run: `ruby -ryaml -e "YAML.load_file('.github/workflows/release.yml'); puts 'Valid YAML'"`
Expected: `Valid YAML`

- [ ] **Step 2: Verify job dependency graph**

Run: `grep -E '^\s+needs:' .github/workflows/release.yml`

Expected output should show:

- `generate-appcast` needs all 5 build jobs
- `upload-macos`, `upload-ios`, `upload-android` each need all 5 build jobs
- `create-release` needs all 5 builds + `generate-appcast` + all 3 uploads
- `validate-release` needs `create-release`

- [ ] **Step 3: Verify no store upload steps remain in build jobs**

Run: `grep -n "Upload to App Store\|Upload to Google Play\|upload_to_app_store\|upload_to_testflight\|upload_to_play_store" .github/workflows/release.yml`

Expected: Only matches within the new `upload-macos`, `upload-ios`, and `upload-android` job sections. No matches within `build-macos`, `build-ios`, or `build-android`.

### Task 12: Commit workflow changes

- [ ] **Step 1: Commit**

```bash
git add .github/workflows/release.yml
git commit -m "feat: gate store uploads behind all platform builds

Separate App Store and Google Play uploads into dedicated jobs that only
run after ALL 5 platform builds succeed. Prevents partial releases where
some stores get updated while other platform builds fail.

New jobs: upload-macos, upload-ios, upload-android
Each declares needs: [all 5 build jobs] as an all-or-nothing gate.
Retry logic (2 attempts, 30s delay) preserved in upload jobs.
generate-appcast runs in parallel with uploads for faster pipeline."
```
