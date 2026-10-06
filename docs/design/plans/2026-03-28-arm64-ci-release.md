# ARM64 CI & Release Builds Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Windows ARM64 and Linux ARM64 builds to CI and release workflows using native GitHub Actions ARM runners.

**Architecture:** Duplicate-job approach -- one self-contained job per platform/architecture. Native ARM64 runners (`ubuntu-24.04-arm`, `windows-11-arm`) eliminate cross-compilation. Backwards compatibility maintained via legacy appcast entries and dual-named Linux tarballs.

**Tech Stack:** GitHub Actions YAML, Inno Setup, Bash (appcast script), Dart (update provider)

**Spec:** `docs/superpowers/specs/2026-03-28-arm64-ci-release-design.md`

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Modify | `windows/installer/submersion.iss` | Rename x64 output filename |
| Create | `windows/installer/submersion-arm64.iss` | ARM64 Windows installer config |
| Modify | `scripts/generate_appcast.sh` | Add Windows ARM64 appcast item + legacy compat item |
| Modify | `lib/features/auto_update/presentation/providers/update_providers.dart` | Architecture-aware Linux `_platformSuffix` |
| Modify | `.github/workflows/ci.yaml` | Rename x64 artifacts, add ARM64 jobs |
| Modify | `.github/workflows/release.yml` | Rename x64 artifacts, add ARM64 jobs, update downstream jobs |

---

### Task 1: Inno Setup -- Rename x64 Output and Create ARM64 Config

**Files:**
- Modify: `windows/installer/submersion.iss:38`
- Create: `windows/installer/submersion-arm64.iss`

- [ ] **Step 1: Rename x64 output filename in existing Inno Setup config**

In `windows/installer/submersion.iss`, change line 38 from:

```
OutputBaseFilename=Submersion-v{#APP_VERSION}-Windows-Setup
```

to:

```
OutputBaseFilename=Submersion-v{#APP_VERSION}-Windows-x64-Setup
```

- [ ] **Step 2: Create ARM64 Inno Setup config**

Create `windows/installer/submersion-arm64.iss` with the following content. This is a copy of `submersion.iss` with three differences: `ArchitecturesAllowed=arm64`, source path uses `arm64` instead of `x64`, and output filename includes `-ARM64-`:

```iss
; Submersion Windows ARM64 Installer
; Built by Inno Setup - https://jrsoftware.org/isinfo.php
;
; Compiled in CI via: iscc /DAPP_VERSION="1.2.5" /DAPP_VERSION_CODE="49" submersion-arm64.iss
; APP_VERSION and APP_VERSION_CODE are passed from the release workflow.

#ifndef APP_VERSION
  #define APP_VERSION "0.0.0"
#endif
#ifndef APP_VERSION_CODE
  #define APP_VERSION_CODE "0"
#endif

; Strip pre-release suffix (e.g. "1.3.3-beta.78" -> "1.3.3") for
; VersionInfoVersion, which only accepts numeric X.X.X.X format.
#define POS Pos("-", APP_VERSION)
#if POS > 0
  #define APP_VERSION_NUMERIC Copy(APP_VERSION, 1, POS - 1)
#else
  #define APP_VERSION_NUMERIC APP_VERSION
#endif

[Setup]
AppId={{B8F4E9A2-7C3D-4E1F-9A5B-2D6E8F0C1A3B}
AppName=Submersion
AppVersion={#APP_VERSION}
AppVerName=Submersion {#APP_VERSION}
AppPublisher=Eric Griffin
AppPublisherURL=https://github.com/submersion-app/submersion
AppSupportURL=https://github.com/submersion-app/submersion/issues
AppUpdatesURL=https://github.com/submersion-app/submersion/releases
DefaultDirName={autopf}\Submersion
DefaultGroupName=Submersion
LicenseFile=..\..\LICENSE
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\submersion.exe
OutputDir=..\..\build\windows\installer
OutputBaseFilename=Submersion-v{#APP_VERSION}-Windows-ARM64-Setup
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=arm64
PrivilegesRequired=admin
WizardStyle=modern
VersionInfoVersion={#APP_VERSION_NUMERIC}.{#APP_VERSION_CODE}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\..\build\windows\arm64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Submersion"; Filename: "{app}\submersion.exe"
Name: "{group}\{cm:UninstallProgram,Submersion}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\Submersion"; Filename: "{app}\submersion.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\submersion.exe"; Description: "{cm:LaunchProgram,Submersion}"; Flags: nowait postinstall skipifsilent
```

