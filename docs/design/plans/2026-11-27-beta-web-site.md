# Beta Web Site Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline in this session (the owner's choice; never subagent-driven). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Serve every published beta at `https://beta.web.submersion.app`, and let the stable and beta web sites point at each other from Settings > About, with the beta site's version badged "(Beta)".

**Architecture:** `deploy-web.yml` gains a `site` input that picks the release repository, Pages repository and domain; `beta.yml` calls it after publishing. In the app, a pure rule maps the page origin to stable, beta or none; a Riverpod provider exposes it so the About badge and a new About row read it, and tests override it.

**Tech Stack:** GitHub Actions, Python 3 scripts, Flutter (Riverpod, url_launcher, gen-l10n).

**Spec:** `docs/design/specs/2026-11-27-beta-web-site-design.md`

## Global Constraints

- Stable site: host `web.submersion.app`, Pages repository `submersion-app/web`, releases from `submersion-app/submersion`.
- Beta site: host `beta.web.submersion.app`, Pages repository `submersion-app/web-beta`, releases from `submersion-app/beta-builds`.
- `GOOGLE_WEB_CLIENT_ORIGINS` = `https://web.submersion.app,https://beta.web.submersion.app`.
- No `https://web.submersion.app` or `https://beta.web.submersion.app` literal anywhere under `lib/` (spec decision 11): the app spells host names and builds the URL at runtime.
- The stable deploy path behaves exactly as today; `site` defaults to `stable`.
- Each new string is translated into all 11 non-English ARBs (ar, de, es, fr, he, hu, it, ja, nl, pt, zh); `flutter gen-l10n` runs last.
- No em-dashes in any file or message. No mention of AI tools in commits or the PR.
- Local test runs: only the files named in a task, by path.

## Review Focus

1. A page served from a local dev server (`http://localhost:8080`) or any self-hosted address: no badge, no rows. Task 1 table and Task 2 widget test.
2. The real origins in odd casing or with a trailing slash still match; `http://`, a port, or a look-alike host (`https://evil.web.submersion.app`) do not. Task 1 table.
3. Native builds (iOS, Android, desktop) never read `Uri.base.origin` (it throws for `file:` URIs) and never show the web rows; the store "Join the Beta" row is unchanged. Task 1 provider test, Task 2 widget test.
4. A manual `site=beta` redeploy of a tag pruned from `beta-builds` fails with a message naming `beta-builds`, not `submersion`. Task 3 step.
5. A beta run built with `skip-publish` deploys nothing and the alert still sees every job. Task 3, `beta_failure_alert_test.py`.

---

### Task 0: Before screenshots

Headless throwaway golden (the real web app at `localhost` matches neither site, so it cannot show either case; memory `widget-screenshot-via-throwaway-golden`).

- [ ] **Step 1:** Write a throwaway test beside `settings_about_build_date_test.dart` that pumps `SettingsSectionDetailPage(sectionId: 'about')` with the same overrides, loads Arial under `Roboto` in `setUpAll`, sets an 800 x 1400 view, and matches `goldens/tmp_about.png` for light and dark (`ThemeData(brightness: ...)`).
- [ ] **Step 2:** `flutter test <that file> --update-goldens`; copy the PNGs to the scratchpad as `01-about-before.png`, `01-about-before-dark.png`; also a 390-wide phone pair (`-phone`). Keep the test file uncommitted for Task 2's after shots, then delete it and its `goldens/`.

### Task 1: Which hosted site the page is

**Files:**
- Create: `lib/features/auto_update/domain/hosted_web_site.dart`
- Create: `lib/features/auto_update/presentation/providers/hosted_web_site_provider.dart`
- Test: `test/features/auto_update/domain/hosted_web_site_test.dart`

**Interfaces:**
- Produces:
  - `enum HostedWebSite { stable, beta, none }`
  - `const kStableWebSiteHost = 'web.submersion.app'`, `const kBetaWebSiteHost = 'beta.web.submersion.app'`
  - `HostedWebSite hostedWebSiteFor(String pageOrigin)`: normalise like `GoogleDriveClientConfig.builtInWebClientIdFor` (trim, lowercase, strip trailing `/`), then match `https://<host>` exactly.
  - `HostedWebSite get currentHostedWebSite`: `none` unless `HostPlatform.isWeb`, else `hostedWebSiteFor(Uri.base.origin)`.
  - `extension HostedWebSiteLinks on HostedWebSite { Uri? get uri; HostedWebSite? get other; }`: `uri` is `Uri(scheme: 'https', host: ...)` for stable/beta, null for none; `other` swaps stable and beta, null for none.
  - `final hostedWebSiteProvider = Provider<HostedWebSite>((ref) => currentHostedWebSite);`

