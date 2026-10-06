# Customizable Home Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users hide/show and reorder the home screen cards via a new Cards section on Settings > Appearance > Home, persisted per-device.

**Architecture:** A `HomeCardType` enum (11 cards) plus a pure reconciliation function define the user's effective card order; a pure layout pass packs ordered visible cards into the existing `DashboardEntry` grid blocks. Persistence mirrors the existing `hiddenHomeChips` / `fullscreenTileOrder` device-local SharedPreferences pattern. The urgent banner is pinned above all customizable content.

**Tech Stack:** Flutter 3.x, Riverpod (StateNotifier), SharedPreferences, go_router, flutter gen-l10n.

**Spec:** `docs/superpowers/specs/2026-08-07-customizable-home-screen-design.md`

## Global Constraints

- Per-device persistence only: SharedPreferences, NO database schema change.
- Urgent banner is not customizable; when triggered it renders above all customizable content.
- Default order must reproduce today's dashboard layout exactly.
- All Dart code passes `dart format` with no changes (run `dart format lib/ test/` before every commit).
- `flutter analyze` on the WHOLE project must be clean — infos are CI-fatal; never pipe analyze output through `tail`/`head`.
- New l10n keys go in ALL 11 ARB files (`lib/l10n/arb/app_{ar,de,en,es,fr,he,hu,it,nl,pt,zh}.arb`) with real translations, then run `flutter gen-l10n`.
- No emojis in code or docs; immutability always; no `console.log`-style debug output.
- Worktree note: branch from **local** `main` (not `origin/main`) so the spec/plan commits are included. After creating the worktree run `git submodule update --init --recursive` and `flutter pub get`.

---

### Task 1: `HomeCardType` enum and order reconciliation

**Files:**
- Create: `lib/features/dashboard/presentation/home_cards.dart`
- Test: `test/features/dashboard/presentation/home_cards_test.dart`

**Interfaces:**
- Consumes: nothing (pure Dart, no imports beyond nothing/`flutter/foundation` not needed).
- Produces: `enum HomeCardType { hero, gaugeStrip, preDive, recentDives, quickActions, milestones, photoRibbon, onThisDay, yearInReview, activeCourses, recentSitesMap }` (declaration order IS the default display order) and `List<HomeCardType> reconcileHomeCardOrder(List<String> stored)`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/dashboard/presentation/home_cards_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dashboard/presentation/home_cards.dart';

