# Windows Installer with Inno Setup

## Summary

Replace the raw ZIP artifact for Windows releases with a proper Inno Setup installer (.exe). This gives users a standard Windows install experience: Start Menu shortcuts, Add/Remove Programs entry, and clean uninstall.

## Current State

The `build-windows` job in `release.yml` runs `flutter build windows --release`, then zips the entire `build\windows\x64\runner\Release\` folder into `Submersion-v*-Windows.zip`. Users must extract the ZIP and manually find the executable. No Start Menu entry, no uninstaller.

## Design

### New File: `windows/installer/submersion.iss`

Inno Setup script defining the installer behavior:

- **App name**: Submersion
- **Publisher**: Eric Griffin
- **Install directory**: `{autopf}\Submersion` (resolves to `C:\Program Files\Submersion\` on 64-bit)
- **Privileges**: Admin elevation required (standard for Program Files installs)
- **Architecture**: 64-bit only (`ArchitecturesAllowed=x64compatible`, `ArchitecturesInstallMode=x64compatible`)
- **Source files**: Recursively includes everything from `build\windows\x64\runner\Release\`
- **Icons**: Start Menu folder with app shortcut + optional Desktop shortcut
- **Uninstall**: Registered in Add/Remove Programs, removes installed files
- **License**: Displays GPLv3 from the project root `LICENSE` file
- **Installer icon**: Uses `windows\runner\resources\app_icon.ico`
- **Version info**: Passed via `/D` defines from CI (`APP_VERSION`, `APP_VERSION_CODE`)
- **Output**: `Submersion-{version}-Windows-Setup.exe`

### CI Changes: `.github/workflows/release.yml`

In the `build-windows` job, replace:

```yaml
# BEFORE
- name: Create ZIP archive
  run: |
    Compress-Archive -Path "build\windows\x64\runner\Release\*" -DestinationPath "Submersion-${env:TAG_NAME}-Windows.zip"
```text
With:

```yaml
# AFTER
- name: Build Windows installer
  run: |
    $version = "$env:TAG_NAME" -replace '^v', ''
    $buildNumber = (Select-String -Path pubspec.yaml -Pattern '^\s*version:.*\+(\d+)' | ForEach-Object { $_.Matches.Groups[1].Value })
    iscc /DAPP_VERSION="$version" /DAPP_VERSION_CODE="$buildNumber" windows\installer\submersion.iss
    Move-Item "build\windows\installer\Submersion-*-Windows-Setup.exe" .
```

Artifact upload pattern changes from `Submersion-*.zip` to `Submersion-*-Setup.exe`.

### Appcast Changes: `scripts/generate_appcast.sh`

- Rename parameter from `windows_zip_url` to `windows_url`
- The URL now points to `Submersion-v*-Windows-Setup.exe` instead of a ZIP
- WinSparkle handles `.exe` installers natively (downloads and runs the installer for silent update)

### Validation Changes

In the `validate-release` job, the expected Windows asset changes from `Submersion-${TAG_NAME}-Windows.zip` to `Submersion-${TAG_NAME}-Windows-Setup.exe`.

### Appcast Generation Changes

In the `generate-appcast` job, the Windows URL construction changes to use `-Windows-Setup.exe` suffix.

## What Does Not Change

- Flutter build step (`flutter build windows --release`)
- Any Dart application code
- Auto-update Dart code (WinSparkle handles installer .exe natively)
- macOS, Linux, Android, iOS builds
- No code signing (can be added later with a certificate)

## Dependencies

- `iscc` (Inno Setup compiler) is pre-installed on GitHub Actions `windows-latest` runners
- No new packages or secrets required
