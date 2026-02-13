# Multi-Platform GitHub Releases Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create a unified GitHub Actions workflow that builds Submersion for macOS, Windows, Linux, Android, and iOS on every version tag push, creating a GitHub Release with downloadable artifacts and uploading iOS/macOS builds to TestFlight/App Store.

**Architecture:** A single `release.yml` workflow fans out to 5 parallel platform-specific build jobs, then a final `create-release` job collects all artifacts and creates a GitHub Release. macOS and iOS builds additionally upload to App Store/TestFlight via Fastlane.

**Tech Stack:** GitHub Actions, Fastlane (Ruby), Flutter build tooling, `create-dmg`, `xcrun notarytool`, `softprops/action-gh-release`

**Design doc:** `docs/plans/2026-02-12-github-releases-design.md`

---

## Task 1: Android Release Signing Configuration

Update the Android Gradle build to support release signing via `key.properties`. This is required for the CI workflow to produce signed APKs.

**Files:**
- Modify: `android/app/build.gradle.kts:1-52`

**Step 1: Update build.gradle.kts to load keystore from key.properties**

Replace the full contents of `android/app/build.gradle.kts` with:

```kotlin
import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "app.submersion"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_21.toString()
    }

    defaultConfig {
        applicationId = "app.submersion"
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    implementation("androidx.exifinterface:exifinterface:1.3.7")
}
```

**Step 2: Verify the build still works locally**

Run: `flutter build apk --debug --target-platform android-arm64`
Expected: BUILD SUCCESSFUL (falls back to debug signing since no key.properties exists locally yet)

**Step 3: Commit**

```bash
git add android/app/build.gradle.kts
git commit -m "feat: add release signing config to Android build"
```

---

## Task 2: macOS Fastlane Setup

Create the Fastlane configuration for macOS builds, mirroring the iOS setup.

**Files:**
- Create: `macos/Gemfile`
- Create: `macos/fastlane/Matchfile`
- Create: `macos/fastlane/Fastfile`

**Step 1: Create macos/Gemfile**

```ruby
source "https://rubygems.org"

gem "fastlane"

plugins_path = File.join(File.dirname(__FILE__), 'fastlane', 'Pluginfile')
eval_gemfile(plugins_path) if File.exist?(plugins_path)
```

**Step 2: Create macos/fastlane/Matchfile**

```ruby
# Matchfile - macOS Code Signing via Match
#
# Uses the same certificate repository as iOS.
# Stores Mac App Store certificates and provisioning profiles.
#
# Usage:
#   cd macos && bundle exec fastlane sync_signing

git_url("git@github.com:submersion-app/certificates.git")

storage_mode("git")

app_identifier(["app.submersion"])

username("ericgriffin@gmail.com")

type("appstore")

readonly(true)

shallow_clone(true)

platform("macos")
```

**Step 3: Create macos/fastlane/Fastfile**

