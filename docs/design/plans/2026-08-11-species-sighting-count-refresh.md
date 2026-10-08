# Species Sighting Count Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the cached species sighting-count map refresh after every committed write to the `sightings` table.

**Architecture:** Add a focused Drift table-update stream to `SpeciesRepository` and subscribe `speciesSightingCountsProvider` with Riverpod's `invalidateSelfWhen`. Prove the behavior with a provider integration test that writes a real sighting into the in-memory database and observes the cached provider refresh without manual invalidation.

**Tech Stack:** Dart, Flutter Test, Drift, Riverpod

## Global Constraints

- The tick must watch only the `sightings` table.
- The provider must refresh after direct database-backed writes without page-level invalidation.
- Do not change count calculation, selection behavior, or deletion behavior.
- Write and verify the behavioral regression test before production code.
- All Dart changes must pass `dart format` with no changes remaining.

---

## File Structure

| File | Responsibility |
| --- | --- |
| `test/features/marine_life/presentation/providers/species_providers_test.dart` | Proves the provider refreshes after the table it reads changes. |
| `lib/features/marine_life/data/repositories/species_repository.dart` | Exposes the focused `sightings` table change stream. |
| `lib/features/marine_life/presentation/providers/species_providers.dart` | Subscribes the count provider to the new stream. |

### Task 1: Refresh sighting counts from the sightings-table tick

**Files:**
- Modify: `test/features/marine_life/presentation/providers/species_providers_test.dart`
- Modify: `lib/features/marine_life/data/repositories/species_repository.dart`
- Modify: `lib/features/marine_life/presentation/providers/species_providers.dart`

**Interfaces:**
- Consumes: `AppDatabase`, `DivesCompanion`, `SpeciesRepository.addSighting`, `SpeciesRepository.sightingCountsBySpecies`, and `Ref.invalidateSelfWhen`.
- Produces: `SpeciesRepository.watchSightingChanges() -> Stream<void>` and an automatically refreshing `speciesSightingCountsProvider`.

- [ ] **Step 1: Add a minimal real-database test fixture**

Add the Drift, database, and database-service imports to
`species_providers_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
```

Then add this helper before `main()`:

```dart
Future<void> _insertTestDive({required String id}) async {
  final db = DatabaseService.instance.database;
  final now = DateTime.now().millisecondsSinceEpoch;
  await db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diveDateTime: Value(now),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
}
```

- [ ] **Step 2: Write the failing provider behavior test**

Add this group between `allSpeciesProvider` and
`speciesListNotifierProvider`:

```dart
group('speciesSightingCountsProvider', () {
  test('auto-refreshes after a sighting is written directly to the DB '
      '(sync scenario)', () async {
    final species = await speciesRepo.createSpecies(
      commonName: 'Counted Grouper',
      category: SpeciesCategory.fish,
    );
    await _insertTestDive(id: 'counted-dive');

    final container = makeContainer();
    addTearDown(container.dispose);
    final sub = container.listen(speciesSightingCountsProvider, (_, _) {});
    addTearDown(sub.close);

    expect(await container.read(speciesSightingCountsProvider.future), isEmpty);

    await speciesRepo.addSighting(
      diveId: 'counted-dive',
      speciesId: species.id,
    );

    var counts = <String, int>{};
    for (var i = 0; i < 50; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      counts = await container.read(speciesSightingCountsProvider.future);
      if (counts[species.id] == 1) break;
    }

    expect(
      counts,
      {species.id: 1},
      reason:
          'speciesSightingCountsProvider should refresh after a sightings '
          'table write without manual invalidation',
    );
  });
});
```

The production mutation this test catches is removal or omission of the
`watchSightingChanges()` subscription. Its expected map is hand-derived from
the single inserted sighting.

- [ ] **Step 3: Run the provider test and verify the new test fails**

Run:

```bash
flutter test test/features/marine_life/presentation/providers/species_providers_test.dart
```

Expected: the new `speciesSightingCountsProvider` test fails because `counts`
remains empty. Existing tests in the file continue to pass.

- [ ] **Step 4: Add the focused repository tick**

Immediately after `watchSpeciesChanges()` in `species_repository.dart`, add:

```dart
/// Emits whenever the `sightings` table changes so aggregate providers can
/// refresh after a sync or any other write.
Stream<void> watchSightingChanges() =>
    _db.tableUpdates(TableUpdateQuery.onTable(_db.sightings));
```

- [ ] **Step 5: Subscribe the provider to the focused tick**

Replace the body of `speciesSightingCountsProvider` with:

```dart
final repository = ref.watch(speciesRepositoryProvider);
ref.invalidateSelfWhen(repository.watchSightingChanges());
return repository.sightingCountsBySpecies();
```

- [ ] **Step 6: Run targeted tests and verify green**

Run:

```bash
flutter test \
  test/features/marine_life/presentation/providers/species_providers_test.dart \
  test/architecture/provider_change_tick_test.dart
```

Expected: both files pass with zero failures. This proves both the runtime
behavior and the architecture rule.

- [ ] **Step 7: Format and run static analysis**

Run:

```bash
dart format lib/ test/
git diff --exit-code --check
flutter analyze
```

Expected: formatting leaves no pending formatting changes after the first run,
the diff check exits zero, and analysis reports no issues.

- [ ] **Step 8: Run the full Flutter test suite**

Run:

```bash
flutter test
```

Expected: the full suite passes with zero failures.

- [ ] **Step 9: Commit the implementation**

Stage only the three implementation files and commit:

```bash
git add \
  lib/features/marine_life/data/repositories/species_repository.dart \
  lib/features/marine_life/presentation/providers/species_providers.dart \
  test/features/marine_life/presentation/providers/species_providers_test.dart
git commit -m "fix: refresh species sighting counts"
```
