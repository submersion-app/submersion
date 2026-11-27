# "Recorded nearby" Marker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show "Recorded nearby" under a marine life suggestion when GBIF lists that species within 5 km of the dive, on the species sheet's Suggested rows, the Possible matches list and Species to review.

**Architecture:** The site page's nearby list (`NearbySpecies`, fetched by `NearbySpeciesService`, saved by `ReefRepository`) also keeps every GBIF species key the search returned. A new provider resolves a dive or photo to a place (site, else photo GPS, else entry), reads that list through `reefNearbySpeciesProvider`, and one small widget, `RecordedNearbyLine`, shows the marker when a suggestion's GBIF key (or catalogue id) is on it. Nothing in naming, scoring or storage of identifications changes.

**Tech Stack:** Flutter, Riverpod 3, Drift, `http` with `MockClient` in tests.

**Spec:** `docs/design/specs/2026-11-19-marine-life-recorded-nearby-marker-design.md`

## Global Constraints

- Hint only: no change to `SpeciesNamer`, `identification_rules.dart`, the suggest or confident bars, auto-apply, or the species pack.
- Positive only: the marker reads "Recorded nearby" or nothing. No "not recorded" text, no spinner, no error.
- Wording: the existing string `l10n.reef_species_recordedNearby`. No new ARB keys.
- Place: the dive's site point, else the photo's own GPS, else the dive's entry point. A Species to review row passes no photo, so it uses site, else entry.
- Nearby species cache variant in `ReefRepository` goes from `'v3'` to `'v4'`.
- Look: the marker uses `Theme.of(context).textTheme.bodySmall`, no new colour.
- A per-item provider family is `autoDispose` (`test/architecture/media_provider_disposal_test.dart`), and a provider reading a table invalidates on that table's change tick (`test/architecture/provider_change_tick_test.dart`).
- Run only the test files a task names, by path. No em-dashes anywhere. No tool attribution in commits.

## Review Focus

- A pack candidate whose GBIF key differs from the occurrence search's species key (a synonym) still shows the marker when it is a catalogue species on the list: covered by the catalogue-id fallback tests in Tasks 2 and 5.
- While the list loads, when GBIF fails, or offline with nothing saved, every row looks exactly as before: Task 4's loading and unavailable tests.
- A dive with no site and no entry, for a photo with no GPS, asks GBIF for nothing: Task 3's no-place test.
- Lists saved under `v3`, without keys, are fetched again rather than read as "nothing nearby": Task 1's refetch test.
- Many review rows from one site cause one search, not one per row: Task 3's sharing test.

---

### Task 0: Branch setup and before screenshots

**Files:**
- Commit: `docs/design/specs/2026-11-19-marine-life-recorded-nearby-marker-design.md`, `docs/design/plans/2026-11-19-marine-life-recorded-nearby-marker.md`

- [ ] **Step 1: Bring the worktree up to date**

Run: `git submodule update --init --recursive && flutter pub get`
Expected: exits 0. If `flutter analyze` then reports missing generated files, run `dart run build_runner build --delete-conflicting-outputs` unfiltered, in the background.

- [ ] **Step 2: Render the before screenshots**

Render the three screens headlessly from the real widgets in the app's light theme, as PR #4734 did, with a scratch render test kept out of git: the species sheet's Suggested section with two suggestions, the Possible matches view for one of them, and Species to review with one tagged and one suggested row. Save as `01-suggested-before.png`, `02-possible-matches-before.png`, `03-species-review-before.png` in the session scratchpad. Keep the scratch test to render the after shots in Task 6.

- [ ] **Step 3: Commit the design and plan**

```bash
git add docs/design/specs/2026-11-19-marine-life-recorded-nearby-marker-design.md docs/design/plans/2026-11-19-marine-life-recorded-nearby-marker.md
git commit -m "docs(species-id): design and plan for the recorded nearby marker"
```

### Task 1: The nearby list keeps GBIF species keys

