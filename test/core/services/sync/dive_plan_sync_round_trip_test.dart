import 'dart:convert';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

DivePlansCompanion _plan(String id) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return DivePlansCompanion.insert(
    id: id,
    name: 'Wreck 60 m',
    gfLow: 50,
    gfHigh: 80,
    createdAt: now,
    updatedAt: now,
    mode: const Value('oc'),
    altitude: const Value(700.0),
    waterType: const Value('salt'),
    sacBottom: const Value(16.0),
    summaryMaxDepth: const Value(60.0),
    summaryRuntimeSeconds: const Value(74 * 60),
    summaryTtsSeconds: const Value(39 * 60),
    hlc: const Value('0001-test-hlc'),
  );
}

DivePlanTanksCompanion _tank(String id, String planId, {double o2 = 21}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return DivePlanTanksCompanion.insert(
    id: id,
    planId: planId,
    createdAt: now,
    updatedAt: now,
    volume: const Value(11.1),
    startPressure: const Value(207.0),
    gasO2: Value(o2),
    hlc: const Value('0001-test-hlc'),
  );
}

DivePlanSegmentsCompanion _segment(
  String id,
  String planId,
  String tankId,
  int order,
) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return DivePlanSegmentsCompanion.insert(
    id: id,
    planId: planId,
    type: 'bottom',
    startDepth: 60.0,
    endDepth: 60.0,
    durationSeconds: 25 * 60,
    tankId: tankId,
    gasO2: 18.0,
    gasHe: 45.0,
    sortOrder: Value(order),
    createdAt: now,
    updatedAt: now,
    hlc: const Value('0001-test-hlc'),
  );
}

void main() {
  group('Dive plan sync round trip (FK ON)', () {
    late AppDatabase db;

    setUp(() async {
      db = await setUpTestDatabase();
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    test(
      'plan + tanks + segments survive export and JSON round-trip',
      () async {
        await db.into(db.divePlans).insert(_plan('plan-1'));
        await db.into(db.divePlanTanks).insert(_tank('tank-1', 'plan-1'));
        await db
            .into(db.divePlanTanks)
            .insert(_tank('tank-2', 'plan-1', o2: 50));
        await db
            .into(db.divePlanSegments)
            .insert(_segment('seg-1', 'plan-1', 'tank-1', 0));
        await db
            .into(db.divePlanSegments)
            .insert(_segment('seg-2', 'plan-1', 'tank-1', 1));
        await db
            .into(db.divePlanSegments)
            .insert(_segment('seg-3', 'plan-1', 'tank-2', 2));

        final serializer = SyncDataSerializer();
        final syncRepository = SyncRepository();
        final deviceId = await syncRepository.getDeviceId();
        final deletions = await syncRepository.getAllDeletions();
        final payload = await serializer.exportData(
          deviceId: deviceId,
          lastSyncTimestamp: null,
          deletions: deletions,
        );
        final data = payload.data;
        expect(data.divePlans, hasLength(1));
        expect(data.divePlanTanks, hasLength(2));
        expect(data.divePlanSegments, hasLength(3));

        // JSON round trip preserves everything.
        final decoded = SyncData.fromJson(
          jsonDecode(jsonEncode(data.toJson())) as Map<String, dynamic>,
        );
        expect(decoded.divePlans.single['name'], 'Wreck 60 m');
        expect(decoded.divePlans.single['waterType'], 'salt');
        expect(decoded.divePlanTanks, hasLength(2));
        expect(decoded.divePlanSegments, hasLength(3));

        // Apply into a second FK-ON database, parents before children.
        // The serializer reads DatabaseService.instance.database, so point the
        // service at the target database for the apply phase.
        final db2 = AppDatabase(NativeDatabase.memory());
        addTearDown(() => db2.close());
        DatabaseService.instance.resetForTesting();
        DatabaseService.instance.setTestDatabase(db2);
        await db2.customStatement('PRAGMA foreign_keys = ON');
        final serializer2 = SyncDataSerializer();
        for (final record in decoded.divePlans) {
          await serializer2.upsertRecord('divePlans', record);
        }
        for (final record in decoded.divePlanTanks) {
          await serializer2.upsertRecord('divePlanTanks', record);
        }
        for (final record in decoded.divePlanSegments) {
          await serializer2.upsertRecord('divePlanSegments', record);
        }

        final plans = await db2.select(db2.divePlans).get();
        expect(plans.single.summaryTtsSeconds, 39 * 60);
        expect(await db2.select(db2.divePlanTanks).get(), hasLength(2));
        expect(await db2.select(db2.divePlanSegments).get(), hasLength(3));
      },
    );
  });
}
