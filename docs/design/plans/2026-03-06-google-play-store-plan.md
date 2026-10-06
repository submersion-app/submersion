# Google Play Store Publication Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Publish Submersion to the Google Play Store with automated Fastlane uploads, a privacy policy, and full store listing compliance.

**Architecture:** Gate Health Connect on Android AAB builds via dart define, write a privacy policy, set up Fastlane for Android (mirroring iOS/macOS patterns), and integrate into the existing release CI workflow. Manual Play Console steps (store listing, data safety, content rating, first upload) are documented as checklists.

**Tech Stack:** Flutter, Fastlane (supply), GitHub Actions, Google Play Console

**Design doc:** `docs/plans/2026-03-06-google-play-store-design.md`

---

## Task 1: Gate Health Connect on Android AAB Builds

The `health` package compiles into all builds. The wearable import UI is already gated behind `Platform.isIOS` in:
- `lib/features/settings/presentation/widgets/settings_list_content.dart:107` (settings section visibility)
- `lib/features/transfer/presentation/pages/transfer_page.dart:723` (transfer page Apple Watch section)

Since the UI entry points are already iOS-only, Health Connect APIs are never invoked on Android. However, the `health` package may auto-merge Health Connect permissions into the Android manifest via its own `AndroidManifest.xml`. We need to verify this and block it if so.

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `.github/workflows/release.yml:459-460`

**Step 1: Check if the health package declares Health Connect permissions**

Run from the project root:

```bash
grep -r "health.connect\|HEALTH" android/ --include="*.xml" -l
find ~/.pub-cache/hosted/pub.dev/health-* -name "AndroidManifest.xml" -exec grep -l "health" {} \;
```

Look for permissions like `android.permission.health.READ_HEALTH_DATA_IN_BACKGROUND` or activity declarations referencing `health.connect`. If found, proceed to Step 2. If not found, skip to Step 3.

**Step 2: Override Health Connect manifest entries (if needed)**

Add `xmlns:tools` to the manifest root and `tools:node="remove"` overrides for any Health Connect permissions or activities the `health` package auto-merges. Example:

In `android/app/src/main/AndroidManifest.xml`, add to the `<manifest>` tag:

```xml
xmlns:tools="http://schemas.android.com/tools"
```

Then add permission overrides inside `<manifest>` (before `<application>`):

```xml
<!-- Block Health Connect permissions until Google approval is granted -->
<uses-permission android:name="android.permission.health.READ_HEALTH_DATA_IN_BACKGROUND" tools:node="remove" />
```

The specific permissions to block depend on what Step 1 finds.

**Step 3: Add HEALTH_CONNECT_ENABLED=false to the AAB build**

In `.github/workflows/release.yml`, modify the AAB build step (currently line 459-460):

```yaml
      - name: Build Android App Bundle
        run: flutter build appbundle --release --dart-define=HEALTH_CONNECT_ENABLED=false
```

This doesn't change runtime behavior today (the UI is already iOS-only), but establishes the convention so that when Health Connect support is eventually added for Android, the flag is already wired in.

**Step 4: Commit**

```bash
git add android/app/src/main/AndroidManifest.xml .github/workflows/release.yml
git commit -m "feat: gate Health Connect for Android Play Store builds"
```

---

## Task 2: Write Privacy Policy

**Files:**
- Create: `PRIVACY.md` (repo root)

**Step 1: Create `PRIVACY.md`**

