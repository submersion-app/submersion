# Release Channels: Stable and Beta

**Date:** 2026-07-28
**Status:** Approved design, pending implementation plan

## Motivation

A beta tester on ScubaBoard (post 10802063) proposed dual release channels: a
stable channel for regular users and a beta channel for testers willing to
tolerate occasional issues, so that "minor issues that only appear in
real-world use" surface before a release reaches everyone. This design
formalizes that proposal across branching, issues/PRs, CI/CD, distribution,
and upgrades.

## Current state (survey findings)

- A proto-beta channel already exists: tags matching `-alpha|-beta|-rc` create
  a GitHub pre-release, route iOS/macOS uploads to TestFlight instead of the
  App Store, and skip appcast generation so Sparkle users never see them.
  `GithubUpdateService` skips pre-releases.
- `release.yml` (tag-triggered) builds all five platforms: signed/notarized
  dmg with Sparkle EdDSA signature, Mac App Store pkg, Inno Setup exe, Linux
  tar.gz, signed APK + AAB, iOS ipa. Uploads: App Store Connect, Google Play
  internal track (draft), GitHub Release with appcast.
- One bundle ID (`app.submersion`) everywhere; no flavors. Versioning is
  manual via `scripts/release/bump_version.sh`; tags are 4-segment
  (`v1.7.0.117`).
- The in-app updater is channel-aware in structure (`UpdateChannel` enum,
  Sparkle/WinSparkle on macOS/Windows, GitHub poller elsewhere) but has no
  user-facing channel selection.
- Latent bugs found: the AAB builds without `UPDATE_CHANNEL=playstore`; the
  MAS pkg inherits `UPDATE_CHANNEL=github` (so a Mac App Store build believes
  auto-update is enabled); `update_providers.dart:25` declares a
  `Windows.zip` asset suffix but releases publish `Windows-Setup.exe`.

## Decisions

| Decision | Choice |
| --- | --- |
| Install model | Same app, in-place. One bundle ID; channel is a user setting, not a separate install. |
| Cadence | Subsurface-style: every green merge to `main` produces a beta build for all five platforms, including TestFlight and Play. |
| Stable | Occasional promotion of an already-shipped beta build. No rebuild. |
| Beta hosting | Dedicated `submersion-app/beta-builds` repo, one release per merge, pruned to the newest ~15. |
| Versioning | Marketing version from `pubspec.yaml`; build number auto-derived as commit count on `main`. No `-beta` suffix in binaries; channel identity lives in distribution, not the version string. |
| Channel UI | Settings toggle switches the update feed on desktop; signposts TestFlight/Play enrollment on mobile. |

## Versioning model

- Build number = `git rev-list --count HEAD` on `main`, passed via
  `flutter build --build-number=`. `pubspec.yaml` never churns per merge; no
  bot commits. The count (thousands) already exceeds the current build
  number (117) and is monotonic as long as `main` is never force-pushed.
- A beta identifies as, e.g., `1.8.0 (5601)`. App Store Connect requires a
  plain `X.Y.Z` short version anyway; Play's versionName is display-only.
  Keeping the version string channel-free is what allows stable to be a
  byte-identical promotion of a tested beta.
- Stable tags keep the existing 4-segment convention (`v1.8.0.5601`) in the
  main repo. Beta releases carry the same tag format in `beta-builds`; each
  release body records the source `main` SHA (tags in that repo cannot point
  at main-repo commits).
- `bump_version.sh` survives, managing only the marketing version.

## Branch, issue, and PR workflow

- No new long-lived branches. Feature work remains PR-per-worktree into
  `main`. Merging now means shipping to beta within the hour, so `main` must
  stay shippable: incomplete features hide behind flags
  (`lib/core/constants/feature_flags.dart` pattern), and schema migrations
  land complete, in a single PR.
- Beta builds trigger only from green `main`: the beta pipeline runs on
  successful completion of the CI/CD workflow (`workflow_run`), never on raw
  push. A concurrency group with cancel-in-progress collapses merge bursts.
- Issues: a beta-report template captures channel and version/build (the
  build number pinpoints the exact merge). Labels: `beta` for triage,
  `beta-blocker` for issues that block promotion. Promotion requires no open
  `beta-blocker` issues.
