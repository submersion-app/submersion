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
import 'package:submersion/features/equipment/data/services/sensor_summary_scheduler.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';
import 'package:submersion/features/transmitters/presentation/pages/transmitter_edit_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

Widget _buildPage(
  MockCurrentDiverIdNotifier diverIdNotifier,
  SharedPreferences prefs, {
  String? transmitterId,
  String? initialSerial,
  MockSettingsNotifier? settings,
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
          transmitterId: transmitterId,
          initialSerial: initialSerial,
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
    diverIdNotifier = MockCurrentDiverIdNotifier();
    await diverIdNotifier.setCurrentDiver('diver-1');
  });
  tearDown(tearDownTestDatabase);

  testWidgets('prefills the serial and saves a new entry for the diver', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      _buildPage(diverIdNotifier, prefs, initialSerial: '555'),
    );

    expect(find.widgetWithText(TextFormField, '555'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('transmitter_label')), 'Stage');
    await tester.enterText(find.byKey(const Key('transmitter_volume')), '11.1');
    await tester.enterText(
      find.byKey(const Key('transmitter_working_pressure')),
      '207',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = await TransmitterRepository().getForDiver('diver-1');
    expect(saved.single.transmitterSerial, '555');
    expect(saved.single.label, 'Stage');
    expect(saved.single.volumeL, closeTo(11.1, 0.01));
    expect(saved.single.workingPressureBar, 207);
    expect(find.text('LIST'), findsOneWidget);
    // Saved from an Assign flow: the snackbar offers the retroactive apply.
    expect(find.text('Apply to existing dives'), findsOneWidget);
  });

  testWidgets('names the transmitter gear item the entry is', (tester) async {
    // Beside the cylinder it feeds, an entry names the transmitter item it
    // is, which is how the dropout rules find that item's serials.
    await DatabaseService.instance.database.customStatement(
      "INSERT INTO equipment (id, diver_id, name, type, created_at, "
      "updated_at) VALUES ('tx', 'diver-1', 'Perdix Tx', 'transmitter', 1, 1), "
      "('tank', 'diver-1', 'Blue AL80', 'tank', 1, 1)",
    );
    await _pumpPage(
      tester,
      _buildPage(diverIdNotifier, prefs, initialSerial: '555'),
    );

    await tester.tap(find.text('Transmitter from gear'));
    await tester.pumpAndSettle();
    expect(find.text('Blue AL80'), findsNothing, reason: 'transmitters only');
    await tester.tap(find.text('Perdix Tx'));
    await tester.pumpAndSettle();
    expect(find.text('Perdix Tx'), findsOneWidget, reason: 'shown on the tile');

    await tester.enterText(find.byKey(const Key('transmitter_label')), 'Main');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = await TransmitterRepository().getForDiver('diver-1');
    expect(saved.single.transmitterEquipmentId, 'tx');
    expect(saved.single.equipmentId, isNull, reason: 'no cylinder picked');
  });

  testWidgets(
    'saving a transmitter link refreshes the items it moves between',
    (tester) async {
      // The dropout findings read serials through this link, and the stored
      // findings are read without the engine, so both the item it left and the
      // item it names must be refreshed when the entry is saved.
      final requested = <String>{};
      SensorSummaryScheduler.instance.findingsRequestListener =
          requested.addAll;
      addTearDown(
        () => SensorSummaryScheduler.instance.findingsRequestListener = null,
      );
      await DatabaseService.instance.database.customStatement(
        "INSERT INTO equipment (id, diver_id, name, type, created_at, "
        "updated_at) VALUES ('old-tx', 'diver-1', 'Old Tx', 'transmitter', 1, "
        "1), ('new-tx', 'diver-1', 'New Tx', 'transmitter', 1, 1)",
      );
      final now = DateTime.utc(2026);
      await TransmitterRepository().create(
        Transmitter(
          id: 'r1',
          diverId: 'diver-1',
          transmitterSerial: '555',
          label: 'Main',
          transmitterEquipmentId: 'old-tx',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await _pumpPage(
        tester,
        _buildPage(diverIdNotifier, prefs, transmitterId: 'r1'),
      );

      await tester.tap(find.text('Transmitter from gear'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New Tx'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(requested, {'old-tx', 'new-tx'});
    },
  );

  testWidgets('clearing the transmitter gear saves the entry unlinked', (
    tester,
  ) async {
    await DatabaseService.instance.database.customStatement(
      "INSERT INTO equipment (id, diver_id, name, type, created_at, "
      "updated_at) VALUES ('tx', 'diver-1', 'Perdix Tx', 'transmitter', 1, 1)",
    );
    final now = DateTime.utc(2026);
    await TransmitterRepository().create(
      Transmitter(
        id: 'r1',
        diverId: 'diver-1',
        transmitterSerial: '555',
        label: 'Main',
        transmitterEquipmentId: 'tx',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await _pumpPage(
      tester,
      _buildPage(diverIdNotifier, prefs, transmitterId: 'r1'),
    );
    expect(find.text('Perdix Tx'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('transmitter_transmitter_gear')),
        matching: find.byIcon(Icons.clear),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Perdix Tx'), findsNothing);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = await TransmitterRepository().getForDiver('diver-1');
    expect(saved.single.transmitterEquipmentId, isNull);
  });

  testWidgets('refuses an entry with neither serial nor channel', (
    tester,
  ) async {
    await _pumpPage(tester, _buildPage(diverIdNotifier, prefs));

    await tester.enterText(find.byKey(const Key('transmitter_label')), 'T1');
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

    await tester.enterText(find.byKey(const Key('transmitter_label')), 'T1');
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
    await _pumpPage(
      tester,
      _buildPage(diverIdNotifier, prefs, initialSerial: '555'),
    );

    await tester.enterText(find.byKey(const Key('transmitter_label')), 'Other');
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
      await _pumpPage(
        tester,
        _buildPage(diverIdNotifier, prefs, initialSerial: '555'),
      );

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
      await _pumpPage(
        tester,
        _buildPage(diverIdNotifier, prefs, initialSerial: '555'),
      );

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
      await _pumpPage(
        tester,
        _buildPage(diverIdNotifier, prefs, initialSerial: '555'),
      );

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
      await _pumpPage(
        tester,
        _buildPage(diverIdNotifier, prefs, initialSerial: '555'),
      );
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

  testWidgets(
    'offers to copy the serial onto a freshly picked transmitter gear item '
    'with no serial (#3367)',
    (tester) async {
      await DatabaseService.instance.database.customStatement(
        "INSERT INTO equipment (id, diver_id, name, type, created_at, "
        "updated_at) VALUES ('tx', 'diver-1', 'Perdix Tx', 'transmitter', 1, "
        "1)",
      );
      await _pumpPage(
        tester,
        _buildPage(diverIdNotifier, prefs, initialSerial: '555'),
      );

      await tester.tap(find.text('Transmitter from gear'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Perdix Tx'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('transmitter_label')), 'M');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Copy the serial to "Perdix Tx"?'), findsOneWidget);
      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();

      final db = DatabaseService.instance.database;
      final row = await (db.select(
        db.equipment,
      )..where((t) => t.id.equals('tx'))).getSingle();
      expect(row.serialNumber, '555');
    },
  );

  testWidgets('declining the serial-copy offer still saves the entry (#3367)', (
    tester,
  ) async {
    await DatabaseService.instance.database.customStatement(
      "INSERT INTO equipment (id, diver_id, name, type, created_at, "
      "updated_at) VALUES ('tx', 'diver-1', 'Perdix Tx', 'transmitter', 1, "
      "1)",
    );
    await _pumpPage(
      tester,
      _buildPage(diverIdNotifier, prefs, initialSerial: '555'),
    );

    await tester.tap(find.text('Transmitter from gear'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Perdix Tx'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('transmitter_label')), 'M');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    final db = DatabaseService.instance.database;
    final row = await (db.select(
      db.equipment,
    )..where((t) => t.id.equals('tx'))).getSingle();
    expect(row.serialNumber, isNull);
    final saved = await TransmitterRepository().getForDiver('diver-1');
    expect(saved.single.transmitterEquipmentId, 'tx');
  });

  testWidgets(
    'does not offer to copy onto a gear item that already has a serial '
    '(#3367)',
    (tester) async {
      await DatabaseService.instance.database.customStatement(
        "INSERT INTO equipment (id, diver_id, name, type, serial_number, "
        "created_at, updated_at) VALUES ('tx', 'diver-1', 'Perdix Tx', "
        "'transmitter', '999', 1, 1)",
      );
      await _pumpPage(
        tester,
        _buildPage(diverIdNotifier, prefs, initialSerial: '555'),
      );

      await tester.tap(find.text('Transmitter from gear'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Perdix Tx'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('transmitter_label')), 'M');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Copy the serial'), findsNothing);
    },
  );

  testWidgets('offers the copy onto a gear item whose serial is an all-zero '
      'placeholder, as the mismatch detector reads it (#3540)', (tester) async {
    await DatabaseService.instance.database.customStatement(
      "INSERT INTO equipment (id, diver_id, name, type, serial_number, "
      "created_at, updated_at) VALUES ('tx', 'diver-1', 'Perdix Tx', "
      "'transmitter', '000', 1, 1)",
    );
    await _pumpPage(
      tester,
      _buildPage(diverIdNotifier, prefs, initialSerial: '555'),
    );

    await tester.tap(find.text('Transmitter from gear'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Perdix Tx'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('transmitter_label')), 'M');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();

    final db = DatabaseService.instance.database;
    final row = await (db.select(
      db.equipment,
    )..where((t) => t.id.equals('tx'))).getSingle();
    expect(row.serialNumber, '555');
    expect(find.text('LIST'), findsOneWidget, reason: 'the save completes');
  });

  testWidgets(
    'does not copy an all-zero sentinel serial onto the gear item (#3540)',
    (tester) async {
      final db = DatabaseService.instance.database;
      await db.customStatement(
        "INSERT INTO equipment (id, diver_id, name, type, created_at, "
        "updated_at) VALUES ('tx', 'diver-1', 'Perdix Tx', 'transmitter', 1, "
        "1)",
      );
      await db.customStatement(
        "INSERT INTO dive_computers (id, diver_id, name, created_at, "
        "updated_at) VALUES ('c1', 'diver-1', 'Perdix', 1, 1)",
      );
      await _pumpPage(tester, _buildPage(diverIdNotifier, prefs));

      await tester.enterText(find.byKey(const Key('transmitter_label')), 'M');
      await tester.enterText(
        find.byKey(const Key('transmitter_serial')),
        '000',
      );
      await tester.tap(find.byType(DropdownButtonFormField<String?>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Perdix').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('transmitter_channel')), '1');
      await tester.tap(find.text('Transmitter from gear'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Perdix Tx'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Copy the serial'), findsNothing);
      final row = await (db.select(
        db.equipment,
      )..where((t) => t.id.equals('tx'))).getSingle();
      expect(row.serialNumber, isNull);
      final saved = await TransmitterRepository().getForDiver('diver-1');
      expect(saved.single.transmitterSerial, isNull, reason: 'normalized away');
    },
  );

  testWidgets(
    'does not re-offer the serial copy on a later save of an existing link '
    '(#3367)',
    (tester) async {
      await DatabaseService.instance.database.customStatement(
        "INSERT INTO equipment (id, diver_id, name, type, created_at, "
        "updated_at) VALUES ('tx', 'diver-1', 'Perdix Tx', 'transmitter', 1, "
        "1)",
      );
      final now = DateTime.utc(2026, 9, 1);
      await TransmitterRepository().create(
        Transmitter(
          id: 'e1',
          diverId: 'diver-1',
          transmitterSerial: '555',
          label: 'Main',
          transmitterEquipmentId: 'tx',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await _pumpPage(
        tester,
        _buildPage(diverIdNotifier, prefs, transmitterId: 'e1'),
      );

      await tester.enterText(
        find.byKey(const Key('transmitter_label')),
        'Main 2',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Copy the serial'), findsNothing);
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
}
