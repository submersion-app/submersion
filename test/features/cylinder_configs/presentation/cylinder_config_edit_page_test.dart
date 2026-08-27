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
    expect(find.text('O2 %'), findsOneWidget);
    expect(find.text('He %'), findsOneWidget);
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

    await tester.enterText(find.widgetWithText(TextField, 'O2 %'), '18');
    await tester.enterText(find.widgetWithText(TextField, 'He %'), '45');
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
}
