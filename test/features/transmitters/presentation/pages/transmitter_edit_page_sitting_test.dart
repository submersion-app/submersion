import 'dart:async';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/services/change_log/record_edit_label.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';
import 'package:submersion/features/transmitters/data/services/transmitter_auto_registrar.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';
import 'package:submersion/features/transmitters/presentation/pages/transmitter_key_saved.dart';
import 'package:submersion/shared/widgets/app_bar_text_action.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';
import 'transmitter_edit_page_harness.dart';

/// A repository whose sibling setup write fails, after the key itself has
/// been written.
class _FailingSetupRepository extends TransmitterRepository {
  @override
  Future<void> saveSetup(
    String equipmentId, {
    required TankRole role,
    String? cylinderId,
    double? volumeL,
    double? workingPressureBar,
    TankMaterial? material,
    String? presetName,
    String? exceptKeyId,
  }) => Future.error(StateError('disk full'));
}

/// The transmitter key editor on the shared Cancel and Save bar (issue
/// #4527, phase 4, plan 2).
void main() {
  late MockCurrentDiverIdNotifier diverIdNotifier;
  late SharedPreferences prefs;
  late List<Object?> results;
  final repo = TransmitterRepository();
  final then = DateTime.utc(2026, 9, 1);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
    final db = DatabaseService.instance.database;
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('diver-1', 'A', 1, 1), ('diver-2', 'B', 1, 1)",
    );
    await db.customStatement(
      "INSERT INTO equipment (id, diver_id, name, type, created_at, "
      "updated_at) VALUES ('tx-gear', 'diver-1', 'Back gas tx', "
      "'transmitter', 1, 1)",
    );
    diverIdNotifier = MockCurrentDiverIdNotifier();
    await diverIdNotifier.setCurrentDiver('diver-1');
    results = [];
  });
  tearDown(tearDownTestDatabase);

  Transmitter key(
    String id, {
    String? serial,
    bool configured = true,
    double? volumeL = 11.1,
    double? workingPressureBar = 207,
    String? cylinderId,
  }) => Transmitter(
    id: id,
    diverId: 'diver-1',
    transmitterSerial: serial ?? id,
    label: 'Back gas tx',
    volumeL: volumeL,
    workingPressureBar: workingPressureBar,
    equipmentId: cylinderId,
    transmitterEquipmentId: 'tx-gear',
    isConfigured: configured,
    createdAt: then,
    updatedAt: then,
  );

  Future<void> open(
    WidgetTester tester, {
    String? transmitterId,
    AppSettings? settings,
    TransmitterRepository? repository,
  }) => pumpTransmitterPage(
    tester,
    buildTransmitterPage(
      diverIdNotifier,
      prefs,
      transmitterId: transmitterId,
      settings: settings == null ? null : MockSettingsNotifier(settings),
      repository: repository,
      results: results,
    ),
  );

  AppBarTextAction save(WidgetTester tester) => tester
      .widgetList<AppBarTextAction>(find.byType(AppBarTextAction))
      .firstWhere((a) => a.label == 'Save');

  Future<void> type(WidgetTester tester, String field, String text) async {
    await tester.enterText(find.byKey(Key(field)), text);
    await tester.pumpAndSettle();
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(AppBarTextAction, 'Save'));
    await tester.pumpAndSettle();
  }

  Future<void> back(WidgetTester tester) async {
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    unawaited(navigator.maybePop());
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('recordEditorMenu')));
    await tester.pumpAndSettle();
  }

  /// The editing sittings written, as (id, operation) pairs.
  Future<List<({String? id, String operation})>> sittings() async {
    final rows = await DatabaseService.instance.database
        .customSelect(
          "SELECT id, label FROM change_log_operations "
          "WHERE label LIKE 'record_edit:%'",
        )
        .get();
    return [
      for (final row in rows)
        (
          id: RecordEditLabel.decode(row.read<String>('label'))?.id,
          operation: row.read<String>('id'),
        ),
    ];
  }

  Future<int> eventsUnder(String operationId, String table) async {
    final row = await DatabaseService.instance.database
        .customSelect(
          'SELECT COUNT(*) AS c FROM change_log_events '
          'WHERE operation_id = ? AND table_name = ?',
          variables: [Variable<String>(operationId), Variable<String>(table)],
        )
        .getSingle();
    return row.read<int>('c');
  }

  /// No sitting wrote anything: one that rolled back keeps an empty
  /// operation row until the log settles, but no events.
  Future<void> expectNothingWritten() async {
    for (final sitting in await sittings()) {
      expect(await eventsUnder(sitting.operation, 'transmitters'), 0);
    }
  }

  Future<bool> itemExists(String id) async =>
      (await DatabaseService.instance.database
              .customSelect(
                'SELECT id FROM equipment WHERE id = ?',
                variables: [Variable<String>(id)],
              )
              .get())
          .isNotEmpty;

  testWidgets(
    'the bar is the tinted Cancel and Save bar with no close button',
    (tester) async {
      await repo.create(key('k1'));
      await open(tester, transmitterId: 'k1');

      expect(find.byType(RecordEditBar), findsOneWidget);
      expect(find.byIcon(Icons.close), findsNothing);
      expect(save(tester).onPressed, isNull);
    },
  );

  testWidgets(
    'a set-up key opened in cuft and psi and left alone is unchanged',
    (tester) async {
      await repo.create(key('k1'));
      await open(
        tester,
        transmitterId: 'k1',
        settings: const AppSettings(
          volumeUnit: VolumeUnit.cubicFeet,
          pressureUnit: PressureUnit.psi,
        ),
      );

      expect(save(tester).onPressed, isNull);
      await back(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('LIST'), findsOneWidget);
    },
  );

  testWidgets('a cylinder whose name fails to load leaves the key editable', (
    tester,
  ) async {
    await DatabaseService.instance.database.customStatement(
      "INSERT INTO equipment (id, diver_id, name, type, created_at, "
      "updated_at) VALUES ('cyl-1', 'diver-1', 'Steel 12', 'tank', 1, 1)",
    );
    await repo.create(key('k1', cylinderId: 'cyl-1'));
    final logged = <LogEntry>[];
    final subscription = LoggerService.logStream.listen(logged.add);
    addTearDown(subscription.cancel);
    await pumpTransmitterPage(
      tester,
      buildTransmitterPage(
        diverIdNotifier,
        prefs,
        transmitterId: 'k1',
        results: results,
        overrides: [
          equipmentItemProvider(
            'cyl-1',
          ).overrideWith((ref) async => throw StateError('database closed')),
        ],
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(RecordEditBar), findsOneWidget);
    expect(
      logged.where((e) => e.message.contains('database closed')),
      isNotEmpty,
    );
  });

  testWidgets('a size with no working pressure shows in cuft, unchanged', (
    tester,
  ) async {
    await repo.create(key('k1', workingPressureBar: null));
    await open(
      tester,
      transmitterId: 'k1',
      settings: const AppSettings(
        volumeUnit: VolumeUnit.cubicFeet,
        pressureUnit: PressureUnit.psi,
      ),
    );

    // 11.1 L at the assumed 200 bar is 78.4 cuft.
    expect(find.widgetWithText(TextFormField, '78.4'), findsOneWidget);
    expect(save(tester).onPressed, isNull);
  });

  testWidgets(
    'a new key prefilled with the item serial opens with Save enabled',
    (tester) async {
      await DatabaseService.instance.database.customStatement(
        "UPDATE equipment SET serial_number = '804512' WHERE id = 'tx-gear'",
      );
      await open(tester);

      expect(find.text('804512'), findsOneWidget);
      expect(save(tester).onPressed, isNotNull);
    },
  );

  testWidgets('a new key on an item with no serial and no keys is unchanged', (
    tester,
  ) async {
    await open(tester);

    expect(find.byType(RecordEditBar), findsOneWidget);
    expect(save(tester).onPressed, isNull);
    await back(tester);
    expect(find.text('LIST'), findsOneWidget);
  });

  testWidgets('a downloaded key not yet set up opens with Save enabled', (
    tester,
  ) async {
    await repo.create(key('k1', configured: false));
    await open(tester, transmitterId: 'k1');

    expect(save(tester).onPressed, isNotNull);
    await tapSave(tester);

    expect((await repo.getById('k1'))!.isConfigured, isTrue);
    expect(find.text('LIST'), findsOneWidget);
  });

  testWidgets('Remove key is in the menu, disabled while there are changes', (
    tester,
  ) async {
    await repo.create(key('k1'));
    await open(tester, transmitterId: 'k1');
    await type(tester, 'transmitter_volume', '15');

    await openMenu(tester);
    final item = tester.widget<PopupMenuItem<int>>(
      find.byKey(const ValueKey('transmitter_remove_key')),
    );
    expect(item.enabled, isFalse);
    expect(find.text('Save or cancel your changes first'), findsOneWidget);
  });

  testWidgets('a new key has no menu', (tester) async {
    await open(tester);

    expect(find.byKey(const ValueKey('recordEditorMenu')), findsNothing);
  });

  testWidgets('the key and its siblings are one change log operation', (
    tester,
  ) async {
    await repo.create(key('k1'));
    await repo.create(key('k2'));
    await open(tester, transmitterId: 'k1');
    await type(tester, 'transmitter_volume', '15');
    await tapSave(tester);

    final written = await sittings();
    expect(written, hasLength(1));
    expect(written.single.id, 'k1');
    expect(await eventsUnder(written.single.operation, 'transmitters'), 2);
    expect((await repo.getById('k1'))!.volumeL, 15);
    expect((await repo.getById('k2'))!.volumeL, 15);
  });

  testWidgets('a sibling write that throws leaves the key as it was', (
    tester,
  ) async {
    await repo.create(key('k1'));
    await open(
      tester,
      transmitterId: 'k1',
      repository: _FailingSetupRepository(),
    );
    await type(tester, 'transmitter_volume', '15');
    await tapSave(tester);

    expect((await repo.getById('k1'))!.volumeL, 11.1);
    expect(find.text('LIST'), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(save(tester).onPressed, isNotNull);
    await expectNothingWritten();
  });

  group('a serial a download registered on another item', () {
    const serial = '76287';

    Future<Transmitter> registerFromDownload() async {
      await TransmitterAutoRegistrar(
        nameFor: (s) => 'Transmitter $s',
      ).registerNewSerials([serial], diverId: 'diver-1');
      return (await repo.getForDiver(
        'diver-1',
      )).singleWhere((t) => t.transmitterSerial == serial);
    }

    testWidgets('a takeover is labelled with the key it took over', (
      tester,
    ) async {
      final unclaimed = await registerFromDownload();
      final placeholder = unclaimed.transmitterEquipmentId!;
      await open(tester);
      await type(tester, 'transmitter_serial', serial);
      await tapSave(tester);

      final written = await sittings();
      expect(written, hasLength(1));
      expect(written.single.id, unclaimed.id);
      // The fold of the placeholder is not part of the save's entry.
      expect(await eventsUnder(written.single.operation, 'equipment'), 0);
      expect(await itemExists(placeholder), isFalse);
      expect((await repo.getForEquipment('tx-gear')).single.id, unclaimed.id);
    });

    testWidgets(
      'a clash with a set-up key shows the duplicate under the serial',
      (tester) async {
        final holder = await registerFromDownload();
        await repo.update(holder.copyWith(isConfigured: true, label: 'Stage'));
        await open(tester);
        await type(tester, 'transmitter_serial', serial);
        await tapSave(tester);

        expect(find.text('Already assigned to Stage'), findsOneWidget);
        expect(find.byType(SnackBar), findsNothing);
        expect(await repo.getForEquipment('tx-gear'), isEmpty);
        await expectNothingWritten();
        expect(save(tester).onPressed, isNotNull);
      },
    );
  });

  testWidgets('the serial copy onto the item runs after the page has gone', (
    tester,
  ) async {
    await open(tester);
    await type(tester, 'transmitter_serial', '555');
    await tapSave(tester);

    expect(find.text('LIST'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final row = await DatabaseService.instance.database
        .customSelect(
          "SELECT serial_number FROM equipment WHERE id = 'tx-gear'",
        )
        .getSingle();
    expect(row.read<String?>('serial_number'), '555');
  });

  testWidgets('Save pops with offerApply for a first setup', (tester) async {
    await open(tester);
    await type(tester, 'transmitter_serial', '555');
    await tapSave(tester);

    expect(results.single, isA<TransmitterKeySaved>());
    expect((results.single! as TransmitterKeySaved).offerApply, isTrue);
  });

  testWidgets('Save pops without offerApply for an edit', (tester) async {
    await repo.create(key('k1'));
    await open(tester, transmitterId: 'k1');
    await type(tester, 'transmitter_volume', '15');
    await tapSave(tester);

    expect((results.single! as TransmitterKeySaved).offerApply, isFalse);
  });

  testWidgets('a key deleted while open is refused at Save', (tester) async {
    await repo.create(key('k1'));
    await open(tester, transmitterId: 'k1');
    await repo.delete('k1');
    await type(tester, 'transmitter_volume', '15');
    await tapSave(tester);

    expect(find.text('This transmitter key no longer exists.'), findsOneWidget);
    expect(await repo.getForEquipment('tx-gear'), isEmpty);
  });

  testWidgets('a key that is missing says so and goes back', (tester) async {
    await open(tester, transmitterId: 'gone');

    expect(find.text('This transmitter key no longer exists.'), findsOneWidget);
    expect(find.text('LIST'), findsOneWidget);
  });

  testWidgets('Back after changing the volume asks before leaving', (
    tester,
  ) async {
    await repo.create(key('k1'));
    await open(tester, transmitterId: 'k1');
    await type(tester, 'transmitter_volume', '15');
    await back(tester);

    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('LIST'), findsOneWidget);
    expect((await repo.getById('k1'))!.volumeL, 11.1);
  });

  testWidgets('a new key typed in closes on a diver switch, writing nothing', (
    tester,
  ) async {
    await open(tester);
    await type(tester, 'transmitter_serial', '555');
    await diverIdNotifier.setCurrentDiver('diver-2');
    await tester.pumpAndSettle();

    expect(find.text('LIST'), findsOneWidget);
    expect(await repo.getForDiver('diver-1'), isEmpty);
  });
}
