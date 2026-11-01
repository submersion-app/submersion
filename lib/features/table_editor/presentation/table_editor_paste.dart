import 'package:flutter/services.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/table_editor/domain/paste_parser.dart';
import 'package:submersion/features/table_editor/domain/paste_planner.dart';
import 'package:submersion/features/table_editor/domain/table_draft.dart';
import 'package:submersion/features/table_editor/domain/table_draft_state.dart';
import 'package:submersion/features/table_editor/domain/table_editor_column.dart';
import 'package:submersion/features/table_editor/domain/table_editor_entity.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/constants/entity_field.dart';

final _log = LoggerService.forClass(TableEditorEntity);

/// The paste flow (#3422): clipboard text to a plan, a plan to drafts. The
/// clipboard is read once here; everything after is pure.

/// The clipboard's text, or null when it is empty or the platform refuses.
Future<String?> readClipboardText() async {
  final ClipboardData? data;
  try {
    data = await Clipboard.getData(Clipboard.kTextPlain);
  } on PlatformException catch (e, stackTrace) {
    _log.warning(
      'Could not read the clipboard',
      error: e,
      stackTrace: stackTrace,
    );
    return null;
  }
  final text = data?.text;
  return text == null || text.isEmpty ? null : text;
}

/// Headers and labels compare without case, spaces or punctuation, so
/// "Dive #", "dive#" and "Dive Number" all name the dive number column.
String _norm(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9#À-￿]'), '');

/// Words a spreadsheet uses for the key column that no label carries.
const _keyAliases = {'dive', 'dive#', 'no', 'nr', '#', 'name'};

PastePlan<F> planClipboardPaste<T, F extends EntityField>({
  required String text,
  required TableEditorEntity<T, F> entity,
  required List<T> rows,
  required List<F> visibleColumns,
  required CellPosition selected,
  required AppLocalizations l10n,
  Set<String> hiddenKeys = const {},
}) {
  Set<String> labelsOf(F f) => {
    _norm(f.localizedDisplayName(l10n)),
    _norm(f.localizedShortLabel(l10n)),
    _norm(f.displayName),
    _norm(f.shortLabel),
    _norm(f.name),
  };
  final byLabel = <String, F>{
    for (final f in entity.adapter.allFields)
      for (final label in labelsOf(f)) label: f,
  };
  final keyLabels = {...labelsOf(entity.keyField), ..._keyAliases};
  final selectedField = entity.fieldFromName(selected.fieldName);
  return planPaste<F>(
    block: parsePasteText(text),
    rows: [
      for (final r in rows)
        SheetRow(
          id: entity.idOf(r),
          number: entity.numberOf(r),
          name: entity.nameOf(r),
        ),
    ],
    selectedRowIndex: rows.indexWhere(
      (r) => entity.idOf(r) == selected.entityId,
    ),
    visibleColumns: visibleColumns,
    selectedColumnIndex: visibleColumns.indexOf(selectedField),
    isEditableColumn: (f) => entity.columnFor(f) != null,
    columnFromLabel: (h) => byLabel[_norm(h)],
    isKeyHeader: (h) => keyLabels.contains(_norm(h)),
    hiddenKeys: hiddenKeys,
  );
}

/// Turns [plan]'s cells into drafts: each parsed by its column, reconciled
/// per record with the drafts already there, then stored. A cell the row
/// cannot edit (a library site's name) is left alone.
List<PasteSkip> applyPastePlan<T, F extends EntityField>({
  required PastePlan<F> plan,
  required TableEditorEntity<T, F> entity,
  required Map<String, T> rowsById,
  required UnitFormatter units,
  required AppLocalizations l10n,
  required TableDraftsNotifier notifier,
  TableDraftState existing = const TableDraftState(),
}) {
  final byEntity = <String, Map<String, TableDraft>>{};
  final skipped = <PasteSkip>[];
  for (final cell in plan.cells) {
    final row = rowsById[cell.entityId];
    final column = entity.columnFor(cell.field);
    if (row == null || column == null) continue;
    if (!column.isEditable(row)) {
      // Reported by the row's key, since the column itself is editable.
      final key = entity.numberOf(row)?.toString() ?? entity.nameOf(row) ?? '';
      skipped.add(PasteSkip(PasteSkipReason.readOnlyCell, detail: key));
      continue;
    }
    // A cell drafted before keeps the baseline that draft was made against,
    // so a value that moved since is still caught at save time.
    final original =
        existing.at(cell.entityId, cell.field.name)?.original ??
        column.valueOf(row);
    final draft = switch (column.parse(cell.text, units, l10n)) {
      CellParsed(:final value) => TableDraft(
        entityId: cell.entityId,
        fieldName: cell.field.name,
        original: original,
        value: value,
        rawText: cell.text,
      ),
      CellRejected(:final flag) => TableDraft(
        entityId: cell.entityId,
        fieldName: cell.field.name,
        original: original,
        value: original,
        rawText: cell.text,
        flag: flag,
      ),
    };
    byEntity.putIfAbsent(cell.entityId, () => {})[cell.field.name] = draft;
  }
  for (final entry in byEntity.entries) {
    final row = rowsById[entry.key];
    if (row == null) continue;
    final merged = {
      for (final d in existing.forEntity(entry.key)) d.fieldName: d,
      ...entry.value,
    };
    notifier.putAll(entity.reconcile(row, merged.values.toList()));
  }
  return skipped;
}
