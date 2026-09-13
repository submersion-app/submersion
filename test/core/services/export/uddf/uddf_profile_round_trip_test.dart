import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/models/uddf_export_options.dart';
import 'package:submersion/core/services/export/uddf/uddf_dives_extras.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_service.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_roles/data/repositories/dive_role_repository.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_component_repository.dart';

import '../../../../helpers/test_database.dart';
import '../../../../helpers/uddf_restore.dart';

/// Issue #1874: a dives-only UDDF export, restored into a clean database,
/// brings back the dive's recorded profile, its cylinders and each
/// cylinder's own sample pressures.
const _diverId = 'me';

Future<void> _createDiver() async {
  final now = DateTime.utc(2026, 3, 1);
  await DiverRepository().createDiver(
    Diver(
      id: _diverId,
      name: 'Me',
      isDefault: true,
      createdAt: now,
      updatedAt: now,
    ),
  );
}

/// The dive the restored one comes back as, profile and tanks hydrated.
Future<Dive> _restoredDive() async {
  final repository = DiveRepository();
  final listed = (await repository.getAllDives(diverId: _diverId)).single;
  return (await repository.getDiveById(listed.id))!;
}

void main() {
  setUp(() async {
    await setUpTestDatabase();
    await _createDiver();
  });

  tearDown(tearDownTestDatabase);

  test('a dives-only export restores the profile, cylinders and each '
      "cylinder's pressures", () async {
    await DiveRepository().createDive(
      Dive(
        id: 'dive-a',
        diverId: _diverId,
        diveNumber: 1,
        dateTime: DateTime.utc(2026, 3, 1, 9),
        tanks: const [
          DiveTank(
            id: 'tank-a',
            volume: 11.1,
            startPressure: 200,
            endPressure: 170,
            gasMix: GasMix(o2: 32),
          ),
          DiveTank(
            id: 'tank-b',
            volume: 5.7,
            startPressure: 210,
            endPressure: 200,
            gasMix: GasMix(o2: 50),
            role: TankRole.deco,
            order: 1,
          ),
        ],
        profile: const [
          DiveProfilePoint(timestamp: 10, depth: 4.5, temperature: 21.0),
          DiveProfilePoint(timestamp: 60, depth: 12.0, temperature: 20.0),
          DiveProfilePoint(timestamp: 120, depth: 6.0, temperature: 20.5),
        ],
      ),
    );
    await TankPressureRepository().insertTankPressures('dive-a', {
      'tank-a': [
        (timestamp: 10, pressure: 200.0),
        (timestamp: 60, pressure: 185.0),
        (timestamp: 120, pressure: 170.0),
      ],
      'tank-b': [
        (timestamp: 10, pressure: 210.0),
        (timestamp: 60, pressure: 210.0),
        (timestamp: 120, pressure: 200.0),
      ],
    });

    // What the dive list's bulk export hands the writer: the selected dives
    // and the extras the export actions fetch.
    const options = UddfExportOptions();
    final xml = await UddfExportService().generateDivesUddfContent(
      await DiveRepository().getDivesByIds(['dive-a']),
      extras: await resolveDivesExtras(
        BuddyRepository(),
        EquipmentComponentRepository(),
        DiveRoleRepository(),
        TankPressureRepository(),
        _diverId,
        ['dive-a'],
        options,
      ),
      options: options,
    );

    await tearDownTestDatabase();
    await setUpTestDatabase();
    await _createDiver();
    await restoreUddfDives(xml, diverId: _diverId);

    final restored = await _restoredDive();
    expect(restored.profile.map((p) => (p.timestamp, p.depth, p.temperature)), [
      (10, 4.5, 21.0),
      (60, 12.0, 20.0),
      (120, 6.0, 20.5),
    ]);

    final tanks = [...restored.tanks]..sort((a, b) => a.order - b.order);
    expect(tanks.map((t) => (t.gasMix.o2, t.startPressure, t.endPressure)), [
      (32.0, 200.0, 170.0),
      (50.0, 210.0, 200.0),
    ]);
    expect(tanks.map((t) => t.volume), [
      closeTo(11.1, 1e-9),
      closeTo(5.7, 1e-9),
    ]);

    final pressures = await TankPressureRepository().getTankPressuresForDive(
      restored.id,
    );
    List<(int, double)> seriesOf(DiveTank tank) => [
      for (final p in pressures[tank.id]!) (p.timestamp, p.pressure),
    ];
    expect(seriesOf(tanks[0]), [(10, 200.0), (60, 185.0), (120, 170.0)]);
    expect(seriesOf(tanks[1]), [(10, 210.0), (60, 210.0), (120, 200.0)]);
  });
}
