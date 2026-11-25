import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/database/database.dart'
    hide CylinderConfig, CylinderConfigItem;
import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/change_log/record_edit_label.dart';
import 'package:submersion/features/cylinder_configs/data/repositories/cylinder_config_repository.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config_item.dart';
import 'package:submersion/features/cylinder_configs/presentation/pages/cylinder_config_edit_page.dart';
import 'package:submersion/features/cylinder_configs/presentation/widgets/cylinder_config_item_editor.dart';
import 'package:submersion/features/cylinder_configs/presentation/providers/cylinder_config_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/app_bar_text_action.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_exit_blocker.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

/// A repository whose cylinder write fails, after the config row it would
/// be saved with has been written.
class _FailingItemsRepository extends CylinderConfigRepository {
  int saveItemsCalls = 0;
  bool fail = true;

  @override
  Future<void> saveItems(
    String configId,
    List<CylinderConfigItem> desired,
  ) async {
    saveItemsCalls++;
    if (fail) throw StateError('disk full');
    await super.saveItems(configId, desired);
  }
}

/// A repository whose configuration read fails, as a closed database would.
class _FailingReadRepository extends CylinderConfigRepository {
  @override
  Future<CylinderConfig?> getConfigById(
    String id, {
    bool includeItems = true,
  }) => Future.error(StateError('database closed'));
}

