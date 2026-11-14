import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_configs/data/repositories/cylinder_config_repository.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config_item.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_prefill.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/features/weight_presets/data/repositories/weight_preset_repository.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Using an equipment set in the dive editor applies its weights and
/// cylinders as well as its gear (issue #4525).
void main() {
  late AppDatabase db;
  late DiveRepository dives;
  late EquipmentSetRepository sets;
  late String diverId;
  late String belt8;
  late String belt6;
  late String al80;
  final now = DateTime(2026, 11, 1);

  EquipmentSet set(
    String id,
    String name, {
    List<String> gear = const [],
    List<String> includes = const [],
    List<String> presets = const [],
    List<String> configs = const [],
  }) => EquipmentSet(
    id: id,
    diverId: diverId,
    name: name,
    equipmentIds: gear,
    includedSetIds: includes,
    weightPresetIds: presets,
    cylinderConfigIds: configs,
    createdAt: now,
    updatedAt: now,
  );

  setUp(() async {
    db = await setUpTestDatabase();
    dives = DiveRepository();
    sets = EquipmentSetRepository();
    diverId = (await DiverRepository().createDiver(
      Diver(id: '', name: 'Tester', createdAt: now, updatedAt: now),
    )).id;
    final equipment = EquipmentRepository();
    for (final (id, name) in [
      ('bp', 'Steel backplate'),
      ('reg', 'Apeks XTX50'),
      ('cam', 'Camera housing'),
    ]) {
      await equipment.createEquipment(
        EquipmentItem(
          id: id,
          diverId: diverId,
          name: name,
          type: EquipmentType.other,
        ),
        notify: false,
      );
    }
    final presets = WeightPresetRepository();
    belt8 = (await presets.createPreset(
      diverId: diverId,
      displayName: 'Belt 8',
      entries: const [
        (weightType: WeightType.belt, amountKg: 3.63, notes: '', label: ''),
      ],
    )).id;
    belt6 = (await presets.createPreset(
      diverId: diverId,
      displayName: 'Pockets 6',
      entries: const [
        (
          weightType: WeightType.backplate,
          amountKg: 2.72,
          notes: '',
          label: '',
        ),
      ],
    )).id;
    final configs = CylinderConfigRepository();
    al80 = await configs.createConfig(diverId: diverId, name: 'AL80 EAN32');
    await configs.saveItems(al80, [
      CylinderConfigItem(
        id: '',
        configId: al80,
        tankRole: TankRole.backGas,
        volumeL: 11.1,
        workingPressureBar: 207,
        o2Percent: 32,
        createdAt: now,
        updatedAt: now,
      ),
    ]);
  });

  tearDown(() async => tearDownTestDatabase());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpEditor(
    WidgetTester tester, {
    String? diveId,
    DivePrefill? prefill,
  }) async {
    tester.view.physicalSize = const Size(1000, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final base = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base.cast<Override>(),
          diveRepositoryProvider.overrideWithValue(dives),
          diveListNotifierProvider.overrideWith(
            (ref) => DiveListNotifier(dives, ref),
          ),
          customTankPresetsProvider.overrideWith((ref) async => []),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => diverId),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DiveEditPage(
              diveId: diveId,
              embedded: true,
              prefill: prefill,
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DiveEditPage)),
    );
    await container
        .read(currentDiverIdProvider.notifier)
        .setCurrentDiver(diverId);
    await settle(tester);
  }

  /// Opens the Gas & Gear section, whose header names the tanks.
  Future<void> openGasGear(WidgetTester tester) async {
    if (find.text('Use Set').evaluate().isNotEmpty) return;
    final header = find.textContaining(RegExp(r'\d+ tanks?\b')).first;
    await tester.ensureVisible(header);
    await settle(tester);
    await tester.tap(header);
    await settle(tester);
  }

  Future<void> useSet(WidgetTester tester, String name) async {
    await openGasGear(tester);
    final button = find.text('Use Set');
    await tester.ensureVisible(button);
    await settle(tester);
    await tester.tap(button);
    await settle(tester);
    await tester.tap(find.text(name).last);
    await settle(tester);
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Save'));
    await settle(tester);
  }

  Future<Map<String, String?>> gearOn(String diveId) async {
    final rows = await (db.select(
      db.diveEquipment,
    )..where((r) => r.diveId.equals(diveId))).get();
    return {for (final r in rows) r.equipmentId: r.viaSetId};
  }

  Future<Dive> emptyDive({List<DiveWeight> weights = const []}) =>
      dives.createDive(
        Dive(
          id: '',
          diverId: diverId,
          dateTime: DateTime(2026, 3, 1, 10),
          weights: weights,
        ),
      );

  const fourKilos = DiveWeight(
    id: 'w1',
    diveId: '',
    weightType: WeightType.belt,
    amountKg: 4.0,
  );

  testWidgets('picking a set fills an empty Weights section and tags '
      'the gear', (tester) async {
    await sets.createSet(
      set('rig', 'BP rig', gear: ['bp', 'reg'], presets: [belt8]),
    );
    final dive = await emptyDive();
    await pumpEditor(tester, diveId: dive.id);

    await useSet(tester, 'BP rig');
    expect(find.textContaining('Use the weights from'), findsNothing);
    await save(tester);

    final reloaded = (await dives.getDiveById(dive.id))!;
    expect(reloaded.weights.single.amountKg, closeTo(3.63, 1e-9));
    expect(await gearOn(dive.id), {'bp': 'rig', 'reg': 'rig'});
  });

  group('on a dive that already has weights', () {
    late Dive dive;

    Future<void> pick(WidgetTester tester, String answer) async {
      await sets.createSet(
        set('rig', 'BP rig', gear: ['bp'], presets: [belt8]),
      );
      dive = await emptyDive(weights: const [fourKilos]);
      await pumpEditor(tester, diveId: dive.id);
      await useSet(tester, 'BP rig');
      expect(find.text('Use the weights from BP rig?'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(answer),
        ),
      );
      await settle(tester);
      await save(tester);
    }

    testWidgets('Add appends the set\'s weights', (tester) async {
      await pick(tester, 'Add');
      final weights = (await dives.getDiveById(dive.id))!.weights;
      expect(weights.map((w) => w.amountKg), [4.0, closeTo(3.63, 1e-9)]);
    });

    testWidgets('Replace swaps them', (tester) async {
      await pick(tester, 'Replace');
      final weights = (await dives.getDiveById(dive.id))!.weights;
      expect(weights.single.amountKg, closeTo(3.63, 1e-9));
    });

    testWidgets('Keep current leaves them and still adds the gear', (
      tester,
    ) async {
      await pick(tester, 'Keep current');
      final weights = (await dives.getDiveById(dive.id))!.weights;
      expect(weights.single.amountKg, 4.0);
      expect(await gearOn(dive.id), {'bp': 'rig'});
    });
  });

  testWidgets('a set with only weights can be picked', (tester) async {
    await sets.createSet(set('lead', 'Lead only', presets: [belt6]));
    final dive = await emptyDive();
    await pumpEditor(tester, diveId: dive.id);

    await useSet(tester, 'Lead only');
    await save(tester);

    final reloaded = (await dives.getDiveById(dive.id))!;
    expect(reloaded.weights.single.amountKg, closeTo(2.72, 1e-9));
    expect(await gearOn(dive.id), isEmpty);
  });

  group('a new dive with a default set', () {
    setUp(() async {
      await sets.createSet(
        set(
          'rig',
          'BP rig',
          gear: ['bp', 'reg'],
          presets: [belt8],
          configs: [al80],
        ),
      );
      await sets.setAsDefault('rig', diverId: diverId);
    });

    Future<Dive> savedDive() async {
      final all = await dives.getAllDives(diverId: diverId);
      return (await dives.getDiveById(all.single.id))!;
    }

    testWidgets('gets its gear and weights, and the starter tank becomes '
        'the set\'s cylinder with its gas', (tester) async {
      await pumpEditor(tester);
      await save(tester);

      final dive = await savedDive();
      expect(dive.weights.single.amountKg, closeTo(3.63, 1e-9));
      expect(dive.tanks, hasLength(1));
      expect(dive.tanks.single.gasMix.o2, 32);
      expect(dive.tanks.single.volume, closeTo(11.1, 1e-9));
      expect(await gearOn(dive.id), {'bp': 'rig', 'reg': 'rig'});
    });

    // A scanned log page or a cylinder tag fills the first tank before the
    // default set lands; that tank is the diver's data, not a starter.
    testWidgets('a tank prefilled from a scan keeps its gas and pressures', (
      tester,
    ) async {
      await pumpEditor(
        tester,
        prefill: const DivePrefill(
          startPressureBar: 200,
          endPressureBar: 50,
          o2Percent: 36,
        ),
      );
      await save(tester);

      final dive = await savedDive();
      expect(dive.tanks, hasLength(1));
      expect(dive.tanks.single.gasMix.o2, 36);
      expect(dive.tanks.single.startPressure, 200);
      expect(dive.tanks.single.endPressure, 50);
      // The set still brings its gear and lead.
      expect(dive.weights.single.amountKg, closeTo(3.63, 1e-9));
      expect(await gearOn(dive.id), {'bp': 'rig', 'reg': 'rig'});
    });

    testWidgets('a tank prefilled from a cylinder tag keeps its mix and '
        'passport', (tester) async {
      await pumpEditor(
        tester,
        prefill: const DivePrefill(
          tank: DiveTank(
            id: 'tag',
            gasMix: GasMix(o2: 28),
            passportId: 'pass-1',
          ),
        ),
      );
      await save(tester);

      final dive = await savedDive();
      expect(dive.tanks, hasLength(1));
      expect(dive.tanks.single.gasMix.o2, 28);
      expect(dive.tanks.single.passportId, 'pass-1');
    });

    testWidgets('picking a set that includes it shows one set and replaces '
        'its weights without asking', (tester) async {
      await sets.createSet(
        set(
          'camrig',
          'BP + camera',
          gear: ['cam'],
          includes: ['rig'],
          presets: [belt6],
        ),
      );
      await pumpEditor(tester);

      await useSet(tester, 'BP + camera');
      expect(find.textContaining('Use the weights from'), findsNothing);
      await save(tester);

      final dive = await savedDive();
      // Everything adds up: the rig's belt, then the camera set's pockets.
      expect(dive.weights.map((w) => w.amountKg), [
        closeTo(3.63, 1e-9),
        closeTo(2.72, 1e-9),
      ]);
      expect((await gearOn(dive.id)).values.toSet(), {'camrig'});
      expect((await gearOn(dive.id)).keys.toSet(), {'bp', 'reg', 'cam'});
      // The rig's cylinder is there once.
      expect(dive.tanks, hasLength(1));
    });
  });
}
