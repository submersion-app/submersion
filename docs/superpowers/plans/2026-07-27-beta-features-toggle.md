# Enable Beta Features Toggle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A visible "Enable beta features" switch in Settings → About that gates
beta UI surfaces device-locally, with reef data (PR #728) as the first gated
feature.

**Architecture:** A `StateNotifier<bool>` seeded synchronously from
SharedPreferences (key `beta_features_enabled`, default false), modeled on the
existing `DebugModeNotifier`. Gating follows the `feature_flags.dart` policy:
UI surfaces only; services, providers, and schema stay intact. Phase 1 is an
infrastructure PR from `worktree-beta-features-toggle` to main; Phase 2 adds
two guards on the reef branch after Phase 1 merges.

**Tech Stack:** Flutter, Riverpod (StateNotifier via the
`core/providers/provider.dart` barrel), SharedPreferences, gen_l10n.

**Spec:** `docs/superpowers/specs/2026-07-27-beta-features-toggle-design.md`

## Global Constraints

- SharedPreferences key is exactly `beta_features_enabled`; default `false`.
- No Drift schema change, no sync or backup participation, in either phase.
- English copy, verbatim: header "Beta"; switch title "Enable beta features";
  switch subtitle "Try features still in development. They may change or have
  rough edges."
- All user-visible strings are localized in `app_en.arb` plus all 10
  non-English locales (ar, de, es, fr, he, hu, it, nl, pt, zh), then
  regenerated with `flutter gen-l10n`.
- Run `dart format .` before every commit; all code must pass with no changes.
- `flutter analyze` must be run on the whole project with NO pipe filtering
  (`| tail`, `| grep` mask failures); infos are CI-fatal.
- No emojis anywhere. No Claude attribution or session links in commits or PR
  descriptions.
- Pre-push hook trap: pushes that add NEW test files can abort silently with
  exit 1. Run the full suite manually first, then push with
  `SKIP_TESTS=1 git push` if the hook dies without output.

---

## Phase 1 — Infrastructure PR (branch `worktree-beta-features-toggle`, this worktree)

### Task 1: BetaFeaturesNotifier and provider

**Files:**
- Create: `lib/features/settings/presentation/providers/beta_features_provider.dart`
- Test: `test/features/settings/presentation/providers/beta_features_provider_test.dart`

**Interfaces:**
- Consumes: `sharedPreferencesProvider` from
  `lib/features/settings/presentation/providers/settings_providers.dart`.
- Produces: `class BetaFeaturesNotifier extends StateNotifier<bool>` with
  constructor `BetaFeaturesNotifier(SharedPreferences prefs)` and method
  `Future<void> setEnabled(bool value)`; provider
  `betaFeaturesEnabledProvider` of type
  `StateNotifierProvider<BetaFeaturesNotifier, bool>`. Tasks 2, 4, and 5
  watch this provider.

- [ ] **Step 1: Write the failing test**

Create `test/features/settings/presentation/providers/beta_features_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/settings/presentation/providers/beta_features_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('BetaFeaturesNotifier', () {
    test('initial state is false when no preference stored', () {
      final notifier = BetaFeaturesNotifier(prefs);
      expect(notifier.state, isFalse);
    });

    test('initial state reads true from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({'beta_features_enabled': true});
      prefs = await SharedPreferences.getInstance();
      final notifier = BetaFeaturesNotifier(prefs);
      expect(notifier.state, isTrue);
    });

    test('setEnabled(true) updates state and persists', () async {
      final notifier = BetaFeaturesNotifier(prefs);
      await notifier.setEnabled(true);
      expect(notifier.state, isTrue);
      expect(prefs.getBool('beta_features_enabled'), isTrue);
    });

    test('setEnabled(false) updates state and persists', () async {
      final notifier = BetaFeaturesNotifier(prefs);
      await notifier.setEnabled(true);
      await notifier.setEnabled(false);
      expect(notifier.state, isFalse);
      expect(prefs.getBool('beta_features_enabled'), isFalse);
    });

    test('persists across notifier instances', () async {
      final first = BetaFeaturesNotifier(prefs);
      await first.setEnabled(true);
      final second = BetaFeaturesNotifier(prefs);
      expect(second.state, isTrue);
    });
  });

  group('betaFeaturesEnabledProvider', () {
    ProviderContainer makeContainer() {
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('reads false by default', () {
      expect(makeContainer().read(betaFeaturesEnabledProvider), isFalse);
    });

    test('setEnabled updates provider state', () async {
      final container = makeContainer();
      await container
          .read(betaFeaturesEnabledProvider.notifier)
          .setEnabled(true);
      expect(container.read(betaFeaturesEnabledProvider), isTrue);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/settings/presentation/providers/beta_features_provider_test.dart`
Expected: FAIL — compile error, `beta_features_provider.dart` does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/features/settings/presentation/providers/beta_features_provider.dart`:

```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

const _kBetaFeaturesKey = 'beta_features_enabled';

/// Notifier for the "Enable beta features" toggle.
///
/// Device-local by design: persisted to SharedPreferences so the choice
/// survives restarts but never syncs to other devices. Beta gating hides
/// UI surfaces only (see lib/core/constants/feature_flags.dart for the
/// policy); services, providers, and schema stay intact.
class BetaFeaturesNotifier extends StateNotifier<bool> {
  final SharedPreferences _prefs;

  BetaFeaturesNotifier(this._prefs)
    : super(_prefs.getBool(_kBetaFeaturesKey) ?? false);

  Future<void> setEnabled(bool value) async {
    state = value;
    await _prefs.setBool(_kBetaFeaturesKey, value);
  }
}

/// Whether beta features are enabled on this device.
final betaFeaturesEnabledProvider =
    StateNotifierProvider<BetaFeaturesNotifier, bool>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return BetaFeaturesNotifier(prefs);
    });
