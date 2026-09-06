import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/weight_presets/data/repositories/weight_preset_repository.dart';

import '../../helpers/test_database.dart';

DiveWeight _w(WeightType type, double kg) =>
    DiveWeight(id: '', diveId: '', weightType: type, amountKg: kg);

void main() {
  late WeightPresetRepository repo;
  late String diverId;
  late String otherDiverId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await setUpTestDatabase();
    repo = WeightPresetRepository();
    final divers = DiverRepository();
    final now = DateTime.now();
    diverId = (await divers.createDiver(
      Diver(id: '', name: 'A', createdAt: now, updatedAt: now),
    )).id;
    otherDiverId = (await divers.createDiver(
      Diver(id: '', name: 'B', createdAt: now, updatedAt: now),
    )).id;
  });

  tearDown(() async => tearDownTestDatabase());

  test(
    'createFromWeights stores a named, diver-scoped preset with entries',
    () async {
      final preset = await repo.createFromWeights(
        diverId: diverId,
        displayName: '  Drysuit  ',
        weights: [_w(WeightType.belt, 3.0), _w(WeightType.integrated, 1.5)],
        notes: 'winter',
      );

      expect(preset.displayName, 'Drysuit');
      expect(preset.notes, 'winter');
      expect(preset.diverId, diverId);
      expect(preset.entries, hasLength(2));
      expect(preset.totalKg, closeTo(4.5, 1e-9));
      expect(preset.entries.map((e) => e.weightType).toSet(), {
        WeightType.belt,
        WeightType.integrated,
      });
      // Ordered by sortOrder = insertion order.
      expect(preset.entries.map((e) => e.sortOrder).toList(), [0, 1]);

      expect(await repo.getPresets(diverId: diverId), hasLength(1));
      expect(await repo.getPresets(diverId: otherDiverId), isEmpty);
      expect(await repo.getPresets(diverId: null), isEmpty);
    },
  );

  test('renamePreset changes the name and leaves entries untouched', () async {
    final preset = await repo.createFromWeights(
      diverId: diverId,
      displayName: 'Old',
      weights: [_w(WeightType.belt, 2.0)],
    );

    await repo.renamePreset(id: preset.id, displayName: 'New');

    final reloaded = (await repo.getPresets(diverId: diverId)).single;
    expect(reloaded.displayName, 'New');
    expect(reloaded.entries, hasLength(1));
  });

  test('deletePreset removes the preset and cascades its entries', () async {
    final preset = await repo.createFromWeights(
      diverId: diverId,
      displayName: 'Gone',
      weights: [_w(WeightType.belt, 2.0), _w(WeightType.ankleWeights, 0.5)],
    );

    await repo.deletePreset(preset.id);

    expect(await repo.getPresets(diverId: diverId), isEmpty);
    final db = DatabaseService.instance.database;
    final entryCount = await db
        .customSelect('SELECT COUNT(*) AS n FROM weight_preset_entries')
        .getSingle();
    expect(entryCount.read<int>('n'), 0);
    // Deletion is logged for sync (preset + each entry), not a silent drop.
    final tombstones = await db
        .customSelect(
          "SELECT COUNT(*) AS n FROM deletion_log "
          "WHERE entity_type IN ('weightPresets', 'weightPresetEntries')",
        )
        .getSingle();
    expect(tombstones.read<int>('n'), 3);
  });
}
