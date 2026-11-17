import 'package:submersion/core/providers/provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config_item.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_prefill.dart';
import 'package:submersion/features/dive_log/domain/entities/new_dive_request.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_header_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/new_dive_seed.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/set_bundle.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/set_bundle_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../../../helpers/mock_providers.dart';
import '../../../../../../helpers/test_database.dart';

/// What a new dive's sitting starts from: today's defaults, none of them a
/// change (issue #4527, plan 8).
void main() {
  final t0 = DateTime.utc(2026, 3, 9);
  DateTime opened() => DateTime(2026, 11, 17, 9, 30, 41);

  const wing = EquipmentItem(
    id: 'wing',
    name: 'Wing',
    type: EquipmentType.wing,
  );
  final usual = EquipmentSet(
    id: 'usual',
    name: 'Usual',
    equipmentIds: const ['wing'],
    isDefault: true,
    items: const [wing],
    createdAt: t0,
    updatedAt: t0,
  );

  late ProviderContainer container;

  ProviderContainer containerWith({
    List<EquipmentSet> sets = const [],
    SetBundle? bundle,
    bool setsFail = false,
  }) {
    final c = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
        equipmentSetSelectionInputsProvider.overrideWith((ref) async {
          if (setsFail) throw StateError('no sets');
          return EquipmentSetSelectionInputs(sets: sets, geofences: const []);
        }),
        if (bundle != null)
          setBundleProvider(bundle.setId).overrideWith((ref) async => bundle),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() async {
    final db = await setUpTestDatabase();
    await db.customStatement(
      'INSERT INTO divers (id, name, created_at, updated_at) '
      "VALUES ('me', 'Me', 0, 0)",
    );
    await DiveRepository().createDive(
      Dive(id: 'old', diverId: 'me', diveNumber: 42, dateTime: t0),
    );
    container = containerWith();
  });
  tearDown(tearDownTestDatabase);

  test('a new dive starts now, numbered, with the default cylinder', () async {
    final seed = await newDiveSeed(
      container.read,
      const NewDiveRequest(),
      now: opened,
    );

    expect(seed.id, isNotEmpty);
    expect(seed.diverId, 'me');
    expect(seed.diveNumber, 43);
    expect(seed.isPlanned, isFalse);
    final tank = seed.tanks.single;
    expect(tank.volume, 11.1); // AL80, the default preset
    expect(tank.presetName, 'al80');
    expect(tank.startPressure, 200.0);
    expect(tank.role, TankRole.backGas);
  });

  test('the entry reads back as the minute it was opened', () async {
    final seed = await newDiveSeed(
      container.read,
      const NewDiveRequest(),
      now: opened,
    );

    final entry = diveEntryField.read(seed);
    expect(entry, DateTime.utc(2026, 11, 17, 9, 30));
    expect(seed.dateTime, entry);
  });

  test('each new dive has an id of its own', () async {
    final a = await newDiveSeed(container.read, const NewDiveRequest());
    final b = await newDiveSeed(container.read, const NewDiveRequest());
    expect(a.id, isNot(b.id));
  });

  // Where the dive came from is not an entry: a scan's dive keeps it.
  test('a scanned dive keeps its import source', () async {
    final seed = await newDiveSeed(
      container.read,
      const NewDiveRequest(prefill: DivePrefill(importSource: 'ocr')),
    );
    expect(seed.importSource, 'ocr');
  });

  test('a planned dive has no number', () async {
    final seed = await newDiveSeed(
      container.read,
      const NewDiveRequest(prefill: DivePrefill(isPlanned: true)),
    );
    expect(seed.isPlanned, isTrue);
    expect(seed.diveNumber, isNull);
  });

  test('the default equipment set is on the seed', () async {
    container = containerWith(
      sets: [usual],
      bundle: const SetBundle(setId: 'usual', gearIds: ['wing']),
    );
    final seed = await newDiveSeed(container.read, const NewDiveRequest());
    expect(seed.gear.map((g) => g.item.id), ['wing']);
    expect(seed.tanks, hasLength(1));
  });

  test(
    'a set that brings the main cylinder takes the starter\'s place',
    () async {
      container = containerWith(
        sets: [usual],
        bundle: SetBundle(
          setId: 'usual',
          gearIds: const ['wing'],
          cylinders: [
            CylinderConfigItem(
              id: 'c1',
              configId: 'cfg',
              tankRole: TankRole.backGas,
              volumeL: 15.0,
              workingPressureBar: 232,
              createdAt: t0,
              updatedAt: t0,
            ),
          ],
        ),
      );
      final seed = await newDiveSeed(container.read, const NewDiveRequest());
      expect(seed.tanks.single.volume, 15.0);
    },
  );

  test('a set with only a stage adds it beside the starter', () async {
    container = containerWith(
      sets: [usual],
      bundle: SetBundle(
        setId: 'usual',
        gearIds: const ['wing'],
        cylinders: [
          CylinderConfigItem(
            id: 'c1',
            configId: 'cfg',
            tankRole: TankRole.stage,
            volumeL: 5.7,
            workingPressureBar: 207,
            createdAt: t0,
            updatedAt: t0,
          ),
        ],
      ),
    );
    final seed = await newDiveSeed(container.read, const NewDiveRequest());
    expect(seed.tanks.map((t) => t.volume), [11.1, 5.7]);
    expect(seed.tanks.map((t) => t.order), [0, 1]);
  });

  test('equipment sets that cannot be read leave none', () async {
    container = containerWith(setsFail: true);
    final seed = await newDiveSeed(container.read, const NewDiveRequest());
    expect(seed.gear, isEmpty);
    expect(seed.tanks, hasLength(1));
  });

  // A number is the diver's next one: with the diver unknown, none is
  // guessed from every diver's log, and Save numbers the dive in its own
  // (review of #4672).
  test('a diver that cannot be read leaves the number for Save', () async {
    final c = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        validatedCurrentDiverIdProvider.overrideWith(
          (ref) async => throw StateError('no database'),
        ),
        equipmentSetSelectionInputsProvider.overrideWith(
          (ref) async =>
              const EquipmentSetSelectionInputs(sets: [], geofences: []),
        ),
      ],
    );
    addTearDown(c.dispose);
    final seed = await newDiveSeed(c.read, const NewDiveRequest());
    expect(seed.diverId, isNull);
    expect(seed.diveNumber, isNull);
  });
}
