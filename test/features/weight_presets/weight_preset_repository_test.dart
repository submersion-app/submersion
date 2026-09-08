import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
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
  test(
    'deletePreset tombstones its entries inside the delete transaction',
    () async {
      // Atomicity is a claim about the SQL that reaches SQLite, so read it off
      // the statement log rather than the repository's Dart control flow.
      await tearDownTestDatabase();
      DatabaseService.instance.setTestDatabase(
        AppDatabase(NativeDatabase.memory(logStatements: true)),
      );
      final divers = DiverRepository();
      final now = DateTime.now();
      final loggedDiverId = (await divers.createDiver(
        Diver(id: '', name: 'A', createdAt: now, updatedAt: now),
      )).id;
      repo = WeightPresetRepository();
      final preset = await repo.createFromWeights(
        diverId: loggedDiverId,
        displayName: 'Atomic',
        weights: [_w(WeightType.belt, 2.0), _w(WeightType.ankleWeights, 0.5)],
      );

      final logged = <String>[];
      await runZoned(
        () => repo.deletePreset(preset.id),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => logged.add(line),
        ),
      );

      final deleteAt = logged.indexWhere(
        (l) => l.contains('DELETE FROM "weight_presets"'),
      );
      final lastTombstoneAt = logged.lastIndexWhere(
        (l) => l.contains('INSERT INTO "deletion_log"'),
      );
      expect(
        deleteAt,
        isNonNegative,
        reason: 'the preset delete should be logged',
      );
      expect(lastTombstoneAt, greaterThan(deleteAt));
      // A COMMIT in between means the preset row is already gone for good while
      // some of its entry tombstones are not yet written. A failure at that point
      // leaves a peer holding entries nothing tells it to delete, and the next
      // sync resurrects them.
      expect(
        logged
            .sublist(deleteAt, lastTombstoneAt)
            .where((l) => l.toUpperCase().contains('COMMIT')),
        isEmpty,
        reason: 'the delete and every tombstone must share one transaction',
      );
    },
  );

  test(
    'createPreset builds a preset from hand-composed rows (#1663)',
    () async {
      final preset = await repo.createPreset(
        diverId: diverId,
        displayName: '  Wetsuit 5mm  ',
        entries: const [
          (weightType: WeightType.belt, amountKg: 4.0, notes: ''),
          (weightType: WeightType.trimWeights, amountKg: 1.0, notes: 'tail'),
        ],
      );

      expect(preset.displayName, 'Wetsuit 5mm');
      expect(preset.diverId, diverId);
      expect(preset.entries, hasLength(2));
      expect(preset.entries[1].weightType, WeightType.trimWeights);
      expect(preset.entries[1].notes, 'tail');
      expect(preset.totalKg, closeTo(5.0, 1e-9));
    },
  );

  test('getPresetById returns the preset with its entries, or null', () async {
    final created = await repo.createFromWeights(
      diverId: diverId,
      displayName: 'Drysuit',
      weights: [_w(WeightType.belt, 3.0)],
    );

    final fetched = await repo.getPresetById(created.id);
    expect(fetched, isNotNull);
    expect(fetched!.displayName, 'Drysuit');
    expect(fetched.entries, hasLength(1));
    expect(await repo.getPresetById('nope'), isNull);
  });

  test('updatePreset replaces the entry list and renames (#1663)', () async {
    final preset = await repo.createFromWeights(
      diverId: diverId,
      displayName: 'Old name',
      weights: [_w(WeightType.belt, 2.0), _w(WeightType.ankleWeights, 0.5)],
    );

    await repo.updatePreset(
      id: preset.id,
      displayName: 'New name',
      entries: const [
        (weightType: WeightType.integrated, amountKg: 6.0, notes: ''),
      ],
    );

    final reloaded = (await repo.getPresets(diverId: diverId)).single;
    expect(reloaded.displayName, 'New name');
    expect(reloaded.entries, hasLength(1));
    expect(reloaded.entries.single.weightType, WeightType.integrated);
    expect(reloaded.totalKg, closeTo(6.0, 1e-9));

    final db = DatabaseService.instance.database;
    // The two removed entries are tombstoned so a peer does not resurrect
    // them; the preset row itself is updated in place, not deleted.
    final entryTombstones = await db
        .customSelect(
          "SELECT COUNT(*) AS n FROM deletion_log "
          "WHERE entity_type = 'weightPresetEntries'",
        )
        .getSingle();
    expect(entryTombstones.read<int>('n'), 2);
    final presetTombstones = await db
        .customSelect(
          "SELECT COUNT(*) AS n FROM deletion_log "
          "WHERE entity_type = 'weightPresets'",
        )
        .getSingle();
    expect(presetTombstones.read<int>('n'), 0);
  });
}