```markdown
# Privacy Policy

**Last Updated:** 2026-03-06

**Submersion** is an open-source dive logging application. This policy explains what data the app collects, how it is stored, and your rights regarding that data.

## Data Collection

Submersion collects the following data, all stored locally on your device:

- **Dive logs:** Date, time, depth, duration, temperature, and other dive parameters you enter or import from dive computers.
- **Dive sites:** Location names, GPS coordinates, and descriptions you create.
- **Diver profile:** Your name, certification information, and dive preferences.
- **Gear inventory:** Equipment names, serial numbers, purchase dates, and service records.
- **Buddies:** Names and contact information of dive buddies you add.
- **Photos and videos:** Media you attach to dive log entries from your device's photo library.
- **Dive computer data:** Dive profiles, tank information, and telemetry downloaded from connected dive computers via Bluetooth.

## Data Storage

All data is stored locally on your device in an encrypted SQLite database. Submersion does not operate any servers and does not transmit your data to any remote service by default.

## Cloud Backup (Optional)

If you choose to enable Google Drive backup, your dive data is uploaded to your own Google Drive account. This is entirely optional and user-initiated. Submersion does not have access to your Google Drive data beyond what you explicitly back up. Backup data is transmitted over HTTPS.

## Health Data (Optional)

On iOS, Submersion can optionally read dive workout data from Apple HealthKit. This data is used solely to import dive records into your local dive log. Health data is never transmitted off your device or shared with any third party.

## Data Sharing

Submersion does **not**:

- Share your data with third parties
- Include analytics or tracking
- Display advertisements
- Require account creation
- Transmit data to remote servers (except optional Google Drive backup to your own account)

## Device Permissions

Submersion requests the following permissions, each for a specific purpose:

| Permission | Purpose |
|------------|---------|
| Bluetooth | Discover and communicate with BLE dive computers to download dive logs |
| Location | Tag dive sites with GPS coordinates; required for Bluetooth scanning on Android 11 and below |
| Photos and media | Attach photos and videos from your gallery to dive log entries |
| Media location | Read GPS coordinates from photo metadata to suggest dive site locations |
| Contacts | Select dive buddies from your device contacts |
| Notifications | Deliver gear maintenance service reminders |
| Exact alarms | Schedule precise gear maintenance reminder notifications |

## Data Deletion

You can delete any or all of your data at any time within the app. Uninstalling Submersion removes all locally stored data from your device. If you have created a Google Drive backup, you can delete it directly from your Google Drive.

## Children

Submersion is not directed at children under the age of 13. We do not knowingly collect data from children under 13.

## Changes to This Policy

This privacy policy may be updated from time to time. Changes will be reflected in this document with an updated "Last Updated" date. Continued use of the app after changes constitutes acceptance of the updated policy.

## Contact

For privacy-related questions, please open an issue on our GitHub repository or contact us at:

**Email:** privacy@submersion.app

## Open Source

Submersion is open-source software. You can review the complete source code to verify our data practices at:

https://github.com/submersion-app/submersion
```

**Step 2: Commit**

```bash
git add PRIVACY.md
git commit -m "docs: add privacy policy for app store listings"
```

---

## Task 3: Create Android Fastlane Configuration

Mirror the iOS/macOS Fastlane structure. Android Fastlane uses `supply` (Google Play upload) instead of `deliver` (App Store upload).

**Files:**
- Create: `android/Gemfile`
- Create: `android/fastlane/Appfile`
- Create: `android/fastlane/Fastfile`

**Step 1: Create `android/Gemfile`**

```ruby
source "https://rubygems.org"

gem "fastlane"
```

**Step 2: Create `android/fastlane/Appfile`**

```ruby
json_key_file(ENV["GOOGLE_PLAY_JSON_KEY_PATH"] || "fastlane/play-store-key.json")
package_name("app.submersion")
```

**Step 3: Create `android/fastlane/Fastfile`**

