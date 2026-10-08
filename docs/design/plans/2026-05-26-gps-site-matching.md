# GPS Site Matching Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Automatically match downloaded dives that carry entry GPS to an existing user site or a bundled "import" site, applying high-confidence matches automatically and surfacing the rest on a review screen.

**Architecture:** A pure `matchDive` domain function (inner/outer radius + separation + existing-site precedence → `AutoMatch | Suggested | NoMatch`); a stateful `SiteMatchingService` that gathers candidates (user `SiteRepository` + bundled `DiveSiteApiService`), runs the matcher, and applies results (link existing / materialize+link bundled, with batch dedup, a ~100 m coincidence guard, and orphan rollback); a Riverpod-backed `SiteMatchReviewPage` reached post-download and from the dives-list overflow menu. Configurable via a `siteMatchSensitivity` diver setting.

**Tech Stack:** Flutter, Drift (SQLite), Riverpod (`StateNotifier`), go_router, mockito (`@GenerateMocks`), flutter_test.

**Phasing (each phase ends with working, tested software):**
- **Phase A** — pure matcher (Tasks 1-5)
- **Phase B** — repository extensions (Task 6)
- **Phase C** — matching service (Tasks 7-9)
- **Phase D** — review screen + notifier (Tasks 10-11)
- **Phase E** — entry points: route, dives-list menu, post-download (Tasks 12-14)
- **Phase F** — configurable sensitivity setting (Tasks 15-17)

By end of Phase E the feature works end-to-end using the Balanced default. Phase F adds the user-facing control.

---

## File Structure

**New files:**

| Path | Responsibility |
|---|---|
| `lib/features/dive_sites/domain/matching/match_thresholds.dart` | Immutable `MatchThresholds` value (inner/outer/separation metres) |
| `lib/features/dive_sites/domain/matching/site_match_sensitivity.dart` | `SiteMatchSensitivity` enum + `.thresholds` mapping + `fromName` |
| `lib/features/dive_sites/domain/matching/match_candidate.dart` | `MatchCandidate` (id, location, isExisting) the matcher reasons over |
| `lib/features/dive_sites/domain/matching/site_match_outcome.dart` | `SiteMatchOutcome` sealed type: `AutoMatch` / `Suggested` / `NoMatch`, `RankedCandidate` |
| `lib/features/dive_sites/domain/matching/site_matcher.dart` | Pure `matchDive(...)` function |
| `lib/features/dive_sites/data/services/site_matching_service.dart` | Candidate gathering, apply, dedup, coincidence guard, rollback |
| `lib/features/dive_sites/presentation/providers/site_match_review_notifier.dart` | `SiteMatchReviewState` + `SiteMatchReviewNotifier` + provider |
| `lib/features/dive_sites/presentation/pages/site_match_review_page.dart` | The review UI (three grouped sections) |
| `test/features/dive_sites/domain/matching/site_matcher_test.dart` | Exhaustive matcher unit tests |
| `test/features/dive_sites/domain/matching/site_match_sensitivity_test.dart` | Threshold mapping tests |
| `test/features/dive_sites/data/services/site_matching_service_test.dart` | Service behaviour tests (mocked repos) |
| `test/features/dive_sites/presentation/pages/site_match_review_page_test.dart` | Review-screen smoke test |

**Modified files:**

| Path | Change |
|---|---|
| `lib/features/dive_log/data/repositories/dive_repository_impl.dart` | Add `setSite(diveId, siteId?)` and `getDivesNeedingSiteMatch({diverId, limitToIds})` |
| `lib/core/database/database.dart` | Add `siteMatchSensitivity` column to the diver-settings table + migration |
| `lib/features/settings/presentation/providers/settings_providers.dart` | `AppSettings.siteMatchSensitivity` field + default + copyWith + `SettingsNotifier.setSiteMatchSensitivity` |
| (diver-settings repository — see Task 15) | Persist/read the new column |
| `lib/features/settings/presentation/pages/section_appearance_page.dart` (or settings home) | Sensitivity picker |
| `lib/features/dive_log/presentation/pages/dive_list_page.dart` | "Match dives to sites" overflow item |
| `lib/core/router/app_router.dart` | `/dives/match-sites` route |
| `lib/features/import_wizard/presentation/widgets/import_summary_step.dart` | "Match N dives to sites" button when eligible imported dives exist |
| `lib/l10n/arb/app_en.arb` | New UI strings |
| `test/helpers/mock_providers.dart`, `test/l10n/localization_test.dart`, `test/features/statistics/presentation/pages/records_page_test.dart`, `test/core/presentation/widgets/dive_comparison_card_test.dart` | Add `setSiteMatchSensitivity` override to the 4 settings mocks |

---

## Phase A — Pure matcher

### Task 1: `MatchThresholds`

**Files:**
- Create: `lib/features/dive_sites/domain/matching/match_thresholds.dart`

- [ ] **Step 1: Create the value type**

```dart
/// Distance thresholds (metres) controlling auto-match confidence.
class MatchThresholds {
  /// A match within this distance with no close competitor is auto-applied.
  final double innerRadiusMeters;

  /// Candidates within this distance are shown as suggestions.
  final double outerRadiusMeters;

  /// The runner-up must be at least this much farther than the nearest for
  /// the nearest to count as a clear (auto) match.
  final double separationMeters;

  const MatchThresholds({
    required this.innerRadiusMeters,
    required this.outerRadiusMeters,
    required this.separationMeters,
  });
}
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/features/dive_sites/domain/matching/match_thresholds.dart`
Expected: "No issues found!"

- [ ] **Step 3: Commit**

```bash
git add lib/features/dive_sites/domain/matching/match_thresholds.dart
git commit -m "feat(site-matching): add MatchThresholds value type"
```

---

### Task 2: `SiteMatchSensitivity` enum + threshold presets

**Files:**
- Create: `lib/features/dive_sites/domain/matching/site_match_sensitivity.dart`
- Test: `test/features/dive_sites/domain/matching/site_match_sensitivity_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/matching/site_match_sensitivity.dart';

void main() {
  group('SiteMatchSensitivity', () {
    test('balanced preset thresholds', () {
      final t = SiteMatchSensitivity.balanced.thresholds;
      expect(t.innerRadiusMeters, 150);
      expect(t.outerRadiusMeters, 1000);
      expect(t.separationMeters, 75);
    });

    test('strict is tighter than relaxed', () {
      expect(
        SiteMatchSensitivity.strict.thresholds.innerRadiusMeters,
        lessThan(SiteMatchSensitivity.relaxed.thresholds.innerRadiusMeters),
      );
    });

    test('fromName falls back to balanced for unknown', () {
      expect(SiteMatchSensitivity.fromName('nonsense'),
          SiteMatchSensitivity.balanced);
      expect(SiteMatchSensitivity.fromName('strict'),
          SiteMatchSensitivity.strict);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_sites/domain/matching/site_match_sensitivity_test.dart`
Expected: FAIL — `site_match_sensitivity.dart` does not exist / `SiteMatchSensitivity` undefined.

- [ ] **Step 3: Implement the enum**

```dart
import 'package:submersion/features/dive_sites/domain/matching/match_thresholds.dart';

/// User-facing sensitivity preset for auto site matching.
enum SiteMatchSensitivity {
  strict,
  balanced,
  relaxed;

  static SiteMatchSensitivity fromName(String name) {
    return SiteMatchSensitivity.values.firstWhere(
      (e) => e.name == name,
      orElse: () => SiteMatchSensitivity.balanced,
    );
  }

  MatchThresholds get thresholds {
    switch (this) {
      case SiteMatchSensitivity.strict:
        return const MatchThresholds(
          innerRadiusMeters: 100,
          outerRadiusMeters: 500,
          separationMeters: 100,
        );
      case SiteMatchSensitivity.balanced:
        return const MatchThresholds(
          innerRadiusMeters: 150,
          outerRadiusMeters: 1000,
          separationMeters: 75,
        );
      case SiteMatchSensitivity.relaxed:
        return const MatchThresholds(
          innerRadiusMeters: 300,
          outerRadiusMeters: 2000,
          separationMeters: 50,
        );
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_sites/domain/matching/site_match_sensitivity_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_sites/domain/matching/site_match_sensitivity.dart test/features/dive_sites/domain/matching/site_match_sensitivity_test.dart
git commit -m "feat(site-matching): add SiteMatchSensitivity presets"
```

---

### Task 3: `MatchCandidate`

**Files:**
- Create: `lib/features/dive_sites/domain/matching/match_candidate.dart`

- [ ] **Step 1: Create the type**