- [ ] **Step 3: Commit**

```bash
git add windows/installer/submersion.iss windows/installer/submersion-arm64.iss
git commit -m "feat: add ARM64 Inno Setup config, rename x64 output"
```

---

### Task 2: Update Appcast Script for ARM64

**Files:**
- Modify: `scripts/generate_appcast.sh`

- [ ] **Step 1: Update the appcast script**

Replace the entire content of `scripts/generate_appcast.sh` with:

```bash
#!/usr/bin/env bash
# Generates appcast.xml for Sparkle/WinSparkle auto-updates.
#
# Usage: ./scripts/generate_appcast.sh <version> <build_number> <date> <macos_dmg_url> <windows_x64_url> <windows_arm64_url>
#
# Arguments:
#   version            - Marketing version string (e.g. "1.1.3")
#   build_number       - Build number (e.g. "40"), used as sparkle:version for macOS (CFBundleVersion)
#   date               - RFC 2822 date string for pubDate
#   macos_dmg_url      - Download URL for macOS DMG
#   windows_x64_url    - Download URL for Windows x64 installer
#   windows_arm64_url  - Download URL for Windows ARM64 installer
#
# Requires:
#   SPARKLE_EDDSA_SIGNATURE env var (EdDSA signature of macOS DMG)
#   SPARKLE_DMG_LENGTH env var (byte length of macOS DMG)

set -euo pipefail

VERSION="${1:?Usage: generate_appcast.sh <version> <build_number> <date> <macos_url> <windows_x64_url> <windows_arm64_url>}"
BUILD_NUMBER="${2:?Missing build_number argument}"
DATE="${3}"
MACOS_URL="${4}"
WINDOWS_X64_URL="${5}"
WINDOWS_ARM64_URL="${6}"
EDDSA_SIG="${SPARKLE_EDDSA_SIGNATURE:-}"
DMG_LENGTH="${SPARKLE_DMG_LENGTH:-0}"

cat <<APPCAST
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Submersion Updates</title>
    <item>
      <title>Version ${VERSION}</title>
      <sparkle:version>${BUILD_NUMBER}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <sparkle:releaseNotesLink>https://github.com/submersion-app/submersion/releases/tag/v${VERSION}</sparkle:releaseNotesLink>
      <pubDate>${DATE}</pubDate>
      <enclosure
        url="${MACOS_URL}"
        sparkle:edSignature="${EDDSA_SIG}"
        length="${DMG_LENGTH}"
        type="application/octet-stream"
        sparkle:os="macos"
      />
    </item>
    <item>
      <title>Version ${VERSION}</title>
      <sparkle:version>${VERSION}.${BUILD_NUMBER}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <sparkle:releaseNotesLink>https://github.com/submersion-app/submersion/releases/tag/v${VERSION}</sparkle:releaseNotesLink>
      <pubDate>${DATE}</pubDate>
      <enclosure
        url="${WINDOWS_X64_URL}"
        type="application/octet-stream"
        sparkle:os="windows"
      />
    </item>
    <item>
      <title>Version ${VERSION}</title>
      <sparkle:version>${VERSION}.${BUILD_NUMBER}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <sparkle:releaseNotesLink>https://github.com/submersion-app/submersion/releases/tag/v${VERSION}</sparkle:releaseNotesLink>
      <pubDate>${DATE}</pubDate>
      <enclosure
        url="${WINDOWS_X64_URL}"
        type="application/octet-stream"
        sparkle:os="windows-x64"
      />
    </item>
    <item>
      <title>Version ${VERSION}</title>
      <sparkle:version>${VERSION}.${BUILD_NUMBER}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <sparkle:releaseNotesLink>https://github.com/submersion-app/submersion/releases/tag/v${VERSION}</sparkle:releaseNotesLink>
      <pubDate>${DATE}</pubDate>
      <enclosure
        url="${WINDOWS_ARM64_URL}"
        type="application/octet-stream"
        sparkle:os="windows-arm64"
      />
    </item>
  </channel>
</rss>
APPCAST
```

