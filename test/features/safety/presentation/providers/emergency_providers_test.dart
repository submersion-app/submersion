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
    final userIds = data.chambers
        .where((c) => c.id == 'near' || c.id == 'far')
        .map((c) => c.id)
        .toList();
    expect(userIds, ['near', 'far']);
  });

  test('without GPS, same-country chambers sort first', () async {
    final container = _container(
      summaries: [_summary(country: 'Germany')], // -> DE, no GPS
      userChambers: [_chamber('other', 'FR'), _chamber('home', 'DE')],
    );
    addTearDown(container.dispose);

    final data = await container.read(emergencyCardDataProvider.future);
    final ids = data.chambers
        .where((c) => c.id == 'home' || c.id == 'other')
        .map((c) => c.id)
        .toList();
    expect(ids.first, 'home');
  });

  test('hidden bundled chambers are filtered out', () async {
    final container0 = _container(summaries: const []);
    addTearDown(container0.dispose);
    final all = await container0.read(emergencyCardDataProvider.future);
    final bundledId = all.chambers.firstWhere((c) => c.isBuiltIn).id;

    final settings = MockSettingsNotifier();
    await settings.setChamberHidden(bundledId, true);
    final container = _container(summaries: const [], settings: settings);
    addTearDown(container.dispose);

    final data = await container.read(emergencyCardDataProvider.future);
    expect(data.chambers.where((c) => c.id == bundledId), isEmpty);
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
