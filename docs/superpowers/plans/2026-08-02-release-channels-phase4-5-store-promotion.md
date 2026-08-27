# Release Channels Phases 4-5: Store Beta Lanes & Promotion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire the mobile/store beta lanes into `beta.yml` (TestFlight external group with public link, Play open-testing track), fill the in-app enrollment links, and build `promote.yml` — the metadata-only promotion that turns a soaked beta into the stable release everywhere (GitHub + appcast, Play track promotion, App Store submission of the existing build, and the version-bump PR).

**Architecture:** New parallel fastlane lanes (`upload_testflight_beta` on iOS/macOS with external distribution, `upload_beta` and `promote_to_production` on Android) leave today's lanes untouched for the legacy tag path. `beta.yml` gains three upload jobs modeled byte-for-byte on `release.yml`'s upload jobs. `promote.yml` is `workflow_dispatch`-only: it copies artifacts from the chosen `beta-builds` release, re-hosts them as the main-repo stable release with an appcast entry built from the stored Sparkle signature, promotes/submits the identical store builds, and opens the bump PR that reopens the beta train.

**Tech Stack:** GitHub Actions, fastlane (`upload_to_testflight`, `upload_to_play_store`, `upload_to_app_store`), `gh` CLI, bash.

## Global Constraints