```ruby
# Fastfile for Submersion macOS App Store Automation
#
# Usage:
#   bundle exec fastlane sync_signing  # Sync code signing certs (Match)
#   bundle exec fastlane build         # Build pkg for Mac App Store
#   bundle exec fastlane beta          # Build + upload to TestFlight
#   bundle exec fastlane release       # Build + upload to App Store

default_platform(:mac)

platform :mac do
  # ============================================================================
  # Helper Methods
  # ============================================================================

  def load_api_key
    if ENV["APP_STORE_CONNECT_API_KEY_KEY_ID"] &&
       ENV["APP_STORE_CONNECT_API_KEY_ISSUER_ID"] &&
       ENV["APP_STORE_CONNECT_API_KEY_KEY_FILEPATH"]

      UI.message("Using API key from environment variables")
      return app_store_connect_api_key(
        key_id: ENV["APP_STORE_CONNECT_API_KEY_KEY_ID"],
        issuer_id: ENV["APP_STORE_CONNECT_API_KEY_ISSUER_ID"],
        key_filepath: ENV["APP_STORE_CONNECT_API_KEY_KEY_FILEPATH"],
        in_house: false
      )
    end

    json_path = "fastlane/api_key.json"
    if File.exist?(json_path)
      UI.message("Using API key from api_key.json")
      config = JSON.parse(File.read(json_path))
      return app_store_connect_api_key(
        key_id: config["key_id"],
        issuer_id: config["issuer_id"],
        key_filepath: config["key_filepath"],
        in_house: config["in_house"] || false
      )
    end

    UI.user_error!(
      "No API key found. Either set environment variables:\n" \
      "  APP_STORE_CONNECT_API_KEY_KEY_ID\n" \
      "  APP_STORE_CONNECT_API_KEY_ISSUER_ID\n" \
      "  APP_STORE_CONNECT_API_KEY_KEY_FILEPATH\n" \
      "Or create fastlane/api_key.json"
    )
  end

  # ============================================================================
  # Code Signing Lanes (Match)
  # ============================================================================

  desc "Sync code signing certificates and provisioning profiles for macOS"
  lane :sync_signing do
    if ENV["CI"]
      create_keychain(
        name: "fastlane_keychain",
        password: ENV["MATCH_PASSWORD"] || "temporary",
        default_keychain: true,
        unlock: true,
        timeout: 3600,
        lock_when_sleeps: false
      )
    end

    match(
      type: "appstore",
      platform: "macos",
      readonly: true,
      keychain_name: ENV["CI"] ? "fastlane_keychain" : nil,
      keychain_password: ENV["CI"] ? (ENV["MATCH_PASSWORD"] || "temporary") : nil
    )

    UI.success("macOS code signing synced successfully!")
  end

  # ============================================================================
  # Build Lanes
  # ============================================================================

  desc "Build the macOS app for Mac App Store distribution"
  lane :build do
    api_key = load_api_key

    UI.message("Building Flutter app for macOS...")
    sh("cd ../.. && flutter build macos --release")

    UI.message("Building and signing pkg...")
    build_mac_app(
      workspace: "Runner.xcworkspace",
      scheme: "Runner",
      export_method: "app-store",
      output_directory: "./build",
      output_name: "Submersion.pkg",
      export_options: {
        signingStyle: "automatic",
        teamID: "8U3RSKF42Q"
      }
    )

    UI.success("Build complete! Pkg saved to macos/build/Submersion.pkg")
  end

  # ============================================================================
  # Upload Lanes
  # ============================================================================

  desc "Build and upload to TestFlight for beta testing"
  lane :beta do
    build

    api_key = load_api_key

    UI.message("Uploading to TestFlight...")
    upload_to_testflight(
      api_key: api_key,
      pkg: "./build/Submersion.pkg",
      skip_waiting_for_build_processing: true
    )

    UI.success("macOS build uploaded to TestFlight!")
  end

  desc "Build and upload to Mac App Store"
  lane :release do
    build

    api_key = load_api_key

    UI.message("Uploading to Mac App Store...")
    upload_to_app_store(
      api_key: api_key,
      pkg: "./build/Submersion.pkg",
      skip_screenshots: true,
      skip_metadata: true,
      submit_for_review: false,
      automatic_release: false,
      precheck_include_in_app_purchases: false
    )

    UI.success("macOS build uploaded to Mac App Store!")
  end
end
```

**Step 4: Verify Fastfile syntax**

Run: `ruby -c macos/fastlane/Fastfile`
Expected: `Syntax OK`

**Step 5: Commit**

```bash
git add macos/Gemfile macos/fastlane/Matchfile macos/fastlane/Fastfile
git commit -m "feat: add macOS Fastlane config for Mac App Store distribution"
```

---

## Task 3: Unified Release Workflow

Create the main GitHub Actions workflow that builds all platforms and creates a GitHub Release.

**Files:**
- Create: `.github/workflows/release.yml`

**Step 1: Create the workflow file**