- Hotfixes: primary path is fix-on-main, which becomes a beta immediately,
  then promote quickly. Escape hatch when `main` cannot ship: short-lived
  branch off the stable tag plus a tag-driven `release.yml` run with an
  explicitly supplied build number greater than the current maximum.
  Documented, expected to be rare.

## CI/CD workflows

### `build-all.yml` (new, reusable via `workflow_call`)

The five build jobs extracted from `release.yml`, parameterized by marketing
version, build number, and per-artifact `UPDATE_CHANNEL` dart-defines.
Retains the signing/notarization logic, Sparkle EdDSA signing, and the
16KB-alignment and native-libs guard scripts. Extraction fixes the three
latent bugs: AAB gets `UPDATE_CHANNEL=playstore`, MAS pkg gets `appstore`,
and the `Windows.zip` suffix in `update_providers.dart` is corrected.

### `beta.yml` (new, per merge)

- Trigger: `workflow_run` on CI/CD success on `main`, plus
  `workflow_dispatch`. Concurrency: cancel-in-progress.
- `compute-version`: marketing version from `pubspec.yaml`; build number =
  commit count. Preflight: fail loudly if the marketing version is already
  live on the App Store (train-closed guard; see Promotion).
- Build via `build-all.yml`.
- `publish-beta`: create release `vX.Y.Z.N` in `beta-builds` with all
  artifacts, `checksums-sha256.txt`, and `metadata.json` (source SHA,
  Sparkle EdDSA signature, dmg length) for later promotion. Requires new
  secret `BETA_BUILDS_TOKEN` (fine-grained PAT, `contents: write` on
  `beta-builds` only).
- `appcast-beta`: generate `appcast-beta.xml` = recent beta entries plus all
  stable entries (a superset feed guarantees beta users a forward path
  through stables), attached to the new release. Feed URL is permanently
  `beta-builds/releases/latest/download/appcast-beta.xml`.
- `upload-testflight`: iOS ipa and MAS pkg to TestFlight, internal group +
  "Public Beta" external group.
- `upload-play`: AAB to the open testing track, `release_status: completed`.
- `prune`: keep the newest ~15 beta releases.

### `promote.yml` (new, manual `workflow_dispatch`)

Input: a beta build number. A metadata operation, no build step:

1. Resolve release `vX.Y.Z.N` in `beta-builds`; read `metadata.json`; verify
   checksums; confirm no open `beta-blocker` issues; fail if the beta was
   pruned.
2. GitHub/desktop: tag `vX.Y.Z.N` in the main repo at the source SHA; create
   the main-repo GitHub Release with the copied artifacts; regenerate release
   notes from the tag range; append the stable `appcast.xml` entry using the
   stored Sparkle signature (dmg bytes identical, notarization stapled, so
   the signature remains valid); run `validate-release`.
3. Google Play: fastlane promotes the same AAB from open testing to
   production (optionally staged rollout).
4. App Store (iOS + macOS): fastlane `deliver` with
   `skip_binary_upload: true` submits the existing TestFlight build for
   review. Apple-paced (~24-48h).
5. Aftercare, coupled to promotion: immediately open the marketing-version
   bump PR (auto-merge on green). Promotion of newer betas is blocked until
   it lands.

Wrapper: `scripts/release/promote.sh <build>` with local preflight.

### `release.yml` (kept, demoted)

Refactored to call `build-all.yml`; retained solely as the hotfix escape
hatch (tag-driven full rebuild from a non-main branch with an explicit build
number).

### App Store version-train rules (verified)

- Within one version train, unlimited builds with increasing build numbers.
- Parallel trains may coexist in TestFlight; uploads to the older train are
  accepted while neither is released.
- Releasing a version closes its train: later uploads with that version
  string are rejected. Hence bump-at-promotion-time (not at approval) and the
  beta-pipeline preflight against the live App Store version.

## Store and distribution setup

- App Store Connect: external TestFlight group "Public Beta" with public link
  (capacity 10,000). First build of each version train needs Beta App Review
  (~hours); subsequent builds flow without review. macOS TestFlight gives Mac
  App Store users a beta path.
- Google Play: open testing track; opt-in URL
  `https://play.google.com/apps/testing/app.submersion`. Internal track
  remains for private experiments.
- GitHub: main-repo releases remain the stable channel, unchanged.
  `beta-builds` is public, issues/discussions disabled, README routes testers
  to the main repo's beta issue template. APK asset names stay predictable
  for Obtainium users.