Note: The `sparkle:os="windows"` item and the `sparkle:os="windows-x64"` item both point to the same x64 installer URL. The `"windows"` entry is a backwards-compatibility shim for old installs. Remove it once old versions have aged out.

- [ ] **Step 2: Verify the script runs**

```bash
SPARKLE_EDDSA_SIGNATURE="test" SPARKLE_DMG_LENGTH="1234" \
  ./scripts/generate_appcast.sh "1.0.0" "50" "$(date -R)" \
  "https://example.com/mac.dmg" \
  "https://example.com/win-x64.exe" \
  "https://example.com/win-arm64.exe"
```

Expected: valid XML output with 4 `<item>` blocks -- one with `sparkle:os="macos"`, one with `sparkle:os="windows"`, one with `sparkle:os="windows-x64"`, and one with `sparkle:os="windows-arm64"`.

- [ ] **Step 3: Commit**

```bash
git add scripts/generate_appcast.sh
git commit -m "feat: add Windows ARM64 and legacy compat entries to appcast"
```

---

### Task 3: Architecture-Aware Platform Suffix in Update Provider

**Files:**
- Modify: `lib/features/auto_update/presentation/providers/update_providers.dart:23-29`

- [ ] **Step 1: Add architecture constant and update `_platformSuffix`**

At the top of the file (after the existing imports), add the architecture constant. Then update `_platformSuffix` to use it for Linux.

Add after line 21 (after the `_appcastUrl` declaration):

```dart
/// CPU architecture, set at build time via --dart-define=ARCH=arm64 (or x64).
/// Defaults to x64 when not specified.
const _arch = String.fromEnvironment('ARCH', defaultValue: 'x64');
```

Then replace the existing `_platformSuffix` getter (lines 23-29):

```dart
/// Platform-specific asset suffix for GitHub Releases downloads.
String get _platformSuffix {
  if (Platform.isMacOS) return 'macOS.dmg';
  if (Platform.isWindows) return 'Windows.zip';
  if (Platform.isLinux) return 'Linux.tar.gz';
  if (Platform.isAndroid) return 'Android.apk';
  return '';
}
```

with:

```dart
/// Platform-specific asset suffix for GitHub Releases downloads.
String get _platformSuffix {
  if (Platform.isMacOS) return 'macOS.dmg';
  if (Platform.isWindows) return 'Windows.zip';
  if (Platform.isLinux) {
    return _arch == 'arm64' ? 'Linux-ARM64.tar.gz' : 'Linux-x64.tar.gz';
  }
  if (Platform.isAndroid) return 'Android.apk';
  return '';
}
```

- [ ] **Step 2: Run format and analyze**

```bash
dart format lib/features/auto_update/presentation/providers/update_providers.dart
flutter analyze --no-fatal-infos lib/features/auto_update/presentation/providers/update_providers.dart
```

Expected: no formatting changes needed, no analysis errors.

- [ ] **Step 3: Commit**

```bash
git add lib/features/auto_update/presentation/providers/update_providers.dart
git commit -m "feat: architecture-aware platform suffix for Linux auto-updates"
```

---

### Task 4: Add ARM64 Jobs to CI Workflow

**Files:**
- Modify: `.github/workflows/ci.yaml:413-537`

- [ ] **Step 1: Rename existing x64 artifact names**

In `.github/workflows/ci.yaml`:

Change the `build-linux` job's artifact upload (line 475):
```yaml
          name: linux-build
```
to:
```yaml
          name: linux-x64-build
```

Change the `build-windows` job's artifact upload (line 536):
```yaml
          name: windows-build
```
to:
```yaml
          name: windows-x64-build
```

