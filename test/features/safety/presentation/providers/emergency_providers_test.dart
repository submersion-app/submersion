import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/safety/data/services/emergency_data_service.dart';
import 'package:submersion/features/safety/domain/entities/emergency_info.dart';
import 'package:submersion/features/safety/data/repositories/emergency_chamber_repository.dart';
import 'package:submersion/features/safety/presentation/providers/emergency_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';

class _FakeDiveRepository extends Fake implements DiveRepository {
  final List<DiveSummary> summaries;
  String? queriedDiverId;

  _FakeDiveRepository(this.summaries);

  @override
  Stream<void> watchDivesChanges() => const Stream.empty();

  @override
  Future<List<DiveSummary>> getDiveSummaries({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
    DiveSummaryCursor? cursor,
    int? offset,
    int limit = 50,
    SortState<DiveSortField>? sort,
    Set<String> disabledSafetyRules = const {},
  }) async {
    queriedDiverId = diverId;
    return summaries;
  }
}

class _FakeChamberRepo extends Fake implements EmergencyChamberRepository {
  final List<EmergencyChamber> chambers;

  _FakeChamberRepo(this.chambers);

  @override
  Stream<void> watchChanges() => const Stream.empty();

  @override
  Future<List<EmergencyChamber>> getUserChambers({String? diverId}) async =>
      chambers;
}

DiveSummary _summary({String? country, double? lat, double? lon}) {
  return DiveSummary(
    id: 'd1',
    dateTime: DateTime.utc(2026, 7, 1),
    sortTimestamp: 0,
    siteCountry: country,
    siteLatitude: lat,
    siteLongitude: lon,
  );
}

/// A chamber the diver added themselves. `EmergencyChamberRepository` always
/// builds these with `isBuiltIn: false`, and the ordering bands rely on that
/// to keep a diver's own entries at the top.
EmergencyChamber _chamber(
  String id,
  String country, {
  double? lat,
  double? lon,
}) {
  return EmergencyChamber(
    id: id,
    name: 'Chamber $id',
    country: country,
    phone: '+1',
    latitude: lat,
    longitude: lon,
    isBuiltIn: false,
  );
}

EmergencyChamber _bundled({
  required String id,
  String country = 'AU',
  ChamberCapability capability = ChamberCapability.divingEmergency,
  double? lat,
  double? lon,
}) {
  return EmergencyChamber(
    id: id,
    name: 'Chamber $id',
    country: country,
    phone: '+61-7-0000-0000',
    latitude: lat,
    longitude: lon,
    capability: capability,
    lastVerified: DateTime.utc(2026, 8, 1),
    isBuiltIn: true,
  );
}

