# Release Channels Phases 1-2: Build Extraction & Beta Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract `release.yml`'s five platform build jobs into a reusable `build-all.yml` (Phase 1), then add the per-merge beta pipeline publishing signed desktop/GitHub artifacts to a dedicated `beta-builds` repo with a beta appcast (Phase 2). Store beta lanes (TestFlight/Play) are Phase 4 — out of scope here.

**Architecture:** `build-all.yml` becomes the repo's first `workflow_call` workflow: the five build jobs move verbatim with two parameterizations (tag string, optional build number injected by rewriting the workspace `pubspec.yaml` before building — one step per job, so Flutter, both Fastfiles, the Windows installer's pubspec scrape, and checksums all agree with zero command changes). `release.yml` calls it; behavior unchanged. `beta.yml` triggers on CI/CD success on `main`, computes `v<semver>.<commit-count>`, calls `build-all.yml`, and publishes to `submersion-app/beta-builds`.

**Tech Stack:** GitHub Actions (`workflow_call`, `workflow_run`), bash, `gh` CLI, existing fastlane lanes untouched.

## Global Constraints

- Follow existing workflow conventions: `actions/checkout@v7`, Flutter version read from `.github/flutter-version.txt`, `permissions: contents: read` default, step names in sentence case.
- No emojis in code or docs. No secrets in files — the one new secret (`BETA_BUILDS_TOKEN`) is set via `gh secret set`.
- YAML must parse: validate every edited workflow with `python3 -c "import yaml,sys; yaml.safe_load(open(sys.argv[1]))" <file>` (actionlint is not installed).
- `beta.yml`'s `workflow_run` trigger only fires once the file exists on the default branch; pre-merge testing is via its `workflow_dispatch` trigger on this branch.
- Beta binaries are configuration-identical to stable ones (`UPDATE_CHANNEL` stays exactly as release.yml sets it today); beta-ness lives only in where artifacts are published.
- Stable tag format `vX.Y.Z.N` (4-segment) is reused verbatim for beta releases in the beta-builds repo, so promoted artifacts never need renaming.
- Commit after each task. Work happens on branch `release-channels-phase1-2` (stacked on `release-channels-phase0`, PR #762).

---

### Task 1: Extract `build-all.yml` and make `release.yml` call it

**Files:**
- Create: `.github/workflows/build-all.yml`
- Modify: `.github/workflows/release.yml`

**Interfaces:**
- Produces: reusable workflow `./.github/workflows/build-all.yml` with inputs `version-tag` (required string), `build-number` (optional string, default `''`), outputs `eddsa-signature` and `dmg-length`, artifacts `macos-dmg`, `macos-pkg`, `windows-setup`, `linux-tar`, `android-apk`, `android-aab`, `ios-ipa`. Task 5's `beta.yml` and the refactored `release.yml` both depend on this exact interface.

- [ ] **Step 1: Create `build-all.yml` with this header, then move the five build jobs into it**

```yaml
name: Build All Platforms

# Reusable build workflow: produces the full signed artifact set for every
# platform. Called by release.yml (tag-driven stable/prerelease builds) and
# beta.yml (per-merge beta builds). The optional build-number input rewrites
# the workspace pubspec.yaml before building so Flutter, the Fastfiles, the
# Windows installer, and the appcast all see one consistent build number.
on:
  workflow_call:
    inputs:
      version-tag:
        description: 'Tag-shaped version string used in artifact filenames (e.g. v1.8.0.5601)'
        required: true
        type: string
      build-number:
        description: 'Overrides the pubspec build number when non-empty'
        required: false
        type: string
        default: ''
      ref:
        description: 'Git ref (SHA or branch) to check out; defaults to the workflow ref'
        required: false
        type: string
        default: ''
    outputs:
      eddsa-signature:
        description: 'Sparkle EdDSA signature of the macOS DMG'
        value: ${{ jobs.build-macos.outputs.eddsa-signature }}
      dmg-length:
        description: 'Byte length of the macOS DMG'
        value: ${{ jobs.build-macos.outputs.dmg-length }}
  workflow_dispatch:
    inputs:
      version-tag:
        description: 'Tag-shaped version string (e.g. v0.0.0-smoke.1)'
        required: true
        type: string
      build-number:
        description: 'Overrides the pubspec build number when non-empty'
        required: false
        type: string
        default: ''

permissions:
  contents: read

env:
  FLUTTER_VERSION_FILE: '.github/flutter-version.txt'

jobs:
```

Then MOVE (cut from `release.yml`, paste here) the five jobs `build-macos` (release.yml:34-314), `build-windows` (:319-384), `build-linux` (:389-455), `build-android` (:460-578), `build-ios` (:583-720), applying exactly these transformations to each:

1. Every `${{ github.ref_name }}` becomes `${{ inputs.version-tag }}`. There are 9 sites, all of the form `TAG_NAME: ${{ github.ref_name }}` in step `env:` blocks (release.yml lines 158, 183, 207, 372, 445, 553, 705 pre-move, plus the DMG create/notarize pair — verify with `grep -n 'github.ref_name' ` on the moved text until zero remain).
2. Every `- uses: actions/checkout@v7` step in these jobs gains a `ref` line so `beta.yml` can pin the CI-validated SHA:

```yaml
      - uses: actions/checkout@v7
        with:
          submodules: recursive
          ref: ${{ inputs.ref }}
```

(`ref: ''` means default behavior, so release.yml is unaffected. Preserve each job's existing `with:` keys — build-macos uses `submodules: recursive`; check the others and keep whatever they have.)
3. Immediately after each job's "Install dependencies" step (the `flutter pub get` step; in build-ios and the MAS section the Ruby/pod installs come later — the pubspec rewrite only needs to precede the first `flutter build`), insert this step (use `shell: bash` — required on windows-latest, harmless elsewhere):

```yaml
      - name: Override build number
        if: inputs.build-number != ''
        shell: bash
        env:
          BUILD_NUMBER: ${{ inputs.build-number }}
        run: |
          perl -pi -e 's/^(version:\s*[0-9]+\.[0-9]+\.[0-9]+)\+[0-9]+/${1}+$ENV{BUILD_NUMBER}/' pubspec.yaml
          grep '^version:' pubspec.yaml
```

One insertion per job (5 total). `perl -pi` is portable across the macOS (BSD) and Linux (GNU) runners where `sed -i` is not.
4. Keep the `outputs:` block on `build-macos` exactly as-is (the workflow-level `outputs:` above maps them out).

- [ ] **Step 2: Replace the five jobs in `release.yml` with one caller job**

Delete the five build jobs from `release.yml` and insert:

```yaml
  build:
    name: Build all platforms
    uses: ./.github/workflows/build-all.yml
    with:
      version-tag: ${{ github.ref_name }}
    secrets: inherit
```

Then update every downstream reference:
- `needs: [build-macos, build-windows, build-linux, build-android, build-ios]` → `needs: build` (jobs: `upload-macos`, `upload-ios`, `upload-android`, `generate-appcast`; `create-release` keeps `generate-appcast` in its list: `needs: [build, generate-appcast]`).
- `${{ needs.build-macos.outputs.eddsa-signature }}` → `${{ needs.build.outputs.eddsa-signature }}` and same for `dmg-length` (generate-appcast job, release.yml:948-949 pre-edit).
- Artifact download steps are unchanged — artifacts from a called workflow land in the same run.

- [ ] **Step 3: Static validation**

Run:
```bash
python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/build-all.yml')); yaml.safe_load(open('.github/workflows/release.yml')); print('YAML OK')"
grep -c "github.ref_name" .github/workflows/build-all.yml   # expect 0
grep -n "needs.build-macos\|needs: \[build-macos" .github/workflows/release.yml   # expect no matches
grep -c "Override build number" .github/workflows/build-all.yml   # expect 5
```

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/build-all.yml .github/workflows/release.yml
git commit -m "ci: extract the five platform builds into a reusable workflow"
```

---

### Task 2: Live smoke test of `build-all.yml`

The extraction can only be truly proven by running it — `workflow_dispatch` on this branch runs the real signed builds with real secrets, without cutting a release.

**Files:** none (verification only)

- [ ] **Step 1: Push the branch and dispatch**

```bash
git push --no-verify -u origin release-channels-phase1-2
env -u GITHUB_TOKEN gh workflow run build-all.yml --ref release-channels-phase1-2 \
  -f version-tag=v0.0.0-smoke.1 -f build-number=999999
```

(`--no-verify`: the pre-push hook analyzes the main checkout, a known wrong-tree trap; Dart is untouched by this task anyway. Build number 999999 proves the pubspec override without colliding with anything — nothing uploads to stores in this workflow.)

- [ ] **Step 2: Watch the run to completion**

```bash
env -u GITHUB_TOKEN gh run watch $(env -u GITHUB_TOKEN gh run list --workflow=build-all.yml --limit 1 --json databaseId -q '.[0].databaseId')
```

Expected: all five jobs green (~45 min); artifacts named `Submersion-v0.0.0-smoke.1-*`; the "Override build number" step log shows `version: X.Y.Z+999999`. If a job fails, fix the extraction before proceeding — do NOT continue to Task 5 on a broken build workflow.

---

### Task 3: Bootstrap the `beta-builds` repo and token

**Files:** none in this repo (remote setup + one secret)

- [ ] **Step 1: Create the repo with a README**

```bash
cd "$(mktemp -d)" && git init -b main beta-builds-seed && cd beta-builds-seed
cat > README.md <<'EOF'
# Submersion Beta Builds

Automated per-merge beta builds of [Submersion](https://github.com/submersion-app/submersion).

Every green merge to Submersion's `main` branch publishes a release here.
These builds are the beta channel: they carry the newest fixes and features
and may migrate your dive log's database ahead of the stable release.
Downgrading is not supported - see the release-channels documentation in the
main repository before installing.

- Latest beta: the newest release on this repo
- Stable channel: https://github.com/submersion-app/submersion/releases
- Report issues: https://github.com/submersion-app/submersion/issues (mention
  the beta build number shown in the release title)

Releases are pruned to the newest 15. Each release's `metadata.json` records
the source commit in the main repository.
EOF
git add README.md && git commit -m "docs: explain the beta channel"
env -u GITHUB_TOKEN gh repo create submersion-app/beta-builds --public \
  --description "Per-merge beta builds of Submersion" --source . --push
env -u GITHUB_TOKEN gh repo edit submersion-app/beta-builds \
  --enable-issues=false --enable-wiki=false --enable-projects=false
```

- [ ] **Step 2: USER ACTION REQUIRED — create the fine-grained PAT**

Stop and ask the user to create a fine-grained personal access token at
https://github.com/settings/personal-access-tokens/new with: Resource owner
`submersion-app`, Repository access "Only select repositories" →
`submersion-app/beta-builds`, Repository permissions → Contents: Read and
write (nothing else). Then set it as a secret on the MAIN repo:

```bash
env -u GITHUB_TOKEN gh secret set BETA_BUILDS_TOKEN --repo submersion-app/submersion
```

(paste the token when prompted). Do not proceed to Task 5's smoke test until this exists.

---

### Task 4: `generate_appcast_beta.sh` + script test

The beta appcast is a superset feed: the new beta `<item>` first, then every `<item>` from the current stable `appcast.xml`, so a beta user always has a forward path onto the next stable.

**Files:**
- Create: `scripts/generate_appcast_beta.sh`
- Create: `scripts/generate_appcast_beta_test.sh`
- Modify: `.github/workflows/ci.yaml` (script-tests job, after the coverage step)

**Interfaces:**
- Consumes: `scripts/generate_appcast.sh` (unchanged) — the beta script shares its item shape and env contract (`SPARKLE_EDDSA_SIGNATURE`, `SPARKLE_DMG_LENGTH`).
- Produces: `generate_appcast_beta.sh <version> <build_number> <date> <macos_dmg_url> <windows_url> <release_notes_html_file> [stable_appcast_path]` → appcast XML on stdout. Task 5 invokes it with these exact positionals.

- [ ] **Step 1: Write the script**

```bash
#!/usr/bin/env bash
# Generates appcast-beta.xml for the Sparkle/WinSparkle beta channel.
#
# Usage: ./scripts/generate_appcast_beta.sh <version> <build_number> <date> \
#          <macos_dmg_url> <windows_url> <release_notes_html_file> [stable_appcast_path]
#
# Same arguments and env contract as generate_appcast.sh
# (SPARKLE_EDDSA_SIGNATURE, SPARKLE_DMG_LENGTH), plus an optional path to the
# CURRENT stable appcast.xml. The output is a superset feed: the beta item
# first, then every <item> from the stable appcast, so a device switched
# back to the stable channel still walks forward onto the next stable.

set -euo pipefail

STABLE_APPCAST="${7:-}"

# Reuse the canonical generator for the beta item and the feed skeleton.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BETA_FEED=$("$SCRIPT_DIR/generate_appcast.sh" "$1" "$2" "$3" "$4" "$5" "$6")

if [ -z "$STABLE_APPCAST" ] || [ ! -s "$STABLE_APPCAST" ]; then
  printf '%s\n' "$BETA_FEED"
  exit 0
fi

# Splice the stable feed's <item> blocks in front of the closing </channel>.
STABLE_ITEMS=$(sed -n '/<item>/,/<\/item>/p' "$STABLE_APPCAST")
printf '%s\n' "$BETA_FEED" | while IFS= read -r line; do
  if [[ "$line" == *"</channel>"* ]]; then
    printf '%s\n' "$STABLE_ITEMS"
  fi
  printf '%s\n' "$line"
done
```

Run `chmod +x scripts/generate_appcast_beta.sh`.

- [ ] **Step 2: Write the failing test**

`scripts/generate_appcast_beta_test.sh` (`chmod +x`):

```bash
#!/usr/bin/env bash
# Tests for generate_appcast_beta.sh: superset ordering, standalone fallback,
# and signature passthrough.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

export SPARKLE_EDDSA_SIGNATURE="sig-beta"
export SPARKLE_DMG_LENGTH="1234"
echo "<p>beta notes</p>" > "$TMP/notes.html"

fail() { echo "FAIL: $1"; exit 1; }

# Case 1: no stable appcast -> valid single-item feed.
OUT=$("$SCRIPT_DIR/generate_appcast_beta.sh" 1.8.0.5601 5601 "Mon, 28 Jul 2026 00:00:00 +0000" \
  https://example.com/beta.dmg https://example.com/beta.exe "$TMP/notes.html")
echo "$OUT" | grep -q "sparkle:version=\"5601\"" || fail "beta item missing sparkle:version"
[ "$(echo "$OUT" | grep -c '<item>')" -eq 1 ] || fail "expected exactly 1 item without stable feed"

# Case 2: with a stable appcast -> beta item first, stable item present, valid XML.
SPARKLE_EDDSA_SIGNATURE="sig-stable" SPARKLE_DMG_LENGTH="999" \
  "$SCRIPT_DIR/generate_appcast.sh" 1.7.0.117 117 "Sun, 27 Jul 2026 00:00:00 +0000" \
  https://example.com/stable.dmg https://example.com/stable.exe "$TMP/notes.html" > "$TMP/stable.xml"
OUT=$("$SCRIPT_DIR/generate_appcast_beta.sh" 1.8.0.5601 5601 "Mon, 28 Jul 2026 00:00:00 +0000" \
  https://example.com/beta.dmg https://example.com/beta.exe "$TMP/notes.html" "$TMP/stable.xml")
[ "$(echo "$OUT" | grep -c '<item>')" -eq 2 ] || fail "expected 2 items in superset feed"
BETA_LINE=$(echo "$OUT" | grep -n "5601" | head -1 | cut -d: -f1)
STABLE_LINE=$(echo "$OUT" | grep -n "sparkle:version=\"117\"" | head -1 | cut -d: -f1)
[ "$BETA_LINE" -lt "$STABLE_LINE" ] || fail "beta item must precede stable item"
echo "$OUT" | grep -q "sig-beta" || fail "beta signature missing"
echo "$OUT" | grep -q "sig-stable" || fail "stable signature not preserved"
echo "$OUT" | python3 -c "import sys,xml.dom.minidom; xml.dom.minidom.parseString(sys.stdin.read())" \
  || fail "output is not well-formed XML"

echo "PASS: generate_appcast_beta_test"
```

- [ ] **Step 3: Run the test**

Run: `./scripts/generate_appcast_beta_test.sh`
Expected: `PASS: generate_appcast_beta_test`. (Write script and test together, then run — shell scripts get no meaningful red phase from a missing file.)

- [ ] **Step 4: Wire into CI script-tests**

In `.github/workflows/ci.yaml`, in the `script-tests` job, add after the "Run Python guard tests with coverage" step:

```yaml
      - name: Run appcast beta feed test
        run: ./scripts/generate_appcast_beta_test.sh
```

- [ ] **Step 5: Validate and commit**

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yaml')); print('YAML OK')"
git add scripts/generate_appcast_beta.sh scripts/generate_appcast_beta_test.sh .github/workflows/ci.yaml
git commit -m "feat(release): add beta appcast generator with stable superset"
```

---

### Task 5: `beta.yml` — the per-merge beta pipeline

**Files:**
- Create: `.github/workflows/beta.yml`

**Interfaces:**
- Consumes: `build-all.yml` (Task 1 interface), `generate_appcast_beta.sh` (Task 4), `BETA_BUILDS_TOKEN` (Task 3), `scripts/release/generate_changelog.sh --notes-only` (existing).
- Produces: releases `vX.Y.Z.N` in `submersion-app/beta-builds`, each with all 7 artifacts, `checksums-sha256.txt`, `metadata.json` (`sourceSha`, `semver`, `buildNumber`, `eddsaSignature`, `dmgLength`), and `appcast-beta.xml`. The permanent beta feed URL is `https://github.com/submersion-app/beta-builds/releases/latest/download/appcast-beta.xml` (Plan C consumes this; promotion in Plan D consumes `metadata.json`).

- [ ] **Step 1: Write the workflow**

```yaml
name: Beta

# Per-merge beta pipeline (release-channels spec, Phase 2). Runs after CI/CD
# succeeds on main, builds the exact validated SHA via build-all.yml, and
# publishes the artifact set as a release in submersion-app/beta-builds.
# Store lanes (TestFlight / Play beta track) are Phase 4 and not wired here.
on:
  workflow_run:
    workflows: ["CI/CD"]
    types: [completed]
    branches: [main]
  workflow_dispatch:
    inputs:
      skip-publish:
        description: 'Build only; do not publish to beta-builds'
        required: false
        type: boolean
        default: false

permissions:
  contents: read

concurrency:
  group: beta-pipeline
  cancel-in-progress: true

jobs:
  precheck:
    name: Compute version and gate
    runs-on: ubuntu-latest
    if: github.event_name == 'workflow_dispatch' || github.event.workflow_run.conclusion == 'success'
    outputs:
      proceed: ${{ steps.gate.outputs.proceed }}
      tag: ${{ steps.version.outputs.tag }}
      build-number: ${{ steps.version.outputs.build-number }}
      sha: ${{ steps.version.outputs.sha }}
    steps:
      - uses: actions/checkout@v7
        with:
          ref: ${{ github.event.workflow_run.head_sha || github.sha }}
          fetch-depth: 0

      - name: Compute beta version
        id: version
        run: |
          set -euo pipefail
          SEMVER=$(grep '^version:' pubspec.yaml | sed 's/version: *//; s/+.*//')
          BUILD=$(git rev-list --count HEAD)
          # Train-closed guard: a stable tag for this marketing version means
          # it has shipped; the bump PR from promotion has not landed yet.
          if [ -n "$(git tag -l "v${SEMVER}.[0-9]*")" ]; then
            echo "::error::Marketing version ${SEMVER} already has a stable release." \
              " Land the version bump (scripts/release/bump_version.sh) before the next beta."
            exit 1
          fi
          echo "tag=v${SEMVER}.${BUILD}" >> "$GITHUB_OUTPUT"
          echo "build-number=${BUILD}" >> "$GITHUB_OUTPUT"
          echo "sha=$(git rev-parse HEAD)" >> "$GITHUB_OUTPUT"

      - name: Skip if nothing shippable changed since the last beta
        id: gate
        env:
          GH_TOKEN: ${{ secrets.BETA_BUILDS_TOKEN }}
        run: |
          set -euo pipefail
          PREV_SHA=""
          if gh release download --repo submersion-app/beta-builds \
               --pattern metadata.json --dir /tmp/prev-beta 2>/dev/null; then
            PREV_SHA=$(python3 -c "import json;print(json.load(open('/tmp/prev-beta/metadata.json'))['sourceSha'])")
          fi
          if [ -z "$PREV_SHA" ] || ! git rev-parse --verify --quiet "${PREV_SHA}^{commit}" >/dev/null; then
            echo "No previous beta baseline; proceeding."
            echo "proceed=true" >> "$GITHUB_OUTPUT"
            exit 0
          fi
          if [ "$PREV_SHA" = "$(git rev-parse HEAD)" ]; then
            echo "HEAD already published as a beta; skipping."
            echo "proceed=false" >> "$GITHUB_OUTPUT"
            exit 0
          fi
          # Same inert-path filter as ci.yaml's changes job: skip when every
          # file changed since the last beta is docs/CI/image-only.
          code=false
          while IFS= read -r f; do
            [ -n "$f" ] || continue
            case "$f" in
              .github/flutter-version.txt) code=true ;;
              .github/*) ;;
              *.md|docs/*|LICENSE*|.gitignore|.gitattributes|.editorconfig|codecov.yml|hooks/*) ;;
              *.png|*.jpg|*.jpeg|*.gif|*.svg|*.webp|*.ico) ;;
              *) code=true ;;
            esac
          done <<< "$(git diff --name-only "${PREV_SHA}..HEAD")"
          echo "proceed=$code" >> "$GITHUB_OUTPUT"

  build:
    name: Build
    needs: precheck
    if: needs.precheck.outputs.proceed == 'true'
    uses: ./.github/workflows/build-all.yml
    with:
      version-tag: ${{ needs.precheck.outputs.tag }}
      build-number: ${{ needs.precheck.outputs.build-number }}
      ref: ${{ needs.precheck.outputs.sha }}
    secrets: inherit

  publish-beta:
    name: Publish to beta-builds
    needs: [precheck, build]
    if: needs.precheck.outputs.proceed == 'true' && inputs.skip-publish != true
    runs-on: ubuntu-latest
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@v7
        with:
          ref: ${{ needs.precheck.outputs.sha }}
          fetch-depth: 0

      - name: Download all artifacts
        uses: actions/download-artifact@v8
        with:
          path: artifacts
          merge-multiple: true

      - name: Generate release notes
        run: |
          set -euo pipefail
          ./scripts/release/generate_changelog.sh --notes-only > release-notes.md
          ./scripts/generate_release_notes_html.sh < release-notes.md > release-notes.html

      - name: Generate checksums and metadata
        env:
          TAG_NAME: ${{ needs.precheck.outputs.tag }}
          BUILD_NUMBER: ${{ needs.precheck.outputs.build-number }}
          SOURCE_SHA: ${{ needs.precheck.outputs.sha }}
          EDDSA_SIGNATURE: ${{ needs.build.outputs.eddsa-signature }}
          DMG_LENGTH: ${{ needs.build.outputs.dmg-length }}
        run: |
          set -euo pipefail
          cd artifacts
          sha256sum Submersion-* > ../checksums-sha256.txt
          cd ..
          SEMVER="${TAG_NAME#v}"; SEMVER="${SEMVER%.${BUILD_NUMBER}}"
          python3 - <<PYEOF
          import json, os
          json.dump({
              'sourceSha': os.environ['SOURCE_SHA'],
              'semver': "${SEMVER}",
              'buildNumber': int(os.environ['BUILD_NUMBER']),
              'eddsaSignature': os.environ['EDDSA_SIGNATURE'],
              'dmgLength': int(os.environ['DMG_LENGTH']),
          }, open('metadata.json', 'w'), indent=2)
          PYEOF

      - name: Generate beta appcast
        env:
          TAG_NAME: ${{ needs.precheck.outputs.tag }}
          BUILD_NUMBER: ${{ needs.precheck.outputs.build-number }}
          SPARKLE_EDDSA_SIGNATURE: ${{ needs.build.outputs.eddsa-signature }}
          SPARKLE_DMG_LENGTH: ${{ needs.build.outputs.dmg-length }}
        run: |
          set -euo pipefail
          VERSION="${TAG_NAME#v}"
          DATE=$(date -R)
          BASE="https://github.com/submersion-app/beta-builds/releases/download/${TAG_NAME}"
          curl -fsSL -o stable-appcast.xml \
            "https://github.com/${{ github.repository }}/releases/latest/download/appcast.xml" \
            || : > stable-appcast.xml
          ./scripts/generate_appcast_beta.sh "$VERSION" "$BUILD_NUMBER" "$DATE" \
            "${BASE}/Submersion-${TAG_NAME}-macOS.dmg" \
            "${BASE}/Submersion-${TAG_NAME}-Windows-Setup.exe" \
            release-notes.html stable-appcast.xml > appcast-beta.xml

      - name: Create beta release
        env:
          GH_TOKEN: ${{ secrets.BETA_BUILDS_TOKEN }}
          TAG_NAME: ${{ needs.precheck.outputs.tag }}
          SOURCE_SHA: ${{ needs.precheck.outputs.sha }}
        run: |
          set -euo pipefail
          gh release create "$TAG_NAME" --repo submersion-app/beta-builds \
            --title "Beta $TAG_NAME" \
            --notes-file release-notes.md \
            artifacts/Submersion-* checksums-sha256.txt metadata.json appcast-beta.xml
          echo "Published beta $TAG_NAME from $SOURCE_SHA"

      - name: Prune old betas
        env:
          GH_TOKEN: ${{ secrets.BETA_BUILDS_TOKEN }}
        run: |
          set -euo pipefail
          gh release list --repo submersion-app/beta-builds \
            --json tagName --limit 100 -q '.[15:][].tagName' | while read -r tag; do
            echo "Pruning $tag"
            gh release delete "$tag" --repo submersion-app/beta-builds --yes --cleanup-tag
          done
```

- [ ] **Step 2: Static validation**

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/beta.yml')); print('YAML OK')"
```

The notes pipeline mirrors release.yml's generate-appcast job exactly (`generate_changelog.sh --notes-only` piped through `scripts/generate_release_notes_html.sh`, verified present); `fetch-depth: 0` supplies the tag history the changelog script diffs against, same as release.yml.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/beta.yml
git commit -m "ci: add per-merge beta pipeline publishing to beta-builds"
```

- [ ] **Step 4: Live smoke test (requires Task 3's token)**

```bash
git push --no-verify
env -u GITHUB_TOKEN gh workflow run beta.yml --ref release-channels-phase1-2
env -u GITHUB_TOKEN gh run watch $(env -u GITHUB_TOKEN gh run list --workflow=beta.yml --limit 1 --json databaseId -q '.[0].databaseId')
```

Expected: precheck computes a tag like `v1.8.0.NNNN` (commit count), build runs all five platforms, publish creates a release in `beta-builds` with 7+ assets, prune is a no-op. Then verify the feed URL resolves:

```bash
curl -fsSL https://github.com/submersion-app/beta-builds/releases/latest/download/appcast-beta.xml | head -20
```

If the smoke beta pollutes the repo, delete it: `env -u GITHUB_TOKEN gh release delete <tag> --repo submersion-app/beta-builds --yes --cleanup-tag`.

---

### Task 6: Document the new secret

**Files:**
- Modify: `docs/developer/release-secrets-setup.md`

- [ ] **Step 1: Add a section**

Append (matching the doc's existing per-secret format — read it first and follow its heading style):

```markdown
## BETA_BUILDS_TOKEN

Fine-grained personal access token used by the Beta workflow (`beta.yml`) to
publish per-merge beta releases into `submersion-app/beta-builds`.

- Resource owner: `submersion-app`
- Repository access: only `submersion-app/beta-builds`
- Permissions: Contents - Read and write (nothing else)
- Set with: `gh secret set BETA_BUILDS_TOKEN --repo submersion-app/submersion`
- Rotation: regenerate the token and re-run the same command. The workflow
  fails loudly on the next merge if the token expires.
```

- [ ] **Step 2: Commit**

```bash
git add docs/developer/release-secrets-setup.md
git commit -m "docs: document BETA_BUILDS_TOKEN for the beta pipeline"
```

---

### Task 7: Full verification

- [ ] **Step 1: Repo checks**

```bash
dart format . && flutter analyze && python3 -c "import yaml; [yaml.safe_load(open(f)) for f in ['.github/workflows/build-all.yml','.github/workflows/release.yml','.github/workflows/beta.yml','.github/workflows/ci.yaml']]; print('all YAML OK')"
./scripts/generate_appcast_beta_test.sh
```

(Dart untouched, so format/analyze are expected clean; they guard against accidental edits.)

- [ ] **Step 2: Confirm both live smokes passed** (Task 2 and Task 5 Step 4). If either was deferred, run it now — this plan is not done until `build-all.yml` and `beta.yml` have each completed a real run.

---

## Deferred (from spec, deliberately not in this plan)

- TestFlight/Play uploads from `beta.yml` (Phase 4; needs the public TestFlight group and Play open-testing track set up first).
- `promote.yml` and `scripts/release/promote.sh` (Phase 5).
- `scripts/release/status.sh` / `delete_release.sh` awareness of the beta workflow.
- README/docs "join the beta" instructions (Phase 3, alongside the channel UI).
- `release.yml` still triggers on `-alpha/-beta/-rc` tags; that legacy prerelease path becomes the hotfix escape hatch and is untouched here.

## Risks

- `workflow_run` only fires from the default branch: the trigger goes live when this branch merges; until then `workflow_dispatch` is the test path.
- `secrets: inherit` exposes all repo secrets to `build-all.yml` — same trust boundary as today (same repo, same jobs).
- The train-closed guard depends on stable tags being 4-segment `vX.Y.Z.N`; the legacy prerelease tags (`vX.Y.Z-beta.N`) do not match `v${SEMVER}.[0-9]*` and correctly do not close the train.
- Windows `VersionInfoVersion` parts are 16-bit: build numbers must stay <= 65535 (discovered when the first smoke used 999999 and Inno Setup rejected it). Commit count is ~4,800 today, so decades of headroom — but if the counter scheme ever changes (e.g. to a date-based number), the Windows installer is the binding constraint. The `precheck` job in `beta.yml` enforces this explicitly, so an over-range number fails in seconds with a named cause instead of as an opaque `iscc` error after the full build matrix.