```

Note: `StateNotifier` comes from the `core/providers/provider.dart` barrel —
that is where it lives under Riverpod 3 in this repo. Do not import
`package:riverpod/legacy.dart` directly.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/settings/presentation/providers/beta_features_provider_test.dart`
Expected: PASS, 7 tests.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/settings/presentation/providers/beta_features_provider.dart \
        test/features/settings/presentation/providers/beta_features_provider_test.dart
git commit -m "feat(settings): add the device-local beta features provider"
```

### Task 2: Localized strings and the About-section switch

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` and the 10 non-English arb files in
  `lib/l10n/arb/` (ar, de, es, fr, he, hu, it, nl, pt, zh)
- Modify: `lib/features/settings/presentation/pages/settings_page.dart`
  (`_AboutSectionContentState.build`, after the About card at ~line 2735,
  before the `UpdateChannelConfig.isAutoUpdateEnabled` block)
- Test: `test/features/settings/presentation/pages/settings_page_test.dart`
  (new group at the end of `main`)

**Interfaces:**
- Consumes: `betaFeaturesEnabledProvider` and `BetaFeaturesNotifier.setEnabled`
  from Task 1; `context.l10n` extension already imported by
  `settings_page.dart`; the test file's existing `getOverrides()` helper and
  `prefs` variable.
- Produces: l10n getters `settings_beta_header`, `settings_beta_enableTitle`,
  `settings_beta_enableSubtitle` on `AppLocalizations`.

- [ ] **Step 1: Add the arb entries**

Entries are plain strings with no `@`-metadata (metadata is only for keys with
placeholders). Insert each in alphabetical key order — `settings_beta_*`
sorts immediately after the `settings_about_*` block in every file.

`app_en.arb`:
```json
  "settings_beta_enableSubtitle": "Try features still in development. They may change or have rough edges.",
  "settings_beta_enableTitle": "Enable beta features",
  "settings_beta_header": "Beta",
```

`app_ar.arb`:
```json
  "settings_beta_enableSubtitle": "جرّب ميزات لا تزال قيد التطوير. قد تتغير أو تحتوي على عيوب.",
  "settings_beta_enableTitle": "تفعيل الميزات التجريبية",
  "settings_beta_header": "تجريبي",
```

`app_de.arb`:
```json
  "settings_beta_enableSubtitle": "Testen Sie Funktionen, die sich noch in der Entwicklung befinden. Sie können sich ändern oder unausgereift sein.",
  "settings_beta_enableTitle": "Beta-Funktionen aktivieren",
  "settings_beta_header": "Beta",
```