```dart
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// A site the matcher considers for one dive. `id` is an existing site id when
/// [isExisting] is true, otherwise a bundled site's `externalId`.
class MatchCandidate {
  final String id;
  final GeoPoint location;
  final bool isExisting;

  const MatchCandidate({
    required this.id,
    required this.location,
    required this.isExisting,
  });
}
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/features/dive_sites/domain/matching/match_candidate.dart`
Expected: "No issues found!"

- [ ] **Step 3: Commit**

```bash
git add lib/features/dive_sites/domain/matching/match_candidate.dart
git commit -m "feat(site-matching): add MatchCandidate type"
```

---

### Task 4: `SiteMatchOutcome` sealed type

**Files:**
- Create: `lib/features/dive_sites/domain/matching/site_match_outcome.dart`

- [ ] **Step 1: Create the types**

```dart
import 'package:submersion/features/dive_sites/domain/matching/match_candidate.dart';

/// A candidate paired with its computed distance to the dive's GPS point.
class RankedCandidate {
  final MatchCandidate candidate;
  final double distanceMeters;

  const RankedCandidate(this.candidate, this.distanceMeters);
}

/// Result of matching one dive's GPS against candidate sites.
sealed class SiteMatchOutcome {
  const SiteMatchOutcome();
}

/// High-confidence single match to auto-apply.
class AutoMatch extends SiteMatchOutcome {
  final String siteId; // existing site id or bundled externalId
  final bool isExisting;
  final double distanceMeters;

  const AutoMatch({
    required this.siteId,
    required this.isExisting,
    required this.distanceMeters,
  });
}

/// One or more candidates worth showing, needing user confirmation/choice.
class Suggested extends SiteMatchOutcome {
  final List<RankedCandidate> candidates; // distance-sorted, length >= 1

  const Suggested(this.candidates);
}

/// Nothing within the outer radius.
class NoMatch extends SiteMatchOutcome {
  const NoMatch();
}
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/features/dive_sites/domain/matching/site_match_outcome.dart`
Expected: "No issues found!"

- [ ] **Step 3: Commit**

```bash
git add lib/features/dive_sites/domain/matching/site_match_outcome.dart
git commit -m "feat(site-matching): add SiteMatchOutcome sealed type"
```

---

### Task 5: `matchDive` — the confidence rule

**Files:**
- Create: `lib/features/dive_sites/domain/matching/site_matcher.dart`
- Test: `test/features/dive_sites/domain/matching/site_matcher_test.dart`

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/matching/match_candidate.dart';
import 'package:submersion/features/dive_sites/domain/matching/match_thresholds.dart';
import 'package:submersion/features/dive_sites/domain/matching/site_match_outcome.dart';
import 'package:submersion/features/dive_sites/domain/matching/site_matcher.dart';

const _balanced = MatchThresholds(
  innerRadiusMeters: 150,
  outerRadiusMeters: 1000,
  separationMeters: 75,
);

// ~0.001 deg longitude at the equator is ~111 m. Build points by metres east.
GeoPoint _origin() => const GeoPoint(0, 0);
GeoPoint _eastMeters(double m) => GeoPoint(0, m / 111320.0);

MatchCandidate _existing(String id, double metersEast) =>
    MatchCandidate(id: id, location: _eastMeters(metersEast), isExisting: true);
MatchCandidate _bundled(String id, double metersEast) =>
    MatchCandidate(id: id, location: _eastMeters(metersEast), isExisting: false);

