import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/data/services/change_log_revert_service.dart';
import 'package:submersion/features/change_log/presentation/providers/change_log_providers.dart';
import 'package:submersion/features/table_editor/data/table_editor_save_service.dart';
import 'package:submersion/features/table_editor/domain/paste_planner.dart';
import 'package:submersion/features/table_editor/domain/save_summary.dart';
import 'package:submersion/features/table_editor/domain/table_draft.dart';
import 'package:submersion/features/table_editor/domain/table_editor_entity.dart';
import 'package:submersion/features/table_editor/presentation/providers/table_editor_providers.dart';
import 'package:submersion/features/table_editor/presentation/widgets/save_summary_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/constants/entity_field.dart';

final _log = LoggerService.forClass(TableEditorSaveFlow);

/// Save all and its Undo for one tab (#3422): the summary, the save, the
/// drafts' bookkeeping afterwards and the snackbar.
class TableEditorSaveFlow {
  const TableEditorSaveFlow._();

  /// Shows the summary, saves on confirmation, and returns whether anything
  /// was written. [refresh] reloads the tab's rows after a save.
  static Future<bool> saveAll<T, F extends EntityField>(
    BuildContext context,
    WidgetRef ref, {
    required TableEditorTab tab,
    required TableEditorEntity<T, F> entity,
    required List<T> rows,
    required VoidCallback refresh,
    required VoidCallback openChangeLog,
    PastePlan<F>? lastPaste,
    bool confirm = true,
  }) async {
    final l10n = context.l10n;
    final notifier = ref.read(tableEditorDraftsProvider(tab).notifier);
    final drafts = ref.read(tableEditorDraftsProvider(tab));
    final summary = SaveSummary.from(
      drafts.all,
      lastPaste: lastPaste,
      notes: entity.summaryNotes(drafts.all, l10n),
    );
    if (confirm) {
      final go = await showSaveSummaryDialog(
        context,
        summary,
        columnLabel: (name) =>
            entity.fieldFromName(name).localizedDisplayName(l10n),
      );
      if (!go || !context.mounted) return false;
    }
    final saveable = drafts.saveable;
    if (saveable.isEmpty) return false;
    final messenger = ScaffoldMessenger.of(context);
    final TableEditorSaveResult result;
    try {
      result = await ref
          .read(tableEditorSaveServiceProvider)
          .save(entity: entity, drafts: saveable);
    } catch (e, stackTrace) {
      _log.error('Table editor save failed', error: e, stackTrace: stackTrace);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.tableEditor_saveFailed)),
      );
      return false;
    }
    final stale = {for (final s in result.changedElsewhere) s.draft.position};
    for (final d in saveable) {
      if (!stale.contains(d.position)) notifier.remove(d.entityId, d.fieldName);
    }
    for (final s in result.changedElsewhere) {
      notifier.rebase(s.draft.entityId, s.draft.fieldName, s.current);
      notifier.flag(
        s.draft.entityId,
        s.draft.fieldName,
        TableDraftFlag.changedElsewhere,
      );
    }
    refresh();
    final operationId = result.operationId;
    // The snackbar outlives the page: capture what Undo needs now.
    final changeLog = ref.read(changeLogRepositoryProvider);
    final revert = ref.read(changeLogRevertServiceProvider);
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.tableEditor_saved(result.saved)),
        duration: const Duration(seconds: 5),
        persist: false,
        action: operationId == null
            ? null
            : SnackBarAction(
                label: l10n.tableEditor_undo,
                onPressed: () => _undo(
                  messenger,
                  changeLog: changeLog,
                  revert: revert,
                  operationId: operationId,
                  total: result.saved,
                  refresh: refresh,
                  openChangeLog: openChangeLog,
                  changeLogLabel: l10n.tableEditor_changeLog,
                  undoneAll: l10n.tableEditor_undoneAll,
                  undonePartial: l10n.tableEditor_undonePartial,
                ),
              ),
      ),
    );
    return result.saved > 0;
  }

  static Future<void> _undo(
    ScaffoldMessengerState messenger, {
    required ChangeLogRepository changeLog,
    required ChangeLogRevertService revert,
    required String operationId,
    required int total,
    required VoidCallback refresh,
    required VoidCallback openChangeLog,
    required String changeLogLabel,
    required String undoneAll,
    required String Function(int reverted, int total) undonePartial,
  }) async {
    var reverted = 0;
    var kept = total;
    try {
      await changeLog.settleAll();
      final result = await revert.execute(
        await revert.planOperation(operationId),
      );
      reverted = result.reverted;
      kept = result.kept;
    } catch (e, stackTrace) {
      _log.error('Table editor undo failed', error: e, stackTrace: stackTrace);
    }
    refresh();
    // A partial undo points at the change log, where each kept change can
    // be looked at on its own.
    messenger.showSnackBar(
      SnackBar(
        content: Text(kept == 0 ? undoneAll : undonePartial(reverted, total)),
        duration: const Duration(seconds: 5),
        persist: false,
        action: kept == 0
            ? null
            : SnackBarAction(label: changeLogLabel, onPressed: openChangeLog),
      ),
    );
  }
}
