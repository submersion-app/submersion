import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/services/dive_site_api_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_match_review_notifier.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';
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

  // The notifier builds its service with the production transaction runner
  // (DatabaseService.instance.database.transaction); confirm() needs a real
  // in-memory DB to open/commit around the (mocked, no-op) repo writes.
  setUp(() async {
    await setUpTestDatabase();
  });
  tearDown(() async {
    await tearDownTestDatabase();
  });

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
    // DiveListNotifier.refresh() (triggered by confirm) reloads via getAllDives.
    when(
      dives.getAllDives(diverId: anyNamed('diverId')),
    ).thenAnswer((_) async => <Dive>[]);
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
        // DiveListNotifier reads currentDiverIdProvider in its constructor;
        // mock it so confirm()'s post-apply refresh can build the notifier.
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
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
    verifyNever(dives.setSite(any, any));
  });

  test('select then confirm writes once and returns counts', () async {
    final container = makeContainer([_dive('d1', const GeoPoint(0, 0))]);
    when(sites.getAllSites(diverId: anyNamed('diverId'))).thenAnswer(
      (_) async => const [
        DiveSite(id: 'a', name: 'A', location: GeoPoint(0, 0.0003)),
        DiveSite(id: 'b', name: 'B', location: GeoPoint(0, 0.0006)),
      ],
    );

    await _settle();
    expect(container.read(siteMatchReviewProvider(null)).selectedCount, 0);

    final notifier = container.read(siteMatchReviewProvider(null).notifier);
    notifier.select('d1', 'b');
    expect(container.read(siteMatchReviewProvider(null)).selections['d1'], 'b');

    final result = await notifier.confirm();
    expect(result?.divesLinked, 1);
    verify(dives.setSite('d1', 'b')).called(1);
  });

  test('confirm with no selection returns null without writing', () async {
    final container = makeContainer([_dive('d1', const GeoPoint(0, 0))]);
    when(sites.getAllSites(diverId: anyNamed('diverId'))).thenAnswer(
      (_) async => const [
        // Review-tier (not auto-selected), so nothing is chosen after init.
        DiveSite(id: 'a', name: 'A', location: GeoPoint(0, 0.0003)),
        DiveSite(id: 'b', name: 'B', location: GeoPoint(0, 0.0006)),
      ],
    );
    await _settle();
    expect(container.read(siteMatchReviewProvider(null)).selectedCount, 0);

    final notifier = container.read(siteMatchReviewProvider(null).notifier);
    final result = await notifier.confirm();

    // Empty selection short-circuits: null result, no transaction, no writes,
    // and isApplying is never left stuck on.
    expect(result, isNull);
    expect(container.read(siteMatchReviewProvider(null)).isApplying, false);
    verifyNever(dives.setSite(any, any));
  });

  test('confirm refreshes the dive list so linked sites appear', () async {
    final container = makeContainer([_dive('d1', _eastMeters(33))]);
    when(sites.getAllSites(diverId: anyNamed('diverId'))).thenAnswer(
      (_) async => const [
        DiveSite(id: 's1', name: 'Blue Hole', location: GeoPoint(0, 0)),
      ],
    );
    await _settle();

    final notifier = container.read(siteMatchReviewProvider(null).notifier);
    // Nothing has reloaded the dive list yet (init only reads dives needing
    // matching, never the full list via getAllDives).
    verifyNever(dives.getAllDives(diverId: anyNamed('diverId')));

    await notifier.confirm();

    // confirm() must refresh DiveListNotifier so the dives list drops the
    // stale "unknown site" rows for the dives it just linked.
    verify(
      dives.getAllDives(diverId: anyNamed('diverId')),
    ).called(greaterThanOrEqualTo(1));
  });

  test(
    'confirm refreshes the sites list when a bundled site is created',
    () async {
      final container = makeContainer([_dive('d1', const GeoPoint(0, 0))]);
      when(sites.createSite(any)).thenAnswer((inv) async {
        final s = inv.positionalArguments.first as DiveSite;
        return s.copyWith(id: 'new-${s.name}');
      });
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
      await _settle();

      final notifier = container.read(siteMatchReviewProvider(null).notifier);
      final result = await notifier.confirm();
      await _settle();

      expect(result?.sitesCreated, 1);
      // SiteListNotifier.refresh() reloads sites via getAllSites. computeProposals
      // reads it once; >1 proves the post-apply sites-tab refresh also ran, so a
      // newly materialised bundled site shows up on the Sites tab.
      verify(
        sites.getAllSites(diverId: anyNamed('diverId')),
      ).called(greaterThan(1));
    },
  );

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
      container
          .read(siteMatchReviewProvider(null))
          .selections
          .containsKey('d1'),
      false,
    );
  });

  test(
    'deselecting a clear match counts it as "to review", not unaccounted',
    () async {
      final container = makeContainer([_dive('d1', _eastMeters(33))]);
      when(sites.getAllSites(diverId: anyNamed('diverId'))).thenAnswer(
        (_) async => const [
          DiveSite(id: 's1', name: 'Blue Hole', location: GeoPoint(0, 0)),
        ],
      );
      await _settle();
      final notifier = container.read(siteMatchReviewProvider(null).notifier);

      // Pre-selected clear match: counted as selected, not to-review.
      var state = container.read(siteMatchReviewProvider(null));
      expect(state.selectedCount, 1);
      expect(state.reviewCount, 0);

      // Toggle it off: it now needs review rather than disappearing from every
      // summary bucket. The three counts must still partition all proposals.
      notifier.select('d1', 's1');
      state = container.read(siteMatchReviewProvider(null));
      expect(state.selectedCount, 0);
      expect(state.reviewCount, 1);
      expect(
        state.selectedCount + state.reviewCount + state.noMatchCount,
        state.proposals.length,
      );
    },
  );

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

  test('focusDive changes the focused dive', () async {
    final container = makeContainer([
      _dive('d1', _eastMeters(33)),
      _dive('d2', _eastMeters(40)),
    ]);
    when(sites.getAllSites(diverId: anyNamed('diverId'))).thenAnswer(
      (_) async => const [
        DiveSite(id: 's1', name: 'Blue Hole', location: GeoPoint(0, 0)),
      ],
    );
    await _settle();
    final notifier = container.read(siteMatchReviewProvider(null).notifier);

    notifier.focusDive('d2');
    expect(container.read(siteMatchReviewProvider(null)).focusedDiveId, 'd2');
  });

  test(
    'apply failure is transient: returns null, keeps review screen reviewable',
    () async {
      final container = makeContainer([_dive('d1', _eastMeters(33))]);
      when(sites.getAllSites(diverId: anyNamed('diverId'))).thenAnswer(
        (_) async => const [
          DiveSite(id: 's1', name: 'Blue Hole', location: GeoPoint(0, 0)),
        ],
      );
      await _settle();
      when(dives.setSite(any, any)).thenThrow(StateError('write failed'));

      final notifier = container.read(siteMatchReviewProvider(null).notifier);
      final result = await notifier.confirm();
      final state = container.read(siteMatchReviewProvider(null));

      expect(result, isNull);
      // Apply errors are surfaced by the page's snackbar, not the fatal
      // errorMessage view; the proposals/selections stay so the user can retry.
      expect(state.errorMessage, isNull);
      expect(state.isApplying, false);
      expect(state.proposals, isNotEmpty);
      expect(state.selections['d1'], 's1');
    },
  );

  test(
    'eligibleImportedDivesProvider returns matchable imported ids',
    () async {
      final container = makeContainer([_dive('d1', _eastMeters(33))]);

      final ids = await container.read(
        eligibleImportedDivesProvider(
          const ImportedDiveIds(['d1', 'd2']),
        ).future,
      );
      expect(ids, ['d1']);

      final empty = await container.read(
        eligibleImportedDivesProvider(const ImportedDiveIds([])).future,
      );
      expect(empty, isEmpty);
    },
  );
}