- [ ] **Step 1: Write the failing tests** in `hosted_web_site_test.dart`:
  - `recognises each site by its exact origin`: `'https://web.submersion.app'` gives stable, `'https://beta.web.submersion.app'` gives beta.
  - `ignores case and a trailing slash`: `'HTTPS://Beta.Web.Submersion.App/'` gives beta.
  - `anything else is none` over `['http://web.submersion.app', 'https://web.submersion.app:8443', 'https://evil.web.submersion.app', 'https://submersion.app', 'http://localhost:8080', 'https://dives.example.org', '']`.
  - `links build the other site's address`: `HostedWebSite.stable.uri.toString() == 'https://web.submersion.app'`, beta likewise, `none.uri` null; `stable.other == beta`, `beta.other == stable`, `none.other` null.
  - `a native build is never a hosted site`: `currentHostedWebSite == HostedWebSite.none` on the VM (proves `Uri.base` is not read for a `file:` base).
- [ ] **Step 2:** `flutter test test/features/auto_update/domain/hosted_web_site_test.dart`; expect a compile failure (no such file).
- [ ] **Step 3:** Implement the two files. Doc comments say why the hosts are not `https://` literals (decision 11) and why promotion forces runtime detection (decision 5).
- [ ] **Step 4:** Same command; expect all pass.
- [ ] **Step 5:** Commit `feat(auto-update): recognise Submersion's stable and beta web sites`.

### Task 2: About badge and site row

**Files:**
- Create: `lib/features/settings/presentation/widgets/hosted_web_site_tile.dart`
- Modify: `lib/features/settings/presentation/widgets/about_submersion.dart` (`watchAboutVersionLabel`)
- Modify: `lib/features/settings/presentation/pages/settings_page.dart` (About card, after the `betaEnrollUrl` row)
- Modify: `lib/l10n/arb/app_*.arb` (12 files), regenerate `app_localizations*.dart`
- Modify: `test/helpers/recording_url_launcher.dart` (record `webOnlyWindowName`)
- Create: `test/features/settings/presentation/pages/settings_about_web_site_test.dart`
- Create: `test/architecture/hosted_web_site_literals_test.dart`

**Interfaces:**
- Consumes: Task 1's `hostedWebSiteProvider`, `HostedWebSiteLinks`, the host constants.
- Produces: `class HostedWebSiteTile extends ConsumerWidget`: builds nothing for `none`, else a `Column` of `Divider(height: 1)` and a `ListTile`. `RecordingUrlLauncher.windowNames` (`List<String?>`), filled alongside `launched`.

Strings, grouped after `settings_updates_joinBetaSubtitle` in every ARB:

| Key | English |
| --- | --- |
| `settings_updates_tryBetaWeb` | Try the beta web app |
| `settings_updates_tryBetaWebSubtitle` | New features early, at {address}. It keeps its own library; sync to see your dives there. |
| `settings_updates_useStableWeb` | Use the stable web app |
| `settings_updates_useStableWebSubtitle` | At {address}. It keeps its own library, separate from this one. |

`{address}` is a `String` placeholder filled with the other site's host (no scheme).

- [ ] **Step 1: Write the failing widget tests** in `settings_about_web_site_test.dart`, reusing `settings_about_build_date_test.dart`'s harness plus `hostedWebSiteProvider.overrideWithValue(...)` and `useRecordingUrlLauncher()`:
  - `the stable site offers the beta site`: finds `'Try the beta web app'` and a subtitle containing `'beta.web.submersion.app'`; `'Version 1.8.5.412'` without `(Beta)`; tapping the row records `'https://beta.web.submersion.app'` with window name `'_blank'`.
  - `the beta site offers the stable site and badges its version`: finds `'Use the stable web app'`, `'Version 1.8.5.412 (Beta)'` on the page and inside `SubmersionAboutDialog` after tapping About Submersion; tapping the row records `'https://web.submersion.app'`, `'_blank'`.
  - `any other page shows neither row`: `HostedWebSite.none` finds neither title and no `(Beta)`.
- [ ] **Step 2: Write the guard** `hosted_web_site_literals_test.dart`: walk every file under `lib/` and fail, naming file and line, on either `https://web.submersion.app` or `https://beta.web.submersion.app`. A second test feeds the scan a string containing one literal and expects a hit, so the guard can fail.
- [ ] **Step 3:** Run both files; expect the widget tests to fail (rows missing) and the guard to pass.
- [ ] **Step 4:** Implement: `watchAboutVersionLabel` badges when `(autoUpdate && channel == beta) || ref.watch(hostedWebSiteProvider) == HostedWebSite.beta`; `HostedWebSiteTile` (stable: `Icons.science_outlined`, try strings; beta: `Icons.undo`, use strings) opens `site.other!.uri!` with `launchUrl(uri, webOnlyWindowName: '_blank')`; place `const HostedWebSiteTile()` after the `betaEnrollUrl` block. Add the English keys to `app_en.arb` with `@` metadata for `address`; translate into the 11 other ARBs; run `flutter gen-l10n` last and check `grep -A1 "settings_updates_tryBetaWeb" lib/l10n/arb/app_localizations_de.dart` shows German.
- [ ] **Step 5:** Run the two new files and `test/features/settings/presentation/pages/settings_about_build_date_test.dart`; expect all pass.
- [ ] **Step 6:** After screenshots with Task 0's throwaway test, now with three cases (stable site, beta site, and the About dialog on the beta site), light, dark and phone: `02-about-stable-site-after*.png`, `03-about-beta-site-after*.png`, `04-about-dialog-beta-site-after.png`. Delete the throwaway test and its goldens.
- [ ] **Step 7:** `dart format .`, `flutter analyze`; commit `feat(settings): point the stable and beta web sites at each other` (ARBs and generated files in the same commit).