```ruby
# Fastfile for Submersion Google Play Store Automation
#
# Usage:
#   bundle exec fastlane beta    # Upload AAB to internal testing track
#   bundle exec fastlane release # Upload AAB to production (20% staged rollout)
#
# Authentication:
#   Set GOOGLE_PLAY_JSON_KEY_PATH to the service account JSON key file path,
#   or place the key at fastlane/play-store-key.json.

default_platform(:android)

platform :android do
  # ============================================================================
  # Upload Lanes
  # ============================================================================

  desc "Upload AAB to internal testing track"
  lane :beta do
    aab_path = find_aab

    UI.message("Uploading to internal testing track...")
    upload_to_play_store(
      aab: aab_path,
      track: "internal",
      release_status: "completed",
      skip_upload_metadata: true,
      skip_upload_changelogs: true,
      skip_upload_images: true,
      skip_upload_screenshots: true,
    )

    UI.success("AAB uploaded to internal testing track!")
  end

  desc "Upload AAB to production track with staged rollout"
  lane :release do
    aab_path = find_aab

    UI.message("Uploading to production track (20% staged rollout)...")
    upload_to_play_store(
      aab: aab_path,
      track: "production",
      release_status: "inProgress",
      rollout: "0.2",
      skip_upload_metadata: true,
      skip_upload_changelogs: true,
      skip_upload_images: true,
      skip_upload_screenshots: true,
    )

    UI.success("AAB uploaded to production with 20% staged rollout!")
  end

  # ============================================================================
  # Utility Lanes
  # ============================================================================

  desc "Validate the AAB without uploading"
  lane :validate do
    aab_path = find_aab

    UI.message("Validating AAB...")
    upload_to_play_store(
      aab: aab_path,
      track: "internal",
      release_status: "draft",
      skip_upload_metadata: true,
      skip_upload_changelogs: true,
      skip_upload_images: true,
      skip_upload_screenshots: true,
      validate_only: true,
    )

    UI.success("AAB validation passed!")
  end

  desc "Show all available lanes"
  lane :lanes_help do
    UI.message("Available Fastlane lanes:")
    UI.message("")
    UI.message("  Upload:")
    UI.message("    beta     - Upload AAB to internal testing track")
    UI.message("    release  - Upload AAB to production (20% staged rollout)")
    UI.message("")
    UI.message("  Utilities:")
    UI.message("    validate   - Validate AAB without uploading")
    UI.message("    lanes_help - Show this help")
  end

  # ============================================================================
  # Helper Methods
  # ============================================================================

  # Finds the AAB file. Checks for the renamed artifact first (CI),
  # then falls back to the default Flutter build output (local).
  def find_aab
    # CI renames artifacts to Submersion-vX.Y.Z-Android.aab in the workspace root
    ci_aab = Dir.glob("../../Submersion-*-Android.aab").first
    if ci_aab
      UI.message("Using CI artifact: #{ci_aab}")
      return File.absolute_path(ci_aab)
    end

    # Local build output
    local_aab = "../../build/app/outputs/bundle/release/app-release.aab"
    if File.exist?(local_aab)
      UI.message("Using local build: #{local_aab}")
      return File.absolute_path(local_aab)
    end

    UI.user_error!(
      "No AAB found. Build with 'flutter build appbundle --release' first, " \
      "or ensure CI has renamed the artifact to Submersion-*-Android.aab."
    )
  end
end
```

**Step 4: Generate Gemfile.lock**

```bash
cd android
bundle install
cd ..
```

**Step 5: Add `android/fastlane/play-store-key.json` to `.gitignore`**

Check if `.gitignore` already has an entry for this. If not, add:

```
android/fastlane/play-store-key.json
```

**Step 6: Commit**

```bash
git add android/Gemfile android/Gemfile.lock android/fastlane/Appfile android/fastlane/Fastfile .gitignore
git commit -m "feat: add Android Fastlane for Google Play Store uploads"
```

---

## Task 4: Integrate Android Fastlane into CI Release Workflow

Add Ruby setup and Fastlane upload steps to the `build-android` job in `.github/workflows/release.yml`, mirroring the iOS/macOS pattern.

**Files:**
- Modify: `.github/workflows/release.yml` (build-android job, ~lines 407-489)

**Step 1: Add Ruby setup step**

After the "Install dependencies" step (line 438) and before the "Setup Android signing" step, add:

```yaml
      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.2'
          bundler-cache: true
          working-directory: android
```

**Step 2: Add Fastlane lane determination step**

After the "Upload Android AAB artifact" step, add:

```yaml
      - name: Determine Fastlane lane
        id: lane
        env:
          TAG_NAME: ${{ github.ref_name }}
        run: |
          if echo "$TAG_NAME" | grep -qE '\-(alpha|beta|rc)'; then
            echo "lane=beta" >> "$GITHUB_OUTPUT"
          else
            echo "lane=release" >> "$GITHUB_OUTPUT"
          fi
```

**Step 3: Add service account key setup step**

```yaml
      - name: Setup Google Play service account key
        env:
          GOOGLE_PLAY_SERVICE_ACCOUNT_KEY: ${{ secrets.GOOGLE_PLAY_SERVICE_ACCOUNT_KEY }}
        run: |
          mkdir -p android/fastlane
          echo "$GOOGLE_PLAY_SERVICE_ACCOUNT_KEY" | base64 --decode > android/fastlane/play-store-key.json
          chmod 600 android/fastlane/play-store-key.json
```

**Step 4: Add Fastlane upload step**