void main() {
  group('matchDive', () {
    test('no candidates in range -> NoMatch', () {
      final out = matchDive(
        point: _origin(),
        candidates: [_existing('a', 5000)],
        thresholds: _balanced,
      );
      expect(out, isA<NoMatch>());
    });

    test('single existing within inner -> AutoMatch', () {
      final out = matchDive(
        point: _origin(),
        candidates: [_existing('a', 40)],
        thresholds: _balanced,
      );
      expect(out, isA<AutoMatch>());
      final auto = out as AutoMatch;
      expect(auto.siteId, 'a');
      expect(auto.isExisting, true);
    });

    test('two existing within inner, too close -> Suggested', () {
      final out = matchDive(
        point: _origin(),
        candidates: [_existing('a', 40), _existing('b', 80)], // gap 40 < 75
        thresholds: _balanced,
      );
      expect(out, isA<Suggested>());
      expect((out as Suggested).candidates.length, 2);
    });

    test('two existing within inner, well separated -> AutoMatch nearest', () {
      final out = matchDive(
        point: _origin(),
        candidates: [_existing('a', 20), _existing('b', 120)], // gap 100 >= 75
        thresholds: _balanced,
      );
      expect(out, isA<AutoMatch>());
      expect((out as AutoMatch).siteId, 'a');
    });

    test('existing within inner beats closer bundled (precedence)', () {
      final out = matchDive(
        point: _origin(),
        candidates: [_bundled('b', 30), _existing('a', 120)],
        thresholds: _balanced,
      );
      expect(out, isA<AutoMatch>());
      final auto = out as AutoMatch;
      expect(auto.siteId, 'a');
      expect(auto.isExisting, true);
    });

    test('only bundled within inner -> AutoMatch bundled', () {
      final out = matchDive(
        point: _origin(),
        candidates: [_bundled('b', 50)],
        thresholds: _balanced,
      );
      expect(out, isA<AutoMatch>());
      final auto = out as AutoMatch;
      expect(auto.siteId, 'b');
      expect(auto.isExisting, false);
    });

    test('single loose candidate (outside inner, inside outer) -> Suggested', () {
      final out = matchDive(
        point: _origin(),
        candidates: [_existing('a', 400)],
        thresholds: _balanced,
      );
      expect(out, isA<Suggested>());
      expect((out as Suggested).candidates.single.candidate.id, 'a');
    });

    test('Suggested candidates are distance-sorted across both pools', () {
      final out = matchDive(
        point: _origin(),
        candidates: [_existing('far', 900), _bundled('near', 300)],
        thresholds: _balanced,
      );
      expect(out, isA<Suggested>());
      final s = out as Suggested;
      expect(s.candidates.first.candidate.id, 'near');
      expect(s.candidates.last.candidate.id, 'far');
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/dive_sites/domain/matching/site_matcher_test.dart`
Expected: FAIL — `site_matcher.dart` / `matchDive` undefined.

- [ ] **Step 3: Implement `matchDive`**

```dart
import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/matching/match_candidate.dart';
import 'package:submersion/features/dive_sites/domain/matching/match_thresholds.dart';
import 'package:submersion/features/dive_sites/domain/matching/site_match_outcome.dart';

/// Matches one dive GPS [point] against [candidates].
///
/// Rules, in order:
/// 1. Rank candidates by distance; keep those within the outer radius.
///    None -> [NoMatch].
/// 2. Pool selection: if any existing site is within the inner radius, the
///    auto-decision considers only those (existing-site precedence — never
///    auto-create a bundled duplicate when the user already has a site here);
///    otherwise consider every candidate within the inner radius.
/// 3. The nearest in the pool is a clear [AutoMatch] when it has no in-pool
///    competitor, or the runner-up is farther by at least the separation
///    margin. Otherwise -> [Suggested] (all in-range candidates, both pools).
SiteMatchOutcome matchDive({
  required GeoPoint point,
  required List<MatchCandidate> candidates,
  required MatchThresholds thresholds,
}) {
  final ranked = candidates
      .map((c) => RankedCandidate(c, distanceMeters(point, c.location)))
      .toList()
    ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));

  final inRange = ranked
      .where((r) => r.distanceMeters <= thresholds.outerRadiusMeters)
      .toList();
  if (inRange.isEmpty) return const NoMatch();

  final innerExisting = inRange
      .where((r) =>
          r.candidate.isExisting &&
          r.distanceMeters <= thresholds.innerRadiusMeters)
      .toList();
  final innerAny = inRange
      .where((r) => r.distanceMeters <= thresholds.innerRadiusMeters)
      .toList();

  final pool = innerExisting.isNotEmpty ? innerExisting : innerAny;
  if (pool.isEmpty) return Suggested(inRange);

  final nearest = pool.first;
  final clear = pool.length == 1 ||
      (pool[1].distanceMeters - nearest.distanceMeters) >=
          thresholds.separationMeters;

  if (clear) {
    return AutoMatch(
      siteId: nearest.candidate.id,
      isExisting: nearest.candidate.isExisting,
      distanceMeters: nearest.distanceMeters,
    );
  }
  return Suggested(inRange);
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/dive_sites/domain/matching/site_matcher_test.dart`
Expected: PASS (8 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_sites/domain/matching/site_matcher.dart test/features/dive_sites/domain/matching/site_matcher_test.dart
git commit -m "feat(site-matching): add pure matchDive confidence rule"
```

> **Phase A checkpoint:** the entire confidence rule exists and is exhaustively tested with zero mocks.

---

## Phase B — Repository extensions

### Task 6: `DiveRepository.setSite` and `getDivesNeedingSiteMatch`

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart`
- Test: `test/features/dive_log/data/repositories/dive_repository_site_match_test.dart`

Context: `DiveRepository` is a concrete class with `AppDatabase get _db => DatabaseService.instance.database;`. `import 'package:drift/drift.dart';` (provides `Value`, `DivesCompanion`) is already present. Tests use the in-memory DB helper at `test/helpers/test_database.dart`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late DiveRepository repo;

  setUp(() async {
    await initTestDatabase(); // wires DatabaseService.instance to an in-memory db
    repo = DiveRepository();
  });

  tearDown(() async {
    await DatabaseService.instance.database.close();
  });

  test('setSite assigns and clears a dive site id', () async {
    final dive = await seedDiveWithGps(repo); // helper: creates a dive, no site
    final site = await seedSite(); // helper: creates a DiveSites row, returns id

    await repo.setSite(dive.id, site);
    expect((await repo.getDiveById(dive.id))!.site?.id, site);

    await repo.setSite(dive.id, null);
    expect((await repo.getDiveById(dive.id))!.site, isNull);
  });

  test('getDivesNeedingSiteMatch returns only GPS+unsited dives', () async {
    final withGps = await seedDiveWithGps(repo); // entry lat/lng set, no site
    await seedDiveWithoutGps(repo); // no lat/lng
    final sited = await seedDiveWithGps(repo);
    final site = await seedSite();
    await repo.setSite(sited.id, site);

    final result = await repo.getDivesNeedingSiteMatch();
    expect(result.map((d) => d.id), contains(withGps.id));
    expect(result.map((d) => d.id), isNot(contains(sited.id)));
    expect(result.length, 1);
  });
}
```

> If `seedDiveWithGps` / `seedSite` / `seedDiveWithoutGps` / `initTestDatabase` helpers do not already exist in `test/helpers/`, add thin helpers there following the existing `test/helpers/test_database.dart` patterns. Inspect that file first and reuse its db-construction helper.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/data/repositories/dive_repository_site_match_test.dart`
Expected: FAIL — `setSite` / `getDivesNeedingSiteMatch` undefined.

- [ ] **Step 3: Implement the two methods**

Add to `DiveRepository` (place near `updateDive`). Mirrors the existing targeted-update pattern (`..where((t) => t.id.equals(...)).write(DivesCompanion(...))`):

```dart
/// Sets (or clears, when [siteId] is null) only the site association of a dive.
/// Single-column update — does not rewrite the whole row.
Future<void> setSite(String diveId, String? siteId) async {
  try {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.dives)..where((t) => t.id.equals(diveId))).write(
      DivesCompanion(
        siteId: Value(siteId),
        updatedAt: Value(now),
      ),
    );
    await _syncRepository.markRecordPending(
      entityType: 'dives',
      recordId: diveId,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  } catch (e, stackTrace) {
    _log.error('Failed to set site on dive: $diveId',
        error: e, stackTrace: stackTrace);
    rethrow;
  }
}

/// Dives that have entry or exit GPS but no assigned site.
/// When [limitToIds] is provided, restricts to that id set (post-download seed).
Future<List<domain.Dive>> getDivesNeedingSiteMatch({
  String? diverId,
  List<String>? limitToIds,
}) async {
  try {
    final matchingIds = await _db.customSelect(
      '''
      SELECT d.id
      FROM dives d
      WHERE d.site_id IS NULL
        AND (
          (d.entry_latitude IS NOT NULL AND d.entry_longitude IS NOT NULL)
          OR (d.exit_latitude IS NOT NULL AND d.exit_longitude IS NOT NULL)
        )
        ${diverId != null ? 'AND d.diver_id = ?' : ''}
      ''',
      variables: diverId != null ? [Variable<String>(diverId)] : const [],
    ).get();

    var ids = matchingIds.map((r) => r.data['id'] as String).toList();
    if (limitToIds != null) {
      final allowed = limitToIds.toSet();
      ids = ids.where(allowed.contains).toList();
    }
    if (ids.isEmpty) return [];

    final rows = await (_db.select(_db.dives)
          ..where((t) => t.id.isIn(ids))
          ..orderBy([(t) => OrderingTerm.desc(t.diveDateTime)]))
        .get();
    return Future.wait(rows.map(_mapRowToDive));
  } catch (e, stackTrace) {
    _log.error('Failed to get dives needing site match',
        error: e, stackTrace: stackTrace);
    rethrow;
  }
}
```

> Verify the actual column name for the dive timestamp ordering: CLAUDE.md notes the column is `diveDateTime` (DB column `dive_date_time`). If `_mapRowToDive` or other queries here order by a different existing column, match them. Confirm `domain` is the import alias already used in this file for domain entities (it is, per `Future<domain.Dive?> getDiveById`).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/data/repositories/dive_repository_site_match_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Run analyze + commit**

Run: `flutter analyze lib/features/dive_log/data/repositories/dive_repository_impl.dart`
Expected: "No issues found!"

```bash
git add lib/features/dive_log/data/repositories/dive_repository_impl.dart test/features/dive_log/data/repositories/dive_repository_site_match_test.dart test/helpers/
git commit -m "feat(site-matching): add DiveRepository.setSite and getDivesNeedingSiteMatch"
```

---

## Phase C — Matching service

The service is stateful per review session (batch dedup + rollback tracking). It is constructed with a `SiteRepository`, a `DiveSiteApiService`, a `DiveRepository`, and the current `diverId`. All three repos are concrete classes; mockito mocks them via `@GenerateMocks`.

### Task 7: Service skeleton, candidate gathering, and result model

**Files:**
- Create: `lib/features/dive_sites/data/services/site_matching_service.dart`
- Test: `test/features/dive_sites/data/services/site_matching_service_test.dart`

- [ ] **Step 1: Define the presentation result model + service shell**

```dart
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/services/dive_site_api_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/matching/match_candidate.dart';
import 'package:submersion/features/dive_sites/domain/matching/match_thresholds.dart';
import 'package:submersion/features/dive_sites/domain/matching/site_match_outcome.dart';
import 'package:submersion/features/dive_sites/domain/matching/site_matcher.dart';

enum MatchEntryStatus { autoMatched, needsReview, noMatch }

/// A display candidate for the review screen (resolved name + distance).
class MatchCandidateView {
  final String id; // existing site id or bundled externalId
  final String name;
  final bool isExisting;
  final double distanceMeters;

  const MatchCandidateView({
    required this.id,
    required this.name,
    required this.isExisting,
    required this.distanceMeters,
  });
}

/// One dive's matching result, ready for the UI.
class DiveMatchEntry {
  final Dive dive;
  final MatchEntryStatus status;
  final String? siteId; // when matched
  final String? siteName; // when matched
  final double? distanceMeters;
  final bool isNewlyCreated; // bundled site materialised by this match
  final List<MatchCandidateView> candidates; // for needsReview

  const DiveMatchEntry({
    required this.dive,
    required this.status,
    this.siteId,
    this.siteName,
    this.distanceMeters,
    this.isNewlyCreated = false,
    this.candidates = const [],
  });

  DiveMatchEntry copyWith({
    MatchEntryStatus? status,
    String? siteId,
    String? siteName,
    double? distanceMeters,
    bool? isNewlyCreated,
    List<MatchCandidateView>? candidates,
    bool clearSite = false,
  }) {
    return DiveMatchEntry(
      dive: dive,
      status: status ?? this.status,
      siteId: clearSite ? null : (siteId ?? this.siteId),
      siteName: clearSite ? null : (siteName ?? this.siteName),
      distanceMeters: clearSite ? null : (distanceMeters ?? this.distanceMeters),
      isNewlyCreated: clearSite ? false : (isNewlyCreated ?? this.isNewlyCreated),
      candidates: candidates ?? this.candidates,
    );
  }
}

class SiteMatchingService {
  SiteMatchingService({
    required SiteRepository siteRepository,
    required DiveSiteApiService apiService,
    required DiveRepository diveRepository,
    required this.diverId,
    required this.thresholds,
  })  : _siteRepository = siteRepository,
        _apiService = apiService,
        _diveRepository = diveRepository;

  final SiteRepository _siteRepository;
  final DiveSiteApiService _apiService;
  final DiveRepository _diveRepository;
  final String? diverId;
  final MatchThresholds thresholds;

  // Per-session state.
  List<DiveSite> _userSites = const [];
  final Map<String, String> _createdByExternalId = {}; // externalId -> new site id
  final Map<String, Set<String>> _createdSiteRefs = {}; // created site id -> diveIds
  // Per-dive resolved candidate objects, keyed by candidate id, for applying.
  final Map<String, Map<String, _CandidateRef>> _refsByDive = {};

  GeoPoint? _pointFor(Dive dive) => dive.entryLocation ?? dive.exitLocation;
  // ... run / link / unlink added in later tasks ...
}

class _CandidateRef {
  final DiveSite? existing; // non-null when existing
  final ExternalDiveSite? bundled; // non-null when bundled
  const _CandidateRef.existing(this.existing) : bundled = null;
  const _CandidateRef.bundled(this.bundled) : existing = null;
}
```

- [ ] **Step 2: Write the failing test for `run` (gathering + outcomes)**

Create the test file with mocks declared. (`createSite` returns the site with a generated id; mirror that in the mock.)

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/services/dive_site_api_service.dart';
import 'package:submersion/features/dive_sites/data/services/site_matching_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/matching/site_match_sensitivity.dart';

@GenerateMocks([SiteRepository, DiveSiteApiService, DiveRepository])
import 'site_matching_service_test.mocks.dart';

Dive _diveAt(String id, double lat, double lng) => Dive(
      id: id,
      diveNumber: 1,
      diveDateTime: DateTime(2026, 1, 1),
      maxDepth: 18,
      duration: const Duration(minutes: 40),
      entryLocation: GeoPoint(lat, lng),
    );

SiteMatchingService _service(
  MockSiteRepository sites,
  MockDiveSiteApiService api,
  MockDiveRepository dives,
) =>
    SiteMatchingService(
      siteRepository: sites,
      apiService: api,
      diveRepository: dives,
      diverId: 'diver-1',
      thresholds: SiteMatchSensitivity.balanced.thresholds,
    );

void main() {
  late MockSiteRepository sites;
  late MockDiveSiteApiService api;
  late MockDiveRepository dives;

  setUp(() {
    sites = MockSiteRepository();
    api = MockDiveSiteApiService();
    dives = MockDiveRepository();
    when(api.searchNearby(
      latitude: anyNamed('latitude'),
      longitude: anyNamed('longitude'),
      radiusKm: anyNamed('radiusKm'),
    )).thenAnswer((_) async => const DiveSiteSearchResult(sites: []));
    when(dives.setSite(any, any)).thenAnswer((_) async {});
  });

  test('auto-links an existing site within inner radius', () async {
    final existing = const DiveSite(id: 's1', name: 'Blue Hole',
        location: GeoPoint(0, 0));
    when(sites.getAllSites(diverId: anyNamed('diverId')))
        .thenAnswer((_) async => [existing]);

    final entries = await _service(sites, api, dives)
        .run([_diveAt('d1', 0, 0.0003)]); // ~33 m east

    expect(entries.single.status, MatchEntryStatus.autoMatched);
    expect(entries.single.siteId, 's1');
    verify(dives.setSite('d1', 's1')).called(1);
  });

  test('no candidates -> noMatch, no write', () async {
    when(sites.getAllSites(diverId: anyNamed('diverId')))
        .thenAnswer((_) async => const []);

    final entries = await _service(sites, api, dives)
        .run([_diveAt('d1', 10, 10)]);

    expect(entries.single.status, MatchEntryStatus.noMatch);
    verifyNever(dives.setSite(any, any));
  });
}
```

> Check the actual required `Dive` constructor parameters in `lib/features/dive_log/domain/entities/dive.dart` and adjust `_diveAt` so it compiles (the entity has many optional fields; supply only required ones plus `entryLocation`).

- [ ] **Step 3: Generate mocks, run test to verify it fails**

Run: `dart run build_runner build --delete-conflicting-outputs`
Then: `flutter test test/features/dive_sites/data/services/site_matching_service_test.dart`
Expected: FAIL — `run` not implemented.

- [ ] **Step 4: Implement `run` (gather, match, apply auto)**

Add to `SiteMatchingService`:

```dart
Future<List<DiveMatchEntry>> run(List<Dive> dives) async {
  _userSites = (await _siteRepository.getAllSites(diverId: diverId))
      .where((s) => s.location != null)
      .toList();

  final entries = <DiveMatchEntry>[];
  for (final dive in dives) {
    final point = _pointFor(dive);
    if (point == null) continue;

    final bundled = await _apiService.searchNearby(
      latitude: point.latitude,
      longitude: point.longitude,
      radiusKm: thresholds.outerRadiusMeters / 1000.0,
    );

    final refs = <String, _CandidateRef>{};
    final candidates = <MatchCandidate>[];
    for (final s in _userSites) {
      refs[s.id] = _CandidateRef.existing(s);
      candidates.add(MatchCandidate(
          id: s.id, location: s.location!, isExisting: true));
    }
    for (final b in bundled.sites) {
      if (!b.hasCoordinates) continue;
      refs[b.externalId] = _CandidateRef.bundled(b);
      candidates.add(MatchCandidate(
        id: b.externalId,
        location: GeoPoint(b.latitude!, b.longitude!),
        isExisting: false,
      ));
    }
    _refsByDive[dive.id] = refs;

    final outcome = matchDive(
        point: point, candidates: candidates, thresholds: thresholds);
    entries.add(await _toEntry(dive, outcome, refs));
  }
  return entries;
}

Future<DiveMatchEntry> _toEntry(
  Dive dive,
  SiteMatchOutcome outcome,
  Map<String, _CandidateRef> refs,
) async {
  switch (outcome) {
    case NoMatch():
      return DiveMatchEntry(dive: dive, status: MatchEntryStatus.noMatch);
    case Suggested(:final candidates):
      return DiveMatchEntry(
        dive: dive,
        status: MatchEntryStatus.needsReview,
        candidates: candidates
            .map((r) => MatchCandidateView(
                  id: r.candidate.id,
                  name: _nameOf(refs[r.candidate.id]!),
                  isExisting: r.candidate.isExisting,
                  distanceMeters: r.distanceMeters,
                ))
            .toList(),
      );
    case AutoMatch(:final siteId, :final distanceMeters):
      final applied = await _applyCandidate(dive.id, refs[siteId]!);
      return DiveMatchEntry(
        dive: dive,
        status: MatchEntryStatus.autoMatched,
        siteId: applied.siteId,
        siteName: applied.siteName,
        distanceMeters: distanceMeters,
        isNewlyCreated: applied.isNewlyCreated,
      );
  }
}

String _nameOf(_CandidateRef ref) =>
    ref.existing?.name ?? ref.bundled!.name;
```

`_applyCandidate` is implemented in Task 8 — add a temporary stub so this task compiles and its two tests pass. `AppliedMatch` is public because Task 9's `link` returns it to the notifier:

```dart
/// The site actually linked by an apply (resolves bundled -> real created id).
class AppliedMatch {
  final String siteId; // the real DiveSites row id (never a bundled externalId)
  final String siteName;
  final bool isNewlyCreated;
  const AppliedMatch({
    required this.siteId,
    required this.siteName,
    required this.isNewlyCreated,
  });
}

Future<AppliedMatch> _applyCandidate(String diveId, _CandidateRef ref) async {
  // Existing-only path for Task 7; bundled handled in Task 8.
  final site = ref.existing!;
  await _diveRepository.setSite(diveId, site.id);
  return AppliedMatch(
      siteId: site.id, siteName: site.name, isNewlyCreated: false);
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/dive_sites/data/services/site_matching_service_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/features/dive_sites/data/services/site_matching_service.dart test/features/dive_sites/data/services/site_matching_service_test.dart test/features/dive_sites/data/services/site_matching_service_test.mocks.dart
git commit -m "feat(site-matching): add SiteMatchingService run with existing-site auto-link"
```

---

### Task 8: Bundled materialise — dedup + coincidence guard + rollback tracking

**Files:**
- Modify: `lib/features/dive_sites/data/services/site_matching_service.dart`
- Modify: `test/features/dive_sites/data/services/site_matching_service_test.dart`

- [ ] **Step 1: Add failing tests**

Append inside `main()`:

```dart
test('materialises a bundled site once for two dives (batch dedup)', () async {
  when(sites.getAllSites(diverId: anyNamed('diverId')))
      .thenAnswer((_) async => const []);
  when(api.searchNearby(
    latitude: anyNamed('latitude'),
    longitude: anyNamed('longitude'),
    radiusKm: anyNamed('radiusKm'),
  )).thenAnswer((_) async => const DiveSiteSearchResult(sites: [
        ExternalDiveSite(
            externalId: 'osm_1',
            name: 'Wreck',
            latitude: 0,
            longitude: 0,
            source: 'OpenStreetMap'),
      ]));
  when(sites.createSite(any)).thenAnswer((inv) async {
    final s = inv.positionalArguments.first as DiveSite;
    return s.copyWith(id: 'new-site-1');
  });

  final entries = await _service(sites, api, dives).run([
    _diveAt('d1', 0, 0.0002),
    _diveAt('d2', 0, 0.0003),
  ]);

  expect(entries.every((e) => e.status == MatchEntryStatus.autoMatched), true);
  expect(entries.every((e) => e.siteId == 'new-site-1'), true);
  expect(entries.first.isNewlyCreated, true);
  verify(sites.createSite(any)).called(1); // created once, linked twice
  verify(dives.setSite('d1', 'new-site-1')).called(1);
  verify(dives.setSite('d2', 'new-site-1')).called(1);
});

test('coincidence guard links existing site instead of creating bundled', () async {
  // Existing site ~120 m from the dive (outside inner 150? it is inside -> use 200 m)
  // Place existing OUTSIDE inner so precedence does not trigger, but WITHIN
  // 100 m of the bundled point so the guard fires.
  const existing = DiveSite(id: 's-exist', name: 'Known Reef',
      location: GeoPoint(0, 0.0016)); // ~178 m east (outside inner 150)
  when(sites.getAllSites(diverId: anyNamed('diverId')))
      .thenAnswer((_) async => const [existing]);
  when(api.searchNearby(
    latitude: anyNamed('latitude'),
    longitude: anyNamed('longitude'),
    radiusKm: anyNamed('radiusKm'),
  )).thenAnswer((_) async => const DiveSiteSearchResult(sites: [
        ExternalDiveSite(
            externalId: 'osm_2',
            name: 'Reef',
            latitude: 0,
            longitude: 0.00165, // ~5 m from the existing site
            source: 'OpenStreetMap'),
      ]));

  await _service(sites, api, dives).run([_diveAt('d1', 0, 0.0016)]);

  // Bundled was nearest+auto, but it coincides with an existing site -> link it.
  verify(dives.setSite('d1', 's-exist')).called(1);
  verifyNever(sites.createSite(any));
});
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/dive_sites/data/services/site_matching_service_test.dart`
Expected: FAIL — current stub `_applyCandidate` does `ref.existing!` and ignores bundled, throwing on bundled matches.

- [ ] **Step 3: Replace the Task 7 stub `_applyCandidate` with the full version**

```dart
static const double _coincidenceMeters = 100;

Future<AppliedMatch> _applyCandidate(String diveId, _CandidateRef ref) async {
  if (ref.existing != null) {
    final site = ref.existing!;
    await _diveRepository.setSite(diveId, site.id);
    _track(site.id, diveId, created: false);
    return AppliedMatch(
        siteId: site.id, siteName: site.name, isNewlyCreated: false);
  }

  final bundled = ref.bundled!;
  final point = GeoPoint(bundled.latitude!, bundled.longitude!);

  // Batch dedup: already materialised this bundled site in this session?
  final existingNewId = _createdByExternalId[bundled.externalId];
  if (existingNewId != null) {
    await _diveRepository.setSite(diveId, existingNewId);
    _track(existingNewId, diveId, created: true);
    return AppliedMatch(
        siteId: existingNewId, siteName: bundled.name, isNewlyCreated: true);
  }

  // Coincidence guard: an existing user site essentially here?
  for (final s in _userSites) {
    if (distanceMeters(point, s.location!) <= _coincidenceMeters) {
      await _diveRepository.setSite(diveId, s.id);
      _track(s.id, diveId, created: false);
      return AppliedMatch(
          siteId: s.id, siteName: s.name, isNewlyCreated: false);
    }
  }

  // Materialise.
  final created = await _siteRepository
      .createSite(bundled.toDiveSite(diverId: diverId));
  _createdByExternalId[bundled.externalId] = created.id;
  await _diveRepository.setSite(diveId, created.id);
  _track(created.id, diveId, created: true);
  return AppliedMatch(
      siteId: created.id, siteName: created.name, isNewlyCreated: true);
}

void _track(String siteId, String diveId, {required bool created}) {
  if (!created) return;
  (_createdSiteRefs[siteId] ??= <String>{}).add(diveId);
}
```

Add `import 'package:submersion/core/utils/geo_math.dart';` to the service if not already present.

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/dive_sites/data/services/site_matching_service_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_sites/data/services/site_matching_service.dart test/features/dive_sites/data/services/site_matching_service_test.dart
git commit -m "feat(site-matching): materialise bundled sites with dedup and coincidence guard"
```

---

### Task 9: `link`, `unlink`, and orphan rollback

**Files:**
- Modify: `lib/features/dive_sites/data/services/site_matching_service.dart`
- Modify: `test/features/dive_sites/data/services/site_matching_service_test.dart`

- [ ] **Step 1: Add failing tests**

```dart
test('unlink clears the site and deletes an orphaned created bundled site', () async {
  when(sites.getAllSites(diverId: anyNamed('diverId')))
      .thenAnswer((_) async => const []);
  when(api.searchNearby(
    latitude: anyNamed('latitude'),
    longitude: anyNamed('longitude'),
    radiusKm: anyNamed('radiusKm'),
  )).thenAnswer((_) async => const DiveSiteSearchResult(sites: [
        ExternalDiveSite(
            externalId: 'osm_1', name: 'Wreck',
            latitude: 0, longitude: 0, source: 'OpenStreetMap'),
      ]));
  when(sites.createSite(any)).thenAnswer((inv) async =>
      (inv.positionalArguments.first as DiveSite).copyWith(id: 'new-1'));
  when(sites.deleteSite(any)).thenAnswer((_) async {});

  final service = _service(sites, api, dives);
  await service.run([_diveAt('d1', 0, 0.0002)]);

  await service.unlink('d1');

  verify(dives.setSite('d1', null)).called(1);
  verify(sites.deleteSite('new-1')).called(1); // orphaned -> removed
});

test('link applies a user-chosen candidate to a needsReview dive', () async {
  const a = DiveSite(id: 's-a', name: 'A', location: GeoPoint(0, 0.0030));
  const b = DiveSite(id: 's-b', name: 'B', location: GeoPoint(0, 0.0034));
  when(sites.getAllSites(diverId: anyNamed('diverId')))
      .thenAnswer((_) async => const [a, b]); // both ~330-378 m -> Suggested
  final service = _service(sites, api, dives);
  final entries = await service.run([_diveAt('d1', 0, 0.0030)]);
  expect(entries.single.status, MatchEntryStatus.needsReview);

  await service.link('d1', 's-b');
  verify(dives.setSite('d1', 's-b')).called(1);
});
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/dive_sites/data/services/site_matching_service_test.dart`
Expected: FAIL — `link` / `unlink` undefined.

- [ ] **Step 3: Implement `link` and `unlink`**

```dart
/// Tracks the currently-applied site per dive, so unlink can roll back.
final Map<String, String> _appliedSiteByDive = {};

/// Applies a user-chosen candidate; returns the real applied site (resolving a
/// bundled externalId to its created site id), or null if the candidate is gone.
Future<AppliedMatch?> link(String diveId, String candidateId) async {
  await unlink(diveId); // clear any prior link (and roll back its orphan)
  final ref = _refsByDive[diveId]?[candidateId];
  if (ref == null) return null;
  final applied = await _applyCandidate(diveId, ref);
  _appliedSiteByDive[diveId] = applied.siteId;
  return applied;
}

Future<void> unlink(String diveId) async {
  final prior = _appliedSiteByDive.remove(diveId);
  await _diveRepository.setSite(diveId, null);
  if (prior == null) return;

  final refs = _createdSiteRefs[prior];
  if (refs != null) {
    refs.remove(diveId);
    if (refs.isEmpty) {
      _createdSiteRefs.remove(prior);
      _createdByExternalId.removeWhere((_, id) => id == prior);
      await _siteRepository.deleteSite(prior);
    }
  }
}
```

Also record `_appliedSiteByDive[dive.id] = applied.siteId;` inside `_toEntry`'s `AutoMatch` branch (after `_applyCandidate`), so auto-applied dives are unlinkable. Add that line.

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/dive_sites/data/services/site_matching_service_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_sites/data/services/site_matching_service.dart test/features/dive_sites/data/services/site_matching_service_test.dart
git commit -m "feat(site-matching): add link/unlink with orphan rollback"
```

> **Phase C checkpoint:** the full matching engine works and is tested against mocked repositories.

---

## Phase D — Review screen + notifier

### Task 10: `SiteMatchReviewNotifier` + state + provider

**Files:**
- Create: `lib/features/dive_sites/presentation/providers/site_match_review_notifier.dart`

The notifier owns one `SiteMatchingService` per session, holds the list of `DiveMatchEntry`, and exposes `link` / `unlink` / `assignManual` that update both the service and the displayed entries.

- [ ] **Step 1: Implement state + notifier + provider**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/services/dive_site_api_service.dart';
import 'package:submersion/features/dive_sites/data/services/site_matching_service.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

class SiteMatchReviewState {
  final bool isLoading;
  final List<DiveMatchEntry> entries;
  final String? errorMessage;

  const SiteMatchReviewState({
    this.isLoading = true,
    this.entries = const [],
    this.errorMessage,
  });

  SiteMatchReviewState copyWith({
    bool? isLoading,
    List<DiveMatchEntry>? entries,
    String? errorMessage,
  }) =>
      SiteMatchReviewState(
        isLoading: isLoading ?? this.isLoading,
        entries: entries ?? this.entries,
        errorMessage: errorMessage,
      );

  int get matchedCount =>
      entries.where((e) => e.status == MatchEntryStatus.autoMatched).length;
  int get reviewCount =>
      entries.where((e) => e.status == MatchEntryStatus.needsReview).length;
  int get noMatchCount =>
      entries.where((e) => e.status == MatchEntryStatus.noMatch).length;
}

class SiteMatchReviewNotifier extends StateNotifier<SiteMatchReviewState> {
  SiteMatchReviewNotifier(this._ref, this._diveIds, {bool autoInit = true})
      : super(const SiteMatchReviewState()) {
    if (autoInit) _init(); // tests pass autoInit:false and seed state directly
  }

  final Ref _ref;
  final List<String>? _diveIds; // null = backlog (all eligible)
  SiteMatchingService? _service;

  Future<void> _init() async {
    try {
      final diverId =
          await _ref.read(validatedCurrentDiverIdProvider.future);
      final diveRepo = _ref.read(diveRepositoryProvider);
      final sensitivity = _ref.read(settingsProvider).siteMatchSensitivity;

      final dives = await diveRepo.getDivesNeedingSiteMatch(
        diverId: diverId,
        limitToIds: _diveIds,
      );

      _service = SiteMatchingService(
        siteRepository: _ref.read(siteRepositoryProvider),
        apiService: _ref.read(diveSiteApiServiceProvider),
        diveRepository: diveRepo,
        diverId: diverId,
        thresholds: sensitivity.thresholds,
      );

      final entries = await _service!.run(dives);
      if (!mounted) return;
      state = state.copyWith(isLoading: false, entries: entries);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
          isLoading: false, errorMessage: 'Matching failed: $e');
    }
  }

  Future<void> link(String diveId, String candidateId) async {
    final applied = await _service?.link(diveId, candidateId);
    if (applied == null) return;
    _replace(diveId, (e) {
      final chosen = e.candidates.firstWhere((c) => c.id == candidateId);
      return e.copyWith(
        status: MatchEntryStatus.autoMatched,
        siteId: applied.siteId, // real created/linked id, not the bundled externalId
        siteName: applied.siteName,
        distanceMeters: chosen.distanceMeters,
        isNewlyCreated: applied.isNewlyCreated,
        candidates: const [],
      );
    });
  }

  Future<void> unlink(String diveId) async {
    await _service?.unlink(diveId);
    _replace(diveId, (e) => e.copyWith(
        status: MatchEntryStatus.noMatch, clearSite: true));
  }

  void _replace(String diveId, DiveMatchEntry Function(DiveMatchEntry) f) {
    state = state.copyWith(
      entries: [
        for (final e in state.entries)
          if (e.dive.id == diveId) f(e) else e,
      ],
    );
  }
}

final siteMatchReviewProvider = StateNotifierProvider.autoDispose
    .family<SiteMatchReviewNotifier, SiteMatchReviewState, List<String>?>(
  (ref, diveIds) => SiteMatchReviewNotifier(ref, diveIds),
);
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/features/dive_sites/presentation/providers/site_match_review_notifier.dart`
Expected: "No issues found!" (after Phase F adds `settingsProvider...siteMatchSensitivity`, this fully resolves; if running before Phase F, temporarily map `sensitivity` to `SiteMatchSensitivity.balanced` and revisit in Task 17 — see note).

> **Ordering note:** `state.siteMatchSensitivity` (Task 16) does not exist yet at this point. To keep Phase D self-contained, hardcode `final sensitivity = SiteMatchSensitivity.balanced;` here (add `import '.../site_match_sensitivity.dart';`), and Task 17 replaces it with `_ref.read(settingsProvider).siteMatchSensitivity`. This keeps every phase compiling.

- [ ] **Step 3: Commit**

```bash
git add lib/features/dive_sites/presentation/providers/site_match_review_notifier.dart
git commit -m "feat(site-matching): add SiteMatchReviewNotifier"
```

---

### Task 11: `SiteMatchReviewPage`

**Files:**
- Create: `lib/features/dive_sites/presentation/pages/site_match_review_page.dart`
- Test: `test/features/dive_sites/presentation/pages/site_match_review_page_test.dart`

- [ ] **Step 1: Implement the page**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/features/dive_sites/data/services/site_matching_service.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_match_review_notifier.dart';

class SiteMatchReviewPage extends ConsumerWidget {
  const SiteMatchReviewPage({super.key, this.diveIds});

  /// Null = backlog (all eligible dives). Non-null = the given dive ids.
  final List<String>? diveIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(siteMatchReviewProvider(diveIds));
    final notifier = ref.read(siteMatchReviewProvider(diveIds).notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Match Sites'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
      body: Builder(
        builder: (_) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.errorMessage != null) {
            return Center(child: Text(state.errorMessage!));
          }
          if (state.entries.isEmpty) {
            return const Center(child: Text('Nothing to match.'));
          }
          return ListView(
            children: [
              _Summary(
                matched: state.matchedCount,
                review: state.reviewCount,
                noMatch: state.noMatchCount,
              ),
              for (final e in state.entries)
                _EntryTile(
                  entry: e,
                  onUnlink: () => notifier.unlink(e.dive.id),
                  onPick: (cid) => notifier.link(e.dive.id, cid),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary(
      {required this.matched, required this.review, required this.noMatch});
  final int matched;
  final int review;
  final int noMatch;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('$matched matched · $review to review · $noMatch no match',
            style: Theme.of(context).textTheme.titleMedium),
      );
}

class _EntryTile extends StatelessWidget {
  const _EntryTile(
      {required this.entry, required this.onUnlink, required this.onPick});
  final DiveMatchEntry entry;
  final VoidCallback onUnlink;
  final void Function(String candidateId) onPick;

  @override
  Widget build(BuildContext context) {
    final title = 'Dive #${entry.dive.diveNumber}';
    switch (entry.status) {
      case MatchEntryStatus.autoMatched:
        return ListTile(
          leading: const Icon(Icons.check_circle, color: Colors.green),
          title: Text(title),
          subtitle: Text(
              '${entry.siteName} · ${entry.distanceMeters?.round()} m'
              '${entry.isNewlyCreated ? ' · newly added' : ''}'),
          trailing: TextButton(onPressed: onUnlink, child: const Text('Unlink')),
        );
      case MatchEntryStatus.needsReview:
        return ExpansionTile(
          leading: const Icon(Icons.help_outline),
          title: Text(title),
          subtitle: Text('${entry.candidates.length} nearby sites'),
          children: [
            for (final c in entry.candidates)
              ListTile(
                title: Text(c.name),
                subtitle: Text(
                    '${c.distanceMeters.round()} m · '
                    '${c.isExisting ? 'your site' : 'import'}'),
                onTap: () => onPick(c.id),
              ),
          ],
        );
      case MatchEntryStatus.noMatch:
        return ListTile(
          leading: const Icon(Icons.location_off_outlined),
          title: Text(title),
          subtitle: const Text('No nearby site'),
        );
    }
  }
}
```

> The `Done` button uses `Navigator.pop`. "Search manually" / "Assign manually" reuse the existing site picker — wire them after confirming the existing picker's entry widget; for the first cut they are omitted (skipping leaves the dive unsited, which is the intended fallback). Localise the literal strings in Task 14's l10n step if you prefer; they are intentionally plain here to keep the page self-contained.

- [ ] **Step 2: Write the smoke test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/data/services/site_matching_service.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_match_review_page.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_match_review_notifier.dart';

void main() {
  testWidgets('renders summary and an auto-matched row', (tester) async {
    final dive = Dive(
      id: 'd1',
      diveNumber: 7,
      diveDateTime: DateTime(2026, 1, 1),
      maxDepth: 18,
      duration: const Duration(minutes: 40),
    );
    final seeded = SiteMatchReviewState(
      isLoading: false,
      entries: [
        DiveMatchEntry(
          dive: dive,
          status: MatchEntryStatus.autoMatched,
          siteId: 's1',
          siteName: 'Blue Hole',
          distanceMeters: 42,
        ),
      ],
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        // autoInit:false skips the async _init(), so we can seed state directly
        // and the real Ref is never touched.
        siteMatchReviewProvider(null).overrideWith(
          (ref) => SiteMatchReviewNotifier(ref, null, autoInit: false)
            ..state = seeded,
        ),
      ],
      child: const MaterialApp(home: SiteMatchReviewPage()),
    ));
    await tester.pump();

    expect(find.textContaining('1 matched'), findsOneWidget);
    expect(find.text('Blue Hole · 42 m'), findsOneWidget);
    expect(find.text('Unlink'), findsOneWidget);
  });
}
```

> This relies on the `autoInit` constructor flag added in Task 10. The override returns the real `SiteMatchReviewNotifier` with init suppressed, then seeds `state` — no fake `Ref` needed. Assertion targets (summary text, row subtitle, Unlink button) match the `SiteMatchReviewPage` widget tree from Step 1.

- [ ] **Step 3: Run the smoke test**

Run: `flutter test test/features/dive_sites/presentation/pages/site_match_review_page_test.dart`
Expected: PASS (1 test). Fix the override pattern per the note if the stub fails to construct.

- [ ] **Step 4: Commit**

```bash
git add lib/features/dive_sites/presentation/pages/site_match_review_page.dart test/features/dive_sites/presentation/pages/site_match_review_page_test.dart
git commit -m "feat(site-matching): add SiteMatchReviewPage"
```

> **Phase D checkpoint:** the review screen renders matching results and supports unlink/pick.

---

## Phase E — Entry points

### Task 12: Route registration

**Files:**
- Modify: `lib/core/router/app_router.dart`

- [ ] **Step 1: Add the route**

Inside the `/dives` route subtree (mirroring the existing `':diveId'` / nested `GoRoute` pattern), add a sibling route before the `:diveId` param route (so `match-sites` is not captured as a dive id):

```dart
GoRoute(
  path: 'match-sites',
  name: 'siteMatchReview',
  builder: (context, state) {
    final ids = (state.extra as List<dynamic>?)?.cast<String>();
    return SiteMatchReviewPage(diveIds: ids);
  },
),
```

Add the import:

```dart
import 'package:submersion/features/dive_sites/presentation/pages/site_match_review_page.dart';
```

> Confirm where the `/dives` children are declared and that adding `match-sites` before the `:diveId` capture avoids route shadowing. If routes are flat (`/dives/:diveId` rather than nested children), register `path: '/dives/match-sites'` at the same level and ensure it is matched ahead of `/dives/:diveId`.

- [ ] **Step 2: Verify**

Run: `flutter analyze lib/core/router/app_router.dart`
Expected: "No issues found!"

- [ ] **Step 3: Commit**

```bash
git add lib/core/router/app_router.dart
git commit -m "feat(site-matching): register /dives/match-sites route"
```

---

### Task 13: Dives-list overflow menu entry

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_list_page.dart`