- No new secrets: `BETA_BUILDS_TOKEN`, `APP_STORE_CONNECT_API_KEY_*`, `GOOGLE_PLAY_SERVICE_ACCOUNT_KEY` all exist. `GITHUB_TOKEN` job permissions are declared per job, minimal.
- Existing fastlane lanes (`upload`, `upload_only`, `upload_testflight_only`, `validate`) are NOT modified — `release.yml`'s legacy tag path keeps working unchanged.
- YAML validated with `python3 -c "import yaml,sys; yaml.safe_load(open(sys.argv[1]))" <file>`; Ruby Fastfiles syntax-checked with `ruby -c <file>`.
- Store uploads cannot be exercised without live credentials: the acceptance test for Phase 4 is the first real merge after this stack lands on `main`; for Phase 5 it is the first deliberate promotion. Both are called out as monitored events, not fire-and-forget.
- Dart: only `beta_program_links.dart` changes; `dart format .` + `flutter analyze` still must pass.
- Branch `release-channels-phase4-5` (stacked on phase3 → #822). Commit per task.

---

### Task 1: USER ACTIONS — store-side beta program setup

Nothing in this task is code; it gates when the lanes can actually deliver. Collect the results before Task 4.

- [ ] **Step 1 (user): TestFlight external group.** In App Store Connect → Submersion → TestFlight (repeat for iOS and macOS platforms of the app record): create an external tester group named exactly `Public Beta`, and enable its **public link**. Record the link (`https://testflight.apple.com/join/XXXXXXXX`). The first beta build of each version train distributed to this group triggers Beta App Review (~hours, once per train).
- [ ] **Step 2 (user): Play open testing.** The first `upload_beta` run (Task 5's post-merge acceptance) creates a release on the `beta` track; then in Play Console → Testing → Open testing: confirm the track is configured as **open** (anyone with the link can join) and publish it. The opt-in URL is deterministic: `https://play.google.com/apps/testing/app.submersion`.
- [ ] **Step 3 (user): create the promotion-gate label** (used by `promote.yml`'s preflight):

```bash
env -u GITHUB_TOKEN gh label create beta-blocker --repo submersion-app/submersion \
  --color B60205 --description "Blocks promoting the current beta to stable"
```

---

### Task 2: fastlane beta lanes

**Files:**
- Modify: `android/fastlane/Fastfile`
- Modify: `ios/fastlane/Fastfile`
- Modify: `macos/fastlane/Fastfile`

**Interfaces:**
- Produces: android lanes `upload_beta` and `promote_to_production` (options: `version_code`, `rollout`); ios/macos lane `upload_testflight_beta` (options: `ipa:`/`pkg:`, reads `BETA_CHANGELOG` env). Tasks 3 and 5 invoke these exact names.

- [ ] **Step 1: Android lanes.** In `android/fastlane/Fastfile`, after the `validate` lane, add:

```ruby
  desc "Upload AAB to the open-testing (beta) track, released"
  lane :upload_beta do
    aab_path = find_aab

    UI.message("Uploading to the open testing (beta) track...")
    upload_to_play_store(
      aab: aab_path,
      track: "beta",
      release_status: "completed",
      skip_upload_metadata: true,
      skip_upload_changelogs: true,
      skip_upload_images: true,
      skip_upload_screenshots: true,
    )

    UI.success("AAB released to the open testing track!")
  end

  desc "Promote an existing beta-track build to production (no upload)"
  lane :promote_to_production do |options|
    version_code = options[:version_code] || UI.user_error!("version_code is required")
    rollout = options[:rollout] || "1.0"

    UI.message("Promoting build #{version_code} from beta to production (rollout #{rollout})...")
    upload_to_play_store(
      track: "beta",
      track_promote_to: "production",
      version_code: version_code,
      rollout: rollout,
      skip_upload_aab: true,
      skip_upload_apk: true,
      skip_upload_metadata: true,
      skip_upload_changelogs: true,
      skip_upload_images: true,
      skip_upload_screenshots: true,
    )

    UI.success("Build #{version_code} promoted to production!")
  end
```

- [ ] **Step 2: iOS beta TestFlight lane.** In `ios/fastlane/Fastfile`, after `upload_testflight_only`, add:

```ruby
  desc "Upload pre-built IPA to TestFlight and distribute to the Public Beta group"
  lane :upload_testflight_beta do |options|
    api_key = load_api_key
    ipa_path = options[:ipa] || "./build/Submersion.ipa"

    UI.message("Uploading IPA to TestFlight (Public Beta): #{ipa_path}")
    # distribute_external requires waiting for processing so the build can be
    # assigned to the group; expect several minutes per upload.
    upload_to_testflight(
      api_key: api_key,
      ipa: ipa_path,
      distribute_external: true,
      groups: ["Public Beta"],
      changelog: ENV["BETA_CHANGELOG"] || "Automated beta build.",
    )
    UI.success("iOS beta distributed to the Public Beta group!")
  end
```

- [ ] **Step 3: macOS beta TestFlight lane.** Same in `macos/fastlane/Fastfile` after its `upload_testflight_only`, with `pkg_path = options[:pkg] || "./build/Submersion.pkg"` and `pkg: pkg_path` instead of `ipa:`.

- [ ] **Step 4: Syntax-check and commit:**

```bash
ruby -c android/fastlane/Fastfile && ruby -c ios/fastlane/Fastfile && ruby -c macos/fastlane/Fastfile
git add android/fastlane/Fastfile ios/fastlane/Fastfile macos/fastlane/Fastfile
git commit -m "feat(release): add beta store lanes alongside the legacy upload lanes"
```

---

### Task 3: `beta.yml` store upload jobs

**Files:**
- Modify: `.github/workflows/beta.yml`

**Interfaces:**
- Consumes: Task 2's lanes; artifacts `ios-ipa`, `macos-pkg`, `android-aab` from `build-all.yml`; existing secrets.

- [ ] **Step 1: Add three jobs** after `publish-beta` (all gated the same way as `publish-beta`: `needs: [precheck, build]`, `if: needs.precheck.outputs.proceed == 'true' && inputs.skip-publish != true`). Model each on `release.yml`'s corresponding upload job with these differences: fixed lane name instead of tag sniffing, the beta changelog env, and the artifact glob matching the beta tag.

`upload-testflight-ios` (macos-15, `timeout-minutes: 45` — external distribution waits for processing):

```yaml
  upload-testflight-ios:
    name: Upload iOS beta to TestFlight
    runs-on: macos-15
    needs: [precheck, build]
    if: needs.precheck.outputs.proceed == 'true' && inputs.skip-publish != true
    timeout-minutes: 45
    steps:
      - name: Checkout repository
        uses: actions/checkout@v7
        with:
          ref: ${{ needs.precheck.outputs.sha }}

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

      - name: Upload to TestFlight (Public Beta)
        working-directory: ios
        env:
          APP_STORE_CONNECT_API_KEY_KEY_ID: ${{ secrets.APP_STORE_CONNECT_API_KEY_KEY_ID }}
          APP_STORE_CONNECT_API_KEY_ISSUER_ID: ${{ secrets.APP_STORE_CONNECT_API_KEY_ISSUER_ID }}
          APP_STORE_CONNECT_API_KEY_KEY_FILEPATH: fastlane/AuthKey.p8
          BETA_CHANGELOG: "Beta ${{ needs.precheck.outputs.tag }} - automated per-merge build."
        run: |
          IPA_PATH=$(ls $GITHUB_WORKSPACE/Submersion-*-iOS.ipa 2>/dev/null | head -1)
          if [ -z "$IPA_PATH" ]; then
            echo "Error: No IPA artifact found"
            exit 1
          fi
          for attempt in 1 2; do
            if bundle exec fastlane upload_testflight_beta ipa:"$IPA_PATH"; then
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

`upload-testflight-macos`: identical shape with `working-directory: macos`, artifact `macos-pkg`. Verified: the MAS package keeps its fixed name `Submersion.pkg` (no tag prefix — release.yml's upload job consumes it by that name, and commit `edcb5173677` widened the beta checksum/upload globs to `Submersion*` to include it), so the lane call is `bundle exec fastlane upload_testflight_beta pkg:"$GITHUB_WORKSPACE/Submersion.pkg"` with an existence check instead of a glob.

`upload-play` (ubuntu-latest, `timeout-minutes: 15`): model on `release.yml`'s `upload-android` job (checkout ref like above, Setup Ruby wd `android`, write `android/fastlane/play-store-key.json` from `GOOGLE_PLAY_SERVICE_ACCOUNT_KEY`, download `android-aab` artifact, retry loop around `bundle exec fastlane upload_beta`, `if: always()` cleanup of the key file).

- [ ] **Step 2: Validate and commit:**

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/beta.yml')); print('YAML OK')"
git add .github/workflows/beta.yml
git commit -m "ci(beta): deliver per-merge betas to TestFlight and Play open testing"
```

---

### Task 4: Fill the in-app enrollment links

**Files:**
- Modify: `lib/features/auto_update/domain/beta_program_links.dart`

- [ ] **Step 1:** Set `kPlayBetaOptInUrl = 'https://play.google.com/apps/testing/app.submersion';` (deterministic). Set `kTestFlightBetaUrl` to the public link from Task 1 if the user has provided it; otherwise leave `''` and record a TODO-free note in the PR body that one constant awaits the link (the tile stays hidden until then — designed behavior).
- [ ] **Step 2:** `dart format . && flutter analyze && flutter test test/features/settings/presentation/pages/settings_page_test.dart`, then:

```bash
git add lib/features/auto_update/domain/beta_program_links.dart
git commit -m "feat(settings): enable the Play beta enrollment link"
```

---

### Task 5: `promote.yml`

**Files:**
- Create: `.github/workflows/promote.yml`

**Interfaces:**
- Consumes: `beta-builds` release assets + `metadata.json` (`sourceSha`, `semver`, `buildNumber`, `eddsaSignature`, `dmgLength`); `scripts/generate_appcast.sh`; `scripts/release/generate_changelog.sh`; `scripts/generate_release_notes_html.sh`; Task 2's `promote_to_production` and new `submit_existing` lanes (Step 2 below adds them).

- [ ] **Step 1: Write the workflow:**

```yaml
name: Promote Beta

# Phase 5 of the release-channels spec: promotes an already-published beta
# to the stable channel everywhere, without rebuilding anything. GitHub gets
# the copied artifacts + a stable appcast entry (signature was computed at
# beta build time); Play promotes the identical AAB from the beta track;
# the App Store gets the existing TestFlight build submitted for review;
# and the marketing-version bump PR opens immediately so the next merge
# starts the next beta train (App Store trains close on release).
on:
  workflow_dispatch:
    inputs:
      build-number:
        description: 'Beta build number to promote (e.g. 4951)'
        required: true
        type: string
      play-rollout:
        description: 'Play production rollout fraction (0.0-1.0)'
        required: false
        type: string
        default: '1.0'
      next-bump:
        description: 'Version bump to open the next beta train'
        required: false
        type: choice
        options: [patch, minor, major]
        default: patch

permissions:
  contents: read

concurrency:
  group: promote
  cancel-in-progress: false

jobs:
  promote:
    name: Publish stable release from beta
    runs-on: ubuntu-latest
    timeout-minutes: 30
    permissions:
      contents: write
      issues: read
    outputs:
      tag: ${{ steps.resolve.outputs.tag }}
      semver: ${{ steps.resolve.outputs.semver }}
      build-number: ${{ steps.resolve.outputs.build-number }}
    steps:
      - name: Checkout repository
        uses: actions/checkout@v7
        with:
          fetch-depth: 0

      - name: Resolve and verify the beta release
        id: resolve
        env:
          GH_TOKEN: ${{ secrets.BETA_BUILDS_TOKEN }}
          BUILD: ${{ inputs.build-number }}
        run: |
          set -euo pipefail
          TAG=$(gh release list --repo submersion-app/beta-builds \
            --json tagName -q ".[].tagName" | grep -E "\.${BUILD}$" | head -1)
          if [ -z "$TAG" ]; then
            echo "::error::No beta release ending in .${BUILD} found (pruned or never built)."
            exit 1
          fi
          mkdir -p promoted && cd promoted
          gh release download "$TAG" --repo submersion-app/beta-builds
          sha256sum -c checksums-sha256.txt
          SEMVER=$(python3 -c "import json;print(json.load(open('metadata.json'))['semver'])")
          SHA=$(python3 -c "import json;print(json.load(open('metadata.json'))['sourceSha'])")
          echo "tag=$TAG" >> "$GITHUB_OUTPUT"
          echo "semver=$SEMVER" >> "$GITHUB_OUTPUT"
          echo "build-number=$BUILD" >> "$GITHUB_OUTPUT"
          echo "sha=$SHA" >> "$GITHUB_OUTPUT"

      - name: Check for beta blockers
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          set -euo pipefail
          OPEN=$(gh issue list --repo ${{ github.repository }} \
            --label beta-blocker --state open --json number -q 'length')
          if [ "$OPEN" != "0" ]; then
            echo "::error::$OPEN open beta-blocker issue(s); resolve them before promoting."
            exit 1
          fi

      - name: Verify the source commit is on main
        run: |
          set -euo pipefail
          git merge-base --is-ancestor "${{ steps.resolve.outputs.sha }}" origin/main || {
            echo "::error::Beta source commit is not on main."; exit 1; }

      - name: Create the stable tag
        run: |
          set -euo pipefail
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git tag "${{ steps.resolve.outputs.tag }}" "${{ steps.resolve.outputs.sha }}"
          git push origin "refs/tags/${{ steps.resolve.outputs.tag }}"

      - name: Generate release notes and stable appcast
        env:
          TAG_NAME: ${{ steps.resolve.outputs.tag }}
        run: |
          set -euo pipefail
          git checkout "${{ steps.resolve.outputs.sha }}"
          ./scripts/release/generate_changelog.sh --notes-only > release-notes.md
          ./scripts/generate_release_notes_html.sh < release-notes.md > release-notes.html
          VERSION="${TAG_NAME#v}"
          export SPARKLE_EDDSA_SIGNATURE=$(python3 -c "import json;print(json.load(open('promoted/metadata.json'))['eddsaSignature'])")
          export SPARKLE_DMG_LENGTH=$(python3 -c "import json;print(json.load(open('promoted/metadata.json'))['dmgLength'])")
          BASE="https://github.com/${{ github.repository }}/releases/download/${TAG_NAME}"
          ./scripts/generate_appcast.sh "$VERSION" "${{ steps.resolve.outputs.build-number }}" \
            "$(date -R)" \
            "${BASE}/Submersion-${TAG_NAME}-macOS.dmg" \
            "${BASE}/Submersion-${TAG_NAME}-Windows-Setup.exe" \
            release-notes.html > appcast.xml
          python3 -c "import xml.dom.minidom;xml.dom.minidom.parse('appcast.xml')"

      - name: Create the stable GitHub release
        env:
          GH_TOKEN: ${{ github.token }}
          TAG_NAME: ${{ steps.resolve.outputs.tag }}
        run: |
          set -euo pipefail
          gh release create "$TAG_NAME" --repo ${{ github.repository }} \
            --title "$TAG_NAME" --notes-file release-notes.md --latest \
            promoted/Submersion-* promoted/checksums-sha256.txt \
            appcast.xml release-notes.html

      - name: Validate the published release
        env:
          GH_TOKEN: ${{ github.token }}
          TAG_NAME: ${{ steps.resolve.outputs.tag }}
        run: |
          set -euo pipefail
          mkdir -p check && cd check
          gh release download "$TAG_NAME" --repo ${{ github.repository }}
          # --ignore-missing: the beta checksums include Submersion.pkg (a
          # store-only artifact deliberately not re-hosted on the stable
          # release, matching the historical stable asset list).
          sha256sum -c --ignore-missing checksums-sha256.txt
          for suffix in macOS.dmg Windows-Setup.exe Linux.tar.gz Android.apk Android.aab iOS.ipa; do
            ls Submersion-*-$suffix >/dev/null || { echo "::error::Missing $suffix"; exit 1; }
          done
          test -s appcast.xml

  promote-play:
    name: Promote Play build to production
    runs-on: ubuntu-latest
    needs: promote
    timeout-minutes: 15
    steps:
      - name: Checkout repository
        uses: actions/checkout@v7

      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.2'
          bundler-cache: true
          working-directory: android

      - name: Setup Google Play service account key
        env:
          GOOGLE_PLAY_SERVICE_ACCOUNT_KEY: ${{ secrets.GOOGLE_PLAY_SERVICE_ACCOUNT_KEY }}
        run: echo "$GOOGLE_PLAY_SERVICE_ACCOUNT_KEY" > android/fastlane/play-store-key.json

      - name: Promote beta track to production
        working-directory: android
        env:
          GOOGLE_PLAY_JSON_KEY_PATH: fastlane/play-store-key.json
        run: |
          bundle exec fastlane promote_to_production \
            version_code:"${{ needs.promote.outputs.build-number }}" \
            rollout:"${{ inputs.play-rollout }}"

      - name: Cleanup sensitive files
        if: always()
        run: rm -f android/fastlane/play-store-key.json

  submit-appstore:
    name: Submit existing builds for App Review
    runs-on: macos-15
    needs: promote
    timeout-minutes: 30
    steps:
      - name: Checkout repository
        uses: actions/checkout@v7

      - name: Setup Ruby (iOS)
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.2'
          bundler-cache: true
          working-directory: ios

      - name: Setup App Store Connect API Key
        env:
          APP_STORE_CONNECT_API_KEY_KEY: ${{ secrets.APP_STORE_CONNECT_API_KEY_KEY }}
        run: |
          mkdir -p ios/fastlane macos/fastlane
          echo "$APP_STORE_CONNECT_API_KEY_KEY" | base64 --decode > ios/fastlane/AuthKey.p8
          echo "$APP_STORE_CONNECT_API_KEY_KEY" | base64 --decode > macos/fastlane/AuthKey.p8

      - name: Submit iOS build
        working-directory: ios
        env:
          APP_STORE_CONNECT_API_KEY_KEY_ID: ${{ secrets.APP_STORE_CONNECT_API_KEY_KEY_ID }}
          APP_STORE_CONNECT_API_KEY_ISSUER_ID: ${{ secrets.APP_STORE_CONNECT_API_KEY_ISSUER_ID }}
          APP_STORE_CONNECT_API_KEY_KEY_FILEPATH: fastlane/AuthKey.p8
        run: |
          bundle exec fastlane submit_existing \
            app_version:"${{ needs.promote.outputs.semver }}" \
            build_number:"${{ needs.promote.outputs.build-number }}"

      - name: Setup Ruby (macOS)
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.2'
          bundler-cache: true
          working-directory: macos

      - name: Submit macOS build
        working-directory: macos
        env:
          APP_STORE_CONNECT_API_KEY_KEY_ID: ${{ secrets.APP_STORE_CONNECT_API_KEY_KEY_ID }}
          APP_STORE_CONNECT_API_KEY_ISSUER_ID: ${{ secrets.APP_STORE_CONNECT_API_KEY_ISSUER_ID }}
          APP_STORE_CONNECT_API_KEY_KEY_FILEPATH: fastlane/AuthKey.p8
        run: |
          bundle exec fastlane submit_existing \
            app_version:"${{ needs.promote.outputs.semver }}" \
            build_number:"${{ needs.promote.outputs.build-number }}"

      - name: Cleanup sensitive files
        if: always()
        run: rm -f ios/fastlane/AuthKey.p8 macos/fastlane/AuthKey.p8

  bump-pr:
    name: Open the version bump PR
    runs-on: ubuntu-latest
    needs: promote
    timeout-minutes: 10
    permissions:
      contents: write
      pull-requests: write
    steps:
      - name: Checkout main
        uses: actions/checkout@v7
        with:
          ref: main

      - name: Bump and open PR
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          set -euo pipefail
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          ./scripts/release/bump_version.sh --${{ inputs.next-bump }}
          NEWVER=$(grep '^version:' pubspec.yaml | sed 's/version: *//')
          BRANCH="chore/bump-${NEWVER//+/-}"
          git checkout -b "$BRANCH"
          git add pubspec.yaml
          git commit -m "chore: bump version to ${NEWVER}

Opens the next beta train after promoting ${{ needs.promote.outputs.tag }};
the App Store closes a version train on release, so betas cannot continue
on the promoted marketing version."
          git push origin "$BRANCH"
          gh pr create --base main --head "$BRANCH" \
            --title "chore: bump version to ${NEWVER}" \
            --body "Opens the next beta train after promoting ${{ needs.promote.outputs.tag }}. Merge promptly: the beta pipeline's train-closed guard fails every merge until this lands. Note: CI does not auto-run on bot-pushed branches; close/reopen the PR or push an empty commit to trigger it."
          gh pr merge --auto --merge "$BRANCH" || \
            echo "::warning::Auto-merge unavailable; merge the bump PR manually."

  notify-failures:
    name: Open issue on promotion failure
    runs-on: ubuntu-latest
    needs: [promote, promote-play, submit-appstore, bump-pr]
    if: always() && contains(needs.*.result, 'failure')
    permissions:
      issues: write
    steps:
      - name: Open tracking issue
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          gh issue create --repo ${{ github.repository }} \
            --title "Promotion of build ${{ inputs.build-number }} partially failed" \
            --label ci \
            --body "One or more promotion jobs failed: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}. The GitHub release, Play promotion, App Store submission, and bump PR are independent - check which succeeded before re-running."
```

- [ ] **Step 2: `submit_existing` fastlane lanes.** In `ios/fastlane/Fastfile` after `upload_testflight_beta`:

```ruby
  desc "Submit an already-uploaded build for App Review (no upload)"
  lane :submit_existing do |options|
    api_key = load_api_key
    app_version = options[:app_version] || UI.user_error!("app_version is required")
    build_number = options[:build_number] || UI.user_error!("build_number is required")

    UI.message("Submitting #{app_version} (#{build_number}) for App Review...")
    upload_to_app_store(
      api_key: api_key,
      app_version: app_version,
      build_number: build_number.to_s,
      skip_binary_upload: true,
      skip_screenshots: true,
      skip_metadata: true,
      submit_for_review: true,
      automatic_release: false,
      precheck_include_in_app_purchases: false,
      submission_information: { add_id_info_uses_idfa: false },
    )
    UI.success("Submitted for review; release manually in App Store Connect on approval.")
  end
```

Same lane in `macos/fastlane/Fastfile` (identical body — deliver selects the platform from the Appfile/app record context).

- [ ] **Step 3: Validate and commit:**

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/promote.yml')); print('YAML OK')"
ruby -c ios/fastlane/Fastfile && ruby -c macos/fastlane/Fastfile
git add .github/workflows/promote.yml ios/fastlane/Fastfile macos/fastlane/Fastfile
git commit -m "ci: add the beta-to-stable promotion workflow"
```

---

### Task 6: `scripts/release/promote.sh`

**Files:**
- Create: `scripts/release/promote.sh` (`chmod +x`)

- [ ] **Step 1:**

```bash
#!/usr/bin/env bash
# Promote a published beta build to the stable channel everywhere.
#
# Usage: ./scripts/release/promote.sh <build-number> [--rollout FRACTION] [--bump patch|minor|major]
#
# Thin wrapper over the Promote Beta workflow (.github/workflows/promote.yml):
# verifies the beta exists and shows what will be promoted before dispatching.

set -euo pipefail

BUILD="${1:?Usage: promote.sh <build-number> [--rollout FRACTION] [--bump patch|minor|major]}"
shift
ROLLOUT="1.0"
BUMP="patch"
while [ $# -gt 0 ]; do
  case "$1" in
    --rollout) ROLLOUT="$2"; shift 2 ;;
    --bump) BUMP="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

TAG=$(gh release list --repo submersion-app/beta-builds --json tagName \
  -q ".[].tagName" | grep -E "\.${BUILD}$" | head -1)
if [ -z "$TAG" ]; then
  echo "Error: no beta release ending in .${BUILD} found in beta-builds." >&2
  exit 1
fi

BLOCKERS=$(gh issue list --repo submersion-app/submersion \
  --label beta-blocker --state open --json number -q 'length')
if [ "$BLOCKERS" != "0" ]; then
  echo "Error: $BLOCKERS open beta-blocker issue(s). Resolve before promoting." >&2
  exit 1
fi

echo "About to promote $TAG to stable (Play rollout $ROLLOUT, next bump: $BUMP)."
read -r -p "Continue? [y/N] " answer
[ "$answer" = "y" ] || { echo "Aborted."; exit 1; }

gh workflow run promote.yml \
  -f build-number="$BUILD" -f play-rollout="$ROLLOUT" -f next-bump="$BUMP"
echo "Dispatched. Watch with:"
echo "  gh run watch \$(gh run list --workflow=promote.yml --limit 1 --json databaseId -q '.[0].databaseId')"
```

- [ ] **Step 2:** `bash -n scripts/release/promote.sh && chmod +x scripts/release/promote.sh`, commit:

```bash
git add scripts/release/promote.sh
git commit -m "feat(release): add the promote.sh wrapper"
```

---

### Task 7: README beta-channel documentation

**Files:**
- Modify: `README.md` (Download section)

- [ ] **Step 1:** After the existing Download platform list, add a short "Beta channel" paragraph: what it is (per-merge builds, ahead of stable, may migrate the database early, no downgrade), how to join on desktop (Settings > About > Update channel > Beta), the `beta-builds` releases page link, the Play opt-in URL, and the TestFlight public link (or "coming soon" if Task 1's link is still pending). Match the README's existing tone and formatting (plain markdown, no HTML style attributes).
- [ ] **Step 2:** Commit:

```bash
git add README.md
git commit -m "docs: describe the beta channel and how to join it"
```

---

### Task 8: Verification

- [ ] **Step 1:** `dart format . && flutter analyze && python3 -c "import yaml; [yaml.safe_load(open(f)) for f in ['.github/workflows/beta.yml','.github/workflows/promote.yml']]; print('YAML OK')" && ruby -c android/fastlane/Fastfile && ruby -c ios/fastlane/Fastfile && ruby -c macos/fastlane/Fastfile && flutter test test/features/settings/ test/features/auto_update/`
- [ ] **Step 2:** Full suite once: `flutter test` (only one Dart constant changed, but the stack rule stands).
- [ ] **Step 3:** Document the two live acceptance events in the PR body (they cannot run pre-merge):
  - Phase 4: the first merge to `main` after the stack lands must be watched — TestFlight processing + Public Beta assignment, Play beta-track release.
  - Phase 5: the first real promotion (`scripts/release/promote.sh <build>`) is a deliberate release event; run it for the next stable and watch all five jobs.

## Risks

- `distribute_external` waits for Apple build processing (minutes, occasionally flaky) — the 2-attempt retry and 45-minute timeout absorb normal variance; a processing outage fails the job visibly and the next merge retries.
- First build of each version train to the external group triggers Beta App Review; testers see that train's builds only after approval (internal testers are unaffected).
- `submit_for_review: true` via the API is the most brittle store step; if it fails persistently, the fallback is manual submission in App Store Connect (select the build, Submit) — everything else in the promotion is unaffected.
- The bump PR cannot trigger CI (bot-pushed branches don't fire workflows); until it merges, every beta merge fails the train-closed guard loudly. The PR body says exactly what to do.
- Play `rollout` fractions only apply to production promotion; open-testing releases are always full.
