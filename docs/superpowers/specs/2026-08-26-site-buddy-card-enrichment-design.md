# Dive Site and Buddy List Card Enrichment: Design

**Status:** approved 2026-08-26
**Branch:** `worktree-site-buddy-card-enrichment`
**Worktree:** `.claude/worktrees/site-buddy-card-enrichment`

## Problem

The Dive Sites and Buddies list cards are plain. A site card shows an icon,
name, location, and a right-aligned stack of text (depth, difficulty, dive
count, rating). A buddy card shows initials, name, "Level - Agency", and a dive
count. Both lists already have richer data one query away, and both features
already own a configurable card-slot system that is exposed in Settings but
read by nothing.

## Findings

1. `SiteListTile` (`site_list_content.dart:1278-1553`) and `BuddyListTile`
   (`buddy_list_content.dart:922-1020`) never read
   `siteDetailedCardConfigProvider` / `buddyDetailedCardConfigProvider` (nor
   the compact variants). Settings edits them and nothing changes. The four
   providers are plain in-memory `StateProvider`s, so they also reset on
   restart, unlike the table configs, which persist through
   `EntityTableConfigNotifier<F>` and the `view_configs` table.
2. `BuddyListTile` is a bare `ListTile` with a text `diveCount` in `trailing`.
   Both are known traps: `ListTile` swaps the title font role under the
   console/minimalist themes, and text in `trailing` starves the title on
   narrow phones in long locales (issue #935).
3. `buddy.photoPath` is loaded through `AssetImage`, which treats a stored file
   path as a bundled asset, so buddy photos never render.
4. `CompactSiteListTile` hardcodes English `'$diveCount dives'`.
5. For buddies, detailed and compact modes render the same widget.
6. Aggregates that would make the cards interesting are one `GROUP BY` away
   in queries that already run for the lists: last dived and max depth
   reached per site (`getDiveCountsBySite`), last dive together and usual role
   per buddy (`getAllBuddiesWithDiveCount`). Site features (wreck, mooring,
   swim-through, ...) have an icon mapping (`SiteFeatureGlyph.styleFor`) and
   localized names (`siteFeature_type_*`) but only a per-site family provider.
7. `CertificationAgency.primaryColor` exists and no card uses it.
   `resolveFeatureAccent` has palette entries for `'sites'` and `'buddies'`
   that neither card uses.
8. `BuddyFieldAdapter.formatValue` renders cert level and agency as the enum
   identifier (`openWater`, `padi`) rather than the display name.
9. `site_list_content.dart` (1553 lines) and `buddy_list_content.dart` (1134
   lines) both exceed the 800-line file limit.

## Decisions

- Layout grammar: dive-card style. Title row with inline badges, subtitle, a
  stat row under the text, a fixed chip row, an optional extra-fields grid, a
  chevron on the right and nothing else there.
- Both configurable slots and fixed identity elements. Slots (`title`,
  `subtitle`, `stat1`, `stat2`, `extraFields`) come from the persisted config
  and are user-editable in Settings. Identity elements (avatar, rating, shared
  badge, difficulty, water type, feature chips, cert chip, usual role, contact
  icons) are fixed and not configurable.
- Config wiring uses a shared generic layer (approach 1): a persisted
  `EntityCardConfigNotifier<F>` and a shared slot renderer, so trips and dive
  centres can adopt the same path later.
- Deferred, not built: site photo thumbnails (needs a batched first-photo
  query plus byte resolution per row), sorting by last dived, wiring the trip,
  dive centre, certification and course card configs.

## Section 1: Data layer

### Wrapper classes move to domain and gain aggregates

`SiteWithDiveCount` moves from `site_repository_impl.dart` to
`lib/features/dive_sites/domain/entities/site_with_dive_count.dart`:

```dart
class SiteWithDiveCount extends Equatable {
  final DiveSite site;
  final int diveCount;
  final DateTime? lastDivedAt;
  final double? maxDepthReached; // metres, deepest dive logged at the site
  final List<String> featureTypes; // distinct site_features.type names
  const SiteWithDiveCount({
    required this.site,
    required this.diveCount,
    this.lastDivedAt,
    this.maxDepthReached,
    this.featureTypes = const [],
  });
}
```

`BuddyWithDiveCount` moves to
`lib/features/buddies/domain/entities/buddy_with_dive_count.dart` with
`buddy`, `diveCount`, `lastDiveAt: DateTime?`, `usualRoleId: String?`.

`site_repository_impl.dart` and `buddy_repository.dart` re-export the moved
classes so existing imports keep compiling. The record typedefs
`SiteWithCount` (`site_field.dart`) and `BuddyWithCount` (`buddy_field.dart`)
become aliases of the classes. The ten record literals (one in
`site_list_content.dart:645`, one in `buddy_list_content.dart:620`, the rest
in the adapter tests) become constructor calls, and the "convert class to
record" boundary at the table view disappears.

### Queries

All are whole-table `GROUP BY` queries; no per-row work.

- `SiteRepository.getDiveAggregatesBySite()` returns
  `Map<String, SiteDiveAggregate>` (`diveCount`, `lastDivedAt`,
  `maxDepthReached`; a small `Equatable` value class declared next to
  `SiteWithDiveCount` in `site_with_dive_count.dart`) from
  `SELECT site_id, COUNT(*), MAX(dive_date_time), MAX(max_depth) FROM dives
  WHERE site_id IS NOT NULL GROUP BY site_id`. `getDiveCountsBySite()` stays as
  a thin wrapper over it so its existing tests hold.
- `SiteRepository.getFeatureTypesBySite()` returns `Map<String, List<String>>`
  from `SELECT site_id, type, MIN(created_at) AS first_seen FROM site_features
  GROUP BY site_id, type ORDER BY site_id, first_seen`.
- `getSitesWithDiveCounts()` runs `getAllSites`, the aggregates, and the
  feature map, then assembles. Sort order is unchanged.
- `BuddyRepository.getAllBuddiesWithDiveCount()`: the count subselect becomes
  `SELECT db.buddy_id, COUNT(*) AS dive_count, MAX(d.dive_date_time) AS
  last_dive FROM dive_buddies db LEFT JOIN dives d ON d.id = db.dive_id GROUP
  BY db.buddy_id`. A second query `SELECT buddy_id, role, COUNT(*) AS c FROM
  dive_buddies GROUP BY buddy_id, role` feeds a pure Dart `usualRoleFor`
  top-level function (declared in `buddy_with_dive_count.dart`) that picks the top role per buddy (higher count wins, ties broken
  by role id ascending, so the result is deterministic). Two queries total,
  then the existing `_withPrimaryCerts` batch.

The existing behaviour that the count subqueries are not diver-scoped is kept
for parity; it is a separate concern.

### Reactivity

`sitesWithCountsProvider` additionally calls
`ref.invalidateSelfWhen(ref.read(siteFeatureRepositoryProvider).watchFeatureChanges())`
so adding a feature on the site map refreshes the list card.

## Section 2: Field enums and adapters

`SiteField` gains three values in category `statistics`:

| Field | Value type | Format | Sortable | Icon |
| --- | --- | --- | --- | --- |
| `depthRange` | `({double? min, double? max})` record | `"12-40 m"` via `units.convertDepth` + `units.formatDepth(decimals: 0)`; max only when min is null; null when both null | no | `Icons.straighten` |
| `lastDived` | `DateTime?` | `units.formatDate` | yes | `Icons.history` |
| `maxDepthReached` | `double?` metres | `units.formatDepth(decimals: 0)` | yes | `Icons.vertical_align_bottom` |

`BuddyField` gains `lastDive` (`DateTime?`, `units.formatDate`, sortable,
`Icons.history`, category `statistics`).

Usual role is deliberately not a `BuddyField`: `EntityFieldAdapter.formatValue`
has no l10n access and a role id needs `diveRoleMapProvider` plus
`DiveRoleDisplay.localizedName`, so the card renders it as a fixed element.

`BuddyFieldAdapter.formatValue` switches `certificationLevel` and
`certificationAgency` from `.name` to `.displayName`.

`EntityTableView` sorts with `Comparable.compareTo`, so `DateTime` and `double`
fields sort correctly as table columns with no further work; `depthRange` is
marked non-sortable because a record is not `Comparable`.

New l10n keys, in all 11 arb files, following the existing pattern:
`enum_siteField_depthRange`, `enum_siteField_depthRange_short`,
`enum_siteField_lastDived`, `enum_siteField_lastDived_short`,
`enum_siteField_maxDepthReached` ("Your max depth"),
`enum_siteField_maxDepthReached_short`, `enum_buddyField_lastDive`,
`enum_buddyField_lastDive_short`.

## Section 3: Persisted card config

### `EntityCardConfigNotifier<F>`

New file `lib/shared/providers/entity_card_config_providers.dart`, a sibling
of `EntityTableConfigNotifier<F>` with the same shape:

- constructor `({required EntityCardViewConfig<F> defaultConfig, required F
  Function(String) fieldFromName})`
- `Future<void> init(ViewConfigRepository repo, String diverId, String
  storageKey)`: loads `getRawConfig`; if the JSON names a field this build does
  not know (`fieldFromName` throws), the notifier keeps the default and logs,
  instead of crashing on a saved layout from a newer build
- mutations: `setSlotField(String slotId, F field)`, `setExtraFields(List<F>)`,
  `addExtraField(F)`, `removeExtraField(F)`, `reorderExtraFields(int, int)`,
  `replace(EntityCardViewConfig<F>)`, `resetToDefault()`
- every mutation schedules a 500 ms debounced `saveRawConfig`; `dispose`
  cancels the timer

### Providers and storage keys

The four existing providers keep their names and become
`StateNotifierProvider<EntityCardConfigNotifier<F>, EntityCardViewConfig<F>>`,
initialised with `currentDiverIdProvider` + `viewConfigRepositoryProvider`
exactly like `siteTableConfigProvider`.

| Provider | Storage key | Default slots | Default extras |
| --- | --- | --- | --- |
| `siteDetailedCardConfigProvider` | `card_detailed_sites` | title=siteName, subtitle=location, stat1=depthRange, stat2=diveCount | lastDived, maxDepthReached |
| `siteCompactCardConfigProvider` | `card_compact_sites` | title=siteName, subtitle=location, stat1=diveCount, stat2=depthRange | none |
| `buddyDetailedCardConfigProvider` | `card_detailed_buddies` | title=buddyName, subtitle=email, stat1=diveCount, stat2=lastDive | none |
| `buddyCompactCardConfigProvider` | `card_compact_buddies` | title=buddyName, subtitle=certificationLevel, stat1=diveCount, stat2=lastDive | none |

### Settings page

`_EntityCardConfigSection<F>` in `column_config_page.dart` is retyped from
`StateProvider<EntityCardViewConfig<F>>` to
`ProviderListenable<EntityCardViewConfig<F>> configProvider` plus
`void Function(WidgetRef, EntityCardViewConfig<F>) onChanged`. Sites and
buddies pass `(ref, c) => ref.read(provider.notifier).replace(c)`; trips, dive
centres, certifications and courses pass `(ref, c) =>
ref.read(provider.notifier).state = c` and are otherwise untouched.
`column_config_page_test.dart` overrides the four site/buddy providers with
`overrideWith((ref) => EntityCardConfigNotifier(...))`.

## Section 4: Cards

### Shared renderer

New directory `lib/shared/widgets/entity_card/`:

- `EntityCardStat<T, F extends EntityField>`: takes `adapter`, `entity`,
  `units`, `field`, `color`; renders `field.icon` (14 px) + formatted value in
  `bodySmall` w600. Renders nothing when `extractValue` returns null, so a
  never-dived site does not show "Last dived --".
- `EntityCardExtraFields<T, F extends EntityField>`: the dive card's grid.
  `Wrap` of `label: value` pairs, two columns, one column under 250 px, label
  from `localizedShortLabel(l10n)`, value from `formatValue`; null values are
  skipped.
- `resolveCardSlot<F>(List<EntityCardSlotConfig<F>> slots, String slotId, F
  fallback)`: the `_slotField` idiom, shared.

### `SiteListTile` (new file `site_list_tile.dart`)

Moves out of `site_list_content.dart`. Structure, top to bottom:

1. Leading 40 px `CircleAvatar` tinted by
   `resolveFeatureAccent(featureId: 'sites', surface: AccentSurface.list)`
   at alpha 0.15, `Icons.location_on`; selection swaps it for the checkbox as
   today.
2. Title row: title slot text (`titleMedium` w600, ellipsis, `maxLines: 1`),
   inline amber `Icons.star` 16 px + `rating.toStringAsFixed(1)` when set,
   `Icons.people_outline` shared badge when `showSharedBadge`.
3. Subtitle slot (`bodyMedium`, secondary colour), hidden when empty.
4. Stat row: `Wrap(spacing: 16, runSpacing: 6)` of `EntityCardStat` for
   stat1 and stat2, inset 52 px like the dive card.
5. Chip row, fixed, same inset: difficulty (text chip, localized through the
   existing `diveSites_difficulty_*` keys), water type (icon chip, localized
   through `WaterTypeDisplay.localizedName` in
   `environment_enum_display.dart`), then
   one chip per `featureTypes` entry using `SiteFeatureGlyph.styleFor` for icon
   and colour and `siteFeature_type_*` for the label; unknown type names fall
   back to the glyph's generic marker and the raw name. Hidden when all are
   absent.
6. `EntityCardExtraFields` for `extraFields`, when non-empty.
7. Trailing chevron only.

The map-background variant (`showMapBackgroundOnSiteCardsProvider`) keeps the
`FlutterMap` + gradient stack and passes white text/icon colours into the same
content builder. `Semantics(label:)` becomes prose (name, location, dive
count) with `selected:` as a flag, like `TripListTile`.

`CompactSiteListTile` reads `siteCompactCardConfigProvider` and stays two
lines: line 1 is title slot | inline rating | stat1 (right-aligned,
`bodySmall`) | chevron; line 2 is subtitle slot | stat2 (right-aligned,
`bodySmall`, secondary colour). `diveCount` formats through the existing
`diveSites_list_tile_diveCount` plural, which replaces the hardcoded English.

### `BuddyListTile` (new file `buddy_list_tile.dart`)

Rebuilt as a hand-rolled `Row`/`Column` in a `Card`, no `ListTile`:

1. Leading 40 px avatar: `FileImage(File(photoPath))` when the file exists,
   else initials on the `'buddies'` accent (alpha 0.15) or `primaryContainer`.
   A 2 px ring in `certificationAgency.primaryColor` when an agency is known.
2. Title slot (`titleMedium` w600, ellipsis, `maxLines: 1`).
3. Subtitle slot, hidden when empty.
4. Fixed cert chip: `"Level · Agency"` tinted with the agency colour at low
   alpha, when `hasCertificationInfo`.
5. Stat row: `EntityCardStat` for stat1 and stat2. `diveCount` formats through
   the existing `buddies_label_diveCount` plural.
6. Fixed trailer row: usual-role chip (`Icons.badge`, `DiveRoleDisplay
   .localizedName`) only when `usualRoleId` is non-null and not
   `DiveRole.buddyId`; the role is resolved through `diveRoleMapProvider`, with
   `DiveRole.synthetic(id)` for an unknown id. Then 16 px `Icons.mail_outline`
   / `Icons.phone_outlined` when email / phone are set (icons only, no text).
7. `EntityCardExtraFields` for `extraFields`.
8. Trailing chevron only.

New `CompactBuddyListTile` (`compact_buddy_list_tile.dart`), same two-line
shape as the compact site tile: title slot | stat1 | chevron, then subtitle
slot | stat2. The mode switch in
`buddy_list_content.dart` routes `ListViewMode.compact` to it.

Dense tiles and table mode are unchanged; the new `SiteField`/`BuddyField`
values appear as optional table columns automatically.

### Bug fixes folded in

- `AssetImage(photoPath)` becomes `FileImage` with an existence check.
- `CompactSiteListTile` dive count is localized.
- The two `*_list_content.dart` files shrink below 800 lines by the tile
  extraction.

## Error handling

- Aggregate queries use the repositories' existing try/log/rethrow pattern.
- A missing photo file falls back to initials; no exception surfaces.
- An unknown saved field name in a card config falls back to the default
  config (logged), never throws into the provider tree.
- An unknown `site_features.type` renders the generic glyph and raw name.
- An unknown role id renders `DiveRole.synthetic(id).name`.

## Testing (TDD, tests first per unit)

- Repository: `getDiveAggregatesBySite` (count, last dived, max depth; sites
  with no dives absent from the map), `getFeatureTypesBySite` (distinct,
  ordered by first created), `getAllBuddiesWithDiveCount` last-dive and
  usual-role (including the tie-break and the all-`buddy` case).
- Pure: `usualRoleFor` tie-break; `depthRange` formatting in metric and
  imperial; `SiteFieldAdapter`/`BuddyFieldAdapter` new fields and the
  `displayName` fix.
- Notifier: load from repo, debounce save (fakeAsync 500 ms), `replace`,
  unknown-field fallback keeps the default.
- Widgets: `SiteListTile` renders slots, rating, chips, extras, hides null
  stats, map-background variant still shows text; `CompactSiteListTile`
  localized count; `BuddyListTile` renders cert chip, usual role only for
  non-buddy roles, contact icons, `FileImage` for an existing file and
  initials for a missing one, and the 360 px German-locale assertion that the
  title renders wider than 150 px with a long name; `CompactBuddyListTile`
  two-line shape; mode switch routes compact to the new tile.
- Settings: `column_config_page_test.dart` still edits site/buddy slots
  through the notifier.
- Existing `site_list_content_test.dart`, `site_list_content_table_test.dart`,
  `buddy_list_content_test.dart`, `site_field_test.dart`, `buddy_field_test.dart`
  updated for the constructor and typedef changes.
- One full `flutter test` run before the PR.

## Files

New: `dive_sites/domain/entities/site_with_dive_count.dart`,
`buddies/domain/entities/buddy_with_dive_count.dart`,
`shared/providers/entity_card_config_providers.dart`,
`shared/widgets/entity_card/entity_card_stat.dart`,
`shared/widgets/entity_card/entity_card_extra_fields.dart`,
`shared/widgets/entity_card/card_slot_resolver.dart`,
`dive_sites/presentation/widgets/site_list_tile.dart`,
`buddies/presentation/widgets/buddy_list_tile.dart`,
`buddies/presentation/widgets/compact_buddy_list_tile.dart`, plus tests.

Modified: `site_repository_impl.dart`, `site_repository.dart` (interface),
`buddy_repository.dart`, `site_field.dart`, `buddy_field.dart`,
`site_providers.dart`, `buddy_providers.dart`, `site_list_content.dart`,
`compact_site_list_tile.dart`, `buddy_list_content.dart`,
`column_config_page.dart`, 11 arb files, regenerated l10n and mocks.
