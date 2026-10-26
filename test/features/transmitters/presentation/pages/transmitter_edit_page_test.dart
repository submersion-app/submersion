import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/database/database.dart' show DiveTanksCompanion;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';
import 'package:submersion/features/transmitters/presentation/pages/transmitter_edit_page.dart';
import 'package:submersion/features/transmitters/presentation/providers/transmitter_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

Widget _buildPage(
  MockCurrentDiverIdNotifier diverIdNotifier,
  SharedPreferences prefs, {
  String equipmentId = 'tx-gear',
  String? transmitterId,
  MockSettingsNotifier? settings,
  TransmitterRepository? repository,
}) {
  final router = GoRouter(
    initialLocation: '/edit',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: Text('LIST')),
      ),
      GoRoute(
        path: '/edit',
        builder: (context, state) => TransmitterEditPage(
          equipmentId: equipmentId,
          transmitterId: transmitterId,
        ),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      settingsProvider.overrideWith(
        (ref) => settings ?? MockSettingsNotifier(),
      ),
      currentDiverIdProvider.overrideWith((ref) => diverIdNotifier),
      validatedCurrentDiverIdProvider.overrideWith((ref) async => 'diver-1'),
      if (repository != null)
        transmitterRepositoryProvider.overrideWithValue(repository),
    ].cast(),
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      routerConfig: router,
    ),
  );
}

// The page now carries field helper text and per-field explanations
// (issue #3367), tall enough that the default test surface needs a
// scroll, so pick a surface generous enough that every field stays
// onstage, matching the pattern in edit_form_scaffold_test.dart.
Future<void> _pumpPage(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(page);
  await tester.pumpAndSettle();
}

/// A repository whose retroactive apply fails, as a closed database would.
class _FailingApplyRepository extends TransmitterRepository {
  @override
  Future<ApplyToExistingResult> applyToExistingDives(Transmitter entry) =>
      Future.error(StateError('database closed'));
}

