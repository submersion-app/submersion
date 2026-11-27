import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/database/database.dart'
    show DiveTanksCompanion, EquipmentCompanion;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';
import 'package:submersion/features/transmitters/data/services/transmitter_auto_registrar.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';
import 'package:submersion/features/transmitters/presentation/pages/transmitter_key_saved.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';
import 'transmitter_edit_page_harness.dart';

void main() {
  late MockCurrentDiverIdNotifier diverIdNotifier;
  late SharedPreferences prefs;

  /// What each push of the editor came back with.
  late List<Object?> results;

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
    results = [];
  });
  tearDown(tearDownTestDatabase);

  testWidgets('refuses an entry with neither serial nor channel', (
    tester,
  ) async {
    await pumpTransmitterPage(
      tester,
      buildTransmitterPage(diverIdNotifier, prefs, results: results),
    );

    // A size with no key: Save is enabled by the change.
    await tester.enterText(find.byKey(const Key('transmitter_volume')), '11.1');
    await tester.pump();
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
    await pumpTransmitterPage(
      tester,
      buildTransmitterPage(diverIdNotifier, prefs, results: results),
    );

    await tester.enterText(find.byKey(const Key('transmitter_serial')), '777');
    await tester.enterText(find.byKey(const Key('transmitter_channel')), '1.5');
    // Save enables on the next frame.
    await tester.pump();
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
    await pumpTransmitterPage(
      tester,
      buildTransmitterPage(diverIdNotifier, prefs, results: results),
    );

    await tester.enterText(find.byKey(const Key('transmitter_serial')), '555');
    // Save enables on the next frame.
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Already assigned to Stage'), findsOneWidget);
  });

  group('a serial a download registered on another item (#3367)', () {
    const serial = '76287';

    /// What a download leaves behind for [serial]; returns its item's id.
    Future<String> registerFromDownload() async {
      await TransmitterAutoRegistrar(
        nameFor: (s) => 'Transmitter $s',
      ).registerNewSerials([serial], diverId: 'diver-1');
      final rows = await TransmitterRepository().getForDiver('diver-1');
      return rows
          .singleWhere((t) => t.transmitterSerial == serial)
          .transmitterEquipmentId!;
    }

    Future<int> itemCount(String id) async {
      final row = await DatabaseService.instance.database
          .customSelect(
            'SELECT COUNT(*) AS c FROM equipment WHERE id = ?',
            variables: [Variable<String>(id)],
          )
          .getSingle();
      return row.read<int>('c');
    }

    testWidgets('moves onto this item and the placeholder goes', (
      tester,
    ) async {
      final placeholder = await registerFromDownload();
      await pumpTransmitterPage(
        tester,
        buildTransmitterPage(diverIdNotifier, prefs, results: results),
      );

      await tester.enterText(
        find.byKey(const Key('transmitter_serial')),
        serial,
      );
      await tester.enterText(find.byKey(const Key('transmitter_volume')), '10');
      // Save enables on the next frame.
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('LIST'), findsOneWidget);
      expect((results.single! as TransmitterKeySaved).offerApply, isTrue);
      final key = (await TransmitterRepository().getForEquipment(
        'tx-gear',
      )).single;
      expect(key.transmitterSerial, serial);
      expect(key.isConfigured, isTrue);
      expect(key.volumeL, 10);
      expect(await itemCount(placeholder), 0);
    });

    testWidgets('editing a set-up key to it still offers the apply', (
      tester,
    ) async {
      await registerFromDownload();
      await TransmitterRepository().create(
        Transmitter(
          id: 'typed',
          diverId: 'diver-1',
          transmitterSerial: '076287',
          label: 'Back gas tx',
          volumeL: 10,
          transmitterEquipmentId: 'tx-gear',
          createdAt: DateTime.utc(2026, 9, 1),
          updatedAt: DateTime.utc(2026, 9, 1),
        ),
      );
      await pumpTransmitterPage(
        tester,
        buildTransmitterPage(
          diverIdNotifier,
          prefs,
          transmitterId: 'typed',
          results: results,
        ),
      );

      await tester.enterText(
        find.byKey(const Key('transmitter_serial')),
        serial,
      );
      // Save enables on the next frame.
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('LIST'), findsOneWidget);
      expect((results.single! as TransmitterKeySaved).offerApply, isTrue);
    });

    testWidgets("keeps what the fold filled in on the item", (tester) async {
      final placeholder = await registerFromDownload();
      final db = DatabaseService.instance.database;
      await db.customStatement(
        "UPDATE equipment SET brand = 'Oceanic' WHERE id = ?",
        [placeholder],
      );
      await pumpTransmitterPage(
        tester,
        buildTransmitterPage(diverIdNotifier, prefs, results: results),
      );

      await tester.enterText(
        find.byKey(const Key('transmitter_serial')),
        serial,
      );
      await tester.enterText(find.byKey(const Key('transmitter_volume')), '10');
      // Save enables on the next frame.
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final row = await db
          .customSelect(
            "SELECT brand, serial_number FROM equipment WHERE id = 'tx-gear'",
          )
          .getSingle();
      expect(row.read<String?>('brand'), 'Oceanic');
      expect(row.read<String?>('serial_number'), serial);
    });

    testWidgets('stays refused once another transmitter is set up with it', (
      tester,
    ) async {
      final placeholder = await registerFromDownload();
      final repo = TransmitterRepository();
      final holder = (await repo.getForEquipment(placeholder)).single;
      await repo.update(holder.copyWith(isConfigured: true, label: 'Stage'));
      await pumpTransmitterPage(
        tester,
        buildTransmitterPage(diverIdNotifier, prefs, results: results),
      );

      await tester.enterText(
        find.byKey(const Key('transmitter_serial')),
        serial,
      );
      // Save enables on the next frame.
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Already assigned to Stage'), findsOneWidget);
      expect(await repo.getForEquipment('tx-gear'), isEmpty);
      expect(await itemCount(placeholder), 1);
    });
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
      await pumpTransmitterPage(
        tester,
        buildTransmitterPage(diverIdNotifier, prefs, results: results),
      );

      await tester.tap(find.text('Cylinder from gear'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sidemount AL80'));
      await tester.pumpAndSettle();

      expect(find.text('Sidemount Left'), findsOneWidget);
    },
  );

  testWidgets(
    'a cylinder marked for suit inflation sets the Role ahead of its history '
    '(#4243)',
    (tester) async {
      final db = DatabaseService.instance.database;
      await db.customStatement(
        "INSERT INTO equipment (id, diver_id, name, type, created_at, "
        "updated_at) VALUES ('tank1', 'diver-1', 'Argon 0.85', 'tank', 1, 1)",
      );
      await db.customStatement(
        "INSERT INTO equipment_attributes (id, equipment_id, attr_key, "
        "value_text, created_at, updated_at) VALUES ('a1', 'tank1', "
        "'cylinder_use', 'suit_inflation', 1, 1)",
      );
      // Logged before as a pony, which the history would suggest.
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
              tankRole: const Value('pony'),
            ),
          );
      await pumpTransmitterPage(
        tester,
        buildTransmitterPage(diverIdNotifier, prefs, results: results),
      );

      await tester.tap(find.text('Cylinder from gear'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Argon 0.85'));
      await tester.pumpAndSettle();

      expect(find.text('Suit Inflation'), findsOneWidget);
      expect(find.text('Pony Bottle'), findsNothing);
    },
  );

  testWidgets(
    'a cylinder worn as a twin set sets the Role ahead of its history '
    '(#4641)',
    (tester) async {
      final db = DatabaseService.instance.database;
      await db.customStatement(
        "INSERT INTO equipment (id, diver_id, name, type, created_at, "
        "updated_at) VALUES ('tank1', 'diver-1', 'D12', 'tank', 1, 1)",
      );
      await db.customStatement(
        "INSERT INTO equipment_attributes (id, equipment_id, attr_key, "
        "value_text, created_at, updated_at) VALUES ('a1', 'tank1', "
        "'worn_as', 'twin_set', 1, 1)",
      );
      // Logged before as back gas, which the history would suggest.
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
              tankRole: const Value('backGas'),
            ),
          );
      await pumpTransmitterPage(
        tester,
        buildTransmitterPage(diverIdNotifier, prefs, results: results),
      );

      await tester.tap(find.text('Cylinder from gear'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('D12'));
      await tester.pumpAndSettle();

      expect(find.text('Twin Set'), findsOneWidget);
      expect(find.text('Back Gas'), findsNothing);
    },
  );

  testWidgets(
    'picking a cylinder with no dive history leaves Role at Back Gas (#3367)',
    (tester) async {
      await DatabaseService.instance.database.customStatement(
        "INSERT INTO equipment (id, diver_id, name, type, created_at, "
        "updated_at) VALUES ('tank1', 'diver-1', 'Fresh AL80', 'tank', 1, 1)",
      );
      await pumpTransmitterPage(
        tester,
        buildTransmitterPage(diverIdNotifier, prefs, results: results),
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
      await pumpTransmitterPage(
        tester,
        buildTransmitterPage(diverIdNotifier, prefs, results: results),
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
      await pumpTransmitterPage(
        tester,
        buildTransmitterPage(diverIdNotifier, prefs, results: results),
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
      await pumpTransmitterPage(
        tester,
        buildTransmitterPage(diverIdNotifier, prefs, transmitterId: 'e1'),
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

  testWidgets('a small bottle keeps both decimals of its size (#4243)', (
    tester,
  ) async {
    // A drysuit's 0.85 L argon bottle must not load, and so save, as 0.9.
    await TransmitterRepository().create(
      Transmitter(
        id: 'e1',
        diverId: 'diver-1',
        transmitterSerial: '555',
        label: 'Argon',
        role: TankRole.suitInflation,
        volumeL: 0.85,
        workingPressureBar: 200,
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: DateTime.utc(2026, 9, 1),
      ),
    );
    await pumpTransmitterPage(
      tester,
      buildTransmitterPage(diverIdNotifier, prefs, transmitterId: 'e1'),
    );

    expect(find.widgetWithText(TextFormField, '0.85'), findsOneWidget);
  });

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

    await pumpTransmitterPage(
      tester,
      buildTransmitterPage(
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
    await pumpTransmitterPage(
      tester,
      buildTransmitterPage(diverIdNotifier, prefs, results: results),
    );

    await tester.enterText(find.byKey(const Key('transmitter_serial')), '555');
    await tester.enterText(find.byKey(const Key('transmitter_volume')), '11.1');
    await tester.enterText(
      find.byKey(const Key('transmitter_working_pressure')),
      '207',
    );
    // Save enables on the next frame.
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = (await TransmitterRepository().getForDiver('diver-1')).single;
    expect(saved.transmitterSerial, '555');
    expect(saved.label, 'Back gas tx');
    expect(saved.transmitterEquipmentId, 'tx-gear');
    expect(saved.isConfigured, isTrue);
    expect(saved.volumeL, closeTo(11.1, 0.01));
    expect(find.text('LIST'), findsOneWidget);
    expect((results.single! as TransmitterKeySaved).offerApply, isTrue);
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
    await pumpTransmitterPage(
      tester,
      buildTransmitterPage(diverIdNotifier, prefs, results: results),
    );

    await tester.enterText(find.byKey(const Key('transmitter_serial')), '555');
    await tester.enterText(find.byKey(const Key('transmitter_volume')), '11.1');
    await tester.enterText(
      find.byKey(const Key('transmitter_working_pressure')),
      '207',
    );
    // Save enables on the next frame.
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final other = await TransmitterRepository().getById('e2');
    expect(other!.isConfigured, isTrue);
    expect(other.volumeL, closeTo(11.1, 0.01));
    expect(other.workingPressureBar, 207);
  });

  testWidgets("a key fills the item's blank serial (#3676)", (tester) async {
    await pumpTransmitterPage(
      tester,
      buildTransmitterPage(diverIdNotifier, prefs, results: results),
    );

    await tester.enterText(find.byKey(const Key('transmitter_serial')), '555');
    await tester.enterText(find.byKey(const Key('transmitter_volume')), '11.1');
    // Save enables on the next frame.
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final row = await DatabaseService.instance.database
        .customSelect(
          "SELECT serial_number FROM equipment WHERE id = 'tx-gear'",
        )
        .getSingle();
    expect(row.read<String?>('serial_number'), '555');
  });

  testWidgets('a serial the item gained while the page was open stays', (
    tester,
  ) async {
    await pumpTransmitterPage(
      tester,
      buildTransmitterPage(diverIdNotifier, prefs, results: results),
    );
    // A sync gives the item a serial after the page read it.
    final db = DatabaseService.instance.database;
    await (db.update(db.equipment)..where((t) => t.id.equals('tx-gear'))).write(
      const EquipmentCompanion(serialNumber: Value('9D0001')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('transmitter_serial')), '555');
    await tester.enterText(find.byKey(const Key('transmitter_volume')), '11.1');
    // Save enables on the next frame.
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final row = await db
        .customSelect(
          "SELECT serial_number FROM equipment WHERE id = 'tx-gear'",
        )
        .getSingle();
    expect(row.read<String?>('serial_number'), '9D0001');
  });

  testWidgets("a first key starts from the item's serial (#3676)", (
    tester,
  ) async {
    await DatabaseService.instance.database.customStatement(
      "UPDATE equipment SET serial_number = '9D0001' WHERE id = 'tx-gear'",
    );
    await pumpTransmitterPage(
      tester,
      buildTransmitterPage(diverIdNotifier, prefs, results: results),
    );

    expect(find.widgetWithText(TextFormField, '9D0001'), findsOneWidget);
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
    await pumpTransmitterPage(
      tester,
      buildTransmitterPage(diverIdNotifier, prefs, transmitterId: 'k2'),
    );

    await tester.tap(find.byKey(const ValueKey('recordEditorMenu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('transmitter_remove_key')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();

    final keys = await tester.runAsync(() => repo.getForEquipment('tx-gear'));
    expect(keys!.map((k) => k.id), ['k1']);
    expect(find.text('LIST'), findsOneWidget);
  });

  testWidgets('a new key offers no remove', (tester) async {
    await pumpTransmitterPage(
      tester,
      buildTransmitterPage(diverIdNotifier, prefs, results: results),
    );

    expect(find.byKey(const ValueKey('recordEditorMenu')), findsNothing);
    expect(find.byKey(const ValueKey('transmitter_remove_key')), findsNothing);
  });
}