- [ ] **Step 2: Add `--dart-define=ARCH=x64` to existing x64 build commands**

In the `build-linux` job, change the Build Linux step (line 468):
```yaml
        run: flutter build linux --release "${{ env.DART_DEFINES }}" -v
```
to:
```yaml
        run: flutter build linux --release "${{ env.DART_DEFINES }}" --dart-define=ARCH=x64 -v
```

In the `build-windows` job, change the Build Windows step (line 529):
```yaml
        run: flutter build windows --release "${{ env.DART_DEFINES }}" -v
```
to:
```yaml
        run: flutter build windows --release "${{ env.DART_DEFINES }}" --dart-define=ARCH=x64 -v
```

- [ ] **Step 3: Add `build-linux-arm64` job**

Insert the following job after the `build-linux` job (after line 477) and before the `build-windows` job:

```yaml
  build-linux-arm64:
    name: Build Linux ARM64
    needs: test
    runs-on: ubuntu-24.04-arm
    steps:
      - uses: actions/checkout@v6
        with:
          submodules: true

      - name: Read Flutter version
        id: flutter-ver
        run: echo "version=$(cat ${{ env.FLUTTER_VERSION_FILE }})" >> "$GITHUB_OUTPUT"

      - uses: subosito/flutter-action@v2
        id: setup-flutter
        with:
          flutter-version: ${{ steps.flutter-ver.outputs.version }}
          channel: 'stable'

      - name: Cache Flutter SDK
        uses: actions/cache@v5
        with:
          path: ${{ steps.setup-flutter.outputs.CACHE-PATH }}
          key: ${{ steps.setup-flutter.outputs.CACHE-KEY }}

      - name: Cache pub dependencies
        uses: actions/cache@v5
        with:
          path: |
            ~/.pub-cache
            ${{ github.workspace }}/.dart_tool
          key: pub-${{ runner.os }}-arm64-${{ hashFiles('**/pubspec.lock') }}
          restore-keys: |
            pub-${{ runner.os }}-arm64-

      - name: Install Linux dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y \
            clang \
            cmake \
            ninja-build \
            pkg-config \
            libgtk-3-dev \
            liblzma-dev \
            libstdc++-12-dev \
            libsecret-1-dev

      - name: Install dependencies
        run: flutter pub get

      - name: Run code generation
        run: dart run build_runner build --delete-conflicting-outputs

      - name: Build Linux ARM64
        run: flutter build linux --release "${{ env.DART_DEFINES }}" --dart-define=ARCH=arm64 -v

      - name: Upload Linux ARM64 artifact
        uses: actions/upload-artifact@v7
        if: github.ref == 'refs/heads/main' && github.event_name == 'push'
        with:
          name: linux-arm64-build
          path: build/linux/arm64/release/bundle
          retention-days: 7
```

Note: The cache key includes `arm64` to avoid sharing caches between x64 and ARM64 runners, which have different binary dependencies.

- [ ] **Step 4: Add `build-windows-arm64` job**

Insert the following job after the `build-windows` job (after line 537, end of file):

