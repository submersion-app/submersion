# Nav Shortcuts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (inline, in this session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a diver add deep pages (Trimix blender, an Insights page, the
emergency card, ...) to the main nav as shortcuts that behave like top-level
destinations.

**Architecture:** A curated catalog (`NavShortcut`) whose entries are stored
as `shortcut:<id>` inside the existing per-surface nav orders. A shortcut
renders as an ordinary `NavDestination` routed to a new alias route,
`/shortcut/:id`, which builds the page as a one-page stack. Nav selection
moves from first-prefix-wins to a specificity score, so a shortcut beats its
parent section.

**Tech Stack:** Flutter, go_router, Riverpod (StateNotifier), flutter_test,
ARB l10n (11 locales).

**Spec:** [docs/design/specs/2026-10-11-nav-shortcuts-design.md](../specs/2026-10-11-nav-shortcuts-design.md)

## Global Constraints

- Shortcuts are stored in `nav_primary_ids` / `nav_rail_ids` as
  `shortcut:<id>`; no new settings key, no schema change.
- `normalizeNavOrder` never appends shortcuts; every built-in stays
  guaranteed exactly once.
- Per surface: adding on Phone never touches the Desktop rail order.
- A new shortcut is inserted at index 0 of the movable list (right after Home).
- `/shortcut/<unknown>` redirects to `/dashboard`.
- System Back from any `/shortcut/...` location (after `mode` / `selected`
  unwind) goes to `/dashboard`.
- New user-facing strings ship in all 11 ARBs; `flutter gen-l10n` runs after
  the translations are in (see Task 8).
- No em dashes anywhere (code, comments, ARB values, commits).
- Paths built with `p.join` where filesystem paths appear (none expected).
- Files stay under 800 lines; `app_router.dart` gets only the one route line
  and an import swap.

## Review Focus

1. A shortcut stored, then removed from a later catalog: the nav must load
   with the built-ins intact and no blank slot (Task 3, normalize test).
2. Phone, Planning in More, blender shortcut in the bar, diver opens the
   blender by hand at `/planning/gas-calculators/blender`: the shortcut, not
   More, is selected (Task 2 selection test).
3. Desktop master-detail selection forms (`/planning?tool=deco-calculator`,
   `/insights?selected=gas`) select the shortcut when one is on the rail
   (Task 2 selection test).
4. Picker search with no match shows an explicit "No matching pages" line
   rather than an empty sheet (Task 7 widget test).
5. Back from `/shortcut/x?selected=1` unwinds the query first, then goes to
   the dashboard (Task 1 back-navigation test).

---

### Task 0: Before screenshots

Capture before any code changes (build-feature step 4.1).

- [ ] **Step 1:** Launch the app with the `run` skill on macOS.
- [ ] **Step 2:** Capture into the scratchpad:
  - `01-nav-settings-phone-before.png`: Settings > Appearance > Navigation, Phone tab, phone width.
  - `02-nav-settings-desktop-before.png`: same page, Desktop tab, desktop width.
  - `03-rail-before.png`: the desktop rail on the dashboard.
  - `04-bottom-bar-before.png`: the phone bottom bar on the dashboard.
- [ ] **Step 3:** Quit the app. No commit.

---

### Task 1: Shortcut locations and Back

**Files:**
- Create: `lib/core/router/shortcut_locations.dart`
- Modify: `lib/core/router/back_navigation.dart` (`resolveUpLocation`)
- Test: `test/core/router/back_navigation_test.dart`

**Interfaces:**
- Produces: `const String kShortcutLocationPrefix = '/shortcut';`,
  `String shortcutLocation(String id)`.

- [ ] **Step 1: Write the failing tests** (append inside the existing `main`):

```dart
  group('shortcut locations', () {
    test('a shortcut goes up to the dashboard', () {
      expect(
        resolveUpLocation(Uri.parse('/shortcut/gas-blender')),
        kRootLocation,
      );
    });

    test('a shortcut unwinds its drill-down query first', () {
      expect(
        resolveUpLocation(Uri.parse('/shortcut/insights-gas?selected=1')),
        '/shortcut/insights-gas',
      );
    });

    test('shortcutLocation builds the alias path', () {
      expect(shortcutLocation('gas-blender'), '/shortcut/gas-blender');
    });
  });
```

Add `import 'package:submersion/core/router/shortcut_locations.dart';`.

- [ ] **Step 2: Run, expect FAIL** (missing import / `/shortcut` returned):
  `flutter test test/core/router/back_navigation_test.dart`

- [ ] **Step 3: Implement.** `shortcut_locations.dart`:

```dart
/// Where nav shortcuts live (#2936).
///
/// A shortcut is a nav destination for a page that normally sits below a
/// top-level section. Its alias route has no parent route, so go_router
/// builds it as a one-page stack and the page behaves as top level.
library;

/// Path prefix of every shortcut's alias route.
const String kShortcutLocationPrefix = '/shortcut';

/// The alias location for the catalog shortcut [id].
String shortcutLocation(String id) => '$kShortcutLocationPrefix/$id';
```

In `resolveUpLocation`, after the drill-down loop and before the
`segments.length > 1` check:

```dart
  // A shortcut's alias route has no parent route; its second segment is an
  // id, not a level to walk up to.
  if (uri.path.startsWith('$kShortcutLocationPrefix/')) return kRootLocation;
```

and import `shortcut_locations.dart`. Update the doc comment's resolution
list with a step "Send a nav shortcut to the dashboard."

- [ ] **Step 4: Run, expect PASS.**
- [ ] **Step 5: Commit** `feat(nav): shortcut alias locations go up to the dashboard`

---

### Task 2: Match scoring and selection

**Files:**
- Modify: `lib/shared/widgets/nav/nav_destinations.dart` (`NavDestination`)
- Create: `lib/shared/widgets/nav/nav_selection.dart`
- Test: `test/shared/widgets/nav/nav_selection_test.dart`