`app_es.arb`:
```json
  "settings_beta_enableSubtitle": "Prueba funciones aún en desarrollo. Pueden cambiar o tener fallos.",
  "settings_beta_enableTitle": "Activar funciones beta",
  "settings_beta_header": "Beta",
```

`app_fr.arb`:
```json
  "settings_beta_enableSubtitle": "Essayez des fonctionnalités encore en développement. Elles peuvent changer ou présenter des défauts.",
  "settings_beta_enableTitle": "Activer les fonctionnalités bêta",
  "settings_beta_header": "Bêta",
```

`app_he.arb`:
```json
  "settings_beta_enableSubtitle": "נסו תכונות שעדיין בפיתוח. הן עשויות להשתנות או להכיל ליקויים.",
  "settings_beta_enableTitle": "הפעלת תכונות בטא",
  "settings_beta_header": "בטא",
```

`app_hu.arb`:
```json
  "settings_beta_enableSubtitle": "Próbáljon ki fejlesztés alatt álló funkciókat. Ezek változhatnak, és lehetnek hibáik.",
  "settings_beta_enableTitle": "Béta funkciók engedélyezése",
  "settings_beta_header": "Béta",
```

`app_it.arb`:
```json
  "settings_beta_enableSubtitle": "Prova funzionalità ancora in sviluppo. Potrebbero cambiare o presentare imperfezioni.",
  "settings_beta_enableTitle": "Attiva le funzionalità beta",
  "settings_beta_header": "Beta",
```

`app_nl.arb`:
```json
  "settings_beta_enableSubtitle": "Probeer functies die nog in ontwikkeling zijn. Ze kunnen veranderen of ruwe randjes hebben.",
  "settings_beta_enableTitle": "Bètafuncties inschakelen",
  "settings_beta_header": "Bèta",
```

`app_pt.arb`:
```json
  "settings_beta_enableSubtitle": "Experimente funcionalidades ainda em desenvolvimento. Podem mudar ou ter falhas.",
  "settings_beta_enableTitle": "Ativar funcionalidades beta",
  "settings_beta_header": "Beta",
```

`app_zh.arb`:
```json
  "settings_beta_enableSubtitle": "试用仍在开发中的功能。它们可能会更改或存在不完善之处。",
  "settings_beta_enableTitle": "启用测试版功能",
  "settings_beta_header": "测试版",
```

- [ ] **Step 2: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: exits 0; `lib/l10n/arb/app_localizations*.dart` gain the three
getters. Verify: `grep -c settings_beta_header lib/l10n/arb/app_localizations_*.dart`
shows a hit in every locale file.

- [ ] **Step 3: Write the failing widget test**

Append this group at the end of `main` in
`test/features/settings/presentation/pages/settings_page_test.dart`. It uses
the same GoRouter `?selected=<section>` technique as the existing
"AppearanceSectionContent navigation" group, and the file's existing
`getOverrides()` and `prefs`:

```dart
  group('About section beta features toggle', () {
    Widget buildAboutWidget(List<Override> overrides) {
      final router = GoRouter(
        initialLocation: '/settings?selected=about',
        routes: [
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsPage(),
          ),
        ],
      );

      return ProviderScope(
        overrides: overrides,
        child: MaterialApp.router(
          locale: const Locale('en'),
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );
    }

    testWidgets('renders the switch off by default and toggles it on', (
      tester,
    ) async {
      await tester.pumpWidget(buildAboutWidget(getOverrides()));
      await tester.pumpAndSettle();

      final switchFinder = find.widgetWithText(
        SwitchListTile,
        'Enable beta features',
      );
      await tester.scrollUntilVisible(switchFinder, 100);
      expect(tester.widget<SwitchListTile>(switchFinder).value, isFalse);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(tester.widget<SwitchListTile>(switchFinder).value, isTrue);
      expect(prefs.getBool('beta_features_enabled'), isTrue);
    });
  });
```

