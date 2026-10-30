import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
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
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart'
    as site_domain;
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Device GPS that never has a fix, so the site picker never reaches the real
/// Geolocator platform channel.
class _NoFixLocationService implements LocationService {
  @override
  Future<LocationResult?> getCurrentLocation({
    bool includeGeocoding = true,
    Duration timeout = const Duration(seconds: 15),
    String languageCode = LocationService.defaultLanguageCode,
  }) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _reef = site_domain.DiveSite(
  id: 's1',
  name: 'House Reef',
  waterType: WaterType.salt,
);

/// The bulk edit Site row (issue #3657).
void main() {
  late DiveRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion(
            id: const Value('s1'),
            name: const Value('House Reef'),
            waterType: const Value('salt'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
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
          locationServiceProvider.overrideWithValue(_NoFixLocationService()),
          sitesProvider.overrideWith((ref) async => [_reef]),
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

  Future<void> saveAndApply(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
  }

  testWidgets('Site is the first Logistics row, gated and not set', (
    tester,
  ) async {
    await pumpBulk(tester);

    expect(siteGate(), findsOneWidget);
    expect(
      tester.getTopLeft(siteGate()).dy,
      lessThan(
        tester
            .getTopLeft(
              find.ancestor(
                of: find.text('Dive center'),
                matching: find.byType(BulkFieldGate),
              ),
            )
            .dy,
      ),
    );
    expect(
      find.descendant(of: siteGate(), matching: find.text('Not set')),
      findsOneWidget,
    );
  });

  testWidgets('a picked site lands on every dive with its water type', (
    tester,
  ) async {
    await repository.createDive(
      domain.Dive(id: 'd1', dateTime: DateTime(2026, 1, 1), notes: ''),
    );
    await repository.createDive(
      domain.Dive(
        id: 'd2',
        dateTime: DateTime(2026, 1, 2),
        notes: '',
        waterType: WaterType.fresh,
      ),
    );
    await pumpBulk(tester);

    await enableSiteGate(tester);
    await tester.tap(find.text('Site'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('House Reef'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: siteGate(), matching: find.text('House Reef')),
      findsOneWidget,
    );

    await saveAndApply(tester);

    for (final id in ['d1', 'd2']) {
      final dive = (await repository.getDiveById(id))!;
      expect(dive.site?.id, 's1');
      expect(dive.waterType, WaterType.salt);
    }
  });

  testWidgets('picking a site leaves the Water Type row as it was', (
    tester,
  ) async {
    await pumpBulk(tester);

    await enableSiteGate(tester);
    await tester.tap(find.text('Site'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('House Reef'));
    await tester.pumpAndSettle();

    // The form's water type is the bulk row's own value; the site's water
    // type reaches each dive through the service, not through this row.
    expect(find.text('Not specified'), findsWidgets);
    expect(find.text('Salt'), findsNothing);
  });

  testWidgets('an enabled Site left empty unlinks every dive', (tester) async {
    await repository.createDive(
      domain.Dive(
        id: 'd1',
        dateTime: DateTime(2026, 1, 1),
        notes: '',
        site: _reef,
        waterType: WaterType.salt,
      ),
    );
    await repository.createDive(
      domain.Dive(
        id: 'd2',
        dateTime: DateTime(2026, 1, 2),
        notes: '',
        site: _reef,
      ),
    );
    await pumpBulk(tester);

    await enableSiteGate(tester);
    await saveAndApply(tester);

    final d1 = (await repository.getDiveById('d1'))!;
    expect(d1.site, isNull);
    expect(d1.waterType, WaterType.salt);
    expect((await repository.getDiveById('d2'))!.site, isNull);
  });

  testWidgets('clearing a picked site unlinks every dive on apply', (
    tester,
  ) async {
    for (final id in ['d1', 'd2']) {
      await repository.createDive(
        domain.Dive(
          id: id,
          dateTime: DateTime(2026, 1, 1),
          notes: '',
          site: _reef,
        ),
      );
    }
    await pumpBulk(tester);

    await enableSiteGate(tester);
    await tester.tap(find.text('Site'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('House Reef'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: siteGate(), matching: find.byIcon(Icons.clear)),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: siteGate(), matching: find.text('Not set')),
      findsOneWidget,
    );

    await saveAndApply(tester);

    expect((await repository.getDiveById('d1'))!.site, isNull);
    expect((await repository.getDiveById('d2'))!.site, isNull);
  });

  testWidgets('a picked site with its gate off writes nothing', (tester) async {
    await repository.createDive(
      domain.Dive(id: 'd1', dateTime: DateTime(2026, 1, 1), notes: ''),
    );
    await repository.createDive(
      domain.Dive(id: 'd2', dateTime: DateTime(2026, 1, 2), notes: ''),
    );
    await pumpBulk(tester);

    await enableSiteGate(tester);
    await tester.tap(find.text('Site'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('House Reef'));
    await tester.pumpAndSettle();
    await enableSiteGate(tester); // tick it off again

    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Nothing is enabled, so the hint shows instead of the confirm dialog.
    expect(find.text('Apply'), findsNothing);
    expect((await repository.getDiveById('d1'))!.site, isNull);
  });
}