**Interfaces:**
- Produces on `NavDestination`: optional `extraMatchPaths`
  (`List<String>`, default `const []`), `selection` (`NavSelectionMatch?`),
  `accentId` getter (falls back to `id`; constructor param `String? accent`).
- Produces: `class NavSelectionMatch { path, queryKey, queryValue }`,
  `int navMatchScore(NavDestination d, Uri location)`,
  `int? bestNavMatchIndex(List<NavDestination> ds, Uri location)`,
  `int railSelectedIndex(List<NavDestination> rail, Uri location)`,
  `int phoneSelectedIndex({required List<NavDestination> primary, required List<NavDestination> overflow, required Uri location})`.

- [ ] **Step 1: Write the failing tests** `nav_selection_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/widgets/nav/nav_destinations.dart';
import 'package:submersion/shared/widgets/nav/nav_selection.dart';

NavDestination _d(
  String id,
  String route, {
  List<String> extra = const [],
  NavSelectionMatch? selection,
}) => NavDestination(
  id: id,
  route: route,
  icon: Icons.circle,
  selectedIcon: Icons.circle,
  label: (_) => id,
  extraMatchPaths: extra,
  selection: selection,
);

final _home = _d('dashboard', '/dashboard');
final _more = _d('more', '');
final _planning = _d('planning', '/planning');
final _dives = _d('dives', '/dives');
final _blender = _d(
  'shortcut:gas-blender',
  '/shortcut/gas-blender',
  extra: ['/planning/gas-calculators/blender'],
  selection: const NavSelectionMatch(
    path: '/planning/gas-calculators',
    queryKey: 'calc',
    queryValue: 'blender',
  ),
);
final _deco = _d(
  'shortcut:deco-calculator',
  '/shortcut/deco-calculator',
  extra: ['/planning/deco-calculator'],
  selection: const NavSelectionMatch(
    path: '/planning',
    queryKey: 'tool',
    queryValue: 'deco-calculator',
  ),
);

void main() {
  group('navMatchScore', () {
    test('a path prefix scores its segment count', () {
      expect(navMatchScore(_dives, Uri.parse('/dives/42')), 1);
    });

    test('a prefix must end on a segment boundary', () {
      expect(navMatchScore(_dives, Uri.parse('/dives-x')), 0);
    });

    test('the empty More route never matches', () {
      expect(navMatchScore(_more, Uri.parse('/anything')), 0);
    });

    test('a canonical path outscores its section', () {
      final uri = Uri.parse('/planning/gas-calculators/blender/invoices');
      expect(
        navMatchScore(_blender, uri),
        greaterThan(navMatchScore(_planning, uri)),
      );
    });

    test('a desktop selection form outscores the hub it rides on', () {
      final uri = Uri.parse('/planning?tool=deco-calculator');
      expect(navMatchScore(_planning, uri), 1);
      expect(navMatchScore(_deco, uri), 2);
    });

    test('a different selection value does not match', () {
      expect(
        navMatchScore(_deco, Uri.parse('/planning?tool=no-fly')),
        0,
      );
    });
  });

  group('railSelectedIndex', () {
    test('the shortcut wins over its section', () {
      final rail = [_home, _planning, _blender];
      expect(
        railSelectedIndex(rail, Uri.parse('/planning/gas-calculators/blender')),
        2,
      );
      expect(railSelectedIndex(rail, Uri.parse('/planning/no-fly')), 1);
    });

    test('the alias location selects the shortcut', () {
      expect(
        railSelectedIndex([_home, _blender], Uri.parse('/shortcut/gas-blender')),
        1,
      );
    });

    test('no match selects Home', () {
      expect(railSelectedIndex([_home, _dives], Uri.parse('/nowhere')), 0);
    });
  });

  group('phoneSelectedIndex', () {
    test('a shortcut in the bar beats its section in More', () {
      expect(
        phoneSelectedIndex(
          primary: [_home, _blender, _dives, _more],
          overflow: [_planning],
          location: Uri.parse('/planning/gas-calculators/blender'),
        ),
        1,
      );
    });

    test('a shortcut in More beats its section in the bar, selecting More', () {
      expect(
        phoneSelectedIndex(
          primary: [_home, _planning, _dives, _more],
          overflow: [_blender],
          location: Uri.parse('/planning/gas-calculators/blender'),
        ),
        3,
      );
    });

    test('no match selects More', () {
      expect(
        phoneSelectedIndex(
          primary: [_home, _dives, _more],
          overflow: const [],
          location: Uri.parse('/settings'),
        ),
        2,
      );
    });
  });
}
```

- [ ] **Step 2: Run, expect FAIL** (`nav_selection.dart` missing):
  `flutter test test/shared/widgets/nav/nav_selection_test.dart`

- [ ] **Step 3: Implement.** In `NavDestination` add (with doc comments):

```dart
    this.extraMatchPaths = const [],
    this.selection,
    String? accent,
  }) : _accent = accent;

  /// Further locations this destination owns besides [route], each matched
  /// as a segment-aware path prefix. A shortcut lists its canonical path
  /// here so it stays selected when the page is reached by hand.
  final List<String> extraMatchPaths;

  /// A desktop master-detail selection that shows this destination's page,
  /// such as `/planning?tool=deco-calculator`.
  final NavSelectionMatch? selection;

  final String? _accent;

  /// The id whose feature accent colors this destination's icon. A shortcut
  /// borrows its section's accent.
  String get accentId => _accent ?? id;
```

Define `NavSelectionMatch` in `nav_destinations.dart` (const class, three
`String` fields, doc comment). Then `nav_selection.dart`:

