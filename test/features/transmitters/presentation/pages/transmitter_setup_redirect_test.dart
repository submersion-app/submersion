import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/dive_computer_gear_identity.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/transmitters/data/services/transmitter_auto_registrar.dart';
import 'package:submersion/features/transmitters/presentation/pages/transmitter_setup_redirect.dart';
import 'package:submersion/features/transmitters/presentation/providers/transmitter_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_database.dart';

/// `/transmitters/new?serial=` (the cylinders card's Assign chip, and old
/// links) opens the transmitter's item, keeping the serial (review).
void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  Future<void> pumpAt(WidgetTester tester, String location) async {
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: '/equipment/new',
          builder: (_, s) => Scaffold(
            body: Text(
              'NEW ${s.uri.queryParameters['type']} '
              '${s.uri.queryParameters['serial']}',
            ),
          ),
        ),
        GoRoute(
          path: '/equipment/:id',
          builder: (_, s) =>
              Scaffold(body: Text('ITEM ${s.pathParameters['id']}')),
        ),
        GoRoute(
          path: '/transmitters/new',
          builder: (_, s) => TransmitterSetupRedirect(
            serial: s.uri.queryParameters['serial'],
            diveId: s.uri.queryParameters['dive'],
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
          transmitterAutoRegistrarProvider.overrideWithValue(
            TransmitterAutoRegistrar(nameFor: (serial) => 'Tx $serial'),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> seedDiveCarrying(String serial) async {
    final db = DatabaseService.instance.database;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'dive1',
            diveDateTime: 0,
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(
            id: 'tank1',
            diveId: 'dive1',
            transmitterSerial: Value(serial),
          ),
        );
  }

  testWidgets("a serial on a dive opens its transmitter's item, registering "
      'it first when no entry knows it', (tester) async {
    await tester.runAsync(() => seedDiveCarrying('4A21F'));

    await pumpAt(tester, '/transmitters/new?serial=4A21F&dive=dive1');

    expect(
      find.text('ITEM ${transmitterGearSeedId(null, '4A21F')}'),
      findsOneWidget,
    );
  });

  testWidgets('a serial no entry knows, with no dive, starts a Transmitter '
      'item carrying it', (tester) async {
    await pumpAt(tester, '/transmitters/new?serial=4A21F');

    expect(find.text('NEW transmitter 4A21F'), findsOneWidget);
  });

  testWidgets('a dive that is gone still finds the entry by its serial', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final db = DatabaseService.instance.database;
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: 'tx-gear',
              name: 'Back gas tx',
              type: 'transmitter',
              createdAt: 0,
              updatedAt: 0,
            ),
          );
      await db
          .into(db.transmitters)
          .insert(
            TransmittersCompanion.insert(
              id: 'tx1',
              label: 'Back gas tx',
              tankRole: 'backGas',
              transmitterSerial: const Value('4A21F'),
              transmitterEquipmentId: const Value('tx-gear'),
              createdAt: 0,
              updatedAt: 0,
            ),
          );
    });

    await pumpAt(tester, '/transmitters/new?serial=4A21F&dive=gone');

    expect(find.text('ITEM tx-gear'), findsOneWidget);
  });
}