- Docs: README Download section and the docsify site gain beta-channel
  instructions; announce on the ScubaBoard thread when live.

## In-app channel UI

In the existing `auto_update` module (Settings > App Updates), extending
`update_preferences.dart`:

- Desktop (github-channel builds): "Update channel" selector, Stable/Beta.
  Choosing Beta shows a one-time dialog covering: betas may migrate the
  database ahead of stable; switching back is not a downgrade (you keep the
  current beta until the next stable overtakes it); synced devices should run
  the same channel. On confirm: persist, switch the Sparkle/WinSparkle feed
  via `setFeedURL()` (macOS/Windows) or repoint the GitHub poller at
  `beta-builds` (Linux), and trigger an immediate check.
- iOS / Mac App Store: "Join the beta" opens the TestFlight public link. iOS
  detects a TestFlight install via the sandbox receipt and shows the channel.
- Android: "Join the beta" opens the Play opt-in page. Play does not expose
  track membership to the app, so show enrollment guidance, not a guessed
  badge.
- About/version row shows `1.8.0 (5601) . Beta` when the channel is known.
- All strings localized into the 10 non-English locales.

### Update behavior per platform, beta channel

| Platform | Experience |
| --- | --- |
| macOS (dmg) | Fully automatic via Sparkle (4h checks, silent install on relaunch) |
| Windows | Automatic check via WinSparkle; one-click Inno Setup upgrade |
| Linux | Update banner + download link (tarball; same as stable today) |
| iOS | Automatic via TestFlight app |
| Android | Automatic via Play once enrolled in open testing |
| Mac App Store | Automatic via TestFlight for Mac |

## Upgrade and data safety

Beta users run schema migrations weeks before stable users, on real dive
logs. Four guards:

1. Pre-migration backup: the automatic backup before any schema upgrade is
   verified for coverage and named in the beta opt-in dialog.
2. Graceful downgrade refusal: read the SQLite `user_version` before Drift
   opens/migrates; if newer than the app supports, show a friendly screen
   offering restore-from-backup or a link to the current beta, instead of
   undefined behavior. Protects stable users too (restored beta backups,
   shared databases).
3. Cross-channel sync gate: verify/harden that a peer receiving
   newer-schema-version sync payloads holds them and reports "update
   required" rather than mis-ingesting. The opt-in dialog advises keeping a
   multi-device fleet on one channel.
4. Migration discipline: once any beta ships schema vN, vN is frozen; a fix
   means vN+1. Migrations land complete, in a single PR.

## Rollout phases

Each phase independently shippable and reversible:

- Phase 0, groundwork: fix the `UPDATE_CHANNEL` dart-defines and the
  Windows asset suffix; implement/verify data-safety guards 1-3.
- Phase 1, extraction: `build-all.yml`; `release.yml` calls it with
  unchanged behavior, proven by a routine stable release.
- Phase 2, beta publishing (desktop): create `beta-builds`; add `beta.yml`
  with publish, appcast-beta, prune. Private soak.
- Phase 3, channel UI: Settings toggle, Linux poller channel-awareness,
  docs. Beta publicly joinable on desktop.
- Phase 4, store lanes: TestFlight public-link group and Play open-testing
  uploads wired into `beta.yml`.
- Phase 5, promotion: `promote.yml`, `promote.sh`, auto bump-PR; first real
  promotion cycle; ScubaBoard announcement.

## Testing

- `workflow_dispatch` dry-runs of each pipeline before enabling triggers.
- `validate-release` adapted to verify both channels' releases and appcasts.
- Unit tests for channel-aware update providers/services (feed selection,
  repo selection, pre-release handling).
- Widget tests for the Settings channel flow, including the opt-in dialog.

## Risks and mitigations

- Forgotten bump PR closes the TestFlight train: mitigated by
  bump-at-promotion plus the beta-pipeline preflight.
- Promoted beta pruned before promotion: promotion fails fast; retention of
  15 builds makes this unlikely in practice.
- Per-merge CI load: public repo uses free GitHub-hosted runners; the
  pipeline runs only after CI success and cancels superseded runs.
- Beta schema regressions on tester data: guards 1-4 above; the beta dialog
  sets expectations explicitly.
