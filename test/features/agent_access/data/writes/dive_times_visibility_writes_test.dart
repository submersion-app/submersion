import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/records/record_catalog.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/change_set.dart';
import 'package:submersion/features/agent_access/data/writes/write_applier.dart';
import 'package:submersion/features/agent_access/data/writes/write_catalog.dart';
import 'package:submersion/features/agent_access/data/writes/write_plan.dart';
import 'package:submersion/features/agent_access/data/writes/write_planner.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/write_confirmer.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';

import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';

class _Allow implements WriteConfirmer {
  @override
  Future<bool> confirm(WriteConfirmation request) async => true;
}

/// Issue #4294: an agent records a paper logbook's dive number, times and
/// measured visibility, by the dive editor's rules.
void main() {
  late AppDatabase db;
  late WriteCatalog writes;
  const t = kSeedTime;
  const entry = 1710408600000; // 2024-03-14T09:30:00Z
  const minute = 60000;

  Future<void> dive(
    String id, {
    int? exit,
    int? runtime,
    int? bottomTime,
    int? number,
    bool planned = false,
    String? band,
    double? meters,
    double? minM,
    double? maxM,
  }) => db
      .into(db.dives)
      .insert(
        DivesCompanion.insert(
          id: id,
          diverId: const Value(kDiverA),
          diveDateTime: entry,
          createdAt: t,
          updatedAt: t,
          entryTime: const Value(entry),
          exitTime: Value(exit),
          runtime: Value(runtime),
          bottomTime: Value(bottomTime),
          diveNumber: Value(number),
          isPlanned: Value(planned),
          visibility: Value(band),
          visibilityMeters: Value(meters),
          visibilityMinMeters: Value(minM),
          visibilityMaxMeters: Value(maxM),
        ),
      );

  Future<Dive> row(String id) =>
      (db.select(db.dives)..where((d) => d.id.equals(id))).getSingle();

  Future<Dive> created() =>
      (db.select(db.dives)..where((d) => d.id.isNotIn(['d1']))).getSingle();

  Future<WritePlan> preview(List<Map<String, Object?>> operations) =>
      WritePlanner(
        writes: writes,
        records: RecordCatalog(RecordRepositories()),
      ).preview(
        db,
        ChangeSet.parse({'label': 'Paper log', 'operations': operations}),
        resolveDiver: (id) async => id ?? kDiverA,
      );

  Future<WriteResult> apply(WritePlan plan) => WriteApplier(
    catalog: writes,
    changeLog: ChangeLogRepository(),
    confirmer: _Allow(),
    confirmEnabled: () => false,
    afterDiveWrites: (_) {},
  ).apply(db, plan);

  Map<String, Object?> update(Map<String, Object?> fields) => {
    'op': 'update',
    'entity': 'dives',
    'id': 'd1',
    'fields': fields,
  };

  Map<String, Object?> create(Map<String, Object?> fields) => {
    'op': 'create',
    'entity': 'dives',
    'fields': {'date_time': '2024-03-14T09:30:00Z', ...fields},
  };

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    await seedTwoDivers(db);
    writes = WriteCatalog(RecordRepositories());
  });

  tearDown(() => tearDownTestDatabase());

  group('dive_number', () {
    test('a create keeps the number it is given', () async {
      await dive('d1', number: 150);

      await apply(
        await preview([
          create({'dive_number': 20}),
        ]),
      );

      expect((await created()).diveNumber, 20);
    });

    test('a create without one still takes the next number', () async {
      await dive('d1', number: 150);

      await apply(await preview([create({})]));

      expect((await created()).diveNumber, 151);
    });

    test('an update renumbers the dive, even onto a used number', () async {
      await dive('d1', number: 151);
      await dive('d2', number: 20);

      final plan = await preview([
        update({'dive_number': 20}),
      ]);
      expect(plan.items.single.fields['dive_number']!.oldValue, 151);
      expect(plan.items.single.fields['dive_number']!.newValue, 20);
      await apply(plan);

      expect((await row('d1')).diveNumber, 20);
    });

    test('a planned dive holds no number', () async {
      await dive('d1', planned: true);

      final plan = await preview([
        update({'dive_number': 20}),
      ]);

      expect(plan.items.single.block?.reason, BlockReason.notPermitted);
    });
  });

  group('times', () {
    test('an exit on a create fills the runtime from it', () async {
      final plan = await preview([
        create({'exit_time': '2024-03-14T10:20:00Z', 'bottom_time_s': 2400}),
      ]);
      final runtime = plan.items.single.fields['runtime_s']!;
      expect(runtime.newValue, 3000);
      expect(runtime.indirect, isTrue);

      await apply(plan);

      final saved = await created();
      expect(saved.exitTime, entry + 50 * minute);
      expect(saved.runtime, 3000);
      expect(saved.bottomTime, 2400);
    });

    test('a runtime alone on a create is stored with no exit', () async {
      await apply(
        await preview([
          create({'runtime_s': 2820}),
        ]),
      );

      final saved = await created();
      expect(saved.runtime, 2820);
      expect(saved.exitTime, isNull);
    });

    test('a create refuses a runtime its exit disagrees with', () async {
      final plan = await preview([
        create({'exit_time': '2024-03-14T10:20:00Z', 'runtime_s': 2700}),
      ]);

      expect(plan.items.single.block?.reason, BlockReason.invalidValue);
      expect(plan.items.single.block?.detail, contains('exit_time'));
    });

    test('a new exit lists the runtime that follows it', () async {
      await dive('d1', exit: entry + 45 * minute, runtime: 2700);

      final plan = await preview([
        update({'exit_time': '2024-03-14T10:20:00Z'}),
      ]);
      final runtime = plan.items.single.fields['runtime_s']!;
      expect(runtime.oldValue, 2700);
      expect(runtime.newValue, 3000);
      expect(runtime.indirect, isTrue);

      await apply(plan);

      final saved = await row('d1');
      expect(saved.exitTime, entry + 50 * minute);
      expect(saved.runtime, 3000);
    });

    test('a runtime the stored exit disagrees with is refused', () async {
      await dive('d1', exit: entry + 45 * minute, runtime: 2700);

      final plan = await preview([
        update({'runtime_s': 3000}),
      ]);

      expect(plan.items.single.block?.reason, BlockReason.invalidValue);
      expect(plan.items.single.block?.detail, contains('exit_time'));
    });

    test('clearing the runtime while the exit stays is refused', () async {
      await dive('d1', exit: entry + 45 * minute, runtime: 2700);

      final plan = await preview([
        update({'runtime_s': null}),
      ]);

      expect(plan.items.single.block?.reason, BlockReason.invalidValue);
    });

    test('clearing the exit leaves the runtime as it is', () async {
      await dive('d1', exit: entry + 45 * minute, runtime: 2700);

      final plan = await preview([
        update({'exit_time': null}),
      ]);
      expect(plan.items.single.fields.keys, ['exit_time']);
      await apply(plan);

      final saved = await row('d1');
      expect(saved.exitTime, isNull);
      expect(saved.runtime, 2700);
    });

    test('a runtime goes in once the same change clears the exit', () async {
      await dive('d1', exit: entry + 45 * minute, runtime: 2700);

      await apply(
        await preview([
          update({'exit_time': null, 'runtime_s': 3000}),
        ]),
      );

      final saved = await row('d1');
      expect(saved.exitTime, isNull);
      expect(saved.runtime, 3000);
    });

    test('a runtime that matches the exit fills an empty column', () async {
      await dive('d1', exit: entry + 45 * minute);

      final plan = await preview([
        update({'runtime_s': 2700}),
      ]);
      expect(plan.items.single.fields['runtime_s']!.oldValue, isNull);
      await apply(plan);

      expect((await row('d1')).runtime, 2700);
    });

    test('an exit at or before the entry is refused', () async {
      await dive('d1');

      final plan = await preview([
        update({'exit_time': '2024-03-14T09:30:00Z'}),
      ]);

      expect(plan.items.single.block?.reason, BlockReason.invalidValue);
    });

    test('an exit more than a day after the entry is refused', () async {
      await dive('d1');

      final plan = await preview([
        update({'exit_time': '2024-03-15T09:31:00Z'}),
      ]);

      expect(plan.items.single.block?.reason, BlockReason.invalidValue);
    });

    test('a named exit wins over the shift a moved entry brings', () async {
      await dive('d1', exit: entry + 45 * minute, runtime: 2700);

      final plan = await preview([
        update({
          'date_time': '2024-03-14T11:30:00Z',
          'exit_time': '2024-03-14T12:10:00Z',
        }),
      ]);
      expect(plan.items.single.fields['runtime_s']!.newValue, 2400);
      await apply(plan);

      final saved = await row('d1');
      expect(saved.entryTime, entry + 120 * minute);
      expect(saved.exitTime, entry + 160 * minute);
      expect(saved.runtime, 2400);
    });

    test('a bottom time leaves the runtime alone', () async {
      await dive('d1', exit: entry + 45 * minute, runtime: 2700);

      final plan = await preview([
        update({'bottom_time_s': 2400}),
      ]);
      expect(plan.items.single.fields.keys, ['bottom_time_s']);
      await apply(plan);

      final saved = await row('d1');
      expect(saved.bottomTime, 2400);
      expect(saved.runtime, 2700);
    });
  });

  group('measured visibility', () {
    test('a measurement clears the range and the band', () async {
      await dive('d1', band: 'good', minM: 10, maxM: 20);

      final plan = await preview([
        update({'visibility_m': 18.3}),
      ]);
      final fields = plan.items.single.fields;
      expect(fields['visibility']!.newValue, isNull);
      expect(fields['visibility_min_m']!.newValue, isNull);
      expect(fields['visibility_max_m']!.newValue, isNull);
      expect(fields['visibility_min_m']!.indirect, isTrue);
      await apply(plan);

      final saved = await row('d1');
      expect(saved.visibilityMeters, 18.3);
      expect(saved.visibility, isNull);
      expect(saved.visibilityMinMeters, isNull);
      expect(saved.visibilityMaxMeters, isNull);
    });

    test('an open range clears the measurement', () async {
      await dive('d1', meters: 12);

      final plan = await preview([
        update({'visibility_min_m': 24.4}),
      ]);
      expect(plan.items.single.fields['visibility_m']!.newValue, isNull);
      await apply(plan);

      final saved = await row('d1');
      expect(saved.visibilityMinMeters, 24.4);
      expect(saved.visibilityMaxMeters, isNull);
      expect(saved.visibilityMeters, isNull);
    });

    test('a range end that crosses the stored other end is refused', () async {
      await dive('d1', minM: 10, maxM: 20);

      final plan = await preview([
        update({'visibility_min_m': 24.4}),
      ]);

      expect(plan.items.single.block?.reason, BlockReason.invalidValue);
      expect(plan.items.single.block?.detail, contains('visibility_max_m'));
    });

    test('two shapes in one change are refused', () async {
      await dive('d1');

      final plan = await preview([
        update({'visibility_m': 18.3, 'visibility': 'good'}),
      ]);

      expect(plan.items.single.block?.reason, BlockReason.invalidValue);
    });

    test('a restated measurement still clears a stale range', () async {
      await dive('d1', meters: 12, minM: 10, maxM: 20);

      final plan = await preview([
        update({'visibility_m': 12.0}),
      ]);
      expect(plan.unchanged, isEmpty);
      await apply(plan);

      final saved = await row('d1');
      expect(saved.visibilityMeters, 12.0);
      expect(saved.visibilityMinMeters, isNull);
      expect(saved.visibilityMaxMeters, isNull);
    });

    test('a create stores a measurement', () async {
      await apply(
        await preview([
          create({'visibility_m': 18.3}),
        ]),
      );

      expect((await created()).visibilityMeters, 18.3);
    });
  });
}
