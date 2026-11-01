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
    final ids = drafts.map((d) => d.entityId).toSet().toList();
    final fresh = {for (final r in await entity.reload(ids)) entity.idOf(r): r};
    const eq = DeepCollectionEquality();
    final stale = <StaleDraft>[];
    final grouped = <String, List<TableDraft>>{};
    for (final d in drafts) {
      final row = fresh[d.entityId];
      if (row == null) {
        stale.add(StaleDraft(d, null));
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
        continue;
      }
      grouped.putIfAbsent(d.entityId, () => []).add(d);
    }
    if (grouped.isEmpty) {
      return TableEditorSaveResult(
        operationId: null,
        saved: 0,
        changedElsewhere: stale,
      );
    }
    final database = _database;
    String? operationId;
    // The scope stays outside the transaction: a failed body must not take
    // the operation row with it (see ChangeLogScope).
    await ChangeLogScope.bulk(
      database,
      label: ChangeLogLabels.tableEditor,
      body: () async {
        operationId = ChangeLogScope.currentOperationId;
        Future<void> write() => entity.save(grouped, fresh);
        if (database == null) {
          await write();
        } else {
          await database.transaction(write);
        }
      },
    );
    return TableEditorSaveResult(
      operationId: operationId,
      saved: grouped.values.fold(0, (n, l) => n + l.length),
      changedElsewhere: stale,
    );
  }
}