```yaml
# Multi-Platform Release Workflow
#
# Triggers on version tag push (v*). Builds all 5 platforms in parallel,
# then creates a GitHub Release with all artifacts attached.
#
# Beta tags (v1.0.0-beta.1) create pre-releases.
# Clean tags (v1.0.0) create full releases.
#
# Required Secrets - see docs/plans/2026-02-12-github-releases-design.md

name: Release

on:
  push:
    tags:
      - 'v*'

concurrency:
  group: release-${{ github.ref_name }}
  cancel-in-progress: true

env:
  FLUTTER_VERSION: '3.x'

jobs:
  # ============================================================================
  # macOS Build (signed DMG + Mac App Store)
  # ============================================================================
  build-macos:
    name: Build macOS
    runs-on: macos-14
    timeout-minutes: 45

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          channel: stable
          cache: true

      - name: Install dependencies
        run: |
          flutter pub get
          dart run build_runner build --delete-conflicting-outputs

      - name: Build macOS release
        run: flutter build macos --release

      # -- Developer ID DMG (for GitHub Release) --

      - name: Import Developer ID certificate
        env:
          MACOS_CERTIFICATE_BASE64: ${{ secrets.MACOS_CERTIFICATE_BASE64 }}
          MACOS_CERTIFICATE_PASSWORD: ${{ secrets.MACOS_CERTIFICATE_PASSWORD }}
          MACOS_KEYCHAIN_PASSWORD: ${{ secrets.MACOS_KEYCHAIN_PASSWORD }}
        run: |
          CERTIFICATE_PATH=$RUNNER_TEMP/build_certificate.p12
          KEYCHAIN_PATH=$RUNNER_TEMP/app-signing.keychain-db
          echo -n "$MACOS_CERTIFICATE_BASE64" | base64 --decode -o $CERTIFICATE_PATH
          security create-keychain -p "$MACOS_KEYCHAIN_PASSWORD" $KEYCHAIN_PATH
          security set-keychain-settings -lut 21600 $KEYCHAIN_PATH
          security unlock-keychain -p "$MACOS_KEYCHAIN_PASSWORD" $KEYCHAIN_PATH
          security import $CERTIFICATE_PATH -P "$MACOS_CERTIFICATE_PASSWORD" -A -t cert -f pkcs12 -k $KEYCHAIN_PATH
          security set-key-partition-list -S apple-tool:,apple: -k "$MACOS_KEYCHAIN_PASSWORD" $KEYCHAIN_PATH
          security list-keychain -d user -s $KEYCHAIN_PATH

      - name: Codesign the app
        run: |
          APP_PATH="build/macos/Build/Products/Release/Submersion.app"
          codesign --deep --force --options runtime \
            --sign "Developer ID Application" \
            "$APP_PATH"

      - name: Install create-dmg
        run: brew install create-dmg

      - name: Create DMG
        env:
          TAG_NAME: ${{ github.ref_name }}
        run: |
          create-dmg \
            --volname "Submersion" \
            --volicon "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png" \
            --window-pos 200 120 \
            --window-size 600 400 \
            --icon-size 100 \
            --icon "Submersion.app" 150 200 \
            --app-drop-link 450 200 \
            "Submersion-${TAG_NAME}-macOS.dmg" \
            "build/macos/Build/Products/Release/Submersion.app" || true
          # create-dmg returns non-zero if background image is missing; dmg is still valid

      - name: Notarize DMG
        env:
          APPLE_ID: ${{ secrets.APPLE_ID }}
          APPLE_APP_PASSWORD: ${{ secrets.APPLE_APP_PASSWORD }}
          APPLE_TEAM_ID: ${{ secrets.APPLE_TEAM_ID }}
          TAG_NAME: ${{ github.ref_name }}
        run: |
          xcrun notarytool submit "Submersion-${TAG_NAME}-macOS.dmg" \
            --apple-id "$APPLE_ID" \
            --password "$APPLE_APP_PASSWORD" \
            --team-id "$APPLE_TEAM_ID" \
            --wait
          xcrun stapler staple "Submersion-${TAG_NAME}-macOS.dmg"

      - name: Upload DMG artifact
        uses: actions/upload-artifact@v4
        with:
          name: macos-dmg
          path: Submersion-*.dmg
          retention-days: 5

      # -- Mac App Store (via Fastlane) --

      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.2'
          bundler-cache: true
          working-directory: macos

      - name: Setup App Store Connect API Key
        env:
          APP_STORE_CONNECT_API_KEY_BASE64: ${{ secrets.APP_STORE_CONNECT_API_KEY_BASE64 }}
        run: |
          mkdir -p macos/fastlane
          echo "$APP_STORE_CONNECT_API_KEY_BASE64" | base64 --decode > macos/fastlane/AuthKey.p8

      - name: Determine Fastlane lane
        id: lane
        env:
          TAG_NAME: ${{ github.ref_name }}
        run: |
          if echo "$TAG_NAME" | grep -qE '\-(beta|rc)'; then
            echo "lane=beta" >> "$GITHUB_OUTPUT"
          else
            echo "lane=release" >> "$GITHUB_OUTPUT"
          fi

      - name: Sync macOS code signing
        working-directory: macos
        env:
          MATCH_PASSWORD: ${{ secrets.MATCH_PASSWORD }}
          MATCH_GIT_BASIC_AUTHORIZATION: ${{ secrets.MATCH_GIT_BASIC_AUTHORIZATION }}
          APP_STORE_CONNECT_API_KEY_KEY_ID: ${{ secrets.APP_STORE_CONNECT_API_KEY_ID }}
          APP_STORE_CONNECT_API_KEY_ISSUER_ID: ${{ secrets.APP_STORE_CONNECT_API_ISSUER_ID }}
          APP_STORE_CONNECT_API_KEY_KEY_FILEPATH: fastlane/AuthKey.p8
        run: bundle exec fastlane sync_signing

      - name: Upload to App Store / TestFlight
        working-directory: macos
        env:
          FASTLANE_LANE: ${{ steps.lane.outputs.lane }}
          APP_STORE_CONNECT_API_KEY_KEY_ID: ${{ secrets.APP_STORE_CONNECT_API_KEY_ID }}
          APP_STORE_CONNECT_API_KEY_ISSUER_ID: ${{ secrets.APP_STORE_CONNECT_API_ISSUER_ID }}
          APP_STORE_CONNECT_API_KEY_KEY_FILEPATH: fastlane/AuthKey.p8
          MATCH_PASSWORD: ${{ secrets.MATCH_PASSWORD }}
          MATCH_GIT_BASIC_AUTHORIZATION: ${{ secrets.MATCH_GIT_BASIC_AUTHORIZATION }}
        run: bundle exec fastlane "$FASTLANE_LANE"

      - name: Cleanup sensitive files
        if: always()
        run: rm -f macos/fastlane/AuthKey.p8

  # ============================================================================
  # Windows Build
  # ============================================================================
  build-windows:
    name: Build Windows
    runs-on: windows-latest
    timeout-minutes: 30

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          channel: stable
          cache: true

      - name: Install dependencies
        run: |
          flutter pub get
          dart run build_runner build --delete-conflicting-outputs

      - name: Build Windows release
        run: flutter build windows --release

      - name: Create ZIP archive
        env:
          TAG_NAME: ${{ github.ref_name }}
        run: |
          Compress-Archive -Path "build\windows\x64\runner\Release\*" -DestinationPath "Submersion-${env:TAG_NAME}-Windows.zip"

      - name: Upload Windows artifact
        uses: actions/upload-artifact@v4
        with:
          name: windows-zip
          path: Submersion-*.zip
          retention-days: 5

  # ============================================================================
  # Linux Build
  # ============================================================================
  build-linux:
    name: Build Linux
    runs-on: ubuntu-latest
    timeout-minutes: 30

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Install Linux dependencies
        run: |
          sudo apt-get update -y
          sudo apt-get install -y \
            clang cmake ninja-build pkg-config \
            libgtk-3-dev liblzma-dev libstdc++-12-dev \
            libsqlite3-dev

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          channel: stable
          cache: true

      - name: Install dependencies
        run: |
          flutter pub get
          dart run build_runner build --delete-conflicting-outputs

      - name: Build Linux release
        run: flutter build linux --release

      - name: Create tarball
        env:
          TAG_NAME: ${{ github.ref_name }}
        run: |
          cd build/linux/x64/release/bundle
          tar czf "$GITHUB_WORKSPACE/Submersion-${TAG_NAME}-Linux.tar.gz" .

      - name: Upload Linux artifact
        uses: actions/upload-artifact@v4
        with:
          name: linux-tar
          path: Submersion-*.tar.gz
          retention-days: 5

  # ============================================================================
  # Android Build
  # ============================================================================
  build-android:
    name: Build Android
    runs-on: ubuntu-latest
    timeout-minutes: 30

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Setup Java
        uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '21'

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          channel: stable
          cache: true

      - name: Install dependencies
        run: |
          flutter pub get
          dart run build_runner build --delete-conflicting-outputs

      - name: Setup Android signing
        env:
          ANDROID_KEYSTORE_BASE64: ${{ secrets.ANDROID_KEYSTORE_BASE64 }}
          ANDROID_KEYSTORE_PASSWORD: ${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
          ANDROID_KEY_ALIAS: ${{ secrets.ANDROID_KEY_ALIAS }}
          ANDROID_KEY_PASSWORD: ${{ secrets.ANDROID_KEY_PASSWORD }}
        run: |
          echo "$ANDROID_KEYSTORE_BASE64" | base64 --decode > android/app/release.keystore
          cat > android/key.properties <<EOL
          storePassword=$ANDROID_KEYSTORE_PASSWORD
          keyPassword=$ANDROID_KEY_PASSWORD
          keyAlias=$ANDROID_KEY_ALIAS
          storeFile=release.keystore
          EOL

      - name: Build Android APK
        run: flutter build apk --release

      - name: Rename APK
        env:
          TAG_NAME: ${{ github.ref_name }}
        run: |
          mv build/app/outputs/flutter-apk/app-release.apk \
            "Submersion-${TAG_NAME}-Android.apk"

      - name: Upload Android artifact
        uses: actions/upload-artifact@v4
        with:
          name: android-apk
          path: Submersion-*.apk
          retention-days: 5

      - name: Cleanup sensitive files
        if: always()
        run: |
          rm -f android/app/release.keystore
          rm -f android/key.properties

  # ============================================================================
  # iOS Build
  # ============================================================================
  build-ios:
    name: Build iOS
    runs-on: macos-14
    timeout-minutes: 60

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          channel: stable
          cache: true

      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.2'
          bundler-cache: true
          working-directory: ios

      - name: Install dependencies
        run: |
          flutter pub get
          dart run build_runner build --delete-conflicting-outputs

      - name: Setup App Store Connect API Key
        env:
          APP_STORE_CONNECT_API_KEY_BASE64: ${{ secrets.APP_STORE_CONNECT_API_KEY_BASE64 }}
        run: |
          mkdir -p ios/fastlane
          echo "$APP_STORE_CONNECT_API_KEY_BASE64" | base64 --decode > ios/fastlane/AuthKey.p8

      - name: Determine Fastlane lane
        id: lane
        env:
          TAG_NAME: ${{ github.ref_name }}
        run: |
          if echo "$TAG_NAME" | grep -qE '\-(beta|rc)'; then
            echo "lane=beta" >> "$GITHUB_OUTPUT"
          else
            echo "lane=release" >> "$GITHUB_OUTPUT"
          fi

      - name: Sync iOS code signing
        working-directory: ios
        env:
          MATCH_PASSWORD: ${{ secrets.MATCH_PASSWORD }}
          MATCH_GIT_BASIC_AUTHORIZATION: ${{ secrets.MATCH_GIT_BASIC_AUTHORIZATION }}
          APP_STORE_CONNECT_API_KEY_KEY_ID: ${{ secrets.APP_STORE_CONNECT_API_KEY_ID }}
          APP_STORE_CONNECT_API_KEY_ISSUER_ID: ${{ secrets.APP_STORE_CONNECT_API_ISSUER_ID }}
          APP_STORE_CONNECT_API_KEY_KEY_FILEPATH: fastlane/AuthKey.p8
        run: bundle exec fastlane sync_signing

      - name: Build and upload iOS
        working-directory: ios
        env:
          FASTLANE_LANE: ${{ steps.lane.outputs.lane }}
          APP_STORE_CONNECT_API_KEY_KEY_ID: ${{ secrets.APP_STORE_CONNECT_API_KEY_ID }}
          APP_STORE_CONNECT_API_KEY_ISSUER_ID: ${{ secrets.APP_STORE_CONNECT_API_ISSUER_ID }}
          APP_STORE_CONNECT_API_KEY_KEY_FILEPATH: fastlane/AuthKey.p8
          MATCH_PASSWORD: ${{ secrets.MATCH_PASSWORD }}
          MATCH_GIT_BASIC_AUTHORIZATION: ${{ secrets.MATCH_GIT_BASIC_AUTHORIZATION }}
        run: bundle exec fastlane "$FASTLANE_LANE"

      - name: Rename IPA
        env:
          TAG_NAME: ${{ github.ref_name }}
        run: |
          mv ios/build/Submersion.ipa "Submersion-${TAG_NAME}-iOS.ipa"

      - name: Upload iOS artifact
        uses: actions/upload-artifact@v4
        with:
          name: ios-ipa
          path: Submersion-*.ipa
          retention-days: 5

      - name: Cleanup sensitive files
        if: always()
        run: rm -f ios/fastlane/AuthKey.p8

  # ============================================================================
  # Create GitHub Release
  # ============================================================================
  create-release:
    name: Create GitHub Release
    runs-on: ubuntu-latest
    needs: [build-macos, build-windows, build-linux, build-android, build-ios]
    permissions:
      contents: write

    steps:
      - name: Download all artifacts
        uses: actions/download-artifact@v4
        with:
          merge-multiple: true

      - name: List artifacts
        run: ls -la Submersion-*

      - name: Determine if pre-release
        id: prerelease
        env:
          TAG_NAME: ${{ github.ref_name }}
        run: |
          if echo "$TAG_NAME" | grep -qE '\-(beta|rc|alpha)'; then
            echo "prerelease=true" >> "$GITHUB_OUTPUT"
          else
            echo "prerelease=false" >> "$GITHUB_OUTPUT"
          fi

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          files: Submersion-*
          prerelease: ${{ steps.prerelease.outputs.prerelease }}
          generate_release_notes: true
```