**Files:**
- Modify: `lib/features/reef/domain/entities/nearby_species.dart`
- Modify: `lib/features/reef/data/services/nearby_species_service.dart` (the `NearbySpecies(...)` built in `fetch`)
- Modify: `lib/features/reef/data/repositories/reef_repository.dart` (`_speciesWhitelistVariant` and its comment)
- Test: `test/features/reef/domain/entities/nearby_species_test.dart` (create)
- Test: `test/features/reef/data/services/nearby_species_service_test.dart`
- Test: `test/features/reef/data/repositories/reef_repository_test.dart`

**Interfaces:**
- Produces: `NearbySpecies.speciesKeys` of type `Set<int>`, defaulting to `const {}`; constructor parameter `speciesKeys`; JSON key `'speciesKeys'` (a list of ints); included in `props`. `isEmpty` is unchanged.

- [ ] **Step 1: Write the failing tests**

```dart
// nearby_species_test.dart
test('species keys survive a JSON round trip', () {
  const nearby = NearbySpecies(speciesKeys: {2335, 5208});
  expect(NearbySpecies.fromJson(nearby.toJson()).speciesKeys, {2335, 5208});
});
test('a list saved without keys reads back with none', () {
  expect(NearbySpecies.fromJson({'matched': [], 'unmatchedNames': []}).speciesKeys, isEmpty);
});

// nearby_species_service_test.dart, in the existing group
test('keeps every species key the search returned', () async {
  // facet counts for keys 101 (catalogue match) and 202 (unmatched)
  ...
  expect(part.value!.speciesKeys, {101, 202});
});
test('keeps keys beyond the 25 names it looks up', () async {
  // 40 unmatched keys, as in 'caps the unmatched tail at 25 entries'
  ...
  expect(part.value!.unmatchedNames.length, 25);
  expect(part.value!.speciesKeys.length, 40);
});

// reef_repository_test.dart, beside the 'v2' refetch test
test('a species row saved before keys were kept is refetched', () async {
  // a cached row under variant 'v3', payload with matched and no speciesKeys
  ...
  expect(searches, 1);
});
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/reef/domain/entities/nearby_species_test.dart test/features/reef/data/services/nearby_species_service_test.dart test/features/reef/data/repositories/reef_repository_test.dart`
Expected: the new tests fail (no `speciesKeys` parameter; the `v3` row is served from cache).

- [ ] **Step 3: Implement**

Add `speciesKeys` to `NearbySpecies` (serialise sorted, read a missing key as empty). In `NearbySpeciesService.fetch`, pass `speciesKeys: {for (final c in counts) c.key}`. Set `_speciesWhitelistVariant = 'v4'` and add a line to its comment: v4 keeps every species key, so marine life suggestions can be matched.

- [ ] **Step 4: Run them to verify they pass**

Run: the command from Step 2.
Expected: all pass, including the existing tests in those files.

- [ ] **Step 5: Commit**

```bash
git add lib/features/reef/domain/entities/nearby_species.dart lib/features/reef/data/services/nearby_species_service.dart lib/features/reef/data/repositories/reef_repository.dart test/features/reef/domain/entities/nearby_species_test.dart test/features/reef/data/services/nearby_species_service_test.dart test/features/reef/data/repositories/reef_repository_test.dart
git commit -m "feat(reef): keep every GBIF species key in the nearby list"
```

### Task 2: Where the list is read, and what counts as on it

**Files:**
- Create: `lib/features/species_id/domain/services/recorded_nearby.dart`
- Test: `test/features/species_id/domain/recorded_nearby_test.dart`

**Interfaces:**
- Consumes: `NearbySpecies.speciesKeys` and `NearbySpecies.matched` (Task 1); `GeoPoint` from `dive_sites/domain/entities/dive_site.dart`.
- Produces:
  - `GeoPoint? nearbyListLocation({GeoPoint? site, GeoPoint? photo, GeoPoint? entry})`
  - `bool isRecordedNearby(NearbySpecies nearby, {int? gbifKey, String? catalogId})`: true when `gbifKey` is in `speciesKeys`, or `catalogId` is the `speciesId` of an entry in `matched`.

