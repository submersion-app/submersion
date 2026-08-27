import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// Issue #1187: the dive edit page's altitude and photo-GPS write-backs used
/// to send a (possibly partial) site entity through `updateSite`, which
/// rewrites every column. These targeted patches touch only the columns
/// they are named for.
void main() {
  late ProviderContainer container;
  late SiteRepository siteRepository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
    siteRepository = SiteRepository();
    container = ProviderContainer(
      overrides: [
        siteRepositoryProvider.overrideWithValue(siteRepository),
        sharedPreferencesProvider.overrideWithValue(prefs),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  const richSite = DiveSite(
    id: 'site-rich',
    name: 'Hertenstein',
    location: GeoPoint(47.027631, 8.400640),
    minDepth: 5,
    maxDepth: 40,
    difficulty: SiteDifficulty.advanced,
    waterType: WaterType.fresh,
    country: 'Switzerland',
    region: 'Lucerne',
    city: 'Weggis',
    bodyOfWater: 'Lake Lucerne',
    rating: 4,
    hazards: 'Boat traffic',
    entryMethod: EntryMethod.shore,
    isShared: true,
  );

  test('updateSiteAltitude writes only the altitude', () async {
    await siteRepository.createSite(richSite);
    final notifier = container.read(siteListNotifierProvider.notifier);

    await notifier.updateSiteAltitude('site-rich', 434.0);

    final stored = await siteRepository.getSiteById('site-rich');
    expect(stored!.altitude, 434.0);
    expect(stored.difficulty, SiteDifficulty.advanced);
    expect(stored.waterType, WaterType.fresh);
    expect(stored.city, 'Weggis');
    expect(stored.bodyOfWater, 'Lake Lucerne');
    expect(stored.hazards, 'Boat traffic');
    expect(stored.entryMethod, EntryMethod.shore);
    expect(stored.isShared, isTrue);
    expect(stored.location, const GeoPoint(47.027631, 8.400640));
  });

  test('updateSiteCoordinates writes location and altitude only', () async {
    await siteRepository.createSite(richSite);
    final notifier = container.read(siteListNotifierProvider.notifier);

    await notifier.updateSiteCoordinates(
      'site-rich',
      const GeoPoint(12.1609, -68.2836),
      altitude: 3.0,
    );

    final stored = await siteRepository.getSiteById('site-rich');
    expect(stored!.location, const GeoPoint(12.1609, -68.2836));
    expect(stored.altitude, 3.0);
    expect(stored.difficulty, SiteDifficulty.advanced);
    expect(stored.rating, 4);
    expect(stored.bodyOfWater, 'Lake Lucerne');
    expect(stored.isShared, isTrue);
  });

  test(
    'updateSiteCoordinates without altitude leaves altitude alone',
    () async {
      await siteRepository.createSite(richSite.copyWith(altitude: 434.0));
      final notifier = container.read(siteListNotifierProvider.notifier);

      await notifier.updateSiteCoordinates(
        'site-rich',
        const GeoPoint(12.1609, -68.2836),
      );

      final stored = await siteRepository.getSiteById('site-rich');
      expect(stored!.altitude, 434.0);
    },
  );

  test('targeted patches refresh the notifier state', () async {
    await siteRepository.createSite(richSite);
    final notifier = container.read(siteListNotifierProvider.notifier);

    await notifier.updateSiteAltitude('site-rich', 434.0);

    final state = container.read(siteListNotifierProvider);
    final site = state.value!.singleWhere((s) => s.id == 'site-rich');
    expect(site.altitude, 434.0);
  });
}
