import 'dart:async';

import 'package:submersion/core/providers/provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/location_service_provider.dart';
import 'package:submersion/core/services/geocoding/place_lookup.dart';
import 'package:submersion/core/services/location_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/services/site_location_backfill_service.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_location_backfill_provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// Blocks each lookup until [release] is called, so a test can observe the
/// running state and cancel mid-run.
class _GatedLocationService implements LocationService {
  final List<Completer<void>> gates = [];
  final List<String> languages = [];

  void release() => gates.removeAt(0).complete();

  @override
  Future<PlaceLookup> reverseGeocode(
    double latitude,
    double longitude, {
    required String languageCode,
  }) async {
    languages.add(languageCode);
    final gate = Completer<void>();
    gates.add(gate);
    await gate.future;
    return const PlaceLookup(country: 'Switzerland', locality: 'Weggis');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Settings pinned to German place names, without a database round-trip.
class _GermanSettings extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _GermanSettings() : super(const AppSettings(placeNameLanguage: 'de'));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late ProviderContainer container;
  late SiteRepository sites;
  late _GatedLocationService location;

  Future<void> tick() => Future<void>.delayed(Duration.zero);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
    sites = SiteRepository();
    location = _GatedLocationService();
    container = ProviderContainer(
      overrides: [
        siteRepositoryProvider.overrideWithValue(sites),
        sharedPreferencesProvider.overrideWithValue(prefs),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
        locationServiceProvider.overrideWithValue(location),
        settingsProvider.overrideWith((_) => _GermanSettings()),
      ],
    );
    await sites.createSite(
      const DiveSite(id: 'a', name: 'A', location: GeoPoint(47.0, 8.4)),
    );
    await sites.createSite(
      const DiveSite(id: 'b', name: 'B', location: GeoPoint(47.1, 8.5)),
    );
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  Future<void> runToCompletion(Future<void> run) async {
    while (location.gates.isEmpty) {
      await tick();
    }
    location.release();
    await tick();
    while (location.gates.isEmpty) {
      await tick();
    }
    location.release();
    await run;
  }

  test('starts idle and counts candidates', () async {
    expect(container.read(siteLocationBackfillProvider), isA<BackfillIdle>());
    final notifier = container.read(siteLocationBackfillProvider.notifier);
    final found = await notifier.findCandidates(
      SiteLocationLookupMode.fillMissing,
    );
    expect(found, hasLength(2));
  });

  test('reports progress while running and finishes with a summary', () async {
    final notifier = container.read(siteLocationBackfillProvider.notifier);
    final run = notifier.start(SiteLocationLookupMode.fillMissing);
    while (location.gates.isEmpty) {
      await tick();
    }

    expect(
      container.read(siteLocationBackfillProvider),
      isA<BackfillRunning>()
          .having((s) => s.done, 'done', 0)
          .having((s) => s.total, 'total', 2),
    );

    location.release();
    while (location.gates.isEmpty) {
      await tick();
    }
    expect(
      container.read(siteLocationBackfillProvider),
      isA<BackfillRunning>().having((s) => s.done, 'done', 1),
    );
    location.release();
    await run;

    final state = container.read(siteLocationBackfillProvider);
    expect(state, isA<BackfillFinished>());
    expect((state as BackfillFinished).summary.updated, 2);
    expect((await sites.getSiteById('a'))!.city, 'Weggis');
  });

  test('a second start while running is a no-op', () async {
    final notifier = container.read(siteLocationBackfillProvider.notifier);
    final first = notifier.start(SiteLocationLookupMode.fillMissing);
    while (location.gates.isEmpty) {
      await tick();
    }
    await notifier.start(SiteLocationLookupMode.fillMissing);
    expect(location.gates, hasLength(1), reason: 'no second run began');

    location.release();
    while (location.gates.isEmpty) {
      await tick();
    }
    location.release();
    await first;
  });

  test('cancel stops after the current site', () async {
    final notifier = container.read(siteLocationBackfillProvider.notifier);
    final run = notifier.start(SiteLocationLookupMode.fillMissing);
    while (location.gates.isEmpty) {
      await tick();
    }

    notifier.cancel();
    location.release();
    await run;

    final state = container.read(siteLocationBackfillProvider);
    expect((state as BackfillFinished).summary.cancelled, isTrue);
    expect(location.gates, isEmpty);
  });

  test('reset returns to idle', () async {
    final notifier = container.read(siteLocationBackfillProvider.notifier);
    await runToCompletion(notifier.start(SiteLocationLookupMode.fillMissing));

    notifier.reset();
    expect(container.read(siteLocationBackfillProvider), isA<BackfillIdle>());
  });

  test('looks up in the place name language', () async {
    final notifier = container.read(siteLocationBackfillProvider.notifier);
    await runToCompletion(notifier.start(SiteLocationLookupMode.fillMissing));
    expect(location.languages, ['de', 'de']);
  });

  test('a refresh run counts sites a fill run would skip', () async {
    await sites.createSite(
      const DiveSite(
        id: 'c',
        name: 'C',
        country: 'Schweiz',
        region: 'Luzern',
        city: 'Weggis',
        bodyOfWater: 'Vierwaldstattersee',
        location: GeoPoint(47.2, 8.6),
      ),
    );
    final notifier = container.read(siteLocationBackfillProvider.notifier);

    final filling = await notifier.findCandidates(
      SiteLocationLookupMode.fillMissing,
    );
    final refreshing = await notifier.findCandidates(
      SiteLocationLookupMode.refreshAll,
    );

    expect(filling, hasLength(2));
    expect(refreshing, hasLength(3));
  });

  test('a started run looks up only the candidates it was handed', () async {
    final notifier = container.read(siteLocationBackfillProvider.notifier);
    final candidates = await notifier.findCandidates(
      SiteLocationLookupMode.fillMissing,
    );
    // A site added between listing and starting is not part of this run.
    await sites.createSite(
      const DiveSite(id: 'c', name: 'C', location: GeoPoint(47.2, 8.6)),
    );

    final run = notifier.start(
      SiteLocationLookupMode.fillMissing,
      targets: candidates,
    );
    while (location.gates.isEmpty) {
      await tick();
    }
    expect(
      container.read(siteLocationBackfillProvider),
      isA<BackfillRunning>().having((s) => s.total, 'total', 2),
    );

    await runToCompletion(run);
    final state = container.read(siteLocationBackfillProvider);
    expect((state as BackfillFinished).summary.total, 2);
    expect((await sites.getSiteById('c'))!.city, isNull);
  });

  test('the running state carries the mode it was started with', () async {
    final notifier = container.read(siteLocationBackfillProvider.notifier);
    final run = notifier.start(SiteLocationLookupMode.refreshAll);
    while (location.gates.isEmpty) {
      await tick();
    }
    expect(
      container.read(siteLocationBackfillProvider),
      isA<BackfillRunning>().having(
        (s) => s.mode,
        'mode',
        SiteLocationLookupMode.refreshAll,
      ),
    );
    await runToCompletion(run);
  });
}