```yaml
      - name: Upload to Google Play
        working-directory: android
        env:
          FASTLANE_LANE: ${{ steps.lane.outputs.lane }}
          GOOGLE_PLAY_JSON_KEY_PATH: fastlane/play-store-key.json
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
```

**Step 5: Update cleanup step**

Modify the existing "Cleanup sensitive files" step to also remove the service account key:

```yaml
      - name: Cleanup sensitive files
        if: always()
        run: |
          rm -f android/app/release.keystore
          rm -f android/key.properties
          rm -f android/fastlane/play-store-key.json
```

**Step 6: Commit**

```bash
git add .github/workflows/release.yml
git commit -m "feat: integrate Android Fastlane upload into release workflow"
```

---

## Task 5: Google Play Console Setup (Manual Steps)

These steps must be done manually in the Google Cloud Console and Google Play Console. They cannot be automated.

### 5a: Create Google Cloud Service Account

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Enable the **Google Play Android Developer API**
4. Go to **IAM & Admin > Service Accounts**
5. Create a service account (e.g., `submersion-play-upload`)
6. Create a JSON key for this service account and download it
7. Base64-encode it: `base64 -i service-account-key.json | pbcopy`
8. Add as GitHub secret: `GOOGLE_PLAY_SERVICE_ACCOUNT_KEY`

### 5b: Grant Service Account Access in Play Console

