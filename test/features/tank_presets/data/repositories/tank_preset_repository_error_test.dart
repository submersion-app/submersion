import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/tank_presets/data/repositories/tank_preset_repository.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';

import '../../../../helpers/test_database.dart';

void main() {
  group('TankPresetRepository error handling', () {
    late TankPresetRepository repository;

    setUp(() async {
      await setUpTestDatabase();
      repository = TankPresetRepository();
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    test('methods handle database errors gracefully', () async {
      await DatabaseService.instance.database.close();
      DatabaseService.instance.resetForTesting();

      final now = DateTime.now();
      final preset = TankPresetEntity(
        id: 'tp1',
        diverId: 'diver1',
        name: 'custom_al80',
        displayName: 'Custom AL80',
        volumeLiters: 11.1,
        workingPressureBar: 207,
        material: TankMaterial.aluminum,
        createdAt: now,
        updatedAt: now,
      );

      // getAllPresets - rethrows
      await expectLater(
        repository.getAllPresets(diverId: 'diver1'),
        throwsA(anything),
      );

      // getCustomPresets - rethrows
      await expectLater(
        repository.getCustomPresets(diverId: 'diver1'),
        throwsA(anything),
      );

      // getPresetById - rethrows
      await expectLater(repository.getPresetById('tp1'), throwsA(anything));

      // getPresetByName - rethrows
      await expectLater(
        repository.getPresetByName('Custom AL80'),
        throwsA(anything),
      );

      // createPreset - rethrows
      await expectLater(repository.createPreset(preset), throwsA(anything));

      // updatePreset - rethrows
      await expectLater(repository.updatePreset(preset), throwsA(anything));

      // deletePreset - rethrows
      await expectLater(repository.deletePreset('tp1'), throwsA(anything));
    });
  });
}