```yaml
  build-windows-arm64:
    name: Build Windows ARM64
    needs: test
    runs-on: windows-11-arm
    steps:
      - uses: actions/checkout@v6
        with:
          submodules: true

      - name: Read Flutter version
        id: flutter-ver
        run: echo "version=$(cat ${{ env.FLUTTER_VERSION_FILE }})" >> "$GITHUB_OUTPUT"

      - uses: subosito/flutter-action@v2
        id: setup-flutter
        with:
          flutter-version: ${{ steps.flutter-ver.outputs.version }}
          channel: 'stable'

      - name: Cache Flutter SDK
        uses: actions/cache@v5
        with:
          path: ${{ steps.setup-flutter.outputs.CACHE-PATH }}
          key: ${{ steps.setup-flutter.outputs.CACHE-KEY }}

      - name: Cache pub dependencies
        uses: actions/cache@v5
        with:
          path: |
            ~\.pub-cache
            ${{ github.workspace }}\.dart_tool
          key: pub-${{ runner.os }}-arm64-${{ hashFiles('**/pubspec.lock') }}
          restore-keys: |
            pub-${{ runner.os }}-arm64-

      - name: Cache NuGet packages
        uses: actions/cache@v5
        with:
          path: |
            C:\Users\runneradmin\.nuget\packages
          key: nuget-${{ runner.os }}-arm64-${{ hashFiles('**/pubspec.lock') }}
          restore-keys: |
            nuget-${{ runner.os }}-arm64-

      - name: Install dependencies
        run: flutter pub get

      - name: Run code generation
        run: dart run build_runner build --delete-conflicting-outputs

      - name: Build Windows ARM64
        run: flutter build windows --release "${{ env.DART_DEFINES }}" --dart-define=ARCH=arm64 -v

      - name: Upload Windows ARM64 artifact
        uses: actions/upload-artifact@v7
        if: github.ref == 'refs/heads/main' && github.event_name == 'push'
        with:
          name: windows-arm64-build
          path: build\windows\arm64\runner\Release
          retention-days: 7
```

- [ ] **Step 5: Verify YAML syntax**

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yaml'))" && echo "Valid YAML"
```

Expected: `Valid YAML`

- [ ] **Step 6: Commit**

```bash
git add .github/workflows/ci.yaml
git commit -m "feat: add ARM64 build jobs to CI workflow"
```

---

### Task 5: Update Release Workflow -- Rename x64 Artifacts and Add Legacy Tarball

**Files:**
- Modify: `.github/workflows/release.yml:309-440`

This task modifies the existing `build-windows` and `build-linux` jobs in the release workflow. The ARM64 jobs are added in Tasks 6 and 7.

- [ ] **Step 1: Rename Windows x64 release artifacts**

In the `build-windows` job:

Update the build command (around line 353) to add ARCH define:
```yaml
      - name: Build Windows release
        run: flutter build windows --release --dart-define=UPDATE_CHANNEL=github --dart-define=ARCH=x64
```

Update the installer step (around line 362) -- change the `Move-Item` to match the new output filename:
```yaml
          Move-Item "build\windows\installer\Submersion-*-Windows-x64-Setup.exe" .
```

Update the artifact upload (around line 366-369):
```yaml
      - name: Upload Windows artifact
        uses: actions/upload-artifact@v7
        with:
          name: windows-x64-setup
          path: Submersion-*-Windows-x64-Setup.exe
          retention-days: 5
```

- [ ] **Step 2: Rename Linux x64 release artifacts and add legacy tarball**

In the `build-linux` job:

Update the build command (around line 425) to add ARCH define:
```yaml
      - name: Build Linux release
        run: flutter build linux --release --dart-define=UPDATE_CHANNEL=github --dart-define=ARCH=x64
```

Replace the "Create tarball" step (around lines 428-433) with two steps -- one for the new name, one for the legacy copy:
```yaml
      - name: Create tarball
        env:
          TAG_NAME: ${{ github.ref_name }}
        run: |
          cd build/linux/x64/release/bundle
          tar czf "$GITHUB_WORKSPACE/Submersion-${TAG_NAME}-Linux-x64.tar.gz" .

      - name: Create legacy tarball (backwards compatibility)
        env:
          TAG_NAME: ${{ github.ref_name }}
        run: |
          cp "Submersion-${TAG_NAME}-Linux-x64.tar.gz" "Submersion-${TAG_NAME}-Linux.tar.gz"
```

Update the artifact upload (around line 436-440) to upload both tarballs:
```yaml
      - name: Upload Linux artifact
        uses: actions/upload-artifact@v7
        with:
          name: linux-x64-tar
          path: Submersion-*-Linux*.tar.gz
          retention-days: 5
```

Note: The glob `Submersion-*-Linux*.tar.gz` captures both `Linux-x64.tar.gz` and `Linux.tar.gz`.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/release.yml
git commit -m "feat: rename x64 release artifacts, add legacy Linux tarball"
```

---

