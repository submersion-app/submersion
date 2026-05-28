# Site Match Review — Map + Staged Confirm Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor the (unmerged, PR #287) Match-Sites review screen from apply-immediately to a staged compute→confirm flow with an interactive map, richer candidate info, and explicit Confirm/Cancel.

**Architecture:** `SiteMatchingService` splits into `computeProposals` (no DB writes) and `applyConfirmed` (one transaction on Confirm). The notifier holds proposals + per-dive selections + the focused dive. The page shows one map (focused dive + candidate pins, tap to select) above a compact accordion dive list whose focused row expands to rich candidate cards, with a pinned Confirm/Cancel bar. Map tap and card tap drive one selection.

**Tech Stack:** Flutter, Riverpod (`StateNotifier` via `core/providers/provider.dart`), Drift (transactions), `flutter_map` v8 + shared tile providers, mockito, flutter_test.

**Phases (each ends green):**
- **A** — service compute/apply split (Tasks 1-4)
- **B** — notifier (Task 5)
- **C** — map widget (Task 6)
- **D** — l10n + page rewrite (Tasks 7-9)
- **E** — final verification (Task 10)

This supersedes the apply-immediately model: `run`/`link`/`unlink` and the rollback bookkeeping are removed. Entry points (dives-list menu, post-download button), the `siteMatchSensitivity` setting + v76 migration, and `DiveRepository.setSite`/`getDivesNeedingSiteMatch` are unchanged.

---

## File Structure

**Modified:**

| Path | Responsibility after change |
|---|---|
| `lib/features/dive_sites/data/services/site_matching_service.dart` | Data model (`ProposalStatus`, enriched `MatchCandidateView`, `MatchProposal`, `ConfirmedMatch`, `ApplyResult`); `computeProposals` (no writes) + `applyConfirmed` (transaction). No `run`/`link`/`unlink`/rollback. |
| `lib/features/dive_sites/presentation/providers/site_match_review_notifier.dart` | Staged state (proposals/focus/selections/isApplying) + actions (focusDive/select/confirm). |
| `lib/features/dive_sites/presentation/pages/site_match_review_page.dart` | Map + accordion + rich cards + Confirm/Cancel bar; responsive. |
| `lib/l10n/arb/app_en.arb` | New keys; retire unlink/newlyAdded/nearbySites. |
| `test/features/dive_sites/data/services/site_matching_service_test.dart` | Rewrite for compute/apply. |
| `test/features/dive_sites/presentation/providers/site_match_review_notifier_test.dart` | Rewrite for select/confirm. |
| `test/features/dive_sites/presentation/pages/site_match_review_page_test.dart` | Rewrite for new UI. |

**New:**

| Path | Responsibility |
|---|---|
| `lib/features/dive_sites/presentation/widgets/match_sites_map.dart` | Focused dive + candidate-pin map with tap-to-select. |
| `test/features/dive_sites/presentation/widgets/match_sites_map_test.dart` | Map widget smoke test. |

---

## Phase A — Service: compute / apply split

### Task 1: Data-model types (proposal + enriched candidate)

**Files:**
- Modify: `lib/features/dive_sites/data/services/site_matching_service.dart`

- [ ] **Step 1: Replace the top-of-file type declarations**

Replace the existing `MatchEntryStatus`, `MatchCandidateView`, `AppliedMatch`, and `DiveMatchEntry` declarations (lines 12-86) with:

```dart
enum ProposalStatus { clear, review, none }

/// A display candidate for the review screen + map (resolved from a user site
/// or a bundled site; fields are null when the source lacks them).
class MatchCandidateView {
  final String id; // existing site id or bundled externalId
  final String name;
  final bool isExisting;
  final double distanceMeters;
  final GeoPoint location;
  final double? minDepth;
  final double? maxDepth;
  final String? country;
  final String? region;
  final double? rating;
  final String? difficulty; // SiteDifficulty.displayName
  final List<String> features; // bundled: wreck/reef/shore...
  final String? description;

  const MatchCandidateView({
    required this.id,
    required this.name,
    required this.isExisting,
    required this.distanceMeters,
    required this.location,
    this.minDepth,
    this.maxDepth,
    this.country,
    this.region,
    this.rating,
    this.difficulty,
    this.features = const [],
    this.description,
  });
}

/// One dive's matching proposal (no write state — selection lives in the notifier).
class MatchProposal {
  final Dive dive;
  final ProposalStatus status;
  final List<MatchCandidateView> candidates; // distance-sorted
  final String? recommendedCandidateId; // matcher's pick (clear only)

  const MatchProposal({
    required this.dive,
    required this.status,
    this.candidates = const [],
    this.recommendedCandidateId,
  });
}

/// A user-confirmed (diveId -> chosen candidate) pair to apply.
class ConfirmedMatch {
  final String diveId;
  final String candidateId; // existing site id or bundled externalId
  const ConfirmedMatch(this.diveId, this.candidateId);
}

/// Outcome counts from applyConfirmed, for the result message.
class ApplyResult {
  final int divesLinked;
  final int sitesCreated;
  const ApplyResult({required this.divesLinked, required this.sitesCreated});
}

/// Runs a body inside a DB transaction. Injectable so unit tests can pass a
/// pass-through that doesn't require a real database.
typedef TransactionRunner = Future<void> Function(Future<void> Function() body);
```

Add the import for the database singleton near the top (used by the default transaction runner):

```dart
import 'package:submersion/core/services/database_service.dart';
```

