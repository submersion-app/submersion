# Species Photos, Phase B, Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Surface the species tags from phase A in three more places: cover photos on the Species page tiles, a photo-count chip on each dive-detail sighting row that opens the dive's photos of that species, and a species facet in the media library filter (sheet, active chips, smart albums).

**Architecture:** Three read-only providers over `MediaSpeciesRepository` queries that already exist (`getCoverMediaBySpecies`, `getPhotoCountsBySpeciesForDive`, `getMediaForSpecies`); a `MediaItem? cover` parameter on `SeenSpeciesTile`; the sighting row extracted from `dive_detail_page.dart` into a `DiveSightingRow` widget so it can carry the chip and be tested alone; a `speciesId` field on `MediaLibraryFilter` compiled to an `EXISTS` subquery. No schema change.

**Tech Stack:** Flutter, Riverpod, Drift (`existsQuery`), `flutter gen-l10n`, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-08-26-species-photos-design.md`, section 7 (phase B). Phase A is on this branch's base (`worktree-species-photos`, PR #1339).

## Global Constraints

- Work only in `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-photo-surfaces` on branch `worktree-species-photo-surfaces`, stacked on `worktree-species-photos`. `flutter analyze` prints `Analyzing species-photo-surfaces...` when it runs in the right tree.
- No schema change. No em-dashes. No emojis in code or docs. Immutable entities; tests first; single-file runs with exit codes, never through a pipe.
- Every new string is an ARB key in all 11 locales; generated l10n files are committed with the ARB change.
- `dart format .` before every commit.

---

### Task 1: Providers for covers, per-dive counts, and a dive-scoped species gallery

**Files:**
- Modify: `lib/features/media/presentation/providers/species_media_providers.dart` (append)
- Test: `test/features/media/presentation/providers/species_media_surfaces_providers_test.dart`

**Interfaces:**
- Produces:
  ```dart
  final speciesCoverMediaProvider = FutureProvider<Map<String, MediaItem>>;                       // speciesId -> newest tagged photo
  final diveSpeciesPhotoCountsProvider = FutureProvider.family<Map<String, int>, String>;         // diveId -> {speciesId: count}
  typedef DiveSpeciesKey = ({String diveId, String speciesId});
  final mediaForDiveSpeciesProvider = FutureProvider.family<List<MediaItem>, DiveSpeciesKey>;    // the dive's photos tagged with the species
  ```

- [ ] **Step 1: Write the failing provider test**

`test/features/media/presentation/providers/species_media_surfaces_providers_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/repositories/media_species_repository.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';
import '../../data/repositories/species_photo_fixtures.dart';

Future<T> _eventually<T>(
  Future<T> Function() read,
  bool Function(T value) until,
) async {
  late T value;
  for (var i = 0; i < 50; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    value = await read();
    if (until(value)) break;
  }
  return value;
}

