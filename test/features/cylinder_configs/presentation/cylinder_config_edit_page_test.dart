import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart'
    hide CylinderConfig, CylinderConfigItem;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_configs/data/repositories/cylinder_config_repository.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config_item.dart';
import 'package:submersion/features/cylinder_configs/presentation/pages/cylinder_config_edit_page.dart';
import 'package:submersion/features/cylinder_configs/presentation/widgets/cylinder_config_item_editor.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late CylinderConfigRepository repo;
  late SharedPreferences prefs;
  final now = DateTime.utc(2026, 8, 5);

  setUp(() async {
    // settingsProvider reads SharedPreferences; without this the page throws
    // "SharedPreferences must be initialized before use".
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = await setUpTestDatabase();
    repo = CylinderConfigRepository();
    final t = now.millisecondsSinceEpoch;
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
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'rb-1',
            name: 'JJ-CCR',
            type: 'rebreather',
            // allEquipmentProvider is diver-scoped; an unowned row is
            // invisible to it.
            diverId: const Value('d1'),
            createdAt: t,
            updatedAt: t,
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  Widget host({String? configId, String? equipmentId}) => ProviderScope(
    overrides: [
      validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd1'),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
    child: MaterialApp(
      // Pinned: an unpinned locale makes text finders machine-dependent.
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: CylinderConfigEditPage(
        configId: configId,
        equipmentId: equipmentId,
      ),
    ),
  );

  testWidgets('a new configuration starts with no cylinders', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('New configuration'), findsOneWidget);
    expect(find.text('Add cylinder'), findsOneWidget);
    expect(find.text('Role'), findsNothing);
  });

  testWidgets('adding a cylinder appends a row with a role selector', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add cylinder'));
    await tester.pumpAndSettle();

    expect(find.text('Role'), findsOneWidget);
    expect(find.text('O2'), findsOneWidget);
    expect(find.text('He'), findsOneWidget);
  });

  testWidgets('saving with an empty name shows a validation error', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a name'), findsOneWidget);
  });

  testWidgets('an existing configuration loads its name and cylinders', (
    tester,
  ) async {
    final id = await repo.createConfig(diverId: 'd1', name: 'JJ trimix');
    await repo.saveItems(id, [
      CylinderConfigItem(
        id: 'i1',
        configId: id,
        tankRole: TankRole.diluent,
        o2Percent: 18,
        hePercent: 45,
        createdAt: now,
        updatedAt: now,
      ),
    ]);

    await tester.pumpWidget(host(configId: id));
    await tester.pumpAndSettle();

    expect(find.text('JJ trimix'), findsOneWidget);
    expect(find.text('18'), findsOneWidget);
    expect(find.text('45'), findsOneWidget);
  });

  testWidgets('the owning unit dropdown lists rebreathers plus a generic '
      'option', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Generic gas plan'));
    await tester.pumpAndSettle();

    expect(find.text('JJ-CCR'), findsOneWidget);
  });

  testWidgets('a wanted rebreather is not offered as the owning unit (#2025)', (
    tester,
  ) async {
    final t = now.millisecondsSinceEpoch;
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'rb-wish',
            name: 'Dream CCR',
            type: 'rebreather',
            diverId: const Value('d1'),
            status: const Value('wanted'),
            isActive: const Value(false),
            createdAt: t,
            updatedAt: t,
          ),
        );
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Generic gas plan'));
    await tester.pumpAndSettle();

    expect(find.text('JJ-CCR'), findsOneWidget);
    expect(find.text('Dream CCR'), findsNothing);
  });

  testWidgets('saving persists the configuration and its cylinders', (
    tester,
  ) async {
    await tester.pumpWidget(host(equipmentId: 'rb-1'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Bailout plan');
    await tester.tap(find.text('Add cylinder'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Scoped to the active diver, not unfiltered: a config saved with a null
    // diver_id persists but is invisible to every diver-scoped provider, so
    // an unfiltered read would pass while the feature is broken.
    final saved = await repo.getAllConfigs(diverId: 'd1', includeItems: true);
    expect(saved, hasLength(1));
    expect(saved.single.name, 'Bailout plan');
    expect(saved.single.equipmentId, 'rb-1');
    expect(saved.single.diverId, 'd1');
    expect(saved.single.cylinderCount, 1);
  });

  testWidgets('editing an existing configuration updates it in place', (
    tester,
  ) async {
    final id = await repo.createConfig(
      diverId: 'd1',
      equipmentId: 'rb-1',
      name: 'JJ trimix',
    );

    await tester.pumpWidget(host(configId: id));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'JJ air dil');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = await repo.getAllConfigs(diverId: 'd1');
    expect(saved, hasLength(1), reason: 'must not fork into a second config');
    expect(saved.single.id, id);
    expect(saved.single.name, 'JJ air dil');
    expect(saved.single.equipmentId, 'rb-1');
  });

  testWidgets('clearing the owning unit demotes a config to a gas plan', (
    tester,
  ) async {
    // The generic option is a real value, not "leave unchanged": picking it
    // must null equipment_id rather than silently keep the old unit.
    final id = await repo.createConfig(
      diverId: 'd1',
      equipmentId: 'rb-1',
      name: 'JJ trimix',
    );

    await tester.pumpWidget(host(configId: id));
    await tester.pumpAndSettle();

    await tester.tap(find.text('JJ-CCR'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Generic gas plan').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = await repo.getConfigById(id);
    expect(saved!.equipmentId, isNull);
    expect(saved.isOwnedByUnit, isFalse);
  });

  testWidgets('removing a cylinder drops it from the saved set', (
    tester,
  ) async {
    final id = await repo.createConfig(diverId: 'd1', name: 'JJ trimix');
    await repo.saveItems(id, [
      CylinderConfigItem(
        id: 'i1',
        configId: id,
        tankRole: TankRole.diluent,
        createdAt: now,
        updatedAt: now,
      ),
      CylinderConfigItem(
        id: 'i2',
        configId: id,
        tankRole: TankRole.bailout,
        createdAt: now,
        updatedAt: now,
      ),
    ]);

    await tester.pumpWidget(host(configId: id));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = await repo.getConfigById(id);
    expect(saved!.cylinderCount, 1);
    expect(saved.items.single.tankRole, TankRole.bailout);
  });

  testWidgets('an edited gas mix reaches the database on save', (tester) async {
    final id = await repo.createConfig(diverId: 'd1', name: 'JJ trimix');
    await repo.saveItems(id, [
      CylinderConfigItem(
        id: 'i1',
        configId: id,
        tankRole: TankRole.diluent,
        o2Percent: 21,
        createdAt: now,
        updatedAt: now,
      ),
    ]);

    await tester.pumpWidget(host(configId: id));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'O2'), '18');
    await tester.enterText(find.widgetWithText(TextField, 'He'), '45');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = await repo.getConfigById(id);
    expect(saved!.items.single.o2Percent, 18);
    expect(saved.items.single.hePercent, 45);
  });

  testWidgets('the first configuration a diver saves is diver-scoped', (
    tester,
  ) async {
    // Regression: diverId used to be inferred from an existing config, so the
    // very first one saved got a null diver_id and vanished from the list.
    expect(await repo.getAllConfigs(diverId: 'd1'), isEmpty);

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'First ever');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = await repo.getAllConfigs(diverId: 'd1');
    expect(saved, hasLength(1), reason: 'must be visible to its own diver');
    expect(saved.single.diverId, 'd1');
  });

  // Issue #3576: the owning-unit field means nothing to a diver without a
  // rebreather, so it only appears when there is one to choose.
  group('owning unit visibility', () {
    Future<void> removeRebreather() async {
      await (db.delete(db.equipment)..where((e) => e.id.equals('rb-1'))).go();
    }

    testWidgets('is hidden without a rebreather, and a save stays generic', (
      tester,
    ) async {
      await removeRebreather();
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      expect(find.text('For unit'), findsNothing);
      expect(find.text('Generic gas plan'), findsNothing);

      await tester.enterText(find.byType(TextFormField).first, 'OC deco');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final saved = await repo.getAllConfigs(diverId: 'd1');
      expect(saved.single.equipmentId, isNull);
    });

    testWidgets('is shown with a rebreather', (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      expect(find.text('For unit'), findsOneWidget);
    });

    testWidgets('is shown for a configuration already pointing at a unit '
        'that is not listed, so it can be made generic again', (tester) async {
      // Deleting a unit already unlinks its configurations (the FK nulls
      // equipment_id), so this is a configuration opened for a unit the
      // list no longer holds.
      await removeRebreather();
      await tester.pumpWidget(host(equipmentId: 'rb-1'));
      await tester.pumpAndSettle();

      expect(find.text('For unit'), findsOneWidget);
    });
  });

  // Issue #3576: fields were crowded on top of each other, labels over
  // inputs. At a phone width no field may overlap another.
  testWidgets('at phone width no two fields of a cylinder overlap', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final id = await repo.createConfig(diverId: 'd1', name: 'Trimix');
    await repo.saveItems(id, [
      CylinderConfigItem(
        id: 'i1',
        configId: id,
        tankRole: TankRole.backGas,
        o2Percent: 18,
        hePercent: 45,
        volumeL: 24,
        workingPressureBar: 232,
        createdAt: now,
        updatedAt: now,
      ),
    ]);

    await tester.pumpWidget(host(configId: id));
    await tester.pumpAndSettle();

    final rects = [
      for (final element in find.byType(InputDecorator).evaluate())
        tester.getRect(find.byWidget(element.widget)),
    ];
    expect(rects.length, greaterThan(6));
    for (var a = 0; a < rects.length; a++) {
      for (var b = a + 1; b < rects.length; b++) {
        final overlap = rects[a].intersect(rects[b]);
        expect(
          overlap.width > 0.5 && overlap.height > 0.5,
          isFalse,
          reason: 'field $a ${rects[a]} overlaps field $b ${rects[b]}',
        );
      }
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('on desktop no field runs under a cylinder\'s drag handle', (
    tester,
  ) async {
    final id = await repo.createConfig(diverId: 'd1', name: 'Twins');
    await repo.saveItems(id, [
      CylinderConfigItem(
        id: 'i1',
        configId: id,
        tankRole: TankRole.backGas,
        volumeL: 24,
        workingPressureBar: 232,
        createdAt: now,
        updatedAt: now,
      ),
    ]);

    await tester.pumpWidget(host(configId: id));
    await tester.pumpAndSettle();

    final handle = tester.getRect(find.byIcon(Icons.drag_handle));
    // Only the cylinder's own fields: the page's run full width above it.
    final cardFields = find.descendant(
      of: find.byType(CylinderConfigItemEditor),
      matching: find.byType(InputDecorator),
    );
    expect(cardFields, findsWidgets);
    for (final element in cardFields.evaluate()) {
      final rect = tester.getRect(find.byWidget(element.widget));
      expect(
        rect.right,
        lessThan(handle.left),
        reason: 'field $rect runs under the handle $handle',
      );
    }
  }, variant: TargetPlatformVariant.desktop());

  testWidgets('a MOD set on a cylinder reaches the database on save', (
    tester,
  ) async {
    final id = await repo.createConfig(diverId: 'd1', name: 'Deco');
    await repo.saveItems(id, [
      CylinderConfigItem(
        id: 'i1',
        configId: id,
        tankRole: TankRole.deco,
        o2Percent: 50,
        createdAt: now,
        updatedAt: now,
      ),
    ]);

    await tester.pumpWidget(host(configId: id));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'MOD'), '18');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = await repo.getConfigById(id);
    expect(saved!.items.single.decoSwitchDepth, 18);
  });

  testWidgets('a MOD set aside by a role change is gone once saved', (
    tester,
  ) async {
    final id = await repo.createConfig(diverId: 'd1', name: 'Deco');
    await repo.saveItems(id, [
      CylinderConfigItem(
        id: 'i1',
        configId: id,
        tankRole: TankRole.deco,
        o2Percent: 50,
        decoSwitchDepth: 15,
        createdAt: now,
        updatedAt: now,
      ),
    ]);

    await tester.pumpWidget(host(configId: id));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Deco').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stage').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = await repo.getConfigById(id);
    expect(saved!.items.single.tankRole, TankRole.stage);
    expect(saved.items.single.decoSwitchDepth, isNull);
  });
}
