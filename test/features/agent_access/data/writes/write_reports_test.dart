import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/records/record_catalog.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/change_set.dart';
import 'package:submersion/features/agent_access/data/writes/families/tag_writes.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/data/writes/write_catalog.dart';
import 'package:submersion/features/agent_access/data/writes/write_plan.dart';
import 'package:submersion/features/agent_access/data/writes/write_planner.dart';

import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';
import 'child_write_harness.dart';

/// Tags that report rows a create adds and records an update rewrites, as a
/// gear item's create adds service clocks and its rename renames a device.
class _ReportingTags extends TagWrites {
  _ReportingTags(super.r);

  @override
  Future<Map<String, int>> alsoCreates(
    String diverId,
    Map<String, Object?> values,
  ) async => const {'service_schedules': 2};

  @override
  Future<SideEffects> sideEffects(
    String id,
    String? ownerId,
    RecordUpdate update,
    Map<String, Object?> document,
  ) async => const SideEffects(touched: {'dive_computers': 1});
}

class _Catalog implements WriteCatalog {
  _Catalog(this.all);

  @override
  final List<WritableEntry> all;

  @override
  WritableEntry? named(String name) =>
      all.where((e) => e.name == name).firstOrNull;
}

/// Rows a create adds alongside its record, and rows of other records an
/// update rewrites, reach the plan, so a diver sees everything a write does.
void main() {
  late AppDatabase db;
  late WritePlanner planner;

  Future<WritePlan> preview(List<Map<String, Object?>> operations) =>
      planner.preview(
        db,
        ChangeSet.parse({'label': 'Gear', 'operations': operations}),
        resolveDiver: (id) async => id ?? kDiverA,
      );

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    await ChildWriteHarness(db).seed();
    final repositories = RecordRepositories();
    planner = WritePlanner(
      writes: _Catalog([_ReportingTags(repositories)]),
      records: RecordCatalog(repositories),
    );
    await db
        .into(db.tags)
        .insert(
          TagsCompanion.insert(
            id: 'reef',
            name: 'Reef',
            createdAt: kSeedTime,
            updatedAt: kSeedTime,
            diverId: const Value(kDiverA),
          ),
        );
  });
  tearDown(() => tearDownTestDatabase());

  test('a create lists the rows it adds alongside its record', () async {
    final plan = await preview([
      createOp('tags', {'name': 'Night'}),
    ]);

    expect(plan.items.single.alsoCreates, {'service_schedules': 2});
    expect(plan.items.single.toJson()['also_creates'], {
      'service_schedules': 2,
    });
  });

  test(
    'an update that only rewrites other records is still a change',
    () async {
      final plan = await preview([
        updateOp('tags', 'reef', {'name': 'Reef'}),
      ]);

      expect(plan.unchanged, isEmpty);
      expect(plan.items.single.alsoChanges, {'dive_computers': 1});
      expect(plan.items.single.toJson()['also_changes'], {'dive_computers': 1});
    },
  );
}