void main() {
  late MockCurrentDiverIdNotifier diverIdNotifier;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
    await DatabaseService.instance.database.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('diver-1', 'A', 1, 1)",
    );
    // The Transmitter item being set up (issue #3676).
    await DatabaseService.instance.database.customStatement(
      "INSERT INTO equipment (id, diver_id, name, type, created_at, "
      "updated_at) VALUES ('tx-gear', 'diver-1', 'Back gas tx', "
      "'transmitter', 1, 1)",
    );
    diverIdNotifier = MockCurrentDiverIdNotifier();
    await diverIdNotifier.setCurrentDiver('diver-1');
  });
  tearDown(tearDownTestDatabase);

  testWidgets('refuses an entry with neither serial nor channel', (
    tester,
  ) async {
    await _pumpPage(tester, _buildPage(diverIdNotifier, prefs));

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Enter a transmitter serial, or pick a dive computer and channel',
      ),
      findsOneWidget,
    );
    expect(await TransmitterRepository().getForDiver('diver-1'), isEmpty);
  });

  testWidgets('refuses a channel that is not a whole number (#1900)', (
    tester,
  ) async {
    await _pumpPage(tester, _buildPage(diverIdNotifier, prefs));

    await tester.enterText(find.byKey(const Key('transmitter_serial')), '777');
    await tester.enterText(find.byKey(const Key('transmitter_channel')), '1.5');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a whole number'), findsOneWidget);
    expect(
      await TransmitterRepository().getForDiver('diver-1'),
      isEmpty,
      reason: 'an unreadable channel used to save as no channel',
    );
  });

  testWidgets('refuses a duplicate serial naming the existing entry', (
    tester,
  ) async {
    await TransmitterRepository().create(
      Transmitter(
        id: 'e1',
        diverId: 'diver-1',
        transmitterSerial: '555',
        label: 'Stage',
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: DateTime.utc(2026, 9, 1),
      ),
    );
    await _pumpPage(tester, _buildPage(diverIdNotifier, prefs));

    await tester.enterText(find.byKey(const Key('transmitter_serial')), '555');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Already assigned to Stage'), findsOneWidget);
  });

  testWidgets(
    'picking a cylinder pre-fills Role from its most recent dive (#3367)',
    (tester) async {
      final db = DatabaseService.instance.database;
      await db.customStatement(
        "INSERT INTO equipment (id, diver_id, name, type, created_at, "
        "updated_at) VALUES ('tank1', 'diver-1', 'Sidemount AL80', 'tank', "
        "1, 1)",
      );
      await db.customStatement(
        "INSERT INTO dives (id, diver_id, dive_date_time, created_at, "
        "updated_at) VALUES ('d1', 'diver-1', 1, 1, 1)",
      );
      await db
          .into(db.diveTanks)
          .insert(
            DiveTanksCompanion.insert(
              id: 'k1',
              diveId: 'd1',
              equipmentId: const Value('tank1'),
              tankRole: const Value('sidemountLeft'),
            ),
          );
      await _pumpPage(tester, _buildPage(diverIdNotifier, prefs));

      await tester.tap(find.text('Cylinder from gear'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sidemount AL80'));
      await tester.pumpAndSettle();

      expect(find.text('Sidemount Left'), findsOneWidget);
    },
  );

  testWidgets(
    'picking a cylinder with no dive history leaves Role at Back Gas (#3367)',
    (tester) async {
      await DatabaseService.instance.database.customStatement(
        "INSERT INTO equipment (id, diver_id, name, type, created_at, "
        "updated_at) VALUES ('tank1', 'diver-1', 'Fresh AL80', 'tank', 1, 1)",
      );
      await _pumpPage(tester, _buildPage(diverIdNotifier, prefs));

      await tester.tap(find.text('Cylinder from gear'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fresh AL80'));
      await tester.pumpAndSettle();

      expect(find.text('Back Gas'), findsOneWidget);
    },
  );

  testWidgets(
    'a manually picked Role is never overridden by a later gear pick (#3367)',
    (tester) async {
      final db = DatabaseService.instance.database;
      await db.customStatement(
        "INSERT INTO equipment (id, diver_id, name, type, created_at, "
        "updated_at) VALUES ('tank1', 'diver-1', 'Sidemount AL80', 'tank', "
        "1, 1)",
      );
      await db.customStatement(
        "INSERT INTO dives (id, diver_id, dive_date_time, created_at, "
        "updated_at) VALUES ('d1', 'diver-1', 1, 1, 1)",
      );
      await db
          .into(db.diveTanks)
          .insert(
            DiveTanksCompanion.insert(
              id: 'k1',
              diveId: 'd1',
              equipmentId: const Value('tank1'),
              tankRole: const Value('sidemountLeft'),
            ),
          );
      await _pumpPage(tester, _buildPage(diverIdNotifier, prefs));

      await tester.tap(find.byType(DropdownButtonFormField<TankRole>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stage').last);
      await tester.pumpAndSettle();
      expect(find.text('Stage'), findsWidgets);

      await tester.tap(find.text('Cylinder from gear'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sidemount AL80'));
      await tester.pumpAndSettle();

      expect(find.text('Stage'), findsWidgets);
      expect(find.text('Sidemount Left'), findsNothing);
    },
  );

  testWidgets(
    'picking a cylinder with no size on file shows a non-blocking hint '
    '(#3367)',
    (tester) async {
      await DatabaseService.instance.database.customStatement(
        "INSERT INTO equipment (id, diver_id, name, type, created_at, "
        "updated_at) VALUES ('tank1', 'diver-1', 'Fresh AL80', 'tank', 1, 1)",
      );
      await _pumpPage(tester, _buildPage(diverIdNotifier, prefs));
      expect(
        find.byKey(const Key('transmitter_missing_size_hint')),
        findsNothing,
      );

      await tester.tap(find.text('Cylinder from gear'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fresh AL80'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('transmitter_missing_size_hint')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'picking a cylinder with no size on file keeps an already-filled size '
    'and skips the hint (#3378)',
    (tester) async {
      await DatabaseService.instance.database.customStatement(
        "INSERT INTO equipment (id, diver_id, name, type, created_at, "
        "updated_at) VALUES ('tank1', 'diver-1', 'Fresh AL80', 'tank', 1, 1)",
      );
      await TransmitterRepository().create(
        Transmitter(
          id: 'e1',
          diverId: 'diver-1',
          transmitterSerial: '555',
          label: 'AL80',
          volumeL: 11.1,
          workingPressureBar: 207,
          createdAt: DateTime.utc(2026, 9, 1),
          updatedAt: DateTime.utc(2026, 9, 1),
        ),
      );
      await _pumpPage(
        tester,
        _buildPage(diverIdNotifier, prefs, transmitterId: 'e1'),
      );

      await tester.tap(find.text('Cylinder from gear'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fresh AL80'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('transmitter_missing_size_hint')),
        findsNothing,
        reason: 'the saved size from before the pick is still on screen',
      );
      expect(find.widgetWithText(TextFormField, '11.1'), findsOneWidget);
    },
  );

  testWidgets('shows volume in cubic feet and stores liters', (tester) async {
    final settings = MockSettingsNotifier();
    await settings.setVolumeUnit(VolumeUnit.cubicFeet);
    await settings.setPressureUnit(PressureUnit.psi);
    await TransmitterRepository().create(
      Transmitter(
        id: 'e1',
        diverId: 'diver-1',
        transmitterSerial: '555',
        label: 'AL80',
        volumeL: 11.1,
        workingPressureBar: 207,
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: DateTime.utc(2026, 9, 1),
      ),
    );

    await _pumpPage(
      tester,
      _buildPage(
        diverIdNotifier,
        prefs,
        transmitterId: 'e1',
        settings: settings,
      ),
    );

    // 11.1 L at 207 bar is 81.1 cuft; 207 bar is 3002 psi.
    expect(find.widgetWithText(TextFormField, '81.1'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '3002'), findsOneWidget);
  });

  testWidgets('adds a key under the item, labelled with its name, configured '
      'and offered the apply (#3676)', (tester) async {
    await _pumpPage(tester, _buildPage(diverIdNotifier, prefs));

    await tester.enterText(find.byKey(const Key('transmitter_serial')), '555');
    await tester.enterText(find.byKey(const Key('transmitter_volume')), '11.1');
    await tester.enterText(
      find.byKey(const Key('transmitter_working_pressure')),
      '207',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = (await TransmitterRepository().getForDiver('diver-1')).single;
    expect(saved.transmitterSerial, '555');
    expect(saved.label, 'Back gas tx');
    expect(saved.transmitterEquipmentId, 'tx-gear');
    expect(saved.isConfigured, isTrue);
    expect(saved.volumeL, closeTo(11.1, 0.01));
    expect(find.text('LIST'), findsOneWidget);
    expect(find.text('Apply to existing dives'), findsOneWidget);
  });

  testWidgets('saving the setup writes it to every key of the item (#3676)', (
    tester,
  ) async {
    await TransmitterRepository().create(
      Transmitter(
        id: 'e2',
        diverId: 'diver-1',
        transmitterSerial: '777',
        label: 'Back gas tx',
        transmitterEquipmentId: 'tx-gear',
        isConfigured: false,
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: DateTime.utc(2026, 9, 1),
      ),
    );
    await _pumpPage(tester, _buildPage(diverIdNotifier, prefs));

    await tester.enterText(find.byKey(const Key('transmitter_serial')), '555');
    await tester.enterText(find.byKey(const Key('transmitter_volume')), '11.1');
    await tester.enterText(
      find.byKey(const Key('transmitter_working_pressure')),
      '207',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final other = await TransmitterRepository().getById('e2');
    expect(other!.isConfigured, isTrue);
    expect(other.volumeL, closeTo(11.1, 0.01));
    expect(other.workingPressureBar, 207);
  });

  testWidgets("a key fills the item's blank serial (#3676)", (tester) async {
    await _pumpPage(tester, _buildPage(diverIdNotifier, prefs));

    await tester.enterText(find.byKey(const Key('transmitter_serial')), '555');
    await tester.enterText(find.byKey(const Key('transmitter_volume')), '11.1');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final row = await DatabaseService.instance.database
        .customSelect(
          "SELECT serial_number FROM equipment WHERE id = 'tx-gear'",
        )
        .getSingle();
    expect(row.read<String?>('serial_number'), '555');
  });

  testWidgets("a first key starts from the item's serial (#3676)", (
    tester,
  ) async {
    await DatabaseService.instance.database.customStatement(
      "UPDATE equipment SET serial_number = '9D0001' WHERE id = 'tx-gear'",
    );
    await _pumpPage(tester, _buildPage(diverIdNotifier, prefs));

    expect(find.widgetWithText(TextFormField, '9D0001'), findsOneWidget);
  });

  testWidgets('the post-save apply fills the dives of every key of the item '
      '(review)', (tester) async {
    final db = DatabaseService.instance.database;
    await db.customStatement(
      "INSERT INTO dives (id, diver_id, dive_date_time, created_at, "
      "updated_at) VALUES ('d1', 'diver-1', 1, 1, 1)",
    );
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(
            id: 'k777',
            diveId: 'd1',
            transmitterSerial: const Value('777'),
          ),
        );
    await TransmitterRepository().create(
      Transmitter(
        id: 'e2',
        diverId: 'diver-1',
        transmitterSerial: '777',
        label: 'Back gas tx',
        transmitterEquipmentId: 'tx-gear',
        isConfigured: false,
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: DateTime.utc(2026, 9, 1),
      ),
    );
    await _pumpPage(tester, _buildPage(diverIdNotifier, prefs));

    await tester.enterText(find.byKey(const Key('transmitter_serial')), '555');
    await tester.enterText(find.byKey(const Key('transmitter_volume')), '11.1');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply to existing dives'));
    await tester.pumpAndSettle();

    final tank = await (db.select(
      db.diveTanks,
    )..where((t) => t.id.equals('k777'))).getSingle();
    expect(tank.volume, closeTo(11.1, 0.01));
  });

  testWidgets('a post-save apply that fails says so (review)', (tester) async {
    await _pumpPage(
      tester,
      _buildPage(diverIdNotifier, prefs, repository: _FailingApplyRepository()),
    );

    await tester.enterText(find.byKey(const Key('transmitter_serial')), '555');
    await tester.enterText(find.byKey(const Key('transmitter_volume')), '11.1');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply to existing dives'));
    await tester.pumpAndSettle();

    expect(find.textContaining('database closed'), findsOneWidget);
  });

  testWidgets('a key can be removed on its own; the item and its other keys '
      'stay (review)', (tester) async {
    late final TransmitterRepository repo;
    await tester.runAsync(() async {
      repo = TransmitterRepository();
      for (final (id, serial) in [('k1', '111'), ('k2', '222')]) {
        await repo.create(
          Transmitter(
            id: id,
            diverId: 'diver-1',
            transmitterSerial: serial,
            label: 'Back gas tx',
            transmitterEquipmentId: 'tx-gear',
            createdAt: DateTime.utc(2026, 9, 1),
            updatedAt: DateTime.utc(2026, 9, 1),
          ),
        );
      }
    });
    await _pumpPage(
      tester,
      _buildPage(diverIdNotifier, prefs, transmitterId: 'k2'),
    );

    await tester.tap(find.byKey(const Key('transmitter_remove_key')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();

    final keys = await tester.runAsync(() => repo.getForEquipment('tx-gear'));
    expect(keys!.map((k) => k.id), ['k1']);
    expect(find.text('LIST'), findsOneWidget);
  });

  testWidgets('a new key offers no remove', (tester) async {
    await _pumpPage(tester, _buildPage(diverIdNotifier, prefs));

    expect(find.byKey(const Key('transmitter_remove_key')), findsNothing);
  });
}