**Step 2: Validate YAML syntax**

Run: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/release.yml'))"`
Expected: No output (valid YAML)

**Step 3: Commit**

```bash
git add .github/workflows/release.yml
git commit -m "feat: add unified multi-platform release workflow"
```

---

## Task 4: Retire Old iOS Release Workflow

Replace the standalone iOS release workflow with the unified one.

**Files:**
- Delete: `.github/workflows/ios-release.yml`

**Step 1: Remove the old workflow**

```bash
git rm .github/workflows/ios-release.yml
```

**Step 2: Commit**

```bash
git commit -m "chore: retire standalone ios-release workflow

Replaced by the iOS job in the unified release.yml workflow."
```

---

## Task 5: Validate and Document

Final validation and documentation updates.

**Files:**
- Modify: `docs/developer/building.md` (update Release Checklist section)

**Step 1: Update the Release Checklist in building.md**

Find the "Release Checklist" section (lines 372-384) and replace with:

```markdown
## Release Checklist

Before releasing:

1. [ ] Run `flutter analyze` - no errors
2. [ ] Run `flutter test` - all passing
3. [ ] Update version in `pubspec.yaml`
4. [ ] Commit: `git commit -am "chore: bump version to X.Y.Z"`
5. [ ] Tag: `git tag vX.Y.Z`
6. [ ] Push: `git push origin main --tags`
7. [ ] Monitor the Release workflow in GitHub Actions
8. [ ] Verify all artifacts appear on the GitHub Release page
9. [ ] Verify iOS build appears in TestFlight
10. [ ] Verify macOS build appears in TestFlight

For beta releases, use tags like `v1.0.0-beta.1` (creates a pre-release).
```