```dart
import 'package:submersion/shared/widgets/nav/nav_destinations.dart';

/// How specifically [location] belongs to [destination]; 0 means not at all.
///
/// A path prefix scores its segment count, so a deeper page outscores the
/// section it sits in. A desktop selection form scores one more than its
/// path, so `/planning?tool=deco-calculator` belongs to a Deco shortcut
/// rather than to Planning.
int navMatchScore(NavDestination destination, Uri location) {
  final segments = _segments(location.path);
  var best = 0;
  for (final path in [destination.route, ...destination.extraMatchPaths]) {
    final prefix = _segments(path);
    if (prefix.isEmpty || prefix.length > segments.length) continue;
    var matches = true;
    for (var i = 0; i < prefix.length; i++) {
      if (prefix[i] != segments[i]) {
        matches = false;
        break;
      }
    }
    if (matches && prefix.length > best) best = prefix.length;
  }
  final selection = destination.selection;
  if (selection != null &&
      location.path == selection.path &&
      location.queryParameters[selection.queryKey] == selection.queryValue) {
    final score = _segments(selection.path).length + 1;
    if (score > best) best = score;
  }
  return best;
}

/// Index of the best-scoring destination for [location], the first on a
/// tie, or null when none matches.
int? bestNavMatchIndex(List<NavDestination> destinations, Uri location) {
  int? bestIndex;
  var bestScore = 0;
  for (var i = 0; i < destinations.length; i++) {
    final score = navMatchScore(destinations[i], location);
    if (score > bestScore) {
      bestScore = score;
      bestIndex = i;
    }
  }
  return bestIndex;
}

/// The rail's selected index: the best match, or Home (index 0).
int railSelectedIndex(List<NavDestination> rail, Uri location) =>
    bestNavMatchIndex(rail, location) ?? 0;

/// The bottom bar's selected index.
///
/// [primary] is `[Home, ...slots, More]`. The best match is taken across the
/// slots and [overflow] together, so a page whose most specific destination
/// sits in the More sheet selects More even when a less specific one is in
/// the bar. No match selects More, as before shortcuts existed.
int phoneSelectedIndex({
  required List<NavDestination> primary,
  required List<NavDestination> overflow,
  required Uri location,
}) {
  final moreIndex = primary.length - 1;
  final best = bestNavMatchIndex([
    ...primary.take(moreIndex),
    ...overflow,
  ], location);
  if (best == null || best >= moreIndex) return moreIndex;
  return best;
}

List<String> _segments(String path) =>
    Uri.parse(path).pathSegments.where((s) => s.isNotEmpty).toList();
```

- [ ] **Step 4: Run, expect PASS.** Also run
  `flutter test test/shared/widgets/nav/` (existing tests stay green).
- [ ] **Step 5: Commit** `feat(nav): score nav matches by specificity`

---

### Task 3: Catalog, normalization and providers

**Files:**
- Create: `lib/shared/widgets/nav/nav_shortcuts.dart`
- Modify: `lib/shared/widgets/nav/nav_destinations.dart` (`normalizeNavOrder`)
- Modify: `lib/shared/widgets/nav/nav_order_provider.dart`
- Modify: `lib/l10n/arb/app_en.arb` (9 label keys, English only for now)
- Test: `test/shared/widgets/nav/nav_shortcuts_test.dart`,
  `test/shared/widgets/nav/nav_normalize_test.dart`,
  `test/shared/widgets/nav/nav_order_provider_test.dart`

**Interfaces:**
- Consumes: `NavDestination` fields from Task 2,
  `shortcutLocation` from Task 1.
- Produces:
  - `enum NavShortcutGroup { planning, insights, views, settingsAndTools }`
  - `class NavShortcut { id, group, icon, label, parentLabel, canonicalPath, accent, selection; bool get isPlanning }`
  - `final List<NavShortcut> kNavShortcuts` (39 entries, spec table order)
  - `const String kNavShortcutIdPrefix = 'shortcut:'`
  - `String navShortcutOrderId(String shortcutId)`
  - `NavShortcut? navShortcutById(String id)`
  - `NavShortcut? navShortcutForOrderId(String orderId)`
  - `final List<String> kNavShortcutOrderIds`
  - `NavDestination navShortcutDestination(NavShortcut s)`
  - `NavDestination? resolveNavDestination(String orderId, Map<String, NavDestination> builtInsById)`
  - `normalizeNavOrder({required stored, required movableIds, Iterable<String> shortcutOrderIds = const []})`
  - `NavOrderNotifier(..., shortcutOrderIds: ...)`

- [ ] **Step 1: Add the 9 label keys to `app_en.arb`** after the
  `@settings_navCustomization_saveError` block, by anchor-line insertion
  (never a JSON round trip), each with an `@` description:
  `navShortcut_noFly` "No-fly time", `navShortcut_cnsOtu` "CNS/OTU",
  `navShortcut_records` "Records", `navShortcut_sitesMap` "Sites map",
  `navShortcut_diveActivityMap` "Dive activity map",
  `navShortcut_diveCentersMap` "Dive centers map",
  `navShortcut_diverProfile` "Diver profile", `navShortcut_cloudSync`
  "Cloud sync", `navShortcut_offlineMaps` "Offline maps". Run
  `flutter gen-l10n` so the getters exist (English fallback in other
  locales until Task 8 regenerates).

