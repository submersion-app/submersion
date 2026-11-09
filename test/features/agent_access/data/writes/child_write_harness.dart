import 'package:drift/drift.dart' show Value;
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/features/agent_access/data/records/record_catalog.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/change_set.dart';
import 'package:submersion/features/agent_access/data/writes/write_applier.dart';
import 'package:submersion/features/agent_access/data/writes/write_catalog.dart';
import 'package:submersion/features/agent_access/data/writes/write_plan.dart';
import 'package:submersion/features/agent_access/data/writes/write_planner.dart';
import 'package:submersion/features/agent_access/domain/write_confirmer.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/data/services/change_log_revert_service.dart';

import '../records/record_harness.dart';

class _Allow implements WriteConfirmer {
  @override
  Future<bool> confirm(WriteConfirmation request) async => true;
}

/// Preview, apply and revert over a real database, for the records that
/// belong to a dive. Two divers are seeded, with dive `d1` for diver A and
/// `d2` for diver B.
class ChildWriteHarness {
  /// [catalog] swaps in other writers, such as a probe a test watches.
  ChildWriteHarness(
    this.db, {
    WriteCatalog Function(RecordRepositories repositories)? catalog,
  }) : records = RecordHarness(db),
       // Diver A is active, as resolveDiver below says.
       _repositories = RecordRepositories(activeDiverId: () async => kDiverA) {
    writes = (catalog ?? WriteCatalog.new)(_repositories);
  }

  final AppDatabase db;
  final RecordHarness records;
  final RecordRepositories _repositories;
  late final WriteCatalog writes;
  final _changeLog = ChangeLogRepository();

  /// The dive ids each apply asked to refresh.
  final refreshed = <Set<String>>[];

  Future<void> seed() async {
    await seedTwoDivers(db);
    await dive('d1');
    await dive('d2', owner: kDiverB);
  }

  /// A dive named "Dive [id]", on 2024-03-14 at 09:30. [owner] null makes an
  /// unowned dive, as an old logbook can hold.
  Future<void> dive(String id, {String? owner = kDiverA}) => db
      .into(db.dives)
      .insert(
        DivesCompanion.insert(
          id: id,
          diverId: Value(owner),
          name: Value('Dive $id'),
          diveDateTime: 1710408600000,
          createdAt: kSeedTime,
          updatedAt: kSeedTime,
        ),
      );

  Future<WritePlan> preview(List<Map<String, Object?>> operations) =>
      WritePlanner(
        writes: writes,
        records: RecordCatalog(_repositories),
      ).preview(
        db,
        ChangeSet.parse({'label': 'Children', 'operations': operations}),
        resolveDiver: (id) async => id ?? kDiverA,
      );

  Future<WriteResult> apply(WritePlan plan) => WriteApplier(
    catalog: writes,
    changeLog: _changeLog,
    confirmer: _Allow(),
    confirmEnabled: () => false,
    afterDiveWrites: (ids) => refreshed.add(ids.toSet()),
    rearmDocuments: (_) async {},
  ).apply(db, plan);

  /// Previews [operations] and applies the plan.
  Future<WriteResult> run(List<Map<String, Object?>> operations) async =>
      apply(await preview(operations));

  Future<void> revert(WriteResult result) async {
    final service = ChangeLogRevertService(afterDiveWrites: (_) {});
    await service.execute(
      await service.planOperation(result.operations.single.operationId),
    );
  }

  /// [entity] [id] as [diverId] reads it, diver A unless named.
  Future<Map<String, Object?>?> one(
    String entity,
    String id, {
    String diverId = kDiverA,
  }) => records.one(entity, id, diverId: diverId);
}

Map<String, Object?> createOp(
  String entity,
  Map<String, Object?> fields, {
  String? diver,
}) => {'op': 'create', 'entity': entity, 'diver_id': ?diver, 'fields': fields};

Map<String, Object?> updateOp(
  String entity,
  String id,
  Map<String, Object?> fields,
) => {'op': 'update', 'entity': entity, 'id': id, 'fields': fields};

Map<String, Object?> deleteOp(String entity, String id, {String? mergeInto}) =>
    {'op': 'delete', 'entity': entity, 'id': id, 'merge_into': ?mergeInto};
