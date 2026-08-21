import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_intervention.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_intervention_codec.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

import '../../../helpers/test_database.dart';

db.DiveScenariosCompanion _scenario(String id, String diveId) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return db.DiveScenariosCompanion.insert(
    id: id,
    diveId: diveId,
    name: 'Lost 50% at 23:40',
    branchSeconds: 1420,
    mode: const Value('replan'),
    interventionsJson: encodeInterventions(const [
      LoseTankIntervention(tankId: 'deco50'),
      AscendNowIntervention(),
    ]),
    createdAt: now,
    updatedAt: now,
    hlc: const Value('0001-test-hlc'),
  );
}

void main() {
  group('Dive scenario sync round trip (FK ON)', () {
    late db.AppDatabase database;

    setUp(() async {
      database = await setUpTestDatabase();
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    test('scenario survives export, JSON round-trip and apply', () async {
      final dive = await DiveRepository().createDive(
        Dive(id: 'dive-1', diveNumber: 1, dateTime: DateTime(2026, 1, 1)),
      );
      await database
          .into(database.diveScenarios)
          .insert(_scenario('sc-1', dive.id));

      final serializer = SyncDataSerializer();
      final syncRepository = SyncRepository();
      final payload = await serializer.exportData(
        deviceId: await syncRepository.getDeviceId(),
        lastSyncTimestamp: null,
        deletions: await syncRepository.getAllDeletions(),
      );
      expect(payload.data.diveScenarios, hasLength(1));

      final decoded = SyncData.fromJson(
        jsonDecode(jsonEncode(payload.data.toJson())) as Map<String, dynamic>,
      );
      final record = decoded.diveScenarios.single;
      expect(record['name'], 'Lost 50% at 23:40');
      expect(record['branchSeconds'], 1420);
      expect(record['mode'], 'replan');
      expect(
        decodeInterventions(record['interventionsJson'] as String),
        hasLength(2),
      );

      // Apply into a second FK-ON database with the parent dive present.
      final db2 = db.AppDatabase(NativeDatabase.memory());
      addTearDown(() => db2.close());
      DatabaseService.instance.resetForTesting();
      DatabaseService.instance.setTestDatabase(db2);
      await db2.customStatement('PRAGMA foreign_keys = ON');
      await DiveRepository().createDive(
        Dive(id: 'dive-1', diveNumber: 1, dateTime: DateTime(2026, 1, 1)),
      );
      final serializer2 = SyncDataSerializer();
      await serializer2.upsertRecord('diveScenarios', record);
      final rows = await db2.select(db2.diveScenarios).get();
      expect(rows.single.diveId, 'dive-1');
      expect(rows.single.interventionsJson, record['interventionsJson']);

      // Record ids round-trip through deleteRecord.
      final ids = await serializer2.recordIdsFor('diveScenarios');
      expect(ids, contains('sc-1'));
      await serializer2.deleteRecord('diveScenarios', 'sc-1');
      expect(await db2.select(db2.diveScenarios).get(), isEmpty);
    });
  });
}