- [ ] **Step 1: Write the failing tests**

```dart
const site = GeoPoint(12.1, -68.2), photo = GeoPoint(12.2, -68.3), entry = GeoPoint(12.3, -68.4);
test('the dive site comes before the photo position', () {
  expect(nearbyListLocation(site: site, photo: photo, entry: entry), site);
});
test('without a site, the photo position, then the entry', () {
  expect(nearbyListLocation(photo: photo, entry: entry), photo);
  expect(nearbyListLocation(entry: entry), entry);
});
test('no place at all is null', () => expect(nearbyListLocation(), isNull));

const nearby = NearbySpecies(
  matched: [MatchedNearbySpecies(speciesId: 'queen-parrotfish', occurrenceCount: 9)],
  speciesKeys: {2335},
);
test('a listed GBIF key is recorded nearby', () => expect(isRecordedNearby(nearby, gbifKey: 2335), isTrue));
test('a listed catalogue species is, whatever its key', () {
  expect(isRecordedNearby(nearby, gbifKey: 1, catalogId: 'queen-parrotfish'), isTrue);
});
test('anything else is not', () {
  expect(isRecordedNearby(nearby, gbifKey: 1, catalogId: 'other'), isFalse);
  expect(isRecordedNearby(nearby), isFalse);
});
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/species_id/domain/recorded_nearby_test.dart`
Expected: FAIL, the file's functions do not exist.

