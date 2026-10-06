# Grouped, Searchable Site Selection Lists Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every place a diver picks a dive site opens one shared, buddy-style sheet with a search bar that matches every location field, a Nearby section, and collapsible Country > Region groups; the Dive Sites page can group its list the same way.

**Architecture:** Pure functions in `dive_sites/domain/utils/` do the search (`SiteQuery`), grouping (`groupSitesByLocation`) and flattening (`flattenSiteGroups`) into a row list. One lazy `ListView.builder` per surface renders those rows with shared header widgets. The picker sheet, the Refine panel's new `SitePickerField`, media import review and the Sites page all consume the same pieces.

**Tech Stack:** Flutter, Riverpod (`StateProvider`, `ConsumerStatefulWidget`), flutter_test widget tests, ARB l10n with `flutter gen-l10n`.

**Spec:** `docs/superpowers/specs/2026-10-05-site-selection-lists-design.md`

## Global Constraints

- Issue #1080, release v1.8.2. Every commit follows `feat(<scope>): ...` / `test(...)` style; no commit or file may mention Claude, Claude Code or Anthropic.
- No em-dashes or en-dashes used as punctuation in any code, comment, ARB string or doc.
- Nearby radius: 50 km (`50000` meters), unchanged from today.
- Distances render through `UnitFormatter.formatGeoDistance` so they respect the diver's unit settings.
- Country and region keys: trimmed and folded with `textSortKey`; blank (null or whitespace) counts as missing.
- The no-country group's key is the empty string `''` and sorts last.
- Group-by on the Sites page is session-only (`StateProvider`), default `SiteGroupBy.none`, hidden in table mode.
- Every new ARB key gets a real translation in all 11 ARB files (`ar de en es fr he hu it nl pt zh`), then `flutter gen-l10n`.
- No widget other than fixed-width icons in `ListTile.trailing` (guarded by `test/architecture/list_tile_trailing_width_test.dart`).
- Imports grouped dart, flutter, packages, local; `dart format .` before each commit.

## Review Focus

1. **Blank location fields** (`country: '   '`, `region: ''`): treated as missing, so the site lands in "No country" or the no-region slot, never in a group with a blank header. Pinned in Task 2.
2. **Selected site id that no longer exists** (deleted since the filter was set): the sheet opens without error and nothing is checked; the Refine field shows "All sites". Pinned in Tasks 4 and 6.
3. **Whitespace-only query** (`'   '`): treated as no query, so the diver's manual expansion is shown, not "everything expanded". Pinned in Tasks 1 and 4.
4. **A GPS site with no country inside 50 km**: listed in Nearby and also in the "No country" group. Pinned in Task 4.
5. **Grouped Sites page in selection mode**: tapping a country header toggles it and never selects anything; select-all still selects sites inside collapsed groups. Pinned in Task 7.

---

## File Structure

| File | Responsibility |
| --- | --- |
| `lib/features/dive_sites/domain/utils/site_search.dart` (create) | `siteSearchText`, `normalizedSiteSearchText`, `SiteQuery` |
| `lib/features/dive_sites/domain/utils/site_grouping.dart` (create) | group types, `groupSitesByLocation`, `flattenSiteGroups`, `siteCountryKey`, `initialExpandedCountries` |
| `lib/features/dive_sites/presentation/widgets/site_picker/grouped_site_list_view.dart` (create) | `SiteCountryHeader`, `SiteSectionLabel`, `siteGroupedSubtitle`, `countryGroupLabel` |
| `lib/features/dive_sites/presentation/widgets/site_picker/site_picker_site_tile.dart` (create) | one site row in the picker (avatar, subtitle, distance, check) |
| `lib/features/dive_sites/presentation/widgets/site_picker/site_picker_sheet.dart` (create) | `SitePickerResult`, `showSitePicker`, `pickOrCreateSite`, `SitePickerSheet` |
| `lib/features/dive_sites/presentation/widgets/site_picker/site_picker_field.dart` (create) | Refine panel field that opens the sheet |
| `lib/features/dive_sites/presentation/providers/site_grouping_providers.dart` (create) | `SiteGroupBy`, `siteGroupByProvider`, `siteListExpandedCountriesProvider` |
| `lib/features/dive_sites/presentation/widgets/site_group_by_selector.dart` (create) | Sites page sort-sheet footer |
| `lib/shared/widgets/sort_bottom_sheet.dart` (modify) | optional `footer` |
| `lib/features/dive_sites/presentation/widgets/site_list_content.dart` (modify) | grouped rendering |
| `lib/features/dive_log/presentation/widgets/refine/groups/refine_location_group.dart` (modify) | use `SitePickerField` |
| `lib/features/dive_log/presentation/pages/dive_edit_page.dart`, `lib/features/nav_track/presentation/pages/nav_track_detail_page.dart`, `lib/features/nav_track/presentation/pages/nav_track_import_review_page.dart` (modify) | import path only |
| `lib/features/media/presentation/pages/media_import_review_page.dart` (modify) | use `showSitePicker` |
| `lib/features/dive_log/presentation/widgets/pickers/site_picker_sheet.dart`, `lib/features/dive_log/presentation/utils/site_picker_search.dart`, `lib/features/media/presentation/widgets/site_picker_sheet.dart` (delete) | replaced |
| `lib/l10n/arb/app_*.arb` (modify) + generated `app_localizations*.dart` | new strings |

---

### Task 1: Site search helper

**Files:**
- Create: `lib/features/dive_sites/domain/utils/site_search.dart`
- Test: `test/features/dive_sites/domain/utils/site_search_test.dart`

**Interfaces:**
- Consumes: `normalize` from `package:submersion/core/text/fuzzy_match.dart`.
- Produces: `String siteSearchText(DiveSite site)`, `String normalizedSiteSearchText(DiveSite site)`, `class SiteQuery { SiteQuery(String query); List<String> words; bool get isEmpty; bool matches(String normalizedSearchText); bool matchesSite(DiveSite site); }`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/utils/site_search.dart';

const _site = DiveSite(
  id: 's1',
  name: 'Blue Hole',
  country: 'Egypt',
  region: 'South Sinai',
  city: 'Dahab',
  island: 'Nowhere Isle',
  bodyOfWater: 'Red Sea',
);