- [ ] **Step 1: Add the menu item + handler**

In the app-bar `PopupMenuButton<String>`'s `onSelected`, add:

```dart
} else if (value == 'match_sites') {
  context.push('/dives/match-sites');
}
```

In `itemBuilder`, add a `PopupMenuItem` after the "numbering" item:

```dart
PopupMenuItem(
  value: 'match_sites',
  child: Row(
    children: [
      const Icon(Icons.add_location_alt_outlined, size: 20),
      const SizedBox(width: 12),
      Text(context.l10n.diveLog_listPage_menuMatchSites),
    ],
  ),
),
```

(The l10n key `diveLog_listPage_menuMatchSites` is added in Task 14.)

- [ ] **Step 2: Verify (after Task 14 adds the key)**

Run: `flutter analyze lib/features/dive_log/presentation/pages/dive_list_page.dart`
Expected: "No issues found!" once the l10n key exists. If doing this before Task 14, temporarily use a string literal `'Match Dives to Sites'` and swap to the l10n key in Task 14.

- [ ] **Step 3: Commit**

```bash
git add lib/features/dive_log/presentation/pages/dive_list_page.dart
git commit -m "feat(site-matching): add dives-list overflow action"
```

---

### Task 14: l10n strings + post-download summary button

**Files:**
- Modify: `lib/l10n/arb/app_en.arb`
- Modify: `lib/features/import_wizard/presentation/widgets/import_summary_step.dart`
- Create: provider for eligible imported dives (in `site_match_review_notifier.dart` or a small new file)

