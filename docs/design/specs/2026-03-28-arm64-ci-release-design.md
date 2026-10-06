# ARM64 CI & Release Builds Design

**Date:** 2026-03-28
**Status:** Approved

## Summary

Add Windows ARM64 and Linux ARM64 build support to both the CI workflow
(`ci.yaml`) and the release workflow (`release.yml`). Uses native GitHub Actions
ARM64 runners (`ubuntu-24.04-arm`, `windows-11-arm`) which are free for public
repositories. All ARM64 builds are production-grade.

## Approach

Duplicate jobs (one job per platform/architecture) following the existing
one-job-per-platform pattern. Each ARM64 job is a near-copy of its x64
counterpart but targets the ARM runner. This is the simplest, most readable
approach and allows independent failure/re-run per architecture.

## CI Workflow Changes (`ci.yaml`)

### New Jobs

**`build-linux-arm64`:**
- `runs-on: ubuntu-24.04-arm`
- `needs: test` (tests are architecture-independent Dart, run once on x64)
- Same steps as `build-linux`: install apt deps, Flutter setup, pub get, codegen,
  `flutter build linux --release`
- Flutter auto-detects the host architecture on the ARM runner
- Artifact path: `build/linux/arm64/release/bundle`
- Artifact name: `linux-arm64-build`

**`build-windows-arm64`:**
- `runs-on: windows-11-arm`
- `needs: test`
- Same steps as `build-windows`: Flutter setup, pub get, codegen,
  `flutter build windows --release`
- Artifact path: `build\windows\arm64\runner\Release`
- Artifact name: `windows-arm64-build`

### Renamed Existing Artifacts

For naming consistency across all desktop builds:
- `linux-build` -> `linux-x64-build`
- `windows-build` -> `windows-x64-build`

## Release Workflow Changes (`release.yml`)

### New Jobs

**`build-linux-arm64`:**
- `runs-on: ubuntu-24.04-arm`, timeout 30 min
- Same steps as release `build-linux`: checkout w/ submodules, install system
  deps, Flutter setup, pub get, codegen, build
- Produces tarball: `Submersion-${TAG_NAME}-Linux-ARM64.tar.gz`
- Artifact name: `linux-arm64-tar`

**`build-windows-arm64`:**
- `runs-on: windows-11-arm`, timeout 30 min
- Same steps as release `build-windows`: checkout w/ submodules, Flutter setup,
  pub get, codegen, build
- Uses new Inno Setup config: `windows/installer/submersion-arm64.iss`
- Produces installer: `Submersion-${TAG_NAME}-Windows-ARM64-Setup.exe`
- Artifact name: `windows-arm64-setup`

### Renamed Existing Release Artifacts

- `Submersion-${TAG_NAME}-Windows-Setup.exe` ->
  `Submersion-${TAG_NAME}-Windows-x64-Setup.exe`
- `Submersion-${TAG_NAME}-Linux.tar.gz` ->
  `Submersion-${TAG_NAME}-Linux-x64.tar.gz`
- Artifact names: `windows-setup` -> `windows-x64-setup`,
  `linux-tar` -> `linux-x64-tar`

### Legacy Compatibility Assets

To avoid breaking auto-updates for existing installs:

- **Linux:** Upload the x64 tarball under both names --
  `Submersion-${TAG_NAME}-Linux.tar.gz` (legacy) and
  `Submersion-${TAG_NAME}-Linux-x64.tar.gz` (new). Both are the same file.
  Remove the legacy name once old versions have aged out.

### Updated Downstream Jobs

- `generate-appcast`: `needs` list gains `build-linux-arm64`,
  `build-windows-arm64`
- `create-release`: `needs` list gains same two jobs
- `validate-release`: expected assets list updated to include ARM64 artifacts
  and the new x64-qualified names, plus the legacy `Linux.tar.gz` name

## Inno Setup Changes

### New File: `windows/installer/submersion-arm64.iss`

Copy of `submersion.iss` with these differences:
- `ArchitecturesAllowed=arm64`
- Source path: `build\windows\arm64\runner\Release\*`
- Output filename: `Submersion-v{VERSION}-Windows-ARM64-Setup`

