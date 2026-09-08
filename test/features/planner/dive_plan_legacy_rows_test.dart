import 'package:drift/drift.dart' hide isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/planner/domain/services/segment_chain.dart';

import '../../helpers/test_database.dart';

/// How rows written by the segment-type era load now.
///
/// `type`, `start_depth` and `rate` are still written (they are NOT NULL
/// columns) but no longer read: the phase, the start depth and the rate are
/// derived from the chain. These tests cover the two things that changes for
/// a database that already has plans in it.

void main() {
  late DivePlanRepository repository;
  late db.AppDatabase database;

  setUp(() async {
    database = await setUpTestDatabase();
    repository = DivePlanRepository();
  });

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

  Future<void> insertPlanShell() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await database
        .into(database.divePlans)
        .insert(
          db.DivePlansCompanion.insert(
            id: 'plan-legacy',
            name: 'Legacy plan',
            gfLow: 30,
            gfHigh: 70,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await database
        .into(database.divePlanTanks)
        .insert(
          db.DivePlanTanksCompanion.insert(
            id: 'tank-1',
            planId: 'plan-legacy',
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  /// Writes a row the way the old code would have, including the columns the
  /// loader now ignores.
  Future<void> insertLegacySegment({
    required String id,
    required String type,
    required double startDepth,
    required double endDepth,
    required int durationSeconds,
    required int sortOrder,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await database
        .into(database.divePlanSegments)
        .insert(
          db.DivePlanSegmentsCompanion.insert(
            id: id,
            planId: 'plan-legacy',
            type: type,
            startDepth: startDepth,
            endDepth: endDepth,
            durationSeconds: durationSeconds,
            tankId: 'tank-1',
            gasO2: 21,
            gasHe: 0,
            sortOrder: Value(sortOrder),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  test('a stored depth discontinuity is repaired by the chain', () async {
    // Segment 1 ended at 30 m and segment 2 claimed to start at 12 m. Nothing
    // ever repaired that, so the deco model integrated an 18 m ascent in zero
    // time. The waypoint model cannot express the gap: segment 2 starts where
    // segment 1 finished.
    await insertPlanShell();
    await insertLegacySegment(
      id: 'seg-1',
      type: 'descent',
      startDepth: 0,
      endDepth: 30,
      durationSeconds: 180,
      sortOrder: 0,
    );
    await insertLegacySegment(
      id: 'seg-2',
      type: 'bottom',
      startDepth: 12, // the gap
      endDepth: 12,
      durationSeconds: 1200,
      sortOrder: 1,
    );

    final loaded = await repository.getPlan('plan-legacy');
    expect(loaded, isNotNull);

    final legs = const SegmentChain().resolve(loaded!.segments);
    expect(legs.map((l) => l.startDepth), [0.0, 30.0]);
    expect(legs.map((l) => l.endDepth), [30.0, 12.0]);
    // Consecutive legs meet, so the profile has no instantaneous jump.
    for (var i = 1; i < legs.length; i++) {
      expect(legs[i].startDepth, legs[i - 1].endDepth);
    }
  });

  test('a row whose type column is unrecognised still loads', () async {
    // The loader used to call SegmentType.values.byName(s.type), which throws
    // on an unknown name - a row written by a newer build could crash the
    // load. The column is no longer read at all.
    await insertPlanShell();
    await insertLegacySegment(
      id: 'seg-1',
      type: 'someFutureType',
      startDepth: 0,
      endDepth: 24,
      durationSeconds: 240,
      sortOrder: 0,
    );

    final loaded = await repository.getPlan('plan-legacy');
    expect(loaded, isNotNull);
    expect(loaded!.segments.single.targetDepth, 24);
    expect(loaded.segments.single.durationSeconds, 240);
  });

  test('re-saving a loaded plan keeps the retired columns truthful', () async {
    // The columns stay NOT NULL, so they are still written. They are filled
    // from the resolved chain rather than with placeholders, so an older
    // build reading this row still sees the real profile - including the
    // repaired start depth.
    await insertPlanShell();
    await insertLegacySegment(
      id: 'seg-1',
      type: 'descent',
      startDepth: 0,
      endDepth: 30,
      durationSeconds: 180,
      sortOrder: 0,
    );
    await insertLegacySegment(
      id: 'seg-2',
      type: 'bottom',
      startDepth: 12,
      endDepth: 12,
      durationSeconds: 1200,
      sortOrder: 1,
    );

    final loaded = await repository.getPlan('plan-legacy');
    await repository.savePlan(loaded!);

    final rows = await (database.select(
      database.divePlanSegments,
    )..orderBy([(t) => OrderingTerm(expression: t.sortOrder)])).get();
    // seg-2 targets 12 m, so once chained it is an ascent from 30 m - not
    // the "bottom" the old row claimed. The rewritten columns say so.
    expect(rows.map((r) => r.type), ['descent', 'ascent']);
    // The gap is gone from start_depth too, not just from the loaded entity.
    expect(rows.map((r) => r.startDepth), [0.0, 30.0]);
    expect(rows[0].rate, closeTo(10.0, 0.001)); // 30 m over 3 min
    expect(rows[1].rate, closeTo(-0.9, 0.001)); // 18 m up over 20 min
  });
}