If `GoRouter`, `GoRoute`, or `SwitchListTile` are unresolved, add the missing
imports (`package:go_router/go_router.dart`, `package:flutter/material.dart`)
— check the file head first; the appearance group already uses GoRouter, so
they are almost certainly present.

The About content watches `packageInfoProvider`, whose platform call fails in
widget tests; the page handles that with an empty-string error branch, so no
PackageInfo mock is needed. If `pumpAndSettle` ever times out here, override
`packageInfoProvider` with a completed value instead of adding a mock channel.

- [ ] **Step 4: Run the test to verify it fails**

Run: `flutter test test/features/settings/presentation/pages/settings_page_test.dart`
Expected: the new test FAILS (switch not found via `scrollUntilVisible`);
all pre-existing tests in the file still pass.

- [ ] **Step 5: Add the switch to the About section**

In `lib/features/settings/presentation/pages/settings_page.dart`, add the
import (alphabetical among the existing local imports):

```dart
import 'package:submersion/features/settings/presentation/providers/beta_features_provider.dart';
```

In `_AboutSectionContentState.build`, immediately after the closing `),` of
the first `Card` (the one ending with the "Report issue" `ListTile`, ~line
2735) and before the `// Auto-update section (only for non-store builds)`
comment, insert:

```dart
          const SizedBox(height: 24),
          _buildSectionHeader(context, context.l10n.settings_beta_header),
          const SizedBox(height: 8),
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.science_outlined),
              title: Text(context.l10n.settings_beta_enableTitle),
              subtitle: Text(context.l10n.settings_beta_enableSubtitle),
              value: ref.watch(betaFeaturesEnabledProvider),
              onChanged: (value) => ref
                  .read(betaFeaturesEnabledProvider.notifier)
                  .setEnabled(value),
            ),
          ),
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `flutter test test/features/settings/presentation/pages/settings_page_test.dart`
Expected: PASS, including the new test.

- [ ] **Step 7: Run the settings feature tests**

Run: `flutter test test/features/settings/`
Expected: PASS. (The new `ref.watch` in the About content is covered by
`getOverrides()`, which already overrides `sharedPreferencesProvider` — but
verify nothing else in the feature regressed.)

- [ ] **Step 8: Format and commit**

```bash
dart format .
git add lib/l10n/arb/ lib/features/settings/presentation/pages/settings_page.dart \
        test/features/settings/presentation/pages/settings_page_test.dart
git commit -m "feat(settings): add the Enable beta features switch to About"
```

### Task 3: Whole-project verification and PR

**Files:** none new — verification only.

- [ ] **Step 1: Format check**

Run: `dart format --set-exit-if-changed .`
Expected: exit 0. If not, commit the formatting as part of the offending task's follow-up.

- [ ] **Step 2: Analyze (no pipe filtering)**

Run: `flutter analyze`
Expected: "No issues found!". Infos are CI-fatal — fix any.

- [ ] **Step 3: Full test suite**

Run: `flutter test`
Expected: all tests pass (baseline was 14,170 passing). Known flaky suites
(backup, media upload drain) may need a single retry of just their file
before concluding a regression.

- [ ] **Step 4: Confirm with the user, then push and open the PR**

Pushing is not preauthorized — confirm first. Then:

```bash
git push -u origin worktree-beta-features-toggle
```

If the pre-push hook aborts silently (new test file trap), rerun as
`SKIP_TESTS=1 git push -u origin worktree-beta-features-toggle` (the suite
already passed in Step 3).

Open the PR against main titled "Add an Enable Beta Features toggle" with a
summary of: device-local switch in Settings → About, `DebugModeNotifier`-style
provider, UI-surface-only gating policy, reef data (#728) to adopt it in a
follow-up. No attribution lines, no session links.

---

## Phase 2 — Gate reef data (branch `worktree-reef-data`, AFTER Phase 1 merges to main)

Execute in the reef worktree, not this one. Precondition: Phase 1 merged to
main.

### Task 4: Merge main and guard the site detail page

**Files:**
- Modify: `lib/features/dive_sites/presentation/pages/site_detail_page.dart`
  (~line 200, the `// Reef Section` block)