- [ ] **Step 1: Add l10n keys**

Add to `lib/l10n/arb/app_en.arb` (place near the other `diveLog_listPage_*` keys):

```json
"diveLog_listPage_menuMatchSites": "Match Dives to Sites",
"importSummary_matchSitesButton": "Match {count} dives to sites",
"@importSummary_matchSitesButton": {
  "placeholders": { "count": { "type": "int" } }
}
```

Run: `flutter gen-l10n`
Expected: regenerates `AppLocalizations`; `context.l10n.diveLog_listPage_menuMatchSites` and `context.l10n.importSummary_matchSitesButton(count)` resolve.

- [ ] **Step 2: Add the eligible-count provider**

```dart
final eligibleImportedDivesProvider =
    FutureProvider.autoDispose.family<List<String>, List<String>>(
  (ref, importedIds) async {
    if (importedIds.isEmpty) return const [];
    final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
    final dives = await ref
        .read(diveRepositoryProvider)
        .getDivesNeedingSiteMatch(diverId: diverId, limitToIds: importedIds);
    return dives.map((d) => d.id).toList();
  },
);
```

- [ ] **Step 3: Show the button on the import summary success view**

In `import_summary_step.dart`'s success view, where `importedDiveIds` is available from `result.importedDiveIds`, add (above/near the existing Done / View Dives actions):

