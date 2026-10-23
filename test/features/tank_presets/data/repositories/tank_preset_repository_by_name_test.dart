import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/tank_presets/data/repositories/tank_preset_repository.dart';

import '../../../../helpers/test_database.dart';

/// A custom preset belongs to one diver, and the default tank preset is a
/// per-diver setting that names it. Two profiles holding a preset of the same
/// name (a copied profile, issue #3343) once made the by-name lookup throw
/// "Too many elements" and fail every import; a lookup that is not scoped to
/// the diver hands one diver the other's cylinder instead.
void main() {
  setUp(() async {
    await setUpTestDatabase();
    for (final id in ['diver-a', 'diver-b']) {
      await insert(
        "INSERT INTO divers (id, name, created_at, updated_at) "
        "VALUES ('$id', '$id', 1000, 1000)",
      );
    }
  });

  tearDown(tearDownTestDatabase);

  Future<void> insertPreset(
    String id,
    String diverId,
    String name,
    double volume,
  ) => insert(
    "INSERT INTO tank_presets (id, diver_id, name, display_name, "
    "volume_liters, working_pressure_bar, material, created_at, updated_at) "
    "VALUES ('$id', '$diverId', '$name', '$name', $volume, 232, 'steel', "
    "1000, 1000)",
  );

  test('two divers sharing a preset name each get their own', () async {
    await insertPreset('dubbel_7', 'diver-a', 'dubbel_7', 14);
    await insertPreset('dubbel_7_1a2b3c4d', 'diver-b', 'dubbel_7', 7);
    final repository = TankPresetRepository();

    final forA = await repository.getPresetByName(
      'dubbel_7',
      diverId: 'diver-a',
    );
    final forB = await repository.getPresetByName(
      'dubbel_7',
      diverId: 'diver-b',
    );

    expect(forA?.id, 'dubbel_7');
    expect(forA?.volumeLiters, 14);
    expect(forB?.id, 'dubbel_7_1a2b3c4d');
    expect(forB?.volumeLiters, 7);
  });

  test('another diver\'s preset never matches', () async {
    await insertPreset('dubbel_7', 'diver-a', 'dubbel_7', 14);

    final found = await TankPresetRepository().getPresetByName(
      'dubbel_7',
      diverId: 'diver-b',
    );

    expect(found, isNull);
  });

  test('a diver\'s own preset shadows the built-in of that name', () async {
    await insertPreset('my_al80', 'diver-a', 'al80', 12);

    final found = await TankPresetRepository().getPresetByName(
      'al80',
      diverId: 'diver-a',
    );

    expect(found?.id, 'my_al80');
    expect(found?.isBuiltIn, isFalse);
  });

  test('another diver\'s shadowing preset leaves the built-in', () async {
    await insertPreset('my_al80', 'diver-a', 'al80', 12);

    final found = await TankPresetRepository().getPresetByName(
      'al80',
      diverId: 'diver-b',
    );

    expect(found?.isBuiltIn, isTrue);
    expect(found?.volumeLiters, 11.1);
  });

  test('without a diver only built-ins match', () async {
    await insertPreset('dubbel_7', 'diver-a', 'dubbel_7', 14);
    final repository = TankPresetRepository();

    expect(await repository.getPresetByName('dubbel_7', diverId: null), isNull);
    expect(
      (await repository.getPresetByName('al80', diverId: null))?.isBuiltIn,
      isTrue,
    );
  });
}

Future<void> insert(String sql) =>
    DatabaseService.instance.database.customStatement(sql);