- [ ] **Step 2: Verify it analyzes (will show errors until Task 2 rewrites the service body — that's expected)**

Run: `flutter analyze lib/features/dive_sites/data/services/site_matching_service.dart`
Expected: errors referencing `run`/`_toEntry`/`DiveMatchEntry` (removed in Task 2). Proceed.

---

### Task 2: `computeProposals` (no DB writes)

**Files:**
- Modify: `lib/features/dive_sites/data/services/site_matching_service.dart`

- [ ] **Step 1: Replace the `SiteMatchingService` class body (constructor through `_nameOf`)**

Replace the class (lines ~98-219, the constructor + fields + `run` + `_toEntry` + `_nameOf`) — but KEEP `_CandidateRef` (lines 89-94) and the `_coincidenceMeters` constant. New class shell + compute:

```dart
class SiteMatchingService {
  SiteMatchingService({
    required SiteRepository siteRepository,
    required DiveSiteApiService apiService,
    required DiveRepository diveRepository,
    required this.diverId,
    required this.thresholds,
    TransactionRunner? runInTransaction,
  }) : _siteRepository = siteRepository,
       _apiService = apiService,
       _diveRepository = diveRepository,
       _runInTransaction =
           runInTransaction ??
           ((body) => DatabaseService.instance.database.transaction(body));

  final SiteRepository _siteRepository;
  final DiveSiteApiService _apiService;
  final DiveRepository _diveRepository;
  final String? diverId;
  final MatchThresholds thresholds;
  final TransactionRunner _runInTransaction;

  static const double _coincidenceMeters = 100;

  // Per-session state (no rollback bookkeeping — nothing is written until apply).
  List<DiveSite> _userSites = const [];
  final Map<String, Map<String, _CandidateRef>> _refsByDive = {};
  // Reset at the start of each applyConfirmed pass (batch dedup).
  final Map<String, String> _createdByExternalId = {};

  GeoPoint? _pointFor(Dive dive) => dive.entryLocation ?? dive.exitLocation;

  /// Computes proposals for [dives]. Performs NO database writes.
  Future<List<MatchProposal>> computeProposals(List<Dive> dives) async {
    _userSites = (await _siteRepository.getAllSites(diverId: diverId))
        .where((s) => s.location != null)
        .toList();

    final proposals = <MatchProposal>[];
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
        candidates.add(
          MatchCandidate(id: s.id, location: s.location!, isExisting: true),
        );
      }
      for (final b in bundled.sites) {
        if (!b.hasCoordinates) continue;
        refs[b.externalId] = _CandidateRef.bundled(b);
        candidates.add(
          MatchCandidate(
            id: b.externalId,
            location: GeoPoint(b.latitude!, b.longitude!),
            isExisting: false,
          ),
        );
      }
      _refsByDive[dive.id] = refs;

      final views =
          candidates
              .map((c) => _viewFor(c, refs[c.id]!, distanceMeters(point, c.location)))
              .where((v) => v.distanceMeters <= thresholds.outerRadiusMeters)
              .toList()
            ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));

      final outcome = matchDive(
        point: point,
        candidates: candidates,
        thresholds: thresholds,
      );

      proposals.add(switch (outcome) {
        NoMatch() => MatchProposal(dive: dive, status: ProposalStatus.none),
        Suggested() => MatchProposal(
          dive: dive,
          status: ProposalStatus.review,
          candidates: views,
        ),
        AutoMatch(:final siteId) => MatchProposal(
          dive: dive,
          status: ProposalStatus.clear,
          candidates: views,
          recommendedCandidateId: siteId,
        ),
      });
    }
    return proposals;
  }

  MatchCandidateView _viewFor(
    MatchCandidate c,
    _CandidateRef ref,
    double distance,
  ) {
    if (ref.existing != null) {
      final s = ref.existing!;
      return MatchCandidateView(
        id: s.id,
        name: s.name,
        isExisting: true,
        distanceMeters: distance,
        location: s.location!,
        minDepth: s.minDepth,
        maxDepth: s.maxDepth,
        country: s.country,
        region: s.region,
        rating: s.rating,
        difficulty: s.difficulty?.displayName,
        description: s.description.isEmpty ? null : s.description,
      );
    }
    final b = ref.bundled!;
    return MatchCandidateView(
      id: b.externalId,
      name: b.name,
      isExisting: false,
      distanceMeters: distance,
      location: GeoPoint(b.latitude!, b.longitude!),
      maxDepth: b.maxDepth,
      country: b.country,
      region: b.region ?? b.ocean,
      features: b.features,
      description: (b.description == null || b.description!.isEmpty)
          ? null
          : b.description,
    );
  }

  // applyConfirmed + _applyOne added in Task 3.
}
```

> Confirm `SiteDifficulty` has a `displayName` getter (it does — `dive_site.dart`) and `ExternalDiveSite` exposes `maxDepth`/`country`/`region`/`ocean`/`features`/`description` (it does). No new imports beyond Task 1's `database_service.dart`.

- [ ] **Step 2: Rewrite the service test for `computeProposals`**

Replace `test/features/dive_sites/data/services/site_matching_service_test.dart` with (mocks unchanged — regenerate not needed; `@GenerateMocks` already covers the three repos):

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

import 'site_matching_service_test.mocks.dart';

GeoPoint _eastMeters(double m) => GeoPoint(0, m / 111320.0);

Dive _diveAt(String id, GeoPoint where) => Dive(
  id: id,
  diveNumber: 1,
  dateTime: DateTime(2026, 1, 1),
  maxDepth: 18,
  entryLocation: where,
);

@GenerateMocks([SiteRepository, DiveSiteApiService, DiveRepository])
void main() {
  late MockSiteRepository sites;
  late MockDiveSiteApiService api;
  late MockDiveRepository dives;

  // Pass-through transaction runner so apply runs without a real database.
  SiteMatchingService service() => SiteMatchingService(
    siteRepository: sites,
    apiService: api,
    diveRepository: dives,
    diverId: 'diver-1',
    thresholds: SiteMatchSensitivity.balanced.thresholds,
    runInTransaction: (body) => body(),
  );

  setUp(() {
    sites = MockSiteRepository();
    api = MockDiveSiteApiService();
    dives = MockDiveRepository();
    when(
      api.searchNearby(
        latitude: anyNamed('latitude'),
        longitude: anyNamed('longitude'),
        radiusKm: anyNamed('radiusKm'),
      ),
    ).thenAnswer((_) async => const DiveSiteSearchResult(sites: []));
    when(
      sites.getAllSites(diverId: anyNamed('diverId')),
    ).thenAnswer((_) async => const []);
    when(dives.setSite(any, any)).thenAnswer((_) async {});
  });

  group('computeProposals', () {
    test('clear match: existing site within inner radius, no writes', () async {
      const existing = DiveSite(
        id: 's1',
        name: 'Blue Hole',
        location: GeoPoint(0, 0),
        maxDepth: 40,
        country: 'Egypt',
      );
      when(
        sites.getAllSites(diverId: anyNamed('diverId')),
      ).thenAnswer((_) async => const [existing]);

      final proposals = await service().computeProposals([
        _diveAt('d1', _eastMeters(33)),
      ]);

      expect(proposals.single.status, ProposalStatus.clear);
      expect(proposals.single.recommendedCandidateId, 's1');
      final view = proposals.single.candidates.single;
      expect(view.name, 'Blue Hole');
      expect(view.maxDepth, 40);
      expect(view.location, const GeoPoint(0, 0));
      // No writes during compute.
      verifyNever(dives.setSite(any, any));
      verifyNever(sites.createSite(any));
    });

    test('no candidates -> none', () async {
      final proposals = await service().computeProposals([
        _diveAt('d1', const GeoPoint(10, 10)),
      ]);
      expect(proposals.single.status, ProposalStatus.none);
      expect(proposals.single.candidates, isEmpty);
    });

    test('two close sites -> review with both candidates, no recommendation', () async {
      when(sites.getAllSites(diverId: anyNamed('diverId'))).thenAnswer(
        (_) async => const [
          DiveSite(id: 'a', name: 'A', location: GeoPoint(0, 0.0003)),
          DiveSite(id: 'b', name: 'B', location: GeoPoint(0, 0.0006)),
        ],
      );
      final proposals = await service().computeProposals([
        _diveAt('d1', const GeoPoint(0, 0)),
      ]);
      expect(proposals.single.status, ProposalStatus.review);
      expect(proposals.single.recommendedCandidateId, isNull);
      expect(proposals.single.candidates.length, 2);
    });
  });
}
```

- [ ] **Step 3: Generate mocks + run (compute tests only; apply tests come in Task 3)**

Run: `dart run build_runner build --delete-conflicting-outputs`
Run: `flutter test test/features/dive_sites/data/services/site_matching_service_test.dart`
Expected: PASS (3 compute tests). `computeProposals` performs no writes.

> Do not commit yet — `applyConfirmed` (Task 3) completes the service.

---

### Task 3: `applyConfirmed` (transaction + dedup + coincidence guard)

**Files:**
- Modify: `lib/features/dive_sites/data/services/site_matching_service.dart`
- Modify: `test/features/dive_sites/data/services/site_matching_service_test.dart`

- [ ] **Step 1: Add `applyConfirmed` + `_applyOne` (replace the `// applyConfirmed ...` comment)**

```dart
/// Applies confirmed selections in a single transaction. Returns counts.
Future<ApplyResult> applyConfirmed(List<ConfirmedMatch> confirmed) async {
  _createdByExternalId.clear();
  var linked = 0;
  var created = 0;
  await _runInTransaction(() async {
    for (final c in confirmed) {
      final ref = _refsByDive[c.diveId]?[c.candidateId];
      if (ref == null) continue;
      final didCreate = await _applyOne(c.diveId, ref);
      linked++;
      if (didCreate) created++;
    }
  });
  return ApplyResult(divesLinked: linked, sitesCreated: created);
}

/// Links one dive to its chosen candidate. Returns true if a new bundled site
/// row was created. Mirrors the original apply logic (dedup + coincidence guard)
/// minus the rollback bookkeeping.
Future<bool> _applyOne(String diveId, _CandidateRef ref) async {
  if (ref.existing != null) {
    await _diveRepository.setSite(diveId, ref.existing!.id);
    return false;
  }

  final bundled = ref.bundled!;
  final point = GeoPoint(bundled.latitude!, bundled.longitude!);

  // Batch dedup: this bundled site already materialised in this pass?
  final dedupId = _createdByExternalId[bundled.externalId];
  if (dedupId != null) {
    await _diveRepository.setSite(diveId, dedupId);
    return false;
  }

  // Coincidence guard: an existing user site essentially here?
  for (final s in _userSites) {
    if (distanceMeters(point, s.location!) <= _coincidenceMeters) {
      await _diveRepository.setSite(diveId, s.id);
      return false;
    }
  }

  // Materialise the bundled site, then link.
  final createdSite = await _siteRepository.createSite(
    bundled.toDiveSite(diverId: diverId),
  );
  _createdByExternalId[bundled.externalId] = createdSite.id;
  await _diveRepository.setSite(diveId, createdSite.id);
  return true;
}
```

- [ ] **Step 2: Verify service analyzes clean**

Run: `flutter analyze lib/features/dive_sites/data/services/site_matching_service.dart`
Expected: "No issues found!"

- [ ] **Step 3: Add apply tests**

Append inside `main()` of the service test:

```dart
group('applyConfirmed', () {
  setUp(() {
    when(sites.createSite(any)).thenAnswer((inv) async {
      final s = inv.positionalArguments.first as DiveSite;
      return s.copyWith(id: 'new-${s.name}');
    });
  });

  test('links an existing candidate; no site created', () async {
    when(
      sites.getAllSites(diverId: anyNamed('diverId')),
    ).thenAnswer((_) async => const [
      DiveSite(id: 's1', name: 'Blue Hole', location: GeoPoint(0, 0)),
    ]);
    final s = service();
    await s.computeProposals([_diveAt('d1', _eastMeters(33))]);

    final result = await s.applyConfirmed([const ConfirmedMatch('d1', 's1')]);

    expect(result.divesLinked, 1);
    expect(result.sitesCreated, 0);
    verify(dives.setSite('d1', 's1')).called(1);
    verifyNever(sites.createSite(any));
  });

  test('materialises a bundled site once for two dives (batch dedup)', () async {
    when(
      api.searchNearby(
        latitude: anyNamed('latitude'),
        longitude: anyNamed('longitude'),
        radiusKm: anyNamed('radiusKm'),
      ),
    ).thenAnswer(
      (_) async => const DiveSiteSearchResult(
        sites: [
          ExternalDiveSite(
            externalId: 'osm_1',
            name: 'Wreck',
            latitude: 0,
            longitude: 0,
            source: 'OpenStreetMap',
          ),
        ],
      ),
    );
    final s = service();
    await s.computeProposals([
      _diveAt('d1', _eastMeters(22)),
      _diveAt('d2', _eastMeters(33)),
    ]);

    final result = await s.applyConfirmed([
      const ConfirmedMatch('d1', 'osm_1'),
      const ConfirmedMatch('d2', 'osm_1'),
    ]);

    expect(result.divesLinked, 2);
    expect(result.sitesCreated, 1); // created once
    verify(sites.createSite(any)).called(1);
    verify(dives.setSite('d1', 'new-Wreck')).called(1);
    verify(dives.setSite('d2', 'new-Wreck')).called(1);
  });

  test('coincidence guard links existing instead of creating bundled', () async {
    final existing = DiveSite(
      id: 's-exist',
      name: 'Known Reef',
      location: _eastMeters(160),
    );
    when(
      sites.getAllSites(diverId: anyNamed('diverId')),
    ).thenAnswer((_) async => [existing]);
    when(
      api.searchNearby(
        latitude: anyNamed('latitude'),
        longitude: anyNamed('longitude'),
        radiusKm: anyNamed('radiusKm'),
      ),
    ).thenAnswer(
      (_) async => DiveSiteSearchResult(
        sites: [
          ExternalDiveSite(
            externalId: 'osm_2',
            name: 'Reef',
            latitude: 0,
            longitude: _eastMeters(140).longitude,
            source: 'OpenStreetMap',
          ),
        ],
      ),
    );
    final s = service();
    await s.computeProposals([_diveAt('d1', const GeoPoint(0, 0))]);

    final result = await s.applyConfirmed([const ConfirmedMatch('d1', 'osm_2')]);

    expect(result.sitesCreated, 0);
    verify(dives.setSite('d1', 's-exist')).called(1);
    verifyNever(sites.createSite(any));
  });

  test('empty confirmed list writes nothing', () async {
    final s = service();
    await s.computeProposals([_diveAt('d1', _eastMeters(33))]);
    final result = await s.applyConfirmed(const []);
    expect(result.divesLinked, 0);
    verifyNever(dives.setSite(any, any));
  });
});
```

- [ ] **Step 4: Run service tests**

Run: `flutter test test/features/dive_sites/data/services/site_matching_service_test.dart`
Expected: PASS (3 compute + 4 apply).

- [ ] **Step 5: Format + commit**

```bash
dart format lib/features/dive_sites/data/services/site_matching_service.dart test/features/dive_sites/data/services/site_matching_service_test.dart
git add lib/features/dive_sites/data/services/site_matching_service.dart test/features/dive_sites/data/services/site_matching_service_test.dart test/features/dive_sites/data/services/site_matching_service_test.mocks.dart
git commit -m "refactor(site-matching): split service into computeProposals + applyConfirmed"
```

> **Phase A checkpoint:** the engine computes proposals without writes and applies confirmed selections atomically.

---

## Phase B — Notifier

### Task 5: Staged `SiteMatchReviewNotifier`

**Files:**
- Modify: `lib/features/dive_sites/presentation/providers/site_match_review_notifier.dart`
- Modify: `test/features/dive_sites/presentation/providers/site_match_review_notifier_test.dart`

- [ ] **Step 1: Replace `SiteMatchReviewState` + `SiteMatchReviewNotifier`**

Keep the imports and `eligibleImportedDivesProvider` (bottom of file) unchanged. Replace the state class + notifier class + `siteMatchReviewProvider`:

```dart
class SiteMatchReviewState {
  final bool isLoading;
  final String? errorMessage;
  final List<MatchProposal> proposals;
  final String? focusedDiveId;
  final Map<String, String> selections; // diveId -> chosen candidateId
  final bool isApplying;

  const SiteMatchReviewState({
    this.isLoading = true,
    this.errorMessage,
    this.proposals = const [],
    this.focusedDiveId,
    this.selections = const {},
    this.isApplying = false,
  });

  SiteMatchReviewState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<MatchProposal>? proposals,
    String? focusedDiveId,
    Map<String, String>? selections,
    bool? isApplying,
  }) => SiteMatchReviewState(
    isLoading: isLoading ?? this.isLoading,
    errorMessage: errorMessage,
    proposals: proposals ?? this.proposals,
    focusedDiveId: focusedDiveId ?? this.focusedDiveId,
    selections: selections ?? this.selections,
    isApplying: isApplying ?? this.isApplying,
  );

  int get selectedCount => selections.length;
  int get reviewCount => proposals
      .where((p) =>
          p.status == ProposalStatus.review &&
          !selections.containsKey(p.dive.id))
      .length;
  int get noMatchCount =>
      proposals.where((p) => p.status == ProposalStatus.none).length;

  MatchProposal? get focusedProposal {
    for (final p in proposals) {
      if (p.dive.id == focusedDiveId) return p;
    }
    return null;
  }
}

class SiteMatchReviewNotifier extends StateNotifier<SiteMatchReviewState> {
  SiteMatchReviewNotifier(this._ref, this._diveIds, {bool autoInit = true})
    : super(const SiteMatchReviewState()) {
    if (autoInit) _init();
  }

  final Ref _ref;
  final List<String>? _diveIds;
  SiteMatchingService? _service;

  Future<void> _init() async {
    try {
      final diverId = await _ref.read(validatedCurrentDiverIdProvider.future);
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

      final proposals = await _service!.computeProposals(dives);
      if (!mounted) return;

      // Seed selections from clear matches; pick the first review (else first
      // dive) as the focused one.
      final selections = <String, String>{};
      for (final p in proposals) {
        if (p.status == ProposalStatus.clear &&
            p.recommendedCandidateId != null) {
          selections[p.dive.id] = p.recommendedCandidateId!;
        }
      }
      final focus = proposals
          .firstWhere(
            (p) => p.status == ProposalStatus.review,
            orElse: () => proposals.isNotEmpty
                ? proposals.first
                : (throw StateError('no proposals')),
          )
          .dive
          .id;

      state = state.copyWith(
        isLoading: false,
        proposals: proposals,
        selections: selections,
        focusedDiveId: proposals.isEmpty ? null : focus,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Matching failed: $e',
      );
    }
  }

  void focusDive(String diveId) =>
      state = state.copyWith(focusedDiveId: diveId);

  /// Toggles the selected candidate for a dive (tap again to deselect).
  void select(String diveId, String candidateId) {
    final next = Map<String, String>.from(state.selections);
    if (next[diveId] == candidateId) {
      next.remove(diveId);
    } else {
      next[diveId] = candidateId;
    }
    state = state.copyWith(selections: next);
  }

  /// Applies all selections in one transaction. Returns the result, or null on
  /// error (errorMessage set). The page handles pop + snackbar.
  Future<ApplyResult?> confirm() async {
    final service = _service;
    if (service == null) return null;
    state = state.copyWith(isApplying: true);
    try {
      final confirmed = [
        for (final e in state.selections.entries)
          ConfirmedMatch(e.key, e.value),
      ];
      final result = await service.applyConfirmed(confirmed);
      if (mounted) state = state.copyWith(isApplying: false);
      return result;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isApplying: false,
          errorMessage: 'Could not apply matches: $e',
        );
      }
      return null;
    }
  }
}

final siteMatchReviewProvider = StateNotifierProvider.autoDispose
    .family<SiteMatchReviewNotifier, SiteMatchReviewState, List<String>?>(
      (ref, diveIds) => SiteMatchReviewNotifier(ref, diveIds),
    );
```

- [ ] **Step 2: Verify analyze**

Run: `flutter analyze lib/features/dive_sites/presentation/providers/site_match_review_notifier.dart`
Expected: "No issues found!"

- [ ] **Step 3: Rewrite the notifier test**

Replace `test/features/dive_sites/presentation/providers/site_match_review_notifier_test.dart` — keep the existing mock-provider harness and `@GenerateMocks`; change the assertions to the staged API:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/services/dive_site_api_service.dart';
import 'package:submersion/features/dive_sites/data/services/site_matching_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_match_review_notifier.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import 'site_match_review_notifier_test.mocks.dart';

@GenerateMocks([SiteRepository, DiveSiteApiService, DiveRepository])
GeoPoint _eastMeters(double m) => GeoPoint(0, m / 111320.0);

Dive _dive(String id, GeoPoint where) => Dive(
  id: id,
  diveNumber: 1,
  dateTime: DateTime(2026, 1, 1),
  maxDepth: 18,
  entryLocation: where,
);

Future<void> _settle() async {
  for (var i = 0; i < 12; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late MockSiteRepository sites;
  late MockDiveSiteApiService api;
  late MockDiveRepository dives;

  ProviderContainer makeContainer(List<Dive> eligible) {
    sites = MockSiteRepository();
    api = MockDiveSiteApiService();
    dives = MockDiveRepository();
    when(
      dives.getDivesNeedingSiteMatch(
        diverId: anyNamed('diverId'),
        limitToIds: anyNamed('limitToIds'),
      ),
    ).thenAnswer((_) async => eligible);
    when(dives.setSite(any, any)).thenAnswer((_) async {});
    when(
      sites.getAllSites(diverId: anyNamed('diverId')),
    ).thenAnswer((_) async => const []);
    when(
      api.searchNearby(
        latitude: anyNamed('latitude'),
        longitude: anyNamed('longitude'),
        radiusKm: anyNamed('radiusKm'),
      ),
    ).thenAnswer((_) async => const DiveSiteSearchResult(sites: []));

    final container = ProviderContainer(
      overrides: [
        diveRepositoryProvider.overrideWithValue(dives),
        siteRepositoryProvider.overrideWithValue(sites),
        diveSiteApiServiceProvider.overrideWithValue(api),
        validatedCurrentDiverIdProvider.overrideWith((ref) => 'diver-1'),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(
      container.listen(siteMatchReviewProvider(null), (_, _) {}).close,
    );
    return container;
  }

  test('clear match is pre-selected; compute does not write', () async {
    final container = makeContainer([_dive('d1', _eastMeters(33))]);
    when(sites.getAllSites(diverId: anyNamed('diverId'))).thenAnswer(
      (_) async => const [
        DiveSite(id: 's1', name: 'Blue Hole', location: GeoPoint(0, 0)),
      ],
    );

    await _settle();
    final state = container.read(siteMatchReviewProvider(null));

    expect(state.isLoading, false);
    expect(state.selectedCount, 1);
    expect(state.selections['d1'], 's1');
    verifyNever(dives.setSite(any, any)); // nothing written yet
  });

  test('select then confirm writes once and returns counts', () async {
    final container = makeContainer([_dive('d1', const GeoPoint(0, 0))]);
    when(sites.getAllSites(diverId: anyNamed('diverId'))).thenAnswer(
      (_) async => const [
        DiveSite(id: 'a', name: 'A', location: GeoPoint(0, 0.0003)),
        DiveSite(id: 'b', name: 'B', location: GeoPoint(0, 0.0006)),
      ],
    ); // two close -> review, nothing pre-selected

    await _settle();
    expect(container.read(siteMatchReviewProvider(null)).selectedCount, 0);

    final notifier = container.read(siteMatchReviewProvider(null).notifier);
    notifier.select('d1', 'b');
    expect(container.read(siteMatchReviewProvider(null)).selections['d1'], 'b');

    final result = await notifier.confirm();
    expect(result?.divesLinked, 1);
    verify(dives.setSite('d1', 'b')).called(1);
  });

  test('select toggles off when tapping the same candidate', () async {
    final container = makeContainer([_dive('d1', _eastMeters(33))]);
    when(sites.getAllSites(diverId: anyNamed('diverId'))).thenAnswer(
      (_) async => const [
        DiveSite(id: 's1', name: 'Blue Hole', location: GeoPoint(0, 0)),
      ],
    );
    await _settle();
    final notifier = container.read(siteMatchReviewProvider(null).notifier);
    notifier.select('d1', 's1'); // was pre-selected -> toggles off
    expect(
      container.read(siteMatchReviewProvider(null)).selections.containsKey('d1'),
      false,
    );
  });

  test('_init surfaces an error message when matching throws', () async {
    final container = makeContainer(const []);
    when(
      dives.getDivesNeedingSiteMatch(
        diverId: anyNamed('diverId'),
        limitToIds: anyNamed('limitToIds'),
      ),
    ).thenThrow(StateError('boom'));
    await _settle();
    expect(
      container.read(siteMatchReviewProvider(null)).errorMessage,
      isNotNull,
    );
  });
}
```

- [ ] **Step 4: Generate mocks, run notifier tests**

Run: `dart run build_runner build --delete-conflicting-outputs`
Run: `flutter test test/features/dive_sites/presentation/providers/site_match_review_notifier_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Format + commit**

```bash
dart format lib/features/dive_sites/presentation/providers/site_match_review_notifier.dart test/features/dive_sites/presentation/providers/site_match_review_notifier_test.dart
git add lib/features/dive_sites/presentation/providers/site_match_review_notifier.dart test/features/dive_sites/presentation/providers/
git commit -m "refactor(site-matching): staged notifier (proposals/selections/confirm)"
```

> **Phase B checkpoint:** the notifier computes proposals, pre-selects clear matches, toggles selections, and confirms via the service.

---

## Phase C — Map widget

### Task 6: `MatchSitesMap`

**Files:**
- Create: `lib/features/dive_sites/presentation/widgets/match_sites_map.dart`
- Create: `test/features/dive_sites/presentation/widgets/match_sites_map_test.dart`

- [ ] **Step 1: Create the widget**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/data/services/site_matching_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/maps/data/services/tile_cache_service.dart';
import 'package:submersion/features/maps/presentation/providers/map_tile_providers.dart';
import 'package:submersion/features/maps/presentation/widgets/map_attribution.dart';

/// Map for the Match-Sites review: shows the focused dive's GPS point plus its
/// candidate sites. Tapping a candidate marker selects it.
class MatchSitesMap extends ConsumerStatefulWidget {
  const MatchSitesMap({
    super.key,
    required this.divePoint,
    required this.candidates,
    required this.onSelectCandidate,
    this.selectedCandidateId,
  });

  final GeoPoint divePoint;
  final List<MatchCandidateView> candidates;
  final String? selectedCandidateId;
  final void Function(String candidateId) onSelectCandidate;

  @override
  ConsumerState<MatchSitesMap> createState() => _MatchSitesMapState();
}

class _MatchSitesMapState extends ConsumerState<MatchSitesMap> {
  final MapController _controller = MapController();

  List<LatLng> get _points => [
    LatLng(widget.divePoint.latitude, widget.divePoint.longitude),
    for (final c in widget.candidates)
      LatLng(c.location.latitude, c.location.longitude),
  ];

  @override
  void didUpdateWidget(MatchSitesMap old) {
    super.didUpdateWidget(old);
    // Refit when the focused dive (and so its point/candidates) changes.
    if (old.divePoint != widget.divePoint) {
      final pts = _points;
      if (pts.length >= 2) {
        _controller.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(pts),
            padding: const EdgeInsets.all(40),
            maxZoom: 16,
          ),
        );
      } else {
        _controller.move(pts.first, 13);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pts = _points;
    final fit = pts.length >= 2
        ? CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(pts),
            padding: const EdgeInsets.all(40),
            maxZoom: 16,
          )
        : null;

    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: pts.first,
        initialZoom: 13,
        initialCameraFit: fit,
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
      ),
      children: [
        TileLayer(
          urlTemplate: ref.watch(mapTileUrlProvider),
          userAgentPackageName: 'app.submersion',
          maxZoom: ref.watch(mapTileMaxZoomProvider),
          tileProvider: TileCacheService.instance.isInitialized
              ? TileCacheService.instance.getTileProvider()
              : null,
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: LatLng(
                widget.divePoint.latitude,
                widget.divePoint.longitude,
              ),
              width: 38,
              height: 38,
              child: _pin(scheme.primary, Icons.my_location, scheme.onPrimary),
            ),
            for (final c in widget.candidates)
              Marker(
                point: LatLng(c.location.latitude, c.location.longitude),
                width: c.id == widget.selectedCandidateId ? 46 : 38,
                height: c.id == widget.selectedCandidateId ? 46 : 38,
                child: GestureDetector(
                  onTap: () => widget.onSelectCandidate(c.id),
                  child: _pin(
                    c.id == widget.selectedCandidateId
                        ? scheme.secondary
                        : (c.isExisting ? Colors.teal : Colors.indigo),
                    Icons.place,
                    Colors.white,
                  ),
                ),
              ),
          ],
        ),
        const MapAttribution(),
      ],
    );
  }

  Widget _pin(Color color, IconData icon, Color iconColor) => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 2),
    ),
    child: Center(child: Icon(icon, size: 18, color: iconColor)),
  );
}
```

> Confirm the imports resolve: `tile_cache_service.dart`, `map_tile_providers.dart`, `map_attribution.dart` are the paths the existing `dive_locations_map.dart` uses (verify by opening that file). `flutter_map` and `latlong2` are in `pubspec.yaml`.

- [ ] **Step 2: Smoke test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/data/services/site_matching_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/match_sites_map.dart';

void main() {
  testWidgets('renders dive + candidate markers and reports taps', (
    tester,
  ) async {
    String? tapped;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: MatchSitesMap(
              divePoint: const GeoPoint(0, 0),
              candidates: const [
                MatchCandidateView(
                  id: 's1',
                  name: 'Blue Hole',
                  isExisting: true,
                  distanceMeters: 40,
                  location: GeoPoint(0, 0.0003),
                ),
              ],
              selectedCandidateId: null,
              onSelectCandidate: (id) => tapped = id,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // Dive pin + one candidate pin.
    expect(find.byIcon(Icons.my_location), findsOneWidget);
    expect(find.byIcon(Icons.place), findsOneWidget);

    await tester.tap(find.byIcon(Icons.place));
    expect(tapped, 's1');
  });
}
```