void main() {
  group('siteSearchText', () {
    test('joins every location field and skips blanks', () {
      expect(
        siteSearchText(_site),
        'Blue Hole Egypt South Sinai Dahab Nowhere Isle Red Sea',
      );
      expect(
        siteSearchText(const DiveSite(id: 'x', name: 'Reef', country: '  ')),
        'Reef',
      );
    });
  });

  group('SiteQuery', () {
    test('matches each location field', () {
      for (final q in ['egypt', 'sinai', 'dahab', 'isle', 'red sea', 'hole']) {
        expect(SiteQuery(q).matchesSite(_site), isTrue, reason: q);
      }
    });

    test('folds case and diacritics', () {
      const site = DiveSite(id: 'c', name: 'Cenote', city: 'Cancún');
      expect(SiteQuery('CANCUN').matchesSite(site), isTrue);
    });

    test('every word must match somewhere, in any order', () {
      expect(SiteQuery('blue egypt').matchesSite(_site), isTrue);
      expect(SiteQuery('egypt blue').matchesSite(_site), isTrue);
      expect(SiteQuery('blue mexico').matchesSite(_site), isFalse);
    });

    test('a whitespace-only query is empty and matches everything', () {
      final query = SiteQuery('   ');
      expect(query.isEmpty, isTrue);
      expect(query.matchesSite(_site), isTrue);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_sites/domain/utils/site_search_test.dart`
Expected: FAIL, `site_search.dart` does not exist.

- [ ] **Step 3: Write the implementation**

```dart
import 'package:submersion/core/text/fuzzy_match.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// Everything about [site] that typing in a site picker can match: its name
/// and every location field, so a diver who forgets a name can find the site
/// by where it is (#1080).
///
/// Blank parts are dropped and the rest joined by a space, so two adjacent
/// parts cannot run together into a match neither contains.
String siteSearchText(DiveSite site) => [
  site.name,
  site.country,
  site.region,
  site.city,
  site.island,
  site.bodyOfWater,
].whereType<String>().map((part) => part.trim()).where((part) => part.isNotEmpty).join(' ');

/// [siteSearchText] after [normalize]. Callers filtering per keystroke compute
/// this once per site and reuse it.
String normalizedSiteSearchText(DiveSite site) =>
    normalize(siteSearchText(site));

/// One site picker query, normalized and split into words once.
///
/// A site matches when every word is a substring of its normalized search
/// text, so "blue egypt" finds Blue Hole in Dahab, Egypt.
class SiteQuery {
  SiteQuery(String query)
    : words = normalize(query)
          .split(RegExp(r'\s+'))
          .where((word) => word.isNotEmpty)
          .toList(growable: false);

  final List<String> words;

  /// True for an empty or whitespace-only query, which matches everything.
  bool get isEmpty => words.isEmpty;

  /// [normalizedSearchText] must already be normalized.
  bool matches(String normalizedSearchText) =>
      words.every(normalizedSearchText.contains);

  bool matchesSite(DiveSite site) => matches(normalizedSiteSearchText(site));
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_sites/domain/utils/site_search_test.dart`
Expected: PASS (all 6 tests).

- [ ] **Step 5: Commit**

```bash
dart format lib/features/dive_sites/domain/utils/site_search.dart test/features/dive_sites/domain/utils/site_search_test.dart
git add lib/features/dive_sites/domain/utils/site_search.dart test/features/dive_sites/domain/utils/site_search_test.dart
git commit -m "feat(dive-sites): search sites by every location field"
```

---

### Task 2: Grouping and flattening

**Files:**
- Create: `lib/features/dive_sites/domain/utils/site_grouping.dart`
- Test: `test/features/dive_sites/domain/utils/site_grouping_test.dart`

**Interfaces:**
- Consumes: `textSortKey`, `TextCollator` from `package:submersion/core/text/text_sort.dart`.
- Produces:
  - `const String noCountryGroupKey = '';`
  - `String siteCountryKey(DiveSite site)`
  - `class SiteRegionGroup<T> { String key; String label; List<T> items; }`
  - `class SiteCountryGroup<T> { String key; String label; List<T> unregioned; List<SiteRegionGroup<T>> regions; bool get isNoCountry; int get siteCount; Iterable<T> get allItems; }`
  - `List<SiteCountryGroup<T>> groupSitesByLocation<T>(List<T> items, DiveSite Function(T) siteOf)`
  - `sealed class SiteListRow<T>` with `CountryHeaderRow<T>(group, isExpanded)`, `RegionHeaderRow<T>(label)`, `SiteRow<T>(item)`
  - `List<SiteListRow<T>> flattenSiteGroups<T>(List<SiteCountryGroup<T>> groups, {required Set<String> expanded})`
  - `Set<String> initialExpandedCountries<T>(List<SiteCountryGroup<T>> groups, {DiveSite? selected})`
  - `Set<String> allCountryKeys<T>(List<SiteCountryGroup<T>> groups)`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/utils/site_grouping.dart';

DiveSite _s(String id, {String? country, String? region}) =>
    DiveSite(id: id, name: id, country: country, region: region);

List<SiteCountryGroup<DiveSite>> _group(List<DiveSite> sites) =>
    groupSitesByLocation(sites, (s) => s);

void main() {
  group('groupSitesByLocation', () {
    test('orders countries alphabetically, ignoring case and accents', () {
      final groups = _group([
        _s('a', country: 'mexico'),
        _s('b', country: 'Égypte'),
        _s('c', country: 'Australia'),
      ]);
      expect(groups.map((g) => g.label), ['Australia', 'Égypte', 'mexico']);
    });

    test('folds spellings into one group labelled by the commonest', () {
      final groups = _group([
        _s('a', country: 'australia'),
        _s('b', country: 'Australia '),
        _s('c', country: 'Australia'),
      ]);
      expect(groups, hasLength(1));
      expect(groups.single.label, 'Australia');
      expect(groups.single.siteCount, 3);
    });

    test('a spelling tie keeps the first one seen', () {
      final groups = _group([
        _s('a', country: 'australia'),
        _s('b', country: 'Australia'),
      ]);
      expect(groups.single.label, 'australia');
    });

    test('blank and missing countries go to a last No country group', () {
      final groups = _group([
        _s('a'),
        _s('b', country: '   '),
        _s('c', country: 'Belize'),
      ]);
      expect(groups.map((g) => g.key), [siteCountryKey(_s('x', country: 'Belize')), noCountryGroupKey]);
      expect(groups.last.isNoCountry, isTrue);
      expect(groups.last.label, '');
      expect(groups.last.allItems.map((s) => s.id), ['a', 'b']);
    });

    test('no-region sites come first, then regions alphabetically', () {
      final group = _group([
        _s('q1', country: 'Australia', region: 'Queensland'),
        _s('n1', country: 'Australia'),
        _s('w1', country: 'Australia', region: 'western australia'),
        _s('b1', country: 'Australia', region: ' '),
        _s('q2', country: 'Australia', region: 'queensland'),
      ]).single;
      expect(group.unregioned.map((s) => s.id), ['n1', 'b1']);
      expect(group.regions.map((r) => r.label), ['Queensland', 'western australia']);
      expect(group.regions.first.items.map((s) => s.id), ['q1', 'q2']);
    });

    test('keeps the input order inside every group', () {
      final group = _group([
        _s('z', country: 'Fiji'),
        _s('a', country: 'Fiji'),
        _s('m', country: 'Fiji'),
      ]).single;
      expect(group.unregioned.map((s) => s.id), ['z', 'a', 'm']);
    });

    test('groups any item type through siteOf', () {
      final groups = groupSitesByLocation<(DiveSite, int)>(
        [(_s('a', country: 'Fiji'), 3)],
        (pair) => pair.$1,
      );
      expect(groups.single.unregioned.single.$2, 3);
    });
  });

  group('flattenSiteGroups', () {
    final groups = _group([
      _s('fiji1', country: 'Fiji'),
      _s('aus1', country: 'Australia', region: 'Queensland'),
      _s('aus0', country: 'Australia'),
    ]);
    final ausKey = siteCountryKey(_s('x', country: 'Australia'));

    String describe(SiteListRow<DiveSite> row) => switch (row) {
      CountryHeaderRow(:final group, :final isExpanded) =>
        'C:${group.label}:${isExpanded ? 'open' : 'closed'}',
      RegionHeaderRow(:final label) => 'R:$label',
      SiteRow(:final item) => 'S:${item.id}',
    };

    test('collapsed countries show only their header', () {
      expect(
        flattenSiteGroups(groups, expanded: const {}).map(describe),
        ['C:Australia:closed', 'C:Fiji:closed'],
      );
    });

    test('an expanded country lists unregioned sites, then regions', () {
      expect(
        flattenSiteGroups(groups, expanded: {ausKey}).map(describe),
        ['C:Australia:open', 'S:aus0', 'R:Queensland', 'S:aus1', 'C:Fiji:closed'],
      );
    });
  });

  group('initialExpandedCountries', () {
    test('opens the selected site country', () {
      final groups = _group([_s('a', country: 'Fiji'), _s('b', country: 'Palau')]);
      expect(
        initialExpandedCountries(groups, selected: _s('b', country: 'Palau')),
        {siteCountryKey(_s('x', country: 'Palau'))},
      );
    });

    test('opens the only group, even No country', () {
      final groups = _group([_s('a'), _s('b')]);
      expect(initialExpandedCountries(groups), {noCountryGroupKey});
    });

    test('opens nothing for several groups and no selection', () {
      final groups = _group([_s('a', country: 'Fiji'), _s('b', country: 'Palau')]);
      expect(initialExpandedCountries(groups), isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_sites/domain/utils/site_grouping_test.dart`
Expected: FAIL, `site_grouping.dart` does not exist.

- [ ] **Step 3: Write the implementation**

```dart
import 'package:submersion/core/text/text_sort.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// Key of the group holding sites with no country. A real country key is
/// never empty, because a blank country counts as no country.
const String noCountryGroupKey = '';

/// The group key of [site]'s country: trimmed and case/accent folded, or
/// [noCountryGroupKey] when the country is null or blank.
String siteCountryKey(DiveSite site) {
  final country = site.country?.trim() ?? '';
  return country.isEmpty ? noCountryGroupKey : textSortKey(country);
}

/// The sites of one region inside a [SiteCountryGroup].
class SiteRegionGroup<T> {
  const SiteRegionGroup({
    required this.key,
    required this.label,
    required this.items,
  });

  final String key;

  /// The region's commonest spelling among its sites.
  final String label;

  final List<T> items;
}

/// The sites of one country, split into those with no region and per-region
/// subgroups (#1080).
class SiteCountryGroup<T> {
  const SiteCountryGroup({
    required this.key,
    required this.label,
    required this.unregioned,
    required this.regions,
  });

  final String key;

  /// The country's commonest spelling, or empty for the no-country group,
  /// whose label the UI supplies ("No country").
  final String label;

  /// Sites with no region, listed before the region subgroups.
  final List<T> unregioned;

  final List<SiteRegionGroup<T>> regions;

  bool get isNoCountry => key == noCountryGroupKey;

  int get siteCount =>
      unregioned.length +
      regions.fold<int>(0, (sum, region) => sum + region.items.length);

  /// Every site in display order: unregioned first, then each region.
  Iterable<T> get allItems sync* {
    yield* unregioned;
    for (final region in regions) {
      yield* region.items;
    }
  }
}

class _Bucket<T> {
  final spellings = <String>[];
  final items = <T>[];
  final regions = <String, _Bucket<T>>{};
}

/// Groups [items] by country, then region, for a site list or picker.
///
/// Countries order alphabetically (accent and case folded) with the
/// no-country group last; regions order the same way after the country's
/// unregioned sites. Items keep their input order inside each group, so the
/// caller's sort carries through.
List<SiteCountryGroup<T>> groupSitesByLocation<T>(
  List<T> items,
  DiveSite Function(T) siteOf,
) {
  final countries = <String, _Bucket<T>>{};
  for (final item in items) {
    final site = siteOf(item);
    final countryKey = siteCountryKey(site);
    final country = countries.putIfAbsent(countryKey, _Bucket<T>.new);
    if (countryKey != noCountryGroupKey) {
      country.spellings.add(site.country!.trim());
    }
    final region = site.region?.trim() ?? '';
    if (region.isEmpty) {
      country.items.add(item);
      continue;
    }
    final regionBucket = country.regions.putIfAbsent(
      textSortKey(region),
      _Bucket<T>.new,
    );
    regionBucket.spellings.add(region);
    regionBucket.items.add(item);
  }

  final collator = TextCollator();
  final groups = [
    for (final entry in countries.entries)
      SiteCountryGroup<T>(
        key: entry.key,
        label: entry.key == noCountryGroupKey
            ? ''
            : _commonest(entry.value.spellings),
        unregioned: List.unmodifiable(entry.value.items),
        regions: List.unmodifiable(
          [
            for (final region in entry.value.regions.entries)
              SiteRegionGroup<T>(
                key: region.key,
                label: _commonest(region.value.spellings),
                items: List.unmodifiable(region.value.items),
              ),
          ]..sort((a, b) => collator.compare(a.label, b.label)),
        ),
      ),
  ];
  groups.sort((a, b) {
    if (a.isNoCountry != b.isNoCountry) return a.isNoCountry ? 1 : -1;
    return collator.compare(a.label, b.label);
  });
  return List.unmodifiable(groups);
}

/// The most frequent spelling; a tie keeps the one seen first.
String _commonest(List<String> spellings) {
  final counts = <String, int>{};
  for (final spelling in spellings) {
    counts[spelling] = (counts[spelling] ?? 0) + 1;
  }
  var best = spellings.first;
  var bestCount = 0;
  for (final entry in counts.entries) {
    if (entry.value > bestCount) {
      best = entry.key;
      bestCount = entry.value;
    }
  }
  return best;
}

/// One row of a grouped site list.
sealed class SiteListRow<T> {
  const SiteListRow();
}

final class CountryHeaderRow<T> extends SiteListRow<T> {
  const CountryHeaderRow({required this.group, required this.isExpanded});

  final SiteCountryGroup<T> group;
  final bool isExpanded;
}

final class RegionHeaderRow<T> extends SiteListRow<T> {
  const RegionHeaderRow(this.label);

  final String label;
}

final class SiteRow<T> extends SiteListRow<T> {
  const SiteRow(this.item);

  final T item;
}

/// Flattens [groups] into rows for one lazy list. A country whose key is not
/// in [expanded] contributes only its header.
List<SiteListRow<T>> flattenSiteGroups<T>(
  List<SiteCountryGroup<T>> groups, {
  required Set<String> expanded,
}) => [
  for (final group in groups) ...[
    CountryHeaderRow<T>(group: group, isExpanded: expanded.contains(group.key)),
    if (expanded.contains(group.key)) ...[
      for (final item in group.unregioned) SiteRow<T>(item),
      for (final region in group.regions) ...[
        RegionHeaderRow<T>(region.label),
        for (final item in region.items) SiteRow<T>(item),
      ],
    ],
  ],
];

/// The countries a grouped list opens with: the [selected] site's country,
/// and the only group when there is just one.
Set<String> initialExpandedCountries<T>(
  List<SiteCountryGroup<T>> groups, {
  DiveSite? selected,
}) => {
  if (groups.length == 1) groups.single.key,
  if (selected != null) siteCountryKey(selected),
};

/// Every group key, for "a search or filter is active, open everything".
Set<String> allCountryKeys<T>(List<SiteCountryGroup<T>> groups) => {
  for (final group in groups) group.key,
};
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_sites/domain/utils/site_grouping_test.dart`
Expected: PASS (all 12 tests).

- [ ] **Step 5: Commit**

```bash
dart format lib/features/dive_sites/domain/utils/site_grouping.dart test/features/dive_sites/domain/utils/site_grouping_test.dart
git add lib/features/dive_sites/domain/utils/site_grouping.dart test/features/dive_sites/domain/utils/site_grouping_test.dart
git commit -m "feat(dive-sites): group sites by country and region"
```

---

### Task 3: Strings and shared header widgets

**Files:**
- Modify: all 11 `lib/l10n/arb/app_*.arb`, regenerate `lib/l10n/arb/app_localizations*.dart`
- Create: `lib/features/dive_sites/presentation/widgets/site_picker/grouped_site_list_view.dart`
- Test: `test/features/dive_sites/presentation/widgets/site_picker/grouped_site_list_view_test.dart`

**Interfaces:**
- Consumes: `SiteCountryGroup` (Task 2).
- Produces:
  - l10n getters: `diveSites_group_noCountry`, `diveSites_group_siteCount(int count)`, `diveSites_picker_nearby`, `diveSites_list_groupBy`, `diveSites_list_groupBy_none`, `diveSites_list_groupBy_location`, `diveLog_filter_clearSite`
  - `String? siteGroupedSubtitle(DiveSite site)`
  - `String countryGroupLabel(AppLocalizations l10n, SiteCountryGroup<Object?> group)`
  - `class SiteCountryHeader extends StatelessWidget { const SiteCountryHeader({Key? key, required String label, required int siteCount, required bool isExpanded, required VoidCallback onTap}); }`
  - `class SiteSectionLabel extends StatelessWidget { const SiteSectionLabel(String text, {Key? key, double indent = 16}); }`

- [ ] **Step 1: Add the ARB keys**

Write a throwaway script in the scratchpad (never in the repo) that inserts these keys into each ARB, keeping keys in alphabetical order the way the files already are, and writing UTF-8 with `ensure_ascii=False` and 2-space indent. Check `git diff --stat lib/l10n/arb` afterwards: each file should gain exactly 7 lines.

| key | en | ar | de | es | fr |
| --- | --- | --- | --- | --- | --- |
| `diveLog_filter_clearSite` | Clear site filter | مسح مرشح الموقع | Tauchplatzfilter löschen | Borrar filtro de punto | Effacer le filtre de site |
| `diveSites_group_noCountry` | No country | بلا دولة | Kein Land | Sin país | Sans pays |
| `diveSites_group_siteCount` | `{count, plural, =1{1 site} other{{count} sites}}` | `{count, plural, =0{لا مواقع} =1{موقع واحد} =2{موقعان} few{{count} مواقع} many{{count} موقعًا} other{{count} موقع}}` | `{count, plural, =1{1 Tauchplatz} other{{count} Tauchplätze}}` | `{count, plural, =1{1 punto} other{{count} puntos}}` | `{count, plural, =1{1 site} other{{count} sites}}` |
| `diveSites_list_groupBy` | Group by | التجميع حسب | Gruppieren nach | Agrupar por | Grouper par |
| `diveSites_list_groupBy_location` | Country & region | الدولة والمنطقة | Land und Region | País y región | Pays et région |
| `diveSites_list_groupBy_none` | None | بلا | Keine | Ninguno | Aucun |
| `diveSites_picker_nearby` | Nearby | قريب | In der Nähe | Cerca | À proximité |

| key | he | hu | it | nl | pt | zh |
| --- | --- | --- | --- | --- | --- | --- |
| `diveLog_filter_clearSite` | נקה מסנן אתר | Merülőhely-szűrő törlése | Cancella filtro sito | Stekfilter wissen | Limpar filtro de ponto | 清除潜水点筛选 |
| `diveSites_group_noCountry` | ללא מדינה | Nincs ország | Nessun paese | Geen land | Sem país | 无国家 |
| `diveSites_group_siteCount` | `{count, plural, =1{אתר אחד} other{{count} אתרים}}` | `{count, plural, =1{1 merülőhely} other{{count} merülőhely}}` | `{count, plural, =1{1 sito} other{{count} siti}}` | `{count, plural, =1{1 stek} other{{count} stekken}}` | `{count, plural, =1{1 ponto} other{{count} pontos}}` | `{count, plural, other{{count} 个潜水点}}` |
| `diveSites_list_groupBy` | קיבוץ לפי | Csoportosítás | Raggruppa per | Groeperen op | Agrupar por | 分组方式 |
| `diveSites_list_groupBy_location` | מדינה ואזור | Ország és régió | Paese e regione | Land en regio | País e região | 国家和地区 |
| `diveSites_list_groupBy_none` | ללא | Nincs | Nessuno | Geen | Nenhum | 无 |
| `diveSites_picker_nearby` | בקרבת מקום | A közelben | Nelle vicinanze | In de buurt | Por perto | 附近 |

- [ ] **Step 2: Regenerate l10n**

Run: `flutter gen-l10n`
Expected: no output errors; `git status` shows the 11 ARB files plus the generated `app_localizations*.dart` files modified.

- [ ] **Step 3: Write the failing widget test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/utils/site_grouping.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_picker/grouped_site_list_view.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Widget _host(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  home: Scaffold(body: child),
);

void main() {
  group('siteGroupedSubtitle', () {
    test('joins locality and body of water', () {
      expect(
        siteGroupedSubtitle(
          const DiveSite(id: 'a', name: 'A', city: 'Dahab', bodyOfWater: 'Red Sea'),
        ),
        'Dahab · Red Sea',
      );
    });

    test('falls back to the island and drops blanks', () {
      expect(
        siteGroupedSubtitle(
          const DiveSite(id: 'a', name: 'A', city: ' ', island: 'Bonaire'),
        ),
        'Bonaire',
      );
      expect(siteGroupedSubtitle(const DiveSite(id: 'a', name: 'A')), isNull);
    });
  });

  testWidgets('country header shows label, count and toggles', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        SiteCountryHeader(
          label: 'Australia',
          siteCount: 3,
          isExpanded: false,
          onTap: () => taps++,
        ),
      ),
    );
    expect(find.text('Australia'), findsOneWidget);
    expect(find.text('3 sites'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    await tester.tap(find.text('Australia'));
    expect(taps, 1);
  });

  testWidgets('the no-country group gets its localized label', (tester) async {
    late String label;
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) {
            final group = groupSitesByLocation(
              const [DiveSite(id: 'a', name: 'A')],
              (s) => s,
            ).single;
            label = countryGroupLabel(AppLocalizations.of(context), group);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(label, 'No country');
  });
}
```

- [ ] **Step 4: Run test to verify it fails**

Run: `flutter test test/features/dive_sites/presentation/widgets/site_picker/grouped_site_list_view_test.dart`
Expected: FAIL, `grouped_site_list_view.dart` does not exist.

- [ ] **Step 5: Write the implementation**

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/utils/site_grouping.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The location a site row shows under its name inside a country group: the
/// parts the country and region headers above it do not already state.
/// Locality prefers the city, falling back to the island.
String? siteGroupedSubtitle(DiveSite site) {
  final city = site.city?.trim() ?? '';
  final locality = city.isNotEmpty ? city : (site.island?.trim() ?? '');
  final water = site.bodyOfWater?.trim() ?? '';
  final parts = [locality, water].where((part) => part.isNotEmpty);
  return parts.isEmpty ? null : parts.join(' · ');
}

/// A country group's header text, naming the no-country group.
String countryGroupLabel(
  AppLocalizations l10n,
  SiteCountryGroup<Object?> group,
) => group.isNoCountry ? l10n.diveSites_group_noCountry : group.label;

/// Tappable header that opens or closes one country group.
///
/// A plain row rather than a ListTile: the site count is text, and text in
/// ListTile.trailing squeezes the title (#2717).
class SiteCountryHeader extends StatelessWidget {
  const SiteCountryHeader({
    super.key,
    required this.label,
    required this.siteCount,
    required this.isExpanded,
    required this.onTap,
  });

  final String label;
  final int siteCount;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      expanded: isExpanded,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Icon(
                isExpanded ? Icons.expand_more : Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n.diveSites_group_siteCount(siteCount),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small section label: a region inside a country group, or the picker's
/// Nearby section.
class SiteSectionLabel extends StatelessWidget {
  const SiteSectionLabel(this.text, {super.key, this.indent = 16});

  final String text;
  final double indent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(indent, 8, 16, 4),
        child: Text(
          text,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
```

If `flutter analyze` reports that `Semantics` has no `expanded` parameter on this SDK, drop that one argument and keep `button: true`.

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/features/dive_sites/presentation/widgets/site_picker/grouped_site_list_view_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
dart format lib/features/dive_sites/presentation/widgets/site_picker test/features/dive_sites/presentation/widgets/site_picker
git add lib/l10n/arb lib/features/dive_sites/presentation/widgets/site_picker/grouped_site_list_view.dart test/features/dive_sites/presentation/widgets/site_picker/grouped_site_list_view_test.dart
git commit -m "feat(dive-sites): country and region headers for grouped site lists"
```

---

### Task 4: Shared site picker sheet

**Files:**
- Create: `lib/features/dive_sites/presentation/widgets/site_picker/site_picker_site_tile.dart`
- Create: `lib/features/dive_sites/presentation/widgets/site_picker/site_picker_sheet.dart`
- Move and rewrite: `test/features/dive_log/presentation/widgets/pickers/site_picker_sheet_test.dart` to `test/features/dive_sites/presentation/widgets/site_picker/site_picker_sheet_test.dart`
- Move: `test/features/dive_log/presentation/widgets/pickers/pick_or_create_site_test.dart` to `test/features/dive_sites/presentation/widgets/site_picker/pick_or_create_site_test.dart` (import path change only)
- Modify (import path only): `lib/features/dive_log/presentation/pages/dive_edit_page.dart`, `lib/features/nav_track/presentation/pages/nav_track_detail_page.dart`, `lib/features/nav_track/presentation/pages/nav_track_import_review_page.dart`, `test/features/nav_track/presentation/pages/nav_track_detail_page_test.dart`
- Delete: `lib/features/dive_log/presentation/widgets/pickers/site_picker_sheet.dart`, `lib/features/dive_log/presentation/utils/site_picker_search.dart`, `test/features/dive_log/presentation/utils/site_picker_search_test.dart`

**Interfaces:**
- Consumes: `SiteQuery`, `normalizedSiteSearchText` (Task 1); `groupSitesByLocation`, `flattenSiteGroups`, `initialExpandedCountries`, `allCountryKeys`, `SiteListRow` types (Task 2); `SiteCountryHeader`, `SiteSectionLabel`, `siteGroupedSubtitle`, `countryGroupLabel`, l10n keys (Task 3).
- Produces:
  - `sealed class SitePickerResult` with `SitePicked(DiveSite site)`, `SitePickerCleared()`, `SitePickerCreateRequested()`
  - `Future<SitePickerResult?> showSitePicker(BuildContext context, {String? selectedSiteId, LocationResult? currentLocation, GeoPoint? diveLocation, bool allowCreate = false, bool allowClear = false, bool useDeviceLocation = true})` (null when dismissed)
  - `Future<DiveSite?> pickOrCreateSite(BuildContext context, WidgetRef ref, {required String? selectedSiteId, LocationResult? currentLocation, GeoPoint? diveLocation, GeoPoint? newSiteSeedLocation, bool allowCreate = true})` (signature unchanged)
  - `class SitePickerSheet extends ConsumerStatefulWidget { const SitePickerSheet({Key? key, required ScrollController scrollController, required String? selectedSiteId, LocationResult? currentLocation, GeoPoint? diveLocation, required void Function(DiveSite) onSiteSelected, VoidCallback? onCreateNewSite, VoidCallback? onClear, bool useDeviceLocation = true}); }`
  - `const sitePickerListKey = Key('site-picker-list');`

- [ ] **Step 1: Move the tests and point them at the new path**

```bash
mkdir -p test/features/dive_sites/presentation/widgets/site_picker
git mv test/features/dive_log/presentation/widgets/pickers/site_picker_sheet_test.dart test/features/dive_sites/presentation/widgets/site_picker/site_picker_sheet_test.dart
git mv test/features/dive_log/presentation/widgets/pickers/pick_or_create_site_test.dart test/features/dive_sites/presentation/widgets/site_picker/pick_or_create_site_test.dart
```

In both moved files, and in `test/features/nav_track/presentation/pages/nav_track_detail_page_test.dart`, replace
`package:submersion/features/dive_log/presentation/widgets/pickers/site_picker_sheet.dart` with
`package:submersion/features/dive_sites/presentation/widgets/site_picker/site_picker_sheet.dart`.

- [ ] **Step 2: Rewrite the sheet tests for the grouped list**

In `site_picker_sheet_test.dart`, keep the fakes, `_pump` and the empty-state, header-create, location-fallback, progress-caption, device-request and imperial-units tests. Add `onClear` and `useDeviceLocation` parameters to `_pump` and pass them to `SitePickerSheet`. Replace `_tileTitles` and the order-based tests with these (sites without a country form one auto-expanded "No country" group, so their rows are visible):

```dart
/// Titles of the rows in the picker list, top to bottom.
List<String> _rowTitles(WidgetTester tester) => tester
    .widgetList<ListTile>(
      find.descendant(
        of: find.byKey(sitePickerListKey),
        matching: find.byType(ListTile),
      ),
    )
    .map((tile) => (tile.title! as Text).data!)
    .toList();

testWidgets('lists sites within 50 km under Nearby, nearest first', (
  tester,
) async {
  await _pump(
    tester,
    sites: const [_farSite, _noGpsSite, _midSite, _nearSite],
    currentLocation: _here,
  );
  expect(find.text('Sorted by distance'), findsOneWidget);
  expect(find.text('Nearby'), findsOneWidget);
  // Nearby: near, mid. Then the single No country group, in name order as
  // the provider gives it.
  expect(_rowTitles(tester), [
    'House Reef',
    'Channel',
    'Blue Hole',
    'Mystery Lake',
    'Channel',
    'House Reef',
  ]);
  expect(find.text('0 m away'), findsOneWidget);
  expect(find.text('No country'), findsOneWidget);
});

testWidgets('a GPS site with no country is in Nearby and in No country', (
  tester,
) async {
  await _pump(tester, sites: const [_nearSite], currentLocation: _here);
  expect(find.text('House Reef'), findsNWidgets(2));
});

testWidgets('groups by country, collapsed except the selected country', (
  tester,
) async {
  await _pump(
    tester,
    selectedSiteId: 'au1',
    sites: const [
      DiveSite(id: 'au1', name: 'Cod Hole', country: 'Australia', region: 'Queensland'),
      DiveSite(id: 'eg1', name: 'Blue Hole', country: 'Egypt', city: 'Dahab', bodyOfWater: 'Red Sea'),
    ],
  );
  expect(find.text('Australia'), findsOneWidget);
  expect(find.text('Queensland'), findsOneWidget);
  expect(find.text('Cod Hole'), findsOneWidget);
  expect(find.text('Egypt'), findsOneWidget);
  expect(find.text('Blue Hole'), findsNothing);

  await tester.tap(find.text('Egypt'));
  await tester.pumpAndSettle();
  expect(find.text('Blue Hole'), findsOneWidget);
  expect(find.text('Dahab · Red Sea'), findsOneWidget);
});

testWidgets('searching opens every group with a match', (tester) async {
  await _pump(
    tester,
    sites: const [
      DiveSite(id: 'au1', name: 'Cod Hole', country: 'Australia'),
      DiveSite(id: 'eg1', name: 'Blue Hole', country: 'Egypt', bodyOfWater: 'Red Sea'),
      DiveSite(id: 'mx1', name: 'Angelita', country: 'Mexico'),
    ],
  );
  expect(find.text('Blue Hole'), findsNothing);

  await tester.enterText(find.byType(TextField), 'hole');
  await tester.pumpAndSettle();
  expect(_rowTitles(tester), ['Cod Hole', 'Blue Hole']);
  expect(find.text('Mexico'), findsNothing);

  await tester.enterText(find.byType(TextField), 'red sea');
  await tester.pumpAndSettle();
  expect(_rowTitles(tester), ['Blue Hole']);

  await tester.tap(find.byIcon(Icons.clear));
  await tester.pumpAndSettle();
  expect(_rowTitles(tester), isEmpty);
  expect(find.text('Mexico'), findsOneWidget);
});

testWidgets('a whitespace-only query keeps the manual expansion', (
  tester,
) async {
  await _pump(
    tester,
    sites: const [
      DiveSite(id: 'au1', name: 'Cod Hole', country: 'Australia'),
      DiveSite(id: 'eg1', name: 'Blue Hole', country: 'Egypt'),
    ],
  );
  await tester.enterText(find.byType(TextField), '   ');
  await tester.pumpAndSettle();
  expect(_rowTitles(tester), isEmpty);
});

testWidgets('filter mode offers an All sites row that clears', (tester) async {
  var cleared = 0;
  await _pump(tester, sites: const [_farSite], onClear: () => cleared++);
  await tester.tap(find.text('All sites'));
  expect(cleared, 1);
});

testWidgets('a selected id that no longer exists checks nothing', (
  tester,
) async {
  await _pump(tester, sites: const [_farSite], selectedSiteId: 'deleted');
  expect(find.byIcon(Icons.check_circle), findsNothing);
  expect(find.text('Blue Hole'), findsOneWidget);
});

testWidgets('does not ask for the device location when told not to', (
  tester,
) async {
  final service = _FakeLocationService(result: _here);
  await _pump(
    tester,
    sites: const [_nearSite],
    locationService: service,
    useDeviceLocation: false,
  );
  expect(service.calls, 0);
  expect(find.text('Nearby'), findsNothing);
});
```

Keep the existing "marks the selected site and selects on tap" and "search with no matches shows the no-results message" tests, changing the latter's `find.byType(ListTile)` to `find.descendant(of: find.byKey(sitePickerListKey), matching: find.byType(ListTile))`. Rewrite the two `sorts by diveLocation` / `falls back to currentLocation` tests to assert the Nearby rows (`_rowTitles(tester).take(2)` is `['House Reef', 'Channel']`) and the same hint text as today. Rewrite "falls back to device location" and "shows a progress caption" the same way: after the fix resolves, `find.text('Nearby')` finds one widget. Rewrite "keeps the provided order when no device fix is available" to expect `find.text('Nearby')` finds nothing and `_rowTitles(tester)` is the provider order.

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/features/dive_sites/presentation/widgets/site_picker/`
Expected: FAIL, `site_picker_sheet.dart` does not exist at the new path.

- [ ] **Step 4: Write the site tile**

`site_picker_site_tile.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// One site in the site picker: the avatar marks the selected site (primary)
/// or a nearby one (tertiary), the subtitle carries its location and, in the
/// Nearby section, its distance.
class SitePickerSiteTile extends StatelessWidget {
  const SitePickerSiteTile({
    super.key,
    required this.site,
    required this.isSelected,
    required this.isNearby,
    required this.subtitle,
    required this.onTap,
    this.distanceText,
  });

  final DiveSite site;
  final bool isSelected;
  final bool isNearby;
  final String? subtitle;
  final String? distanceText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isSelected
            ? colorScheme.primaryContainer
            : isNearby
            ? colorScheme.tertiaryContainer
            : colorScheme.surfaceContainerHighest,
        child: Icon(
          isNearby ? Icons.near_me : Icons.location_on,
          color: isSelected
              ? colorScheme.onPrimaryContainer
              : isNearby
              ? colorScheme.onTertiaryContainer
              : colorScheme.onSurfaceVariant,
        ),
      ),
      title: Text(site.name),
      subtitle: subtitle == null && distanceText == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subtitle != null) Text(subtitle!),
                if (distanceText != null)
                  Text(
                    distanceText!,
                    style: textTheme.bodySmall?.copyWith(
                      color: isNearby
                          ? colorScheme.tertiary
                          : colorScheme.onSurfaceVariant,
                      fontWeight: isNearby ? FontWeight.w600 : null,
                    ),
                  ),
              ],
            ),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: colorScheme.primary)
          : null,
      onTap: onTap,
    );
  }
}
```

- [ ] **Step 5: Write the sheet**

Create `site_picker_sheet.dart` by moving the old `lib/features/dive_log/presentation/widgets/pickers/site_picker_sheet.dart` here with `git mv` (so history follows), then rewrite it as below. Keep the old file's header block, device-location resolution (`_resolveDeviceLocation`, `_anchor`, `_distanceToSite`, `_formatDistance`), empty state and `SimilarValueHint` block verbatim except where shown.

```bash
git mv lib/features/dive_log/presentation/widgets/pickers/site_picker_sheet.dart lib/features/dive_sites/presentation/widgets/site_picker/site_picker_sheet.dart
git rm lib/features/dive_log/presentation/utils/site_picker_search.dart test/features/dive_log/presentation/utils/site_picker_search_test.dart
```

Top of file (results, `showSitePicker`, `pickOrCreateSite`):

```dart
/// Identifies the picker's scrolling list, for tests.
const sitePickerListKey = Key('site-picker-list');

/// What the site picker resolved to. Dismissing the sheet resolves to null.
sealed class SitePickerResult {
  const SitePickerResult();
}

/// The diver picked [site].
final class SitePicked extends SitePickerResult {
  const SitePicked(this.site);

  final DiveSite site;
}

/// The diver chose "All sites" (filter use only).
final class SitePickerCleared extends SitePickerResult {
  const SitePickerCleared();
}

/// The diver tapped "New Dive Site".
final class SitePickerCreateRequested extends SitePickerResult {
  const SitePickerCreateRequested();
}

/// Opens [SitePickerSheet] in a draggable bottom sheet.
///
/// [allowCreate] adds the "New Dive Site" button, [allowClear] the leading
/// "All sites" row a filter needs. [useDeviceLocation] lets the sheet ask for
/// a GPS fix when the caller gave no location; a filter or a media review
/// passes false so opening it never prompts for location.
Future<SitePickerResult?> showSitePicker(
  BuildContext context, {
  String? selectedSiteId,
  LocationResult? currentLocation,
  GeoPoint? diveLocation,
  bool allowCreate = false,
  bool allowClear = false,
  bool useDeviceLocation = true,
}) {
  return showModalBottomSheet<SitePickerResult>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (sheetContext, scrollController) => SitePickerSheet(
        scrollController: scrollController,
        selectedSiteId: selectedSiteId,
        currentLocation: currentLocation,
        diveLocation: diveLocation,
        useDeviceLocation: useDeviceLocation,
        onSiteSelected: (site) =>
            Navigator.of(sheetContext).pop(SitePicked(site)),
        onCreateNewSite: allowCreate
            ? () => Navigator.of(
                sheetContext,
              ).pop(const SitePickerCreateRequested())
            : null,
        onClear: allowClear
            ? () => Navigator.of(sheetContext).pop(const SitePickerCleared())
            : null,
      ),
    ),
  );
}

/// Opens the site picker and, on "New Dive Site", pushes the new-site form
/// seeded with [newSiteSeedLocation] and resolves once the site is saved.
///
/// Returns the picked or newly created [DiveSite], or null if the sheet was
/// dismissed or the new-site form was cancelled.
Future<DiveSite?> pickOrCreateSite(
  BuildContext context,
  WidgetRef ref, {
  required String? selectedSiteId,
  LocationResult? currentLocation,
  GeoPoint? diveLocation,
  GeoPoint? newSiteSeedLocation,
  bool allowCreate = true,
}) async {
  final result = await showSitePicker(
    context,
    selectedSiteId: selectedSiteId,
    currentLocation: currentLocation,
    diveLocation: diveLocation,
    allowCreate: allowCreate,
  );
  switch (result) {
    case SitePicked(:final site):
      return site;
    case SitePickerCreateRequested():
      if (!context.mounted) return null;
      final newSiteId = await context.push<String>(
        '/sites/new',
        extra: newSiteSeedLocation,
      );
      if (newSiteId == null || !context.mounted) return null;
      return ref.read(siteProvider(newSiteId).future);
    case SitePickerCleared() || null:
      return null;
  }
}
```

Widget fields: add `final VoidCallback? onClear;` and `final bool useDeviceLocation;` (constructor default `true`). In `initState`, guard the device lookup with `widget.useDeviceLocation &&`.

State additions:

```dart
  /// Countries the diver opened or closed by hand; null until the first
  /// build with data, which seeds it from [initialExpandedCountries].
  Set<String>? _manualExpanded;

  /// Countries the diver closed while the current query is active. Cleared
  /// whenever the query changes, since a new query opens every match again.
  Set<String> _searchCollapsed = const {};

  /// Each site's normalized search text, rebuilt only when the site list
  /// itself changes, so a keystroke costs one substring test per site.
  List<DiveSite>? _indexedSites;
  Map<String, String> _searchIndex = const {};

  Map<String, String> _searchIndexFor(List<DiveSite> sites) {
    if (!identical(sites, _indexedSites)) {
      _indexedSites = sites;
      _searchIndex = {
        for (final site in sites) site.id: normalizedSiteSearchText(site),
      };
    }
    return _searchIndex;
  }

  void _onQueryChanged(String value) => setState(() {
    _searchQuery = value;
    _searchCollapsed = const {};
  });

  void _toggleCountry(String key, {required bool searching}) {
    setState(() {
      if (searching) {
        _searchCollapsed = _searchCollapsed.contains(key)
            ? (_searchCollapsed.toSet()..remove(key))
            : {..._searchCollapsed, key};
      } else {
        final current = _manualExpanded ?? const <String>{};
        _manualExpanded = current.contains(key)
            ? (current.toSet()..remove(key))
            : {...current, key};
      }
    });
  }
```

The search field's `onChanged` calls `_onQueryChanged`; its clear button calls `_searchController.clear(); _onQueryChanged('');`. The `SimilarValueHint` block uses `final query = SiteQuery(_searchQuery);` and `hidden = sites.where((s) => !query.matchesSite(s))`.

Replace the old `data:` list branch (from `// Sort sites by distance` to the end of the `ListView.builder`) with:

```dart
              final query = SiteQuery(_searchQuery);
              final index = _searchIndexFor(sites);
              final visible = query.isEmpty
                  ? sites
                  : sites
                        .where((site) => query.matches(index[site.id]!))
                        .toList();
              if (visible.isEmpty) {
                return Center(
                  child: Text(
                    context.l10n.diveSites_list_search_noResults(
                      _searchQuery.trim(),
                    ),
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                );
              }

              final selected = sites
                  .where((site) => site.id == widget.selectedSiteId)
                  .firstOrNull;
              final groups = groupSitesByLocation(visible, (site) => site);
              _manualExpanded ??= initialExpandedCountries(
                groupSitesByLocation(sites, (site) => site),
                selected: selected,
              );
              final searching = !query.isEmpty;
              final expanded = searching
                  ? allCountryKeys(groups).difference(_searchCollapsed)
                  : _manualExpanded!;

              final nearby = [
                for (final site in visible)
                  if (_distanceToSite(site) case final d? when d < 50000)
                    (site: site, distance: d),
              ]..sort((a, b) => a.distance.compareTo(b.distance));

              final rows = <Widget Function()>[
                if (widget.onClear != null)
                  () => ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.public)),
                    title: Text(context.l10n.diveLog_filter_allSites),
                    trailing: widget.selectedSiteId == null
                        ? Icon(Icons.check_circle, color: colorScheme.primary)
                        : null,
                    onTap: widget.onClear,
                  ),
                if (nearby.isNotEmpty) ...[
                  () => SiteSectionLabel(context.l10n.diveSites_picker_nearby),
                  for (final entry in nearby)
                    () => SitePickerSiteTile(
                      site: entry.site,
                      isSelected: entry.site.id == widget.selectedSiteId,
                      isNearby: true,
                      subtitle: entry.site.locationString.isEmpty
                          ? null
                          : entry.site.locationString,
                      distanceText: _formatDistance(
                        context,
                        units,
                        entry.distance,
                      ),
                      onTap: () => widget.onSiteSelected(entry.site),
                    ),
                ],
                for (final row in flattenSiteGroups(groups, expanded: expanded))
                  switch (row) {
                    CountryHeaderRow(:final group, :final isExpanded) =>
                      () => SiteCountryHeader(
                        label: countryGroupLabel(context.l10n, group),
                        siteCount: group.siteCount,
                        isExpanded: isExpanded,
                        onTap: () =>
                            _toggleCountry(group.key, searching: searching),
                      ),
                    RegionHeaderRow(:final label) =>
                      () => SiteSectionLabel(label, indent: 56),
                    SiteRow(:final item) => () => SitePickerSiteTile(
                      site: item,
                      isSelected: item.id == widget.selectedSiteId,
                      isNearby: false,
                      subtitle: siteGroupedSubtitle(item),
                      onTap: () => widget.onSiteSelected(item),
                    ),
                  },
              ];

              return ListView.builder(
                key: sitePickerListKey,
                controller: widget.scrollController,
                itemCount: rows.length,
                itemBuilder: (context, i) => rows[i](),
              );
```

Delete the `_SiteWithDistance` class. Imports: add `site_search.dart`, `site_grouping.dart`, `grouped_site_list_view.dart`, `site_picker_site_tile.dart`; remove `site_picker_search.dart`, and `fuzzy_match.dart` if `findSimilar` now comes only from `similar_value_hint.dart` (keep whichever import still provides `findSimilar`). `firstOrNull` comes from `package:collection/collection.dart` if the SDK extension is not in scope; check `flutter analyze`.

- [ ] **Step 6: Point the callers at the new path**

In `dive_edit_page.dart`, `nav_track_detail_page.dart` and `nav_track_import_review_page.dart`, replace the import of `package:submersion/features/dive_log/presentation/widgets/pickers/site_picker_sheet.dart` with `package:submersion/features/dive_sites/presentation/widgets/site_picker/site_picker_sheet.dart`. `pickOrCreateSite` calls stay unchanged.

- [ ] **Step 7: Run tests to verify they pass**

Run: `flutter test test/features/dive_sites/presentation/widgets/site_picker/ test/features/nav_track/presentation/pages/nav_track_detail_page_test.dart test/features/dive_log/presentation/pages/`
Expected: PASS.

Run: `flutter analyze lib/features/dive_sites lib/features/dive_log lib/features/nav_track`
Expected: No issues found.

- [ ] **Step 8: Commit**

```bash
dart format lib/features/dive_sites lib/features/dive_log lib/features/nav_track test/features/dive_sites test/features/nav_track
git add -A lib/features/dive_sites/presentation/widgets/site_picker test/features/dive_sites/presentation/widgets/site_picker lib/features/dive_log/presentation/pages/dive_edit_page.dart lib/features/nav_track/presentation/pages/nav_track_detail_page.dart lib/features/nav_track/presentation/pages/nav_track_import_review_page.dart test/features/nav_track/presentation/pages/nav_track_detail_page_test.dart
git status --short
git commit -m "feat(dive-sites): one grouped, searchable site picker sheet"
git show --stat HEAD
```

Check `git show --stat` lists the two deletions and the moves; if a deleted path is missing, `git rm` it and amend.

---

### Task 5: Media import review uses the shared sheet

**Files:**
- Modify: `lib/features/media/presentation/pages/media_import_review_page.dart:67-71`
- Delete: `lib/features/media/presentation/widgets/site_picker_sheet.dart`
- Move and rewrite: `test/features/media/presentation/widgets/site_picker_sheet_test.dart` to `test/features/media/presentation/pages/media_import_review_site_picker_test.dart`

**Interfaces:**
- Consumes: `showSitePicker`, `SitePicked` (Task 4).

- [ ] **Step 1: Rewrite the test against `showSitePicker` as media calls it**

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_picker/site_picker_sheet.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  Widget host(
    void Function(SitePickerResult?) onPicked, {
    Future<List<DiveSite>> Function()? load,
  }) {
    return ProviderScope(
      overrides: [
        sitesProvider.overrideWith(
          (ref) =>
              load?.call() ??
              Future.value(const [
                DiveSite(id: 's1', name: 'Blue Hole'),
                DiveSite(id: 's2', name: 'Elphinstone'),
              ]),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => onPicked(
                await showSitePicker(context, useDeviceLocation: false),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('picking a site resolves it, with a search bar and no create', (
    tester,
  ) async {
    SitePickerResult? picked;
    await tester.pumpWidget(host((r) => picked = r));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('New Dive Site'), findsNothing);
    await tester.tap(find.text('Elphinstone'));
    await tester.pumpAndSettle();

    expect((picked! as SitePicked).site.id, 's2');
  });

  testWidgets('shows a spinner while sites are still loading', (tester) async {
    final pending = Completer<List<DiveSite>>();
    await tester.pumpWidget(host((_) {}, load: () => pending.future));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete(const []);
    await tester.pumpAndSettle();
  });

  testWidgets('dismissing resolves null', (tester) async {
    SitePickerResult? picked = const SitePickerCleared();
    await tester.pumpWidget(host((r) => picked = r));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(picked, isNull);
  });
}
```

```bash
git mv test/features/media/presentation/widgets/site_picker_sheet_test.dart test/features/media/presentation/pages/media_import_review_site_picker_test.dart
```

Then overwrite the moved file with the code above.

- [ ] **Step 2: Run it to verify it passes against Task 4's sheet**

Run: `flutter test test/features/media/presentation/pages/media_import_review_site_picker_test.dart`
Expected: PASS (this pins the media call shape before the page changes).

- [ ] **Step 3: Change the page and delete the old sheet**

In `media_import_review_page.dart` replace `_chooseSite` with:

```dart
  Future<void> _chooseSite(ImportCandidate c) async {
    final result = await showSitePicker(context, useDeviceLocation: false);
    if (result is! SitePicked || !mounted) return;
    setState(() => _overrides[c.key] = SiteAttachTarget(result.site.id));
  }
```

Swap its import of `package:submersion/features/media/presentation/widgets/site_picker_sheet.dart` for `package:submersion/features/dive_sites/presentation/widgets/site_picker/site_picker_sheet.dart`.

```bash
git rm lib/features/media/presentation/widgets/site_picker_sheet.dart
```

- [ ] **Step 4: Run the media tests**

Run: `flutter test test/features/media/ && flutter analyze lib/features/media`
Expected: PASS, No issues found.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/media test/features/media
git add -A lib/features/media test/features/media
git commit -m "feat(media): pick a site from the grouped, searchable site picker"
git show --stat HEAD
```

---

### Task 6: Refine panel site field

**Files:**
- Create: `lib/features/dive_sites/presentation/widgets/site_picker/site_picker_field.dart`
- Modify: `lib/features/dive_log/presentation/widgets/refine/groups/refine_location_group.dart:43-70`
- Test: `test/features/dive_sites/presentation/widgets/site_picker/site_picker_field_test.dart`
- Modify test: `test/features/dive_log/presentation/widgets/refine/groups/refine_small_groups_test.dart:92-101`

**Interfaces:**
- Consumes: `showSitePicker`, `SitePicked`, `SitePickerCleared`, `sitePickerListKey` (Task 4); `diveLog_filter_clearSite` (Task 3).
- Produces: `class SitePickerField extends ConsumerWidget { const SitePickerField({Key? key, required String? value, required ValueChanged<String?> onChanged}); }`, `const sitePickerFieldKey = Key('site-picker-field');`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_picker/site_picker_field.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_picker/site_picker_sheet.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

const _sites = [
  DiveSite(id: 's1', name: 'Blue Hole', country: 'Egypt', city: 'Dahab'),
  DiveSite(id: 's2', name: 'Coral Garden', country: 'Mexico'),
];

Future<List<String?>> _pump(WidgetTester tester, String? value) async {
  final changes = <String?>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sitesProvider.overrideWith((ref) async => _sites)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: SitePickerField(value: value, onChanged: changes.add),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return changes;
}

void main() {
  testWidgets('shows All sites when nothing is selected', (tester) async {
    await _pump(tester, null);
    expect(find.text('All sites'), findsOneWidget);
    expect(find.byTooltip('Clear site filter'), findsNothing);
  });

  testWidgets('shows the selected site with its location', (tester) async {
    await _pump(tester, 's1');
    expect(find.text('Blue Hole'), findsOneWidget);
    expect(find.text('Dahab · Egypt'), findsOneWidget);
  });

  testWidgets('a deleted site id falls back to All sites', (tester) async {
    await _pump(tester, 'gone');
    expect(find.text('All sites'), findsOneWidget);
  });

  testWidgets('tapping opens the sheet, searching and picking sets the id', (
    tester,
  ) async {
    final changes = await _pump(tester, null);
    await tester.tap(find.byKey(sitePickerFieldKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'mexico');
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(sitePickerListKey),
        matching: find.text('Coral Garden'),
      ),
    );
    await tester.pumpAndSettle();
    expect(changes, ['s2']);
  });

  testWidgets('All sites in the sheet clears the filter', (tester) async {
    final changes = await _pump(tester, 's1');
    await tester.tap(find.byKey(sitePickerFieldKey));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(sitePickerListKey),
        matching: find.text('All sites'),
      ),
    );
    await tester.pumpAndSettle();
    expect(changes, [null]);
  });

  testWidgets('the clear button clears without opening the sheet', (
    tester,
  ) async {
    final changes = await _pump(tester, 's1');
    await tester.tap(find.byTooltip('Clear site filter'));
    await tester.pumpAndSettle();
    expect(changes, [null]);
    expect(find.byKey(sitePickerListKey), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_sites/presentation/widgets/site_picker/site_picker_field_test.dart`
Expected: FAIL, `site_picker_field.dart` does not exist.

- [ ] **Step 3: Write the field**

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_picker/site_picker_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Identifies the field's tap target, for tests.
const sitePickerFieldKey = Key('site-picker-field');

/// A dive filter's site field: shows the selected site (or "All sites") and
/// opens the shared site picker sheet on tap (#1080).
///
/// The value is always a site id or null; an id whose site has been deleted
/// shows "All sites", like the filter it stands for.
class SitePickerField extends ConsumerWidget {
  const SitePickerField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String? value;
  final ValueChanged<String?> onChanged;

  Future<void> _open(BuildContext context) async {
    final result = await showSitePicker(
      context,
      selectedSiteId: value,
      allowClear: true,
      useDeviceLocation: false,
    );
    switch (result) {
      case SitePicked(:final site):
        onChanged(site.id);
      case SitePickerCleared():
        onChanged(null);
      case SitePickerCreateRequested() || null:
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final sites = ref.watch(sitesProvider).value ?? const [];
    final site = sites.where((s) => s.id == value).firstOrNull;
    final location = site?.locationString ?? '';

    return InkWell(
      key: sitePickerFieldKey,
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: l10n.diveLog_search_label_diveSite,
          prefixIcon: const Icon(Icons.location_on),
          suffixIcon: site == null
              ? const Icon(Icons.arrow_drop_down)
              : IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: l10n.diveLog_filter_clearSite,
                  onPressed: () => onChanged(null),
                ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(site?.name ?? l10n.diveLog_filter_allSites),
            if (location.isNotEmpty)
              Text(
                location,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Use it in the Refine Location group**

In `refine_location_group.dart` replace the `data: (sites) => SearchableFilterDropdown<String>(...)` for the site with:

```dart
              data: (_) => SitePickerField(
                value: draft.siteId,
                onChanged: (v) => onChanged(
                  draft.copyWith(siteId: v, clearSiteId: v == null),
                ),
              ),
```

Add the import `package:submersion/features/dive_sites/presentation/widgets/site_picker/site_picker_field.dart`. Keep the trip and center dropdowns unchanged.

- [ ] **Step 5: Update the Refine group test**

In `refine_small_groups_test.dart`, replace the site line of `site by country, trip by place, center by city`:

```dart
      await tester.tap(find.byKey(sitePickerFieldKey));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(TextField),
        ),
        'mexico',
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byKey(sitePickerListKey),
          matching: find.text('Coral Garden'),
        ),
      );
      await tester.pumpAndSettle();
      expect(h.draft.siteId, 's2');
```

and add imports for `site_picker_field.dart` and `site_picker_sheet.dart`.

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/features/dive_sites/presentation/widgets/site_picker/ test/features/dive_log/presentation/widgets/refine/`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
dart format lib/features/dive_sites lib/features/dive_log test/features/dive_sites test/features/dive_log
git add lib/features/dive_sites/presentation/widgets/site_picker/site_picker_field.dart test/features/dive_sites/presentation/widgets/site_picker/site_picker_field_test.dart lib/features/dive_log/presentation/widgets/refine/groups/refine_location_group.dart test/features/dive_log/presentation/widgets/refine/groups/refine_small_groups_test.dart
git commit -m "feat(dive-log): pick the filter's dive site from the site picker sheet"
```

---

### Task 7: Group the Dive Sites page

**Files:**
- Create: `lib/features/dive_sites/presentation/providers/site_grouping_providers.dart`
- Create: `lib/features/dive_sites/presentation/widgets/site_group_by_selector.dart`
- Modify: `lib/shared/widgets/sort_bottom_sheet.dart`
- Modify: `lib/features/dive_sites/presentation/widgets/site_list_content.dart` (`_scrollToSelectedItem` ~156-182, `_showSortSheet` ~569-590, `_buildSiteList` ~1101-1162)
- Test: `test/features/dive_sites/presentation/widgets/site_list_content_grouped_test.dart`
- Test: `test/shared/widgets/sort_bottom_sheet_test.dart` (create if absent; add the footer test)

**Interfaces:**
- Consumes: Task 2 grouping, Task 3 headers and strings.
- Produces:
  - `enum SiteGroupBy { none, location }`
  - `final siteGroupByProvider = StateProvider<SiteGroupBy>((ref) => SiteGroupBy.none);`
  - `final siteListExpandedCountriesProvider = StateProvider<Set<String>?>((ref) => null);` (null until the diver first toggles)
  - `SortBottomSheet({..., Widget? footer})`, `showSortBottomSheet({..., Widget? footer})`
  - `class SiteGroupBySelector extends ConsumerWidget`

- [ ] **Step 1: Write the failing tests**

`test/shared/widgets/sort_bottom_sheet_test.dart` (append a test if the file exists):

```dart
  testWidgets('renders an optional footer under the fields', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: SortBottomSheet<SiteSortField>(
            title: 'Sort Sites',
            currentField: SiteSortField.name,
            currentDirection: SortDirection.descending,
            fields: SiteSortField.values,
            getFieldDisplayName: (f) => f.displayName,
            getFieldIcon: (f) => f.icon,
            onSortChanged: (_, _) {},
            footer: const Text('footer here'),
          ),
        ),
      ),
    );
    expect(find.text('footer here'), findsOneWidget);
  });
```

`site_list_content_grouped_test.dart`: copy the imports, `_setMobileTestSurfaceSize`, `_buildPhoneOverrides` and `_MockSiteListNotifier` from `site_list_content_test.dart` (adding `country`/`region` to the site factory), then:

```dart
SiteWithDiveCount _site(String id, String name, {String? country, String? region}) =>
    SiteWithDiveCount(
      site: DiveSite(id: id, name: name, country: country, region: region),
      diveCount: 0,
    );

final _sites = [
  _site('au1', 'Cod Hole', country: 'Australia', region: 'Queensland'),
  _site('eg1', 'Blue Hole', country: 'Egypt'),
  _site('xx1', 'Mystery Lake'),
];

Future<void> _pumpGrouped(
  WidgetTester tester, {
  ListViewMode viewMode = ListViewMode.detailed,
  String? selectedId,
}) async {
  _setMobileTestSurfaceSize(tester);
  final overrides = await _buildPhoneOverrides(sites: _sites, viewMode: viewMode);
  await tester.pumpWidget(
    testApp(
      overrides: [
        ...overrides,
        siteGroupByProvider.overrideWith((ref) => SiteGroupBy.location),
      ],
      child: SiteListContent(showAppBar: true, selectedId: selectedId),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('grouped list starts collapsed with country headers', (
    tester,
  ) async {
    await _pumpGrouped(tester);
    expect(find.text('Australia'), findsOneWidget);
    expect(find.text('Egypt'), findsOneWidget);
    expect(find.text('No country'), findsOneWidget);
    expect(find.byType(SiteListTile), findsNothing);

    await tester.tap(find.text('Australia'));
    await tester.pumpAndSettle();
    expect(find.text('Queensland'), findsOneWidget);
    expect(find.byType(SiteListTile), findsOneWidget);
  });

  testWidgets('opens the country of the site shown in the detail pane', (
    tester,
  ) async {
    await _pumpGrouped(tester, selectedId: 'eg1');
    expect(find.byType(SiteListTile), findsOneWidget);
    expect(find.text('Blue Hole'), findsWidgets);
  });

  testWidgets('expansion survives a rebuild of the list', (tester) async {
    await _pumpGrouped(tester);
    await tester.tap(find.text('Egypt'));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SiteListContent)),
    );
    expect(
      container.read(siteListExpandedCountriesProvider),
      contains(siteCountryKey(const DiveSite(id: 'x', name: 'x', country: 'Egypt'))),
    );
  });

  testWidgets('compact mode groups too', (tester) async {
    await _pumpGrouped(tester, viewMode: ListViewMode.compact);
    await tester.tap(find.text('No country'));
    await tester.pumpAndSettle();
    expect(find.byType(CompactSiteListTile), findsOneWidget);
  });

  testWidgets('a header tap in selection mode toggles, never selects', (
    tester,
  ) async {
    await _pumpGrouped(tester);
    await tester.tap(find.text('Egypt'));
    await tester.pumpAndSettle();
    await tester.longPress(find.byType(SiteListTile));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);

    await tester.tap(find.text('Australia'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
    expect(find.text('Queensland'), findsOneWidget);
  });
}
```

Before relying on `'1 selected'`, open `site_list_content_test.dart` and copy the exact selection-count text and long-press entry it already asserts (the `selection_contract.dart` helper names it); use that instead if it differs. Add one more test using that file's select-all helper (`select_items_menu.dart`): with only Egypt expanded, select all, and assert the selection count is 3 (sites in collapsed groups included).

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/shared/widgets/sort_bottom_sheet_test.dart test/features/dive_sites/presentation/widgets/site_list_content_grouped_test.dart`
Expected: FAIL, no `footer` parameter and no `site_grouping_providers.dart`.

- [ ] **Step 3: Add the providers**

```dart
import 'package:submersion/core/providers/provider.dart';

/// How the Dive Sites list is grouped (#1080). Session-only, like the list's
/// sort.
enum SiteGroupBy { none, location }

final siteGroupByProvider = StateProvider<SiteGroupBy>(
  (ref) => SiteGroupBy.none,
);

/// Country groups the diver has opened on the grouped Dive Sites list. Null
/// until the first toggle, so the list can open the selected site's country
/// without writing state during build. Kept in a provider so opening a site
/// and coming back keeps the list as the diver left it.
final siteListExpandedCountriesProvider = StateProvider<Set<String>?>(
  (ref) => null,
);
```

Check how `StateProvider` is imported in `site_providers.dart` (it uses `core/providers/provider.dart`); match it.

- [ ] **Step 4: Add the sort sheet footer**

In `sort_bottom_sheet.dart`: add `final Widget? footer;` to `SortBottomSheet` (doc: "Extra controls under the field list, such as a list's group-by choice."), add `this.footer` to the constructor, and after the field `map(...)` in `build` insert:

```dart
            if (widget.footer != null) ...[
              const Divider(height: 1),
              widget.footer!,
            ],
```

Add `Widget? footer` to `showSortBottomSheet` and pass `footer: footer` through.

- [ ] **Step 5: Add the group-by selector**

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_grouping_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Dive Sites sort sheet's "Group by" control. Choosing closes the
/// sheet, as choosing a sort field does.
class SiteGroupBySelector extends ConsumerWidget {
  const SiteGroupBySelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.diveSites_list_groupBy,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          SegmentedButton<SiteGroupBy>(
            segments: [
              ButtonSegment(
                value: SiteGroupBy.none,
                label: Text(l10n.diveSites_list_groupBy_none),
              ),
              ButtonSegment(
                value: SiteGroupBy.location,
                icon: const Icon(Icons.public),
                label: Text(l10n.diveSites_list_groupBy_location),
              ),
            ],
            selected: {ref.watch(siteGroupByProvider)},
            showSelectedIcon: false,
            onSelectionChanged: (selected) {
              ref.read(siteGroupByProvider.notifier).state = selected.first;
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: Pass the footer from the Sites page**

In `site_list_content.dart` `_showSortSheet`, add:

```dart
      // Table mode keeps a flat grid; headers would cut across its columns.
      footer: ref.read(siteListViewModeProvider) == ListViewMode.table
          ? null
          : const SiteGroupBySelector(),
```

- [ ] **Step 7: Render grouped rows**

In `_buildSiteList`, extract the existing per-site `switch (viewMode)` into a method:

```dart
  Widget _buildSiteTile(
    SiteWithDiveCount siteData,
    List<SiteWithDiveCount> orderedSites,
    int diversCount,
  ) {
    // body: the existing lines from `final site = siteData.site;` through the
    // `switch (viewMode) { ... }`, with every `_handleRowTap(site.id, sites)`
    // changed to `_handleRowTap(site.id, orderedSites)`.
  }
```

Then build the list from either flat sites or grouped rows:

```dart
    final grouped =
        ref.watch(siteGroupByProvider) == SiteGroupBy.location;
    if (!grouped) {
      // existing ListView.builder, itemBuilder:
      //   (context, index) => _buildSiteTile(sites[index], sites, diversCount)
    }

    final groups = groupSitesByLocation(sites, (s) => s.site);
    // Range selection follows what the diver sees: group order.
    final orderedSites = [for (final g in groups) ...g.allItems];
    final expanded = _groupedExpansion(groups, sites);
    final rows = flattenSiteGroups(groups, expanded: expanded);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(sortedSitesWithCountsProvider),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: rows.length,
        itemBuilder: (context, index) => switch (rows[index]) {
          CountryHeaderRow(:final group, :final isExpanded) =>
            SiteCountryHeader(
              label: countryGroupLabel(context.l10n, group),
              siteCount: group.siteCount,
              isExpanded: isExpanded,
              onTap: () => _toggleCountry(group.key, expanded),
            ),
          RegionHeaderRow(:final label) => SiteSectionLabel(label, indent: 32),
          SiteRow(:final item) => _buildSiteTile(item, orderedSites, diversCount),
        },
      ),
    );
```

with these members on the state class:

```dart
  /// Countries closed by hand while a filter is active; reset when the
  /// filter changes, since a new filter opens every match again.
  Set<String> _filterCollapsed = const {};

  /// The open countries for [groups]: everything while a filter narrows the
  /// list, else the diver's own choice, seeded with the detail pane's site.
  Set<String> _groupedExpansion(
    List<SiteCountryGroup<SiteWithDiveCount>> groups,
    List<SiteWithDiveCount> sites,
  ) {
    if (ref.watch(siteFilterProvider).hasActiveFilters) {
      return allCountryKeys(groups).difference(_filterCollapsed);
    }
    final stored = ref.watch(siteListExpandedCountriesProvider);
    if (stored != null) return stored;
    final selected = sites
        .where((s) => s.site.id == widget.selectedId)
        .firstOrNull;
    return initialExpandedCountries(groups, selected: selected?.site);
  }

  void _toggleCountry(String key, Set<String> current) {
    if (ref.read(siteFilterProvider).hasActiveFilters) {
      setState(() {
        _filterCollapsed = _filterCollapsed.contains(key)
            ? (_filterCollapsed.toSet()..remove(key))
            : {..._filterCollapsed, key};
      });
      return;
    }
    ref.read(siteListExpandedCountriesProvider.notifier).state =
        current.contains(key) ? (current.toSet()..remove(key)) : {...current, key};
  }
```

In `build`, add `ref.listen(siteFilterProvider, (_, _) => setState(() => _filterCollapsed = const {}));` next to the existing watches.

- [ ] **Step 8: Keep scroll-to-selected right when grouped**

In `_scrollToSelectedItem`, replace `final index = sites.indexWhere(...)` and the `sites.length` used for `avgItemHeight` with a row index and row count computed for the current mode:

```dart
      final grouped = ref.read(siteGroupByProvider) == SiteGroupBy.location;
      int index;
      int rowCount;
      if (grouped) {
        final groups = groupSitesByLocation(sites, (s) => s.site);
        final rows = flattenSiteGroups(
          groups,
          expanded: _groupedExpansion(groups, sites),
        );
        index = rows.indexWhere(
          (row) => row is SiteRow<SiteWithDiveCount> &&
              row.item.site.id == widget.selectedId,
        );
        rowCount = rows.length;
      } else {
        index = sites.indexWhere((s) => s.site.id == widget.selectedId);
        rowCount = sites.length;
      }
```

and use `rowCount` in place of `sites.length` in the offset arithmetic. `_groupedExpansion` uses `ref.watch`; since this runs outside build, make it take a `bool watch` flag or split reads: give `_groupedExpansion` a `{bool listen = true}` parameter and use `listen ? ref.watch(p) : ref.read(p)` for both providers, passing `listen: false` here.

- [ ] **Step 9: Run tests to verify they pass**

Run: `flutter test test/shared/widgets/sort_bottom_sheet_test.dart test/features/dive_sites/`
Expected: PASS, including the untouched `site_list_content_test.dart` and `site_list_content_table_test.dart` (flat mode is the default).

- [ ] **Step 10: Commit**

```bash
dart format lib test
git add lib/shared/widgets/sort_bottom_sheet.dart lib/features/dive_sites/presentation/providers/site_grouping_providers.dart lib/features/dive_sites/presentation/widgets/site_group_by_selector.dart lib/features/dive_sites/presentation/widgets/site_list_content.dart test/shared/widgets/sort_bottom_sheet_test.dart test/features/dive_sites/presentation/widgets/site_list_content_grouped_test.dart
git commit -m "feat(dive-sites): group the Dive Sites list by country and region"
```

---

### Task 8: Whole-branch verification

**Files:** none new.

- [ ] **Step 1: Format and analyze the whole project**

Run: `dart format . && flutter analyze`
Expected: `No issues found!` (infos count as failures in CI).

- [ ] **Step 2: Architecture guards (new files under lib/)**

Run: `flutter test test/architecture/`
Expected: PASS. If `list_tile_trailing_width_test.dart` flags a file from this branch, move the text out of `ListTile.trailing`.

- [ ] **Step 3: Affected tests**

Run: `flutter test test/features/dive_sites test/features/dive_log test/features/media test/features/nav_track test/shared`
Expected: PASS.

- [ ] **Step 4: Search for leftovers**

Run: `grep -rn "site_picker_search\|media/presentation/widgets/site_picker_sheet\|dive_log/presentation/widgets/pickers/site_picker_sheet" lib test`
Expected: no output.

- [ ] **Step 5: Commit any formatting fallout**

```bash
git status --short
git add -u
git commit -m "chore(dive-sites): format"
```

Skip the commit if `git status` is clean.
