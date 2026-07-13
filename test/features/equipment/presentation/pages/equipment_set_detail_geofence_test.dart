import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/database/database.dart'
    hide EquipmentSet, EquipmentSetGeofence;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set_geofence.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_set_detail_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Detail-page coverage backed by a real database so the "Set as default"
/// menu action drives the notifier, and so the geofence section renders live
/// rows rather than an override stub.
void main() {
  late EquipmentSetRepository repo;

  setUp(() async {
    await setUpTestDatabase();
    repo = EquipmentSetRepository();
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
    await repo.createSet(
      EquipmentSet(
        id: 'a',
        diverId: 'd1',
        name: 'Cold Water',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  });
  tearDown(tearDownTestDatabase);

  Future<Widget> page() async {
    final overrides = await getBaseOverrides();
    overrides.add(
      validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd1'),
    );
    final router = GoRouter(
      initialLocation: '/detail',
      routes: [
        GoRoute(
          path: '/detail',
          builder: (_, _) => const EquipmentSetDetailPage(setId: 'a'),
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

  testWidgets('renders live geofence rows for the set', (tester) async {
    await repo.addGeofence(
      EquipmentSetGeofence(
        id: 'g1',
        setId: 'a',
        label: 'Monterey',
        latitude: 36.62,
        longitude: -121.9,
        radiusMeters: 20000,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    await tester.pumpWidget(await page());
    await tester.pumpAndSettle();

    expect(find.text('Monterey'), findsOneWidget);
  });

  testWidgets('"Set as default" action promotes the set', (tester) async {
    await tester.pumpWidget(await page());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Set as default'));
    await tester.pumpAndSettle();

    expect((await repo.getSetById('a'))!.isDefault, isTrue);
  });
}