/// The cylinder configuration editor on the shared Cancel and Save bar
/// (issue #4527, phase 4, plan 2).
void main() {
  late AppDatabase db;
  late CylinderConfigRepository repo;
  final now = DateTime.utc(2026, 11, 22);

  setUp(() async {
    db = await setUpTestDatabase();
    repo = CylinderConfigRepository();
    for (final diver in ['d1', 'd2']) {
      await db.customStatement(
        "INSERT INTO divers (id, name, created_at, updated_at) "
        "VALUES ('$diver', '$diver', 1, 1)",
      );
    }
    await db.customStatement(
      "INSERT INTO equipment (id, diver_id, name, type, created_at, "
      "updated_at) VALUES ('rb-1', 'd1', 'JJ-CCR', 'rebreather', 1, 1)",
    );
  });
  tearDown(tearDownTestDatabase);

  CylinderConfigItem cylinder(String id, String configId, {int order = 0}) =>
      CylinderConfigItem(
        id: id,
        configId: configId,
        sortOrder: order,
        label: 'Bailout $id',
        tankRole: TankRole.bailout,
        volumeL: 11.1,
        workingPressureBar: 207,
        createdAt: now,
        updatedAt: now,
      );

  /// A stored configuration with two cylinders.
  Future<String> stored() async {
    final id = await repo.createConfig(diverId: 'd1', name: 'Cave bailout');
    await repo.saveItems(id, [cylinder('i1', id), cylinder('i2', id)]);
    return id;
  }

  late ProviderContainer container;

  /// The editor pushed over a stand-in list, on a route with the app's
  /// leave check.
  Future<void> pump(
    WidgetTester tester, {
    String? configId,
    String? equipmentId,
    AppSettings settings = const AppSettings(),
    CylinderConfigRepository? repository,
  }) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('LIST')),
          routes: [
            GoRoute(
              path: 'edit',
              onExit: confirmLeaveRecordSitting,
              builder: (_, _) => CylinderConfigEditPage(
                configId: configId,
                equipmentId: equipmentId,
              ),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => MockSettingsNotifier(settings),
          ),
          currentDiverIdProvider.overrideWith(
            (ref) => MockCurrentDiverIdNotifier(),
          ),
          validatedCurrentDiverIdProvider.overrideWith(
            (ref) async => ref.watch(currentDiverIdProvider),
          ),
          if (repository != null)
            cylinderConfigRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    container = ProviderScope.containerOf(
      tester.element(find.byType(Navigator).first),
    );
    await container.read(currentDiverIdProvider.notifier).setCurrentDiver('d1');
    await tester.pumpAndSettle();
    router.push('/edit');
    await tester.pumpAndSettle();
  }

  AppBarTextAction save(WidgetTester tester) => tester
      .widgetList<AppBarTextAction>(find.byType(AppBarTextAction))
      .firstWhere((a) => a.label == 'Save');

  Future<void> rename(WidgetTester tester, String name) async {
    await tester.enterText(find.byType(TextFormField).first, name);
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

  /// The labels of the editing sittings written: the setup's own writes
  /// are not sittings.
  Future<List<String?>> operationLabels() async {
    final rows = await db
        .customSelect(
          "SELECT label FROM change_log_operations "
          "WHERE label LIKE 'record_edit:%'",
        )
        .get();
    return [for (final row in rows) row.read<String?>('label')];
  }

  testWidgets('the bar is the tinted Cancel and Save bar with no back arrow', (
    tester,
  ) async {
    await pump(tester, configId: await stored());

    expect(find.byType(RecordEditBar), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    expect(save(tester).onPressed, isNull);
  });

  testWidgets(
    'a configuration opened in cuft and psi and left alone is unchanged',
    (tester) async {
      await pump(
        tester,
        configId: await stored(),
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

  testWidgets(
    'a new configuration with no cylinders and no name is unchanged',
    (tester) async {
      await pump(tester);

      expect(find.byType(RecordEditBar), findsOneWidget);
      expect(save(tester).onPressed, isNull);
      await back(tester);
      expect(find.text('LIST'), findsOneWidget);
    },
  );

  testWidgets('a new configuration from a unit opens with Save enabled', (
    tester,
  ) async {
    await pump(tester, equipmentId: 'rb-1');

    expect(save(tester).onPressed, isNotNull);
    await tester.tap(find.widgetWithText(AppBarTextAction, 'Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('Back after renaming asks; Discard leaves the list', (
    tester,
  ) async {
    final id = await stored();
    await pump(tester, configId: id);
    await rename(tester, 'Renamed');

    await back(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(find.text('LIST'), findsOneWidget);
    expect((await repo.getConfigById(id))!.name, 'Cave bailout');
  });

  testWidgets('reordering the cylinders is a change; reordering back is not', (
    tester,
  ) async {
    await pump(tester, configId: await stored());
    void reorder(int from, int to) => tester
        .widget<ReorderableListView>(find.byType(ReorderableListView))
        .onReorderItem!(from, to);

    reorder(0, 1);
    await tester.pumpAndSettle();
    expect(save(tester).onPressed, isNotNull);
    reorder(0, 1);
    await tester.pumpAndSettle();
    expect(save(tester).onPressed, isNull);
  });

  testWidgets('Save writes config and cylinders in one change log operation', (
    tester,
  ) async {
    final id = await stored();
    await pump(tester, configId: id);
    await rename(tester, 'Renamed');
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    await tapSave(tester);

    final saved = await repo.getConfigById(id);
    expect(saved!.name, 'Renamed');
    expect(saved.items.map((i) => i.id), ['i2']);
    final labels = await operationLabels();
    expect(labels, hasLength(1));
    final label = RecordEditLabel.decode(labels.single!);
    expect(label?.table, 'cylinder_configs');
    expect(label?.id, id);
    expect(find.text('LIST'), findsOneWidget);
  });

  testWidgets('a cylinder write that throws leaves no new configuration', (
    tester,
  ) async {
    final failing = _FailingItemsRepository();
    await pump(tester, repository: failing);
    await rename(tester, 'Doomed');
    await tester.tap(find.text('Add cylinder'));
    await tester.pumpAndSettle();
    await tapSave(tester);

    expect(failing.saveItemsCalls, 1);
    expect(await repo.getAllConfigs(), isEmpty);
    expect(find.text('LIST'), findsNothing);
    expect(find.text('Doomed'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(save(tester).onPressed, isNotNull);
  });

  testWidgets('a cylinder write that throws keeps the stored name', (
    tester,
  ) async {
    final id = await stored();
    final failing = _FailingItemsRepository();
    await pump(tester, configId: id, repository: failing);
    await rename(tester, 'Renamed');
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    await tapSave(tester);

    expect(failing.saveItemsCalls, 1);
    final kept = await repo.getConfigById(id);
    expect(kept!.name, 'Cave bailout');
    expect(kept.items, hasLength(2));
  });

  testWidgets('a new configuration is created under the page id', (
    tester,
  ) async {
    await pump(tester);
    final pageId =
        (tester.state(find.byType(CylinderConfigEditPage)) as dynamic)
                .newEditorRecordId
            as String;
    await rename(tester, 'Fresh');
    await tapSave(tester);

    final all = await repo.getAllConfigs(diverId: 'd1');
    expect(all.single.id, pageId);
    expect(all.single.diverId, 'd1');
  });

  testWidgets('a rename keeps a cylinder changed in storage meanwhile', (
    tester,
  ) async {
    final id = await stored();
    final counting = _FailingItemsRepository()..fail = false;
    await pump(tester, configId: id, repository: counting);
    await db.customStatement(
      "UPDATE cylinder_config_items SET volume_l = 15 WHERE id = 'i1'",
    );
    await rename(tester, 'Renamed');
    await tapSave(tester);

    expect(counting.saveItemsCalls, 0);
    final saved = await repo.getConfigById(id);
    expect(saved!.name, 'Renamed');
    expect(saved.items.first.volumeL, 15);
  });

  testWidgets('an untouched cylinder keeps what storage gave it meanwhile', (
    tester,
  ) async {
    final id = await stored();
    await pump(tester, configId: id);
    await db.customStatement(
      "UPDATE cylinder_config_items SET volume_l = 15 WHERE id = 'i1'",
    );
    // A change to the other cylinder: the cylinders are written.
    await tester.tap(find.byIcon(Icons.delete_outline).last);
    await tester.pumpAndSettle();
    await tapSave(tester);

    final saved = await repo.getConfigById(id);
    expect(saved!.items.single.id, 'i1');
    expect(saved.items.single.volumeL, 15);
  });

  testWidgets('a cylinder deleted elsewhere and left alone stays deleted', (
    tester,
  ) async {
    final id = await stored();
    await pump(tester, configId: id);
    // Another device removes i1 while the diver edits i2.
    await db.customStatement(
      "DELETE FROM cylinder_config_items WHERE id = 'i1'",
    );
    await tester.enterText(find.widgetWithText(TextField, 'O2').last, '32');
    await tester.pumpAndSettle();
    await tapSave(tester);

    final saved = await repo.getConfigById(id);
    expect(saved!.items.map((i) => i.id), ['i2']);
    expect(saved.items.single.o2Percent, 32);
  });

  testWidgets('a cylinder added elsewhere survives a change to the others', (
    tester,
  ) async {
    final id = await stored();
    await pump(tester, configId: id);
    // Another device adds i3 while the diver edits i2.
    await db.customStatement(
      "INSERT INTO cylinder_config_items (id, config_id, sort_order, "
      "tank_role, o2_percent, he_percent, created_at, updated_at) "
      "VALUES ('i3', '$id', 2, 'stage', 50, 0, 1, 1)",
    );
    await tester.enterText(find.widgetWithText(TextField, 'O2').last, '32');
    await tester.pumpAndSettle();
    await tapSave(tester);

    final saved = await repo.getConfigById(id);
    expect(saved!.items.map((i) => i.id), ['i1', 'i2', 'i3']);
  });

  testWidgets('an edited cylinder keeps what storage gave its hidden fields', (
    tester,
  ) async {
    final id = await stored();
    await pump(tester, configId: id);
    // Another device sets fields this editor does not show on i1, while the
    // diver changes i1's label and size.
    await db.customStatement(
      "UPDATE cylinder_config_items SET tank_material = 'steel', "
      "default_start_pressure_bar = 200 WHERE id = 'i1'",
    );
    await tester.enterText(
      find.byKey(CylinderConfigItemEditor.labelFieldKey).first,
      'Left bailout',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Volume').first,
      '12',
    );
    await tester.pumpAndSettle();
    await tapSave(tester);

    final saved = (await repo.getConfigById(id))!.items.first;
    expect(saved.label, 'Left bailout');
    expect(saved.volumeL, 12);
    expect(saved.workingPressureBar, 207);
    expect(saved.tankMaterial, TankMaterial.steel);
    expect(saved.defaultStartPressureBar, 200);
  });

  testWidgets('a changed pressure in litres keeps the stored size', (
    tester,
  ) async {
    final id = await stored();
    await pump(tester, configId: id);
    await db.customStatement(
      "UPDATE cylinder_config_items SET volume_l = 15 WHERE id = 'i1'",
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Working P').first,
      '232',
    );
    await tester.pumpAndSettle();
    await tapSave(tester);

    final saved = (await repo.getConfigById(id))!.items.first;
    expect(saved.workingPressureBar, 232);
    expect(saved.volumeL, 15);
  });

  testWidgets('a configuration deleted while open is refused at Save', (
    tester,
  ) async {
    final id = await stored();
    await pump(tester, configId: id);
    await repo.deleteConfig(id);
    await rename(tester, 'Renamed');
    await tapSave(tester);

    expect(find.text('This configuration no longer exists.'), findsOneWidget);
    expect(await repo.getConfigById(id), isNull);
    expect(await repo.getAllConfigs(), isEmpty);
  });

  testWidgets('a configuration that fails to load says so, logs why and goes '
      'back', (tester) async {
    final logged = <LogEntry>[];
    final subscription = LoggerService.logStream.listen(logged.add);
    addTearDown(subscription.cancel);
    await pump(tester, configId: 'c1', repository: _FailingReadRepository());

    expect(find.text('LIST'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(
      logged.where((e) => e.message.contains('database closed')),
      isNotEmpty,
    );
  });

  testWidgets('a configuration that is missing says so and goes back', (
    tester,
  ) async {
    await pump(tester, configId: 'gone');

    expect(find.text('This configuration no longer exists.'), findsOneWidget);
    expect(find.text('LIST'), findsOneWidget);
  });

  testWidgets('a new configuration closes on a diver switch, writing nothing', (
    tester,
  ) async {
    await pump(tester);
    await rename(tester, 'Not yours');
    await container.read(currentDiverIdProvider.notifier).setCurrentDiver('d2');
    await tester.pumpAndSettle();

    expect(find.text('LIST'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(await repo.getAllConfigs(), isEmpty);
  });
}