- [ ] **Step 2: Write the failing tests.** `nav_shortcuts_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/router/shortcut_locations.dart';
import 'package:submersion/shared/widgets/nav/nav_destinations.dart';
import 'package:submersion/shared/widgets/nav/nav_shortcuts.dart';

void main() {
  test('catalog ids are unique and never collide with built-ins', () {
    final ids = kNavShortcuts.map((s) => s.id).toList();
    expect(ids.toSet().length, ids.length);
    expect(kNavShortcuts.length, 39);
    for (final id in kNavShortcutOrderIds) {
      expect(movableNavIds, isNot(contains(id)));
    }
  });

  test('every planning shortcut is gated, nothing else is', () {
    for (final s in kNavShortcuts) {
      expect(
        s.isPlanning,
        s.canonicalPath.startsWith('/planning'),
        reason: s.id,
      );
    }
  });

  test('order ids round-trip through the prefix', () {
    expect(navShortcutOrderId('gas-blender'), 'shortcut:gas-blender');
    expect(navShortcutForOrderId('shortcut:gas-blender')?.id, 'gas-blender');
    expect(navShortcutForOrderId('gas-blender'), isNull);
    expect(navShortcutForOrderId('shortcut:retired'), isNull);
  });

  test('a shortcut destination routes to its alias and owns its page', () {
    final d = navShortcutDestination(navShortcutById('gas-blender')!);
    expect(d.id, 'shortcut:gas-blender');
    expect(d.route, shortcutLocation('gas-blender'));
    expect(d.extraMatchPaths, ['/planning/gas-calculators/blender']);
    expect(d.accentId, 'planning');
  });

  test('resolveNavDestination finds built-ins and shortcuts', () {
    final byId = {for (final d in kNavDestinations) d.id: d};
    expect(resolveNavDestination('dives', byId)?.route, '/dives');
    expect(
      resolveNavDestination('shortcut:insights-gas', byId)?.route,
      '/shortcut/insights-gas',
    );
    expect(resolveNavDestination('shortcut:nope', byId), isNull);
  });
}
```

Append to `nav_normalize_test.dart`:

```dart
  group('with shortcuts', () {
    const known = ['shortcut:gas-blender', 'shortcut:insights-gas'];

    test('known shortcuts keep their stored position', () {
      final result = normalizeNavOrder(
        stored: ['shortcut:gas-blender', 'dives'],
        movableIds: movableNavIds,
        shortcutOrderIds: known,
      );
      expect(result.take(2), ['shortcut:gas-blender', 'dives']);
      expect(result.where((id) => !id.startsWith('shortcut:')).toSet(),
          movableNavIds.toSet());
    });

    test('unknown and duplicate shortcuts are dropped', () {
      final result = normalizeNavOrder(
        stored: ['shortcut:retired', 'shortcut:gas-blender', 'shortcut:gas-blender'],
        movableIds: movableNavIds,
        shortcutOrderIds: known,
      );
      expect(result.where((id) => id.startsWith('shortcut:')),
          ['shortcut:gas-blender']);
    });

    test('missing shortcuts are never appended', () {
      final result = normalizeNavOrder(
        stored: const [],
        movableIds: movableNavIds,
        shortcutOrderIds: known,
      );
      expect(result, movableNavIds);
    });

    test('legacy ids pass shortcut ids through untouched', () {
      expect(
        withLegacyNavIds(['shortcut:gas-blender', 'insights']),
        ['shortcut:gas-blender', 'insights', 'statistics'],
      );
    });
  });
```

Append to `nav_order_provider_test.dart` inside `group('NavOrderNotifier')`:

```dart
    test('loads stored shortcuts and resolves them for the bar', () async {
      final repo = FakeAppSettingsRepository()
        ..navPrimaryIds = ['shortcut:gas-blender', 'dives', 'sites'];
      final container = _container(repo);
      addTearDown(container.dispose);

      await _loaded(container, navPhoneOrderNotifierProvider);
      final primary = container.read(navPrimaryDestinationsProvider(3));

      expect(primary.map((d) => d.id), [
        'dashboard',
        'shortcut:gas-blender',
        'dives',
        'sites',
        'more',
      ]);
    });

    test('resetToDefaults drops shortcuts', () async {
      final repo = FakeAppSettingsRepository()
        ..navRailIds = ['shortcut:insights-gas', 'dives'];
      final container = _container(repo);
      addTearDown(container.dispose);

      await _loaded(container, navRailOrderNotifierProvider);
      await container.read(navRailOrderNotifierProvider.notifier)
          .resetToDefaults();

      expect(container.read(navRailOrderNotifierProvider), movableNavIds);
    });
```

- [ ] **Step 3: Run, expect FAIL** for all three files.

- [ ] **Step 4: Implement `nav_shortcuts.dart`.** `NavShortcut` fields:
  `id`, `group`, `icon` (`IconData`), `label` and `parentLabel`
  (`String Function(AppLocalizations)`), `canonicalPath`, `accent` (the
  built-in nav id whose accent it borrows), `selection`
  (`NavSelectionMatch?`); `bool get isPlanning => group == NavShortcutGroup.planning;`.
  Entries, in this order, using these labels / parents / icons / accents:

  | id | label | parent | icon | accent | selection |
  | --- | --- | --- | --- | --- | --- |
  | dive-planner | planning_card_divePlanner_title | nav_planning | Icons.edit_calendar | planning | none |
  | deco-calculator | planning_card_decoCalculator_title | nav_planning | Icons.calculate | planning | /planning tool=deco-calculator |
  | gas-calculators | planning_card_gasCalculators_title | nav_planning | Icons.science | planning | none |
  | weight-calculator | planning_card_weightCalculator_title | nav_planning | Icons.fitness_center | planning | /planning tool=weight-calculator |
  | surface-interval | planning_card_surfaceInterval_title | nav_planning | Icons.timer | planning | /planning tool=surface-interval |
  | no-fly | navShortcut_noFly | nav_planning | Icons.airplanemode_inactive | planning | /planning tool=no-fly |
  | cns-otu | navShortcut_cnsOtu | nav_planning | Icons.air | planning | /planning tool=cns-otu |
  | gas-mod ... gas-blender (8) | gasCalculators_tab_<x> | planning_card_gasCalculators_title | icons from `gas_calculator_tools.dart` | planning | /planning/gas-calculators calc=<x> |
  | insights-<page> (11) | insights_category_<x>_title (observations: insights_observations_title) | nav_insights | icons from `insights_list_content.dart`; observations Icons.lightbulb_outline | insights | /insights selected=<page> |
  | records | navShortcut_records | nav_insights | Icons.emoji_events | insights | none |
  | connections | connections_title | nav_insights | Icons.hub_outlined | insights | none |
  | sites-map | navShortcut_sitesMap | nav_sites | Icons.map_outlined | sites | none |
  | dive-activity-map | navShortcut_diveActivityMap | nav_dives | Icons.public | dives | none |
  | dive-centers-map | navShortcut_diveCentersMap | nav_diveCenters | Icons.map | dive-centers | none |
  | equipment-sets | equipment_sets_appBar_title | nav_equipment | Icons.inventory_2_outlined | equipment | none |
  | certification-wallet | certifications_wallet_appBar_title | nav_certifications | Icons.wallet | certifications | none |
  | emergency-card | dashboard_quickAction_emergency | nav_settings | Icons.emergency_outlined | settings | none |
  | diver-profile | navShortcut_diverProfile | nav_settings | Icons.person_outline | settings | none |
  | cloud-sync | navShortcut_cloudSync | nav_settings | Icons.cloud_sync_outlined | settings | none |
  | backup | backup_appBar_title | nav_settings | Icons.backup_outlined | settings | none |
  | offline-maps | navShortcut_offlineMaps | nav_settings | Icons.download_for_offline_outlined | settings | none |
  | import-wizard | universalImport_title | nav_transfer | Icons.file_upload_outlined | transfer | none |

  Canonical paths per the spec table. Helpers:

```dart
const String kNavShortcutIdPrefix = 'shortcut:';

String navShortcutOrderId(String shortcutId) =>
    '$kNavShortcutIdPrefix$shortcutId';

final Map<String, NavShortcut> _byId = {
  for (final s in kNavShortcuts) s.id: s,
};

NavShortcut? navShortcutById(String id) => _byId[id];

NavShortcut? navShortcutForOrderId(String orderId) =>
    orderId.startsWith(kNavShortcutIdPrefix)
    ? _byId[orderId.substring(kNavShortcutIdPrefix.length)]
    : null;

final List<String> kNavShortcutOrderIds = List.unmodifiable(
  kNavShortcuts.map((s) => navShortcutOrderId(s.id)),
);

NavDestination navShortcutDestination(NavShortcut s) => NavDestination(
  id: navShortcutOrderId(s.id),
  route: shortcutLocation(s.id),
  icon: s.icon,
  selectedIcon: s.icon,
  label: s.label,
  subtitle: s.parentLabel,
  extraMatchPaths: [s.canonicalPath],
  selection: s.selection,
  accent: s.accent,
);

NavDestination? resolveNavDestination(
  String orderId,
  Map<String, NavDestination> builtInsById,
) {
  final shortcut = navShortcutForOrderId(orderId);
  if (shortcut != null) return navShortcutDestination(shortcut);
  return builtInsById[orderId];
}
```

- [ ] **Step 5: Normalization.** Add
  `Iterable<String> shortcutOrderIds = const []` to `normalizeNavOrder`. In
  the stored loop, before the movable check:

```dart
    if (shortcutOrderIds.contains(storedId)) {
      if (!result.contains(storedId)) result.add(storedId);
      continue;
    }
```

  Extend the doc comment: known shortcut ids keep their stored position,
  unknown ones are dropped, missing ones are never appended.

- [ ] **Step 6: Providers.** In `NavOrderNotifier` add a required
  `shortcutOrderIds` field passed to both `normalizeNavOrder` calls (load
  and `setOrder`). Both notifier providers pass `kNavShortcutOrderIds`.
  Replace each `byId[id]` lookup in `navPrimaryDestinationsProvider`,
  `navOverflowDestinationsProvider` and `navRailDestinationsProvider` with
  `resolveNavDestination(id, byId)`.

- [ ] **Step 7: Run, expect PASS:** `flutter test test/shared/widgets/nav/`
- [ ] **Step 8: Commit** `feat(nav): catalog of nav shortcuts stored in the nav orders`

---

### Task 4: Alias route and page builders

**Files:**
- Create: `lib/core/router/nav_shortcut_pages.dart`
- Create: `lib/features/import_wizard/presentation/pages/universal_import_wizard_route.dart`
  (moves `_UniversalImportWizardRoute` out of `app_router.dart`, made public)
- Modify: `lib/core/router/app_router.dart` (use the moved class; add
  `navShortcutRoute()` inside the main `ShellRoute` routes, after Dashboard)
- Test: `test/core/router/nav_shortcut_pages_test.dart`,
  `test/core/router/nav_shortcut_route_test.dart`

**Interfaces:**
- Consumes: `kNavShortcuts`, `navShortcutById` (Task 3),
  `kShortcutLocationPrefix` (Task 1), `kRootLocation`.
- Produces: `typedef NavShortcutPageBuilder = Widget Function(Map<String, String> query);`,
  `final Map<String, NavShortcutPageBuilder> kNavShortcutPages`,
  `GoRoute navShortcutRoute({Map<String, NavShortcutPageBuilder>? pages})`,
  `class UniversalImportWizardRoute extends ConsumerWidget`.

