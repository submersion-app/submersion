# Windows Inno Setup Installer Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the raw ZIP Windows release artifact with a proper Inno Setup installer that provides Start Menu shortcuts, Add/Remove Programs entry, and clean uninstall.

**Architecture:** Create an Inno Setup `.iss` script in `windows/installer/`, compile it with `iscc` in the CI release workflow, and update all downstream references (appcast, validation) from `.zip` to `-Setup.exe`.

**Tech Stack:** Inno Setup 6 (pre-installed on GitHub Actions `windows-latest`), PowerShell, Bash

---

### Task 1: Create Inno Setup Script

**Files:**

- Create: `windows/installer/submersion.iss`

**Step 1: Create the installer directory**

```bash
mkdir -p windows/installer
```text
**Step 2: Write the Inno Setup script**

Create `windows/installer/submersion.iss` with this exact content:

```iss
; Submersion Windows Installer
; Built by Inno Setup - https://jrsoftware.org/isinfo.php
;
; Compiled in CI via: iscc /DAPP_VERSION="1.2.5" /DAPP_VERSION_CODE="49" submersion.iss
; APP_VERSION and APP_VERSION_CODE are passed from the release workflow.

#ifndef APP_VERSION
  #define APP_VERSION "0.0.0"
#endif
#ifndef APP_VERSION_CODE
  #define APP_VERSION_CODE "0"
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
OutputBaseFilename=Submersion-v{#APP_VERSION}-Windows-Setup
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallMode=x64compatible
PrivilegesRequired=admin
WizardStyle=modern
VersionInfoVersion={#APP_VERSION}.{#APP_VERSION_CODE}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Submersion"; Filename: "{app}\submersion.exe"
Name: "{group}\{cm:UninstallProgram,Submersion}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\Submersion"; Filename: "{app}\submersion.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\submersion.exe"; Description: "{cm:LaunchProgram,Submersion}"; Flags: nowait postinstall skipifsilent
```text
**Step 3: Verify the file was created**

```bash
cat windows/installer/submersion.iss | head -5
```text
Expected: First 5 lines of the .iss file.

**Step 4: Commit**

```bash
git add windows/installer/submersion.iss
git commit -m "feat: add Inno Setup installer script for Windows"
```diff
---

### Task 2: Update Release Workflow - Windows Build Job

**Files:**

- Modify: `.github/workflows/release.yml:286-297` (the ZIP + upload steps in `build-windows`)

**Step 1: Replace ZIP step with Inno Setup compile**

In `.github/workflows/release.yml`, replace lines 286-291:

```yaml
      - name: Create ZIP archive
        env:
          TAG_NAME: ${{ github.ref_name }}
        run: |
          Compress-Archive -Path "build\windows\x64\runner\Release\*" -DestinationPath "Submersion-${env:TAG_NAME}-Windows.zip"
```text
With:

```yaml
      - name: Build Windows installer
        env:
          TAG_NAME: ${{ github.ref_name }}
        run: |
          $version = "$env:TAG_NAME" -replace '^v', ''
          $buildNumber = (Select-String -Path pubspec.yaml -Pattern '^\s*version:.*\+(\d+)' | ForEach-Object { $_.Matches.Groups[1].Value })
          iscc /DAPP_VERSION="$version" /DAPP_VERSION_CODE="$buildNumber" windows\installer\submersion.iss
          Move-Item "build\windows\installer\Submersion-*-Windows-Setup.exe" .
```text
**Step 2: Update artifact upload step**

Replace lines 293-297:

```yaml
      - name: Upload Windows artifact
        uses: actions/upload-artifact@v7
        with:
          name: windows-zip
          path: Submersion-*.zip
          retention-days: 5
```text
With:

```yaml
      - name: Upload Windows artifact
        uses: actions/upload-artifact@v7
        with:
          name: windows-setup
          path: Submersion-*-Setup.exe
          retention-days: 5
```text
**Step 3: Commit**

```bash
git add .github/workflows/release.yml
git commit -m "ci: build Windows installer instead of ZIP in release workflow"
```diff
---

### Task 3: Update Appcast Generation

**Files:**

- Modify: `scripts/generate_appcast.sh:4-5,11` (usage comment and parameter name)
- Modify: `.github/workflows/release.yml:604` (Windows URL in generate-appcast job)

**Step 1: Update the appcast script comments**

In `scripts/generate_appcast.sh`, update the usage comment on line 4:

```bash
# Usage: ./scripts/generate_appcast.sh <version> <build_number> <date> <macos_dmg_url> <windows_url>
```text
And line 11:

```bash
#   windows_url     - Download URL for Windows installer
```text
**Step 2: Update the Windows URL in the release workflow**

In `.github/workflows/release.yml`, change line 604:

```yaml
          WINDOWS_URL="https://github.com/${{ github.repository }}/releases/download/${TAG_NAME}/Submersion-${TAG_NAME}-Windows.zip"
```text
To:

```yaml
          WINDOWS_URL="https://github.com/${{ github.repository }}/releases/download/${TAG_NAME}/Submersion-${TAG_NAME}-Windows-Setup.exe"
```text
**Step 3: Commit**

```bash
git add scripts/generate_appcast.sh .github/workflows/release.yml
git commit -m "ci: update appcast generation for Windows installer URL"
```diff
---

### Task 4: Update Release Validation

**Files:**

- Modify: `.github/workflows/release.yml:698` (expected asset name in validate-release job)

**Step 1: Update expected Windows asset name**

In `.github/workflows/release.yml`, change line 698:

```bash
            "Submersion-${TAG_NAME}-Windows.zip" \
```text
To:

```bash
            "Submersion-${TAG_NAME}-Windows-Setup.exe" \
```text
**Step 2: Commit**

```bash
git add .github/workflows/release.yml
git commit -m "ci: update release validation for Windows installer artifact name"
```diff
---

### Task 5: Review All Changes

**Step 1: Verify all changes are consistent**

```bash
git log --oneline -4
```text
Expected: 4 commits for tasks 1-4.

**Step 2: Search for any remaining references to `Windows.zip`**

```bash
grep -r "Windows.zip" . --include="*.yml" --include="*.yaml" --include="*.sh" --include="*.md"
```text
Expected: Only matches in the design doc (`docs/plans/2026-03-02-windows-installer-design.md`), not in any workflow or script files.

**Step 3: Verify the .iss file references valid paths**

```bash
ls windows/runner/resources/app_icon.ico && echo "Icon exists" || echo "MISSING"
ls LICENSE && echo "License exists" || echo "MISSING"
```

Expected: Both files exist.