### Task 3: Deploy the beta site

**Files:**
- Modify: `.github/workflows/deploy-web.yml`
- Modify: `.github/workflows/beta.yml` (new `deploy-web` job; `alert.needs`)
- Modify: `.github/workflows/build-all.yml:843` (`GOOGLE_WEB_CLIENT_ORIGINS`)
- Test: `scripts/bots/beta_failure_alert_test.py` (existing; checks `alert.needs` lists every job)

- [ ] **Step 1:** `deploy-web.yml`: add input `site` (type `choice` with `stable`, `beta` on dispatch; `string` default `stable` on call). Replace the `SITE_DOMAIN`/`PAGES_REMOTE` env with a first step in `deploy` that maps `site` to `RELEASE_REPO`, `PAGES_REMOTE` and `SITE_DOMAIN` (written to `$GITHUB_ENV`), failing on any other value; the `configured` job's notice names the site. Use `RELEASE_REPO` in "Refuse an unknown tag" (its error names that repository) and "Download". Concurrency group `deploy-web-${{ inputs.site || 'stable' }}`. Update the header comment and the dispatch descriptions ("Release tag", no longer "Stable").
- [ ] **Step 2:** "Read the release's sqlite3.wasm lock": for `stable` keep the tag fetch; for `beta`, `gh release download "$TAG" --repo "$RELEASE_REPO" --pattern metadata.json`, read `.sourceSha` with `python3 -c`, refuse an empty value, `git fetch -q --depth 1 origin "$SHA"` and `git show "$SHA:scripts/web/sqlite3_wasm.lock"`.
- [ ] **Step 3:** `beta.yml`: job `deploy-web` named "Deploy the beta web app", `needs: [precheck, publish-beta]`, `if: needs.publish-beta.result == 'success'`, `uses: ./.github/workflows/deploy-web.yml` with `tag: ${{ needs.precheck.outputs.tag }}`, `site: beta`, secret `WEB_DEPLOY_TOKEN`, `permissions: contents: read`. Add `deploy-web` to `alert.needs`.
- [ ] **Step 4:** `build-all.yml`: origins value per Global Constraints; the comment above it names both sites.
- [ ] **Step 5:** `python3.14 -m pytest scripts/bots/beta_failure_alert_test.py -q`; expect pass. Run `actionlint` on the three workflows if installed, else `python3.14 -c "import yaml,sys; [yaml.safe_load(open(f)) for f in sys.argv[1:]]"` on them.
- [ ] **Step 6:** Commit `feat(web): deploy every beta to beta.web.submersion.app`.

### Task 4: Docs

**Files:**
- Modify: `docs/user/web-app.md` (new "Beta web app" section; CORS examples mention adding the beta address)
- Modify: `docs/developer/web-site-setup.md` (the beta site: how it deploys, the four owner steps, `-f site=beta` redeploy and rollback)
- Modify: `docs/developer/web.md` (one paragraph on the beta site)
- Modify: `README.md` (beta section: the beta web address beside TestFlight and Play)
- Modify: `docs/design/specs/2026-11-03-hosted-web-app-design.md` (the non-goal "A beta or preview site" gains "(since added: `2026-11-27-beta-web-site-design.md`, #4481)")

- [ ] **Step 1:** Write the sections. The user doc says: the address; it updates with every beta; its library is separate and fills through sync; a stable device holds beta peers (#2619) so a beta tester syncs the beta site with beta apps.
- [ ] **Step 2:** `python3.14 scripts/checks/check_docs_links.py`; expect OK.
- [ ] **Step 3:** Commit `docs(web): document the beta web site`.

### Task 5: Verify and hand off to the PR

- [ ] **Step 1:** `dart format --set-exit-if-changed .` and `flutter analyze`; both clean.
- [ ] **Step 2:** `scripts/web/build_web.sh` with `GOOGLE_WEB_CLIENT_ID=test.apps.googleusercontent.com` and the two origins; then `python3.14 scripts/web/stage_hosted_site.py stage` on a zip of `build/web` with `--domain beta.web.submersion.app --client-id test.apps.googleusercontent.com`: expect no origin warning. Rebuild with only the stable origin and stage for the beta domain: expect the origin warning (decision 11 proved on a real bundle).
- [ ] **Step 3:** Continue with the build-feature skill's step 5 (PR). The PR body lists the owner's four setup steps as a pre-merge checklist (decision 10).