ProviderContainer _container({
  required List<DiveSummary> summaries,
  List<EmergencyChamber> userChambers = const [],
  MockSettingsNotifier? settings,
  Diver? diver,
}) {
  final container = ProviderContainer(
    overrides: [
      diveRepositoryProvider.overrideWithValue(_FakeDiveRepository(summaries)),
      emergencyChamberRepositoryProvider.overrideWithValue(
        _FakeChamberRepo(userChambers),
      ),
      settingsProvider.overrideWith(
        (ref) => settings ?? MockSettingsNotifier(),
      ),
      validatedCurrentDiverIdProvider.overrideWith((ref) async => 'diver-1'),
      currentDiverProvider.overrideWith((ref) async => diver),
    ],
  );
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(EmergencyDataService.resetCacheForTesting);

  test('manual region override is normalized to upper-case ISO', () async {
    final settings = MockSettingsNotifier();
    await settings.setEmergencyRegion('us');

    final container = _container(summaries: const [], settings: settings);
    addTearDown(container.dispose);

    expect(await container.read(emergencyRegionProvider.future), 'US');

    final data = await container.read(emergencyCardDataProvider.future);
    expect(data.countryCode, 'US');
    // US hotline + EMS resolved from the bundled dataset.
    expect(data.hotline.countries, contains('US'));
    expect(data.emsNumber, '911');
  });

  test('region derives from the most recent dive site country', () async {
    final container = _container(summaries: [_summary(country: 'Germany')]);
    addTearDown(container.dispose);

    expect(await container.read(emergencyRegionProvider.future), 'DE');
    final data = await container.read(emergencyCardDataProvider.future);
    expect(data.countryCode, 'DE');
  });

  test('region resolves localized country names from geocoding', () async {
    // Platform geocoding returns Placemark.country in the device language.
    for (final entry in {
      'Deutschland': 'DE',
      'España': 'ES',
      'Égypte': 'EG',
      'Türkei': 'TR',
    }.entries) {
      final container = _container(summaries: [_summary(country: entry.key)]);
      addTearDown(container.dispose);
      expect(
        await container.read(emergencyRegionProvider.future),
        entry.value,
        reason: entry.key,
      );
    }
  });

  test('no dives resolves to the worldwide hotline and default EMS', () async {
    final container = _container(summaries: const []);
    addTearDown(container.dispose);

    expect(await container.read(emergencyRegionProvider.future), isNull);
    final data = await container.read(emergencyCardDataProvider.future);
    expect(data.countryCode, isNull);
    expect(data.hotline.countries, isEmpty); // worldwide fallback
    expect(data.emsNumber, '112'); // default EMS
  });

  test('chambers are distance-sorted when the last dive has GPS', () async {
    // Dive near chamber "near" (0,0); chamber "far" is at (10,10).
    final container = _container(
      summaries: [_summary(country: 'Germany', lat: 0.1, lon: 0.1)],
      userChambers: [
        _chamber('far', 'DE', lat: 10, lon: 10),
        _chamber('near', 'DE', lat: 0, lon: 0),
      ],
    );
    addTearDown(container.dispose);

    final data = await container.read(emergencyCardDataProvider.future);
    final userIds = data.nearbyChambers
        .map((l) => l.chamber.id)
        .where((id) => id == 'near' || id == 'far')
        .toList();
    expect(userIds, ['near', 'far']);
  });

  test('without GPS, same-country chambers sort first', () async {
    final container = _container(
      summaries: [_summary(country: 'Germany')], // -> DE, no GPS
      userChambers: [_chamber('other', 'FR'), _chamber('home', 'DE')],
    );
    addTearDown(container.dispose);

    final listings = await container.read(chamberListingsProvider.future);
    final ids = listings
        .map((l) => l.chamber.id)
        .where((id) => id == 'home' || id == 'other')
        .toList();
    expect(ids.first, 'home');
  });

  test('hidden bundled chambers are filtered out', () async {
    final container0 = _container(summaries: const []);
    addTearDown(container0.dispose);
    final all = await container0.read(chamberListingsProvider.future);
    final bundledId = all.firstWhere((l) => l.chamber.isBuiltIn).chamber.id;

    final settings = MockSettingsNotifier();
    await settings.setChamberHidden(bundledId, true);
    final container = _container(summaries: const [], settings: settings);
    addTearDown(container.dispose);

    final listings = await container.read(chamberListingsProvider.future);
    expect(listings.where((l) => l.chamber.id == bundledId), isEmpty);
  });

  group('chamber ordering', () {
    test(
      'an elective clinic never outranks a dive chamber, however close',
      () async {
        // Sydney Harbour. The elective clinic is next door, the dive chamber
        // is a couple of hundred kilometres up the coast.
        EmergencyDataService.setBundledChambersForTesting([
          _bundled(
            id: 'elective-near',
            capability: ChamberCapability.elective,
            lat: -33.86,
            lon: 151.21,
          ),
          _bundled(
            id: 'dive-far',
            capability: ChamberCapability.divingEmergency,
            lat: -32.0,
            lon: 150.0,
          ),
        ]);
        final container = _container(
          summaries: [_summary(country: 'Australia', lat: -33.85, lon: 151.21)],
        );
        addTearDown(container.dispose);

        final listings = await container.read(chamberListingsProvider.future);
        final order = listings.map((l) => l.chamber.id).toList();

        expect(
          order.indexOf('dive-far'),
          lessThan(order.indexOf('elective-near')),
        );
      },
    );

    test('user chambers stay at the top', () async {
      // The bundled chamber is on the dive site; the diver's own entry is on
      // the other side of the planet. Theirs still leads.
      EmergencyDataService.setBundledChambersForTesting([
        _bundled(id: 'bundled-near', lat: -33.85, lon: 151.21),
      ]);
      final container = _container(
        summaries: [_summary(country: 'Australia', lat: -33.85, lon: 151.21)],
        userChambers: [_chamber('mine', 'AU', lat: 40.0, lon: -74.0)],
      );
      addTearDown(container.dispose);

      final listings = await container.read(chamberListingsProvider.future);
      expect(listings.first.chamber.id, 'mine');
    });

    test('within a band, the nearer chamber wins', () async {
      EmergencyDataService.setBundledChambersForTesting([
        _bundled(id: 'far', lat: -32.0, lon: 150.0),
        _bundled(id: 'near', lat: -33.85, lon: 151.2),
      ]);
      final container = _container(
        summaries: [_summary(country: 'Australia', lat: -33.85, lon: 151.21)],
      );
      addTearDown(container.dispose);

      final listings = await container.read(chamberListingsProvider.future);
      expect(listings.map((l) => l.chamber.id).toList(), ['near', 'far']);
    });

    test('chambers without coordinates sort last within their band', () async {
      EmergencyDataService.setBundledChambersForTesting([
        _bundled(id: 'nowhere'),
        _bundled(id: 'somewhere', lat: -33.85, lon: 151.21),
      ]);
      final container = _container(
        summaries: [_summary(country: 'Australia', lat: -33.85, lon: 151.21)],
      );
      addTearDown(container.dispose);

      final listings = await container.read(chamberListingsProvider.future);
      expect(listings.map((l) => l.chamber.id).toList(), [
        'somewhere',
        'nowhere',
      ]);
    });
  });

  group('card selection', () {
    test('the card shows at most five chambers', () async {
      EmergencyDataService.setBundledChambersForTesting([
        for (var i = 0; i < 8; i++)
          _bundled(id: 'c$i', lat: -33.85 + i * 0.01, lon: 151.21),
      ]);
      final container = _container(
        summaries: [_summary(country: 'Australia', lat: -33.85, lon: 151.21)],
      );
      addTearDown(container.dispose);

      final data = await container.read(emergencyCardDataProvider.future);
      expect(data.nearbyChambers, hasLength(chamberCardLimit));
      expect(data.totalChamberCount, 8);
    });

    test('chambers beyond 500 km are left off the card', () async {
      // Sydney dive, chamber in Perth.
      EmergencyDataService.setBundledChambersForTesting([
        _bundled(id: 'perth', lat: -31.95, lon: 115.86),
      ]);
      final container = _container(
        summaries: [_summary(country: 'Australia', lat: -33.85, lon: 151.21)],
      );
      addTearDown(container.dispose);

      final data = await container.read(emergencyCardDataProvider.future);
      expect(data.nearbyChambers, isEmpty);
      expect(data.totalChamberCount, 1);
    });

    test('without GPS, the card falls back to same-country chambers', () async {
      EmergencyDataService.setBundledChambersForTesting([
        _bundled(id: 'german', country: 'DE'),
        _bundled(id: 'french', country: 'FR'),
      ]);
      final container = _container(
        summaries: [_summary(country: 'Germany')], // -> DE, no GPS
      );
      addTearDown(container.dispose);

      final data = await container.read(emergencyCardDataProvider.future);
      expect(data.nearbyChambers.map((l) => l.chamber.id).toList(), ['german']);
    });

    test('the full directory keeps every chamber the card omits', () async {
      EmergencyDataService.setBundledChambersForTesting([
        _bundled(id: 'perth', lat: -31.95, lon: 115.86),
        _bundled(id: 'sydney', lat: -33.86, lon: 151.21),
      ]);
      final container = _container(
        summaries: [_summary(country: 'Australia', lat: -33.85, lon: 151.21)],
      );
      addTearDown(container.dispose);

      final data = await container.read(emergencyCardDataProvider.future);
      final listings = await container.read(chamberListingsProvider.future);

      expect(data.nearbyChambers.map((l) => l.chamber.id).toList(), ['sydney']);
      expect(listings.map((l) => l.chamber.id).toList(), ['sydney', 'perth']);
    });
  });

  test('the diver id scopes chamber and dive lookups', () async {
    final diver = Diver(
      id: 'diver-1',
      name: 'Test',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    final container = _container(summaries: const [], diver: diver);
    addTearDown(container.dispose);

    final data = await container.read(emergencyCardDataProvider.future);
    expect(data.diver, diver);
  });
}
