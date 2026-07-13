import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/database/database.dart'
    hide EquipmentSet, DiveSite;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_set_edit_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  setUp(() async {
    await setUpTestDatabase();
    final db = DatabaseService.instance.database;
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'd1',
            name: 'd1',
            createdAt: t,
            updatedAt: t,
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  Future<Widget> buildPage({String? setId}) async {
    final overrides = await getBaseOverrides();
    overrides.addAll([
      validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd1'),
      activeEquipmentProvider.overrideWith((ref) async => <EquipmentItem>[]),
      sitesProvider.overrideWith(
        (ref) async => const [
          DiveSite(
            id: 'site-1',
            name: 'Breakwater',
            location: GeoPoint(36.62, -121.90),
          ),
        ],
      ),
    ]);

    final router = GoRouter(
      initialLocation: '/home/edit',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('home')),
          routes: [
            GoRoute(
              path: 'edit',
              builder: (_, _) => EquipmentSetEditPage(setId: setId),
            ),
          ],
        ),
      ],
    );

    return ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }

  Future<void> addGeofenceViaSheet(WidgetTester tester) async {
    await tester.tap(find.text('Add geofence'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('From dive site'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Breakwater').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save geofence'));
    await tester.pumpAndSettle();
  }

  testWidgets('toggles default and manages geofences before saving', (
    tester,
  ) async {
    await tester.pumpWidget(await buildPage());
    await tester.pumpAndSettle();

    // Name the set.
    await tester.enterText(find.byType(TextFormField).first, 'Cold Water');

    // Toggle the Default switch on.
    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );

    // Add a geofence via the editor sheet, then confirm the row rendered.
    await addGeofenceViaSheet(tester);
    expect(find.text('Breakwater'), findsOneWidget);

    // Tapping the row re-opens the editor seeded with the fence (edit action).
    await tester.tap(find.text('Breakwater'));
    await tester.pumpAndSettle();
    expect(find.text('Save geofence'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Save geofence'));
    await tester.pumpAndSettle();
    expect(find.text('Breakwater'), findsOneWidget);

    // Remove the geofence.
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(find.text('Breakwater'), findsNothing);
  });

  testWidgets('saving a new default set with a geofence persists both', (
    tester,
  ) async {
    await tester.pumpWidget(await buildPage());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Cold Water');
    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();
    await addGeofenceViaSheet(tester);

    // Save; the button sits below the fold of a lazily-built ListView, so
    // scroll it into existence before tapping. The form pops home on success.
    await tester.scrollUntilVisible(
      find.widgetWithText(FilledButton, 'Create Set'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create Set'));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);

    final repo = EquipmentSetRepository();
    final sets = await repo.getAllSets(diverId: 'd1');
    expect(sets, hasLength(1));
    expect(sets.first.isDefault, isTrue);
    expect(await repo.getGeofencesForSet(sets.first.id), hasLength(1));
  });
}