- [ ] **Step 3: Run**

Run: `flutter test test/features/dive_sites/presentation/widgets/match_sites_map_test.dart`
Expected: PASS. (If tile network fetches log warnings, ignore — the test asserts markers, not tiles.)

- [ ] **Step 4: Format + commit**

```bash
dart format lib/features/dive_sites/presentation/widgets/match_sites_map.dart test/features/dive_sites/presentation/widgets/match_sites_map_test.dart
git add lib/features/dive_sites/presentation/widgets/match_sites_map.dart test/features/dive_sites/presentation/widgets/match_sites_map_test.dart
git commit -m "feat(site-matching): add MatchSitesMap (dive + candidate pins, tap to select)"
```

---

## Phase D — l10n + page

### Task 7: l10n keys

**Files:**
- Modify: `lib/l10n/arb/app_en.arb`

- [ ] **Step 1: Add/replace keys**

Add these near the other `siteMatchReview_*` keys (and remove the now-unused `siteMatchReview_unlink`, `siteMatchReview_newlyAdded`, `siteMatchReview_nearbySites`, `siteMatchReview_matchedSubtitle`):

```json
"siteMatchReview_summary": "{selected} selected · {review} to review · {none} no match",
"@siteMatchReview_summary": {
  "placeholders": {
    "selected": { "type": "int" },
    "review": { "type": "int" },
    "none": { "type": "int" }
  }
},
"siteMatchReview_confirm": "Confirm {count} matches",
"@siteMatchReview_confirm": {
  "placeholders": { "count": { "type": "int" } }
},
"siteMatchReview_cancel": "Cancel",
"siteMatchReview_chooseSite": "Choose a site",
"siteMatchReview_tapToChoose": "Tap to choose a site",
"siteMatchReview_awayMeters": "{meters} m away",
"@siteMatchReview_awayMeters": {
  "placeholders": { "meters": { "type": "int" } }
},
"siteMatchReview_depthTo": "to {meters} m",
"@siteMatchReview_depthTo": {
  "placeholders": { "meters": { "type": "int" } }
},
"siteMatchReview_depthRange": "{min}–{max} m",
"@siteMatchReview_depthRange": {
  "placeholders": { "min": { "type": "int" }, "max": { "type": "int" } }
},
"siteMatchReview_diveLabel": "Your dive",
"siteMatchReview_appliedSnack": "Linked {dives} dives · added {sites} sites",
"@siteMatchReview_appliedSnack": {
  "placeholders": { "dives": { "type": "int" }, "sites": { "type": "int" } }
},
"siteMatchReview_applyError": "Couldn't apply matches",
"siteMatchReview_discardTitle": "Discard matches?",
"siteMatchReview_discardMessage": "Your selections won't be saved.",
"siteMatchReview_discardConfirm": "Discard",
"siteMatchReview_keepReviewing": "Keep reviewing"
```

