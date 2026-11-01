import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/table_editor/domain/table_draft.dart';
import 'package:submersion/features/table_editor/domain/table_editor_entity.dart';
import 'package:submersion/shared/constants/entity_field.dart';

/// A draft left out of a save because the stored value moved since it was
/// made, with the value now stored so the sheet can show it.
@immutable
class StaleDraft {
  final TableDraft draft;
  final Object? current;
  const StaleDraft(this.draft, this.current);
}

@immutable
class TableEditorSaveResult {
  /// The change log operation the save filed under; null with no database.
  final String? operationId;
  final int saved;
  final List<StaleDraft> changedElsewhere;

  const TableEditorSaveResult({
    required this.operationId,
    required this.saved,
    required this.changedElsewhere,
  });
}

/// Save all for one tab (#3422): rereads every drafted record, leaves out
/// drafts whose stored value changed since they were made, then writes the
/// rest under one change log operation inside one transaction, so an error
/// anywhere rolls back everything and Undo reverts it whole.
class TableEditorSaveService {
  final AppDatabase? _db;

  TableEditorSaveService({AppDatabase? db}) : _db = db;

  AppDatabase? get _database => _db ?? DatabaseService.instance.databaseOrNull;

  Future<TableEditorSaveResult> save<T, F extends EntityField>({
    required TableEditorEntity<T, F> entity,
    required List<TableDraft> drafts,
  }) async {
    final database = _database;
    var stale = <StaleDraft>[];
    var saved = 0;
    String? operationId;
    // The scope stays outside the transaction: a failed body must not take
    // the operation row with it (see ChangeLogScope). The reread and the
    // stale check run inside it, so nothing can move between the check and
    // the write.
    await ChangeLogScope.bulk(
      database,
      label: ChangeLogLabels.tableEditor,
      body: () async {
        operationId = ChangeLogScope.currentOperationId;
        Future<void> write() async {
          final (grouped, skipped, fresh) = await _partition(entity, drafts);
          stale = skipped;
          saved = grouped.values.fold(0, (n, l) => n + l.length);
          if (grouped.isNotEmpty) await entity.save(grouped, fresh);
        }

        if (database == null) {
          await write();
        } else {
          await database.transaction(write);
        }
      },
    );
    return TableEditorSaveResult(
      operationId: saved == 0 ? null : operationId,
      saved: saved,
      changedElsewhere: stale,
    );
  }

  /// Rereads every drafted record and splits the drafts into those still
  /// against the stored value (grouped by record) and those left out.
  Future<(Map<String, List<TableDraft>>, List<StaleDraft>, Map<String, T>)>
  _partition<T, F extends EntityField>(
    TableEditorEntity<T, F> entity,
    List<TableDraft> drafts,
  ) async {
    final ids = drafts.map((d) => d.entityId).toSet().toList();
    final fresh = {for (final r in await entity.reload(ids)) entity.idOf(r): r};
    const eq = DeepCollectionEquality();
    final stale = <StaleDraft>[];
    final staleKeys = <CellPosition>{};
    final grouped = <String, List<TableDraft>>{};
    for (final d in drafts) {
      final row = fresh[d.entityId];
      if (row == null) {
        stale.add(StaleDraft(d, null));
        staleKeys.add(d.position);
        continue;
      }
      final column = entity.columnFor(entity.fieldFromName(d.fieldName));
      final current = column?.valueOf(row);
      // A cell that can no longer be edited (a second weight row arrived, a
      // site joined a library) is as stale as a changed value.
      if (!eq.equals(current, d.original) ||
          column == null ||
          !column.isEditable(row)) {
        stale.add(StaleDraft(d, current));
        staleKeys.add(d.position);
        continue;
      }
      grouped.putIfAbsent(d.entityId, () => []).add(d);
    }
    // A stale draft takes its linked partners with it.
    for (final group in entity.linkedFields) {
      for (final entry in grouped.entries.toList()) {
        final hit = staleKeys.any(
          (k) => k.entityId == entry.key && group.contains(k.fieldName),
        );
        if (!hit) continue;
        final partners = entry.value
            .where((d) => group.contains(d.fieldName))
            .toList();
        for (final d in partners) {
          final column = entity.columnFor(entity.fieldFromName(d.fieldName));
          stale.add(StaleDraft(d, column?.valueOf(fresh[d.entityId] as T)));
          entry.value.remove(d);
        }
        if (entry.value.isEmpty) grouped.remove(entry.key);
      }
    }
    return (grouped, stale, fresh);
  }
}
