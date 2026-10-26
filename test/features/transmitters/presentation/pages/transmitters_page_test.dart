import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';
import 'package:submersion/features/transmitters/presentation/pages/transmitters_page.dart';
import 'package:submersion/features/transmitters/presentation/widgets/transmitter_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The Transmitters list shows Transmitter Equipment items (issue #3676).
Future<void> _seed() async {
  final db = DatabaseService.instance.database;
  await db.customStatement(
    "INSERT INTO divers (id, name, created_at, updated_at) "
    "VALUES ('diver-1', 'A', 1, 1)",
  );
  await db.customStatement(
    "INSERT INTO dives (id, diver_id, dive_date_time, created_at, updated_at) "
    "VALUES ('d1', 'diver-1', 1, 1, 1)",
  );
  await db.customStatement(
    "INSERT INTO dive_tanks (id, dive_id, transmitter_serial, tank_order) "
    "VALUES ('k1', 'd1', '555', 0)",
  );
  await db.customStatement(
    "INSERT INTO equipment (id, diver_id, name, type, created_at, updated_at) "
    "VALUES ('o2-gear', 'diver-1', 'O2 bottle tx', 'transmitter', 1, 1), "
    "('new-gear', 'diver-1', 'Transmitter 555', 'transmitter', 1, 1)",
  );
}

Widget _buildPage(
  MockCurrentDiverIdNotifier diverIdNotifier,
  SharedPreferences prefs,
) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const TransmittersPage()),
      GoRoute(
        path: '/equipment/new',
        builder: (context, state) =>
            Scaffold(body: Text('NEW ${state.uri.queryParameters['type']}')),
      ),
      GoRoute(
        path: '/equipment/:id',
        builder: (context, state) => Scaffold(
          body: SingleChildScrollView(
            child: TransmitterSection(equipmentId: state.pathParameters['id']!),
          ),
        ),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      currentDiverIdProvider.overrideWith((ref) => diverIdNotifier),
      validatedCurrentDiverIdProvider.overrideWith((ref) async => 'diver-1'),
    ].cast(),
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      routerConfig: router,
    ),
  );
}

void main() {
  late MockCurrentDiverIdNotifier diverIdNotifier;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
    await _seed();
    diverIdNotifier = MockCurrentDiverIdNotifier();
    await diverIdNotifier.setCurrentDiver('diver-1');
    await TransmitterRepository().create(
      Transmitter(
        id: 'e1',
        diverId: 'diver-1',
        transmitterSerial: '180777',
        label: 'O2 bottle tx',
        role: TankRole.oxygenSupply,
        volumeL: 2.0,
        workingPressureBar: 232,
        transmitterEquipmentId: 'o2-gear',
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: DateTime.utc(2026, 9, 1),
      ),
    );
    await TransmitterRepository().create(
      Transmitter(
        id: 'e2',
        diverId: 'diver-1',
        transmitterSerial: '555',
        label: 'Transmitter 555',
        transmitterEquipmentId: 'new-gear',
        isConfigured: false,
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: DateTime.utc(2026, 9, 1),
      ),
    );
  });
  tearDown(tearDownTestDatabase);

  testWidgets('lists each transmitter item with its key and setup in the '
      'diver units', (tester) async {
    await tester.pumpWidget(_buildPage(diverIdNotifier, prefs));
    await tester.pumpAndSettle();

    expect(find.text('O2 bottle tx'), findsOneWidget);
    expect(find.textContaining('Transmitter 180777'), findsOneWidget);
    expect(find.textContaining('232 bar'), findsOneWidget);
    // The download-created one is listed too, asking for its cylinder.
    expect(find.text('Transmitter 555'), findsWidgets);
    expect(find.text('No cylinder set up'), findsOneWidget);
    expect(find.text('Seen in downloads, not assigned'), findsNothing);
  });

  testWidgets('a retired transmitter item says so (review)', (tester) async {
    await DatabaseService.instance.database.customStatement(
      "UPDATE equipment SET status = 'retired', is_active = 0 "
      "WHERE id = 'o2-gear'",
    );
    await tester.pumpWidget(_buildPage(diverIdNotifier, prefs));
    await tester.pumpAndSettle();

    expect(find.text('Retired'), findsOneWidget);
  });

  testWidgets('a hand-added transmitter with no key asks for one, not for a '
      'cylinder (review)', (tester) async {
    await DatabaseService.instance.database.customStatement(
      "INSERT INTO equipment (id, diver_id, name, type, created_at, "
      "updated_at) VALUES ('bare-gear', 'diver-1', 'Spare tx', "
      "'transmitter', 1, 1)",
    );
    await tester.pumpWidget(_buildPage(diverIdNotifier, prefs));
    await tester.pumpAndSettle();

    expect(find.text('Spare tx'), findsOneWidget);
    expect(find.text('No serial or channel yet'), findsOneWidget);
    // Only the download-created one still asks for its cylinder.
    expect(find.text('No cylinder set up'), findsOneWidget);
  });

  testWidgets('the FAB adds a Transmitter item', (tester) async {
    await tester.pumpWidget(_buildPage(diverIdNotifier, prefs));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('NEW transmitter'), findsOneWidget);
  });

  testWidgets('tapping a transmitter opens its Equipment page, where apply to '
      'existing dives confirms with counts and updates', (tester) async {
    await TransmitterRepository().saveSetup(
      'new-gear',
      role: TankRole.stage,
      volumeL: 11.1,
    );
    await tester.pumpWidget(_buildPage(diverIdNotifier, prefs));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Transmitter 555').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply to existing dives'));
    await tester.pumpAndSettle();
    expect(find.text('Apply to existing dives?'), findsOneWidget);
    expect(find.textContaining('1 cylinders on 1 dives'), findsOneWidget);
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(find.text('Updated 1 cylinders on 1 dives'), findsOneWidget);
    final db = DatabaseService.instance.database;
    final row = await (db.select(
      db.diveTanks,
    )..where((t) => t.id.equals('k1'))).getSingle();
    expect(row.volume, 11.1);
    expect(row.tankRole, 'stage');
  });
}