Keep the existing `siteMatchReview_title`, `siteMatchReview_done` (reused as a fallback), `siteMatchReview_empty`, `siteMatchReview_sourceExisting`, `siteMatchReview_sourceBundled`, `siteMatchReview_noNearbySite`.

- [ ] **Step 2: Regenerate + verify**

Run: `flutter gen-l10n`
Run: `flutter test test/l10n/localization_test.dart`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add lib/l10n/
git commit -m "feat(site-matching): l10n for staged review (confirm/cancel/map/cards)"
```

---

### Task 8: Page rewrite — map + accordion + confirm bar

**Files:**
- Modify: `lib/features/dive_sites/presentation/pages/site_match_review_page.dart`

- [ ] **Step 1: Rewrite the page**

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/data/services/site_matching_service.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_match_review_notifier.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/match_sites_map.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Staged review: compute proposals, choose a site per dive (list or map),
/// then Confirm to write all matches. Reached post-download and from the
/// dives-list overflow menu (diveIds == null = whole eligible backlog).
class SiteMatchReviewPage extends ConsumerWidget {
  const SiteMatchReviewPage({super.key, this.diveIds});

  final List<String>? diveIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(siteMatchReviewProvider(diveIds));
    final notifier = ref.read(siteMatchReviewProvider(diveIds).notifier);

    Future<void> onConfirm() async {
      final result = await notifier.confirm();
      if (!context.mounted) return;
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.siteMatchReview_applyError)),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.siteMatchReview_appliedSnack(
              result.divesLinked,
              result.sitesCreated,
            ),
          ),
        ),
      );
      Navigator.of(context).pop();
    }

    Future<void> onCancel() async {
      if (state.selections.isEmpty) {
        Navigator.of(context).pop();
        return;
      }
      final discard = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.siteMatchReview_discardTitle),
          content: Text(l10n.siteMatchReview_discardMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.siteMatchReview_keepReviewing),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.siteMatchReview_discardConfirm),
            ),
          ],
        ),
      );
      if (discard == true && context.mounted) Navigator.of(context).pop();
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.siteMatchReview_title)),
      body: Builder(
        builder: (_) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.errorMessage != null) {
            return Center(child: Text(state.errorMessage!));
          }
          if (state.proposals.isEmpty) {
            return Center(child: Text(l10n.siteMatchReview_empty));
          }
          return Column(
            children: [
              _MapPanel(state: state, notifier: notifier),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  l10n.siteMatchReview_summary(
                    state.selectedCount,
                    state.reviewCount,
                    state.noMatchCount,
                  ),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    for (final p in state.proposals)
                      _DiveRow(
                        proposal: p,
                        focused: p.dive.id == state.focusedDiveId,
                        selectedCandidateId: state.selections[p.dive.id],
                        onFocus: () => notifier.focusDive(p.dive.id),
                        onSelect: (cid) => notifier.select(p.dive.id, cid),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: state.isLoading || state.proposals.isEmpty
          ? null
          : _ConfirmBar(
              count: state.selectedCount,
              busy: state.isApplying,
              onCancel: onCancel,
              onConfirm: state.selectedCount == 0 ? null : onConfirm,
            ),
    );
  }
}

class _MapPanel extends StatelessWidget {
  const _MapPanel({required this.state, required this.notifier});
  final SiteMatchReviewState state;
  final SiteMatchReviewNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final p = state.focusedProposal;
    final point = p?.dive.entryLocation ?? p?.dive.exitLocation;
    if (p == null || point == null) {
      return const SizedBox(height: 200);
    }
    return SizedBox(
      height: 200,
      child: MatchSitesMap(
        key: ValueKey(p.dive.id),
        divePoint: point,
        candidates: p.candidates,
        selectedCandidateId: state.selections[p.dive.id],
        onSelectCandidate: (cid) => notifier.select(p.dive.id, cid),
      ),
    );
  }
}

class _DiveRow extends StatelessWidget {
  const _DiveRow({
    required this.proposal,
    required this.focused,
    required this.selectedCandidateId,
    required this.onFocus,
    required this.onSelect,
  });

  final MatchProposal proposal;
  final bool focused;
  final String? selectedCandidateId;
  final VoidCallback onFocus;
  final void Function(String candidateId) onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = 'Dive #${proposal.dive.diveNumber ?? '?'}';
    final selected = selectedCandidateId == null
        ? null
        : proposal.candidates
              .where((c) => c.id == selectedCandidateId)
              .firstOrNull;

    final subtitle = switch (proposal.status) {
      ProposalStatus.none => l10n.siteMatchReview_noNearbySite,
      _ =>
        selected != null
            ? '${selected.name} · ${l10n.siteMatchReview_awayMeters(selected.distanceMeters.round())}'
            : l10n.siteMatchReview_tapToChoose,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          selected: focused,
          leading: Icon(
            selected != null
                ? Icons.check_circle
                : (proposal.status == ProposalStatus.none
                      ? Icons.location_off_outlined
                      : Icons.help_outline),
            color: selected != null ? Colors.green : null,
          ),
          title: Text(title),
          subtitle: Text(subtitle),
          onTap: onFocus,
        ),
        if (focused && proposal.candidates.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              children: [
                for (final c in proposal.candidates)
                  _CandidateCard(
                    candidate: c,
                    selected: c.id == selectedCandidateId,
                    onTap: () => onSelect(c.id),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({
    required this.candidate,
    required this.selected,
    required this.onTap,
  });

  final MatchCandidateView candidate;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final c = candidate;

    final meta = <String>[
      l10n.siteMatchReview_awayMeters(c.distanceMeters.round()),
      if (c.minDepth != null && c.maxDepth != null)
        l10n.siteMatchReview_depthRange(c.minDepth!.round(), c.maxDepth!.round())
      else if (c.maxDepth != null)
        l10n.siteMatchReview_depthTo(c.maxDepth!.round()),
      if ((c.region ?? c.country) != null) (c.region ?? c.country)!,
    ];

    return Card(
      color: selected ? scheme.secondaryContainer : null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      c.name,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  Text(
                    c.isExisting
                        ? l10n.siteMatchReview_sourceExisting
                        : l10n.siteMatchReview_sourceBundled,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(meta.join(' · '),
                  style: TextStyle(color: scheme.onSurfaceVariant)),
              if (c.rating != null || c.difficulty != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    [
                      if (c.rating != null) '★ ${c.rating!.toStringAsFixed(1)}',
                      if (c.difficulty != null) c.difficulty!,
                    ].join(' · '),
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              if (c.features.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Wrap(
                    spacing: 6,
                    children: [
                      for (final f in c.features) Chip(label: Text(f)),
                    ],
                  ),
                ),
              if (c.description != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    c.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfirmBar extends StatelessWidget {
  const _ConfirmBar({
    required this.count,
    required this.busy,
    required this.onCancel,
    required this.onConfirm,
  });

  final int count;
  final bool busy;
  final VoidCallback onCancel;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: busy ? null : onCancel,
                child: Text(l10n.siteMatchReview_cancel),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: busy ? null : onConfirm,
                child: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.siteMatchReview_confirm(count)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

> `firstOrNull` comes from `package:collection`, which is already a transitive dependency used across the app; if analyze flags it, add `import 'package:collection/collection.dart';`. The "Skip this dive" affordance is implicitly "leave unselected" (a review dive with no selection counts toward "to review" and is simply not confirmed) — no extra control needed for v1. The wide-screen side-by-side is deferred (see Task 9 note); this stacked layout works on all widths.

- [ ] **Step 2: Analyze**

Run: `flutter analyze lib/features/dive_sites/presentation/pages/site_match_review_page.dart`
Expected: "No issues found!" (add the `collection` import if `firstOrNull` is flagged).

- [ ] **Step 3: Commit**

```bash
dart format lib/features/dive_sites/presentation/pages/site_match_review_page.dart
git add lib/features/dive_sites/presentation/pages/site_match_review_page.dart
git commit -m "feat(site-matching): map + accordion + confirm/cancel review screen"
```

---

### Task 9: Rewrite the page widget test

**Files:**
- Modify: `test/features/dive_sites/presentation/pages/site_match_review_page_test.dart`

- [ ] **Step 1: Replace the test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/data/services/site_matching_service.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_match_review_page.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_match_review_notifier.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _SeededNotifier extends SiteMatchReviewNotifier {
  _SeededNotifier(Ref ref, SiteMatchReviewState seeded)
    : super(ref, null, autoInit: false) {
    state = seeded;
  }
}

Dive _dive(int n, {bool gps = true}) => Dive(
  id: 'd$n',
  diveNumber: n,
  dateTime: DateTime(2026, 1, 1),
  maxDepth: 18,
  entryLocation: gps ? const GeoPoint(0, 0) : null,
);

MatchCandidateView _cand(String id, {bool existing = true}) => MatchCandidateView(
  id: id,
  name: 'Site $id',
  isExisting: existing,
  distanceMeters: 42,
  location: const GeoPoint(0, 0.0003),
  maxDepth: 30,
  region: 'Red Sea',
);

Widget _harness(SiteMatchReviewState seeded) => ProviderScope(
  overrides: [
    siteMatchReviewProvider(
      null,
    ).overrideWith((ref) => _SeededNotifier(ref, seeded)),
  ],
  child: const MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: SiteMatchReviewPage(),
  ),
);

void main() {
  testWidgets('loading shows progress', (tester) async {
    await tester.pumpWidget(_harness(const SiteMatchReviewState()));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsWidgets);
  });

  testWidgets('renders summary, confirm bar, and focused candidates', (
    tester,
  ) async {
    final dive = _dive(7);
    final seeded = SiteMatchReviewState(
      isLoading: false,
      proposals: [
        MatchProposal(
          dive: dive,
          status: ProposalStatus.clear,
          candidates: [_cand('s1')],
          recommendedCandidateId: 's1',
        ),
      ],
      focusedDiveId: 'd7',
      selections: const {'d7': 's1'},
    );
    await tester.pumpWidget(_harness(seeded));
    await tester.pump();

    expect(find.textContaining('1 selected'), findsOneWidget);
    expect(find.textContaining('Confirm 1'), findsOneWidget);
    // Focused dive expands its candidate card.
    expect(find.text('Site s1'), findsWidgets);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('confirm disabled when nothing selected', (tester) async {
    final seeded = SiteMatchReviewState(
      isLoading: false,
      proposals: [
        MatchProposal(
          dive: _dive(3),
          status: ProposalStatus.review,
          candidates: [_cand('a'), _cand('b')],
        ),
      ],
      focusedDiveId: 'd3',
      selections: const {},
    );
    await tester.pumpWidget(_harness(seeded));
    await tester.pump();

    expect(find.textContaining('0 selected'), findsOneWidget);
    final confirm = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(confirm.onPressed, isNull); // disabled
  });

  testWidgets('no-match dive shows no nearby site', (tester) async {
    final seeded = SiteMatchReviewState(
      isLoading: false,
      proposals: [
        MatchProposal(dive: _dive(9), status: ProposalStatus.none),
      ],
      focusedDiveId: 'd9',
      selections: const {},
    );
    await tester.pumpWidget(_harness(seeded));
    await tester.pump();
    expect(find.text('No nearby site'), findsOneWidget);
  });

  testWidgets('cancel with selections prompts to discard', (tester) async {
    final seeded = SiteMatchReviewState(
      isLoading: false,
      proposals: [
        MatchProposal(
          dive: _dive(7),
          status: ProposalStatus.clear,
          candidates: [_cand('s1')],
          recommendedCandidateId: 's1',
        ),
      ],
      focusedDiveId: 'd7',
      selections: const {'d7': 's1'},
    );
    await tester.pumpWidget(_harness(seeded));
    await tester.pump();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Discard matches?'), findsOneWidget);
  });
}
```