1. Go to [Google Play Console](https://play.google.com/console/)
2. Make sure you are at the **account level** (click "All apps" or your developer account name at the top — you must NOT be inside a specific app)
3. In the left sidebar, scroll to the **Setup** section and click **API access**
4. Link the Google Cloud project created in 5a
5. Find the service account and click **Manage permissions**
6. Grant **Release manager** role (or at minimum: manage production/testing releases, manage app information)
7. Apply permissions to **Submersion Dive Log** app

### 5c: Enroll in Play App Signing

1. In Play Console, go to **Submersion Dive Log > Setup > App signing**
2. Choose **Let Google manage and protect your app signing key**
3. Upload your upload key certificate:
   ```bash
   keytool -export -alias <your-key-alias> -keystore <your-keystore.jks> -rfc | openssl x509 -inform PEM -outform DER | base64
   ```
   Or simply upload the first AAB signed with your upload key and Google will extract it.

### 5d: First AAB Upload (Bootstrap)

1. Build an AAB locally or download from a GitHub Release
2. In Play Console, go to **Submersion Dive Log > Testing > Internal testing**
3. Click **Create new release** and upload the AAB
4. This establishes the app in Play Console so Fastlane can upload subsequent versions

---

## Task 6: Play Store Listing (Manual Steps)

Fill out these fields in Google Play Console > **Submersion Dive Log > Grow > Store presence > Main store listing**:

### 6a: App Details

- **App name:** Submersion Dive Log
- **Short description:** Open-source dive log for scuba divers. Track dives, gear, sites, and stats.
- **Full description:**

```
Submersion is a free, open-source dive logging app for scuba divers. Track your dives, manage gear, explore dive sites, and visualize your dive statistics -- all with your data stored privately on your device.

KEY FEATURES

Dive Logging
- Log dives with depth, time, temperature, visibility, and more
- Support for 20+ dive types including recreational, technical, cave, wreck, and night dives
- Track gas mixes, tank configurations, and rebreather (CCR/SCR) dives
- Attach photos and videos to dive entries

Dive Computer Integration
- Download dives from BLE dive computers (Shearwater, Suunto, Mares, Oceanic, and more)
- Import dive profiles with depth, temperature, and tank pressure data
- Automatic duplicate detection when importing

Dive Sites
- GPS-tagged dive sites with interactive maps
- Offline map tile caching for remote locations
- Search and filter your dive sites

Gear Management
- Track your equipment inventory with serial numbers and purchase dates
- Service reminder notifications so you never miss a maintenance date
- Link gear to specific dives

Statistics & Reports
- Visualize your dive history with charts and graphs
- Export dive logs to PDF, CSV, UDDF, and more
- Print professional logbook pages

Cloud Backup
- Optional backup to your Google Drive account
- Your data stays yours -- no accounts, no servers, no subscriptions

Import & Export
- Import from Subsurface, UDDF, Garmin FIT, DivingLog, MacDive, and more
- Export to UDDF, CSV, PDF, and Excel

Privacy First
- All data stored locally on your device
- No analytics, no tracking, no ads
- Open-source: review the code yourself at github.com/submersion-app/submersion

Submersion is built by divers, for divers. Free forever.
```

### 6b: Store Assets (Create Manually)

| Asset | Spec | Suggested Content |
|-------|------|-------------------|
| Hi-res icon | 512x512 PNG | Export from existing adaptive icon source |
| Feature graphic | 1024x500 PNG | App name + tagline + device mockup showing dive profile |
| Phone screenshots (min 2) | 1080x1920 or 1920x1080 | Dive list, dive detail with profile chart, site map, stats dashboard, gear list |

### 6c: Content Rating

Go to **Policy and programs > App content > Content rating** and complete the IARC questionnaire:

- No violence: Yes
- No sexual content: Yes
- No gambling: Yes
- No controlled substances: Yes
- No user-generated content sharing: Yes
- Expected rating: **Everyone (E)**

### 6d: Data Safety Declaration

Go to **Policy and programs > App content > Data safety**:

| Data type | Collected | Shared | Required | Purpose |
|-----------|-----------|--------|----------|---------|
| Approximate location | Yes | No | No | Dive site tagging |
| Precise location | Yes | No | No | Dive site tagging |
| Photos | Yes | No | No | Dive photo attachments |
| Videos | Yes | No | No | Dive video attachments |
| Name | Yes | No | No | Diver profile |
| Contacts | Yes | No | No | Buddy selection |
| Files and docs | Yes | No | No | Dive log import |

Additional declarations:
- Data is encrypted in transit: **Yes** (Google Drive uses HTTPS)
- Users can request data deletion: **Yes**
- Data is not shared with third parties
- App does not follow the Google Play Families Policy

### 6e: Target Audience

- **Target age group:** 18 and over
- The app is **not** designed for children

### 6f: Privacy Policy

- **Privacy policy URL:** `https://github.com/submersion-app/submersion/blob/main/PRIVACY.md`

---

## Task 7: Submit and Verify

### 7a: Submit to Internal Testing

1. If the first AAB was uploaded in Task 5d, the app is already on internal testing
2. Add yourself as an internal tester in **Testing > Internal testing > Testers**
3. Accept the invite link on an Android device
4. Install from the Play Store internal testing track
5. Verify the app launches, core features work, and no Health Connect prompts appear

### 7b: Verify Fastlane Upload

1. Push a beta tag to trigger the CI pipeline:
   ```bash
   git tag v1.2.17-beta.1
   git push origin v1.2.17-beta.1
   ```
2. Verify the `build-android` job completes successfully
3. Verify a new release appears in Play Console internal testing track
4. Install and verify on a physical Android device

### 7c: Promote to Production

1. Once verified, go to **Production > Create new release**
2. Promote the internal testing release to production
3. Set **Staged rollout: 20%**
4. Submit for review
5. Google typically reviews within 1-3 days for new apps
6. After approval, monitor for crashes in Play Console
7. When satisfied, increase rollout to 100%

---

## Summary of Files Changed

| File | Action |
|------|--------|
| `android/app/src/main/AndroidManifest.xml` | Possibly add Health Connect permission overrides |
| `.github/workflows/release.yml` | Add `HEALTH_CONNECT_ENABLED=false` to AAB build, add Ruby/Fastlane steps |
| `PRIVACY.md` | Create privacy policy |
| `android/Gemfile` | Create Ruby deps for Fastlane |
| `android/Gemfile.lock` | Generated by `bundle install` |
| `android/fastlane/Appfile` | Create with package name and key config |
| `android/fastlane/Fastfile` | Create with beta and release lanes |
| `.gitignore` | Add `android/fastlane/play-store-key.json` |

## GitHub Secrets Required

| Secret | Description |
|--------|-------------|
| `GOOGLE_PLAY_SERVICE_ACCOUNT_KEY` | Base64-encoded Google Cloud service account JSON key |
| `ANDROID_KEYSTORE_BASE64` | Already exists -- used for upload signing |
| `ANDROID_KEYSTORE_PASSWORD` | Already exists |
| `ANDROID_KEY_ALIAS` | Already exists |
| `ANDROID_KEY_PASSWORD` | Already exists |
