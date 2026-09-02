import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/services/dive_site_api_service.dart';
import 'package:submersion/features/dive_sites/data/services/site_matching_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_suggestion_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/weather/presentation/providers/weather_providers.dart';

import '../../../../helpers/mock_providers.dart';
import 'site_suggestion_providers_test.mocks.dart';

@GenerateMocks([
  SiteRepository,
  DiveSiteApiService,
  DiveRepository,
  MediaRepository,
])
void main() {
  late MockSiteRepository sites;
  late MockDiveSiteApiService api;
  late MockDiveRepository dives;
  late MockMediaRepository media;

  ProviderContainer makeContainer({required List<Dive> eligible}) {
    sites = MockSiteRepository();
    api = MockDiveSiteApiService();
    dives = MockDiveRepository();
    media = MockMediaRepository();
    when(
      dives.getDivesNeedingSiteMatch(
        diverId: anyNamed('diverId'),
        limitToIds: anyNamed('limitToIds'),
      ),
    ).thenAnswer((_) async => eligible);
    when(
      dives.watchDivesChanges(),
    ).thenAnswer((_) => const Stream<void>.empty());
    when(
      sites.watchSitesChanges(),
    ).thenAnswer((_) => const Stream<void>.empty());
    when(
      media.watchMediaChanges(),
    ).thenAnswer((_) => const Stream<void>.empty());
    when(media.getBestPhotoGpsForDives(any)).thenAnswer((_) async => const {});
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
        mediaRepositoryProvider.overrideWithValue(media),
        validatedCurrentDiverIdProvider.overrideWith((ref) => 'diver-1'),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        weatherHttpClientProvider.overrideWithValue(
          MockClient((_) async => http.Response('', 500)),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('returns null when the dive is not eligible', () async {
    final container = makeContainer(eligible: const []);
    expect(
      await container.read(siteSuggestionForDiveProvider('d1').future),
      isNull,
    );
  });

  test('returns a proposal with its service when eligible', () async {
    final container = makeContainer(
      eligible: [
        Dive(
          id: 'd1',
          diveNumber: 1,
          dateTime: DateTime(2026, 1, 1),
          maxDepth: 18,
          entryLocation: const GeoPoint(0, 0),
        ),
      ],
    );
    final s = await container.read(siteSuggestionForDiveProvider('d1').future);
    expect(s, isNotNull);
    expect(s!.proposal.status, ProposalStatus.none);
    expect(s.point, const GeoPoint(0, 0));
    expect(s.pointSource, PointSource.diveComputer);
    expect(s.service, isA<SiteMatchingService>());
  });

  test('the factory wires the sensitivity thresholds', () {
    final container = makeContainer(eligible: const []);
    final service = container.read(siteMatchingServiceFactoryProvider)(
      'diver-1',
    );
    expect(
      service.thresholds,
      MockSettingsNotifier().state.siteMatchSensitivity.thresholds,
    );
  });
}