> The map (`MatchSitesMap`) renders inside the page; widget tests pump it without tiles loading — assert on text/buttons, not map internals. If a focused dive with GPS makes the map attempt network tiles and emit errors, they are non-fatal in tests.

- [ ] **Step 2: Run**

Run: `flutter test test/features/dive_sites/presentation/pages/site_match_review_page_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 3: Format + commit**

```bash
dart format test/features/dive_sites/presentation/pages/site_match_review_page_test.dart
git add test/features/dive_sites/presentation/pages/site_match_review_page_test.dart
git commit -m "test(site-matching): rewrite review page widget tests for staged UI"
```

> **Phase D checkpoint:** the staged map+confirm screen works end-to-end.

---

### Task 10: Responsive wide-screen layout (list ‖ map + cards)

**Files:**
- Modify: `lib/features/dive_sites/presentation/pages/site_match_review_page.dart`
- Modify: `test/features/dive_sites/presentation/pages/site_match_review_page_test.dart`

- [ ] **Step 1: Make `_DiveRow` inline cards optional**

Add `final bool showInlineCards;` to `_DiveRow` (constructor `required this.showInlineCards,`), and change its inline-cards guard:

```dart
if (focused && showInlineCards && proposal.candidates.isNotEmpty)
```

- [ ] **Step 2: Make the page body responsive**

Replace the body `Column(...)` (the non-loading/-error/-empty branch) with a `LayoutBuilder` that stacks on narrow and splits on wide (≥720 dp). The dive list is shared; on wide it doesn't expand inline (the detail pane shows the focused dive's cards):

```dart
final summary = Padding(
  padding: const EdgeInsets.all(12),
  child: Text(
    l10n.siteMatchReview_summary(
      state.selectedCount,
      state.reviewCount,
      state.noMatchCount,
    ),
    style: Theme.of(context).textTheme.titleMedium,
  ),
);