### Task 6: Add Linux ARM64 Release Job

**Files:**
- Modify: `.github/workflows/release.yml` (insert new job after `build-linux`)

- [ ] **Step 1: Add `build-linux-arm64` release job**

Insert the following job after the existing `build-linux` job (after the Linux artifact upload step) and before the `build-android` job:

```yaml
  # ============================================================================
  # Linux ARM64 Build
  # ============================================================================
  build-linux-arm64:
    name: Build Linux ARM64
    runs-on: ubuntu-24.04-arm
    timeout-minutes: 30

    steps:
      - name: Checkout repository
        uses: actions/checkout@v6
        with:
          submodules: recursive

      - name: Read Flutter version
        id: flutter-ver
        run: echo "version=$(cat ${{ env.FLUTTER_VERSION_FILE }})" >> "$GITHUB_OUTPUT"

      - name: Install Linux dependencies
        run: |
          sudo apt-get update -y
          sudo apt-get install -y \
            clang cmake ninja-build pkg-config \
            libgtk-3-dev liblzma-dev libstdc++-12-dev \
            libsqlite3-dev libsecret-1-dev

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        id: setup-flutter
        with:
          flutter-version: ${{ steps.flutter-ver.outputs.version }}
          channel: stable

      - name: Cache Flutter SDK
        uses: actions/cache@v5
        with:
          path: ${{ steps.setup-flutter.outputs.CACHE-PATH }}
          key: ${{ steps.setup-flutter.outputs.CACHE-KEY }}

      - name: Cache pub dependencies
        uses: actions/cache@v5
        with:
          path: |
            ~/.pub-cache
            ${{ github.workspace }}/.dart_tool
          key: pub-${{ runner.os }}-arm64-${{ hashFiles('**/pubspec.lock') }}
          restore-keys: |
            pub-${{ runner.os }}-arm64-

      - name: Install dependencies
        run: |
          flutter pub get
          dart run build_runner build --delete-conflicting-outputs

      - name: Build Linux ARM64 release
        run: flutter build linux --release --dart-define=UPDATE_CHANNEL=github --dart-define=ARCH=arm64

      - name: Create tarball
        env:
          TAG_NAME: ${{ github.ref_name }}
        run: |
          cd build/linux/arm64/release/bundle
          tar czf "$GITHUB_WORKSPACE/Submersion-${TAG_NAME}-Linux-ARM64.tar.gz" .

      - name: Upload Linux ARM64 artifact
        uses: actions/upload-artifact@v7
        with:
          name: linux-arm64-tar
          path: Submersion-*-Linux-ARM64.tar.gz
          retention-days: 5
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/release.yml
git commit -m "feat: add Linux ARM64 release build job"
```

---

### Task 7: Add Windows ARM64 Release Job

**Files:**
- Modify: `.github/workflows/release.yml` (insert new job after `build-windows`)

- [ ] **Step 1: Add `build-windows-arm64` release job**

Insert the following job after the existing `build-windows` job and before the `build-linux` job:

```yaml
  # ============================================================================
  # Windows ARM64 Build
  # ============================================================================
  build-windows-arm64:
    name: Build Windows ARM64
    runs-on: windows-11-arm
    timeout-minutes: 30

    steps:
      - name: Checkout repository
        uses: actions/checkout@v6
        with:
          submodules: recursive

      - name: Read Flutter version
        id: flutter-ver
        run: echo "version=$(cat ${{ env.FLUTTER_VERSION_FILE }})" >> "$GITHUB_OUTPUT"

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        id: setup-flutter
        with:
          flutter-version: ${{ steps.flutter-ver.outputs.version }}
          channel: stable

      - name: Cache Flutter SDK
        uses: actions/cache@v5
        with:
          path: ${{ steps.setup-flutter.outputs.CACHE-PATH }}
          key: ${{ steps.setup-flutter.outputs.CACHE-KEY }}

      - name: Cache pub dependencies
        uses: actions/cache@v5
        with:
          path: |
            ~\.pub-cache
            ${{ github.workspace }}\.dart_tool
          key: pub-${{ runner.os }}-arm64-${{ hashFiles('**/pubspec.lock') }}
          restore-keys: |
            pub-${{ runner.os }}-arm64-

      - name: Install dependencies
        run: |
          flutter pub get
          dart run build_runner build --delete-conflicting-outputs

      - name: Build Windows ARM64 release
        run: flutter build windows --release --dart-define=UPDATE_CHANNEL=github --dart-define=ARCH=arm64

      - name: Install Inno Setup
        run: choco install innosetup -y --no-progress

      - name: Build Windows ARM64 installer
        env:
          TAG_NAME: ${{ github.ref_name }}
        run: |
          $version = "$env:TAG_NAME" -replace '^v', ''
          $buildNumber = (Select-String -Path pubspec.yaml -Pattern '^\s*version:.*\+(\d+)' | ForEach-Object { $_.Matches.Groups[1].Value })
          iscc /DAPP_VERSION="$version" /DAPP_VERSION_CODE="$buildNumber" windows\installer\submersion-arm64.iss
          Move-Item "build\windows\installer\Submersion-*-Windows-ARM64-Setup.exe" .

      - name: Upload Windows ARM64 artifact
        uses: actions/upload-artifact@v7
        with:
          name: windows-arm64-setup
          path: Submersion-*-Windows-ARM64-Setup.exe
          retention-days: 5
```

Note: The `choco install innosetup` step ensures Inno Setup is available on the `windows-11-arm` runner. On `windows-latest` (x64) it comes pre-installed, but the ARM64 runner image may not include it.

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/release.yml
git commit -m "feat: add Windows ARM64 release build job"
```

---

### Task 8: Update Downstream Release Jobs

**Files:**
- Modify: `.github/workflows/release.yml` (generate-appcast, create-release, validate-release jobs)

- [ ] **Step 1: Update `generate-appcast` job**

Update the `needs` list (around line 889):
```yaml
    needs: [build-macos, build-windows, build-windows-arm64, build-linux, build-linux-arm64, build-android, build-ios]
```

Update the appcast generation step (around lines 900-911). Replace the `run:` block:
```yaml
      - name: Generate appcast.xml
        env:
          TAG_NAME: ${{ github.ref_name }}
          SPARKLE_EDDSA_SIGNATURE: ${{ needs.build-macos.outputs.eddsa-signature }}
          SPARKLE_DMG_LENGTH: ${{ needs.build-macos.outputs.dmg-length }}
        run: |
          VERSION="${TAG_NAME#v}"
          BUILD_NUMBER=$(grep '^version:' pubspec.yaml | sed 's/.*+//')
          DATE=$(date -R)
          MACOS_URL="https://github.com/${{ github.repository }}/releases/download/${TAG_NAME}/Submersion-${TAG_NAME}-macOS.dmg"
          WINDOWS_X64_URL="https://github.com/${{ github.repository }}/releases/download/${TAG_NAME}/Submersion-${TAG_NAME}-Windows-x64-Setup.exe"
          WINDOWS_ARM64_URL="https://github.com/${{ github.repository }}/releases/download/${TAG_NAME}/Submersion-${TAG_NAME}-Windows-ARM64-Setup.exe"
          ./scripts/generate_appcast.sh "$VERSION" "$BUILD_NUMBER" "$DATE" "$MACOS_URL" "$WINDOWS_X64_URL" "$WINDOWS_ARM64_URL" > appcast.xml
```

- [ ] **Step 2: Update `create-release` job**

Update the `needs` list (around line 936):
```yaml
    needs: [build-macos, build-windows, build-windows-arm64, build-linux, build-linux-arm64, build-android, build-ios, generate-appcast]