- [ ] **Step 3: Implement both functions** in `recorded_nearby.dart`, each with a doc comment saying why the site comes first (it matches the site page's list, one lookup per dive).

- [ ] **Step 4: Run to verify they pass**

Run: the command from Step 2. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/species_id/domain/services/recorded_nearby.dart test/features/species_id/domain/recorded_nearby_test.dart
git commit -m "feat(species-id): where a recorded nearby list is read and what is on it"
```

### Task 3: The provider

**Files:**
- Create: `lib/features/species_id/presentation/providers/recorded_nearby_providers.dart`
- Test: `test/features/species_id/presentation/recorded_nearby_providers_test.dart`

**Interfaces:**
- Consumes: Task 2's functions; `divePlaceRepositoryProvider` (`dive_species_run_providers.dart`) and its `placeOf(String diveId)` returning `({bool exists, GeoPoint? site, GeoPoint? entry})`; `reefNearbySpeciesProvider(GeoPoint)` returning `ReefPart<NearbySpecies>`.
- Produces:
  - `typedef NearbyListRequest = ({String? diveId, GeoPoint? photo});`
  - `NearbyListRequest nearbyRequestForMedia(MediaItem item)`: the item's `diveId`, and its `latitude`/`longitude` as `photo` when both are set.
  - `final recordedNearbyListProvider = FutureProvider.autoDispose.family<NearbySpecies?, NearbyListRequest>`: null when there is no place, or the part's status is not `ReefDataStatus.ok`; otherwise the part's value. It invalidates itself on `diveRepositoryProvider`'s `watchDivesChanges()` and `siteRepositoryProvider`'s `watchSitesChanges()`.

- [ ] **Step 1: Write the failing tests**

Build each container from `await getBaseOverrides()` plus a fake `divePlaceRepositoryProvider` (a `DivePlaceRepository` subclass overriding `placeOf`) and `reefNearbySpeciesProvider.overrideWith((ref, point) async { asked.add(point); return parts[point] ?? const ReefPart.empty(); })`.

```dart
test('reads the dive site's list, not the photo's position', () async {
  // dive d1: site S, entry E; request (diveId: 'd1', photo: P)
  expect(await container.read(recordedNearbyListProvider(request).future), listAtS);
  expect(asked, [S]);
});
test('with no place it asks for nothing', () async {
  // dive d1 with no site and no entry; photo null
  expect(await container.read(recordedNearbyListProvider((diveId: 'd1', photo: null)).future), isNull);
  expect(asked, isEmpty);
});
test('an empty or unavailable list gives null', () async { ... });
test('two dives at one site share one search', () async {
  // d1 and d2 both at site S. Listen to both requests before awaiting
  // either, as two rows on screen do, so the shared list stays alive.
  expect(asked, [S]);
});
test('a photo in no dive uses its own position', () async {
  // request (diveId: null, photo: P) -> asked == [P]
});
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/species_id/presentation/recorded_nearby_providers_test.dart`
Expected: FAIL, the provider does not exist.

- [ ] **Step 3: Implement** `recorded_nearby_providers.dart` as in the Interfaces block. A dive that `placeOf` reports as not existing has no site and no entry.

- [ ] **Step 4: Run to verify they pass**

Run: the command from Step 2. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/species_id/presentation/providers/recorded_nearby_providers.dart test/features/species_id/presentation/recorded_nearby_providers_test.dart
git commit -m "feat(species-id): read the recorded nearby list for a dive or photo"
```

### Task 4: The marker on the species sheet

**Files:**
- Create: `lib/features/species_id/presentation/widgets/recorded_nearby_line.dart`
- Modify: `lib/features/species_id/presentation/widgets/suggested_species_section.dart` (`_SuggestionRow`'s name, `SuggestionCropView`'s candidate `ListTile` subtitle)
- Test: `test/features/media/presentation/widgets/media_species_sheet_suggestions_test.dart`

**Interfaces:**
- Consumes: Task 3's `recordedNearbyListProvider`, `nearbyRequestForMedia`, `NearbyListRequest`; Task 2's `isRecordedNearby`.
- Produces: `class RecordedNearbyLine extends ConsumerWidget` with `const RecordedNearbyLine({super.key, required NearbyListRequest request, int? gbifKey, String? catalogId})`. It shows `Text(l10n.reef_species_recordedNearby, style: bodySmall)` only when the provider has a value and `isRecordedNearby` is true, else `SizedBox.shrink()`.

- [ ] **Step 1: Write the failing tests**

Give the file's pump a `NearbySpecies? nearby` parameter and a `Completer<NearbySpecies?>? pending` parameter, overriding `recordedNearbyListProvider.overrideWith((ref, request) => pending?.future ?? Future.value(nearby))`, so no test in the file reaches GBIF.

```dart
testWidgets('a suggestion recorded nearby says so', (tester) async {
  // nearby lists the first suggestion's gbifKey
  expect(find.descendant(of: find.byKey(ValueKey('media_suggested_row_$key1')), matching: find.text('Recorded nearby')), findsOneWidget);
  expect(find.descendant(of: find.byKey(ValueKey('media_suggested_row_$key2')), matching: find.text('Recorded nearby')), findsNothing);
});
testWidgets('while the list loads, no row shows the marker', (tester) async {
  // pending: a Completer never completed
  expect(find.text('Recorded nearby'), findsNothing);
});
testWidgets('with no list, no row shows the marker', (tester) async {
  // nearby: null
  expect(find.text('Recorded nearby'), findsNothing);
});
testWidgets('a possible match recorded nearby says so in the crop view', (tester) async {
  // open the crop of the first suggestion; nearby lists one alternative's key
  expect(find.descendant(of: find.byKey(ValueKey('media_suggested_candidate_$altKey')), matching: find.text('Recorded nearby')), findsOneWidget);
});
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/media/presentation/widgets/media_species_sheet_suggestions_test.dart`
Expected: the two "says so" tests fail; the rest pass.

- [ ] **Step 3: Implement** `RecordedNearbyLine`, then put it under the name in `_SuggestionRow` (the name and the line in a `Column` inside the existing `Expanded`, start-aligned) and under the scientific name in `SuggestionCropView`'s subtitle. Pass `nearbyRequestForMedia(item)`, the candidate's `gbifKey` and its `catalogId`.

- [ ] **Step 4: Run to verify they pass**

Run: the command from Step 2. Expected: every test in the file passes.

- [ ] **Step 5: Commit**

```bash
git add lib/features/species_id/presentation/widgets/recorded_nearby_line.dart lib/features/species_id/presentation/widgets/suggested_species_section.dart test/features/media/presentation/widgets/media_species_sheet_suggestions_test.dart
git commit -m "feat(species-id): mark suggestions recorded near the dive"
```

### Task 5: The marker in Species to review

**Files:**
- Modify: `lib/features/species_id/presentation/widgets/species_review_row.dart` (the row `ListTile`'s subtitle)
- Test: `test/features/species_id/presentation/species_review_page_test.dart`

**Interfaces:**
- Consumes: Task 4's `RecordedNearbyLine`; Task 3's `NearbyListRequest`.
- The row's request is `(diveId: row.best.media.diveId, photo: null)`. Its `gbifKey` is `row.candidate?.gbifKey`, else the first item's `suggestion?.top.candidate.gbifKey`. Its `catalogId` is `row.species?.id`, else `row.candidate?.catalogId`. Item lines under an expanded row get no marker: the row already says it.

- [ ] **Step 1: Write the failing tests**

Give the file's pump a `NearbySpecies? nearby` parameter overriding `recordedNearbyListProvider`, as in Task 4.

```dart
testWidgets('a suggested row recorded nearby says so', (tester) async {
  // nearby lists the suggested row's candidate gbifKey
  expect(find.descendant(of: find.byKey(suggestedRowKey), matching: find.text('Recorded nearby')), findsOneWidget);
});
testWidgets('a tagged row of a catalogue species on the list says so', (tester) async {
  // nearby.matched holds the tagged species' id; speciesKeys empty
  expect(find.descendant(of: find.byKey(taggedRowKey), matching: find.text('Recorded nearby')), findsOneWidget);
});
testWidgets('the marker is read with the row', (tester) async {
  expect(find.bySemanticsLabel(RegExp('Recorded nearby')), findsOneWidget);
});
testWidgets('with no list, no row shows the marker', (tester) async {
  expect(find.text('Recorded nearby'), findsNothing);
});
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/species_id/presentation/species_review_page_test.dart`
Expected: the three "says so" and semantics tests fail; the rest pass.

- [ ] **Step 3: Implement**: the subtitle becomes a start-aligned `Column` of the existing text and a `RecordedNearbyLine`, with the request, key and id above.

- [ ] **Step 4: Run to verify they pass**

Run: the command from Step 2. Expected: every test in the file passes.

- [ ] **Step 5: Commit**

```bash
git add lib/features/species_id/presentation/widgets/species_review_row.dart test/features/species_id/presentation/species_review_page_test.dart
git commit -m "feat(species-id): mark review rows recorded near the dive"
```

### Task 6: Checks and after screenshots

- [ ] **Step 1: Format and analyze**

Run: `dart format . && flutter analyze`
Expected: no changes left unformatted; "No issues found!".

- [ ] **Step 2: Run every test file this plan touched**

Run: `flutter test test/features/reef/domain/entities/nearby_species_test.dart test/features/reef/data/services/nearby_species_service_test.dart test/features/reef/data/repositories/reef_repository_test.dart test/features/species_id/domain/recorded_nearby_test.dart test/features/species_id/presentation/recorded_nearby_providers_test.dart test/features/media/presentation/widgets/media_species_sheet_suggestions_test.dart test/features/species_id/presentation/species_review_page_test.dart`
Expected: all pass. Architecture guards are left to the pre-push hook.

- [ ] **Step 3: Render the after screenshots** with Task 0's scratch test, the nearby list now listing one suggestion, one possible match and both review rows: `01-suggested-after.png`, `02-possible-matches-after.png`, `03-species-review-after.png`. Delete the scratch test afterwards; it is never committed.

- [ ] **Step 4: Commit any formatting changes**, with explicit paths, as `style: dart format`, only if Step 1 changed files.

## After the plan (each needs the maintainer's go)

- Open an issue for the marker (Refs #4668) and push the branch.
- Open the pull request with `Closes #<new issue>`, the before and after screenshots attached through the project's secret gist, and the spec and plan linked.
- Code review rounds and Copilot, as for the other marine life pieces.