- Test: `test/features/dive_sites/presentation/pages/site_detail_page_test.dart`
  (create the file if the reef branch has no site-detail test; follow the
  provider-override pattern of `test/features/settings/presentation/pages/settings_page_test.dart`)

**Interfaces:**
- Consumes: `betaFeaturesEnabledProvider` from Phase 1;
  `BetaFeaturesNotifier(SharedPreferences prefs)` for test overrides.
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Merge main**

```bash
git merge origin/main
```

Resolve conflicts if any; then regenerate stale codegen (branch switch trap):

```bash
dart run build_runner build --delete-conflicting-outputs
```

Run: `flutter test test/features/reef/` — expected PASS before any gating change.

- [ ] **Step 2: Add the guard**

In `site_detail_page.dart`, change:

```dart
          // Reef Section (only if site has coordinates)
          if (site.hasCoordinates) ...[
            ReefSection(location: site.location!),
            const SizedBox(height: 16),
          ],
```

to:

```dart
          // Reef Section (beta; only if site has coordinates)
          if (ref.watch(betaFeaturesEnabledProvider) &&
              site.hasCoordinates) ...[
            ReefSection(location: site.location!),
            const SizedBox(height: 16),
          ],
```

Add the import:

```dart
import 'package:submersion/features/settings/presentation/providers/beta_features_provider.dart';
```

- [ ] **Step 3: Write the visibility tests**

In the site detail test file, add two cases: pump the page with
`SharedPreferences.setMockInitialValues({'beta_features_enabled': true})` and
`sharedPreferencesProvider` overridden, assert `find.byType(ReefSection)`
finds one widget for a site with coordinates; repeat with `{}` (flag absent)
and assert `findsNothing`. Mock reef providers the same way the reef branch's
`test/features/reef/presentation/widgets/reef_section_test.dart` does, so no
network is touched.

- [ ] **Step 4: Run, fix, format, commit**

Run: `flutter test test/features/dive_sites/ test/features/reef/`
Expected: PASS. Any pre-existing site-detail test that asserted reef presence
now needs the flag seeded true in its setup.

```bash
dart format .
git add -u && git add test/features/dive_sites/
git commit -m "feat(reef): gate the site reef section behind beta features"
```

### Task 5: Guard the dive detail reef section

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart`
  (the `DiveDetailSectionId.reefHealth` entry in the section builder map,
  ~line 368)
- Test: the dive detail page test file on the reef branch covering section
  visibility, plus `test/core/constants/dive_detail_sections_test.dart`

**Interfaces:**
- Consumes: `betaFeaturesEnabledProvider` from Phase 1.
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Add the guard**

Change:

```dart
      DiveDetailSectionId.reefHealth: () {
        return [_buildReefHealthSection(context, ref, dive)];
      },
```

to (the empty-list return matches the existing conditional-section pattern in
this map, e.g. `surfaceGps`):

```dart
      DiveDetailSectionId.reefHealth: () {
        if (!ref.watch(betaFeaturesEnabledProvider)) return [];
        return [_buildReefHealthSection(context, ref, dive)];
      },
```

Add the same `beta_features_provider.dart` import as Task 4.

- [ ] **Step 2: Write the visibility tests**

Same pattern as Task 4 Step 3: flag on → the reef health section renders on a
dive detail page; flag off → absent. Follow the reef branch's existing dive
detail test setup for providers and fixtures.

- [ ] **Step 3: Verify the section-count tests**

Run: `flutter test test/core/constants/dive_detail_sections_test.dart`
Expected: PASS unchanged — the `DiveDetailSectionId` enum is untouched; only
rendering is conditional. If a count assertion fails, the test is asserting
rendered sections rather than enum members: seed the flag true in that test's
setup rather than changing the expected count.

- [ ] **Step 4: Run the full suite, format, commit**

Run: `flutter test`
Expected: PASS. The full suite is required here — the new provider dependency
in two heavily-tested pages is exactly the class of change `flutter analyze`
cannot catch.

```bash
dart format .
git add -u && git add test/
git commit -m "feat(reef): gate the dive reef health section behind beta features"
```

- [ ] **Step 5: Confirm with the user, then push to update PR #728**

```bash
git push
```

(Same silent-abort caveat as Task 3 Step 4.)
