import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/location_service_provider.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/location_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/bulk_field_gate.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart'
    as site_domain;
import 'package:submersion/features/dive_sites/presentation/providers/site_catalogue_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_picker/catalogue_site_tile.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/fake_site_catalogue.dart';
import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

class _NoFixLocationService implements LocationService {
  int calls = 0;

  @override
  Future<LocationResult?> getCurrentLocation({
    bool includeGeocoding = true,
    Duration timeout = const Duration(seconds: 15),
    String languageCode = LocationService.defaultLanguageCode,
  }) async {
    calls++;
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Salt Pier, the site the diver already named on the trip's first dive.
const _saltPier = site_domain.DiveSite(
  id: 'salt-pier',
  name: 'Salt Pier',
  location: site_domain.GeoPoint(12.0836, -68.2820),
  island: 'Bonaire',
);

/// The dive edit page hands the site picker the area of the dives being
/// edited, taken from the dives around them: a diver naming a trip's sites
/// sees that area's built-in sites without typing.
void main() {
  late DiveRepository repository;
  late AppDatabase db;
  late FakeSiteCatalogue catalogue;
  late _NoFixLocationService location;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
    location = _NoFixLocationService();
    catalogue = FakeSiteCatalogue(const [
      CatalogueSite(
        id: 'c1',
        name: 'Angel City',
        location: site_domain.GeoPoint(12.10, -68.28),
        island: 'Bonaire',
        source: 'osm',
      ),
      CatalogueSite(
        id: 'c2',
        name: 'Blue Hole',
        location: site_domain.GeoPoint(28.57, 34.54),
        country: 'Egypt',
        source: 'osm',
      ),
    ]);
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion(
            id: const Value('salt-pier'),
            name: const Value('Salt Pier'),
            latitude: const Value(12.0836),
            longitude: const Value(-68.2820),
            island: const Value('Bonaire'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    // The trip's first dive, already named, and two more not yet named.
    await repository.createDive(
      domain.Dive(
        id: 'named',
        dateTime: DateTime.utc(2026, 11, 2, 9),
        notes: '',
        site: _saltPier,
      ),
    );
    await repository.createDive(
      domain.Dive(id: 'd1', dateTime: DateTime.utc(2026, 11, 2, 14), notes: ''),
    );
    await repository.createDive(
      domain.Dive(id: 'd2', dateTime: DateTime.utc(2026, 11, 3, 9), notes: ''),
    );
  });
  tearDown(() async => tearDownTestDatabase());

  Future<void> pumpBulk(WidgetTester tester) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          diveRepositoryProvider.overrideWithValue(repository),
          diveListNotifierProvider.overrideWith(
            (ref) => DiveListNotifier(repository, ref),
          ),
          customTankPresetsProvider.overrideWith((ref) async => []),
          locationServiceProvider.overrideWithValue(location),
          sitesProvider.overrideWith((ref) async => [_saltPier]),
          siteCatalogueProvider.overrideWithValue(catalogue),
        ].cast(),
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DiveEditPage(bulkDiveIds: ['d1', 'd2'], embedded: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder siteGate() => find.ancestor(
    of: find.text('Site'),
    matching: find.byType(BulkFieldGate),
  );

  Future<void> enableSiteGate(WidgetTester tester) async {
    await tester.tap(
      find.descendant(of: siteGate(), matching: find.byType(Checkbox)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the picker opens on the area of the dives being edited', (
    tester,
  ) async {
    await pumpBulk(tester);
    await enableSiteGate(tester);

    await tester.tap(find.text('Site'));
    await tester.pumpAndSettle();

    // Named after the neighbouring dive's site, with that area's built-in
    // site and not the one in Egypt.
    expect(find.text('More sites near Bonaire'), findsOneWidget);
    expect(find.text('Angel City'), findsOneWidget);
    expect(find.text('Blue Hole'), findsNothing);
    expect(find.byType(CatalogueSiteTile), findsOneWidget);
    // The area came from the logbook: the device was not asked where it is.
    expect(location.calls, 0);
  });

  testWidgets('tapping Site twice opens one picker', (tester) async {
    await pumpBulk(tester);
    await enableSiteGate(tester);

    // The second tap lands while the area is still being worked out.
    await tester.tap(find.text('Site'));
    await tester.tap(find.text('Site'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Select Dive Site'), findsOneWidget);
  });

  testWidgets('with no named dive nearby the picker opens as before', (
    tester,
  ) async {
    await db.delete(db.dives).go();
    await repository.createDive(
      domain.Dive(id: 'd1', dateTime: DateTime.utc(2026, 11, 2, 14), notes: ''),
    );
    await repository.createDive(
      domain.Dive(id: 'd2', dateTime: DateTime.utc(2026, 11, 3, 9), notes: ''),
    );
    await pumpBulk(tester);
    await enableSiteGate(tester);

    await tester.tap(find.text('Site'));
    await tester.pumpAndSettle();

    expect(find.text('Select Dive Site'), findsOneWidget);
    expect(find.textContaining('More sites'), findsNothing);
    // Their own site is listed as ever.
    expect(find.text('Salt Pier'), findsWidgets);
  });
}
