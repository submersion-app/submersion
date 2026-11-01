import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/table_editor/domain/cell_navigation.dart';
import 'package:submersion/features/table_editor/domain/table_draft.dart';
import 'package:submersion/features/table_editor/domain/table_draft_state.dart';
import 'package:submersion/features/table_editor/domain/table_editor_column.dart';
import 'package:submersion/features/table_editor/domain/table_editor_entity.dart';
import 'package:submersion/features/table_editor/presentation/providers/table_editor_providers.dart';
import 'package:submersion/features/table_editor/presentation/widgets/editable_cell.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/constants/entity_field.dart';
import 'package:submersion/shared/models/entity_table_config.dart';
import 'package:submersion/shared/providers/entity_table_config_providers.dart';
import 'package:submersion/shared/widgets/entity_table/entity_table_menu.dart';
import 'package:submersion/shared/widgets/entity_table/entity_table_view.dart';

/// One tab's spreadsheet (#3422): the shared table with the editor's cell
/// hooks. A tap opens an editable cell, a commit becomes a draft painted in
/// place, a double tap opens the record.
class TableEditorSheet<T, F extends EntityField> extends ConsumerWidget {
  final TableEditorTab tab;
  final TableEditorEntity<T, F> entity;
  final List<T> rows;
  final StateNotifierProvider<
    EntityTableConfigNotifier<F>,
    EntityTableViewConfig<F>
  >
  configProvider;
  final EntityTableHeaderMenuBuilder<F>? headerMenuBuilder;
  final EntityTableCellMenuBuilder<T, F>? cellMenuBuilder;
  final bool Function(F field) isColumnFiltered;
  final void Function(String entityId) onOpenRecord;