```dart
Consumer(
  builder: (context, ref, _) {
    final eligible =
        ref.watch(eligibleImportedDivesProvider(result.importedDiveIds));
    return eligible.maybeWhen(
      data: (ids) => ids.isEmpty
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(top: 8),
              child: FilledButton.icon(
                icon: const Icon(Icons.add_location_alt_outlined),
                label: Text(
                    context.l10n.importSummary_matchSitesButton(ids.length)),
                onPressed: () =>
                    context.push('/dives/match-sites', extra: ids),
              ),
            ),
      orElse: () => const SizedBox.shrink(),
    );
  },
),
```

Add imports for `Consumer`/`ref` (`package:flutter_riverpod/flutter_riverpod.dart`), `context.push` (`package:go_router/go_router.dart`), the new provider, and `context.l10n`.

> Confirm `UnifiedImportResult` exposes `importedDiveIds` (the earlier research indicates it does). If the field is named differently, adjust. If the summary success view is a private `_SuccessView` without `result` in scope, pass `result.importedDiveIds` into it as a constructor parameter.

- [ ] **Step 4: Verify + commit**

Run: `flutter analyze`
Expected: "No issues found!"
Run: `flutter test test/l10n/localization_test.dart`
Expected: PASS (confirms the new arb keys are consistent).