void main() {
  late SharedPreferences prefs;
  late MediaSpeciesRepository tags;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
    tags = MediaSpeciesRepository();
    await insertTestDive(id: 'd1', at: DateTime(2024, 1, 10));
    await insertTestDive(id: 'd2', at: DateTime(2024, 2, 10));
    await insertTestSpecies(id: 'c1', name: 'Grouper');
    await insertTestSpecies(id: 'c2', name: 'Wrasse');
    await insertTestMedia(id: 'p1', diveId: 'd1', takenAt: DateTime(2024, 1, 10, 9));
    await insertTestMedia(id: 'p2', diveId: 'd1', takenAt: DateTime(2024, 1, 10, 10));
    await insertTestMedia(id: 'p3', diveId: 'd2', takenAt: DateTime(2024, 2, 10, 9));
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('speciesCoverMediaProvider maps species to their newest photo', () async {
    await tags.addTag(mediaId: 'p1', speciesId: 'c1');
    await tags.addTag(mediaId: 'p3', speciesId: 'c1');
    await tags.addTag(mediaId: 'p2', speciesId: 'c2');
    final container = makeContainer();
    final sub = container.listen(speciesCoverMediaProvider, (_, _) {});
    addTearDown(sub.close);

    final covers = await container.read(speciesCoverMediaProvider.future);

    expect(covers['c1']!.id, 'p3');
    expect(covers['c2']!.id, 'p2');
  });

  test('speciesCoverMediaProvider refreshes when a tag is added', () async {
    final container = makeContainer();
    final sub = container.listen(speciesCoverMediaProvider, (_, _) {});
    addTearDown(sub.close);
    expect(await container.read(speciesCoverMediaProvider.future), isEmpty);

    await tags.addTag(mediaId: 'p1', speciesId: 'c1');

    final covers = await _eventually(
      () => container.read(speciesCoverMediaProvider.future),
      (v) => v.isNotEmpty,
    );
    expect(covers['c1']!.id, 'p1');
  });

  test('diveSpeciesPhotoCountsProvider counts per species on one dive', () async {
    await tags.addTag(mediaId: 'p1', speciesId: 'c1');
    await tags.addTag(mediaId: 'p2', speciesId: 'c1');
    await tags.addTag(mediaId: 'p3', speciesId: 'c1');
    final container = makeContainer();
    final sub = container.listen(diveSpeciesPhotoCountsProvider('d1'), (_, _) {});
    addTearDown(sub.close);

    expect(await container.read(diveSpeciesPhotoCountsProvider('d1').future), {
      'c1': 2,
    });
  });

  test('mediaForDiveSpeciesProvider keeps only the dive\'s photos of the species',
      () async {
    await tags.addTag(mediaId: 'p1', speciesId: 'c1');
    await tags.addTag(mediaId: 'p2', speciesId: 'c2');
    await tags.addTag(mediaId: 'p3', speciesId: 'c1');
    final container = makeContainer();
    const key = (diveId: 'd1', speciesId: 'c1');
    final sub = container.listen(mediaForDiveSpeciesProvider(key), (_, _) {});
    addTearDown(sub.close);

    final items = await container.read(mediaForDiveSpeciesProvider(key).future);

    expect(items.map((m) => m.id).toList(), ['p1']);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/media/presentation/providers/species_media_surfaces_providers_test.dart`
Expected: compilation errors, the three providers are not defined.

- [ ] **Step 3: Append the providers**

Append to `species_media_providers.dart`:

```dart

/// Newest tagged photo per species, for the Species page's tile avatars.
/// One query for the whole list; derived, never chosen (built-in species
/// rows never sync, so a chosen cover could not follow the diver).
final speciesCoverMediaProvider = FutureProvider<Map<String, MediaItem>>((
  ref,
) async {
  final repository = ref.watch(mediaSpeciesRepositoryProvider);
  final diverId = ref.watch(currentDiverIdProvider);
  ref.invalidateSelfWhen(repository.watchTagChanges());
  ref.invalidateSelfWhen(ref.watch(mediaRepositoryProvider).watchMediaChanges());
  return repository.getCoverMediaBySpecies(diverId: diverId);
});

/// How many photos on one dive carry each species tag, for the sighting
/// rows' photo chips.
final diveSpeciesPhotoCountsProvider =
    FutureProvider.family<Map<String, int>, String>((ref, diveId) async {
      final repository = ref.watch(mediaSpeciesRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchTagChanges());
      ref.invalidateSelfWhen(
        ref.watch(mediaRepositoryProvider).watchMediaChanges(),
      );
      return repository.getPhotoCountsBySpeciesForDive(diveId);
    });

/// Identifies one dive's photos of one species.
typedef DiveSpeciesKey = ({String diveId, String speciesId});

/// The photos on [DiveSpeciesKey.diveId] tagged with [DiveSpeciesKey.speciesId],
/// newest first: the species gallery narrowed to one dive.
final mediaForDiveSpeciesProvider =
    FutureProvider.family<List<MediaItem>, DiveSpeciesKey>((ref, key) async {
      final items = await ref.watch(
        mediaForSpeciesProvider(key.speciesId).future,
      );
      return [
        for (final item in items)
          if (item.diveId == key.diveId) item,
      ];
    });
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/media/presentation/providers/species_media_surfaces_providers_test.dart`
Expected: `All tests passed!` (4 tests), exit 0.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/features/media/presentation/providers/species_media_providers.dart test/features/media/presentation/providers/species_media_surfaces_providers_test.dart
git add lib/features/media/presentation/providers/species_media_providers.dart test/features/media/presentation/providers/species_media_surfaces_providers_test.dart
git commit -m "feat(media): add cover, per-dive count and dive-scoped species gallery providers"
```

---

### Task 2: Localization keys

**Files:**
- Modify: all 11 `lib/l10n/arb/app_*.arb`; regenerate `lib/l10n/arb/app_localizations*.dart`
- Test: `test/l10n/species_photo_surfaces_strings_test.dart`

Keys (anchors: `diveLog_detail_section_marineLife` for the dive key, `media_library_filter_site` for the library key; `@` metadata in `app_en.arb` only):

| key | en | de | es | fr | it | pt | nl | hu | zh | ar | he |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `diveLog_detail_sightingPhotos` (count int, plural) | `{count, plural, =1{1 photo} other{{count} photos}}` | `{count, plural, =1{1 Foto} other{{count} Fotos}}` | `{count, plural, =1{1 foto} other{{count} fotos}}` | `{count, plural, =1{1 photo} other{{count} photos}}` | `{count, plural, =1{1 foto} other{{count} foto}}` | `{count, plural, =1{1 foto} other{{count} fotos}}` | `{count, plural, =1{1 foto} other{{count} foto's}}` | `{count, plural, =1{1 fotó} other{{count} fotó}}` | `{count, plural, =1{1 张照片} other{{count} 张照片}}` | `{count, plural, =1{صورة واحدة} other{{count} صور}}` | `{count, plural, =1{תמונה אחת} other{{count} תמונות}}` |
| `media_library_filter_species` | Species | Art | Especie | Espèce | Specie | Espécie | Soort | Faj | 物种 | النوع | מין |

- [ ] **Step 1: Write the failing strings test** asserting `diveLog_detail_sightingPhotos(1) == '1 photo'`, `(3) == '3 photos'`, `media_library_filter_species == 'Species'` in `en`, and `media_library_filter_species == 'Art'` in `de`.
- [ ] **Step 2: Run it to see it fail** (undefined getters).
- [ ] **Step 3: Insert the keys** with the same anchored-insertion script shape used in phase A (`add_species_photo_keys.py`), then `flutter gen-l10n`.
- [ ] **Step 4: Run the strings test and `test/l10n/arb_parity_test.dart`**; expect green.
- [ ] **Step 5: Commit** `lib/l10n/arb` and the test: `feat(l10n): add sighting photo count and library species facet strings`.

---

### Task 3: Cover photos on the Species page

**Files:**
- Modify: `lib/features/marine_life/presentation/widgets/seen_species_tile.dart` (`MediaItem? cover` parameter; the `leading` becomes a clipped `MediaItemView` thumbnail when a cover exists)
- Modify: `lib/features/marine_life/presentation/pages/species_page.dart` (watch `speciesCoverMediaProvider`, pass `cover: covers[entry.species.id]`)
- Test: `test/features/marine_life/presentation/widgets/seen_species_tile_test.dart` (add a case), `test/features/marine_life/presentation/pages/species_page_test.dart` (override `speciesCoverMediaProvider`, assert a `MediaItemView` is rendered for the covered species and the category avatar for the other)

Tile change:

```dart
      leading: cover == null
          ? CircleAvatar(... as today ...)
          : ClipOval(
              child: SizedBox(
                width: 40,
                height: 40,
                child: MediaItemView(
                  item: cover,
                  thumbnail: true,
                  targetSize: const Size(80, 80),
                  fit: BoxFit.cover,
                ),
              ),
            ),
```

Page change: `final covers = ref.watch(speciesCoverMediaProvider).value ?? const <String, MediaItem>{};` in `build`, and `cover: covers[entry.species.id]` in the `itemBuilder`. Widget tests use the media harness's `testMediaItem` plus `mediaTestApp` (its fake resolver serves a 1x1 PNG) for the tile, and `speciesCoverMediaProvider.overrideWith((ref) async => {'sp_whale_shark': item})` for the page; the page test also needs `mediaSourceResolverRegistryProvider` overridden the way `mediaTestApp` does, or the tile falls back to its placeholder (assert `find.byType(MediaItemView)` rather than pixels).

- [ ] Steps: failing tests, red, implement, green, format, commit `feat(marine-life): show a species' newest photo on its Species page tile`.

---

### Task 4: Photo-count chips on dive-detail sighting rows

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/dive_sighting_row.dart` (the body of `_buildSightingTile` moved into `DiveSightingRow({required Sighting sighting, required int photoCount, required VoidCallback onOpen, VoidCallback? onOpenPhotos})`, with a trailing photo chip when `photoCount > 0`)
- Create: `lib/features/media/presentation/pages/dive_species_photo_viewer_page.dart` (`DiveSpeciesPhotoViewerPage({diveId, speciesId, initialMediaId?})`: watches `mediaForDiveSpeciesProvider`, hands off to `MediaViewerPage` with the first photo as initial when none given)
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart` (`_buildSightingsSection` watches `diveSpeciesPhotoCountsProvider(diveId)` and builds `DiveSightingRow`s; delete `_buildSightingTile`)
- Test: `test/features/dive_log/presentation/widgets/dive_sighting_row_test.dart`, `test/features/media/presentation/pages/dive_species_photo_viewer_page_test.dart`

Row chip (trailing, beside the existing count badge):

```dart
              if (photoCount > 0 && onOpenPhotos != null)
                ActionChip(
                  key: const ValueKey('sighting_photos'),
                  avatar: const Icon(Icons.photo_outlined, size: 16),
                  label: Text(l10n.diveLog_detail_sightingPhotos(photoCount)),
                  onPressed: onOpenPhotos,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
```

The page passes `onOpenPhotos: () => Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => DiveSpeciesPhotoViewerPage(diveId: diveId, speciesId: sighting.speciesId)))` only when the count is positive. Row tests: name and notes render, `x3` badge for count 3, photo chip present and calls back only when `photoCount > 0`, tap on the row calls `onOpen`. Viewer test mirrors `species_photo_viewer_page_test.dart`.

- [ ] Steps: failing tests, red, implement (including the extraction), green plus `test/features/dive_log/presentation/pages/` still green, format, commit `feat(dive-log): show photo counts on sighting rows and open the dive's photos of a species`.

---

### Task 5: Species facet in the media library

**Files:**
- Modify: `lib/features/media/domain/entities/media_library_filter.dart` (`speciesId` in the constructor, field, `isEmpty`, `copyWith`, `toJson`, `fromJson`, `==`, `hashCode`)
- Modify: `lib/features/media/data/repositories/media_library_repository.dart` (`_baseWhere`: after the `tripId` block add
  ```dart
    final speciesId = filter.speciesId;
    if (speciesId != null) {
      final ms = _db.mediaSpecies;
      where =
          where &
          existsQuery(
            _db.selectOnly(ms)
              ..addColumns([ms.id])
              ..where(ms.mediaId.equalsExp(m.id) & ms.speciesId.equals(speciesId)),
          );
    }
  ```
  )
- Modify: `lib/features/media/presentation/widgets/media_library_filter_sheet.dart` (`String? _speciesId` seeded, cleared, applied and restored like `_siteId`; a `ListTile` titled `media_library_filter_species` after the site tile, options from `allSpeciesProvider` labelled with `localizedCommonName(l10n)` sorted by that label)
- Modify: `lib/features/media/presentation/widgets/media_library_active_filter_chips.dart` (a chip after the site chip, labelled with the species' localized name, fallback `media_library_filter_species`, clearing `speciesId`)
- Tests: `test/features/media/domain/media_library_filter_json_test.dart` (add `speciesId` to the round-trip and equality cases), `test/features/media/data/media_library_repository_test.dart` (a new test inserting a `media_species` row through `MediaSpeciesRepository.addTag` and asserting `getPage(filter: MediaLibraryFilter(speciesId: ...))` returns only tagged rows), `test/features/media/presentation/media_library_filter_sheet_test.dart` (override `allSpeciesProvider`; `picking a species drafts it and Apply commits the id`; extend Clear All), `test/features/media/presentation/media_library_active_filter_chips_test.dart` (species chip shows the localized name and clears only its facet), `test/features/media/data/media_smart_album_repository_test.dart` (round-trip `speciesId`)

- [ ] Steps: failing tests, red, implement all five files, green for the five test files, format, commit `feat(media): filter the library by species`.

---

### Task 6: Docs, format, analyze, full suite

- [ ] Add to `docs/features/marine-life.md`, under "### Species Photos", a final bullet: `- The Species page shows each species' newest tagged photo; a dive's sighting rows show how many of its photos carry the species, and the media library can be filtered by species (also inside smart albums).`
- [ ] `dart format .`, `flutter analyze --fatal-infos` (expect `Analyzing species-photo-surfaces...` then no issues), full `flutter test` detached with exit line and summary checked, commit `docs: describe the phase B species photo surfaces`. Do not push.

## Self-review notes

- Spec section 7 coverage: cover tiles (Task 3), sighting-row counts opening a dive-scoped viewer (Task 4), library facet with sheet, chips and smart albums (Task 5); providers (Task 1) and strings (Task 2) serve them.
- Deviation: the sighting row is extracted into `DiveSightingRow` rather than widening a private builder, because the dive detail page has no test that renders sightings and a widget of its own can be tested directly.
