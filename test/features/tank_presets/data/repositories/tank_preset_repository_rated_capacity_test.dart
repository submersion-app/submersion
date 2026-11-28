import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/tank_presets/data/repositories/tank_preset_repository.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';

import '../../../../helpers/test_database.dart';

/// A custom preset keeps a manufacturer's rated capacity, so a copy of a
/// built-in AL80 still reads 77.4 cuft rather than the 81 its volume and
/// pressure work out to (issue #800).
void main() {
  setUp(() async {
    await setUpTestDatabase();
    await insert(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('diver-a', 'diver-a', 1000, 1000)",
    );
  });

  tearDown(tearDownTestDatabase);

  TankPresetEntity preset({double? rated}) => TankPresetEntity.create(
    id: 'p1',
    diverId: 'diver-a',
    name: 'al80_copy',
    displayName: 'AL80 (copy)',
    volumeLiters: 11.1,
    workingPressureBar: 206.843,
    material: TankMaterial.aluminum,
    ratedCapacityCuft: rated,
  );

  test('a rated capacity is stored and read back', () async {
    final repository = TankPresetRepository();
    await repository.createPreset(preset(rated: 77.4));
    final read = await repository.getPresetById('p1');
    expect(read!.ratedCapacityCuft, 77.4);
    expect(read.volumeCuft, 77.4);
  });

  test('a preset without one works its capacity out', () async {
    final repository = TankPresetRepository();
    await repository.createPreset(preset());
    final read = await repository.getPresetById('p1');
    expect(read!.ratedCapacityCuft, isNull);
    expect(read.volumeCuft, closeTo(81.1, 0.1));
  });

  test('an update can clear it', () async {
    final repository = TankPresetRepository();
    await repository.createPreset(preset(rated: 77.4));
    final stored = (await repository.getPresetById('p1'))!;
    await repository.updatePreset(
      stored.copyWith(volumeLiters: 12, clearRatedCapacityCuft: true),
    );
    final read = await repository.getPresetById('p1');
    expect(read!.ratedCapacityCuft, isNull);
    expect(read.volumeLiters, 12);
  });
}

Future<void> insert(String sql) =>
    DatabaseService.instance.database.customStatement(sql);