return LayoutBuilder(
  builder: (context, constraints) {
    final wide = constraints.maxWidth >= 720;
    final list = ListView(
      children: [
        for (final p in state.proposals)
          _DiveRow(
            proposal: p,
            focused: p.dive.id == state.focusedDiveId,
            selectedCandidateId: state.selections[p.dive.id],
            showInlineCards: !wide,
            onFocus: () => notifier.focusDive(p.dive.id),
            onSelect: (cid) => notifier.select(p.dive.id, cid),
          ),
      ],
    );

    if (!wide) {
      return Column(
        children: [
          _MapPanel(state: state, notifier: notifier),
          summary,
          Expanded(child: list),
        ],
      );
    }

    final focused = state.focusedProposal;
    return Row(
      children: [
        Expanded(flex: 2, child: list),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 3,
          child: Column(
            children: [
              _MapPanel(state: state, notifier: notifier),
              summary,
              Expanded(
                child: ListView(
                  children: [
                    if (focused != null)
                      for (final c in focused.candidates)
                        _CandidateCard(
                          candidate: c,
                          selected:
                              c.id == state.selections[focused.dive.id],
                          onTap: () =>
                              notifier.select(focused.dive.id, c.id),
                        ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  },
);
```

(The old body's standalone `summary` `Padding` and the `Column`/`Expanded(list)` are now produced inside the `LayoutBuilder`; delete the previous inline versions.)

- [ ] **Step 3: Wide-screen widget test**

Append to the page test:

```dart
testWidgets('wide layout shows list and detail side by side', (tester) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1100, 800);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final seeded = SiteMatchReviewState(
    isLoading: false,
    proposals: [
      MatchProposal(
        dive: _dive(7),
        status: ProposalStatus.clear,
        candidates: [_cand('s1')],
        recommendedCandidateId: 's1',
      ),
    ],
    focusedDiveId: 'd7',
    selections: const {'d7': 's1'},
  );
  await tester.pumpWidget(_harness(seeded));
  await tester.pump();

  expect(find.byType(VerticalDivider), findsOneWidget); // side-by-side
  expect(find.text('Site s1'), findsWidgets); // detail pane candidate
});
```

- [ ] **Step 4: Analyze, run, commit**

Run: `flutter analyze lib/features/dive_sites/presentation/pages/site_match_review_page.dart`
Run: `flutter test test/features/dive_sites/presentation/pages/site_match_review_page_test.dart`
Expected: PASS.

```bash
dart format lib/features/dive_sites/presentation/pages/site_match_review_page.dart test/features/dive_sites/presentation/pages/site_match_review_page_test.dart
git add lib/features/dive_sites/presentation/pages/site_match_review_page.dart test/features/dive_sites/presentation/pages/site_match_review_page_test.dart
git commit -m "feat(site-matching): responsive wide-screen layout for the review screen"
```

---

## Phase E — Final verification

### Task 11: Full verification

- [ ] **Step 1: Analyze (full project)**

Run: `flutter analyze`
Expected: "No issues found!" Fix any breakage in the entry-point tests (`import_summary_step_test`, `dive_list_page_test`) — they only navigate to the page and should be unaffected, but confirm.

- [ ] **Step 2: Run the affected suites**

Run:
```bash
flutter test test/features/dive_sites/ test/features/import_wizard/presentation/widgets/import_summary_step_test.dart test/features/dive_log/presentation/pages/dive_list_page_test.dart test/l10n/localization_test.dart
```
Expected: all PASS.

- [ ] **Step 3: Patch coverage check (hold ≥90%)**

Run: `flutter test --coverage`
Then recompute patch coverage over the changed lib files (matcher unchanged; service/notifier/page/map are the patch). Add focused tests if any changed file falls below 90% — likely candidates: the `_CandidateCard` field-omission branches (add a card test with a bundled candidate that has `features` + no rating) and `applyConfirmed` skip path (already covered).

- [ ] **Step 4: Format + final commit (if coverage tests were added)**

```bash
dart format lib/ test/
git add -A
git commit -m "test(site-matching): coverage for staged review map/cards"
```

- [ ] **Step 5: Guardrail re-confirm**

Confirm `reparse_service.dart` still never writes `siteId` (unchanged) and that `applyConfirmed`'s writes all occur inside the injected transaction (so a mid-batch failure rolls back). No code change — verification only.

---

## Notes for the implementer

- **Mockito regen:** after editing `@GenerateMocks` lists (service + notifier tests both mock the three repos), run `dart run build_runner build --delete-conflicting-outputs` before running those tests.
- **Transaction injection** is the key testability seam: production uses `DatabaseService.instance.database.transaction`; unit tests pass `runInTransaction: (body) => body()`.
- **Entry points unchanged:** `/dives/match-sites` route, the dives-list overflow action, and the post-download button all still construct `SiteMatchReviewPage(diveIds: ...)`. `eligibleImportedDivesProvider` and `getDivesNeedingSiteMatch` are untouched.
- **Wide-screen side-by-side** (list left / map+cards right) is intentionally deferred — the stacked layout is responsive enough for v1; revisit if desired.