- [ ] **Step 1: Write the failing tests.** `nav_shortcut_pages_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/router/nav_shortcut_pages.dart';
import 'package:submersion/features/gas_calculators/presentation/pages/gas_calculator_detail_page.dart';
import 'package:submersion/features/import_wizard/presentation/pages/universal_import_wizard_route.dart';
import 'package:submersion/features/insights/presentation/pages/insights_gas_page.dart';
import 'package:submersion/shared/widgets/nav/nav_shortcuts.dart';

void main() {
  test('every catalog shortcut has a page and nothing else does', () {
    expect(
      kNavShortcutPages.keys.toSet(),
      kNavShortcuts.map((s) => s.id).toSet(),
    );
  });

  test('every builder returns a page', () {
    for (final entry in kNavShortcutPages.entries) {
      expect(entry.value(const {}), isNotNull, reason: entry.key);
    }
  });

  test('builders build the canonical page', () {
    final blender = kNavShortcutPages['gas-blender']!(const {});
    expect(blender, isA<GasCalculatorDetailPage>());
    expect((blender as GasCalculatorDetailPage).toolId, 'blender');
    expect(kNavShortcutPages['insights-gas']!(const {}), isA<InsightsGasPage>());
    expect(
      kNavShortcutPages['import-wizard']!(const {}),
      isA<UniversalImportWizardRoute>(),
    );
  });
}
```

`nav_shortcut_route_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/router/nav_shortcut_pages.dart';

Future<GoRouter> _pump(WidgetTester tester, String initial) async {
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      ShellRoute(
        builder: (context, state, child) => child,
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const Text('Dashboard'),
          ),
          navShortcutRoute(
            pages: {
              'probe': (query) => Scaffold(
                appBar: AppBar(title: Text('Probe ${query['q'] ?? ''}')),
              ),
            },
          ),
        ],
      ),
    ],
  );
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('a shortcut opens as a one-page stack', (tester) async {
    final router = await _pump(tester, '/shortcut/probe');
    expect(find.text('Probe '), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    expect(router.canPop(), isFalse);
  });

  testWidgets('the page receives the alias query', (tester) async {
    await _pump(tester, '/shortcut/probe?q=x');
    expect(find.text('Probe x'), findsOneWidget);
  });

  testWidgets('an unknown shortcut redirects to the dashboard', (tester) async {
    await _pump(tester, '/shortcut/nope');
    expect(find.text('Dashboard'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Move the import wizard route.** Cut
  `_UniversalImportWizardRoute` from `app_router.dart` into
  `universal_import_wizard_route.dart` as `UniversalImportWizardRoute`
  (same body, a doc comment, imports for `UnifiedImportWizard`,
  `UniversalAdapter`, `provider.dart`). Update the router's reference and
  import; drop any import that becomes unused.

- [ ] **Step 4: Implement `nav_shortcut_pages.dart`.** One map entry per
  catalog id, building the same widget the canonical route builds:
  `PlanCanvasPage()`, `DecoCalculatorPage()`, `GasCalculatorsPage()`,
  `WeightPlannerPage()`, `SurfaceIntervalToolPage()`, `NoFlyPage()`,
  `CnsOtuPage()`, eight `GasCalculatorDetailPage(toolId: '<x>')` (generated
  with a `for` over `kGasCalculatorIds` under key `'gas-$id'`), the 11
  Insights pages, `RecordsPage()`,
  `ConnectionsPage(args: ConnectionsRouteArgs.fromQuery(query))`,
  `SiteMapPage(initialSiteId: query['site'], initialScape3d: query['scape'] == '3d')`,
  `DiveActivityMapPage()`, `DiveCenterMapPage()`, `EquipmentSetListPage()`,
  `CertificationWalletPage()`, `EmergencyCardPage()`,
  `DiverProfileHubPage()`, `CloudSyncPage()`, `BackupSettingsPage()`,
  `OfflineMapsPage()`, `UniversalImportWizardRoute()`. Then:

```dart
/// The alias route every nav shortcut opens on (#2936).
///
/// It has no parent route, so go_router builds the page as a one-page stack:
/// no back arrow, and system Back goes to the dashboard like any other
/// top-level tab. Planning pages keep the Planning safety disclaimer.
GoRoute navShortcutRoute({Map<String, NavShortcutPageBuilder>? pages}) {
  final resolved = pages ?? kNavShortcutPages;
  return GoRoute(
    path: '$kShortcutLocationPrefix/:id',
    redirect: (context, state) =>
        resolved.containsKey(state.pathParameters['id']) ? null : kRootLocation,
    pageBuilder: (context, state) {
      final id = state.pathParameters['id']!;
      final page = resolved[id]!(state.uri.queryParameters);
      final gated = navShortcutById(id)?.isPlanning ?? false;
      return NoTransitionPage(
        key: state.pageKey,
        child: gated ? PlanningDisclaimerGate(child: page) : page,
      );
    },
  );
}
```

- [ ] **Step 5: Add `navShortcutRoute(),`** to the main `ShellRoute`
  routes in `app_router.dart`, right after the Dashboard route, with a
  one-line comment pointing at the spec.

- [ ] **Step 6: Run, expect PASS:** both new tests plus
  `flutter test test/core/router/`.
- [ ] **Step 7: Commit** `feat(nav): alias route that opens a shortcut as top level`

---

### Task 5: Scaffold selection and accents

**Files:**
- Modify: `lib/shared/widgets/main_scaffold.dart`
- Test: `test/shared/widgets/main_scaffold_shortcuts_test.dart` (new; a
  trimmed copy of the `_buildTestApp` harness and stubs from
  `main_scaffold_test.dart`, with `FakeAppSettingsRepository` from
  `test/support/` for the nav orders and routes `/dashboard`, `/planning`,
  `/planning/gas-calculators/blender`, `/shortcut/gas-blender`,
  `/dives`, `/sites`)

**Interfaces:**
- Consumes: `railSelectedIndex`, `phoneSelectedIndex` (Task 2),
  `NavDestination.accentId` (Task 2).

- [ ] **Step 1: Write the failing tests:**

```dart
  testWidgets('phone: a shortcut in the bar is selected on its page', (
    tester,
  ) async {
    useSize(tester, const Size(400, 800));
    final repo = FakeAppSettingsRepository()
      ..navPrimaryIds = ['shortcut:gas-blender', 'dives', 'sites'];
    await tester.pumpWidget(
      await buildHarness(repo, initialLocation: '/planning/gas-calculators/blender'),
    );
    await tester.pumpAndSettle();

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 1);
    expect(find.widgetWithText(NavigationDestination, 'Trimix blender'),
        findsOneWidget);
  });

  testWidgets('phone: tapping a shortcut opens its alias', (tester) async {
    useSize(tester, const Size(400, 800));
    final repo = FakeAppSettingsRepository()
      ..navPrimaryIds = ['shortcut:gas-blender', 'dives', 'sites'];
    await tester.pumpWidget(await buildHarness(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(NavigationDestination, 'Trimix blender'));
    await tester.pumpAndSettle();

    expect(find.text('Blender alias'), findsOneWidget);
  });

  testWidgets('rail: the shortcut beats Planning on the canonical page', (
    tester,
  ) async {
    useSize(tester, const Size(1300, 900));
    final repo = FakeAppSettingsRepository()
      ..navRailIds = ['planning', 'shortcut:gas-blender'];
    await tester.pumpWidget(
      await buildHarness(repo, initialLocation: '/planning/gas-calculators/blender'),
    );
    await tester.pumpAndSettle();

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.selectedIndex, 2); // Home, Planning, Blender
  });