  const TableEditorSheet({
    super.key,
    required this.tab,
    required this.entity,
    required this.rows,
    required this.configProvider,
    required this.isColumnFiltered,
    required this.onOpenRecord,
    this.headerMenuBuilder,
    this.cellMenuBuilder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(configProvider);
    final configNotifier = ref.read(configProvider.notifier);
    final drafts = ref.watch(tableEditorDraftsProvider(tab));
    final draftsNotifier = ref.read(tableEditorDraftsProvider(tab).notifier);
    final units = ref.watch(unitFormatterProvider);
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final rowsById = {for (final r in rows) entity.idOf(r): r};

    return EntityTableView<T, F>(
      entities: rows,
      idExtractor: entity.idOf,
      adapter: entity.adapter,
      config: config,
      units: units,
      onSortFieldChanged: configNotifier.setSortField,
      onResizeColumn: configNotifier.resizeColumn,
      onHideColumn: configNotifier.hideColumn,
      onEntityTap: (_) {},
      onEntityDoubleTap: onOpenRecord,
      headerMenuBuilder: headerMenuBuilder,
      cellMenuBuilder: cellMenuBuilder,
      isColumnFiltered: isColumnFiltered,
      onCellTap: (row, field) {
        final column = entity.columnFor(field);
        final id = entity.idOf(row);
        draftsNotifier.setSelected(CellPosition(id, field.name));
        if (column != null && column.isEditable(row)) {
          draftsNotifier.setEditing(CellPosition(id, field.name));
        }
      },
      cellBackground: (row, field) {
        final draft = drafts.at(entity.idOf(row), field.name);
        if (draft == null) return null;
        return draft.isSaveable
            ? colors.tertiaryContainer
            : colors.errorContainer;
      },
      cellBuilder: (context, row, field, formatted) {
        final id = entity.idOf(row);
        final column = entity.columnFor(field);
        final draft = drafts.at(id, field.name);
        if (column != null && drafts.editing == CellPosition(id, field.name)) {
          return _editor(
            column: column,
            row: row,
            draft: draft,
            units: units,
            l10n: l10n,
            config: config,
            rowsById: rowsById,
            drafts: drafts,
            notifier: draftsNotifier,
          );
        }
        if (draft != null && column != null) {
          return _draftCell(context, column, draft, formatted, units, l10n);
        }
        if (column != null && !column.isEditable(row)) {
          final reason = column.readOnlyReason(row, l10n);
          if (reason != null) {
            return Tooltip(message: reason, child: _plain(context, formatted));
          }
        }
        return null;
      },
    );
  }

  Widget _plain(BuildContext context, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    alignment: Alignment.centerLeft,
    child: Text(
      text,
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
      style: Theme.of(context).textTheme.bodySmall,
    ),
  );

  /// A drafted cell: the new value, or the text as typed when flagged, with
  /// the original (or the flag's reason) in a tooltip.
  Widget _draftCell(
    BuildContext context,
    TableEditorColumn<T, F> column,
    TableDraft draft,
    String formatted,
    UnitFormatter units,
    AppLocalizations l10n,
  ) {
    final String text;
    final String message;
    if (draft.flag case final flag?) {
      text = draft.rawText ?? '';
      message = switch (flag) {
        TableDraftFlag.unparsable => l10n.tableEditor_flag_unparsable,
        TableDraftFlag.unknownValue => l10n.tableEditor_flag_unknownValue,
        TableDraftFlag.pairIncomplete => l10n.tableEditor_flag_pairIncomplete,
        TableDraftFlag.changedElsewhere =>
          l10n.tableEditor_flag_changedElsewhere,
      };
    } else {
      text = _display(column, draft.value, units, l10n);
      message = l10n.tableEditor_original(
        _display(column, draft.original, units, l10n),
      );
    }
    return Tooltip(message: message, child: _plain(context, text));
  }

  /// A stored value as the cell shows it: the column formats what the
  /// adapter would for that value, so a draft reads like a saved cell.
  String _display(
    TableEditorColumn<T, F> column,
    Object? value,
    UnitFormatter units,
    AppLocalizations l10n,
  ) {
    if (value == null) return kFieldValuePlaceholder;
    switch (column.kind) {
      case CellEditorKind.choice:
      case CellEditorKind.reference:
        for (final o in column.choices(l10n)) {
          if (o.value == value) return o.label;
        }
        return value.toString();
      case CellEditorKind.multiChoice:
        final names = (value as List).cast<String>();
        return [
          for (final o in column.choices(l10n))
            if (names.contains(o.value)) o.label,
        ].join(', ');
      case CellEditorKind.toggle:
        return value == true ? l10n.attr_flagYes : l10n.attr_flagNo;
      case CellEditorKind.text:
      case CellEditorKind.number:
      case CellEditorKind.integer:
        return entity.adapter.formatValue(column.field, value, units);
    }
  }

  Widget _editor({
    required TableEditorColumn<T, F> column,
    required T row,
    required TableDraft? draft,
    required UnitFormatter units,
    required AppLocalizations l10n,
    required EntityTableViewConfig<F> config,
    required Map<String, T> rowsById,
    required TableDraftState drafts,
    required TableDraftsNotifier notifier,
  }) {
    final id = entity.idOf(row);
    final position = CellPosition(id, column.field.name);
    final original = column.valueOf(row);
    final current = draft?.value ?? original;

    void move(CellMove m) {
      final editable = [
        for (final c in config.columns)
          if (entity.columnFor(c.field) case final col?)
            if (col.isEditable(rowsById[id] ?? row)) c.field.name,
      ];
      notifier.setEditing(
        nextCell(
          from: position,
          move: m,
          rowIds: [for (final r in rows) entity.idOf(r)],
          editableFieldNames: editable,
        ),
      );
    }

    void commit(TableDraft next, CellMove m) {
      notifier.putAll(
        entity.reconcile(row, [
          ...drafts.forEntity(id).where((d) => d.fieldName != next.fieldName),
          next,
        ]),
      );
      move(m);
    }

    return EditableCell(
      key: ValueKey(position),
      kind: column.kind,
      initialText:
          draft?.rawText ??
          (draft != null && draft.value != null
              ? _display(column, draft.value, units, l10n)
              : column.editText(row, units)),
      choices: column.choices(l10n),
      initialToggle: column.kind == CellEditorKind.toggle && current == true,
      initialChoice: current is String ? current : null,
      initialSelection: current is List ? current.cast<String>() : const [],
      doneLabel: l10n.tableEditor_multiChoice_done,
      onCancel: () => notifier.setEditing(null),
      onCommitText: (text, m) {
        final result = column.parse(text, units, l10n);
        commit(switch (result) {
          CellParsed(:final value) => TableDraft(
            entityId: id,
            fieldName: column.field.name,
            original: original,
            value: value,
            rawText: text,
          ),
          CellRejected(:final flag) => TableDraft(
            entityId: id,
            fieldName: column.field.name,
            original: original,
            value: original,
            rawText: text,
            flag: flag,
          ),
        }, m);
      },
      onCommitValue: (value, m) => commit(
        TableDraft(
          entityId: id,
          fieldName: column.field.name,
          original: original,
          value: value,
        ),
        m,
      ),
    );
  }
}
