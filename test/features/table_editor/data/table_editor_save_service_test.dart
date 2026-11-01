import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/data/services/change_log_revert_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/bulk_dive_edit_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/presentation/table/dive_field_adapter.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/table_editor/data/table_editor_save_service.dart';
import 'package:submersion/features/table_editor/domain/table_draft.dart';
import 'package:submersion/features/table_editor/domain/table_editor_column.dart';
import 'package:submersion/features/table_editor/domain/table_editor_entity.dart';
import 'package:submersion/features/table_editor/entities/dive_table_editor_entity.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../core/database/change_log/change_log_support.dart';
import '../../../helpers/test_database.dart';

/// Save all (#3422): one change log operation, stale drafts left out, and
/// nothing written when any write fails.
void main() {
  late AppDatabase db;
  late DiveRepository diveRepo;
  late DiveTableEditorEntity entity;
  final changeLog = ChangeLogRepository();

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement('PRAGMA foreign_keys = OFF');
    SyncClock.instance.configure(nodeId: 'node-test', now: () => 5000);
    diveRepo = DiveRepository();
    for (final id in ['d1', 'd2', 'd3']) {
      await diveRepo.createDive(
        domain.Dive(
          id: id,
          dateTime: DateTime(2026, 1, 1),
          notes: '',
          visibilityMeters: 10,
        ),
      );
    }
    entity = DiveTableEditorEntity(
      diveRepo: diveRepo,
      bulk: BulkDiveEditService(
        diveRepo,
        BuddyRepository(),
        SpeciesRepository(),
      ),
      weightsByDive: const {},
      sites: const [],
      centers: const [],
      trips: const [],
    );
    await changeLog.settleAll();
    await clearLog(db);
    await db.customStatement('DELETE FROM change_log_operations');
    await SyncRepository().clearPendingRecords();
  });

  tearDown(() async {
    SyncClock.instance.reset();
    await tearDownTestDatabase();
  });

  Future<Map<String, domain.Dive>> rows() async => {
    for (final d in await diveRepo.getDivesByIdsWithoutSamples([
      'd1',
      'd2',
      'd3',
    ]))
      d.id: d,
  };

  TableDraft visibility(String id, double value, {double original = 10}) =>
      TableDraft(
        entityId: id,
        fieldName: DiveField.visibility.name,
        original: original,
        value: value,
      );

  Future<List<ChangeLogOperationRow>> operations() async {
    await changeLog.settleAll();
    return db.select(db.changeLogOperations).get();
  }

  test('saves drafts and reports the operation id', () async {
    final service = TableEditorSaveService();

    final result = await service.save(
      entity: entity,
      rows: await rows(),
      drafts: [visibility('d1', 15), visibility('d2', 20)],
    );

    final after = await rows();
    expect(after['d1']!.visibilityMeters, 15);
    expect(after['d2']!.visibilityMeters, 20);
    expect(after['d3']!.visibilityMeters, 10);
    expect(result.saved, 2);
    expect(result.changedElsewhere, isEmpty);
    expect(result.operationId, isNotNull);
  });

  test(
    'one operation: every written row shares the change log operation',
    () async {
      final result = await TableEditorSaveService().save(
        entity: entity,
        rows: await rows(),
        drafts: [visibility('d1', 15), visibility('d2', 20)],
      );

      final ops = await operations();
      final op = ops.singleWhere((o) => o.label == ChangeLogLabels.tableEditor);
      expect(op.id, result.operationId);
      final events = await logEvents(db);
      final touched = events
          .where((e) => e['operation_id'] == op.id)
          .map((e) => e['record_id'])
          .toSet();
      expect(touched, containsAll(['d1', 'd2']));
      expect(ops.where((o) => o.label == ChangeLogLabels.bulkEdit), isEmpty);
    },
  );

  test('stale draft is skipped and the others save', () async {
    final before = await rows();
    // A sync lands on d2 between drafting and saving.
    await db.customStatement(
      "UPDATE dives SET visibility_meters = 11 WHERE id = 'd2'",
    );

    final result = await TableEditorSaveService().save(
      entity: entity,
      rows: before,
      drafts: [
        visibility('d1', 15),
        visibility('d2', 20),
        visibility('d3', 25),
      ],
    );

    final after = await rows();
    expect(after['d1']!.visibilityMeters, 15);
    expect(after['d2']!.visibilityMeters, 11);
    expect(after['d3']!.visibilityMeters, 25);
    expect(result.saved, 2);
    expect(result.changedElsewhere.single.draft.entityId, 'd2');
    expect(result.changedElsewhere.single.current, 11);
  });

  test('all or nothing: a failing write leaves every dive unchanged', () async {
    final failing = _FailAfterFirst(entity);

    await expectLater(
      TableEditorSaveService().save(
        entity: failing,
        rows: await rows(),
        drafts: [visibility('d1', 15), visibility('d2', 20)],
      ),
      throwsStateError,
    );

    final after = await rows();
    expect(after['d1']!.visibilityMeters, 10);
    expect(after['d2']!.visibilityMeters, 10);
    expect(failing.written, ['d1']);
  });

  test('undo through the change log revert restores the rows', () async {
    final result = await TableEditorSaveService().save(
      entity: entity,
      rows: await rows(),
      drafts: [visibility('d1', 15), visibility('d2', 20)],
    );
    await changeLog.settleAll();

    final revert = ChangeLogRevertService();
    final outcome = await revert.execute(
      await revert.planOperation(result.operationId!),
    );

    final after = await rows();
    expect(after['d1']!.visibilityMeters, 10);
    expect(after['d2']!.visibilityMeters, 10);
    expect(outcome.kept, 0);
  });
}

/// Writes the first dive through the real entity, then throws, so the
/// outer transaction has something to roll back.
class _FailAfterFirst extends TableEditorEntity<domain.Dive, DiveField> {
  final DiveTableEditorEntity inner;
  final written = <String>[];

  _FailAfterFirst(this.inner);

  @override
  DiveFieldAdapter get adapter => inner.adapter;
  @override
  List<TableEditorColumn<domain.Dive, DiveField>> get columns => inner.columns;
  @override
  DiveField fieldFromName(String name) => inner.fieldFromName(name);
  @override
  String idOf(domain.Dive entity) => inner.idOf(entity);
  @override
  DiveField get keyField => inner.keyField;
  @override
  int? numberOf(domain.Dive entity) => inner.numberOf(entity);
  @override
  String? nameOf(domain.Dive entity) => null;
  @override
  Future<List<domain.Dive>> reload(List<String> ids) => inner.reload(ids);
  @override
  List<String> summaryNotes(List<TableDraft> drafts, AppLocalizations l10n) =>
      const [];

  @override
  Future<void> save(
    Map<String, List<TableDraft>> draftsByEntity,
    Map<String, domain.Dive> fresh,
  ) async {
    for (final entry in draftsByEntity.entries) {
      await inner.save({entry.key: entry.value}, fresh);
      written.add(entry.key);
      throw StateError('boom');
    }
  }
}