```bash
git add lib/l10n/arb/ lib/features/import_wizard/presentation/widgets/import_summary_step.dart lib/features/dive_sites/presentation/providers/site_match_review_notifier.dart
git commit -m "feat(site-matching): add post-download match button and l10n strings"
```

> **Phase E checkpoint:** the feature works end-to-end with the Balanced default — reachable post-download and from the dives list.

---

## Phase F — Configurable sensitivity setting

### Task 15: Persist `siteMatchSensitivity` (DB column + migration + repository mapping)

**Files:**
- Modify: `lib/core/database/database.dart`
- Modify: the diver-settings repository that maps the diver-settings row to/from `AppSettings` (find it: search for `mapStyle:` usages writing/reading the diver-settings companion — it is the repository called by `SettingsNotifier._saveSettings` via `updateSettingsForDiver`)

- [ ] **Step 1: Add the column**

In the diver-settings table class in `database.dart`, alongside the existing `mapStyle` column, add:

```dart
TextColumn get siteMatchSensitivity =>
    text().withDefault(const Constant('balanced'))();
```

- [ ] **Step 2: Bump schema version + migration**

In `database.dart`, find `int get schemaVersion => N;` and set it to `N + 1`. In the `onUpgrade`/`MigrationStrategy`, add a branch mirroring the most recent diver-settings column migration (the v75 `diver_settings` change is the template):

```dart
if (from < <N+1>) {
  await m.addColumn(<diverSettingsTable>, <diverSettingsTable>.siteMatchSensitivity);
}
```

Replace `<N+1>` with the new version number and `<diverSettingsTable>` with the actual Drift table getter used elsewhere in this migration file (the same one the `mapStyle` column belongs to).

- [ ] **Step 3: Regenerate Drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: regenerates `database.g.dart` with the new column.

