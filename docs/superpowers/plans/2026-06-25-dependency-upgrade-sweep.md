# Dependency Upgrade Sweep Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring Submersion's Dart/Flutter dependencies as close to latest as is safely achievable, in risk-ordered tiers, without breaking the codegen toolchain, the native plugins, or the deliberately-pinned overrides.

**Architecture:** Upgrade in four tiers ordered by blast radius — (1) within-constraint bumps, (2) constraint-loosening bumps, (3) the Flutter/Dart SDK upgrade that unlocks the SDK-gated majors (analyzer/drift/xml/etc.), (4) re-evaluation of the four documented `dependency_overrides`. Each tier is its own branch commit with a full verification gate, so any tier can be shipped or reverted independently.

**Tech Stack:** Flutter (stable channel), Dart, Drift (SQLite codegen), Riverpod 3 (+ generator), Freezed, json_serializable, Mockito — all driven by `build_runner` and bounded by the `analyzer` version the Flutter SDK bundles.

## Global Constraints

- **Branch, never `main`.** Use a dedicated worktree per the project convention: `claude -w dep-upgrade` (or `git worktree add`). `main` was just stabilized; an upgrade sweep must fail in isolation.
- **Worktree init is mandatory before anything else:** `git submodule update --init --recursive` then `flutter pub get` then `dart run build_runner build --delete-conflicting-outputs`. DB-touching tests fail with `database.g.dart: No such file or directory` if codegen is skipped.
- **Codegen is not optional after any dependency change:** always re-run `dart run build_runner build --delete-conflicting-outputs` before analyzing or testing. Drift, Riverpod, Freezed, json_serializable, and Mockito all generate code against the resolved `analyzer`.
- **`*.mocks.dart`, `*.g.dart`, `*.freezed.dart` are gitignored** (as of commit `d3e33eea32c`) — regenerated artifacts, never committed. Do not `git add` them.
- **Format the whole repo before pushing:** `dart format .` (not a scoped subdir — CI's Analyze & Format job checks the entire project).
- **Run `flutter analyze` on the whole project** — never `flutter analyze | tail`, which masks failures.
- **Local tests: run targeted files**, not broad directories, to avoid Bash timeouts. Rely on CI's sharded full suite + the pre-push hook (`dart format --set-exit-if-changed`, `flutter analyze`, `flutter test`) for whole-suite coverage.
- **No `Co-Authored-By` lines in commit messages.**
- **Do not touch the four `dependency_overrides` except in Tier 4**, and only after re-verifying the documented blocker each one guards (iOS/Xcode SDK, vendored threading fix, upstream compile bug, `fit_tool` compat).
- **Native plugin changes need `pod install`** per platform (macOS and iOS Pods projects drift independently).
- **Version numbers in any UI/copy use 4-segment format** (major.minor.patch.build) — not relevant to pubspec but holds if a task touches version display.

---

## Reference: current state (captured 2026-06-25)

- **SDK:** Flutter 3.41.4 stable (revision ff37bef603, 2026-03-03), Dart SDK constraint `^3.10.0`.
- **The SDK ceiling** freezes `analyzer` at 9.0.0 (latest 14.0.0) in even the *Resolvable* column. Everything blocked by `Resolvable < Latest` (drift 2.34, xml 7, archive 4, share_plus 13, package_info_plus 10, win32 6, objectbox 5 via `flutter_map_tile_caching`) moves **only** after Tier 3.
- **Local path packages** (`libdivecomputer_plugin`, `submersion_saf`, `auto_updater_windows`) are vendored — `pub upgrade` never touches them.
- **The four overrides and their guards:**
  - `permission_handler_apple: 9.4.5` — upstream `CNAuthorizationStatusLimited` compile error (Baseflow issue #1450). Latest 9.4.10.
  - `csv: ^6.0.0`, `logger: ^2.0.0` — `fit_tool` (unmaintained) compat. Latest csv 8.0.0.
  - `device_info_plus: 12.3.0` — 12.4.0+ calls `NSProcessInfo.isiOSAppOnVision`, absent from Xcode 16.2's SDK → iOS build failure. Latest 13.1.0.
  - `auto_updater_windows: path:` — vendored WinSparkle threading fix (#83). No upstream target.

---

## Task 0: Create isolated worktree and confirm a green baseline

**Files:**
- Create: new git worktree `dep-upgrade` (branch `chore/dependency-upgrade-sweep`)
- Modify: none yet

**Interfaces:**
- Produces: a worktree with submodules + codegen initialized and a known-green test baseline that later tiers are diffed against.

- [ ] **Step 1: Create the worktree and branch**

```bash
git worktree add .claude/worktrees/dep-upgrade -b chore/dependency-upgrade-sweep
cd .claude/worktrees/dep-upgrade
```

- [ ] **Step 2: Initialize submodules, packages, codegen**

```bash
git submodule update --init --recursive
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```
Expected: all three succeed; `database.g.dart` and other generated files now exist.

- [ ] **Step 3: Capture the baseline (analyze must be clean)**

Run: `flutter analyze`
Expected: `No issues found!` (record any pre-existing warnings — later tiers must not add to them).

- [ ] **Step 4: Capture the baseline outdated report for diffing**

```bash
flutter pub outdated > ../dep-upgrade-baseline-outdated.txt
```
Expected: file written; this is the before-snapshot.

- [ ] **Step 5: Smoke-launch to confirm the app runs before any change**

Run: `flutter run -d macos` (let it reach the home screen, then quit with `q`)
Expected: app launches cleanly. This is the "it worked before" anchor.

*(No commit — Task 0 only establishes the workspace.)*

---

## Task 1: Tier 1 — within-constraint upgrade (`flutter pub upgrade`)

**Files:**
- Modify: `pubspec.lock` (only — `pubspec.yaml` constraints unchanged)

**Interfaces:**
- Consumes: the green baseline from Task 0.
- Produces: `pubspec.lock` advanced to the *Upgradable* column for ~30 packages (go_router 17.3.0, flutter_map 8.3.0, flutter_secure_storage 10.3.1, build_runner 2.15.0, permission_handler 12.0.3, path_provider 2.1.6, and the platform-interface family). Overrides and `analyzer` stay put.

- [ ] **Step 1: Upgrade within existing constraints**

Run: `flutter pub upgrade`
Expected: "Changed N dependencies!" with no `pubspec.yaml` edits. `git diff pubspec.yaml` is empty; `git diff pubspec.lock` shows the bumps.

- [ ] **Step 2: Regenerate code against the new toolchain**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `Succeeded after ...`. (`build_runner` itself bumped 2.13.1 → 2.15.0; confirm it still runs.)

- [ ] **Step 3: Analyze**

Run: `flutter analyze`
Expected: `No issues found!` Tier 1 is within-constraint, so breakage is unlikely; if anything appears, it is the culprit bump — note the package and proceed to fix at its call site.

- [ ] **Step 4: Run targeted smoke tests for the highest-traffic generated code**

```bash
flutter test test/features/dive_log
flutter test test/core
```
Expected: all pass. (Targeted dirs, not the whole suite — whole suite runs in CI / pre-push.)

- [ ] **Step 5: Launch the app**

Run: `flutter run -d macos` (reach home, quit)
Expected: launches cleanly.

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add pubspec.lock
git commit -m "chore(deps): tier 1 within-constraint upgrade (flutter pub upgrade)"
```

---

## Task 2: Tier 2 — constraint-loosening bumps (`Upgradable < Resolvable`)

**Files:**
- Modify: `pubspec.yaml` (constraint lines for the packages below), `pubspec.lock`
- Possibly modify: app code at call sites the analyzer flags (discovered in Step 3)

**Interfaces:**
- Consumes: Tier 1 lock state.
- Produces: `pubspec.yaml` constraints raised to admit the *Resolvable* versions for: `flutter_local_notifications` (^21 → ^22.0.1), `native_exif` (^0.7 → ^0.8.0), `package_info_plus` (^8 → ^9.0.1), `sqlite3_flutter_libs` (^0.5.41 → ^0.6.0). Each is a major bump with possible API changes.

> **Why these and not the others:** these four have `Upgradable < Resolvable` — a constraint edit alone unlocks them. The rest (drift, xml, archive, share_plus, win32) sit at `Resolvable < Latest` and are deferred to Tier 3 because no constraint edit can reach them.

- [ ] **Step 1: Find the blast radius before editing constraints**

```bash
grep -rn "flutter_local_notifications" lib/ | grep "import"
grep -rn "native_exif\|Exif" lib/ | grep -i exif
grep -rn "package_info_plus\|PackageInfo" lib/
grep -rn "sqlite3_flutter_libs" lib/ packages/
```
Expected: a concrete list of files that touch each package's API. These are the only files Tier 2 can break.

- [ ] **Step 2: Raise the four constraints with `--major-versions` (scoped)**

```bash
flutter pub upgrade --major-versions flutter_local_notifications native_exif package_info_plus sqlite3_flutter_libs
```
Expected: `pubspec.yaml` rewritten for exactly those four; "Changed N dependencies!". Confirm `git diff pubspec.yaml` shows only those lines.

- [ ] **Step 3: Regenerate, then analyze to surface breakage**

```bash
dart run build_runner build --delete-conflicting-outputs
flutter analyze
```
Expected: either `No issues found!` or specific errors at the call sites from Step 1. For each error, consult the package's CHANGELOG / migration notes:
  - `flutter_local_notifications` 22 — check initialization + notification-details API (the 21→22 changelog flags platform-detail constructor changes).
  - `package_info_plus` 9 — verify `PackageInfo.fromPlatform()` usage and any removed fields.
  - `native_exif` 0.8 — verify the read/write attribute API.
Fix each flagged call site to the new API. Do not suppress with `// ignore` — migrate.

- [ ] **Step 4: Targeted tests for the touched features**

```bash
flutter test test/features/notifications 2>/dev/null || echo "(no dedicated notifications tests — covered by integration)"
flutter test test/features/media   # native_exif lives in media import
```
Expected: pass.

- [ ] **Step 5: Launch on macOS AND build iOS (notifications + package_info are platform-channel heavy)**

```bash
flutter run -d macos   # reach home, quit
flutter build ios --no-codesign --simulator
```
Expected: macOS launches; iOS simulator build succeeds (this is the cheapest way to catch a platform-channel regression without hardware).

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add pubspec.yaml pubspec.lock
git commit -m "chore(deps): tier 2 constraint bumps (notifications 22, package_info 9, native_exif 0.8, sqlite3_flutter_libs 0.6)"
```

---

## Task 3: Tier 3a — upgrade the Flutter/Dart SDK (the lever)

**Files:**
- Modify: none in-repo yet (this task changes the toolchain, not the source). May modify `pubspec.yaml` `environment.sdk` if the new Dart SDK requires a higher floor.

**Interfaces:**
- Consumes: Tier 2 state.
- Produces: a newer Flutter stable installed, which raises the `analyzer` ceiling and unblocks the SDK-gated majors for Tier 3b.

> **This is the high-risk tier.** A new Dart SDK ships a new `analyzer`, and `drift_dev` / `riverpod_generator` / `freezed` / `json_serializable` run against it. Regeneration can fail or change output. Do Tier 3a (SDK) and Tier 3b (the dependent majors) as one logical unit but commit them separately so a failed 3b can be reverted without un-upgrading Flutter.

- [ ] **Step 1: Record the current SDK and check the target**

```bash
flutter --version
flutter upgrade --verify-only
```
Expected: prints current (3.41.4) and whether a newer stable is available. Note the target version string.

- [ ] **Step 2: Upgrade Flutter**

Run: `flutter upgrade`
Expected: new stable installed; bundled Dart SDK version printed. Record it.

- [ ] **Step 3: Re-resolve and check the SDK floor**

```bash
flutter pub get
```
Expected: succeeds. If it complains the new Dart SDK is below a dependency floor, raise `environment.sdk` in `pubspec.yaml` to the new Dart version (e.g. `^3.11.0`) and re-run. Confirm `flutter pub outdated` now shows `analyzer` *Resolvable* advancing past 9.0.0 — proof the lever worked.

- [ ] **Step 4: Regenerate against the new analyzer (the moment of truth)**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `Succeeded`. If it fails, the codegen packages don't yet support the new analyzer — STOP, this means Tier 3 is blocked until `drift_dev`/`riverpod_generator` publish compatible releases; revert with `flutter downgrade` and ship Tiers 1–2 only. Document the blocking package + version in the commit/PR.

- [ ] **Step 5: Analyze + smoke test the SDK bump alone (before pulling majors)**

```bash
flutter analyze
flutter test test/core test/features/dive_log
```
Expected: clean. New analyzer/lints may surface new warnings — fix them now so Tier 3b's diff stays about dependencies, not lints.

- [ ] **Step 6: Commit the SDK upgrade on its own**

```bash
dart format .
git add pubspec.yaml pubspec.lock
git commit -m "chore(toolchain): upgrade Flutter/Dart SDK to <version>"
```

---

## Task 4: Tier 3b — the SDK-gated major upgrades

**Files:**
- Modify: `pubspec.yaml`, `pubspec.lock`
- Modify: app code + regenerated Drift schema at call sites flagged by the analyzer

**Interfaces:**
- Consumes: the raised analyzer ceiling from Task 3.
- Produces: `drift`/`drift_dev` → 2.34.x, `xml` → 7.x, `share_plus` → 13.x, `package_info_plus` → 10.x, `archive`/`win32`/`objectbox` advanced transitively. Each migrated and verified.

> **Order matters: do these one package (or one tight cluster) at a time**, analyzing and testing between each, so a break is attributable. Drift first (highest blast radius), then the rest.

- [ ] **Step 1: Drift 2.31 → 2.34 — find call sites**

```bash
grep -rln "package:drift" lib/ packages/
grep -rn "import 'package:drift" lib/core/database/
```
Expected: the database layer files. Drift minor bumps can change generated APIs and add lints.

- [ ] **Step 2: Bump Drift, regenerate, analyze**

```bash
flutter pub upgrade --major-versions drift drift_dev
dart run build_runner build --delete-conflicting-outputs
flutter analyze
```
Expected: regeneration succeeds; analyzer flags any changed generated API. Review the `pubspec.lock` for `sqlparser`/`sqlite3` advancing too. Fix flagged call sites per the Drift 2.32–2.34 changelog. Confirm no schema-version change was introduced (the `schemaVersion` in `database.dart` must be unchanged unless intentionally migrating).

- [ ] **Step 3: Drift verification — database tests are non-negotiable**

```bash
flutter test test/core/database
flutter test test/features/dive_log/data
```
Expected: pass. Drift is the riskiest bump; a green DB test layer is the gate.

- [ ] **Step 4: Commit Drift independently**

```bash
dart format .
git add pubspec.yaml pubspec.lock
git commit -m "chore(deps): upgrade drift 2.34 + regenerate schema"
```

- [ ] **Step 5: Remaining majors — xml, share_plus, package_info_plus to latest**

```bash
grep -rn "package:xml\|XmlDocument\|XmlBuilder" lib/    # UDDF import/export uses xml heavily
grep -rn "Share\.\|SharePlus\|share_plus" lib/
flutter pub upgrade --major-versions xml share_plus package_info_plus
dart run build_runner build --delete-conflicting-outputs
flutter analyze
```
Expected: analyzer flags `xml` 6→7 API changes (the UDDF parser is the main consumer — `dive_import` feature) and `share_plus` 12→13 (the `Share.share` → `SharePlus.instance.share(ShareParams(...))` migration). Fix each per changelog.

- [ ] **Step 6: Targeted tests for xml/share consumers**

```bash
flutter test test/features/dive_import        # UDDF (xml) round-trip
flutter test test/features/universal_import
```
Expected: pass. UDDF import/export is the xml canary.

- [ ] **Step 7: Cross-platform build sweep (these touch Windows/iOS plugins)**

```bash
flutter build ios --no-codesign --simulator
flutter build macos
```
Expected: both succeed. (`win32`/`archive`/`objectbox` advanced transitively — Windows is covered by CI; flag in the PR that Windows + Android need CI/hardware confirmation.)

- [ ] **Step 8: Commit the remaining majors**

```bash
dart format .
git add pubspec.yaml pubspec.lock
git commit -m "chore(deps): upgrade xml 7, share_plus 13, package_info_plus 10"
```

---

## Task 5: Tier 4 — re-evaluate the four overrides

**Files:**
- Modify: `pubspec.yaml` `dependency_overrides` (only those whose guard has cleared)

**Interfaces:**
- Consumes: the upgraded SDK + Xcode environment.
- Produces: overrides removed or bumped *only where re-verified safe*; the rest stay with their comments intact.

> Each override is a load-bearing pin with a documented reason. Removing one without re-checking its guard re-introduces the exact failure the comment warns about. Evaluate one at a time.

- [ ] **Step 1: `device_info_plus` — gated on Xcode SDK**

```bash
xcodebuild -version
```
Expected: if Xcode now ships an SDK that defines `NSProcessInfo.isiOSAppOnVision` (Xcode 16.4+/26), the pin can be removed:
```bash
# only if Xcode SDK supports it:
# remove the device_info_plus override block from pubspec.yaml, then:
flutter pub get && flutter build ios --no-codesign --simulator
```
Expected: iOS build still succeeds. If Xcode is unchanged, LEAVE the pin and its comment — do not touch.

- [ ] **Step 2: `permission_handler_apple` — gated on upstream #1450**

```bash
# check whether 9.4.10 fixed CNAuthorizationStatusLimited before changing:
flutter pub deps | grep permission_handler_apple
```
Expected: consult Baseflow issue #1450 / the 9.4.6–9.4.10 changelog. If fixed, bump the override to `9.4.10` and `flutter build ios --no-codesign --simulator` to confirm no compile error. If unverified, LEAVE pinned.

- [ ] **Step 3: `csv` / `logger` — gated on `fit_tool`**

```bash
flutter pub deps | grep -A2 fit_tool
```
Expected: `fit_tool` still unmaintained and still constrains csv/logger → LEAVE both overrides (their comments already document this is intentional). Only revisit if `fit_tool` is replaced.

- [ ] **Step 4: `auto_updater_windows` — vendored**

Expected: no action. It is a local `path:` package with a threading fix; there is no upstream to move to. LEAVE.

- [ ] **Step 5: Verify + commit any override change**

If any override changed:
```bash
dart run build_runner build --delete-conflicting-outputs
flutter analyze
dart format .
git add pubspec.yaml pubspec.lock
git commit -m "chore(deps): retire device_info_plus override (Xcode SDK now supports isiOSAppOnVision)"
```
If nothing changed, skip the commit and note in the PR that all four overrides remain intentionally pinned.

---

## Task 6: Tier 5 — Dependabot reconciliation + final verification

**Files:**
- Modify: none (verification + PR)

**Interfaces:**
- Consumes: all prior tiers.
- Produces: a confirmation of which of GitHub's 22 Dependabot alerts the upgrade resolved, and a fully-green PR.

- [ ] **Step 1: List Dependabot alerts and map to upgrades**

```bash
gh api repos/submersion-app/submersion/dependabot/alerts --jq '.[] | select(.state=="open") | {pkg: .dependency.package.name, severity: .security_advisory.severity, vuln_range: .security_vulnerability.vulnerable_version_range, fixed: .security_vulnerability.first_patched_version.identifier}' 2>/dev/null | head -40
```
Expected: the open alerts (10 high / 8 moderate / 4 low). Cross-reference each `pkg` against `pubspec.lock` — note which are now patched by Tiers 1–4 and which remain (likely transitive deps still SDK-gated). Record the residual set in the PR body.

- [ ] **Step 2: Full local verification gate**

```bash
dart run build_runner build --delete-conflicting-outputs
flutter analyze
dart format --set-exit-if-changed .
```
Expected: codegen succeeds, `No issues found!`, formatting clean (exit 0).

- [ ] **Step 3: Run the full suite once locally (or rely on pre-push hook)**

Run: `flutter test`
Expected: all green. (If this times out locally, push and let CI's sharded suite + the pre-push hook run it — that is the authoritative gate.)

- [ ] **Step 4: Final multi-platform build confirmation**

```bash
flutter build macos
flutter build ios --no-codesign --simulator
flutter build apk --debug
```
Expected: all succeed. Linux/Windows are confirmed by CI.

- [ ] **Step 5: Push and open the PR**

```bash
git push -u origin chore/dependency-upgrade-sweep
gh pr create --title "chore(deps): staged dependency upgrade sweep" --body "<summary of tiers shipped, overrides left pinned + why, Dependabot alerts resolved vs residual, platforms verified locally vs deferred to CI>"
```
Expected: PR opens; CI runs the full matrix. Address any CI-only breakage (Windows/Linux/Android) on the branch.

---

## Self-Review

**Spec coverage:** Every "available" upgrade from the `flutter run` warning maps to a tier: within-constraint → Task 1; constraint-loosening (`Upgradable<Resolvable`) → Task 2; SDK-gated (`Resolvable<Latest`: analyzer, drift, xml, share_plus, package_info_plus, archive, win32, objectbox) → Tasks 3–4; the four overrides → Task 5; security alerts → Task 6. Transitive deps are covered implicitly (they ride their parents). No requirement is unmapped.

**Known unknowns (honest, not placeholders):** the exact code edits for `xml` 7, `share_plus` 13, `drift` 2.34, `flutter_local_notifications` 22, and `package_info_plus` 9/10 cannot be pre-written because major-version breakage is discovered at `flutter analyze` time. Each task therefore (a) greps the precise call sites first so the blast radius is known, (b) names the API areas the changelog flags, and (c) gates on analyze + targeted tests + a build. This is the correct shape for a migration plan — the discovery command is the deliverable, not invented code.

**Hard stop:** Task 3 Step 4 is the gate — if `drift_dev`/`riverpod_generator` don't support the new analyzer, Tier 3 is abandoned (`flutter downgrade`) and Tiers 1–2 ship alone. This prevents a half-migrated, non-compiling toolchain.

**Type/name consistency:** branch name `chore/dependency-upgrade-sweep` and worktree `dep-upgrade` are used consistently across Tasks 0 and 6. Verification commands (`build_runner build --delete-conflicting-outputs`, whole-project `flutter analyze`, `dart format .`) match the Global Constraints verbatim.
