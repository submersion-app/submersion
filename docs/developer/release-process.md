# Release Process

Submersion uses a two-channel release model: every green merge to `main`
becomes a **beta** automatically, and a **stable** release is a promotion of
a beta that soaked well - the identical artifacts, never a rebuild. The
design history lives in `docs/superpowers/specs/2026-07-28-release-channels-design.md`;
this page is the operational guide.

User-facing channel documentation is on the wiki:
[Update Channels](https://github.com/submersion-app/submersion/wiki/Update-Channels).

## The pipeline at a glance

```
merge PR to main
  -> CI/CD (ci.yaml)                       tests, analyze, all-platform smoke
  -> Beta (beta.yml, on CI success)        signed builds via build-all.yml
       -> beta-builds release              dmg/exe/tar.gz/apk/aab/ipa/pkg
          + appcast-beta.xml               Sparkle beta feed
       -> TestFlight                       iOS + macOS, "Public Beta" group
       -> Play testing track               PLAY_BETA_TRACK (see below)

promote (workflow_dispatch, manual)
  -> Promote Beta (promote.yml)            copies the chosen beta's artifacts
       -> main-repo tag + stable release   + appcast.xml entry (stored sig)
       -> Play: track -> production        identical AAB, staged rollout
       -> App Store: submit existing build, releases on approval
       -> version-bump PR                  auto-merges; opens the next train
```

## Versioning

- Marketing version comes from `pubspec.yaml` (bumped only by the post-
  promotion bump PR, via `scripts/release/bump_version.sh`).
- Build number is the commit count on `main`, injected at build time; a
  beta identifies as e.g. `1.7.2 (4977)`, tagged `v1.7.2.4977`.
- There is no `-beta` suffix anywhere in a binary: channel identity lives in
  where a build is published, which is what lets stable ship the exact bytes
  testers ran.

## Day to day: nothing

Merging a PR is releasing to beta. `beta.yml` runs only after CI/CD succeeds
on `main`, builds the exact CI-validated commit, and publishes everywhere.
There is nothing to remember per merge.

### Guards that can stop a beta (all fail fast and loudly)

| Guard | Meaning | Fix |
|---|---|---|
| Train closed | `pubspec` marketing version already has a stable tag | Land the version bump (normally the auto-merged bump PR from promotion) |
| Nothing shippable | Only docs/CI/image files changed since the last beta | Nothing to do; by design |
| Build number > 65535 | Windows `VersionInfoVersion` parts are 16-bit | Requires a new numbering scheme; decades away at current commit rate |
| Already published | HEAD is the same commit as the newest beta | Nothing to do; a rerun, not a failure |

## Promoting a beta to stable

Pick the newest beta that soaked without incident (the
[beta-builds releases](https://github.com/submersion-app/beta-builds/releases)
list, newest first; betas are pruned to the newest 30). Disqualifying issues
get the `beta-blocker` label, which hard-blocks promotion until closed.

Then either:

- **CLI:** `./scripts/release/promote.sh 4977` (or `--latest`); options
  `--rollout 0.2`, `--bump minor`. Run `--help` for details.
- **Web:** Actions > Promote Beta > Run workflow, same inputs.

What the workflow does: verifies the beta (checksums, blockers, source
commit on `main`), tags `main` and publishes the stable GitHub release with
the copied artifacts and an `appcast.xml` entry built from the Sparkle
signature stored at beta-build time, promotes the identical AAB from the
Play testing track to production, submits the existing TestFlight builds
for App Review, and opens the version-bump PR (auto-merges on green CI).

The five jobs are independent: a partial failure opens a tracking issue
(`notify-failures`) and only the failed leg needs re-running.

### After promoting

Nothing to do. iOS and macOS carry `automatic_release: true`, so both go
live on their own once Apple approves (~24-48h); the bump PR merges itself,
and the next merge to `main` starts the next beta train.

Two things still want a human:

- **A rejection.** Auto-release only covers the approved path. A rejected
  version sits in App Store Connect until someone addresses it. If the
  rejection is a misunderstanding rather than a defect (1.7.4 and 1.7.5 were
  both flagged under 5.1.1(v) because the first-launch "Create Your Profile"
  step reads as account creation), reply in the Resolution Center thread and
  do **not** re-run promote: the submission is still open, Apple approves
  from the reply, and promote would cancel that submission and start over.
  The standing explanation Apple reads before every review lives in
  `ios/fastlane/metadata/review_information/notes.txt` (macOS has an
  identical copy; `scripts/release/app_review_notes_test.sh` enforces
  that). Update it whenever a reviewer needs context a reply had to supply.
- **A bad build.** There is no staged rollout to halt and no rollback once a
  version is live. Recovering means pulling it and shipping a fix through
  another review cycle. If that risk ever outweighs the convenience, set
  `phased_release: true` in `ios/fastlane/Fastfile` for a haltable 7-day iOS
  rollout, or put `automatic_release` back to `false` in both Fastfiles.

## Contributor credits

The stable release body credits work as it goes. `generate_changelog.sh`
attributes every bullet to the person who wrote it and the PR that merged it
(`- fixed a thing by @octocat in #42`), and closes with a **New Contributors**
section naming anyone whose first commit to the repository landed in this
release. Nothing to run by hand: `promote.yml` generates it.

Where the authorship comes from, in `scripts/release/contributors.sh`:

- **PR numbers come from git alone.** A merge commit records
  `Merge pull request #N`, and its second parent names the commits that PR
  contributed. A squash-merged commit carries `(#N)` in its subject instead.
  Either way no network is involved.
- **GitHub logins come from the API.** Git records a name and an email, never
  a login, so an @mention that actually notifies someone has to be looked up
  through `repos/.../compare`. First contributions are a second lookup per
  contributor.

Credits never block a release. If the API is unavailable the script falls back
to logins derived from `@users.noreply.github.com` commit emails, and where
even that fails the bullet simply renders without a name. First contributions
are only ever claimed from the API, because announcing someone as a first-time
contributor when they are not is worse than saying nothing. Bots are never
credited and never announced.

Two consumers treat the credits differently, from the same source:

- The **Sparkle update dialog** and the GitHub release page show them in full.
- The **App Store "What's New"** does not.
  `sanitize_apple_store_notes.py` strips the handles, the PR numbers and the
  whole New Contributors section, because `promote.yml` derives that field
  from the published release body and an @handle is not a name.

Pass `--no-attribution` to `generate_changelog.sh` to reproduce the older,
uncredited body.

**In the announcement, too.** Every `docs/releases/v<version>.md` ends with a
`## 🙏 Contributors` section thanking the release's contributors by handle,
with first-time contributors called out. Take the list from the generated
release body rather than reconstructing it.

The emoji is deliberate and local to these files. `docs/releases/*.md` are
ScubaBoard posts rather than developer documentation, and every section
heading in them carries one (`## ✨ New and improved`, `## 🐞 Bug fixes`,
`## 🔧 Under the hood`, `## ⚠️ Upgrade notes`). No other document under
`docs/` does. A bare `## Contributors` would be the odd heading out in its own
file; the no-emoji rule in CLAUDE.md governs everything except this format.

## Play Store state

Until Google grants production access (earned by a closed test with 12+
testers over 14 days), betas target the closed `alpha` track and the
`promote-play` leg cannot succeed. The track is a single switch:
`PLAY_BETA_TRACK` (default `alpha` in `android/fastlane/Fastfile`); flip to
`beta` (open testing) once access is granted.

## Hotfix escape hatch

The primary hotfix path is fix-on-main, beta, promote quickly. If `main`
genuinely cannot ship, the legacy tag-driven `release.yml` still exists:
branch from the last stable tag, cherry-pick, and push a 4-segment tag with
a build number above the current commit count. Expected to be rare.

## Troubleshooting

| Symptom | Cause | Action |
|---|---|---|
| Beta run fails in seconds with "already has a stable release" | Bump PR from the last promotion has not landed | Merge it (check CI ran; close/reopen kicks it if needed) |
| Play upload: `Precondition check failed` | Track not set up in Play Console, or targeting open testing without production access | Configure the closed track / check `PLAY_BETA_TRACK` |
| TestFlight upload slow (~10+ min) | External distribution waits for Apple build processing | Normal; 45-minute job timeout absorbs it |
| Testers not seeing a new TestFlight build | First build of a new version train awaits Beta App Review | Normal; once per train, internal testers unaffected |
| Promotion: "pruned or never built" | The build aged out of the newest-30 window | Promote a retained build instead |
| Store upload leg failed after release published | Legs are independent | Fix the cause, then dispatch the SAME promotion again - it is re-entrant (existing release is verified by checksum and left untouched; a merged or already-open bump PR is skipped). Avoid GitHub's "re-run failed jobs": it replays the workflow definition pinned at the original run, without any fixes merged since |

## Pointers

- Secrets (App Store, Play, Sparkle, `BETA_BUILDS_TOKEN`,
  `RELEASE_BOT_TOKEN`): `docs/developer/release-secrets-setup.md`
- Workflows: `.github/workflows/{build-all,beta,promote,release}.yml`
- Scripts: `scripts/release/` (`promote.sh`, `bump_version.sh`,
  `contributors.sh`; the old `release.sh` orchestrator belongs to the legacy
  tag path)
- Beta artifact host: `github.com/submersion-app/beta-builds`