- [ ] **Step 4: Map it in the diver-settings repository**

Where the repository writes the companion (next to `mapStyle: Value(settings.mapStyle.name)`), add:

```dart
siteMatchSensitivity: Value(settings.siteMatchSensitivity.name),
```

Where it reads the row into `AppSettings` (next to `mapStyle: MapStyle.fromName(row.mapStyle)`), add:

```dart
siteMatchSensitivity:
    SiteMatchSensitivity.fromName(row.siteMatchSensitivity),
```

Add `import 'package:submersion/features/dive_sites/domain/matching/site_match_sensitivity.dart';` to that repository.

- [ ] **Step 5: Run the migration tests + commit**

Run: `flutter test test/core/database/`
Expected: PASS (migration tests, including the partial-schema guard, still pass).

```bash
git add lib/core/database/database.dart lib/core/database/database.g.dart <diver-settings-repository path>
git commit -m "feat(site-matching): persist siteMatchSensitivity setting"
```

---

### Task 16: `AppSettings` field + `SettingsNotifier` setter + 4 mocks

**Files:**
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart`
- Modify: `test/helpers/mock_providers.dart`
- Modify: `test/l10n/localization_test.dart`
- Modify: `test/features/statistics/presentation/pages/records_page_test.dart`
- Modify: `test/core/presentation/widgets/dive_comparison_card_test.dart`

- [ ] **Step 1: Add the field to `AppSettings`**

Add the import and field (next to `mapStyle`):

```dart
import 'package:submersion/features/dive_sites/domain/matching/site_match_sensitivity.dart';
// ...
final SiteMatchSensitivity siteMatchSensitivity;
```

Add the constructor default (next to the `mapStyle` default `MapStyle.openStreetMap`):

```dart
this.siteMatchSensitivity = SiteMatchSensitivity.balanced,
```

Add to `copyWith` parameters and body (mirroring `mapStyle`):

```dart
SiteMatchSensitivity? siteMatchSensitivity,
// ...
siteMatchSensitivity: siteMatchSensitivity ?? this.siteMatchSensitivity,
```

- [ ] **Step 2: Add the notifier setter**

Mirror `setMapStyle` exactly:

```dart
Future<void> setSiteMatchSensitivity(SiteMatchSensitivity value) async {
  state = state.copyWith(siteMatchSensitivity: value);
  await _saveSettings();
}
```

- [ ] **Step 3: Add the override to ALL FOUR mocks**

Each mock `implements SettingsNotifier`, so the new abstract method must be overridden or `flutter analyze` fails. Add to each (mirroring how each currently overrides `setMapStyle`):

In `test/helpers/mock_providers.dart` (the verbose `MockSettingsNotifier`):
```dart
@override
Future<void> setSiteMatchSensitivity(SiteMatchSensitivity value) async =>
    state = state.copyWith(siteMatchSensitivity: value);
```

In `test/l10n/localization_test.dart` (`_TestSettingsNotifier`) and `test/core/presentation/widgets/dive_comparison_card_test.dart` (`_TestSettingsNotifier`): these rely on `noSuchMethod` for most methods — add the same explicit override only if `flutter analyze` reports it missing. (If they explicitly override `setMapStyle`, add `setSiteMatchSensitivity` the same way; otherwise `noSuchMethod` covers it.)

In `test/features/statistics/presentation/pages/records_page_test.dart` (`_MockSettingsNotifier`):
```dart
@override
Future<void> setSiteMatchSensitivity(SiteMatchSensitivity value) async =>
    state = state.copyWith(siteMatchSensitivity: value);
```

Add `import 'package:submersion/features/dive_sites/domain/matching/site_match_sensitivity.dart';` to each test file that references the type.

- [ ] **Step 4: Verify all four compile**

Run: `flutter analyze`
Expected: "No issues found!" (this is the ONLY check that catches a missed mock — do not skip it).

- [ ] **Step 5: Commit**

```bash
git add lib/features/settings/presentation/providers/settings_providers.dart test/helpers/mock_providers.dart test/l10n/localization_test.dart test/features/statistics/presentation/pages/records_page_test.dart test/core/presentation/widgets/dive_comparison_card_test.dart
git commit -m "feat(site-matching): add siteMatchSensitivity to AppSettings + notifier"
```

---

### Task 17: Settings UI picker + wire the notifier to read the setting

**Files:**
- Modify: a settings section page (e.g. `lib/features/settings/presentation/pages/section_appearance_page.dart`, or the most relevant section — confirm placement)
- Modify: `lib/features/dive_sites/presentation/providers/site_match_review_notifier.dart`
- Modify: `lib/l10n/arb/app_en.arb`

- [ ] **Step 1: Add l10n keys for the picker**

```json
"settings_siteMatch_title": "Auto site matching",
"settings_siteMatch_subtitle": "How aggressively downloaded dives are matched to sites",
"settings_siteMatch_strict": "Strict",
"settings_siteMatch_balanced": "Balanced",
"settings_siteMatch_relaxed": "Relaxed"
```

Run: `flutter gen-l10n`

- [ ] **Step 2: Add the picker widget**

In the chosen settings section's build, add (mirroring how `mapStyle` or other enum settings are surfaced — a `ListTile` with a trailing `DropdownButton`, or a `RadioListTile` group):

```dart
ListTile(
  leading: const Icon(Icons.add_location_alt_outlined),
  title: Text(context.l10n.settings_siteMatch_title),
  subtitle: Text(context.l10n.settings_siteMatch_subtitle),
  trailing: DropdownButton<SiteMatchSensitivity>(
    value: settings.siteMatchSensitivity,
    onChanged: (value) {
      if (value != null) {
        ref.read(settingsProvider.notifier).setSiteMatchSensitivity(value);
      }
    },
    items: [
      DropdownMenuItem(
        value: SiteMatchSensitivity.strict,
        child: Text(context.l10n.settings_siteMatch_strict),
      ),
      DropdownMenuItem(
        value: SiteMatchSensitivity.balanced,
        child: Text(context.l10n.settings_siteMatch_balanced),
      ),
      DropdownMenuItem(
        value: SiteMatchSensitivity.relaxed,
        child: Text(context.l10n.settings_siteMatch_relaxed),
      ),
    ],
  ),
),
```

Add `import 'package:submersion/features/dive_sites/domain/matching/site_match_sensitivity.dart';` to the settings page.

- [ ] **Step 3: Wire the notifier to read the real setting**

In `site_match_review_notifier.dart`, replace the Task 10 hardcoded line:

```dart
final sensitivity = SiteMatchSensitivity.balanced;
```

with:

```dart
final sensitivity = _ref.read(settingsProvider).siteMatchSensitivity;
```

- [ ] **Step 4: Verify + commit**

Run: `flutter analyze`
Expected: "No issues found!"
Run: `flutter test test/l10n/localization_test.dart`
Expected: PASS.

```bash
git add lib/features/settings/ lib/features/dive_sites/presentation/providers/site_match_review_notifier.dart lib/l10n/arb/
git commit -m "feat(site-matching): add sensitivity setting UI and wire it through"
```

> **Phase F checkpoint:** the sensitivity preset is user-configurable and drives matching.

---

## Final verification

- [ ] **Run the full suite for touched areas**

Run:
```bash
flutter test test/features/dive_sites/ test/features/dive_log/data/repositories/dive_repository_site_match_test.dart test/l10n/localization_test.dart test/core/database/
```
Expected: all PASS.

- [ ] **Analyze + format**

Run: `flutter analyze` → "No issues found!"
Run: `dart format lib/ test/` → confirm no diffs to commit, or commit formatting.

- [ ] **Guardrail check (reparse never clobbers siteId)**

Confirm `reparse_service.dart`'s `_updateDiveRow` still omits `siteId` from its `DivesCompanion` write (it does today). No code change needed; this is a verification step. Optionally add a regression test asserting a reparse leaves an assigned `siteId` intact.

---

## Notes for the implementer

- **Confirm `Dive` constructor params** before writing test fixtures (`_diveAt`): the entity has many optional fields; provide only the required ones plus `entryLocation`/`exitLocation`.
- **Mockito**: after adding/altering `@GenerateMocks`, run `dart run build_runner build --delete-conflicting-outputs` before running the affected test.
- **Phase ordering matters for compilation**: Task 10 deliberately hardcodes `SiteMatchSensitivity.balanced` so Phases A-E compile without the Phase F setting; Task 17 swaps it for the real read.
- **l10n**: every user-visible string in the review page (`'Match Sites'`, `'Done'`, `'Nothing to match.'`, etc.) should ultimately move to `app_en.arb`. Task 11 ships plain literals to stay self-contained; fold them into l10n alongside Task 14/17 keys if the project's localization test enforces no hardcoded UI strings.