**Step 2: Commit**

```bash
git add docs/developer/building.md
git commit -m "docs: update release checklist for automated workflow"
```

---

## Task 6: Secrets Setup Guide

Create a one-time setup guide for configuring the required GitHub Secrets.

**Files:**
- Create: `docs/developer/release-secrets-setup.md`

**Step 1: Create the secrets setup guide**

```markdown
# Release Secrets Setup

One-time setup guide for configuring GitHub Secrets required by the
multi-platform release workflow.

## GitHub Secrets Configuration

Go to: Repository Settings > Secrets and variables > Actions > New repository secret

### Already Configured (iOS)

These should already exist from the iOS release workflow:

- `APP_STORE_CONNECT_API_KEY_ID`
- `APP_STORE_CONNECT_API_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY_BASE64`
- `MATCH_PASSWORD`
- `MATCH_GIT_BASIC_AUTHORIZATION`

### macOS Signing (Developer ID DMG)

**MACOS_CERTIFICATE_BASE64**

Export your Developer ID Application certificate from Keychain Access:

1. Open Keychain Access
2. Find "Developer ID Application: [Your Name]"
3. Right-click > Export Items > save as .p12
4. Set a password when prompted
5. Base64 encode: `base64 -i certificate.p12 | pbcopy`
6. Paste as the secret value

**MACOS_CERTIFICATE_PASSWORD**

The password you set when exporting the .p12 file.

**MACOS_KEYCHAIN_PASSWORD**

Any arbitrary password (e.g., `ci-keychain-password`). Only used to create a
temporary keychain in CI.

### macOS Notarization

**APPLE_ID**

Your Apple ID email address (e.g., `ericgriffin@gmail.com`).

**APPLE_APP_PASSWORD**

Generate an app-specific password:

1. Go to https://appleid.apple.com
2. Sign in > App-Specific Passwords > Generate
3. Use the generated password as the secret value

**APPLE_TEAM_ID**

Your Apple Developer Team ID: `8U3RSKF42Q`

### Android Signing

**ANDROID_KEYSTORE_BASE64**

Base64 encode your release keystore:

```bash
base64 -i your-release.keystore | pbcopy
```

Paste as the secret value.

**ANDROID_KEYSTORE_PASSWORD**

The password for the keystore file.

**ANDROID_KEY_ALIAS**

The alias of the key within the keystore (e.g., `submersion`).

**ANDROID_KEY_PASSWORD**

The password for the key (often the same as the keystore password).

## macOS Match Setup

If macOS provisioning profiles have not been added to your Match repository yet:

```bash
cd macos
bundle install
bundle exec fastlane match appstore --platform macos
```

This will generate Mac App Store certificates and provisioning profiles and
store them encrypted in your certificates repository.

## Verification

After configuring all secrets, trigger a test release:

```bash
git tag v0.0.1-test.1
git push origin v0.0.1-test.1
```

Monitor the workflow in GitHub Actions. If successful, delete the test release:

```bash
git tag -d v0.0.1-test.1
git push origin :refs/tags/v0.0.1-test.1
gh release delete v0.0.1-test.1 --yes
```
```

**Step 2: Commit**

```bash
git add docs/developer/release-secrets-setup.md
git commit -m "docs: add release secrets setup guide"
```

---

## Summary

| Task | Description | Files |
|------|-------------|-------|
| 1 | Android release signing | `android/app/build.gradle.kts` |
| 2 | macOS Fastlane setup | `macos/Gemfile`, `macos/fastlane/Matchfile`, `macos/fastlane/Fastfile` |
| 3 | Unified release workflow | `.github/workflows/release.yml` |
| 4 | Retire old iOS workflow | delete `.github/workflows/ios-release.yml` |
| 5 | Update release docs | `docs/developer/building.md` |
| 6 | Secrets setup guide | `docs/developer/release-secrets-setup.md` |