```

The `files:` glob (`Submersion-*`) already captures all artifacts automatically. No changes needed to the release step itself.

- [ ] **Step 3: Update `validate-release` expected assets**

Replace the expected assets loop (around lines 1002-1009):
```yaml
          for expected in \
            "Submersion-${TAG_NAME}-macOS.dmg" \
            "Submersion-${TAG_NAME}-Windows-x64-Setup.exe" \
            "Submersion-${TAG_NAME}-Windows-ARM64-Setup.exe" \
            "Submersion-${TAG_NAME}-Linux-x64.tar.gz" \
            "Submersion-${TAG_NAME}-Linux.tar.gz" \
            "Submersion-${TAG_NAME}-Linux-ARM64.tar.gz" \
            "Submersion-${TAG_NAME}-Android.apk" \
            "Submersion-${TAG_NAME}-Android.aab" \
            "appcast.xml" \
            "checksums-sha256.txt"; do
```

- [ ] **Step 4: Update `upload-macos`, `upload-ios`, `upload-android` needs lists**

These upload jobs gate on all builds succeeding. Update their `needs` lists to include the new ARM64 build jobs.

`upload-macos` (around line 693):
```yaml
    needs: [build-macos, build-windows, build-windows-arm64, build-linux, build-linux-arm64, build-android, build-ios]
```

`upload-ios` (around line 761):
```yaml
    needs: [build-macos, build-windows, build-windows-arm64, build-linux, build-linux-arm64, build-android, build-ios]
```

`upload-android` (around line 835):
```yaml
    needs: [build-macos, build-windows, build-windows-arm64, build-linux, build-linux-arm64, build-android, build-ios]
```

- [ ] **Step 5: Verify YAML syntax**

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/release.yml'))" && echo "Valid YAML"
```

Expected: `Valid YAML`

- [ ] **Step 6: Commit**

```bash
git add .github/workflows/release.yml
git commit -m "feat: update downstream release jobs for ARM64 builds"
```

---

### Task 9: Format, Verify, and Final Commit

- [ ] **Step 1: Run dart format**

```bash
dart format lib/features/auto_update/presentation/providers/update_providers.dart
```

Expected: no changes (already formatted in Task 3).

- [ ] **Step 2: Run flutter analyze**

```bash
flutter analyze --no-fatal-infos
```

Expected: no new errors or warnings from our changes.

- [ ] **Step 3: Run tests**

```bash
flutter test
```

Expected: all tests pass. Our changes to `update_providers.dart` are minimal (adding a const and modifying a getter) and should not break any existing tests.

- [ ] **Step 4: Verify all YAML files**

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yaml'))" && echo "ci.yaml: Valid"
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/release.yml'))" && echo "release.yml: Valid"
```

Expected: both files valid.

- [ ] **Step 5: Verify appcast script**

```bash
SPARKLE_EDDSA_SIGNATURE="test" SPARKLE_DMG_LENGTH="1234" \
  ./scripts/generate_appcast.sh "1.0.0" "50" "$(date -R)" \
  "https://example.com/mac.dmg" \
  "https://example.com/win-x64.exe" \
  "https://example.com/win-arm64.exe" \
  | python3 -c "import xml.etree.ElementTree as ET, sys; ET.parse(sys.stdin); print('Valid XML')"
```

Expected: `Valid XML`

---

## Post-Implementation Notes

**First CI run:** The ARM64 jobs will run on GitHub's native ARM runners. Watch for:
- `libstdc++-12-dev` package availability on `ubuntu-24.04-arm` (may need `libstdc++-13-dev` or `libstdc++-14-dev` depending on what's available)
- Inno Setup availability/compatibility on `windows-11-arm`
- MSVC `/await` flag compatibility on ARM64 (used by `libdivecomputer_plugin` Windows CMakeLists.txt)
- `subosito/flutter-action@v2` ARM64 runner compatibility

**WinSparkle investigation (deferred):** After the builds are working, verify that WinSparkle correctly filters `sparkle:os="windows-x64"` vs `sparkle:os="windows-arm64"`. If it doesn't, fall back to separate appcast files per architecture as described in the spec.

**Legacy cleanup (future):** Once old installs have updated:
- Remove `sparkle:os="windows"` entry from appcast
- Remove legacy `Submersion-${TAG_NAME}-Linux.tar.gz` tarball from release workflow
- Remove legacy name from `validate-release` expected assets
