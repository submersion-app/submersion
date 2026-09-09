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
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

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
}

final _pushed = <String>[];

Widget _buildPage(
  MockCurrentDiverIdNotifier diverIdNotifier,
  SharedPreferences prefs,
) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const TransmittersPage()),
      GoRoute(
        path: '/transmitters/new',
        builder: (context, state) {
          _pushed.add(state.uri.toString());
          return const Scaffold(body: Text('NEW_PAGE'));
        },
      ),
      GoRoute(
        path: '/transmitters/:transmitterId/edit',
        builder: (context, state) {
          _pushed.add(state.uri.toString());
          return const Scaffold(body: Text('EDIT_PAGE'));
        },
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
    _pushed.clear();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
    await _seed();
    diverIdNotifier = MockCurrentDiverIdNotifier();
    await diverIdNotifier.setCurrentDiver('diver-1');
  });
  tearDown(tearDownTestDatabase);

  testWidgets(
    'lists entries with size in the diver units and unassigned serials',
    (tester) async {
      await TransmitterRepository().create(
        Transmitter(
          id: 'e1',
          diverId: 'diver-1',
          transmitterSerial: '180777',
          label: 'O2',
          role: TankRole.oxygenSupply,
          volumeL: 2.0,
          workingPressureBar: 232,
          createdAt: DateTime.utc(2026, 9, 1),
          updatedAt: DateTime.utc(2026, 9, 1),
        ),
      );

      await tester.pumpWidget(_buildPage(diverIdNotifier, prefs));
      await tester.pumpAndSettle();

      expect(find.text('Assigned transmitters'), findsOneWidget);
      expect(find.text('O2'), findsOneWidget);
      expect(find.textContaining('Transmitter 180777'), findsOneWidget);
      expect(find.textContaining('232 bar'), findsOneWidget);
      expect(find.text('Seen in downloads, not assigned'), findsOneWidget);
      expect(find.textContaining('Transmitter 555'), findsOneWidget);
      expect(find.text('1 dive'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    },
  );

  testWidgets('Assign opens the editor with the serial prefilled', (
    tester,
  ) async {
    await tester.pumpWidget(_buildPage(diverIdNotifier, prefs));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Assign'));
    await tester.pumpAndSettle();

    expect(_pushed, ['/transmitters/new?serial=555']);
  });

  testWidgets('the FAB opens a blank editor', (tester) async {
    await tester.pumpWidget(_buildPage(diverIdNotifier, prefs));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(_pushed, ['/transmitters/new']);
  });

  testWidgets('delete asks first and removes the entry', (tester) async {
    await TransmitterRepository().create(
      Transmitter(
        id: 'e1',
        diverId: 'diver-1',
        transmitterSerial: '180777',
        label: 'O2',
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: DateTime.utc(2026, 9, 1),
      ),
    );
    await tester.pumpWidget(_buildPage(diverIdNotifier, prefs));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Delete transmitter?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('O2'), findsNothing);
    expect(await TransmitterRepository().getById('e1'), isNull);
  });

  testWidgets('apply to existing dives confirms with counts and updates', (
    tester,
  ) async {
    await TransmitterRepository().create(
      Transmitter(
        id: 'e1',
        diverId: 'diver-1',
        transmitterSerial: '555',
        label: 'Stage',
        role: TankRole.stage,
        volumeL: 11.1,
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: DateTime.utc(2026, 9, 1),
      ),
    );
    await tester.pumpWidget(_buildPage(diverIdNotifier, prefs));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.playlist_add_check));
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