void main() {
  group('reconcileHomeCardOrder', () {
    test('empty stored list returns the default order', () {
      expect(reconcileHomeCardOrder(const []), HomeCardType.values);
    });

    test('complete stored list is returned as stored', () {
      final reversed = HomeCardType.values.reversed.toList();
      expect(
        reconcileHomeCardOrder([for (final c in reversed) c.name]),
        reversed,
      );
    });

    test('unknown names are dropped', () {
      final stored = [
        'notACard',
        for (final c in HomeCardType.values) c.name,
        'alsoNotACard',
      ];
      expect(reconcileHomeCardOrder(stored), HomeCardType.values);
    });

    test('duplicate names keep the first occurrence', () {
      final stored = [
        for (final c in HomeCardType.values) c.name,
        HomeCardType.hero.name,
      ];
      expect(reconcileHomeCardOrder(stored), HomeCardType.values);
    });

    test(
      'missing card is inserted after its closest preceding default '
      'neighbor present in the stored order',
      () {
        // Default order: ..., recentDives, quickActions, milestones, ...
        // Store everything except quickActions, with milestones moved first.
        final stored = [
          HomeCardType.milestones.name,
          for (final c in HomeCardType.values)
            if (c != HomeCardType.quickActions && c != HomeCardType.milestones)
              c.name,
        ];
        final result = reconcileHomeCardOrder(stored);
        // quickActions' closest preceding default neighbor is recentDives,
        // so it lands immediately after recentDives (NOT after milestones,
        // which the user moved away).
        final recentDivesIndex = result.indexOf(HomeCardType.recentDives);
        expect(result[recentDivesIndex + 1], HomeCardType.quickActions);
        expect(result.toSet(), HomeCardType.values.toSet());
      },
    );

    test('missing card with no preceding neighbor present goes to the front',
        () {
      // Store only the LAST default card; hero (default index 0) has no
      // preceding neighbor, so it is inserted at the front.
      final stored = [HomeCardType.recentSitesMap.name];
      final result = reconcileHomeCardOrder(stored);
      expect(result.first, HomeCardType.hero);
      expect(result.toSet(), HomeCardType.values.toSet());
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/dashboard/presentation/home_cards_test.dart`
Expected: FAIL — `home_cards.dart` does not exist.

- [ ] **Step 3: Write the implementation**

```dart
// lib/features/dashboard/presentation/home_cards.dart

/// The customizable home screen cards. Declaration order is the default
/// display order and must match the pre-customization dashboard layout.
/// The urgent banner is deliberately absent: it is pinned and always
/// renders above all customizable content when triggered.
enum HomeCardType {
  hero,
  gaugeStrip,
  preDive,
  recentDives,
  quickActions,
  milestones,
  photoRibbon,
  onThisDay,
  yearInReview,
  activeCourses,
  recentSitesMap,
}

/// Turns a stored order (HomeCardType.name strings from SharedPreferences)
/// into the effective card order:
/// - unknown names are dropped (card removed in a later app version),
/// - duplicates keep the first occurrence,
/// - missing types (card added in a later app version) are inserted
///   immediately after their closest preceding default-order neighbor
///   present in the result, or at the front if none is.
List<HomeCardType> reconcileHomeCardOrder(List<String> stored) {
  final byName = {for (final c in HomeCardType.values) c.name: c};
  final seen = <HomeCardType>{};
  final result = <HomeCardType>[
    for (final name in stored)
      if (byName[name] != null && seen.add(byName[name]!)) byName[name]!,
  ];
  for (var i = 0; i < HomeCardType.values.length; i++) {
    final card = HomeCardType.values[i];
    if (seen.contains(card)) continue;
    var insertAt = 0;
    for (var j = i - 1; j >= 0; j--) {
      final neighborIndex = result.indexOf(HomeCardType.values[j]);
      if (neighborIndex != -1) {
        insertAt = neighborIndex + 1;
        break;
      }
    }
    result.insert(insertAt, card);
    seen.add(card);
  }
  return result;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/dashboard/presentation/home_cards_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Format and commit**

```bash
dart format lib/ test/
git add lib/features/dashboard/presentation/home_cards.dart test/features/dashboard/presentation/home_cards_test.dart
git commit -m "Add HomeCardType enum and order reconciliation"
```

---

### Task 2: Settings persistence and notifier methods

**Files:**
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart`
  - `SettingsKeys` (near line 85, next to `hiddenHomeChips`)
  - `AppSettings` field declarations (near line 383), constructor defaults (near line 515), `copyWith` (params near line 667, body near line 814)
  - `_loadSettings` (both the no-diver branch near line 944 and the diver branch near line 962; prefs reads near line 919)
  - `_saveSettings` (near line 1018)
  - new setters next to `setHomeChipEnabled` (line 1241)
- Modify: `test/helpers/mock_providers.dart` (`MockSettingsNotifier`, line 29)
- Modify: every other mock flagged by `flutter analyze` (there are several local `implements SettingsNotifier` mocks in test files, e.g. `test/features/statistics/presentation/pages/records_page_test.dart`; let analyze find the full list)
- Test: `test/features/settings/presentation/providers/home_card_settings_test.dart` (create)

**Interfaces:**
- Consumes: `HomeCardType` from Task 1 (test-side only; the settings layer stores plain strings and does NOT import dashboard code).
- Produces on `AppSettings`: `final List<String> homeCardOrder;` (default `const <String>[]`, meaning "use default order") and `final Set<String> hiddenHomeCards;` (default `const <String>{}`), both in `copyWith`.
- Produces on `SettingsNotifier` (and every mock): `Future<void> setHomeCardEnabled(String cardId, bool enabled)`, `Future<void> setHomeCardOrder(List<String> order)`, `Future<void> resetHomeCards()`.
- Produces on `SettingsKeys`: `homeCardOrder = 'home_card_order'`, `hiddenHomeCards = 'hidden_home_cards'`.
- Produces on `MockSettingsNotifier`: optional seed constructor `MockSettingsNotifier([AppSettings? initial])`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/settings/presentation/providers/home_card_settings_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dashboard/presentation/home_cards.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> makeContainer() async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('defaults: empty order and no hidden cards', () async {
    SharedPreferences.setMockInitialValues({});
    final container = await makeContainer();
    final settings = container.read(settingsProvider);
    expect(settings.homeCardOrder, isEmpty);
    expect(settings.hiddenHomeCards, isEmpty);
  });

  test('setHomeCardOrder persists to SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({});
    final container = await makeContainer();
    final notifier = container.read(settingsProvider.notifier);
    final order = [for (final c in HomeCardType.values.reversed) c.name];
    await notifier.setHomeCardOrder(order);
    expect(container.read(settingsProvider).homeCardOrder, order);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(SettingsKeys.homeCardOrder), order);
  });

  test('setHomeCardEnabled(false) adds to hidden set and persists', () async {
    SharedPreferences.setMockInitialValues({});
    final container = await makeContainer();
    final notifier = container.read(settingsProvider.notifier);
    await notifier.setHomeCardEnabled(HomeCardType.photoRibbon.name, false);
    expect(
      container.read(settingsProvider).hiddenHomeCards,
      {HomeCardType.photoRibbon.name},
    );
    await notifier.setHomeCardEnabled(HomeCardType.photoRibbon.name, true);
    expect(container.read(settingsProvider).hiddenHomeCards, isEmpty);
  });

  test('stored values load on startup', () async {
    SharedPreferences.setMockInitialValues({
      SettingsKeys.homeCardOrder: [HomeCardType.recentDives.name],
      SettingsKeys.hiddenHomeCards: [HomeCardType.hero.name],
    });
    final container = await makeContainer();
    // _loadSettings runs async in the notifier constructor; pump it.
    await Future<void>.delayed(Duration.zero);
    final settings = container.read(settingsProvider);
    expect(settings.homeCardOrder, [HomeCardType.recentDives.name]);
    expect(settings.hiddenHomeCards, {HomeCardType.hero.name});
  });

  test('corrupt pref type falls back to defaults', () async {
    SharedPreferences.setMockInitialValues({
      SettingsKeys.homeCardOrder: 'not-a-list',
      SettingsKeys.hiddenHomeCards: 42,
    });
    final container = await makeContainer();
    await Future<void>.delayed(Duration.zero);
    final settings = container.read(settingsProvider);
    expect(settings.homeCardOrder, isEmpty);
    expect(settings.hiddenHomeCards, isEmpty);
  });

  test('resetHomeCards clears both prefs', () async {
    SharedPreferences.setMockInitialValues({});
    final container = await makeContainer();
    final notifier = container.read(settingsProvider.notifier);
    await notifier.setHomeCardOrder([HomeCardType.hero.name]);
    await notifier.setHomeCardEnabled(HomeCardType.hero.name, false);
    await notifier.resetHomeCards();
    final settings = container.read(settingsProvider);
    expect(settings.homeCardOrder, isEmpty);
    expect(settings.hiddenHomeCards, isEmpty);
  });
}
```

Adjust the container setup to match how `test/features/settings/presentation/providers/settings_notifier_real_test.dart` constructs a real `SettingsNotifier` (it may need extra overrides, e.g. a database or diver provider); reuse that file's helper pattern verbatim rather than inventing a new one.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/settings/presentation/providers/home_card_settings_test.dart`
Expected: FAIL — `homeCardOrder`/`hiddenHomeCards`/setters undefined.

- [ ] **Step 3: Implement settings changes**

In `SettingsKeys` (next to `hiddenHomeChips`):

```dart
  // Home card layout is device-local like the chip toggles below (stored
  // directly in SharedPreferences rather than per-diver in the DB).
  static const String homeCardOrder = 'home_card_order';
  static const String hiddenHomeCards = 'hidden_home_cards';
```

In `AppSettings`: field declarations next to `hiddenHomeChips` (line 383):

```dart
  /// Display order of home screen cards (HomeCardType.name values).
  /// Empty means the default order.
  final List<String> homeCardOrder;

  /// Home screen cards the user has toggled off (HomeCardType.name values).
  final Set<String> hiddenHomeCards;
```

Constructor defaults (next to line 515): `this.homeCardOrder = const <String>[]`, `this.hiddenHomeCards = const <String>{}`.

`copyWith`: add `List<String>? homeCardOrder` / `Set<String>? hiddenHomeCards` params and `homeCardOrder: homeCardOrder ?? this.homeCardOrder`, `hiddenHomeCards: hiddenHomeCards ?? this.hiddenHomeCards` in the body.

In `_loadSettings` (next to the `hiddenHomeChips` read at line 919):

```dart
      List<String> homeCardOrder;
      Set<String> hiddenHomeCards;
      try {
        homeCardOrder =
            prefs.getStringList(SettingsKeys.homeCardOrder) ?? const [];
        hiddenHomeCards =
            prefs.getStringList(SettingsKeys.hiddenHomeCards)?.toSet() ??
            const <String>{};
      } catch (_) {
        // Corrupt pref types must never block the dashboard; fall back to
        // the default layout.
        homeCardOrder = const [];
        hiddenHomeCards = const <String>{};
      }
```

Pass `homeCardOrder: homeCardOrder, hiddenHomeCards: hiddenHomeCards` in BOTH state assignments (the no-diver `AppSettings(...)` at ~line 944 and the `settings.copyWith(...)` at ~line 962).

In `_saveSettings` (next to the `hiddenHomeChips` write at line 1018):

```dart
    await prefs.setStringList(
      SettingsKeys.homeCardOrder,
      state.homeCardOrder,
    );
    await prefs.setStringList(
      SettingsKeys.hiddenHomeCards,
      state.hiddenHomeCards.toList()..sort(),
    );
```

New setters directly below `setHomeChipEnabled` (line 1250):

```dart
  /// Show or hide one home card (id = HomeCardType.name).
  Future<void> setHomeCardEnabled(String cardId, bool enabled) async {
    final hidden = {...state.hiddenHomeCards};
    if (enabled) {
      hidden.remove(cardId);
    } else {
      hidden.add(cardId);
    }
    state = state.copyWith(hiddenHomeCards: hidden);
    await _saveSettings();
  }

  /// Persist the home card display order (HomeCardType.name values).
  Future<void> setHomeCardOrder(List<String> order) async {
    state = state.copyWith(homeCardOrder: List.unmodifiable(order));
    await _saveSettings();
  }

  /// Restore the default home card order and visibility.
  Future<void> resetHomeCards() async {
    state = state.copyWith(
      homeCardOrder: const <String>[],
      hiddenHomeCards: const <String>{},
    );
    await _saveSettings();
  }
```

- [ ] **Step 4: Update `MockSettingsNotifier` and every other mock**

In `test/helpers/mock_providers.dart`, change the constructor to allow seeding and add the three methods:

```dart
  MockSettingsNotifier([AppSettings? initial])
      : super(initial ?? const AppSettings());

  @override
  Future<void> setHomeCardEnabled(String cardId, bool enabled) async {
    final hidden = {...state.hiddenHomeCards};
    if (enabled) {
      hidden.remove(cardId);
    } else {
      hidden.add(cardId);
    }
    state = state.copyWith(hiddenHomeCards: hidden);
  }

  @override
  Future<void> setHomeCardOrder(List<String> order) async =>
      state = state.copyWith(homeCardOrder: order);

  @override
  Future<void> resetHomeCards() async => state = state.copyWith(
        homeCardOrder: const <String>[],
        hiddenHomeCards: const <String>{},
      );
```

Then run `flutter analyze` (full project, NO piping) and add the same three methods to every other mock class it flags with "missing concrete implementation" (known offenders: local mocks in `records_page_test.dart`, `statistics_overview_page_test.dart`, gas-calculator tests, `dive_comparison_card_test.dart`, `localization_test.dart` — trust analyze, not this list). Mocks that use `noSuchMethod` need no change.

- [ ] **Step 5: Run tests and analyze**

Run: `flutter test test/features/settings/presentation/providers/home_card_settings_test.dart`
Expected: PASS.
Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 6: Format and commit**

```bash
dart format lib/ test/
git add -A lib/features/settings test/helpers test/features
git commit -m "Persist home card order and visibility in settings"
```

---

### Task 3: Layout pass

**Files:**
- Create: `lib/features/dashboard/presentation/home_layout.dart`
- Test: `test/features/dashboard/presentation/home_layout_test.dart`

**Interfaces:**
- Consumes: `HomeCardType` (Task 1); `DashboardEntry`/`FullBlock`/`ThirdBlock`/`LeadSideGroup` from `lib/features/dashboard/presentation/widgets/dashboard_grid.dart`; the card widgets listed below.
- Produces: `List<DashboardEntry> buildDashboardEntries(List<HomeCardType> visibleCards)`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/dashboard/presentation/home_layout_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dashboard/presentation/home_cards.dart';
import 'package:submersion/features/dashboard/presentation/home_layout.dart';
import 'package:submersion/features/dashboard/presentation/widgets/dashboard_grid.dart';
import 'package:submersion/features/dashboard/presentation/widgets/milestones_card.dart';
import 'package:submersion/features/dashboard/presentation/widgets/quick_actions_card.dart';
import 'package:submersion/features/dashboard/presentation/widgets/recent_dives_card.dart';

void main() {
  group('buildDashboardEntries', () {
    test('default order reproduces the legacy block structure', () {
      final entries = buildDashboardEntries(HomeCardType.values);
      // hero, gaugeStrip, preDive as FullBlocks; recentDives absorbs
      // quickActions + milestones into a LeadSideGroup; then photoRibbon
      // (Full), onThisDay/yearInReview/activeCourses (Thirds),
      // recentSitesMap (Full).
      expect(entries, hasLength(9));
      expect(entries[0], isA<FullBlock>());
      expect(entries[1], isA<FullBlock>());
      expect(entries[2], isA<FullBlock>());
      final group = entries[3] as LeadSideGroup;
      expect(group.lead, isA<RecentDivesCard>());
      expect(group.side, hasLength(2));
      expect(group.side[0], isA<QuickActionsCard>());
      expect(group.side[1], isA<MilestonesCard>());
      expect(entries[4], isA<FullBlock>());
      expect(entries[5], isA<ThirdBlock>());
      expect(entries[6], isA<ThirdBlock>());
      expect(entries[7], isA<ThirdBlock>());
      expect(entries.last, isA<FullBlock>());
    });

    test('side cards absorb only when immediately after recentDives', () {
      final entries = buildDashboardEntries(const [
        HomeCardType.quickActions,
        HomeCardType.recentDives,
        HomeCardType.milestones,
      ]);
      expect(entries, hasLength(2));
      expect(entries[0], isA<ThirdBlock>());
      final group = entries[1] as LeadSideGroup;
      expect(group.side, hasLength(1));
      expect(group.side.single, isA<MilestonesCard>());
    });

    test('recentDives with no following side cards is a FullBlock', () {
      final entries = buildDashboardEntries(const [
        HomeCardType.recentDives,
        HomeCardType.photoRibbon,
      ]);
      expect(entries[0], isA<FullBlock>());
      expect((entries[0] as FullBlock).child, isA<RecentDivesCard>());
    });

    test('side cards without recentDives render as ThirdBlocks', () {
      final entries = buildDashboardEntries(const [
        HomeCardType.quickActions,
        HomeCardType.milestones,
      ]);
      expect(entries, hasLength(2));
      expect(entries[0], isA<ThirdBlock>());
      expect(entries[1], isA<ThirdBlock>());
    });

    test('absorption caps at two side cards', () {
      // Only two side-capable types exist; a third card after them must
      // not be absorbed even if the cap logic is wrong, so instead assert
      // a non-side card directly after recentDives is never absorbed.
      final entries = buildDashboardEntries(const [
        HomeCardType.recentDives,
        HomeCardType.onThisDay,
      ]);
      expect(entries[0], isA<FullBlock>());
      expect(entries[1], isA<ThirdBlock>());
    });

    test('empty input produces no entries', () {
      expect(buildDashboardEntries(const []), isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/dashboard/presentation/home_layout_test.dart`
Expected: FAIL — `home_layout.dart` does not exist.

- [ ] **Step 3: Write the implementation**

```dart
// lib/features/dashboard/presentation/home_layout.dart
import 'package:flutter/material.dart';

import 'package:submersion/features/dashboard/presentation/home_cards.dart';
import 'package:submersion/features/dashboard/presentation/widgets/active_course_progress_card.dart';
import 'package:submersion/features/dashboard/presentation/widgets/dashboard_grid.dart';
import 'package:submersion/features/dashboard/presentation/widgets/gauge_strip.dart';
import 'package:submersion/features/dashboard/presentation/widgets/hero_header.dart';
import 'package:submersion/features/dashboard/presentation/widgets/milestones_card.dart';
import 'package:submersion/features/dashboard/presentation/widgets/on_this_day_card.dart';
import 'package:submersion/features/dashboard/presentation/widgets/photo_ribbon_card.dart';
import 'package:submersion/features/dashboard/presentation/widgets/quick_actions_card.dart';
import 'package:submersion/features/dashboard/presentation/widgets/recent_dives_card.dart';
import 'package:submersion/features/dashboard/presentation/widgets/recent_sites_map_card.dart';
import 'package:submersion/features/dashboard/presentation/widgets/year_in_review_card.dart';
import 'package:submersion/features/pre_dive/presentation/widgets/pre_dive_dashboard_card.dart';

/// Maximum side cards a LeadSideGroup absorbs (mirrors the legacy layout).
const int _maxSideCards = 2;

bool _isSideCapable(HomeCardType card) =>
    card == HomeCardType.quickActions || card == HomeCardType.milestones;

Widget _sideWidget(HomeCardType card) => switch (card) {
  HomeCardType.quickActions => const QuickActionsCard(),
  HomeCardType.milestones => const MilestonesCard(),
  _ => throw ArgumentError('not side-capable: $card'),
};

DashboardEntry _standaloneEntry(HomeCardType card) => switch (card) {
  HomeCardType.hero => const FullBlock(HeroHeader()),
  HomeCardType.gaugeStrip => const FullBlock(GaugeStrip()),
  HomeCardType.preDive => const FullBlock(PreDiveDashboardCard()),
  HomeCardType.recentDives => const FullBlock(RecentDivesCard()),
  HomeCardType.quickActions => const ThirdBlock(QuickActionsCard()),
  HomeCardType.milestones => const ThirdBlock(MilestonesCard()),
  HomeCardType.photoRibbon => const FullBlock(PhotoRibbonCard()),
  HomeCardType.onThisDay => const ThirdBlock(OnThisDayCard()),
  HomeCardType.yearInReview => const ThirdBlock(YearInReviewCard()),
  HomeCardType.activeCourses => const ThirdBlock(ActiveCourseProgressCard()),
  HomeCardType.recentSitesMap => const FullBlock(RecentSitesMapCard()),
};

/// Packs the ordered visible cards into grid entries. Side-capable cards
/// (quickActions, milestones) directly following recentDives are absorbed
/// into its LeadSideGroup side column, exactly like the legacy hardcoded
/// layout; everywhere else every card has one fixed block shape.
List<DashboardEntry> buildDashboardEntries(List<HomeCardType> visibleCards) {
  final entries = <DashboardEntry>[];
  var i = 0;
  while (i < visibleCards.length) {
    final card = visibleCards[i];
    if (card == HomeCardType.recentDives) {
      final side = <Widget>[];
      var j = i + 1;
      while (j < visibleCards.length &&
          side.length < _maxSideCards &&
          _isSideCapable(visibleCards[j])) {
        side.add(_sideWidget(visibleCards[j]));
        j++;
      }
      entries.add(
        side.isEmpty
            ? const FullBlock(RecentDivesCard())
            : LeadSideGroup(lead: const RecentDivesCard(), side: side),
      );
      i = j;
    } else {
      entries.add(_standaloneEntry(card));
      i++;
    }
  }
  return entries;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/dashboard/presentation/home_layout_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Format and commit**

```bash
dart format lib/ test/
git add lib/features/dashboard/presentation/home_layout.dart test/features/dashboard/presentation/home_layout_test.dart
git commit -m "Add pure layout pass packing home cards into grid entries"
```

---

### Task 4: l10n keys

**Files:**
- Modify: all 11 ARB files in `lib/l10n/arb/` (`app_en.arb` is the template; also ar, de, es, fr, he, hu, it, nl, pt, zh)

**Interfaces:**
- Consumes: nothing.
- Produces: `AppLocalizations` getters used by Tasks 5 and 6, exactly these key names:
  `settings_homeCards_sectionTitle`, `settings_homeCards_description`, `settings_homeCards_autoHides`, `settings_homeCards_resetToDefault`, `settings_homeCards_resetDialog_title`, `settings_homeCards_resetDialog_message`, `settings_homeCards_resetDialog_cancel`, `settings_homeCards_resetDialog_confirm`, `settings_homeCards_card_hero`, `settings_homeCards_card_gaugeStrip`, `settings_homeCards_card_preDive`, `settings_homeCards_card_recentDives`, `settings_homeCards_card_quickActions`, `settings_homeCards_card_milestones`, `settings_homeCards_card_photoRibbon`, `settings_homeCards_card_onThisDay`, `settings_homeCards_card_yearInReview`, `settings_homeCards_card_activeCourses`, `settings_homeCards_card_recentSitesMap`, `dashboard_allHidden_message`, `dashboard_allHidden_customize`.

- [ ] **Step 1: Add English values to `app_en.arb`** (next to the existing `settings_homeChips_*` block, ~line 1948)

```json
  "settings_homeCards_sectionTitle": "Home cards",
  "settings_homeCards_description": "Choose which cards appear on the Home tab and drag to reorder them.",
  "settings_homeCards_autoHides": "Hides automatically when empty",
  "settings_homeCards_resetToDefault": "Reset to default",
  "settings_homeCards_resetDialog_title": "Reset Home layout?",
  "settings_homeCards_resetDialog_message": "This restores the default card order and shows all cards again.",
  "settings_homeCards_resetDialog_cancel": "Cancel",
  "settings_homeCards_resetDialog_confirm": "Reset",
  "settings_homeCards_card_hero": "Welcome header",
  "settings_homeCards_card_gaugeStrip": "Status chips",
  "settings_homeCards_card_preDive": "Pre-dive checklist",
  "settings_homeCards_card_recentDives": "Recent dives",
  "settings_homeCards_card_quickActions": "Quick actions",
  "settings_homeCards_card_milestones": "Milestones",
  "settings_homeCards_card_photoRibbon": "Recent photos",
  "settings_homeCards_card_onThisDay": "On this day",
  "settings_homeCards_card_yearInReview": "Year in review",
  "settings_homeCards_card_activeCourses": "Course progress",
  "settings_homeCards_card_recentSitesMap": "Recent sites map",
  "dashboard_allHidden_message": "All Home cards are hidden.",
  "dashboard_allHidden_customize": "Customize Home"
```

Also update the existing `settings_homeChips_pageTitle` value from "Home status chips" to "Home screen" in ALL locales (the page now covers cards and chips; the key name stays).

- [ ] **Step 2: Translate into the other 10 locales**

Add the same keys with real translations (not English copies) to app_ar, app_de, app_es, app_fr, app_he, app_hu, app_it, app_nl, app_pt, app_zh. Match each file's existing tone and terminology (e.g. reuse each locale's existing translation of "Reset to default" from `settings_diveDetailSections_resetToDefault`, and of "Home" from existing keys).

- [ ] **Step 3: Regenerate and verify**

Run: `flutter gen-l10n`
Run: `flutter test test/l10n/localization_test.dart`
Expected: PASS (this suite enforces key parity across locales).

- [ ] **Step 4: Format and commit**

```bash
dart format lib/ test/
git add lib/l10n
git commit -m "Add home card customization l10n keys in all locales"
```

---

### Task 5: Wire DashboardPage to settings

**Files:**
- Modify: `lib/features/dashboard/presentation/pages/dashboard_page.dart`
- Modify: `test/features/dashboard/presentation/pages/dashboard_page_test.dart` (extend `pumpDashboard` and add tests)

**Interfaces:**
- Consumes: `reconcileHomeCardOrder`, `HomeCardType` (Task 1); `buildDashboardEntries` (Task 3); `settingsProvider` fields `homeCardOrder`/`hiddenHomeCards` (Task 2); l10n keys `dashboard_allHidden_message`/`dashboard_allHidden_customize` (Task 4); `MockSettingsNotifier([AppSettings? initial])` seed constructor (Task 2).
- Produces: no new public API; `DashboardPage` behavior only.

- [ ] **Step 1: Write the failing tests**

Extend `pumpDashboard` in `dashboard_page_test.dart` with an optional parameter, passing it through to the existing overrides call:

```dart
Future<void> pumpDashboard(
  WidgetTester tester, {
  MockSettingsNotifier? settingsNotifier,
  // ...existing params unchanged...
}) async {
  // ...
  final overrides = await getBaseOverrides(settingsNotifier: settingsNotifier);
  // ...rest unchanged...
}
```

Add tests (reuse the file's existing pump/override style for providers not shown here):

```dart
  testWidgets('hidden card is absent', (tester) async {
    await pumpDashboard(
      tester,
      settingsNotifier: MockSettingsNotifier(
        AppSettings(hiddenHomeCards: {HomeCardType.quickActions.name}),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(QuickActionsCard), findsNothing);
    expect(find.byType(RecentDivesCard), findsOneWidget);
  });

  testWidgets('custom order is respected', (tester) async {
    // Recent dives first, hero last.
    final order = [
      HomeCardType.recentDives.name,
      for (final c in HomeCardType.values)
        if (c != HomeCardType.recentDives && c != HomeCardType.hero) c.name,
      HomeCardType.hero.name,
    ];
    await pumpDashboard(
      tester,
      settingsNotifier: MockSettingsNotifier(
        AppSettings(homeCardOrder: order),
      ),
    );
    await tester.pumpAndSettle();
    // SingleChildScrollView lays out ALL children (it is not lazy), so both
    // widgets are measurable without scrolling and share a coordinate space.
    final recentDivesY = tester.getTopLeft(find.byType(RecentDivesCard)).dy;
    final heroY = tester.getTopLeft(find.byType(HeroHeader)).dy;
    expect(heroY, greaterThan(recentDivesY));
  });

  testWidgets('all cards hidden shows empty state with settings link',
      (tester) async {
    await pumpDashboard(
      tester,
      settingsNotifier: MockSettingsNotifier(
        AppSettings(
          hiddenHomeCards: {for (final c in HomeCardType.values) c.name},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.dashboard_allHidden_message), findsOneWidget);
    expect(find.text(l10n.dashboard_allHidden_customize), findsOneWidget);
  });

  testWidgets('renders at phone width without layout errors', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await pumpDashboard(tester);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(DashboardPage), findsOneWidget);
  });
```

Also add a test that the urgent banner sits above a reordered hero: pump with `alerts` overridden to trigger the banner (copy the file's existing urgent-banner test setup) plus `homeCardOrder` putting `hero` first, and assert `tester.getTopLeft(find.byType(UrgentBanner)).dy < tester.getTopLeft(find.byType(HeroHeader)).dy`.

The empty-state settings link needs a `/settings/appearance/home` route in the test router: add `GoRoute(path: '/settings/appearance/home', builder: (_, _) => const Scaffold())` to the `pumpDashboard` router, then in the empty-state test tap `l10n.dashboard_allHidden_customize` and assert navigation succeeded (no exception).

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/dashboard/presentation/pages/dashboard_page_test.dart`
Expected: new tests FAIL (settings are ignored; no empty state), existing tests PASS.

- [ ] **Step 3: Rewrite the entries computation in `DashboardPage.build`**

Replace the hardcoded `entries` literal (dashboard_page.dart:51-80) with:

```dart
    final homeCardOrder = ref.watch(
      settingsProvider.select((s) => s.homeCardOrder),
    );
    final hiddenHomeCards = ref.watch(
      settingsProvider.select((s) => s.hiddenHomeCards),
    );

    // Content gates: conditional cards appear only once their provider has
    // resolved to non-empty content (same rationale as before).
    bool hasContent(HomeCardType card) => switch (card) {
      HomeCardType.milestones => show(milestones, (m) => !m.isEmpty),
      HomeCardType.photoRibbon => show(photos, (p) => p.isNotEmpty),
      HomeCardType.onThisDay => show(onThisDay, (d) => d.isNotEmpty),
      HomeCardType.yearInReview => show(yearInReview, (y) => y != null),
      HomeCardType.activeCourses => show(courses, (c) => c.isNotEmpty),
      HomeCardType.recentSitesMap => show(sites, (s) => s.isNotEmpty),
      _ => true,
    };

    final visibleCards = [
      for (final card in reconcileHomeCardOrder(homeCardOrder))
        if (!hiddenHomeCards.contains(card.name) && hasContent(card)) card,
    ];

    final showUrgent = show(
      alerts,
      (a) =>
          a.serviceClocksDue.any(
            (c) => c.status.severity == ServiceClockSeverity.overdue,
          ) ||
          a.insuranceExpired,
    );

    // The urgent banner is pinned: never hideable, never reorderable,
    // always above all customizable content.
    final entries = <DashboardEntry>[
      if (showUrgent) const FullBlock(UrgentBanner()),
      ...buildDashboardEntries(visibleCards),
    ];
```

Keep the existing provider watches and `RefreshIndicator` invalidations unchanged. Replace the `DashboardGrid(entries: entries)` child with an empty-state branch:

```dart
            child: entries.isEmpty
                ? _AllCardsHiddenState()
                : DashboardGrid(entries: entries),
```

Add at the bottom of the file:

```dart
class _AllCardsHiddenState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 96),
      child: Column(
        children: [
          Text(
            l10n.dashboard_allHidden_message,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: () => context.push('/settings/appearance/home'),
            child: Text(l10n.dashboard_allHidden_customize),
          ),
        ],
      ),
    );
  }
}
```

Add the needed imports (`home_cards.dart`, `home_layout.dart`, `go_router`, `l10n_extension.dart`, `dashboard_grid.dart` already partially present); remove card-widget imports that the page no longer references directly (analyze will flag unused ones — the page still imports `urgent_banner.dart`).

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/dashboard/`
Expected: PASS, including all pre-existing dashboard tests (the default order must be pixel-compatible; if an existing test fails, the layout pass or gating logic is wrong — fix the code, not the test).

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/ test/
flutter analyze
git add lib/features/dashboard test/features/dashboard
git commit -m "Drive dashboard layout from customizable card settings"
```

---

### Task 6: Settings page Cards section

**Files:**
- Modify: `lib/features/settings/presentation/pages/home_appearance_page.dart` (full restructure)
- Test: `test/features/settings/presentation/pages/home_appearance_page_test.dart` (create or extend if it exists — check first)

**Interfaces:**
- Consumes: `HomeCardType`, `reconcileHomeCardOrder` (Task 1); notifier methods `setHomeCardEnabled`/`setHomeCardOrder`/`resetHomeCards` (Task 2); l10n keys (Task 4).
- Produces: no new public API; `HomeAppearancePage` gains the Cards section, keeps `embedded` behavior and all existing chip toggles (keys `homeChipToggle_<name>` unchanged; new tile keys `homeCardTile_<name>`, switch keys `homeCardToggle_<name>`, reset button key `homeCardsReset`).

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/settings/presentation/pages/home_appearance_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dashboard/presentation/home_cards.dart';
import 'package:submersion/features/settings/presentation/pages/home_appearance_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

Future<MockSettingsNotifier> pumpPage(WidgetTester tester,
    {AppSettings? initial}) async {
  final notifier = MockSettingsNotifier(initial);
  final overrides = await getBaseOverrides(settingsNotifier: notifier);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HomeAppearancePage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return notifier;
}

void main() {
  testWidgets('renders one tile per card type in effective order',
      (tester) async {
    await pumpPage(tester);
    for (final card in HomeCardType.values) {
      await tester.scrollUntilVisible(
        find.byKey(Key('homeCardTile_${card.name}')),
        200,
      );
      expect(find.byKey(Key('homeCardTile_${card.name}')), findsOneWidget);
    }
  });

  testWidgets('toggle off calls setHomeCardEnabled and persists in state',
      (tester) async {
    final notifier = await pumpPage(tester);
    final toggle = find.byKey(Key('homeCardToggle_${HomeCardType.hero.name}'));
    await tester.scrollUntilVisible(toggle, 200);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(notifier.state.hiddenHomeCards, {HomeCardType.hero.name});
  });

  testWidgets('hidden card row is switched off', (tester) async {
    await pumpPage(
      tester,
      initial: AppSettings(hiddenHomeCards: {HomeCardType.milestones.name}),
    );
    final toggle =
        find.byKey(Key('homeCardToggle_${HomeCardType.milestones.name}'));
    await tester.scrollUntilVisible(toggle, 200);
    expect(tester.widget<Switch>(toggle).value, isFalse);
  });

  testWidgets('reset asks for confirmation then clears customization',
      (tester) async {
    final notifier = await pumpPage(
      tester,
      initial: AppSettings(hiddenHomeCards: {HomeCardType.hero.name}),
    );
    await tester.scrollUntilVisible(find.byKey(const Key('homeCardsReset')), 200);
    await tester.tap(find.byKey(const Key('homeCardsReset')));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.settings_homeCards_resetDialog_title), findsOneWidget);
    await tester.tap(find.text(l10n.settings_homeCards_resetDialog_confirm));
    await tester.pumpAndSettle();
    expect(notifier.state.hiddenHomeCards, isEmpty);
    expect(notifier.state.homeCardOrder, isEmpty);
  });

  testWidgets('chip toggles still render below the cards section',
      (tester) async {
    await pumpPage(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('homeChipToggle_gear')),
      300,
    );
    expect(find.byKey(const Key('homeChipToggle_gear')), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/settings/presentation/pages/home_appearance_page_test.dart`
Expected: FAIL — no card tiles exist.

- [ ] **Step 3: Restructure `HomeAppearancePage`**

Replace the `ListView` body with a `CustomScrollView`. Keep `embedded` handling and the chip section content identical; the chips simply move into slivers after the cards section. Structure:

```dart
    final homeCardOrder = ref.watch(
      settingsProvider.select((s) => s.homeCardOrder),
    );
    final hiddenHomeCards = ref.watch(
      settingsProvider.select((s) => s.hiddenHomeCards),
    );
    final cards = reconcileHomeCardOrder(homeCardOrder);

    String cardName(HomeCardType type) => switch (type) {
      HomeCardType.hero => l10n.settings_homeCards_card_hero,
      HomeCardType.gaugeStrip => l10n.settings_homeCards_card_gaugeStrip,
      HomeCardType.preDive => l10n.settings_homeCards_card_preDive,
      HomeCardType.recentDives => l10n.settings_homeCards_card_recentDives,
      HomeCardType.quickActions => l10n.settings_homeCards_card_quickActions,
      HomeCardType.milestones => l10n.settings_homeCards_card_milestones,
      HomeCardType.photoRibbon => l10n.settings_homeCards_card_photoRibbon,
      HomeCardType.onThisDay => l10n.settings_homeCards_card_onThisDay,
      HomeCardType.yearInReview => l10n.settings_homeCards_card_yearInReview,
      HomeCardType.activeCourses => l10n.settings_homeCards_card_activeCourses,
      HomeCardType.recentSitesMap =>
        l10n.settings_homeCards_card_recentSitesMap,
    };

    // Conditional cards auto-hide when empty; tell the user.
    const autoHiding = {
      HomeCardType.milestones,
      HomeCardType.photoRibbon,
      HomeCardType.onThisDay,
      HomeCardType.yearInReview,
      HomeCardType.activeCourses,
      HomeCardType.recentSitesMap,
    };

    final content = CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              l10n.settings_homeCards_description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        SliverReorderableList(
          itemCount: cards.length,
          onReorder: (oldIndex, newIndex) {
            if (newIndex > oldIndex) newIndex -= 1;
            final updated = List.of(cards);
            final moved = updated.removeAt(oldIndex);
            updated.insert(newIndex, moved);
            notifier.setHomeCardOrder([for (final c in updated) c.name]);
          },
          itemBuilder: (context, index) {
            final card = cards[index];
            final visible = !hiddenHomeCards.contains(card.name);
            return AnimatedOpacity(
              key: Key('homeCardTile_${card.name}'),
              duration: const Duration(milliseconds: 200),
              opacity: visible ? 1.0 : 0.5,
              child: ListTile(
                leading: ReorderableDragStartListener(
                  index: index,
                  child: const Icon(Icons.drag_handle),
                ),
                title: Text(cardName(card)),
                subtitle: autoHiding.contains(card)
                    ? Text(l10n.settings_homeCards_autoHides)
                    : null,
                trailing: Switch(
                  key: Key('homeCardToggle_${card.name}'),
                  value: visible,
                  onChanged: (enabled) =>
                      notifier.setHomeCardEnabled(card.name, enabled),
                ),
              ),
            );
          },
        ),
        SliverToBoxAdapter(
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextButton.icon(
                key: const Key('homeCardsReset'),
                icon: const Icon(Icons.restore),
                label: Text(l10n.settings_homeCards_resetToDefault),
                onPressed: () => _confirmReset(context, notifier),
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: Divider(height: 24)),
        // Chip section: header text (the old settings_homeChips_description
        // Padding) as a SliverToBoxAdapter, then the existing chip
        // SwitchListTiles via SliverList.list(children: [...]) — reuse the
        // existing chipName() switch and homeChipToggle_ keys verbatim.
      ],
    );
```

Add the confirmation dialog as a private function in the same file:

```dart
Future<void> _confirmReset(
  BuildContext context,
  SettingsNotifier notifier,
) async {
  final l10n = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.settings_homeCards_resetDialog_title),
      content: Text(l10n.settings_homeCards_resetDialog_message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.settings_homeCards_resetDialog_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.settings_homeCards_resetDialog_confirm),
        ),
      ],
    ),
  );
  if (confirmed ?? false) {
    await notifier.resetHomeCards();
  }
}
```

Add a section header for the cards above the description ("Home cards", `settings_homeCards_sectionTitle`) styled like the `settings_diveDetailSections_configurableSections` header in `dive_detail_sections_page.dart` (titleSmall, primary color, bold). Design rationale for the sliver structure: a shrink-wrapped `ReorderableListView` nested in a `ListView` disables auto-scroll-while-dragging, so the whole page is ONE `CustomScrollView` and the reorderable list is a sliver within it.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/settings/presentation/pages/home_appearance_page_test.dart`
Expected: PASS (5 tests). Also run: `flutter test test/features/settings/` — pre-existing settings tests must stay green.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/ test/
flutter analyze
git add lib/features/settings test/features/settings
git commit -m "Add card reorder and visibility section to Home appearance settings"
```

---

### Task 7: Full verification

**Files:** none new.

- [ ] **Step 1: Format check**

Run: `dart format lib/ test/`
Expected: no files changed (if any change, commit them).

- [ ] **Step 2: Analyze the whole project**

Run: `flutter analyze`
Expected: "No issues found" — do NOT pipe through tail/head; infos are CI-fatal.

- [ ] **Step 3: Run the affected suites in full**

Run: `flutter test test/features/dashboard/ test/features/settings/ test/l10n/ test/helpers/ test/app_test.dart`
Expected: all PASS. If unrelated flaky suites are needed for confidence, prefer re-running the specific failing file before blaming the diff.

- [ ] **Step 4: Smoke test on macOS**

Run: `flutter run -d macos`
Manually verify: default home layout unchanged; hide a card in Settings > Appearance > Home and see it vanish; drag Quick Actions to the top and see it standalone; reset restores everything; hide all cards and use the empty-state button.

- [ ] **Step 5: Final commit if anything changed**

```bash
git status
dart format lib/ test/
git add -A
git commit -m "Home screen customization: verification fixes"
```