```

  (`/shortcut/gas-blender` in the harness renders `Text('Blender alias')`.)

- [ ] **Step 2: Run, expect FAIL** (Planning or More selected).

- [ ] **Step 3: Implement.** Replace the body of `_calculateSelectedIndex`
  with:

```dart
    final location = GoRouterState.of(context).uri;
    return isWideScreen
        ? railSelectedIndex(railDestinations, location)
        : phoneSelectedIndex(
            primary: primaryDestinations,
            overflow: overflowDestinations,
            location: location,
          );
```

  adding the `overflowDestinations` parameter and passing it from `build`.
  Update its doc comment (most specific match, overflow selects More).
  Change every `navAccent(destination.id)` to
  `navAccent(destination.accentId)` (rail, bar, More sheet).

- [ ] **Step 4: Run, expect PASS:** the new file plus
  `flutter test test/shared/widgets/main_scaffold_test.dart test/shared/widgets/main_scaffold_back_navigation_test.dart`.
- [ ] **Step 5: Commit** `feat(nav): select the most specific nav destination`

---

### Task 6: Settings strings

**Files:**
- Modify: `lib/l10n/arb/app_en.arb`

- [ ] **Step 1:** Insert after the Task 3 keys (anchor-line insertion, `@`
  descriptions): `settings_navCustomization_addShortcut` "Add shortcut",
  `settings_navCustomization_shortcutPickerTitle` "Add a shortcut",
  `settings_navCustomization_shortcutSearchHint` "Search pages",
  `settings_navCustomization_shortcutNoMatches` "No matching pages",
  `settings_navCustomization_shortcutAlreadyAdded` "Already in this layout",
  `settings_navCustomization_removeShortcutLabel` "Remove {destination}"
  (placeholder `destination`: String),
  `settings_navCustomization_group_views` "Views",
  `settings_navCustomization_group_settingsAndTools` "Settings and tools".
- [ ] **Step 2:** `flutter gen-l10n`; no commit yet (lands with Task 7).

---

### Task 7: Picker and editor

**Files:**
- Create: `lib/features/settings/presentation/widgets/nav_shortcut_picker.dart`
- Modify: `lib/features/settings/presentation/widgets/nav_order_editor.dart`
- Test: `test/features/settings/presentation/widgets/nav_shortcut_picker_test.dart`,
  `test/features/settings/presentation/pages/nav_customization_page_test.dart`

**Interfaces:**
- Consumes: `kNavShortcuts`, `NavShortcutGroup`, `navShortcutOrderId`,
  `navShortcutForOrderId`, `resolveNavDestination` (Task 3).
- Produces: `class NavShortcutPicker extends StatefulWidget { alreadyAdded: Set<String> }`,
  `Future<String?> showNavShortcutPicker(BuildContext, {required Set<String> alreadyAdded})`,
  `String navShortcutGroupLabel(AppLocalizations l10n, NavShortcutGroup g)`.

- [ ] **Step 1: Write the failing picker tests:**

```dart
Widget _host(Set<String> added, void Function(String?) onPicked) =>
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async =>
              onPicked(await showNavShortcutPicker(context, alreadyAdded: added)),
          child: const Text('open'),
        ),
      ),
    );

testWidgets('lists groups and returns the chosen id', (tester) async {
  String? picked;
  await tester.pumpWidget(_host(const {}, (id) => picked = id));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  expect(find.text('Planning'), findsWidgets);
  await tester.enterText(find.byType(TextField), 'blender');
  await tester.pumpAndSettle();
  await tester.tap(find.text('Trimix blender'));
  await tester.pumpAndSettle();
  expect(picked, 'gas-blender');
});

testWidgets('entries already added are disabled', (tester) async {
  String? picked = 'unset';
  await tester.pumpWidget(_host({'gas-blender'}, (id) => picked = id));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), 'blender');
  await tester.pumpAndSettle();
  await tester.tap(find.text('Trimix blender'));
  await tester.pumpAndSettle();
  expect(picked, 'unset'); // still open, nothing returned
  expect(find.byTooltip('Already in this layout'), findsOneWidget);
});