### Existing File: `windows/installer/submersion.iss`

- Update output filename to include `-x64-`:
  `Submersion-v{VERSION}-Windows-x64-Setup`

## Appcast & Auto-Update Changes

### `scripts/generate_appcast.sh`

Accept a 6th argument: `windows_arm64_url`.

Produce 4 `<item>` blocks:

| `sparkle:os` | Target | URL |
|--------------|--------|-----|
| `macos` | macOS DMG | macOS URL (unchanged) |
| `windows` | Windows x64 (legacy) | x64 installer URL |
| `windows-x64` | Windows x64 (new clients) | Same x64 installer URL |
| `windows-arm64` | Windows ARM64 | ARM64 installer URL |

The `sparkle:os="windows"` entry is a backwards-compatibility shim. Old
WinSparkle clients match `"windows"` and get the x64 installer. New clients
(built with architecture awareness) match `"windows-x64"` or
`"windows-arm64"`. The legacy `"windows"` entry will be removed in a future
release once old installs have updated.

### `update_providers.dart`

- `_platformSuffix` becomes architecture-aware for Linux: return
  `'Linux-ARM64.tar.gz'` or `'Linux-x64.tar.gz'` based on build-time config
- Architecture is set via `--dart-define=ARCH=arm64` (or `x64`) in the CI
  workflow build step. This is simpler and more reliable than runtime detection
  since we fully control the build environment. `_platformSuffix` reads
  `const String.fromEnvironment('ARCH', defaultValue: 'x64')` to select the
  correct suffix

### Risk: WinSparkle Architecture Filtering

WinSparkle's support for `sparkle:os="windows-x64"` vs
`sparkle:os="windows-arm64"` needs verification during implementation. If
WinSparkle does not support these values natively, fallback options:
1. Use separate appcast files per architecture (`appcast.xml` for x64,
   `appcast-arm64.xml` for ARM64), baked in at build time via `--dart-define`
2. Configure WinSparkle with a custom system profile string that includes
   architecture

## Native Plugin (libdivecomputer)

### No Source Changes Expected

**Linux (`packages/libdivecomputer_plugin/linux/`):**
- `config.h` is architecture-neutral (OS-level feature flags only)
- `CMakeLists.txt` is architecture-neutral; CMake picks up the ARM64 toolchain
  from the runner automatically

**Windows (`packages/libdivecomputer_plugin/windows/`):**
- `config.h` is architecture-neutral
- `CMakeLists.txt` uses `/await` compiler flag -- verify this works on ARM64 MSVC
- C++/WinRT (used by BLE scanner) is supported on ARM64

### Verification

The first ARM64 CI run will validate that the native plugin compiles. Any issues
will surface as compiler/linker errors to fix incrementally.

## Out of Scope

- **macOS:** Already universal binary (Apple Silicon + Intel) via the macOS runner
- **iOS / Android:** Already architecture-independent (Flutter handles this)
- **New secrets or infrastructure:** Not required -- native ARM runners are free
  for public repos
- **Linux auto-update via appcast:** Linux uses `GithubUpdateService`, not Sparkle

## Release Artifact Matrix (Post-Change)

| Platform | Architecture | Artifact Name | Format |
|----------|-------------|---------------|--------|
| macOS | Universal | `Submersion-vX.Y.Z-macOS.dmg` | DMG |
| Windows | x64 | `Submersion-vX.Y.Z-Windows-x64-Setup.exe` | Inno Setup |
| Windows | ARM64 | `Submersion-vX.Y.Z-Windows-ARM64-Setup.exe` | Inno Setup |
| Linux | x64 | `Submersion-vX.Y.Z-Linux-x64.tar.gz` | Tarball |
| Linux | x64 (legacy) | `Submersion-vX.Y.Z-Linux.tar.gz` | Tarball |
| Linux | ARM64 | `Submersion-vX.Y.Z-Linux-ARM64.tar.gz` | Tarball |
| Android | Universal | `Submersion-vX.Y.Z-Android.apk` | APK |
| Android | Universal | `Submersion-vX.Y.Z-Android.aab` | AAB |
| iOS | Universal | `Submersion-vX.Y.Z-iOS.ipa` | IPA |
