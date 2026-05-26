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