testWidgets('a search with no match says so', (tester) async {
  await tester.pumpWidget(_host(const {}, (_) {}));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), 'zzzz');
  await tester.pumpAndSettle();
  expect(find.text('No matching pages'), findsOneWidget);
});
```

  And in `nav_customization_page_test.dart` (inside the page group, using
  `pumpPage`):

```dart
    testWidgets('Add shortcut inserts it right after Home', (tester) async {
      final repo = await pumpPage(tester);
      await tester.tap(find.text('Add shortcut'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'blender');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Trimix blender'));
      await tester.pumpAndSettle();

      expect(repo.navPrimaryIds!.first, 'shortcut:gas-blender');
      expect(find.byKey(const ValueKey('nav-item-shortcut:gas-blender')),
          findsOneWidget);
    });

    testWidgets('a shortcut row can be removed', (tester) async {
      final repo = FakeAppSettingsRepository()
        ..navPrimaryIds = ['shortcut:gas-blender'];
      await pumpPage(tester, repo: repo);
      await tester.tap(find.byTooltip('Remove Trimix blender'));
      await tester.pumpAndSettle();

      expect(repo.navPrimaryIds, isNot(contains('shortcut:gas-blender')));
    });

    testWidgets('built-in rows have no remove button', (tester) async {
      await pumpPage(tester);
      expect(find.byTooltip('Remove Dives'), findsNothing);
    });

    testWidgets('Reset clears shortcuts', (tester) async {
      final repo = FakeAppSettingsRepository()
        ..navPrimaryIds = ['shortcut:gas-blender'];
      await pumpPage(tester, repo: repo);
      await tester.tap(find.text('Reset to defaults'));
      await tester.pumpAndSettle();

      expect(repo.navPrimaryIds, isNot(contains('shortcut:gas-blender')));
    });

    testWidgets('adding on Phone leaves the Desktop order alone', (tester) async {
      final repo = await pumpPage(tester);
      await tester.tap(find.text('Add shortcut'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'blender');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Trimix blender'));
      await tester.pumpAndSettle();

      expect(repo.navRailIds, isNull);
    });
```

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement the picker.** `showNavShortcutPicker` shows a
  `Dialog` (max 480 x 640) when `ResponsiveBreakpoints.isDesktop(context)`,
  otherwise a scroll-controlled `showModalBottomSheet` with
  `useSafeArea: true` and an 85% height cap (matching the More sheet). The
  picker body: title row (`shortcutPickerTitle` + close button), a search
  `TextField` (hint `shortcutSearchHint`, prefix search icon), then a
  `ListView` of group headers and `ListTile`s (icon, label, parent label as
  subtitle). Filtering: case-insensitive `contains` on label or parent
  label; empty groups are skipped; an empty result shows
  `shortcutNoMatches`. An already-added entry is `enabled: false` with a
  trailing `Tooltip(message: shortcutAlreadyAdded, child: Icon(Icons.check))`.
  Tapping an enabled entry pops with its id. Group labels:
  planning `nav_planning`, insights `nav_insights`, views `group_views`,
  settingsAndTools `group_settingsAndTools`.

- [ ] **Step 4: Implement the editor changes** in `NavOrderEditor`:
  - Build `destinationsById` as today and look rows up with
    `resolveNavDestination(id, destinationsById)!`.
  - Split `_commitReorder` into the index math plus a shared
    `Future<void> _commitOrder(List<String> newList)` that holds the
    existing optimistic update, write and rollback.
  - `_addShortcut()`: collect `alreadyAdded` from `_local` via
    `navShortcutForOrderId`, await `showNavShortcutPicker`, and on a pick
    call `_commitOrder([navShortcutOrderId(picked), ..._local!])`.
  - `_removeShortcut(String orderId)`:
    `_commitOrder(_local!.where((id) => id != orderId).toList())`.
  - `_buildMovableTile` takes `onRemove` (`VoidCallback?`); when non-null it
    adds an `IconButton(icon: Icon(Icons.close), tooltip: removeShortcutLabel(label))`
    before the arrows.
  - Bottom bar: a `Row` with `TextButton.icon(Icons.add_link, addShortcut)`
    and the existing Reset button.

- [ ] **Step 5: Run, expect PASS:** the picker test and
  `flutter test test/features/settings/`.
- [ ] **Step 6: Commit** `feat(settings): add and remove nav shortcuts` (includes the Task 6 ARB keys and generated l10n).

---

### Task 8: Translations

**Files:**
- Modify: `lib/l10n/arb/app_{ar,de,es,fr,he,hu,it,nl,pt,zh}.arb` and the
  generated `app_localizations_*.dart`

- [ ] **Step 1:** List this PR's new keys:
  `git diff origin/main...HEAD -- lib/l10n/arb/app_en.arb`.
- [ ] **Step 2:** Translate each of the 17 keys into all 10 locales,
  matching each locale's neighbouring `settings_navCustomization_*` and
  `nav_*` terms, keeping `{destination}` verbatim. Insert by anchor line
  after each locale's `settings_navCustomization_saveError` line with a
  python3.14 script that builds lines via `json.dumps(value, ensure_ascii=False)`
  and asserts `json.loads` still parses each file. No `@meta` in locale files.
- [ ] **Step 3:** `flutter gen-l10n`, then verify, for example
  `grep -A1 "get settings_navCustomization_addShortcut" lib/l10n/arb/app_localizations_de.dart`
  shows German, and `git diff --numstat lib/l10n/arb/` shows even rows.
- [ ] **Step 4: Commit** `i18n(nav): translate nav shortcut strings`

---

### Task 9: Whole-branch checks and after screenshots

- [ ] **Step 1:** `dart format .` then `flutter analyze` (clean).
- [ ] **Step 2:** `flutter test test/architecture/ test/shared/ test/core/router/ test/features/settings/`
- [ ] **Step 3:** After screenshots with the `run` skill, same screens as
  Task 0 plus: `05-shortcut-picker-phone-after.png`,
  `06-shortcut-picker-desktop-after.png`,
  `07-bottom-bar-blender-after.png` (blender in the bar, selected on its
  page), `08-rail-blender-after.png`, and dark-mode variants of 05 and 07.
  Manually confirm: no back arrow on the blender, and choosing a calculator
  in the Gas calculators shortcut hub on desktop stays on `/shortcut/...`.
- [ ] **Step 4:** Commit any format fixes as
  `chore(nav): format` (skip if none).
